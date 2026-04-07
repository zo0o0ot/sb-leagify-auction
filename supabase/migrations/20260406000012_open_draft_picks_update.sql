-- draft_picks UPDATE policy used is_auction_master() which depends on the
-- pre_request session_token hook — unreliable on cloud. Open it for MVP.
DROP POLICY IF EXISTS "Auction masters can update draft picks" ON draft_picks;
CREATE POLICY "Anyone can update draft picks" ON draft_picks FOR UPDATE USING (true);
