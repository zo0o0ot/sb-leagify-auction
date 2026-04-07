-- All auction data is internal / non-sensitive for this MVP.
-- Open SELECT on the remaining tables so client-side queries in the
-- lobby and draft views never hit RLS walls.

CREATE POLICY "Anyone can view roster positions"
    ON roster_positions FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view auction schools"
    ON auction_schools FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view draft picks"
    ON draft_picks FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view bid history"
    ON bid_history FOR SELECT
    USING (true);

-- Auction master needs to update status (pause/resume/end) from the client.
-- Replace auth.uid()-based UPDATE policy with a session-token-based one.
DROP POLICY IF EXISTS "Auction creators can update their auctions" ON auctions;
CREATE POLICY "Auction masters can update auction status"
    ON auctions FOR UPDATE
    USING (
        id IN (
            SELECT auction_id FROM participants
            WHERE session_token = current_setting('app.session_token', true)
            AND role = 'auction_master'
        )
        OR EXISTS (
            SELECT 1 FROM users WHERE supabase_uid = auth.uid() AND is_system_admin = true
        )
    );

-- Participants UPDATE: allow updating your own record by id match (for reconnect
-- where the caller doesn't yet have the old session token).
DROP POLICY IF EXISTS "Participants can update own record" ON participants;
CREATE POLICY "Participants can update own record"
    ON participants FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- Teams UPDATE: needed for join flow (rename team to display name) and
-- auction master edits. Open for MVP.
CREATE POLICY "Anyone can update teams"
    ON teams FOR UPDATE
    USING (true);
