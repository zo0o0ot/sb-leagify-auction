# MVP Build Plan — April 5–8

Target: a running auction from create → lobby → live draft → position assignment.

---

## Environment Setup Checklist (do first)

```bash
# 1. Install Docker Desktop
#    Download from https://docs.docker.com/desktop/install/linux/
#    Or on Ubuntu:
sudo apt-get install docker.io docker-compose-v2
sudo usermod -aG docker $USER
# Log out and back in, then verify:
docker run hello-world

# 2. Install Supabase CLI
npm install -g supabase
# or via homebrew if available:
# brew install supabase/tap/supabase

# 3. Start the local stack
cd /path/to/sb-leagify-auction
supabase start
# This prints out local keys — copy them into .env.local

# 4. Create .env.local (never commit this)
# VITE_SUPABASE_URL=http://127.0.0.1:54321
# VITE_SUPABASE_ANON_KEY=<anon key from supabase start output>

# 5. Run migrations + seed
npm run db:reset

# 6. Start Vue dev server
npm run dev
# Should be live at http://localhost:5173
```

**One config change needed before `supabase start`:**
In `supabase/config.toml`, line 171 — change:
```
enable_anonymous_sign_ins = false
```
to:
```
enable_anonymous_sign_ins = true
```
The join flow uses Supabase anonymous auth. Without this, no one can join.

---

## Current Build Status (updated Apr 6)

| Area | Status |
|------|--------|
| Vue 3 + Vite + TypeScript | Done |
| Tailwind CSS v4 + Gridiron Prime tokens | Done — `src/assets/main.css` |
| Supabase client + session-token header injection | Done — `src/lib/supabase.ts` |
| PostgREST pre_request hook (RLS session_token) | Done — migration `20260406000000_add_pre_request.sql` |
| Vue Router (all routes) | Done — `src/router/index.ts` |
| Pinia auction store | Done — `src/stores/auction.ts` |
| TypeScript types | Done — `src/types/auction.ts` |
| AppShell component | Done — `src/components/AppShell.vue` |
| Join page (`/join`) | Done — `src/views/JoinView.vue` |
| Create Auction page (`/create`) | Done — `src/views/CreateAuctionView.vue` |
| Maintain Schools + CSV upload (`/admin/schools`) | Done — `src/views/admin/MaintainSchoolsView.vue` |
| Realtime composable | Done — `src/composables/useAuctionRealtime.ts` |
| Participant card component | Done — `src/components/lobby/ParticipantCard.vue` |
| Practice Bidding Zone component | Done — `src/components/lobby/PracticeBiddingZone.vue` |
| Auction Lobby — coach + admin views | Done — `src/views/auction/LobbyView.vue` |
| myMaxBid unit tests (9 passing) | Done — `src/stores/__tests__/auction.spec.ts` |
| Live Draft view | **Not started — Day 3** |
| Edge Functions (place-bid, pass, complete-bid) | **Not started — Day 3** |

---

## Scope Decision: What's In vs. Out for MVP

### In (needed to run a draft)
- Gridiron Prime design system wired into Tailwind
- App shell (header + sidebar)
- Join page — code + name + team slot selection
- Create auction page — name, join code, budget, participant count, roster positions, school data
- Maintain Schools / CSV upload — school import and review
- Auction Lobby — coach and admin views with embedded practice bidding
- Live bidding console — nominations, bidding, pass, out-of-budget state
- "The Pick is In" sting overlay
- Position assignment modal
- On the Clock alert
- Admin mode toggle — proxy bidding + auto-pass per team
- Auction controls — start, pause, resume (sidebar overrides)
- Connection lost overlay
- Edge Functions: place bid, pass, complete bid, advance nomination

### Out for MVP (defer)
- Post-auction views (standings, squad recap, draft log) — use Supabase Studio to view results
- System admin dashboard — manage via Supabase Studio directly
- Results CSV export
- Reconnection syncing (beyond basic Supabase Realtime auto-reconnect)
- Mobile/tablet responsiveness
- Comprehensive test coverage (write tests for edge functions only)
- Fuzzy CSV matching — use exact school name match only

---

## Day-by-Day Build Sequence

### Day 1 — Foundation + Entry Flow ✅ COMPLETE
**Goal: the app runs, someone can join an auction**

1. ✅ **Gridiron Prime Tailwind config** — `src/assets/main.css` with `@theme {}` block
2. ✅ **App shell** — `AppShell.vue` with header, sidebar, ticker, named slots
3. ✅ **Pinia auction store** — `stores/auction.ts` with full state + myMaxBid
4. ✅ **Join page** — anonymous auth, participant insert, team slot picker, session save
5. ✅ **Session persistence** — localStorage, route guard on protected routes
6. ✅ **Create Auction page** — single-page, join code, budget, roster positions, creator gets team 1
7. ✅ **Basic routing** — all routes wired, session guard
8. ✅ **myMaxBid unit tests** — 9 passing in Vitest

---

### Day 2 — Lobby + School Setup ✅ COMPLETE
**Goal: everyone is in the lobby and can practice bid**

1. ✅ **Maintain Schools page** (`/admin/schools`) — school table, search/sort, CSV upload (parse → preview → import), export template, logo edit modal stub
2. ✅ **Auction Lobby — Coach view** — left: participant readiness list; right: Practice Bidding Zone
3. ✅ **Auction Lobby — Admin view** — same route, admin right panel: school on block, Force bid controls, START DRAFT gated on allCoachesReady, Skip override
4. ✅ **Team slot self-selection on join** — join page slot picker, slot name = display name
5. ✅ **Realtime presence** — `useAuctionRealtime` composable, `is_connected` heartbeat, 6-table subscription

---

### Day 3 — Live Draft ✅ COMPLETE
**Goal: a full auction round works end-to-end**

1. ✅ **Live Bidding Console** (`/auction/:id/draft`) — school hero, bid controls (+$1/+$5/+$10/custom), auto-pass lock state, bid log, admin right panel (team budgets + picks), nomination order sidebar
2. ✅ **School Nomination Grid** — `NominationGrid.vue`, conference filter tabs, school grid, nominate action
3. ✅ **On the Clock / Nominate Now** — inline prompt + sidebar button when it's coach's turn and no school on block
4. ✅ **Out of Budget state** — bid controls replaced with BIDDING LOCKED indicator, Pass button auto-activates
5. ✅ **Admin mode toggle** — proxy team dropdown + per-team auto-pass toggles, audit right panel at col-span-4
6. ✅ **Edge Function: `place-bid`** — validates bid > current, ≤ budget, records bid_history
7. ✅ **Edge Function: `pass-bid`** — records pass, auto-triggers complete-bid when all non-high-bidders passed
8. ✅ **Edge Function: `complete-bid`** — deducts budget, creates draft_pick, marks school unavailable, advances nominator (circular by nomination_order)
9. ✅ **Edge Function: `nominate-school`** — validates turn order, sets current_school_id on auction
10. ✅ **"The Pick is In" sting** — `PickIsInSting.vue`, full-screen overlay, school logo, winner, price, auto-dismiss 4s
11. ✅ **Position Assignment Modal** — `PositionAssignmentModal.vue`, roster slot radio group, confirm updates draft_pick
12. ✅ **Connection Lost overlay** — `ConnectionLostOverlay.vue`, shown on Supabase Realtime disconnect
13. ✅ **Auction controls** — Pause, Resume, Force End Bidding wired to auction status transitions
14. ✅ **Migration** — `draft_picks.roster_position_id` made nullable (assigned post-sting via modal)

---

## Critical Implementation Notes

### Tailwind v4 Color Tokens
The project uses Tailwind v4 (`@tailwindcss/vite`). Color tokens go in `src/assets/main.css` as CSS custom properties, not in a `tailwind.config.js`:
```css
@import 'tailwindcss';

@theme {
  --color-surface-container-lowest: #0a0e14;
  --color-surface-container-low: #181c22;
  --color-surface-container: #1c2026;
  --color-surface-container-high: #262a31;
  --color-surface-container-highest: #31353c;
  --color-primary: #adc6ff;
  --color-secondary: #ffb3b2;
  --color-tertiary: #e9c400;
  --color-secondary-container: #bf012c;
  --color-on-primary-container: #3686ff;
  --color-on-primary-fixed: #001a41;
  --color-on-surface: #dfe2eb;
  --color-on-surface-variant: #c4c6cf;
  --color-outline-variant: #43474e;
  --color-outline: #8d9199;
  --color-on-tertiary-fixed: #221b00;
  --color-tertiary-container: #c9a900;
  --font-headline: 'Space Grotesk', sans-serif;
  --font-body: 'Inter', sans-serif;
  --font-label: 'Space Grotesk', sans-serif;
  --radius-DEFAULT: 0.125rem;
  --radius-lg: 0.25rem;
  --radius-xl: 0.5rem;
}
```

### Shared CSS Utilities
Add to `main.css` after `@theme`:
```css
.glass-panel {
  background: rgba(28, 32, 38, 0.6);
  backdrop-filter: blur(12px);
  outline: 1px solid rgba(67, 71, 78, 0.15);
}
.metallic-primary {
  background: linear-gradient(135deg, #adc6ff 0%, #3686ff 100%);
}
.metallic-secondary {
  background: linear-gradient(135deg, #ffb3b2 0%, #bf012c 100%);
}
```

### Anonymous Auth + Session
`supabase/config.toml` must have `enable_anonymous_sign_ins = true`.
The join flow calls `supabase.auth.signInAnonymously()`, then stores `{ participantId, auctionId, teamId, sessionToken }` in localStorage.

### Creator Gets a Team Automatically
When `create-auction` runs, after creating the auction record it also:
1. Creates N placeholder team slots (`teams` table) with names "Team 1" through "Team N"
2. Claims slot 1 for the creator: updates that team record with the creator's display name and links their participant record

### Edge Function Race Conditions
`place-bid` and `pass`/`complete-bid` must use Postgres advisory locks or `SELECT FOR UPDATE` to prevent two simultaneous bids both thinking they're the winner. This is the highest-risk implementation item.

### Realtime Subscriptions
One channel per auction (`auction:{id}`), subscribed to:
- `auctions` table (status, current bid state)
- `participants` table (connection status, readiness)
- `bid_history` table (live bid log)
- `draft_picks` table (roster updates)

### Route Structure
```
/                     → redirect to /join
/join                 → JoinView.vue
/create               → CreateAuctionView.vue
/admin/schools        → MaintainSchoolsView.vue
/auction/:id/lobby    → LobbyView.vue (coach + admin, role-conditional)
/auction/:id/draft    → DraftView.vue (coach + admin, role-conditional)
```

---

## To Run a Full Draft (deployment checklist)

All UI and edge function code is written. Before running an end-to-end draft:

```bash
# 1. Apply all migrations (includes nullable roster_position_id fix)
supabase db reset
# or if Supabase is already running:
supabase migration up

# 2. Deploy edge functions
supabase functions deploy nominate-school
supabase functions deploy place-bid
supabase functions deploy pass-bid
supabase functions deploy complete-bid

# 3. Start dev server
npm run dev
```

**Flow to test:**
1. `/create` — create auction, set N teams, budget, roster positions
2. Each coach opens `/join` and joins with their name + picks a team slot
3. All coaches navigate to `/auction/:id/lobby`, toggle Draft Ready
4. Admin clicks START DRAFT → navigates to `/auction/:id/draft`
5. Current nominator sees NOMINATE NOW → picks a school from NominationGrid
6. Coaches bid (+$1/+$5/+$10 or custom), or pass
7. When all non-high-bidders pass → complete-bid fires → sting plays → winner assigns position
8. Repeat until all schools sold

---

## Biggest Risks

1. **Edge function race conditions** on bid placement — use `SELECT FOR UPDATE` on the auction row
2. **Realtime subscription timing** — client must re-sync full state on reconnect, not just listen for deltas
3. **Team slot claiming** on join — need to prevent two coaches claiming the same slot simultaneously (use a DB unique constraint on `team_id` in participants, or a transaction in the join edge function)
4. **Time** — Day 3 is very full. If slipping, cut the sting animation and nomination grid UI (use a simple dropdown instead) to protect the core bid loop.
