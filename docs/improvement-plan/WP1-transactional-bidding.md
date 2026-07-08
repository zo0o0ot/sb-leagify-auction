# WP1 — Transactional Bidding RPCs + DB Constraints

**Complexity:** Medium-Hard
**Dependencies:** None — start immediately. WP5's integration tests run against this.
**Findings addressed:** F1, F2, F3, F4, F5, F9 (see [README.md](README.md))
**Branch:** `wp1-transactional-bidding`

## Problem

All four bidding edge functions (`supabase/functions/{place-bid,complete-bid,pass-bid,nominate-school}/index.ts`)
do read → validate → write with a service-role Supabase client and **no transaction or lock**:

- Two concurrent `place-bid` calls can both pass validation; the last `UPDATE auctions` wins
  even if it carries the **lower** bid (`place-bid/index.ts:35-53`).
- `complete-bid` deducts budget with read-then-write (`complete-bid/index.ts:39-51`) and inserts
  a draft pick with no uniqueness guard. Called twice for the same school (which happens: the
  pass-threshold trigger in `pass-bid/index.ts:117-128` can race the admin "Force End Bidding"
  button, and auto-pass fires from every connected client — `DraftView.vue:272-311`), it deducts
  budget twice and creates two picks.
- `place-bid/index.ts:21-75` contains a dead branch: it calls RPC `get_auction_for_update`,
  which exists in no migration. If that RPC is ever created and returns data, the function
  returns `{ok: true}` **without placing the bid**. Delete this branch.
- The "max bid" rule (budget minus $1 per remaining open roster slot, see `myMaxBid` in
  `src/stores/auction.ts:96-106`) is enforced only client-side. Server checks only
  `remaining_budget`. No integer validation on `amount`.
- Pass semantics: a pass counts forever per (team, school) (`pass-bid/index.ts:50-59`). A team
  that passes, then bids, then is outbid still has its old pass counted, so bidding can be
  ended under a team that wants to keep bidding.
- **Premature sale (F9, confirmed in a live draft):** the pass count includes passes from
  **ineligible** teams (only the high bidder is excluded, `pass-bid/index.ts:50-59`), while
  the required count excludes roster-full teams (`pass-bid/index.ts:61-96`). Auto-pass makes
  roster-full teams pass on every school (`DraftView.vue:272-311`), so each roster-full team
  inflates the numerator without being in the denominator — the sale completes while eligible
  teams are still bidding.

## Approach

Move each state transition into a **single Postgres function** (SECURITY DEFINER, called via
RPC from the edge functions) so it runs in one transaction with `SELECT ... FOR UPDATE` on the
`auctions` row. The edge functions become thin wrappers: parse body → call RPC → return the
existing `{ok, error}` envelope (do NOT change the response shape; the client depends on it).
Keep the edge functions as the public entry points — the client code in `src/stores/auction.ts`
must not need changes.

New migration(s) under `supabase/migrations/` with `202607DDHHMMSS` timestamps.

### `fn_place_bid(p_auction_id, p_participant_id, p_team_id, p_amount, p_on_behalf_of_team_id)`

Lock auction row, then validate:

1. status is `in_progress` or `practice`; a school is on the block.
2. `p_amount` is a positive integer strictly greater than `current_high_bid`.
3. Effective team (`on_behalf_of` if set, else `team_id`) exists and is active.
4. **Server-side max bid:** `p_amount <= remaining_budget - (open_roster_slots_after_this_win - 1)`
   where open slots = sum of `roster_positions.slots_per_team` minus that team's `draft_picks`
   count. (Mirror the client's `myMaxBid` computation; the DB already has a
   `calculate_max_bid()` helper from the initial schema — reuse or fix it if correct.)

Then atomically: update `auctions.current_high_bid/current_high_bidder_id`, insert
`bid_history` row. Distinct error messages per failure (used directly in the UI).

### `fn_complete_bid(p_auction_id)`

Lock auction row. If `current_school_id IS NULL`, return an "already completed / nothing on
the block" result **without error** — this is the idempotency guard that defuses the
double-completion race. Otherwise, in the same transaction, port the existing logic from
`complete-bid/index.ts`: deduct budget, insert draft pick (`pick_order` = count+1 is now safe
under the lock), mark school unavailable, mark winning bid, advance nominator with the
existing roster-full skip logic (lines 96-155), set status `completed` when no eligible
nominator remains, clear the `current_*` fields.

### `fn_pass_bid(p_auction_id, p_participant_id, p_team_id)`

Lock auction row. Record the pass (idempotent: passing twice is not an error). Compute the
**eligible set** once — active teams with a participant and a non-full roster, excluding the
current high bidder (as in `pass-bid/index.ts:61-96`) — then apply two counting rules, both
required:

1. **Count only passes from teams in the eligible set** (fixes F9). The current code counts
   every pass except the high bidder's, so auto-passes from roster-full teams meet the
   threshold early and the sale completes while eligible teams are still bidding. The
   threshold is met only when **every team in the eligible set** has a live pass — not when
   a raw pass count reaches the eligible-set size.
2. **A bid invalidates the team's earlier pass on that school** (fixes F5): a team's pass is
   live only if it has not placed a `bid_type='bid'` row for this school _after_ its most
   recent pass.

When the threshold is met: call `fn_complete_bid` directly (same transaction) instead of the
current HTTP fetch to the complete-bid function (`pass-bid/index.ts:119-127`). Keep the
no-sale path (no high bidder + all eligible teams passed → clear the block without a pick).

### `fn_nominate_school(p_auction_id, p_participant_id, p_team_id, p_auction_school_id, p_is_admin_override)`

Lock auction row; port validations from `nominate-school/index.ts` (in_progress, nothing on
the block, nominator turn unless admin override, school available). Add: nominating team's
**max bid** must be ≥ 1 (not just budget ≥ 1), since nomination commits them to the $1 opening
bid. Set school on block + insert nomination and $1 opening bid history rows atomically.

### Defense-in-depth constraints (same migration)

- `ALTER TABLE teams ADD CONSTRAINT teams_budget_nonneg CHECK (remaining_budget >= 0);`
- `ALTER TABLE draft_picks ADD CONSTRAINT draft_picks_school_once UNIQUE (auction_id, auction_school_id);`
- Verify existing data won't violate these (fresh reset is fine; note it in the PR if a
  constraint needs `NOT VALID` for existing deployments).

## Out of scope

- Client changes (`src/**`) — response envelopes must stay compatible so none are needed.
- Auto-pass client-side dedup (the server-side idempotency above makes duplicate calls safe).
- RLS tightening (the permissive MVP policies stay as they are).
- `admin-assign` and `create-auction` functions.

## Acceptance criteria

- [ ] Dead `get_auction_for_update` branch removed from place-bid.
- [ ] All four operations run as single-transaction RPCs with `FOR UPDATE` on the auction row.
- [ ] Two concurrent `place-bid` calls: exactly one wins; final `current_high_bid` is the
      highest accepted amount, never overwritten by a lower one.
- [ ] `complete-bid` called twice concurrently or sequentially: one draft pick, one budget
      deduction, second call returns ok (no error, no effect).
- [ ] Bid above the max-bid rule is rejected server-side with a clear message.
- [ ] Non-integer / zero / negative amounts rejected.
- [ ] Team that passes then bids is no longer counted as passed for that school.
- [ ] A roster-full team's pass does not count toward the threshold: with one roster-full
      team auto-passing, the sale must NOT complete until every eligible team has passed
      (regression for the live-draft premature-winner incident, F9).
- [ ] Full happy path works in the browser against local Supabase with two windows:
      nominate → bid → passes → sting → position assignment → next nominator.
- [ ] `supabase db reset` runs clean; existing Vitest suite passes.

## Verification recipe

Concurrency without WP5's harness: `supabase start`, then fire simultaneous requests with
`curl` (e.g. two `curl ... &` to `http://127.0.0.1:54321/functions/v1/place-bid` with the
service key) and inspect `auctions` / `draft_picks` / `teams` in Studio (`localhost:54323`).
