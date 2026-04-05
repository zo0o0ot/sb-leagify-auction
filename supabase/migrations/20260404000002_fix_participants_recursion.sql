-- Fix participants table RLS recursion
-- The issue: participants SELECT policy was querying participants table

-- Create a function to get current participant's auction_ids without triggering RLS
CREATE OR REPLACE FUNCTION get_participant_auction_ids()
RETURNS SETOF BIGINT AS $$
BEGIN
    RETURN QUERY
    SELECT auction_id FROM participants
    WHERE session_token = current_setting('app.session_token', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate participants SELECT policy
-- Just check if this row's session matches, OR if user is in same auction
DROP POLICY IF EXISTS "Auction members can view participants" ON participants;
CREATE POLICY "Auction members can view participants"
    ON participants FOR SELECT
    USING (
        -- You can see yourself
        session_token = current_setting('app.session_token', true)
        OR
        -- You can see others in your auction(s)
        auction_id IN (SELECT get_participant_auction_ids())
        OR
        -- System admin sees all
        is_system_admin()
    );

-- Update other policies to use the function
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
        id IN (SELECT get_participant_auction_ids())
    );

DROP POLICY IF EXISTS "Auction members can view teams" ON teams;
CREATE POLICY "Auction members can view teams"
    ON teams FOR SELECT
    USING (
        auction_id IN (SELECT get_participant_auction_ids())
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view roster positions" ON roster_positions;
CREATE POLICY "Auction members can view roster positions"
    ON roster_positions FOR SELECT
    USING (
        auction_id IN (SELECT get_participant_auction_ids())
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view auction schools" ON auction_schools;
CREATE POLICY "Auction members can view auction schools"
    ON auction_schools FOR SELECT
    USING (
        auction_id IN (SELECT get_participant_auction_ids())
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view draft picks" ON draft_picks;
CREATE POLICY "Auction members can view draft picks"
    ON draft_picks FOR SELECT
    USING (
        auction_id IN (SELECT get_participant_auction_ids())
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction members can view bid history" ON bid_history;
CREATE POLICY "Auction members can view bid history"
    ON bid_history FOR SELECT
    USING (
        auction_id IN (SELECT get_participant_auction_ids())
        OR is_system_admin()
    );

-- Fix the auction participant check policies to use a function too
CREATE OR REPLACE FUNCTION is_auction_master(p_auction_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM participants
        WHERE session_token = current_setting('app.session_token', true)
        AND role = 'auction_master'
        AND auction_id = p_auction_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP POLICY IF EXISTS "Auction masters can manage teams" ON teams;
CREATE POLICY "Auction masters can manage teams"
    ON teams FOR ALL
    USING (is_auction_master(auction_id) OR is_system_admin());

DROP POLICY IF EXISTS "Auction masters can manage roster positions" ON roster_positions;
CREATE POLICY "Auction masters can manage roster positions"
    ON roster_positions FOR ALL
    USING (is_auction_master(auction_id) OR is_system_admin());

DROP POLICY IF EXISTS "Auction masters can manage auction schools" ON auction_schools;
CREATE POLICY "Auction masters can manage auction schools"
    ON auction_schools FOR ALL
    USING (is_auction_master(auction_id) OR is_system_admin());

DROP POLICY IF EXISTS "Auction masters can manage draft picks" ON draft_picks;
CREATE POLICY "Auction masters can manage draft picks"
    ON draft_picks FOR ALL
    USING (is_auction_master(auction_id) OR is_system_admin());

DROP POLICY IF EXISTS "Participants can update own record" ON participants;
CREATE POLICY "Participants can update own record"
    ON participants FOR UPDATE
    USING (
        session_token = current_setting('app.session_token', true)
        OR is_auction_master(auction_id)
        OR is_system_admin()
    );

DROP POLICY IF EXISTS "Auction participants can create bids" ON bid_history;
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
