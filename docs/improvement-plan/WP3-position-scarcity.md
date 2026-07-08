# WP3 — Position Supply/Demand Information

**Complexity:** Medium
**Dependencies:** None — start immediately. **WP4 Part B waits on this** (it rearranges
DraftView/NominationGrid after you land), so prefer landing this promptly.
**Findings addressed:** F8 (see [README.md](README.md))
**Branch:** `wp3-position-scarcity`

## Problem (this caused real pain in a live draft)

Coaches had no way to see how many schools were still available at a given position versus how
many roster slots league-wide still needed that position. Teams bid casually on a position and
then discovered supply had run out.

Data model (see `supabase/migrations/20260404000000_initial_schema.sql`):

- `auction_schools.leagify_position` (TEXT, line 179) — the school's position.
- `roster_positions` per auction: `position_name`, `slots_per_team`, `is_flex`
  (lines 155-168). Eligibility rule in `is_position_eligible` (lines 317-333): a school fits a
  roster position when `LOWER(leagify_position) = LOWER(position_name)`, **or the roster
  position is flex** (flex accepts any position).
- `draft_picks.roster_position_id` links picks to slots; picks can transiently be NULL
  (assigned via modal after winning).

Current UI: `src/components/draft/NominationGrid.vue` filters by conference + text search only
(lines 24-42) and shows only _your own_ roster slots. Nothing during bidding shows scarcity.

## Approach

### 1. Store computeds — `src/stores/auction.ts` (you own additive changes here)

Add a computed `positionScarcity` producing, per distinct `leagify_position` present in the
auction's schools:

- `supply`: count of `schools` where `is_available && leagify_position === pos`.
- `demand`: league-wide open non-flex slots for that position — for each active team, sum
  `max(0, slots_per_team - filledCount)` over roster positions whose `position_name` matches
  `pos` case-insensitively (mirror `is_position_eligible`; do the comparison case-insensitively
  in JS). Count a pick as filling a position only when `roster_position_id` is set; also expose
  the count of unassigned picks so the UI can hint at temporary imprecision if nonzero.
- `flexDemand` (single shared number, not per-position): open flex slots league-wide — any
  position can fill these.
- `topRemaining`: highest `projected_points` available school at that position (name + points).
- `scarce`: boolean, `supply <= demand` (flex demand deliberately excluded from the flag —
  it's a soft demand; note this in a code comment).

Sort by scarcity first, then by supply ascending. Do **not** modify existing state/computeds —
WP2 may add a `silent` param to `loadAuction`; that's the only other change expected in this
file, so conflicts should be trivial.

Unit-test the computed in `src/stores/__tests__/` (WP5 owns the test dirs, but shipping the
computed's own spec with this WP is expected and coordinated — put it in a new file
`positionScarcity.spec.ts` to avoid clashing with existing `auction.spec.ts`).

### 2. New component — `src/components/draft/PositionBoard.vue`

Compact panel listing each position: name, `supply` remaining, `demand` open slots, scarce
badge when `scarce` (use the existing `text-tertiary` / warning-style tokens; match Gridiron
Prime idioms — dark surfaces, `font-label` uppercase micro-text, no rounded corners; crib
markup patterns from the roster summary in `NominationGrid.vue:82-102`). One line per
position, plus a footer line for open flex slots. Keep it dense: it must fit in a sidebar
column without scrolling for ~6 positions.

### 3. Surface it in DraftView (minimal insertion only)

Add `<PositionBoard />` in the right-hand sidebar column of `src/views/auction/DraftView.vue`
(the `col-span-4` column starting at line 1280), above or below the existing content —
pick the spot that doesn't push the bid log off-screen at 1080p. **Do not restructure the
layout** — WP4-B owns the DraftView template refactor and will reposition the component for
mobile; keep your diff to the import + one insertion.

### 4. Position filters in NominationGrid

In `src/components/draft/NominationGrid.vue`:

- Add a row of position filter chips (pattern-match the existing conference chips,
  lines 118-133) with the remaining count in each chip label, e.g. `SEC · 3`, and a scarce
  indicator on scarce positions.
- Position filter combines with conference filter and search (AND).
- Also show `leagify_position` scarcity inline on school cards if cheap to do (the position
  is already rendered at line 170-172).

## Out of scope

- Any schema/edge-function change (pure client feature).
- Mobile layout of the new panel (WP4-B handles placement below `lg:`).
- Historical/analytics views.

## Acceptance criteria

- [ ] `positionScarcity` computed matches hand-computed values in a unit test covering:
      flex slots, case-insensitive position match, unassigned picks, sold-out position.
- [ ] PositionBoard visible in DraftView sidebar during bidding; counts update live as picks
      complete (verify with two windows: win a school in one, watch counts change in both).
- [ ] NominationGrid can filter by position; chips show live remaining counts.
- [ ] Scarce badge appears exactly when remaining supply ≤ open demand for that position.
- [ ] DraftView diff is limited to import + component insertion.
- [ ] `npm test` and `npm run build` pass.
