-- The create-auction flow inserts a participant before the session is saved,
-- so the existing session_token-based SELECT policy returns nothing.
-- Add an auth.uid()-based policy so the auction creator can always read
-- participants in their own auction.
CREATE POLICY "Auction creator can view participants"
    ON participants FOR SELECT
    USING (
        auction_id IN (
            SELECT a.id FROM auctions a
            JOIN users u ON u.id = a.created_by
            WHERE u.supabase_uid = auth.uid()
        )
    );

-- Also trigger PostgREST to reload so the pre_request hook takes effect
-- for all subsequent session-token based policies.
NOTIFY pgrst, 'reload config';
