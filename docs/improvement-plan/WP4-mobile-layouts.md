# WP4 — Mobile Web Layouts

**Complexity:** Hard (largest UI change)
**Dependencies:** Part A: none, start immediately. **Part B: start after WP3 merges**
(WP3 adds a PositionBoard component and NominationGrid filter chips that Part B repositions).
**Findings addressed:** F7 (see [README.md](README.md))
**Branch:** `wp4a-mobile-shell` / `wp4b-mobile-draft`

## Problem

The app has zero responsive breakpoints (`grep -c 'sm:\|md:\|lg:'` over `src/` returns 0
matches in every view). `src/views/auction/DraftView.vue:955` is a fixed 12-column grid inside
`h-[calc(100vh-104px)] overflow-hidden`; below ~1024px columns collapse into unusable slivers.
Coaches want to draft from phones. Target: fully usable at 375×812 (iPhone-class), portrait.

`index.html` already has a correct viewport meta (line 6). Tailwind v4; tokens in
`src/assets/main.css` under `@theme {}`. Design system "Gridiron Prime" — keep the dark
broadcast aesthetic on mobile; don't invent a second visual language.

General approach: **desktop layout is the `lg:` variant, mobile is the default.** Refactor
class lists so current desktop classes get `lg:` prefixes and mobile-first classes take their
place. Prefer restructuring templates over CSS trickery.

## Part A — Join, Lobby, Roster, shell (branch `wp4a-mobile-shell`)

Files owned: `src/views/JoinView.vue`, `src/views/auction/LobbyView.vue`,
`src/views/auction/RosterView.vue`, `src/components/AppShell.vue`,
`src/components/lobby/ParticipantCard.vue`, `src/components/lobby/PracticeBiddingZone.vue`,
`src/assets/main.css` (additive only), `index.html`.

- **JoinView is the top priority** — guests join via a link _on their phones_. Form must be
  comfortable one-handed: full-width inputs, ≥44px touch targets, `font-size >= 16px` on
  inputs (prevents iOS focus zoom), sensible `autocomplete`/`inputmode` attributes.
- **LobbyView:** stack panels single-column below `lg:`; ready toggle and team-slot picker
  thumb-reachable; participant list scrolls naturally.
- **RosterView:** roster tables/cards stack; if any table is wider than the viewport wrap it
  in `overflow-x-auto` rather than shrinking text below legibility. Keep the CSV export button
  reachable.
- **Shell:** add `viewport-fit=cover` to the viewport meta and safe-area padding
  (`env(safe-area-inset-*)`) where fixed/sticky elements are introduced.

## Part B — DraftView + NominationGrid + modals (branch `wp4b-mobile-draft`, after WP3)

Files owned: `src/views/auction/DraftView.vue`, `src/components/draft/NominationGrid.vue`,
`src/components/draft/PositionAssignmentModal.vue`, `src/components/draft/PickIsInSting.vue`,
`src/components/draft/ConnectionLostOverlay.vue`.

Keep the existing 12-column layout **unchanged at `lg:` and up**. Below `lg:`:

- **Single-column scroll layout** — drop `h-[calc(100vh-104px)] overflow-hidden` on small
  screens; the page scrolls normally.
- **"On the block" card** (school, current bid, high bidder, nominator) pinned at top
  (`sticky top-0`) so it's always visible.
- **Sticky bottom bid bar**: min-bid button (+$1), +$5, custom amount input, PASS. This is the
  critical control surface — thumb zone, ≥44px targets, safe-area bottom padding, disabled
  states identical to desktop logic (reuse the same handlers: `bid()`, `submitCustomBid()`,
  `pass()` in the script, lines 321-355 — **do not duplicate bidding logic**).
- **Tabs** for the middle content: Bid Log / Rosters / Positions (WP3's PositionBoard goes in
  the Positions tab; on desktop it stays in the sidebar). Local `ref` for the active tab is
  fine — no router changes.
- **NominationGrid:** full-screen sheet on mobile; school grid `grid-cols-1 sm:grid-cols-2`
  (currently hardcoded `grid-cols-2` at line 136); filter chip rows horizontally scrollable
  (`overflow-x-auto`, no wrap) so WP3's position chips + conference chips fit.
- **PositionAssignmentModal / PickIsInSting:** verify at 375px; buttons stack vertically if
  cramped.
- **Admin panel** (the `isAdmin` sections and pre-draft admin grid at lines 681-953): out of
  scope for phone optimization — the auction master uses a laptop. It only needs to not render
  broken if opened on mobile (acceptable: usable-but-ugly). The coach-facing layout must never
  regress because of admin markup.

## Both parts

- Test with Playwright viewport presets or browser device emulation at 375×812 and 768×1024;
  desktop (1280+) must be pixel-equivalent to current behavior (screenshot before/after).
- No new dependencies; Tailwind utilities only.
- If a shared component needs a tweak owned by another WP, note it in the PR instead of
  editing (see ownership map in [README.md](README.md)).

## Acceptance criteria

Part A:

- [ ] Join flow (link → name → slot claim → lobby) completable one-handed at 375px with no
      horizontal scroll and no zoomed-in inputs.
- [ ] Lobby and Roster render single-column at 375px, unchanged at ≥1024px.

Part B:

- [ ] Full coach draft loop at 375px: see school on block → bid via bottom bar → win → position
      assignment modal → roster tab reflects pick. No horizontal scroll anywhere.
- [ ] Bid bar always visible while any tab is active; custom-bid input does not get hidden
      behind the on-screen keyboard (verify in device emulation).
- [ ] Nomination sheet usable at 375px including WP3's position filter chips.
- [ ] Desktop (≥1024px) layout visually unchanged.
- [ ] `npm test`, `npm run test:e2e`, `npm run build` pass.
