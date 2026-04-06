-- Position assignment happens after the pick completes (via modal),
-- so roster_position_id must be nullable until the winner assigns it.
ALTER TABLE draft_picks ALTER COLUMN roster_position_id DROP NOT NULL;
