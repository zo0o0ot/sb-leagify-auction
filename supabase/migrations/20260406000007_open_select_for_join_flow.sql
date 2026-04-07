-- The join flow needs to read teams and participants before a session exists,
-- to find open slots and detect reconnects. Add permissive SELECT policies
-- so pre-session lookups by auction_id work.

CREATE POLICY "Anyone can view teams"
    ON teams FOR SELECT
    USING (true);

CREATE POLICY "Anyone can view participants"
    ON participants FOR SELECT
    USING (true);
