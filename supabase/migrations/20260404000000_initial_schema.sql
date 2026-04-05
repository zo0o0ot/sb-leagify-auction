-- Initial schema for Leagify Fantasy Auction
-- Based on DATABASE-SCHEMA.md

------------------------------------------------------------
-- Helper Functions
------------------------------------------------------------

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------
-- Core Tables
------------------------------------------------------------

-- Schools (Master Data)
CREATE TABLE schools (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    logo_filename TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_schools_name ON schools(name);

CREATE TRIGGER set_schools_updated_at
    BEFORE UPDATE ON schools
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Users (System-level)
CREATE TABLE users (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    supabase_uid UUID UNIQUE,
    email TEXT,
    is_system_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_supabase_uid ON users(supabase_uid);

CREATE TRIGGER set_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auctions (Main Container)
CREATE TABLE auctions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    join_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'practice', 'in_progress', 'paused', 'completed', 'archived')),

    created_by BIGINT REFERENCES users(id),

    -- Current bidding state (denormalized for real-time)
    current_nominator_id BIGINT,
    current_school_id BIGINT,
    current_high_bid DECIMAL(10,2),
    current_high_bidder_id BIGINT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Settings
    default_budget DECIMAL(10,2) DEFAULT 200.00
);

CREATE UNIQUE INDEX idx_auctions_join_code ON auctions(join_code);
CREATE INDEX idx_auctions_status ON auctions(status);
CREATE INDEX idx_auctions_created_by ON auctions(created_by);

CREATE TRIGGER set_auctions_updated_at
    BEFORE UPDATE ON auctions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Teams
CREATE TABLE teams (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    team_name TEXT NOT NULL,

    budget DECIMAL(10,2) NOT NULL DEFAULT 200.00,
    remaining_budget DECIMAL(10,2) NOT NULL DEFAULT 200.00,

    nomination_order INT NOT NULL,
    has_nominated_this_round BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    auto_pass_enabled BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_budget_positive CHECK (budget > 0),
    CONSTRAINT chk_remaining_budget CHECK (remaining_budget >= 0 AND remaining_budget <= budget),
    UNIQUE(auction_id, team_name),
    UNIQUE(auction_id, nomination_order)
);

CREATE INDEX idx_teams_auction ON teams(auction_id);
CREATE INDEX idx_teams_nomination ON teams(auction_id, nomination_order);

CREATE TRIGGER set_teams_updated_at
    BEFORE UPDATE ON teams
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Participants (per-auction identity)
CREATE TABLE participants (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES users(id),
    display_name TEXT NOT NULL,

    role TEXT NOT NULL DEFAULT 'viewer'
        CHECK (role IN ('auction_master', 'team_coach', 'viewer')),
    team_id BIGINT REFERENCES teams(id),

    session_token TEXT,
    is_connected BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),

    has_practiced BOOLEAN DEFAULT FALSE,
    is_ready BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(auction_id, display_name)
);

CREATE INDEX idx_participants_auction ON participants(auction_id);
CREATE INDEX idx_participants_session ON participants(session_token) WHERE session_token IS NOT NULL;
CREATE INDEX idx_participants_connected ON participants(auction_id, is_connected);

CREATE TRIGGER set_participants_updated_at
    BEFORE UPDATE ON participants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Roster Positions
CREATE TABLE roster_positions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    position_name TEXT NOT NULL,
    slots_per_team INT NOT NULL DEFAULT 1,
    is_flex BOOLEAN DEFAULT FALSE,
    display_order INT NOT NULL,
    color_code TEXT DEFAULT '#6B7280',

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_slots_positive CHECK (slots_per_team > 0),
    CONSTRAINT chk_color_format CHECK (color_code ~ '^#[0-9A-Fa-f]{6}$'),
    UNIQUE(auction_id, position_name)
);

CREATE INDEX idx_roster_positions_auction ON roster_positions(auction_id, display_order);

-- Auction Schools (per-auction school data)
CREATE TABLE auction_schools (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    school_id BIGINT NOT NULL REFERENCES schools(id),

    leagify_position TEXT NOT NULL,
    conference TEXT,

    projected_points DECIMAL(8,2) NOT NULL DEFAULT 0,
    number_of_prospects INT DEFAULT 0,
    suggested_value DECIMAL(10,2),

    points_above_average DECIMAL(8,2),
    points_above_replacement DECIMAL(8,2),

    is_available BOOLEAN DEFAULT TRUE,
    import_order INT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(auction_id, school_id)
);

CREATE INDEX idx_auction_schools_auction ON auction_schools(auction_id);
CREATE INDEX idx_auction_schools_available ON auction_schools(auction_id, is_available);
CREATE INDEX idx_auction_schools_position ON auction_schools(auction_id, leagify_position);

-- Draft Picks
CREATE TABLE draft_picks (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    team_id BIGINT NOT NULL REFERENCES teams(id),
    auction_school_id BIGINT NOT NULL REFERENCES auction_schools(id),
    roster_position_id BIGINT NOT NULL REFERENCES roster_positions(id),

    winning_bid DECIMAL(10,2) NOT NULL,
    nominated_by_id BIGINT REFERENCES participants(id),
    won_by_id BIGINT REFERENCES participants(id),

    pick_order INT NOT NULL,
    drafted_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_winning_bid_positive CHECK (winning_bid > 0),
    UNIQUE(auction_school_id)
);

CREATE INDEX idx_draft_picks_auction ON draft_picks(auction_id);
CREATE INDEX idx_draft_picks_team ON draft_picks(team_id);
CREATE INDEX idx_draft_picks_order ON draft_picks(auction_id, pick_order);

-- Bid History
CREATE TABLE bid_history (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
    auction_school_id BIGINT NOT NULL REFERENCES auction_schools(id),
    participant_id BIGINT NOT NULL REFERENCES participants(id),
    team_id BIGINT REFERENCES teams(id),

    amount DECIMAL(10,2) NOT NULL,
    bid_type TEXT NOT NULL CHECK (bid_type IN ('nomination', 'bid', 'pass')),
    is_winning_bid BOOLEAN DEFAULT FALSE,
    is_practice BOOLEAN DEFAULT FALSE,

    on_behalf_of_team_id BIGINT REFERENCES teams(id),

    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_amount_positive CHECK (amount >= 0)
);

CREATE INDEX idx_bid_history_auction ON bid_history(auction_id);
CREATE INDEX idx_bid_history_school ON bid_history(auction_school_id, created_at);
CREATE INDEX idx_bid_history_participant ON bid_history(participant_id);

-- Admin Actions (audit log)
CREATE TABLE admin_actions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    auction_id BIGINT REFERENCES auctions(id) ON DELETE SET NULL,
    performed_by BIGINT REFERENCES users(id),
    participant_id BIGINT REFERENCES participants(id),

    action_type TEXT NOT NULL,
    description TEXT,
    metadata JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_actions_auction ON admin_actions(auction_id, created_at);

------------------------------------------------------------
-- Add foreign key references that couldn't be added earlier
------------------------------------------------------------

ALTER TABLE auctions
    ADD CONSTRAINT fk_auctions_current_nominator
    FOREIGN KEY (current_nominator_id) REFERENCES participants(id);

ALTER TABLE auctions
    ADD CONSTRAINT fk_auctions_current_school
    FOREIGN KEY (current_school_id) REFERENCES auction_schools(id);

ALTER TABLE auctions
    ADD CONSTRAINT fk_auctions_current_high_bidder
    FOREIGN KEY (current_high_bidder_id) REFERENCES participants(id);

------------------------------------------------------------
-- Helper Functions for Business Logic
------------------------------------------------------------

-- Calculate max bid for a team
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
    SELECT remaining_budget INTO v_remaining_budget
    FROM teams WHERE id = p_team_id;

    SELECT COALESCE(SUM(slots_per_team), 0) INTO v_total_slots
    FROM roster_positions WHERE auction_id = p_auction_id;

    SELECT COUNT(*) INTO v_filled_slots
    FROM draft_picks WHERE team_id = p_team_id;

    v_remaining_slots := v_total_slots - v_filled_slots;

    IF v_remaining_slots <= 0 THEN
        RETURN 0;
    END IF;

    -- MaxBid = RemainingBudget - (RemainingSlots - 1)
    RETURN GREATEST(0, v_remaining_budget - (v_remaining_slots - 1));
END;
$$ LANGUAGE plpgsql;

-- Check if a school can be assigned to a position
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

    IF v_is_flex THEN
        RETURN TRUE;
    END IF;

    RETURN LOWER(p_school_position) = LOWER(v_position_name);
END;
$$ LANGUAGE plpgsql;

------------------------------------------------------------
-- Enable Row Level Security
------------------------------------------------------------

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

------------------------------------------------------------
-- RLS Policies
------------------------------------------------------------

-- Schools: Public read, admin write
CREATE POLICY "Schools are viewable by everyone"
    ON schools FOR SELECT
    USING (true);

CREATE POLICY "System admins can manage schools"
    ON schools FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Users: Users can see themselves, admins see all
CREATE POLICY "Users can view own record"
    ON users FOR SELECT
    USING (supabase_uid = auth.uid());

CREATE POLICY "System admins can manage users"
    ON users FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Auctions: Participants and creators can see their auctions
CREATE POLICY "Users can view their auctions"
    ON auctions FOR SELECT
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
        OR
        id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
    );

CREATE POLICY "Auction creators can update their auctions"
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

CREATE POLICY "System admins can delete auctions"
    ON auctions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

CREATE POLICY "Authenticated users can create auctions"
    ON auctions FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Participants: Visible to auction members
CREATE POLICY "Auction members can view participants"
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

CREATE POLICY "Anyone can join an auction"
    ON participants FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Participants can update own record"
    ON participants FOR UPDATE
    USING (
        session_token = current_setting('app.session_token', true)
        OR
        EXISTS (
            SELECT 1 FROM participants p
            WHERE p.session_token = current_setting('app.session_token', true)
            AND p.role = 'auction_master'
            AND p.auction_id = participants.auction_id
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Teams: Visible to auction members
CREATE POLICY "Auction members can view teams"
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

CREATE POLICY "Auction masters can manage teams"
    ON teams FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = teams.auction_id
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Roster Positions: Visible to auction members
CREATE POLICY "Auction members can view roster positions"
    ON roster_positions FOR SELECT
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

CREATE POLICY "Auction masters can manage roster positions"
    ON roster_positions FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = roster_positions.auction_id
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Auction Schools: Visible to auction members
CREATE POLICY "Auction members can view auction schools"
    ON auction_schools FOR SELECT
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

CREATE POLICY "Auction masters can manage auction schools"
    ON auction_schools FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = auction_schools.auction_id
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Draft Picks: Visible to auction members
CREATE POLICY "Auction members can view draft picks"
    ON draft_picks FOR SELECT
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

CREATE POLICY "Auction masters can manage draft picks"
    ON draft_picks FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = draft_picks.auction_id
        )
        OR
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

-- Bid History: Visible to auction members
CREATE POLICY "Auction members can view bid history"
    ON bid_history FOR SELECT
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

CREATE POLICY "Auction participants can create bids"
    ON bid_history FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND auction_id = bid_history.auction_id
            AND role IN ('auction_master', 'team_coach')
        )
    );

-- Admin Actions: Only system admins
CREATE POLICY "System admins can view admin actions"
    ON admin_actions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
    );

CREATE POLICY "System admins can create admin actions"
    ON admin_actions FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE supabase_uid = auth.uid()
            AND is_system_admin = true
        )
        OR
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
        )
    );

------------------------------------------------------------
-- Enable Realtime for relevant tables
------------------------------------------------------------

ALTER PUBLICATION supabase_realtime ADD TABLE auctions;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE teams;
ALTER PUBLICATION supabase_realtime ADD TABLE auction_schools;
ALTER PUBLICATION supabase_realtime ADD TABLE draft_picks;
ALTER PUBLICATION supabase_realtime ADD TABLE bid_history;
