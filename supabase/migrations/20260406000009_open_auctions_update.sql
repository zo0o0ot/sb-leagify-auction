-- setAuctionStatus (pause/resume/start draft/practice) is called client-side
-- by the auction master. The session_token-based UPDATE policy depends on the
-- pre_request hook, which is unreliable on cloud Supabase for MVP.
-- Open the UPDATE entirely for MVP — this is an internal tool.
DROP POLICY IF EXISTS "Auction masters can update auction status" ON auctions;
CREATE POLICY "Anyone can update auctions"
    ON auctions FOR UPDATE
    USING (true);
