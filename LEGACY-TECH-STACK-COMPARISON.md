# Tech Stack Comparison for Real-Time Auction App

## Overview

This document compares alternative tech stacks for rebuilding the Leagify Fantasy Auction system, moving away from the Azure-centric stack (Blazor WASM + Azure Functions + Azure SignalR + Azure SQL) due to free tier limitations.

**Key Requirements:**
- Real-time bidding updates to 6-20 concurrent users
- Relational data model (auctions, teams, users, schools, bids)
- Budget-friendly hosting (ideally functional on free tier)
- Reasonable development speed (1 week timeline)

---

## Option 1: Supabase + React/Vue/Svelte

**Recommended for: Fastest development, best free tier, relational data**

### Architecture
```
Frontend (Vercel/Netlify)
    ↓
Supabase
├── PostgreSQL (relational database)
├── Realtime (change subscriptions via Phoenix Channels)
├── Auth (optional - could keep join code system)
└── Edge Functions (complex validation if needed)
```

### Real-Time Mechanism
Database change subscriptions - when a row changes, all subscribed clients get notified automatically.

```javascript
// Subscribe to bid updates for an auction
supabase
  .channel('auction-123')
  .on('postgres_changes',
    { event: 'UPDATE', schema: 'public', table: 'auctions', filter: 'id=eq.123' },
    (payload) => updateBidDisplay(payload.new)
  )
  .subscribe()
```

### Data Model Fit
**Excellent** - Your existing relational schema maps almost 1:1:
- All 12 entities translate directly
- Foreign keys, constraints, indexes all work
- Full SQL for complex queries (joins, aggregations)
- Row-level security for multi-tenancy

### Free Tier
| Resource | Limit |
|----------|-------|
| Database | 500 MB |
| Bandwidth | 5 GB |
| Monthly Active Users | 50,000 |
| Realtime Messages | Included |
| Edge Function Invocations | 500K |

**Assessment:** Genuinely usable for development and small production workloads.

### Pros
- Relational database matches existing data model perfectly
- Real-time built-in with no extra service
- PostgreSQL - portable, not locked in
- Open source - can self-host if needed
- Generous free tier
- Good documentation, AI tools know it well

### Cons
- Less control over real-time logic than raw WebSockets
- Dependent on Supabase infrastructure (mitigated by self-host option)
- Newer than Firebase (less training data for AI tools, though still well-known)

### Hosting Options
- **Frontend:** Vercel, Netlify (both free tier)
- **Backend:** Supabase handles everything

---

## Option 2: Firebase/Firestore + React/Vue

**Recommended for: Google ecosystem, simpler setup, NoSQL comfort**

### Architecture
```
Frontend (Firebase Hosting)
    ↓
Firebase
├── Firestore (NoSQL document database)
├── Realtime Database (alternative, older)
├── Auth (built-in)
└── Cloud Functions (server-side logic)
```

### Real-Time Mechanism
Document listeners - subscribe to documents/collections and receive updates automatically.

```javascript
// Subscribe to auction state changes
onSnapshot(doc(db, 'auctions', auctionId), (doc) => {
  updateBidDisplay(doc.data().currentBid)
})
```

### Data Model Fit
**Requires Restructuring** - Your relational model needs denormalization:

```javascript
// Relational (Supabase/PostgreSQL):
SELECT schools.name, auction_schools.projected_points
FROM auction_schools
JOIN schools ON auction_schools.school_id = schools.id
WHERE auction_id = 123

// NoSQL (Firestore) - must denormalize:
// Each auction_school document must contain school name, logo, etc.
// Updates to school info require updating ALL references
```

**Denormalization Pain Points:**
- School logo update requires updating every auction_schools document
- Team names duplicated in multiple places
- Complex queries (e.g., "SEC schools not drafted") are limited

### Free Tier
| Resource | Limit |
|----------|-------|
| Firestore Storage | 1 GB |
| Firestore Reads | 50,000/day |
| Firestore Writes | 20,000/day |
| Firestore Deletes | 20,000/day |
| Hosting | 10 GB/month |
| Cloud Functions | 2M invocations/month |

**Assessment:** Watch the daily read/write limits - auctions with frequent updates could hit limits.

### Pros
- Mature platform (since 2012)
- Excellent documentation
- Google AI tools have extensive Firebase knowledge
- Simple real-time listener syntax
- Auth system included
- Single ecosystem - less integration work

### Cons
- **NoSQL doesn't fit relational data well** - significant restructuring needed
- Daily read/write limits (not monthly)
- High vendor lock-in - hard to migrate away
- Pricing unpredictable with heavy reads/writes
- No joins - multiple queries or denormalization required

### Hosting Options
- **Everything:** Firebase handles frontend, backend, database, hosting

---

## Option 3: Node.js + Socket.io + PostgreSQL

**Recommended for: Maximum control, self-hosting flexibility**

### Architecture
```
Frontend (Vercel/Netlify)
    ↓
Node.js API (Railway/Render/Fly.io)
├── Express/Fastify (REST API)
├── Socket.io (real-time WebSockets)
└── PostgreSQL (Neon/Supabase/Railway)
```

### Real-Time Mechanism
Direct WebSocket connections with rooms/namespaces.

```javascript
// Server
io.to(`auction-${auctionId}`).emit('bidPlaced', { amount, bidder })

// Client
socket.on('bidPlaced', (data) => updateBidDisplay(data))
```

### Data Model Fit
**Excellent** - Full PostgreSQL, same as existing schema.

### Free Tier (Combined)
| Service | Free Tier |
|---------|-----------|
| Render (API) | 750 hours/month |
| Railway (API) | $5 credits/month |
| Fly.io (API) | 3 shared VMs |
| Neon (DB) | 0.5 GB storage |
| Vercel (Frontend) | 100 GB bandwidth |

**Assessment:** Requires combining multiple services, but total is genuinely free for small apps.

### Pros
- Full control over WebSocket logic
- No vendor lock-in - standard tech
- Large ecosystem and community
- Easy to debug (you own the server)
- Can optimize for your specific use case

### Cons
- More code to write (WebSocket server, connection management)
- Must manage server yourself
- Multiple services to coordinate
- More deployment complexity

### Hosting Options
- **Frontend:** Vercel, Netlify
- **API:** Railway, Render, Fly.io
- **Database:** Neon, Supabase (just the DB), Railway

---

## Option 4: Phoenix LiveView (Elixir)

**Recommended for: Best real-time performance, if you know Elixir**

### Architecture
```
Phoenix Application (Fly.io)
├── LiveView (real-time UI without JS)
├── Phoenix Channels (WebSocket abstraction)
└── Ecto + PostgreSQL (database)
```

### Real-Time Mechanism
Server-rendered HTML pushed over WebSocket - no client-side JavaScript framework needed.

```elixir
# Server pushes UI updates directly
def handle_event("place_bid", %{"amount" => amount}, socket) do
  # Validate bid, update DB, broadcast to all
  {:noreply, assign(socket, :current_bid, amount)}
end
```

### Data Model Fit
**Excellent** - Ecto works with PostgreSQL, relational model preserved.

### Free Tier
| Service | Free Tier |
|---------|-----------|
| Fly.io | 3 shared VMs, 3GB storage |

**Assessment:** Fly.io is built on Elixir, excellent support.

### Pros
- **Best real-time performance** - handles thousands of connections efficiently
- Single codebase for UI and real-time logic
- No JavaScript framework to maintain
- Excellent for real-time applications (built for this)
- Fly.io has first-class Elixir support

### Cons
- **Learning curve** - Elixir is different from mainstream languages
- Smaller ecosystem than JavaScript
- Fewer developers familiar with it
- **Not recommended for 1-week timeline** unless you know Elixir

---

## Comparison Matrix

| Factor | Supabase + React | Firebase | Node.js + Socket.io | Phoenix LiveView |
|--------|-----------------|----------|--------------------|-----------------|
| **Data Model Fit** | Excellent (relational) | Poor (needs restructuring) | Excellent (relational) | Excellent (relational) |
| **Free Tier** | Generous (monthly) | Limited (daily) | Adequate (combined) | Good (Fly.io) |
| **Development Speed** | Fast | Fast | Medium | Slow (if learning) |
| **Vendor Lock-in** | Low (open source) | High | None | None |
| **Real-time Simplicity** | Simple (DB subscriptions) | Simple (doc listeners) | Medium (manual) | Simple (built-in) |
| **AI Tool Familiarity** | Good | Excellent | Excellent | Limited |
| **Query Flexibility** | Full SQL | Limited | Full SQL | Full SQL |
| **Learning Curve** | Low | Low | Low | High |

---

## Recommendation

### For Your Situation (1-week timeline, Azure fatigue)

**Go with Supabase + React/Vue**

Reasons:
1. **Data model translates directly** - no restructuring needed
2. **Generous free tier** - won't hit limits during development or small production
3. **Real-time built-in** - database subscriptions handle bidding updates
4. **Not locked in** - PostgreSQL is portable, can self-host Supabase
5. **Good AI tool support** - well-documented, LLMs know it
6. **Fast development** - less code than Socket.io, less restructuring than Firebase

### Migration Strategy

1. **Create new repository** for Supabase project
2. **Give LLMs access to existing documentation:**
   - LEGACY-DATABASE-ERD.md (data model)
   - PRODUCT-DESIGN.md (business logic)
   - LESSONS-LEARNED.md (avoid past mistakes)
3. **Port schema to Supabase** (nearly 1:1 translation)
4. **Implement real-time subscriptions** for bidding
5. **Build UI with React/Vue** (simpler than Blazor)

### If Firebase Is Preferred (Google AI tools)

Consider Firebase only if:
- You're very comfortable with NoSQL
- You're willing to denormalize heavily
- You'll closely monitor daily read/write limits
- You accept the vendor lock-in

---

## Quick Reference: Supabase Schema Translation

```sql
-- Existing (Azure SQL)
CREATE TABLE Auction (
    AuctionId INT IDENTITY PRIMARY KEY,
    JoinCode NVARCHAR(10) UNIQUE,
    Status NVARCHAR(20),
    CurrentHighBid DECIMAL(10,2)
);

-- Supabase (PostgreSQL) - nearly identical
CREATE TABLE auctions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    join_code TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'draft',
    current_high_bid DECIMAL(10,2)
);

-- Real-time subscription
supabase
  .channel('bids')
  .on('postgres_changes',
    { event: 'UPDATE', schema: 'public', table: 'auctions' },
    handleBidUpdate
  )
  .subscribe()
```

The translation is straightforward - snake_case instead of PascalCase, `BIGINT` instead of `INT`, `TEXT` instead of `NVARCHAR`. All relationships and constraints work the same.
