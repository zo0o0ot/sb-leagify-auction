-- current_high_bidder_id was mistakenly FK'd to participants(id).
-- Both place-bid and complete-bid treat it as a teams.id reference.
-- Re-point the FK to teams(id).
ALTER TABLE auctions DROP CONSTRAINT IF EXISTS fk_auctions_current_high_bidder;
ALTER TABLE auctions
    ADD CONSTRAINT fk_auctions_current_high_bidder
    FOREIGN KEY (current_high_bidder_id) REFERENCES teams(id);
