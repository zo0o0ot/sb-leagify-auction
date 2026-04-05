-- Fix infinite recursion in RLS policies
-- The issue: policies on users table were checking users table

-- Create a security definer function to check admin status
-- This bypasses RLS when checking admin status
CREATE OR REPLACE FUNCTION is_system_admin()
RETURNS BOOLEAN AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    SELECT is_system_admin INTO v_is_admin
    FROM users
    WHERE supabase_uid = auth.uid();

    RETURN COALESCE(v_is_admin, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the problematic policies
DROP POLICY IF EXISTS "System admins can manage users" ON users;
DROP POLICY IF EXISTS "System admins can manage schools" ON schools;

-- Recreate users policies without recursion
CREATE POLICY "System admins can manage users"
    ON users FOR ALL
    USING (is_system_admin());

-- Recreate schools admin policy
CREATE POLICY "System admins can manage schools"
    ON schools FOR ALL
    USING (is_system_admin());

-- Update other policies that referenced users table directly
-- (These use the function instead)

DROP POLICY IF EXISTS "Users can view their auctions" ON auctions;
CREATE POLICY "Users can view their auctions"
    ON auctions FOR SELECT
    USING (
        is_system_admin()
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

DROP POLICY IF EXISTS "Auction creators can update their auctions" ON auctions;
CREATE POLICY "Auction creators can update their auctions"
    ON auctions FOR UPDATE
    USING (
        is_system_admin()
        OR
        created_by IN (
            SELECT id FROM users WHERE supabase_uid = auth.uid()
        )
    );

DROP POLICY IF EXISTS "System admins can delete auctions" ON auctions;
CREATE POLICY "System admins can delete auctions"
    ON auctions FOR DELETE
    USING (is_system_admin());

DROP POLICY IF EXISTS "Auction members can view participants" ON participants;
CREATE POLICY "Auction members can view participants"
    ON participants FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Participants can update own record" ON participants;
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
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view teams" ON teams;
CREATE POLICY "Auction members can view teams"
    ON teams FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction masters can manage teams" ON teams;
CREATE POLICY "Auction masters can manage teams"
    ON teams FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = teams.auction_id
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view roster positions" ON roster_positions;
CREATE POLICY "Auction members can view roster positions"
    ON roster_positions FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction masters can manage roster positions" ON roster_positions;
CREATE POLICY "Auction masters can manage roster positions"
    ON roster_positions FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = roster_positions.auction_id
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view auction schools" ON auction_schools;
CREATE POLICY "Auction members can view auction schools"
    ON auction_schools FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction masters can manage auction schools" ON auction_schools;
CREATE POLICY "Auction masters can manage auction schools"
    ON auction_schools FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = auction_schools.auction_id
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view draft picks" ON draft_picks;
CREATE POLICY "Auction members can view draft picks"
    ON draft_picks FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction masters can manage draft picks" ON draft_picks;
CREATE POLICY "Auction masters can manage draft picks"
    ON draft_picks FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
            AND auction_id = draft_picks.auction_id
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view bid history" ON bid_history;
CREATE POLICY "Auction members can view bid history"
    ON bid_history FOR SELECT
    USING (
        auction_id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
        )
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "System admins can view admin actions" ON admin_actions;
CREATE POLICY "System admins can view admin actions"
    ON admin_actions FOR SELECT
    USING (is_system_admin());

DROP POLICY IF EXISTS "System admins can create admin actions" ON admin_actions;
CREATE POLICY "System admins can create admin actions"
    ON admin_actions FOR INSERT
    WITH CHECK (
        is_system_admin()
        OR
        EXISTS (
            SELECT 1 FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
        )
    );
