# Leagify Fantasy Auction - Development Tasks

## Overview

Phased implementation plan for rebuilding the auction system with Supabase + Vue 3. Each task includes success criteria, required tests (written first), and documentation to update.

**Principles:**
- Test-first: Write tests before implementation
- Local-first: All development against Supabase local
- Documentation included: Update docs in same commit as code
- AI UI Assistance: Use `UI-GENERATION-GUIDE.md` to rapidly scaffold layout and components via Google Stitch for the UI tasks.

---

## Phase 1: Foundation

**Goal:** Local development environment, database schema, basic project structure.

### Task 1.1: Project Setup

**Complexity:** Simple

**Description:**
Initialize Vue 3 project with Vite, configure Supabase local development, set up testing infrastructure.

**Success Criteria:**
- [ ] `npm run dev` starts Vue app at localhost:5173
- [ ] `supabase start` runs local Supabase stack
- [ ] `npm test` runs Vitest (even with no tests yet)
- [ ] `npm run test:e2e` runs Playwright (even with no tests yet)
- [ ] TypeScript configured with strict mode
- [ ] ESLint + Prettier configured
- [ ] Pre-commit hook runs tests

**Required Tests:**
- None (infrastructure only)

**Documentation:**
- [ ] Update README.md with setup instructions
- [ ] Create CONTRIBUTING.md with dev workflow

**Dependencies:** None

---

### Task 1.2: Database Schema

**Complexity:** Medium

**Description:**
Create all database tables, functions, indexes, and RLS policies as defined in DATABASE-SCHEMA.md.

**Success Criteria:**
- [ ] All tables created via migrations
- [ ] `calculate_max_bid()` function works
- [ ] `is_position_eligible()` function works
- [ ] RLS policies block cross-auction access
- [ ] Realtime enabled on required tables
- [ ] `supabase db reset` applies clean schema

**Required Tests (pgTAP):**
- [ ] `calculate_max_bid` returns correct values for all edge cases
- [ ] `is_position_eligible` handles flex and non-flex positions
- [ ] RLS blocks participant from viewing other auctions
- [ ] Constraints prevent negative budgets

**Documentation:**
- [ ] DATABASE-SCHEMA.md is source of truth (already written)

**Dependencies:** Task 1.1

---

### Task 1.3: Seed Data Script

**Complexity:** Simple

**Description:**
Create seed script for development/testing with realistic auction data.

**Success Criteria:**
- [ ] `npm run db:seed` populates test auction
- [ ] Creates auction with join code "TEST01"
- [ ] Creates 6 teams with $200 budget
- [ ] Creates ~50 schools across positions
- [ ] Creates 8 roster positions (SEC×2, Big Ten×2, ACC×1, Big 12×1, Flex×2)
- [ ] Creates system admin user

**Required Tests:**
- [ ] Seed script creates expected number of records
- [ ] Seeded auction is in valid state

**Documentation:**
- [ ] Document seed data in README.md

**Dependencies:** Task 1.2

---

## Phase 2: Authentication & Join Flow

**Goal:** Users can join auctions via code, sessions persist across refresh.

### Task 2.1: Join Page UI

**Complexity:** Simple

**Description:**
Create landing page with join code + display name form.

**Success Criteria:**
- [ ] Form validates join code (6 chars, alphanumeric)
- [ ] Form validates display name (2-20 chars)
- [ ] Error messages display clearly
- [ ] Responsive layout (desktop primary)

**Required Tests:**
- [ ] Component test: validation error shown for invalid code
- [ ] Component test: validation error shown for empty name
- [ ] Component test: form submits with valid input

**Documentation:**
- [ ] Screenshot in README.md

**Dependencies:** Task 1.1

---

### Task 2.2: Join API (Edge Function)

**Complexity:** Medium

**Description:**
Edge Function to handle join requests: validate code, create/retrieve participant, return session.

**Success Criteria:**
- [ ] Returns error if join code doesn't exist
- [ ] Returns error if name taken by connected user
- [ ] Creates new participant for new name
- [ ] Returns existing participant for reconnecting user
- [ ] Generates session token
- [ ] Returns participant data with role and team info

**Required Tests:**
- [ ] `join_invalidCode_returnsError`
- [ ] `join_nameTaken_returnsError`
- [ ] `join_newUser_createsParticipant`
- [ ] `join_returningUser_reconnects`
- [ ] `join_sameNameDifferentAuction_allowed`

**Documentation:**
- [ ] API documentation in code comments

**Dependencies:** Task 1.2, Task 2.1

---

### Task 2.3: Session Persistence

**Complexity:** Simple

**Description:**
Store session in localStorage, auto-rejoin on page load.

**Success Criteria:**
- [ ] Session stored in localStorage after join
- [ ] Page refresh auto-rejoins auction
- [ ] Invalid/expired session clears localStorage and shows join form
- [ ] Manual "Leave Auction" clears session

**Required Tests:**
- [ ] Unit test: session stored after successful join
- [ ] Unit test: auto-rejoin called on mount with stored session
- [ ] E2E test: refresh maintains session

**Documentation:**
- [ ] Session flow in PRODUCT-DESIGN.md (already documented)

**Dependencies:** Task 2.2

---

### Task 2.4: Connection Status Tracking

**Complexity:** Medium

**Description:**
Track participant connection status via Supabase Realtime presence.

**Success Criteria:**
- [ ] `is_connected` updates when user joins channel
- [ ] `is_connected` updates when user leaves/disconnects
- [ ] `last_seen_at` updates periodically (heartbeat)
- [ ] Other participants see connection status in real-time

**Required Tests:**
- [ ] Integration test: joining sets is_connected = true
- [ ] Integration test: leaving sets is_connected = false
- [ ] E2E test: connection status visible to other users

**Documentation:**
- [ ] Update PRODUCT-DESIGN.md with presence implementation details

**Dependencies:** Task 2.2

---

## Phase 3: Auction Setup

**Goal:** Auction Master can create and configure auctions.

### Task 3.1: Create Auction UI

**Complexity:** Simple

**Description:**
Form for creating new auction with name and default settings.

**Success Criteria:**
- [ ] Generates unique 6-character join code
- [ ] Sets default budget ($200)
- [ ] Creates auction in "draft" status
- [ ] Creator automatically joins as Auction Master
- [ ] Redirects to auction setup page

**Required Tests:**
- [ ] Component test: form validation
- [ ] Integration test: auction created in database
- [ ] Integration test: creator assigned auction_master role

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 2.2

---

### Task 3.2: CSV Import

**Complexity:** Complex

**Description:**
Upload CSV, parse, fuzzy match schools, preview, and import.

**Success Criteria:**
- [ ] Accepts CSV with required columns (School, LeagifyPosition, ProjectedPoints)
- [ ] Validates data (no duplicates, valid numbers)
- [ ] Fuzzy matches school names (70% threshold)
- [ ] Shows preview with match confidence
- [ ] User confirms before import
- [ ] Creates/updates school master records
- [ ] Creates auction_schools records

**Required Tests:**
- [ ] Unit test: CSV parsing extracts correct columns
- [ ] Unit test: fuzzy matching finds similar names
- [ ] Unit test: validation catches duplicate schools
- [ ] Unit test: validation catches invalid numbers
- [ ] Integration test: import creates correct records
- [ ] E2E test: full import flow with preview

**Documentation:**
- [ ] CSV format documented in PRODUCT-DESIGN.md (already done)

**Dependencies:** Task 3.1

---

### Task 3.3: Roster Configuration

**Complexity:** Medium

**Description:**
Configure roster positions (how many of each type per team).

**Success Criteria:**
- [ ] Default positions created from LeagifyPosition values in CSV
- [ ] Auction Master can adjust slots per team
- [ ] Auction Master can add Flex positions
- [ ] Validation prevents more positions than available schools
- [ ] Color picker for position visualization

**Required Tests:**
- [ ] Component test: slot count validation
- [ ] Integration test: positions saved to database
- [ ] Unit test: validation against school count

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 3.2

---

### Task 3.4: Team Setup

**Complexity:** Simple

**Description:**
Create teams, set budgets, assign nomination order.

**Success Criteria:**
- [ ] Create N teams (default 6)
- [ ] Set budget per team (default $200)
- [ ] Drag-and-drop nomination order
- [ ] Team names editable

**Required Tests:**
- [ ] Component test: team creation form
- [ ] Component test: drag-and-drop reorder
- [ ] Integration test: teams saved with correct order

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 3.1

---

### Task 3.5: Role Assignment

**Complexity:** Medium

**Description:**
Assign participants to teams and roles.

**Success Criteria:**
- [ ] List all joined participants
- [ ] Assign participant as Team Coach to a team
- [ ] Assign participant as Viewer (no team)
- [ ] Auction Master role is automatic for creator
- [ ] Show connection status of each participant

**Required Tests:**
- [ ] Component test: role dropdown options
- [ ] Integration test: role saved to database
- [ ] E2E test: participant sees updated role

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 2.4, Task 3.4

---

## Phase 4: Live Auction Core

**Goal:** Real-time bidding works end-to-end.

### Task 4.1: Auction Lobby UI

**Complexity:** Medium

**Description:**
Waiting area showing all participants, connection status, readiness.

**Success Criteria:**
- [ ] Shows all participants with connection status
- [ ] Shows role assignments
- [ ] Auction Master sees "Start Practice" / "Start Auction" buttons
- [ ] Non-masters see "waiting for auction to start" message
- [ ] Real-time updates as participants join/leave

**Required Tests:**
- [ ] Component test: participant list rendering
- [ ] Component test: button visibility by role
- [ ] E2E test: new participant appears in real-time

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 3.5

---

### Task 4.2: Practice Mode

**Complexity:** Medium

**Description:**
Pre-auction practice round using real schools (bids not saved).

**Success Criteria:**
- [ ] Auction Master can start practice mode
- [ ] Random school selected for practice bidding
- [ ] Users can place practice bids
- [ ] Practice bids marked with `is_practice = true`
- [ ] Connection test: users see their bids appear
- [ ] "Ready" toggle for each user
- [ ] Auction Master sees who has practiced
- [ ] "End Practice, Start Auction" clears practice data

**Required Tests:**
- [ ] Integration test: practice bids have is_practice flag
- [ ] Integration test: ending practice clears practice bids
- [ ] E2E test: practice bid visible to other users

**Documentation:**
- [ ] Update PRODUCT-DESIGN.md with practice mode details

**Dependencies:** Task 4.1

---

### Task 4.3: Nomination Flow

**Complexity:** Medium

**Description:**
Current nominator selects school, auto-bids $1.

**Success Criteria:**
- [ ] Shows whose turn to nominate
- [ ] Nominator sees school selection UI
- [ ] Non-nominators see "waiting for nomination" message
- [ ] Selecting school auto-places $1 bid
- [ ] School marked as unavailable
- [ ] Current bidding state updated in auction record

**Required Tests:**
- [ ] Integration test: nomination creates $1 bid
- [ ] Integration test: nomination updates auction state
- [ ] Integration test: school marked unavailable
- [ ] Integration test: non-nominator cannot nominate (RLS)
- [ ] E2E test: nomination visible to all users

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 4.2

---

### Task 4.4: Bidding UI

**Complexity:** Medium

**Description:**
Real-time bidding interface with quick-bid buttons and pass.

**Success Criteria:**
- [ ] Shows current school with stats
- [ ] Shows current high bid and bidder
- [ ] Shows user's max bid
- [ ] Quick-bid buttons (+$1, +$5, +$10, custom)
- [ ] Buttons disabled when bid would exceed max
- [ ] Pass button
- [ ] Shows bid status of all participants (waiting, passed, auto-passed)
- [ ] Real-time updates on new bids

**Required Tests:**
- [ ] Component test: buttons disabled at max bid
- [ ] Component test: auto-pass message shown
- [ ] Component test: bid status indicators

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 4.3

---

### Task 4.5: Place Bid (Edge Function)

**Complexity:** Complex

**Description:**
Server-side bid validation and placement.

**Success Criteria:**
- [ ] Validates bid > current high bid
- [ ] Validates bid <= user's max bid
- [ ] Validates auction is in_progress
- [ ] Validates user hasn't passed
- [ ] Updates auction.current_high_bid and current_high_bidder_id
- [ ] Creates bid_history record
- [ ] Returns updated auction state

**Required Tests:**
- [ ] `placeBid_belowCurrent_rejects`
- [ ] `placeBid_exceedsMax_rejects`
- [ ] `placeBid_auctionPaused_rejects`
- [ ] `placeBid_alreadyPassed_rejects`
- [ ] `placeBid_valid_updatesState`
- [ ] `placeBid_concurrent_highestWins` (race condition)

**Documentation:**
- [ ] API documentation in code comments

**Dependencies:** Task 1.2

---

### Task 4.6: Pass (Edge Function)

**Complexity:** Medium

**Description:**
Record user passing on current school, check if bidding should end.

**Success Criteria:**
- [ ] Records pass in bid_history
- [ ] Checks if all non-high-bidders have passed/auto-passed
- [ ] If yes, triggers bid completion
- [ ] Returns updated bidder status

**Required Tests:**
- [ ] `pass_recordsInHistory`
- [ ] `pass_allOthersPassed_endsBidding`
- [ ] `pass_concurrent_endsOnce` (race condition)

**Documentation:**
- [ ] API documentation in code comments

**Dependencies:** Task 4.5

---

### Task 4.7: Complete Bid (Edge Function)

**Complexity:** Complex

**Description:**
Handle bid completion: update budgets, create draft pick, advance turn.

**Success Criteria:**
- [ ] Deducts winning bid from team's remaining_budget
- [ ] Creates draft_pick record (pending position assignment)
- [ ] Marks school as unavailable
- [ ] Auto-assigns to most restrictive valid position
- [ ] Winner can override position assignment
- [ ] Advances nomination to next eligible user
- [ ] Skips users with full roster or $0 budget
- [ ] Ends auction if all rosters full

**Required Tests:**
- [ ] `completeBid_deductsBudget`
- [ ] `completeBid_createsPickRecord`
- [ ] `completeBid_marksSchoolUnavailable`
- [ ] `completeBid_autoAssignsPosition`
- [ ] `completeBid_advancesNominator`
- [ ] `completeBid_skipsFullRoster`
- [ ] `completeBid_endsWhenComplete`

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 4.6

---

### Task 4.8: Position Assignment UI

**Complexity:** Simple

**Description:**
After winning bid, show position assignment with auto-suggestion.

**Success Criteria:**
- [ ] Shows won school
- [ ] Suggests most restrictive valid position
- [ ] User can select different valid position
- [ ] Invalid positions disabled with explanation
- [ ] Confirm button saves assignment

**Required Tests:**
- [ ] Component test: auto-suggestion is most restrictive
- [ ] Component test: invalid positions disabled
- [ ] Integration test: assignment saved

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 4.7

---

## Phase 5: Auction Master Controls

**Goal:** Auction Master can manage auction, bid for absent teams, handle edge cases.

### Task 5.1: Auction Controls

**Complexity:** Simple

**Description:**
Start, pause, resume, end auction buttons.

**Success Criteria:**
- [ ] Start transitions draft → in_progress
- [ ] Pause transitions in_progress → paused
- [ ] Resume transitions paused → in_progress
- [ ] End transitions any → completed
- [ ] End requires confirmation
- [ ] All users see status change in real-time

**Required Tests:**
- [ ] Integration test: status transitions
- [ ] E2E test: status change visible to all

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 4.1

---

### Task 5.2: Force End Bidding

**Complexity:** Simple

**Description:**
Auction Master can end current bidding early.

**Success Criteria:**
- [ ] "End Bidding" button visible only to Auction Master
- [ ] Triggers same completion flow as all-pass
- [ ] Logs action in admin_actions

**Required Tests:**
- [ ] Integration test: force end completes bid
- [ ] Integration test: admin action logged

**Documentation:**
- [ ] None (existing docs cover this)

**Dependencies:** Task 4.7

---

### Task 5.3: Bid for Absent Team

**Complexity:** Medium

**Description:**
Auction Master can place bids on behalf of teams whose coach is absent.

**Success Criteria:**
- [ ] Dropdown to select "Bid as: [Team Name]"
- [ ] Toggle switch to enable "Auto-Pass" for the selected team
- [ ] Bids placed use selected team's budget/maxBid
- [ ] Bid history records on_behalf_of_team_id
- [ ] UI shows "Ross (as: Jordan's Team)" when proxy bidding
- [ ] Nominations work same way

**Required Tests:**
- [ ] Integration test: proxy bid uses correct team budget
- [ ] Integration test: bid history tracks on_behalf_of
- [ ] E2E test: proxy bid visible to all users

**Documentation:**
- [ ] Update PRODUCT-DESIGN.md with proxy bidding details

**Dependencies:** Task 4.5

---

### Task 5.4: Override Assignment

**Complexity:** Simple

**Description:**
Auction Master can reassign schools to different positions after the fact.

**Success Criteria:**
- [ ] Edit button on draft picks
- [ ] Can change roster position (within eligibility)
- [ ] Logs action in admin_actions

**Required Tests:**
- [ ] Integration test: reassignment saves
- [ ] Integration test: invalid reassignment rejected

**Documentation:**
- [ ] None

**Dependencies:** Task 4.8

---

## Phase 6: Views & Export

**Goal:** Rosters, results, and data export.

### Task 6.1: Roster View

**Complexity:** Medium

**Description:**
Display team rosters with position slots and assigned schools.

**Success Criteria:**
- [ ] Shows all teams side-by-side (or tabs on mobile)
- [ ] Shows position slots with color coding
- [ ] Shows assigned school with projected points
- [ ] Shows remaining budget
- [ ] Empty slots show "Empty"
- [ ] Real-time updates as picks happen

**Required Tests:**
- [ ] Component test: roster renders correctly
- [ ] Component test: empty slots shown
- [ ] E2E test: pick appears in roster

**Documentation:**
- [ ] None

**Dependencies:** Task 4.7

---

### Task 6.2: Bid History View

**Complexity:** Simple

**Description:**
Scrolling log of all bids during auction.

**Success Criteria:**
- [ ] Shows all bids in chronological order
- [ ] Shows bid type (nomination, bid, pass)
- [ ] Shows bidder and amount
- [ ] Highlights winning bids
- [ ] Auto-scrolls to latest

**Required Tests:**
- [ ] Component test: bid types rendered correctly

**Documentation:**
- [ ] None

**Dependencies:** Task 4.5

---

### Task 6.3: Results Export

**Complexity:** Simple

**Description:**
Export final results as CSV.

**Success Criteria:**
- [ ] Export button available to all participants
- [ ] CSV format: Owner, Player, Position, Bid, ProjectedPoints
- [ ] File named with auction name and date

**Required Tests:**
- [ ] Unit test: CSV generation
- [ ] E2E test: download works

**Documentation:**
- [ ] Export format in PRODUCT-DESIGN.md (already documented)

**Dependencies:** Task 4.7

---

## Phase 7: Admin Interface

**Goal:** System admin can manage auctions and clean up data.

### Task 7.1: System Admin Dashboard

**Complexity:** Medium

**Description:**
Admin interface for system-wide auction management.

**Success Criteria:**
- [ ] List all auctions with status, date, participant count
- [ ] Filter by status
- [ ] Delete test auctions
- [ ] Archive completed auctions
- [ ] View any auction (impersonate)
- [ ] Only accessible to system admin (is_system_admin flag)

**Required Tests:**
- [ ] Integration test: only system admin can access
- [ ] Integration test: delete removes auction and children
- [ ] E2E test: admin dashboard loads

**Documentation:**
- [ ] Admin access in PRODUCT-DESIGN.md (already documented)

**Dependencies:** Task 1.2

---

### Task 7.2: School Management

**Complexity:** Simple

**Description:**
CRUD for master school data.

**Success Criteria:**
- [ ] List all schools
- [ ] Add new school
- [ ] Edit school name/logo
- [ ] Test logo URL loading
- [ ] Cannot delete schools used in auctions

**Required Tests:**
- [ ] Integration test: delete fails if school in use

**Documentation:**
- [ ] None

**Dependencies:** Task 7.1

---

## Phase 8: Polish & Edge Cases

**Goal:** Handle remaining edge cases, improve UX.

### Task 8.1: Reconnection Handling

**Complexity:** Medium

**Description:**
Graceful handling of disconnects and reconnects.

**Success Criteria:**
- [ ] Client detects disconnect
- [ ] Shows "reconnecting..." overlay
- [ ] Auto-reconnects within 30 seconds
- [ ] Syncs missed state on reconnect
- [ ] If reconnect fails, shows "connection lost" with rejoin button

**Required Tests:**
- [ ] E2E test: disconnect and reconnect
- [ ] E2E test: state sync after reconnect

**Documentation:**
- [ ] Update PRODUCT-DESIGN.md with reconnection details

**Dependencies:** Task 2.4

---

### Task 8.2: Error Handling

**Complexity:** Simple

**Description:**
Consistent error display throughout app.

**Success Criteria:**
- [ ] Toast notifications for transient errors
- [ ] Inline errors for form validation
- [ ] Error boundary for component crashes
- [ ] Clear error messages (not technical jargon)

**Required Tests:**
- [ ] Component tests for error states

**Documentation:**
- [ ] Error codes in PRODUCT-DESIGN.md (already documented)

**Dependencies:** All previous tasks

---

### Task 8.3: Mobile Responsiveness

**Complexity:** Medium

**Description:**
Make UI usable on tablets (mobile is secondary).

**Success Criteria:**
- [ ] Roster view works on tablet
- [ ] Bidding controls accessible on smaller screens
- [ ] No horizontal scroll on common tablet sizes

**Required Tests:**
- [ ] Visual regression tests at tablet breakpoints

**Documentation:**
- [ ] None

**Dependencies:** Task 6.1

---

### Task 8.4: Performance Optimization

**Complexity:** Medium

**Description:**
Ensure smooth performance with full auction.

**Success Criteria:**
- [ ] Initial load < 2 seconds
- [ ] Bid updates appear < 500ms
- [ ] No memory leaks during long auction
- [ ] Bundle size < 200KB gzipped

**Required Tests:**
- [ ] Lighthouse performance audit
- [ ] Load testing with simulated users

**Documentation:**
- [ ] None

**Dependencies:** All previous tasks

---

## Task Dependencies Graph

```
Phase 1 (Foundation)
├── 1.1 Project Setup
├── 1.2 Database Schema (depends: 1.1)
└── 1.3 Seed Data (depends: 1.2)

Phase 2 (Auth & Join)
├── 2.1 Join Page UI (depends: 1.1)
├── 2.2 Join API (depends: 1.2, 2.1)
├── 2.3 Session Persistence (depends: 2.2)
└── 2.4 Connection Status (depends: 2.2)

Phase 3 (Auction Setup)
├── 3.1 Create Auction UI (depends: 2.2)
├── 3.2 CSV Import (depends: 3.1)
├── 3.3 Roster Configuration (depends: 3.2)
├── 3.4 Team Setup (depends: 3.1)
└── 3.5 Role Assignment (depends: 2.4, 3.4)

Phase 4 (Live Auction)
├── 4.1 Auction Lobby (depends: 3.5)
├── 4.2 Practice Mode (depends: 4.1)
├── 4.3 Nomination Flow (depends: 4.2)
├── 4.4 Bidding UI (depends: 4.3)
├── 4.5 Place Bid API (depends: 1.2)
├── 4.6 Pass API (depends: 4.5)
├── 4.7 Complete Bid API (depends: 4.6)
└── 4.8 Position Assignment (depends: 4.7)

Phase 5 (Auction Master)
├── 5.1 Auction Controls (depends: 4.1)
├── 5.2 Force End Bidding (depends: 4.7)
├── 5.3 Bid for Absent Team (depends: 4.5)
└── 5.4 Override Assignment (depends: 4.8)

Phase 6 (Views & Export)
├── 6.1 Roster View (depends: 4.7)
├── 6.2 Bid History View (depends: 4.5)
└── 6.3 Results Export (depends: 4.7)

Phase 7 (Admin)
├── 7.1 System Admin Dashboard (depends: 1.2)
└── 7.2 School Management (depends: 7.1)

Phase 8 (Polish)
├── 8.1 Reconnection Handling (depends: 2.4)
├── 8.2 Error Handling (depends: all)
├── 8.3 Mobile Responsiveness (depends: 6.1)
└── 8.4 Performance Optimization (depends: all)
```

---

## Complexity Summary

| Complexity | Count | Tasks |
|------------|-------|-------|
| Simple | 15 | 1.1, 1.3, 2.1, 2.3, 3.1, 3.4, 4.8, 5.1, 5.2, 5.4, 6.2, 6.3, 7.2, 8.2 |
| Medium | 14 | 1.2, 2.2, 2.4, 3.3, 3.5, 4.1, 4.2, 4.3, 4.4, 4.6, 5.3, 8.1, 8.3, 8.4 |
| Complex | 3 | 3.2, 4.5, 4.7 |

---

## Milestone Checkpoints

### Milestone 1: "Hello Auction" (End of Phase 2)
- User can join auction via code
- Session persists across refresh
- Connection status visible

### Milestone 2: "Ready to Draft" (End of Phase 3)
- Auction can be created and configured
- CSV import works
- Teams and positions set up

### Milestone 3: "First Bid" (End of Phase 4)
- Complete bidding loop works
- Real-time updates visible to all
- Picks assigned to positions

### Milestone 4: "Auction Master" (End of Phase 5)
- Full Auction Master controls
- Can bid for absent teams
- Can override assignments

### Milestone 5: "Production Ready" (End of Phase 8)
- All features complete
- Error handling robust
- Performance acceptable
