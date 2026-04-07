-- The join flow needs to look up an auction by join_code before a session exists.
-- Add a permissive SELECT policy so anyone can read auctions (name, status, join_code
-- are not sensitive — you need the join code to find the auction in the first place).
CREATE POLICY "Anyone can view auctions"
    ON auctions FOR SELECT
    USING (true);
