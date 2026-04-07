-- No DELETE policy existed on bid_history — admin practice bid clear operations
-- (clear last bid, clear all bids, end bidding) need to delete practice records.
CREATE POLICY "Anyone can delete bid history" ON bid_history FOR DELETE USING (true);
