# Leagify Fantasy Auction - Database Schema

## Overview

PostgreSQL schema for Supabase, translated from the original Azure SQL design. Uses snake_case naming convention, PostgreSQL-native types, and includes Row Level Security (RLS) policies for multi-tenancy.

## Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   schools   │       │    auctions     │       │     users       │
│─────────────│       │─────────────────│       │─────────────────│
│ id (PK)     │       │ id (PK)         │       │ id (PK)         │
│ name        │       │ join_code       │◄──────│ supabase_uid    │
│ logo_url    │       │ name            │       │ is_system_admin │
└──────┬──────┘       │ status          │       └─────────────────┘
       │              │ created_by      │──────────────┘
       │              │ current_*       │
       │              └────────┬────────┘
       │                       │
       │              ┌────────┴────────┐
       │              │                 │
       ▼              ▼                 ▼
┌─────────────────────────┐    ┌─────────────────┐
│    auction_schools      │    │   participants  │
│─────────────────────────│    │─────────────────│
│ id (PK)                 │    │ id (PK)         │
│ auction_id (FK)         │    │ auction_id (FK) │
│ school_id (FK)          │    │ user_id (FK)    │
│ leagify_position        │    │ display_name    │
│ projected_points        │    │ role            │
│ is_available            │    │ team_id (FK)    │
└───────────┬─────────────┘    │ is_connected    │
            │                  └────────┬────────┘
            │                           │
            │              ┌────────────┴────────────┐
            │              │                         │
            ▼              ▼                         ▼
┌─────────────────┐  ┌─────────────────┐    ┌─────────────────┐
│  roster_positions│  │     teams       │    │   bid_history   │
│─────────────────│  │─────────────────│    │─────────────────│
│ id (PK)         │  │ id (PK)         │    │ id (PK)         │
│ auction_id (FK) │  │ auction_id (FK) │    │ auction_id (FK) │
│ position_name   │  │ team_name       │    │ school_id (FK)  │
│ slots_per_team  │  │ budget          │    │ participant_id  │
│ is_flex         │  │ remaining_budget│    │ amount          │
│ display_order   │  │ nomination_order│    │ bid_type        │
└────────┬────────┘  └────────┬────────┘    └─────────────────┘
         │                    │
         │                    │
         └─────────┬──────────┘
                   │
                   ▼
         ┌─────────────────┐
         │   draft_picks   │
         │─────────────────│
         │ id (PK)         │
         │ auction_id (FK) │
         │ team_id (FK)    │
         │ school_id (FK)  │
         │ position_id (FK)│
         │ winning_bid     │
         │ pick_order      │
         └─────────────────┘
```

---

## Core Tables

### schools (Master Data)

Persistent school data shared across all auctions.

```sql
CREATE TABLE schools (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL UNIQUE,
    logo_url TEXT,                    -- External URL (primary)
    logo_filename TEXT,               -- Internal fallback
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_schools_name ON schools(name);

-- Trigger for updated_at
CREATE TRIGGER set_schools_updated_at
    BEFORE UPDATE ON schools
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### auctions

Main container for each draft event.

```sql
CREATE TABLE auctions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    join_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'practice', 'in_progress', 'paused', 'completed', 'archived')),

    -- Ownership
    created_by BIGINT REFERENCES users(id),

    -- Current bidding state (denormalized for real-time performance)
    current_nominator_id BIGINT,      -- FK to participants
    current_school_id BIGINT,         -- FK to auction_schools
    current_high_bid DECIMAL(10,2),
    current_high_bidder_id BIGINT,    -- FK to participants

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Settings
    default_budget DECIMAL(10,2) DEFAULT 200.00
);

-- Indexes
CREATE UNIQUE INDEX idx_auctions_join_code ON auctions(join_code);
CREATE INDEX idx_auctions_status ON auctions(status);
CREATE INDEX idx_auctions_created_by ON auctions(created_by);

-- Trigger for updated_at
CREATE TRIGGER set_auctions_updated_at
    BEFORE UPDATE ON auctions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### users

System-level users (for admin and ownership tracking).

```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    supabase_uid UUID UNIQUE,         -- Links to Supabase auth.users
    email TEXT,
    is_system_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for Supabase auth lookup
CREATE INDEX idx_users_supabase_uid ON users(supabase_uid);
```

### participants

Users within a specific auction (ephemeral, per-auction identity).

```sql
CREATE TABLE participants (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES users(id),  -- NULL for anonymous participants
    display_name TEXT NOT NULL,

    -- Role and team assignment
    role TEXT NOT NULL DEFAULT 'viewer'
        CHECK (role IN ('auction_master', 'team_coach', 'viewer')),
    team_id BIGINT,                   -- FK to teams (set when assigned as coach)

    -- Session management
    session_token TEXT,
    is_connected BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),

    -- Practice tracking
    has_practiced BOOLEAN DEFAULT FALSE,
    is_ready BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    UNIQUE(auction_id, display_name)
);

-- Indexes
CREATE INDEX idx_participants_auction ON participants(auction_id);
CREATE INDEX idx_participants_session ON participants(session_token) WHERE session_token IS NOT NULL;
CREATE INDEX idx_participants_connected ON participants(auction_id, is_connected);

-- Trigger for updated_at
CREATE TRIGGER set_participants_updated_at
    BEFORE UPDATE ON participants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### teams

Team entities within an auction.

```sql
CREATE TABLE teams (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,

    -- Budget
    budget DECIMAL(10,2) NOT NULL DEFAULT 200.00,
    remaining_budget DECIMAL(10,2) NOT NULL DEFAULT 200.00,

    -- Nomination order
    nomination_order INT NOT NULL,
    has_nominated_this_round BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,   -- Can still participate (not full, has budget)
    auto_pass_enabled BOOLEAN DEFAULT FALSE, -- Toggle for absent team coaches

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_budget_positive CHECK (budget > 0),
    CONSTRAINT chk_remaining_budget CHECK (remaining_budget >= 0 AND remaining_budget <= budget),
    UNIQUE(auction_id, team_name),
    UNIQUE(auction_id, nomination_order)
);

-- Indexes
CREATE INDEX idx_teams_auction ON teams(auction_id);
CREATE INDEX idx_teams_nomination ON teams(auction_id, nomination_order);

-- Trigger for updated_at
CREATE TRIGGER set_teams_updated_at
    BEFORE UPDATE ON teams
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### roster_positions

Position slots that each team must fill.

```sql
CREATE TABLE roster_positions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    position_name TEXT NOT NULL,      -- "SEC", "Big Ten", "Flex", etc.
    slots_per_team INT NOT NULL DEFAULT 1,
    is_flex BOOLEAN DEFAULT FALSE,    -- Accepts any school
    display_order INT NOT NULL,
    color_code TEXT DEFAULT '#6B7280',  -- Hex color for UI

    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_slots_positive CHECK (slots_per_team > 0),
    CONSTRAINT chk_color_format CHECK (color_code ~ '^#[0-9A-Fa-f]{6}$'),
    UNIQUE(auction_id, position_name)
);

-- Index
CREATE INDEX idx_roster_positions_auction ON roster_positions(auction_id, display_order);
```

### auction_schools

Schools available in a specific auction (with auction-specific stats).

```sql
CREATE TABLE auction_schools (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    school_id BIGINT NOT NULL REFERENCES schools(id),

    -- Position mapping
    leagify_position TEXT NOT NULL,   -- "SEC", "Big Ten", "Flex", etc.
    conference TEXT,                  -- Display only (may differ from position)

    -- Stats from CSV
    projected_points DECIMAL(8,2) NOT NULL DEFAULT 0,
    number_of_prospects INT DEFAULT 0,
    suggested_value DECIMAL(10,2),

    -- Calculated fields (can be recomputed)
    points_above_average DECIMAL(8,2),
    points_above_replacement DECIMAL(8,2),

    -- Status
    is_available BOOLEAN DEFAULT TRUE,
    import_order INT,                 -- Order from CSV

    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    UNIQUE(auction_id, school_id)
);

-- Indexes
CREATE INDEX idx_auction_schools_auction ON auction_schools(auction_id);
CREATE INDEX idx_auction_schools_available ON auction_schools(auction_id, is_available);
CREATE INDEX idx_auction_schools_position ON auction_schools(auction_id, leagify_position);
```

### draft_picks

Completed picks (schools assigned to teams).

```sql
CREATE TABLE draft_picks (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    team_id BIGINT NOT NULL REFERENCES teams(id),
    auction_school_id BIGINT NOT NULL REFERENCES auction_schools(id),
    roster_position_id BIGINT NOT NULL REFERENCES roster_positions(id),

    -- Bid details
    winning_bid DECIMAL(10,2) NOT NULL,
    nominated_by_id BIGINT REFERENCES participants(id),
    won_by_id BIGINT REFERENCES participants(id),

    -- Tracking
    pick_order INT NOT NULL,
    drafted_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_winning_bid_positive CHECK (winning_bid > 0),
    UNIQUE(auction_school_id)  -- Each school can only be drafted once
);

-- Indexes
CREATE INDEX idx_draft_picks_auction ON draft_picks(auction_id);
CREATE INDEX idx_draft_picks_team ON draft_picks(team_id);
CREATE INDEX idx_draft_picks_order ON draft_picks(auction_id, pick_order);
```

### bid_history

Audit trail of all bidding activity.

```sql
CREATE TABLE bid_history (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    auction_school_id BIGINT NOT NULL REFERENCES auction_schools(id),
    participant_id BIGINT NOT NULL REFERENCES participants(id),
    team_id BIGINT REFERENCES teams(id),  -- Which team the bid was for

    -- Bid details
    amount DECIMAL(10,2) NOT NULL,
    bid_type TEXT NOT NULL CHECK (bid_type IN ('nomination', 'bid', 'pass')),
    is_winning_bid BOOLEAN DEFAULT FALSE,
    is_practice BOOLEAN DEFAULT FALSE,    -- Practice mode bids

    -- For proxy bidding
    on_behalf_of_team_id BIGINT REFERENCES teams(id),

    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_amount_positive CHECK (amount >= 0)
);

-- Indexes
CREATE INDEX idx_bid_history_auction ON bid_history(auction_id);
CREATE INDEX idx_bid_history_school ON bid_history(auction_school_id, created_at);
CREATE INDEX idx_bid_history_participant ON bid_history(participant_id);
```

### admin_actions

Audit log for administrative actions.

```sql
CREATE TABLE admin_actions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT REFERENCES auctions(id) ON DELETE SET NULL,
    performed_by BIGINT REFERENCES users(id),
    participant_id BIGINT REFERENCES participants(id),  -- If action was by participant

    action_type TEXT NOT NULL,
    description TEXT,
    metadata JSONB,               -- Flexible storage for action details

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX idx_admin_actions_auction ON admin_actions(auction_id, created_at);
```

---

## Helper Functions

### Updated At Trigger

```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Calculate Max Bid

```sql
CREATE OR REPLACE FUNCTION calculate_max_bid(
    p_team_id BIGINT,
    p_auction_id BIGINT
) RETURNS DECIMAL AS $$
DECLARE
    v_remaining_budget DECIMAL;
    v_total_slots INT;
    v_filled_slots INT;
    v_remaining_slots INT;
BEGIN
    -- Get team's remaining budget
    SELECT remaining_budget INTO v_remaining_budget
    FROM teams WHERE id = p_team_id;

    -- Get total slots per team for this auction
    SELECT COALESCE(SUM(slots_per_team), 0) INTO v_total_slots
    FROM roster_positions WHERE auction_id = p_auction_id;

    -- Get filled slots for this team
    SELECT COUNT(*) INTO v_filled_slots
    FROM draft_picks WHERE team_id = p_team_id;

    v_remaining_slots := v_total_slots - v_filled_slots;

    IF v_remaining_slots <= 0 THEN
        RETURN 0;
    END IF;

    -- MaxBid = RemainingBudget - (RemainingSlots - 1)
    -- Must reserve $1 for each remaining slot after this one
    RETURN GREATEST(0, v_remaining_budget - (v_remaining_slots - 1));
END;
$$ LANGUAGE plpgsql;
```

### Check Position Eligibility

```sql
CREATE OR REPLACE FUNCTION is_position_eligible(
    p_school_position TEXT,
    p_roster_position_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_position_name TEXT;
    v_is_flex BOOLEAN;
BEGIN
    SELECT position_name, is_flex INTO v_position_name, v_is_flex
    FROM roster_positions WHERE id = p_roster_position_id;

    -- Flex positions accept any school
    IF v_is_flex THEN
        RETURN TRUE;
    END IF;

    -- Non-flex: exact match required (case-insensitive)
    RETURN LOWER(p_school_position) = LOWER(v_position_name);
END;
$$ LANGUAGE plpgsql;
```

---

## Row Level Security (RLS)

### Enable RLS on All Tables

```sql
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE roster_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE auction_schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE draft_picks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bid_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;
```

### Schools (Public Read, Admin Write)

```sql
-- Anyone can read schools
CREATE POLICY "Schools are viewable by everyone"
    ON schools FOR SELECT
    USING (true);

-- Only system admins can modify schools
CREATE POLICY "System admins can manage schools"
    ON schools FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );
```

### Auctions

```sql
-- Users can see auctions they're participating in or created
CREATE POLICY "Users can view their auctions"
    ON auctions FOR SELECT
    USING (
        -- System admin sees all
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
        OR
        -- Creator sees their auction
        created_by IN (
            SELECT id FROM users WHERE supabase_uid = auth.uid()
        )
        OR
        -- Participants see their auction
        id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
    );

-- Auction masters and system admins can update
CREATE POLICY "Auction masters can update their auctions"
    ON auctions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
        OR
        created_by IN (
            SELECT id FROM users WHERE supabase_uid = auth.uid()
        )
    );

-- System admins can delete
CREATE POLICY "System admins can delete auctions"
    ON auctions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );
```

### Participants

```sql
-- Participants in same auction can see each other
CREATE POLICY "Participants can view auction members"
    ON participants FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Auction master can update participants
CREATE POLICY "Auction masters can manage participants"
    ON participants FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM participants p
            JOIN auctions a ON a.id = p.auction_id
            WHERE p.session_token = current_setting('app.session_token', true)
            AND p.role = 'auction_master'
            AND a.id = participants.auction_id
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );
```

### Teams, Roster Positions, Auction Schools, Draft Picks, Bid History

Similar pattern: readable by auction participants, writable by auction master or system admin.

```sql
-- Example for teams (same pattern for others)
CREATE POLICY "Auction participants can view teams"
    ON teams FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );
```

---

## Realtime Subscriptions

### Tables Requiring Realtime

| Table | Events | Purpose |
|-------|--------|---------|
| `auctions` | UPDATE | Status changes, current bid updates |
| `participants` | INSERT, UPDATE | Connection status, ready state |
| `bid_history` | INSERT | New bids |
| `draft_picks` | INSERT | Completed picks |
| `teams` | UPDATE | Budget changes |
| `auction_schools` | UPDATE | Availability changes |

### Enable Realtime

```sql
-- In Supabase Dashboard or via SQL
ALTER PUBLICATION supabase_realtime ADD TABLE auctions;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE bid_history;
ALTER PUBLICATION supabase_realtime ADD TABLE draft_picks;
ALTER PUBLICATION supabase_realtime ADD TABLE teams;
ALTER PUBLICATION supabase_realtime ADD TABLE auction_schools;
```

### Subscription Patterns

```typescript
// Client subscribes to specific auction
supabase
  .channel('auction:${auctionId}')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'auctions',
    filter: `id=eq.${auctionId}`
  }, handleAuctionChange)
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'bid_history',
    filter: `auction_id=eq.${auctionId}`
  }, handleNewBid)
  .subscribe()
```

---

## Indexes Summary

| Table | Index | Purpose |
|-------|-------|---------|
| schools | name | Fuzzy matching on import |
| auctions | join_code (unique) | Join by code lookup |
| auctions | status | Filter active auctions |
| participants | auction_id | List auction members |
| participants | session_token | Session lookup |
| participants | (auction_id, is_connected) | Connection status |
| teams | auction_id | List teams |
| teams | (auction_id, nomination_order) | Turn order |
| auction_schools | (auction_id, is_available) | Available schools |
| auction_schools | (auction_id, leagify_position) | Position filtering |
| draft_picks | team_id | Team roster |
| draft_picks | (auction_id, pick_order) | Pick history |
| bid_history | (auction_school_id, created_at) | Bid timeline |

---

## Migration from Azure SQL

### Key Differences

| Azure SQL | PostgreSQL (Supabase) |
|-----------|----------------------|
| `INT IDENTITY` | `BIGINT GENERATED ALWAYS AS IDENTITY` |
| `NVARCHAR(n)` | `TEXT` |
| `BIT` | `BOOLEAN` |
| `DATETIME2` | `TIMESTAMPTZ` |
| `PascalCase` | `snake_case` |
| Stored procedures | Functions + Edge Functions |
| SignalR | Supabase Realtime |

### Schema Translation Notes

1. **User/Participant split**: Azure had single `User` table; now split into `users` (system-level) and `participants` (per-auction)
2. **UserRole table removed**: Role is now a column on `participants`
3. **NominationOrder table removed**: Nomination tracking moved to `teams.has_nominated_this_round`
4. **Test schools removed**: No more virtual test school entities
5. **Proxy coach simplified**: Auction Master uses "on_behalf_of" when bidding for absent teams

---

## Sample Data

### Default Roster Configuration (6-team auction)

```sql
INSERT INTO roster_positions (auction_id, position_name, slots_per_team, is_flex, display_order, color_code)
VALUES
    (1, 'SEC', 2, false, 1, '#DC2626'),      -- Red
    (1, 'Big Ten', 2, false, 2, '#2563EB'),  -- Blue
    (1, 'ACC', 1, false, 3, '#7C3AED'),      -- Purple
    (1, 'Big 12', 1, false, 4, '#D97706'),   -- Orange
    (1, 'Flex', 2, true, 5, '#6B7280');      -- Gray
```

### Typical Auction Stats

| Metric | Value |
|--------|-------|
| Teams | 6 |
| Budget per team | $200 |
| Total schools | ~50-150 |
| Roster slots per team | 8 |
| Total picks | 48 |
| Bids per auction | ~200-500 |
