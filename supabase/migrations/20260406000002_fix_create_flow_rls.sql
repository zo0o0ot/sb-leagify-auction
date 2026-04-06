-- Fix RLS policies for the create-auction flow.
--
-- Problem: CreateAuctionView runs several INSERTs (users, auctions, teams,
-- roster_positions, auction_schools) before the session token is established.
-- All the session_token-based policies therefore fail for these initial writes.
-- The auction creator is identified by auth.uid() (from the anonymous JWT),
-- so we add auth.uid()-based policies alongside the existing session_token ones.

-- 1. Users: allow any authenticated user to insert their own record
CREATE POLICY "Users can insert own record"
    ON users FOR INSERT
    WITH CHECK (supabase_uid = auth.uid());

-- 2. Teams: allow INSERT for authenticated users (creator is setting up the auction)
--    Existing session_token UPDATE policy handles in-draft mutations.
CREATE POLICY "Authenticated users can insert teams"
    ON teams FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- 3. Teams UPDATE: allow the auction creator to rename team slots during setup
--    (session_token policy kicks in once the lobby is active)
CREATE POLICY "Auction creator can update teams during setup"
    ON teams FOR UPDATE
    USING (
        auction_id IN (
            SELECT a.id FROM auctions a
            JOIN users u ON u.id = a.created_by
            WHERE u.supabase_uid = auth.uid()
        )
    );

-- 4. Roster positions: allow INSERT for authenticated users during auction setup
CREATE POLICY "Authenticated users can insert roster positions"
    ON roster_positions FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- 5. Auction schools: allow INSERT for authenticated users during setup
--    (Default schools linked on create; CSV uploaded via maintain-schools page)
CREATE POLICY "Authenticated users can insert auction schools"
    ON auction_schools FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);
