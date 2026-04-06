# Stitches UI Mockups — Overview & Implementation Guide

This document catalogs the Google Stitch mockup files in this folder and maps them to the development phases defined in `DEVELOPMENT-TASKS.md`.

---

## What's in This Folder

Each mockup screen is a self-contained folder containing:
- **`code.html`** — A fully-rendered, static HTML file using Tailwind CSS (CDN), Space Grotesk + Inter fonts (Google Fonts), and Material Symbols. These files can be opened directly in a browser.
- **`screen.png`** — A screenshot of the rendered output, useful for quick visual reference without opening HTML.

Top-level documents:
- **`gridiron_prime/DESIGN.md`** — The canonical design system spec ("The Broadcast Prime Directive"). **Read this first before building any UI component.** It defines the color palette, typography rules, surface hierarchy, component patterns, and explicit do's/don'ts.
- **`mvpDesignPackage.md`** / **`mvpFinalDesignPackage.md`** — Two versions of the MVP screen inventory. The "Final" version is the most current. References use `{{DATA:SCREEN:SCREEN_N}}` placeholders which correspond to the screens below.
- **`leagify_mvp_design_prd.html`** / **`leagify_final_mvp_design_package.html`** — HTML versions of the design PRD documents.

---

## Screen Inventory

### Entry & Authentication (Phase 2)

| Folder | Description | Phase Task |
|--------|-------------|------------|
| `join_auction_tanookizoot_updated` | Clean entry screen — join code field + display name. "TANOOKIZOOT" is the example join code. Alphanumeric, no dashes. | Task 2.1 |

**Key UI details:** Single-column centered layout, `surface-container-lowest` background, metallic primary gradient on the submit button. Includes validation state markup.

---

### Auction Lobby (Phases 4.1 & 4.2)

Practice bidding is **not a separate screen** — it lives directly inside the lobby. Both views are single-page layouts that coaches stay on from the moment they join until the admin fires the draft.

| Folder | Description | Phase Task |
|--------|-------------|------------|
| `auction_lobby_coach_view` | 12-column layout. Left (5 cols): "Staff Readiness" — scrollable list of coaches, each with a Tech Check dot (green/red) and a Draft Ready checkbox. Right (7 cols): "Practice Bidding Zone" — full bidding UI with the current practice school (Michigan shown), Your Budget, Current High Bid, +$1/+$5/+$10 buttons, SUBMIT BID, and Pass/Fold. Footer ticker at bottom. | Tasks 4.1, 4.2 |
| `auction_lobby_admin_view_refined` | Same left readiness list (4 cols) but shows "ADMIN MODE" badge in header and "Operational Manifest" label. Right (8 cols): "Draft Management Console" — shows the nominated school as a hero card with stadium photo, conference/projected value/history stats, then a "Practice Bidding Zone" sub-panel with admin-only controls: Force +$1, Force +$5, Clear Bid, Reset Most Recent Bid, Reset All Bids, last bid log with progress bar. Below that: "Global Action Center" with current readiness status ("Awaiting Coach Smart"), the START DRAFT button, and a "Skip Readiness Check (Admin Override)" escape hatch. Sidebar has Pause / Reset system override buttons. | Tasks 4.1, 4.2, 5.1 |

**Key UI details:**
- Fixed header (64px) + fixed left sidebar (256px). Main content is `h-[calc(100vh-104px)] overflow-hidden` — no scroll on the page itself, only within panels.
- Coach readiness cards: `border-l-4 border-primary` = fully ready, `border-l-4 border-surface-variant` = connected but not ready, `border-l-4 border-error` = tech check failed (red dot).
- The two status indicators per coach are independent: **Tech Check** (green/red dot = connection quality) and **Draft Ready** (filled/empty checkbox = coach self-declared ready).
- Practice bids in the lobby are the same bidding controls as the live war room — the coach sees identical UI, making it a genuine dry run.
- The admin's practice panel has destructive controls (Clear Bid, Reset All) not available to coaches — these are for resetting the practice state before starting the real draft.
- START DRAFT button is gated: it shows the name of any coach who hasn't passed both checks. The override link bypasses this.

---

### Live Auction — The War Room (Phase 4)

| Folder | Description | Phase Task |
|--------|-------------|------------|
| `live_bidding_console_refined_admin_budget` | Core bidding console. 12-column grid: left sidebar shows participant status + budget summary, main area shows current school on the block with bid buttons (+$1, +$5, +$10, Custom). Admin budget panel visible. | Task 4.4 |
| `live_bidding_console_admin_toggle_mode` | Same as above but with "Admin Mode" toggle active. When admin mode is on, a secondary panel appears for "Bid on Behalf Of" team selection. CSS class `admin-mode-active` on `<body>` controls layout shift (main column goes from `col-span-12` to `col-span-8`). | Task 5.3 |
| `live_bidding_the_pick_is_in_sting` | Full-screen overlay that fires when a bid is won. Animated broadcast-style card with `sting-in` keyframe animation, school logo, winner name, and winning price in gold (`tertiary`). | Task 4.7 |
| `on_the_clock_alert_required_action` | Alert overlay/modal prompting the current nominator to act. Shows a countdown-style UI with "NOMINATE NOW" CTA. | Task 4.3 |
| `out_of_budget_auto_pass_state` | State shown when a coach's max bid is ≤ current high bid. Bid buttons are replaced with an "AUTO-PASSED" indicator. | Task 4.4 |
| `connection_lost_clean_code` | Full-screen "Signal Interrupted" overlay. Thematic broadcast-static aesthetic. Includes a "Reconnect" button. | Task 8.1 |

---

### School Nomination & Assignment (Phase 4)

| Folder | Description | Phase Task |
|--------|-------------|------------|
| `school_nomination_grid_data_rich_with_small_school_tab` | School selection catalog. Data-rich table view with conference filter tabs, projected points, SVG icon placeholders, and a "Small School" tab. "Nominate" button on each row. | Task 4.3 |
| `position_assignment_modal` | Modal overlay on top of a dimmed bidding console. Congratulatory header, large school logo area, and radio group for roster slot selection. Most-restrictive position is pre-selected ("Recommended" label). | Task 4.8 |

---

### Admin & System Management (Phases 3, 5, 7)

| Folder | Description | Phase Task |
|--------|-------------|------------|
| `create_new_auction` | Setup wizard form. Auction name, join code (auto-generated, copyable), budget ($200 default), max teams (6 default). Clean two-column form layout. | Task 3.1 |
| `auction_command_center_central_overrides` | Admin master control panel for a live auction. Override controls: force-end bidding, pause, reassign picks, toggle auto-pass per team. | Task 5.1, 5.2, 5.4 |
| `system_admin_auction_registry` | System-level admin dashboard. Table of all auctions with status badges, participant counts, and action buttons (View, Archive, Delete). | Task 7.1 |
| `maintain_schools` | School database CRUD. Table with school name, conference, position, projected points, logo URL, and edit/delete actions. | Task 7.2 |
| `auction_rules_protocol_refined` | Read-only reference guide for players. Scannable layout with scoring rules, roster slot explanation, and bidding protocol. | Phase 8 / informational |

---

### Post-Auction Views (Phase 6)

| Folder | Description | Phase Task |
|--------|-------------|------------|
| `post_auction_projections_standings` | Final broadcast-style leaderboard. Ranks coaches by projected total points. Each row shows team name, schools won, and projected score. | Task 6.1 |
| `final_squad_recap_multi_team_view` | Side-by-side roster comparison across all teams. Each team column shows its 8 slots with school name, position badge, price paid, and projected points. | Task 6.1 |
| `official_draft_recap_log_highlights` | Chronological bid log. Each entry shows round, school, winning coach, price, and a "VALUE" / "REACH" highlight tag. | Task 6.2 |

---

## Design System Quick Reference

All screens share the **Gridiron Prime** design system. When porting HTML to Vue components, extract these patterns:

### Colors (Tailwind custom tokens)
```
Background stack (darkest → brightest):
  surface-container-lowest: #0a0e14   ← page background
  surface-container-low:    #181c22
  surface-container:        #1c2026   ← main panels
  surface-container-high:   #262a31
  surface-container-highest:#31353c   ← interactive cards

Accent colors:
  primary:   #adc6ff   ← blue, main interactive
  secondary: #ffb3b2   ← red/pink, alerts
  tertiary:  #e9c400   ← gold, championship moments
```

### Reusable CSS Utilities (defined in every screen's `<style>` block)
```css
.glass-panel      { background: rgba(28,32,38,0.6); backdrop-filter: blur(12px); outline: 1px solid rgba(67,71,78,0.15); }
.metallic-primary { background: linear-gradient(135deg, #adc6ff 0%, #3686ff 100%); }
.metallic-secondary { background: linear-gradient(135deg, #ffb3b2 0%, #bf012c 100%); }
.broadcast-skew   { transform: skewX(-10deg); }
```

These should become a shared `src/assets/gridiron.css` or Tailwind plugin.

### Typography
- Headlines / labels: `font-['Space_Grotesk']`, uppercase, `tracking-tighter`
- Body text: `font-['Inter']`
- Secondary text color: `text-on-surface-variant` (#c4c6cf)
- Gold data labels (bid amounts, key stats): `text-tertiary`

### Layout Shell
Every screen uses the same shell:
- Fixed header: `h-16`, `bg-[#0a0e14]`, "DRAFT COMMAND" branding
- Fixed left sidebar: `w-64`, WAR ROOM / MARKET / ROSTERS nav
- Main content: `ml-64 mt-16`, grid-based

This shell is a strong candidate for a `AppShell.vue` layout component built early.

---

## How the Mockups Map to Implementation Phases

### Phase 2 — Authentication & Join (Tasks 2.1–2.4)
`join_auction_tanookizoot_updated` is the complete reference for the join page. The form structure, validation states, and button styles are all present. This screen is self-contained and can be implemented directly without the app shell.

### Phase 3 — Auction Setup (Tasks 3.1–3.5)
**Important:** `create_new_auction` is a single consolidated page, not a multi-step wizard. It covers Tasks 3.1, 3.2 (entry point), 3.3, and 3.4 all in one screen:
- Left column: Auction Name, Join Code (auto-generated read-only + copy button), Participant Limit (stepper, default 6), Total Budget (number input, default $200), and a school pool selector with two cards — "DEFAULT 2026 SET" and "UPLOAD CSV".
- Right column: "Roster Architecture" panel listing conference slots (e.g., BIG TEN ×2, SEC ×2, ACC ×1, BIG 12 ×1) each with an edit button for adjusting slot counts.

**CSV Upload flow:** Clicking "UPLOAD CSV" on the create auction screen navigates to `maintain_schools`, which doubles as the import and verification screen (see that section above). After completing the upload and review there, the user returns to finish auction setup. `maintain_schools` has a prominent "BULK UPLOAD SCHOOLS" button and displays aggregate stats (total institutions, projected points captured, unassigned logos) — it is designed for both post-import review and ongoing school database management.

**Team slots & role assignment (Tasks 3.4, 3.5):** Team slots are pre-created numbered placeholders (Team 1–6) during setup. No names are set at creation time — this prevents coaches from claiming someone else's named slot for fun.

When a coach joins via the join code, the join screen shows the available unclaimed slots. The coach picks one and their display name becomes that team's name. First come, first served.

The auction owner (creator) automatically receives a team as part of creation — they do not need to join a second time via the join code.

**Absent player (MVP workaround):** The owner opens a private/incognito browser window, navigates to the join page, and joins as the absent person, claiming their placeholder slot. This reuses the standard join flow with no additional code. During the draft, the owner uses the "Bid on Behalf Of" admin toggle in the bidding console to proxy-bid for that team.

### Phase 4 — Live Auction Core (Tasks 4.1–4.8)
This is the most heavily mocked phase:
- `auction_lobby_coach_view` + `auction_lobby_admin_view_refined` → Tasks 4.1 **and 4.2** (practice bidding is embedded in the lobby, not a separate route)
- `school_nomination_grid_data_rich_with_small_school_tab` → Task 4.3
- `live_bidding_console_refined_admin_budget` → Task 4.4
- `out_of_budget_auto_pass_state` → Task 4.4 edge case
- `live_bidding_the_pick_is_in_sting` → Task 4.7 completion moment
- `position_assignment_modal` → Task 4.8
- `on_the_clock_alert_required_action` → Task 4.3 ("your turn" prompt)

The bidding console HTML is the most complex screen (~500 lines). It contains the admin mode CSS toggle logic which directly informs how Task 5.3 (bid for absent team) should be implemented.

### Phase 5 — Auction Master Controls (Tasks 5.1–5.4)
- `auction_command_center_central_overrides` → Tasks 5.1, 5.2, 5.4
- `live_bidding_console_admin_toggle_mode` → Task 5.3 (the admin mode panel shows the "Bid as" team dropdown in context)

### Phase 6 — Views & Export (Tasks 6.1–6.3)
- `final_squad_recap_multi_team_view` + `post_auction_projections_standings` → Task 6.1
- `official_draft_recap_log_highlights` → Task 6.2
- No export UI mockup was provided for Task 6.3.

### Phase 7 — Admin Interface (Tasks 7.1–7.2)
- `system_admin_auction_registry` → Task 7.1
- `maintain_schools` → Task 7.2

### Phase 8 — Polish (Tasks 8.1–8.3)
- `connection_lost_clean_code` → Task 8.1 (reconnection overlay)
- `auction_rules_protocol_refined` → informational panel, low priority

---

## Implementation Notes

1. **Start with the shared shell.** Build `AppShell.vue` (header + sidebar) and the Tailwind config extension first. Every other component plugs into it.

2. **The HTML files are your component specs.** When implementing a screen, open its `code.html` alongside the Vue file. The Tailwind classes can mostly be copied verbatim since the same config is used.

3. **Admin mode toggle is CSS-driven in the mockup.** The `live_bidding_console_admin_toggle_mode` screen uses a `body.admin-mode-active` class to show/hide elements and shift grid column spans. In Vue, this translates to a reactive boolean and `:class` bindings — no global body class needed.

4. **Images are placeholder URLs.** The `code.html` files reference `lh3.googleusercontent.com/aida-public/...` URLs for school logos and avatars. These are AI-generated placeholders. Real SVG school icons will be supplied via the `schools` table's logo URL field.

5. **Screens not covered by mockups:** Results export (Task 6.3) does not have a Stitch reference and will need to follow Gridiron Prime conventions from `DESIGN.md` without a pixel-perfect reference. CSV import, roster config, team setup, and role assignment are all handled by the `create_new_auction` + `maintain_schools` combination.

6. **Absent team / proxy bidding** is fully handled by the admin mode panel in `live_bidding_console_admin_toggle_mode`. The CSS class `admin-mode-active` on `<body>` controls the layout shift — in Vue this becomes a reactive boolean. The panel contains a "Bid on Behalf Of" team dropdown and a per-team auto-pass toggle, which covers both the absent-from-the-start and left-early scenarios.
