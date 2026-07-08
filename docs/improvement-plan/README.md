# Improvement Plan: Bidding Correctness, Position Scarcity, Mobile Support

**Status:** Planned — no work started
**Created:** 2026-07-07
**Origin:** Post-draft retrospective. Issues hit in a live draft: no visibility into how many
schools remained at a position, bidding edge cases, and the app being unusable on phones.

This directory is the coordination point for splitting the work across multiple agents/sessions.
Each work package (WP) has its own brief in this directory and is written to be self-contained:
an agent should be able to read `README.md` + its own `WPn-*.md` and start working without any
other context.

## Documents

| File                                                         | Work package                                | Can start                               |
| ------------------------------------------------------------ | ------------------------------------------- | --------------------------------------- |
| [WP1-transactional-bidding.md](WP1-transactional-bidding.md) | Transactional bidding RPCs + DB constraints | Immediately                             |
| [WP2-reconnect-resync.md](WP2-reconnect-resync.md)           | State resync on reconnect / tab resume      | Immediately                             |
| [WP3-position-scarcity.md](WP3-position-scarcity.md)         | Position supply/demand info in draft UI     | Immediately                             |
| [WP4-mobile-layouts.md](WP4-mobile-layouts.md)               | Mobile web layouts                          | Part A immediately; Part B after WP3    |
| [WP5-concurrency-tests.md](WP5-concurrency-tests.md)         | Concurrency + e2e test suite                | Specs immediately; green only after WP1 |

## Findings (shared context)

These are verified against the code as of commit `2273ade`. Work-package briefs reference them
by ID.

- **F1 — Dead locking path in place-bid.** `supabase/functions/place-bid/index.ts:21` calls an
  RPC `get_auction_for_update` that exists in **no migration**. Today the error fallback always
  runs so bids work; but if that RPC is ever created, the function returns `{ok: true}` at
  lines 71–75 **without placing the bid**. The row-locking mitigation planned for the MVP was
  never implemented.
- **F2 — No atomicity in any bidding function.** All four edge functions
  (`place-bid`, `complete-bid`, `pass-bid`, `nominate-school`) do read → validate → write with
  a service-role client and no transaction/lock. Two concurrent bids can both pass validation
  and the **last write wins even if it is the lower bid** (`place-bid/index.ts:35-53`).
- **F3 — Double-completion race.** `complete-bid` deducts budget via read-then-write
  (`complete-bid/index.ts:39-51`) and creates a draft pick with no uniqueness guard. If invoked
  twice for the same school, budget is deducted twice and two picks are created. Two live
  triggers can race: `pass-bid` fires `complete-bid` when the pass threshold is met
  (`pass-bid/index.ts:117-128`), and the admin "Force End Bidding" button calls it directly.
  Additionally the auto-pass watcher in `src/views/auction/DraftView.vue:272-311` runs on every
  connected client, so several near-simultaneous passes are normal, not rare.
- **F4 — Max-bid rule enforced client-side only.** The store computes `myMaxBid`
  (`src/stores/auction.ts:96-106`) reserving $1 per remaining open roster slot, but the server
  only checks `remaining_budget` (`place-bid/index.ts:45`). A stale or modified client can bid
  itself into being unable to fill its roster. No integer/positivity validation on `amount`.
- **F5 — Pass semantics.** A pass is recorded once per team per school and counted forever
  (`pass-bid/index.ts:50-59`). A team that passes at $5, later bids, and is outbid still has
  its old pass counted toward "all teams passed", which can end bidding under them.
- **F6 — No state resync after missed realtime events.** `src/composables/useAuctionRealtime.ts`
  loads state once on mount and then applies deltas only. On reconnect (`SUBSCRIBED` after a
  drop) nothing is refetched. Phones suspend WebSockets when the browser is backgrounded, so
  this guarantees stale UI on mobile and after any network blip.
- **F7 — No responsive design.** Zero `sm:`/`md:`/`lg:` classes in the entire app. DraftView's
  main layout is a fixed 12-column grid with `h-[calc(100vh-104px)] overflow-hidden`
  (`DraftView.vue:955`). Unusable below ~1024px.
- **F8 — No position-scarcity information.** Schools carry `leagify_position`
  (`auction_schools`, initial schema line 179) and rosters have positions with flex support
  (`is_position_eligible`, initial schema lines 317-333), but no UI shows remaining schools
  per position vs. open roster slots league-wide. NominationGrid filters only by conference
  and search (`src/components/draft/NominationGrid.vue:24-42`).
- **F9 — Premature sale: ineligible teams' passes count toward the pass threshold.**
  Confirmed cause of a live-draft incident where a winner was declared while eligible teams
  were still bidding. In `pass-bid/index.ts` the pass count (lines 50-59) includes **every**
  pass row for the school except the current high bidder's, but the required-pass count
  (lines 61-96) **excludes roster-full teams** (and teams without participants). Auto-pass
  (`DraftView.vue:272-311`) makes roster-full teams pass on every new school, so each
  roster-full team inflates the numerator by one while being absent from the denominator —
  bidding ends one eligible team early per roster-full team. Worsens late in a draft as
  rosters fill; typically first noticed after a coach finishes their roster and leaves.
  Fix specified in WP1 (`fn_pass_bid`): count only passes from currently-eligible teams.

## Dependency graph

```
WP1 (bidding RPCs) ──────────────► WP5 (tests must run against WP1's RPCs)
WP2 (resync)          independent
WP3 (position board) ────────────► WP4 Part B (DraftView/NominationGrid mobile refactor
WP4 Part A (Join/Lobby/Roster)      rearranges the components WP3 adds — land WP3 first)
```

Safe to run in parallel from day one: **WP1, WP2, WP3, WP4-A**. Then WP4-B and WP5 finish.

## File ownership (conflict avoidance)

Each file is owned by exactly one WP. If you need a change in a file you don't own, note it in
your PR description instead of editing it, unless marked "shared" below.

| Path                                                                        | Owner                                                        |
| --------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `supabase/migrations/**` (new files)                                        | WP1 (use `202607*` timestamps)                               |
| `supabase/functions/**`                                                     | WP1                                                          |
| `src/composables/useAuctionRealtime.ts`                                     | WP2                                                          |
| `src/stores/auction.ts`                                                     | WP3 (new computeds only; **do not** reshape existing state)  |
| `src/components/draft/PositionBoard.vue` (new)                              | WP3                                                          |
| `src/components/draft/NominationGrid.vue`                                   | WP3, then WP4-B                                              |
| `src/views/auction/DraftView.vue`                                           | WP3 (minimal insertion of PositionBoard), then WP4-B         |
| `src/views/JoinView.vue`, `LobbyView.vue`, `RosterView.vue`, `AppShell.vue` | WP4-A                                                        |
| `src/stores/__tests__/**`, `e2e/**`, new `supabase/tests/**`                | WP5                                                          |
| `src/types/auction.ts`                                                      | shared — additive changes only, never modify existing fields |

## Conventions (all WPs)

- **Branch naming:** `wp1-transactional-bidding`, `wp2-resync`, etc. Base off `main`.
- **Migrations:** only WP1 creates them. Timestamp prefix `202607DDHHMMSS`, sequential.
- **Local dev:** `supabase start` (Docker required), `.env.local` from `supabase start` output,
  `npm run dev`. Reset DB with `supabase db reset` (applies all migrations + `seed.sql`).
- **Tests:** `npm test` (Vitest), `npm run test:e2e` (Playwright). Don't break existing tests.
- **Tailwind v4:** color tokens live in `src/assets/main.css` under `@theme {}` — there is no
  `tailwind.config.js`. Design system is "Gridiron Prime" (see `stitches/STITCHES-OVERVIEW.md`);
  match existing utility-class idioms.
- **Edge function error style:** functions currently return HTTP 200 with `{ok: false, error}`;
  the client checks `data.ok`. Keep this envelope (WP1 included) — changing it breaks the store.
- **Do not** touch the untracked scratch files at repo root (`DEBUG-CREATE-AUCTION.md`, etc.).

## Definition of done (every WP)

1. Acceptance criteria in the WP brief all pass.
2. `npm test`, `npm run build`, and lint pass.
3. Behavior verified in the running app against local Supabase (two browser windows for
   anything multi-participant), not just unit tests.
4. WP brief updated: check off criteria, note deviations.
