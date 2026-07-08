# WP5 — Concurrency + E2E Test Suite

**Complexity:** Medium
**Dependencies:** Test specs can be written immediately (they encode WP1's acceptance
criteria); they will fail red until WP1 merges, then must go green unmodified (or with agreed
adjustments noted in the PR). E2E mobile checks land after WP4-B.
**Findings addressed:** verification for F1–F5 and F9; regression protection for all WPs.
**Branch:** `wp5-tests`

## Context

Existing infra: Vitest (`npm test`, config `vitest.config.ts`, existing specs in
`src/stores/__tests__/auction.spec.ts` and `src/components/__tests__/App.spec.ts`) and
Playwright (`npm run test:e2e`, `playwright.config.ts`, near-empty `e2e/vue.spec.ts`).
Local stack: `supabase start` (Docker), Studio at `localhost:54323`, functions at
`http://127.0.0.1:54321/functions/v1/<name>`, service-role key printed by `supabase start`.

The races being tested are described in [README.md](README.md) findings F1–F5 and specified in
[WP1-transactional-bidding.md](WP1-transactional-bidding.md). Read both before writing specs.

## Deliverables

### 1. Integration tests for the bidding RPCs (the core of this WP)

New directory `supabase/tests/` (you own it), runnable via a Vitest project or a separate
`npm run test:integration` script (add to `package.json`; document in the README of the test
dir). Tests hit the local Supabase HTTP API / edge functions directly with the service key —
no browser. Each test seeds a fresh auction (use `create-auction` function or direct inserts;
schools come from `supabase/seed.sql`).

Required scenarios (these are WP1's acceptance criteria, encoded):

- **Concurrent bids:** fire N simultaneous `place-bid` calls with different amounts
  (`Promise.all`); assert final `current_high_bid` equals the highest _valid_ amount and
  `bid_history` contains no accepted bid lower than a previously accepted one for that school.
- **Lower-bid-late:** accepted bid at $10, then a $5 request → rejected, state unchanged.
- **Double complete:** two simultaneous `complete-bid` calls → exactly one `draft_picks` row
  for that school, budget deducted exactly once, both calls return `ok: true`.
- **Pass threshold race:** all non-high-bidder teams pass simultaneously from parallel
  requests → exactly one completion.
- **Max-bid enforcement:** team with budget B and S open slots cannot bid more than
  B − (S − 1); boundary case exactly at the max succeeds.
- **Invalid amounts:** 0, negative, non-integer, ≤ current high → rejected with `ok: false`.
- **Pass-then-bid:** team passes, later bids, is outbid; remaining teams' passes alone must
  NOT complete the sale while that team is still eligible (encodes WP1's new pass semantics).
- **Ineligible passes don't count (F9 — reproduced in a live draft):** one team's roster is
  full and it passes (as auto-pass does on every school); the remaining eligible teams minus
  one also pass → sale must NOT complete; the last eligible team then passes → sale completes.
  This encodes the premature-winner fix and must fail on pre-WP1 code.
- **No-sale:** nobody bids, everyone passes → school cleared, no pick, school stays available
  or is skipped per WP1's implemented behavior (assert whichever WP1 documents).
- **Nomination race:** two simultaneous nominations → exactly one school on the block.

### 2. Store unit tests

Extend `src/stores/__tests__/` for `myMaxBid` edge cases (empty roster, one slot left, zero
budget). Do not duplicate WP3's `positionScarcity.spec.ts` — WP3 ships that with its computed.

### 3. Playwright e2e

Replace the placeholder `e2e/vue.spec.ts` with:

- **Two-context draft loop** (desktop viewport): owner creates auction (or seed via API for
  speed), coach joins via join code, owner starts draft, nominate → bid from coach → owner
  passes → completion sting → position assignment → roster shows pick, budgets correct in
  both contexts.
- **Mobile viewport smoke** (after WP4-B merges; keep it in a separate spec file, skipped
  until then): the same coach loop at 375×812 using Playwright's iPhone preset — join, bid
  via bottom bar, assign position. Assert no horizontal overflow
  (`document.documentElement.scrollWidth <= viewport width`).

E2E must run against local Supabase; document required env in the spec or a `e2e/README.md`.

## Out of scope

- Fixing any bug the tests reveal (report to WP1 owner instead; keep the failing test,
  marked `.fails`/`.skip` with a comment referencing the finding).
- CI pipeline setup (valuable, but a separate decision — note recommendations in the PR).
- Load/soak testing.

## Acceptance criteria

- [ ] `npm run test:integration` exists and runs the scenario list above against local
      Supabase; all green on a branch containing WP1.
- [ ] Integration tests are independent and re-runnable (fresh auction per test, no
      cross-test state).
- [ ] Two-context e2e passes headless on a branch containing WP1 (it exercises current UI,
      so it must also pass on plain `main` + WP1 — don't depend on WP3/WP4 markup; select by
      text/role, not layout-specific classes).
- [ ] Mobile e2e spec exists (skipped or green depending on whether WP4-B has merged).
- [ ] `npm test` unchanged suites still pass.
