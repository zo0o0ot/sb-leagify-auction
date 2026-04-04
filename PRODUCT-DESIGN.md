# Leagify Fantasy Auction - Product Design Document

## Overview

A real-time auction draft web application for fantasy sports leagues. Users join via a simple code, bid on schools in real-time, and build their rosters within budget constraints. Built with Vue 3, Supabase, and deployed on Vercel.

## Technical Architecture

### Core Technologies
- **Frontend:** Vue 3 (Composition API) + Vite
- **UI Framework:** Tailwind CSS + Headless UI (lightweight, accessible)
- **Backend:** Supabase (PostgreSQL, Realtime, Edge Functions, Auth)
- **Hosting:** Vercel (frontend)
- **State Management:** Pinia (minimal, built for Vue 3)

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         VERCEL                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Vue 3 SPA                              │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │  │
│  │  │ Auction View│  │ Admin View  │  │ Roster View     │   │  │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘   │  │
│  │         │                │                   │            │  │
│  │         └────────────────┼───────────────────┘            │  │
│  │                          │                                │  │
│  │                   ┌──────▼──────┐                         │  │
│  │                   │ Pinia Store │                         │  │
│  │                   └──────┬──────┘                         │  │
│  └──────────────────────────┼───────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        SUPABASE                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  PostgreSQL │  │  Realtime   │  │    Edge Functions       │ │
│  │             │◄─┤ Subscriptions│  │                         │ │
│  │  - auctions │  │             │  │  - validate_bid()       │ │
│  │  - teams    │  │  Channels:  │  │  - complete_bid()       │ │
│  │  - bids     │  │  auction:123│  │  - advance_nomination() │ │
│  │  - schools  │  │             │  │                         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Row Level Security (RLS)                    │   │
│  │  - Users see only their auction's data                   │   │
│  │  - Bid validation enforced at DB level                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User joins auction** → Supabase creates session, stores in localStorage
2. **User subscribes to auction channel** → Receives real-time updates
3. **User places bid** → Edge Function validates, updates DB
4. **DB change triggers** → Supabase Realtime broadcasts to all subscribers
5. **All clients update** → Vue reactivity updates UI instantly

### Why This Stack

| Concern | Solution | Why |
|---------|----------|-----|
| Real-time | Supabase Realtime | Built-in, no separate service, generous free tier |
| Data model | PostgreSQL | Existing relational schema maps 1:1 |
| Validation | Edge Functions + RLS | Server-side enforcement, no client trust |
| State | Pinia | Minimal boilerplate, perfect for focused apps |
| Bundle size | Vue 3 + Vite | Tree-shaking, <100KB gzipped (vs 2MB Blazor) |
| Local dev | Supabase CLI | Full local stack via Docker |

---

## Authentication & Sessions

### Join Code Flow (No Signup Required)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Landing    │     │  Join Form  │     │  Auction    │
│  Page       │────▶│  Code+Name  │────▶│  Lobby      │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Supabase   │
                    │  Anonymous  │
                    │  Auth       │
                    └─────────────┘
```

1. **User enters**: 6-character join code + display name
2. **System checks**: Is this name already in this auction?
   - **Yes, connected**: Reject (name taken)
   - **Yes, disconnected**: Reconnect flow (same user returning)
   - **No**: Create new participant
3. **Supabase anonymous auth**: Creates session token
4. **Store in localStorage**: `{ auctionId, odisplayName, sessionToken, participantId }`
5. **On page refresh**: Auto-rejoin using stored credentials

### Session Persistence

```typescript
// On app mount
const stored = localStorage.getItem('auction_session')
if (stored) {
  const session = JSON.parse(stored)
  // Verify session still valid with Supabase
  const { data, error } = await supabase
    .from('participants')
    .select('*')
    .eq('id', session.participantId)
    .eq('session_token', session.sessionToken)
    .single()

  if (data) {
    // Auto-rejoin auction
    await joinAuctionChannel(session.auctionId)
  }
}
```

### Reconnection Handling

- **Browser refresh**: Auto-reconnects using localStorage session
- **Network drop**: Supabase Realtime auto-reconnects, client resyncs state
- **Tab close + reopen**: Uses same localStorage session
- **Different device**: Must re-enter join code + name (takes over session)

---

## User Roles & Permissions

### Role Hierarchy

| Role | Description | Scope |
|------|-------------|-------|
| **System Admin** | You - full access to everything | Global |
| **Auction Master** | Creates/runs auction, can override anything | Single auction |
| **Team Coach** | Owns a team, can nominate and bid | Single team |
| **Viewer** | Read-only access | Single auction |

### Permission Matrix

| Action | System Admin | Auction Master | Team Coach | Viewer |
|--------|:------------:|:--------------:|:----------:|:------:|
| Create auction | ✅ | ✅ | ❌ | ❌ |
| Delete any auction | ✅ | ❌ | ❌ | ❌ |
| Delete own auction | ✅ | ✅ | ❌ | ❌ |
| Upload CSV | ✅ | ✅ | ❌ | ❌ |
| Assign roles | ✅ | ✅ | ❌ | ❌ |
| Start/pause/end auction | ✅ | ✅ | ❌ | ❌ |
| Nominate school | ✅* | ✅* | ✅ | ❌ |
| Place bid | ✅* | ✅* | ✅ | ❌ |
| Bid for absent team | ✅ | ✅ | ❌ | ❌ |
| Override bid/assignment | ✅ | ✅ | ❌ | ❌ |
| View all data | ✅ | ✅ | ✅ | ✅ |
| Export results | ✅ | ✅ | ✅ | ✅ |

*When Auction Master also owns a team

### Handling Absent Participants

Instead of a complex Proxy Coach system:

1. **Before auction**: Auction Master assigns team to absent user's name
2. **During auction**: Auction Master uses "Bid for Team" dropdown to act on their behalf
3. **Auto-Pass Toggle**: The Auction Master can toggle an "Auto-Pass" setting for an absent team to automatically pass on their behalf unless manually overridden.
4. **UI clearly shows**: "Ross (bidding as: Jordan's Team)"
5. **All bids logged**: Audit trail shows who actually placed the bid

This is simpler than proxy roles and covers the real use case.

---

## Auction Flow

### States

```
┌─────────┐     ┌─────────┐     ┌──────────┐     ┌───────────┐
│  Draft  │────▶│ Practice│────▶│InProgress│────▶│ Completed │
└─────────┘     └─────────┘     └──────────┘     └───────────┘
     │               │               │
     │               │               ▼
     │               │          ┌─────────┐
     │               │          │ Paused  │
     │               │          └─────────┘
     │               │
     ▼               ▼
┌─────────────────────────┐
│       Archived          │
└─────────────────────────┘
```

| State | Description |
|-------|-------------|
| **Draft** | Setup phase - configure teams, upload schools, assign roles |
| **Practice** | Pre-auction testing - users verify connections, try bidding |
| **InProgress** | Live auction - real bidding happening |
| **Paused** | Temporary stop - Auction Master can pause/resume |
| **Completed** | All rosters filled or manually ended |
| **Archived** | Soft delete - hidden from normal views |

### Pre-Auction: Practice Mode

Instead of virtual "test schools", use real schools in a practice round:

1. Auction Master clicks "Start Practice"
2. System picks a random available school
3. Users can bid (bids are marked as practice, not saved)
4. Connection status shown: ✅ connected, ❌ disconnected
5. Auction Master sees who has participated
6. "End Practice, Start Auction" resets and begins real auction

Benefits:
- Tests real bidding flow, not a fake simulation
- No virtual school entities cluttering the schema
- Users practice with actual UI they'll use

### Live Auction Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    NOMINATION PHASE                         │
│                                                             │
│  Current Nominator: Ross (Team 1)                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Available Schools                          [Search] │   │
│  │ ┌─────────────────────────────────────────────────┐ │   │
│  │ │ Ohio State    │ Big Ten │ 225 pts │ [Nominate] │ │   │
│  │ │ Alabama       │ SEC     │ 204 pts │ [Nominate] │ │   │
│  │ │ Georgia       │ SEC     │ 198 pts │ [Nominate] │ │   │
│  │ └─────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Ross nominates Ohio State
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     BIDDING PHASE                           │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [Ohio State Logo]  OHIO STATE                       │   │
│  │ Big Ten | 225 projected points                      │   │
│  │                                                     │   │
│  │ Current Bid: $45 (Tilo)                            │   │
│  │ Your Max Bid: $72                                  │   │
│  │                                                     │   │
│  │ ┌────────┐  ┌────────┐  ┌────────┐  ┌──────────┐  │   │
│  │ │ +$1    │  │ +$5    │  │ +$10   │  │  Custom  │  │   │
│  │ └────────┘  └────────┘  └────────┘  └──────────┘  │   │
│  │                                                     │   │
│  │              ┌─────────────────┐                   │   │
│  │              │      PASS       │                   │   │
│  │              └─────────────────┘                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Bidder Status:                                            │
│  Ross: $1 (nominated) | Tilo: $45 ✓ | Sarah: waiting      │
│  Mike: passed | Jordan: auto-passed (max $40)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ All others pass/auto-pass
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   ASSIGNMENT PHASE                          │
│                                                             │
│  Tilo won Ohio State for $45!                              │
│                                                             │
│  Assign to position:                                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ○ Big Ten (1/2 slots filled) ← Recommended          │   │
│  │ ○ Flex (0/3 slots filled)                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│              ┌─────────────────────┐                       │
│              │  Confirm Assignment │                       │
│              └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Business Rules

**Nomination:**
- Round-robin order set before auction starts
- Nominator auto-bids $1 when nominating
- Skip users whose roster is full
- Skip users with $0 remaining budget

**Bidding:**
- **MaxBid = RemainingBudget - (EmptySlots - 1)**
- Must reserve $1 for each remaining roster slot
- Users can bid any amount up to MaxBid
- Bids must exceed current high bid
- Pass is explicit (no timer)

**Auto-Pass:**
- If user's MaxBid ≤ current high bid, they're automatically passed
- Shown in UI as "auto-passed (max $X)"

**Bid Completion:**
- Ends when all non-high-bidders have passed or auto-passed
- Auction Master can also force-end bidding

**Position Assignment:**
- Auto-suggest most restrictive valid position
- Non-flex: school's LeagifyPosition must match position name
- Flex: accepts any school
- User can override to any valid position

---

## Position Eligibility

### How It Works

Schools have a `leagify_position` (e.g., "SEC", "Big Ten", "ACC").
Roster positions have a `position_name` and `is_flex` flag.

```
School: Alabama
└── leagify_position: "SEC"

Roster Positions for Auction:
├── SEC (is_flex: false) ← Alabama can go here
├── Big Ten (is_flex: false) ← Alabama CANNOT go here
├── ACC (is_flex: false) ← Alabama CANNOT go here
└── Flex (is_flex: true) ← Alabama CAN go here (any school fits)
```

### Assignment Priority

When auto-assigning, prefer most restrictive valid position:

1. Check non-flex positions first (ordered by display_order)
2. If school's position matches and slot available → assign
3. If no match, check flex positions
4. First available flex slot → assign

This prevents wasting flex slots on schools that have dedicated positions.

---

## State Management

### Pinia Store Structure

```typescript
// stores/auction.ts
export const useAuctionStore = defineStore('auction', () => {
  // Core state
  const auction = ref<Auction | null>(null)
  const participants = ref<Participant[]>([])
  const teams = ref<Team[]>([])
  const schools = ref<AuctionSchool[]>([])
  const draftPicks = ref<DraftPick[]>([])

  // Derived state
  const currentPhase = computed(() => auction.value?.status)
  const currentNominator = computed(() => /* ... */)
  const currentHighBid = computed(() => /* ... */)
  const myTeam = computed(() => /* ... */)
  const myMaxBid = computed(() => /* ... */)
  const availableSchools = computed(() => schools.value.filter(s => s.is_available))

  // Actions (trigger Edge Functions)
  async function placeBid(amount: number) { /* ... */ }
  async function nominateSchool(schoolId: number) { /* ... */ }
  async function pass() { /* ... */ }

  return { /* ... */ }
})
```

### Realtime Subscriptions

```typescript
// composables/useAuctionRealtime.ts
export function useAuctionRealtime(auctionId: string) {
  const store = useAuctionStore()

  onMounted(() => {
    // Subscribe to auction state changes
    const channel = supabase
      .channel(`auction:${auctionId}`)
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'auctions', filter: `id=eq.${auctionId}` },
        (payload) => store.updateAuction(payload.new)
      )
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'bids', filter: `auction_id=eq.${auctionId}` },
        (payload) => store.handleBidUpdate(payload)
      )
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'draft_picks', filter: `auction_id=eq.${auctionId}` },
        (payload) => store.handleDraftPick(payload)
      )
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'participants', filter: `auction_id=eq.${auctionId}` },
        (payload) => store.handleParticipantUpdate(payload)
      )
      .subscribe()

    onUnmounted(() => {
      supabase.removeChannel(channel)
    })
  })
}
```

---

## Admin Interface

### Two-Tier Access

**System Admin (you):**
- Access via environment variable flag or specific user ID
- Can see all auctions across the system
- Can delete test data, archive old auctions
- Can impersonate Auction Master of any auction

**Auction Master:**
- Creator of an auction automatically becomes Auction Master
- Full control over their auction only
- Cannot see or affect other auctions

### Admin Routes

```
/admin                    # System admin dashboard (your access only)
  /admin/auctions         # List all auctions, cleanup tools
  /admin/schools          # Manage school master data

/auction/:id/manage       # Auction Master controls (per-auction)
  - Role assignments
  - Start/pause/end
  - Override bids
  - Bid for absent teams
```

### System Admin View

```
┌─────────────────────────────────────────────────────────────┐
│  System Administration                                      │
├─────────────────────────────────────────────────────────────┤
│  Auctions                                        [+ Create] │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Code   │ Name           │ Status    │ Teams │ Actions  ││
│  │────────┼────────────────┼───────────┼───────┼──────────││
│  │ ABC123 │ 2026 Draft     │ Completed │ 6     │ [Archive]││
│  │ XYZ789 │ Test Auction   │ Draft     │ 2     │ [Delete] ││
│  │ DEF456 │ Practice Run   │ InProgress│ 6     │ [View]   ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  Quick Actions:                                             │
│  [Delete all test auctions] [Archive completed auctions]   │
└─────────────────────────────────────────────────────────────┘
```

---

## CSV Import/Export

### Import Format (Schools)

```csv
School,Conference,ProjectedPoints,NumberOfProspects,SchoolURL,LeagifyPosition
Alabama,SEC,204,34,https://example.com/alabama.svg,SEC
Ohio State,Big Ten,225,28,https://example.com/osu.svg,Big Ten
Notre Dame,Independent,101,18,https://example.com/nd.svg,Flex
```

Required columns: School, LeagifyPosition, ProjectedPoints
Optional: Conference, NumberOfProspects, SchoolURL, SuggestedAuctionValue

### Import Process

1. Upload CSV file
2. Parse and validate (show errors with row numbers)
3. Fuzzy match school names to existing records (70% threshold)
4. Show match preview with confidence scores
5. User confirms matches or corrects
6. Create/update AuctionSchool records

### Export Format (Results)

```csv
Owner,Player,Position,Bid,ProjectedPoints
Ross,Ohio State,Big Ten,70,225
Tilo,Alabama,SEC,69,204
Sarah,Notre Dame,Flex,25,101
```

---

## Local Development

### Prerequisites

- Node.js 18+
- Docker Desktop
- Supabase CLI

### Setup

```bash
# Clone and install
git clone <repo>
cd sb-leagify-auction
npm install

# Start Supabase local
supabase start

# Run migrations
supabase db reset

# Seed test data
npm run db:seed

# Start dev server
npm run dev
```

### Local Services

| Service | URL | Purpose |
|---------|-----|---------|
| Vue App | http://localhost:5173 | Frontend |
| Supabase Studio | http://localhost:54323 | DB admin |
| Supabase API | http://localhost:54321 | Backend |
| Inbucket | http://localhost:54324 | Email testing |

### Test Data

Seed script creates:
- 1 auction with join code "TEST01"
- 6 teams with $200 budget each
- 50 schools across SEC, Big Ten, ACC, Flex positions
- 1 System Admin user

---

## Error Handling

### Client-Side

```typescript
// All Supabase calls wrapped in error handler
async function safeFetch<T>(fn: () => Promise<T>): Promise<T | null> {
  try {
    return await fn()
  } catch (error) {
    toast.error(getErrorMessage(error))
    console.error(error)
    return null
  }
}
```

### Server-Side (Edge Functions)

All Edge Functions return consistent error format:

```typescript
// Success
{ success: true, data: { ... } }

// Error
{ success: false, error: { code: 'BID_TOO_LOW', message: 'Bid must exceed $45' } }
```

### Error Codes

| Code | Meaning |
|------|---------|
| `BID_TOO_LOW` | Bid doesn't exceed current high bid |
| `BID_EXCEEDS_MAX` | Bid exceeds user's MaxBid |
| `NOT_YOUR_TURN` | User tried to nominate out of turn |
| `SCHOOL_UNAVAILABLE` | School already drafted |
| `INVALID_POSITION` | School can't go in that roster position |
| `AUCTION_NOT_ACTIVE` | Auction isn't in InProgress state |

---

## Security

### Row Level Security (RLS)

All tables have RLS policies enforcing:
- Users can only see data for auctions they're participating in
- Write operations validated against user's role
- Bid amounts validated server-side (Edge Functions)

### No Sensitive Data

- No passwords (anonymous auth + join codes)
- No PII beyond display names
- No payment information

### Validation Layers

1. **Client**: Disable invalid actions in UI
2. **Edge Function**: Validate business rules
3. **Database**: RLS policies + constraints

Client validation is for UX only - server is authoritative.
