-- Seed data for local development
-- Run with: npm run db:seed

-- Temporarily disable RLS for seeding
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE auctions DISABLE ROW LEVEL SECURITY;
ALTER TABLE teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE roster_positions DISABLE ROW LEVEL SECURITY;
ALTER TABLE auction_schools DISABLE ROW LEVEL SECURITY;

------------------------------------------------------------
-- System Admin User
------------------------------------------------------------

INSERT INTO users (supabase_uid, email, is_system_admin)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'admin@example.com', true);

-- Schools are seeded via migration 20260406000010_seed_default_schools.sql

------------------------------------------------------------
-- Test Auction (join code: TEST01)
------------------------------------------------------------

INSERT INTO auctions (join_code, name, status, created_by, default_budget)
VALUES ('TEST01', 'Test Auction', 'draft', 1, 200.00);

-- Roster positions for test auction
INSERT INTO roster_positions (auction_id, position_name, slots_per_team, is_flex, display_order, color_code) VALUES
  (1, 'SEC', 2, false, 1, '#DC2626'),
  (1, 'Big Ten', 2, false, 2, '#2563EB'),
  (1, 'ACC', 1, false, 3, '#7C3AED'),
  (1, 'Big 12', 1, false, 4, '#D97706'),
  (1, 'Flex', 2, true, 5, '#6B7280');

-- Teams for test auction
INSERT INTO teams (auction_id, team_name, budget, remaining_budget, nomination_order) VALUES
  (1, 'Team 1', 200, 200, 1),
  (1, 'Team 2', 200, 200, 2),
  (1, 'Team 3', 200, 200, 3),
  (1, 'Team 4', 200, 200, 4),
  (1, 'Team 5', 200, 200, 5),
  (1, 'Team 6', 200, 200, 6);

-- Auction schools (link schools to auction with positions)
INSERT INTO auction_schools (auction_id, school_id, leagify_position, conference, projected_points)
SELECT 1, s.id,
  CASE
    WHEN s.name IN ('Alabama', 'Georgia', 'LSU', 'Tennessee', 'Auburn', 'Ole Miss', 'Texas A&M') THEN 'SEC'
    WHEN s.name IN ('Ohio State', 'Michigan', 'Penn State', 'Wisconsin') THEN 'Big Ten'
    WHEN s.name IN ('Clemson', 'Florida State', 'Miami', 'North Carolina') THEN 'ACC'
    WHEN s.name IN ('Texas', 'Oklahoma') THEN 'Big 12'
    ELSE 'Flex'
  END,
  CASE
    WHEN s.name IN ('Alabama', 'Georgia', 'LSU', 'Tennessee', 'Auburn', 'Ole Miss', 'Texas A&M') THEN 'SEC'
    WHEN s.name IN ('Ohio State', 'Michigan', 'Penn State', 'Wisconsin') THEN 'Big Ten'
    WHEN s.name IN ('Clemson', 'Florida State', 'Miami', 'North Carolina') THEN 'ACC'
    WHEN s.name IN ('Texas', 'Oklahoma') THEN 'Big 12'
    WHEN s.name = 'Notre Dame' THEN 'Independent'
    ELSE 'Pac-12'
  END,
  CASE s.name
    WHEN 'Ohio State' THEN 225
    WHEN 'Alabama' THEN 204
    WHEN 'Georgia' THEN 198
    WHEN 'Michigan' THEN 185
    WHEN 'Texas' THEN 180
    WHEN 'Penn State' THEN 165
    WHEN 'Clemson' THEN 160
    WHEN 'Florida State' THEN 155
    WHEN 'LSU' THEN 150
    WHEN 'Notre Dame' THEN 145
    WHEN 'Oregon' THEN 140
    WHEN 'USC' THEN 135
    WHEN 'Tennessee' THEN 130
    WHEN 'Oklahoma' THEN 125
    WHEN 'Miami' THEN 120
    WHEN 'Wisconsin' THEN 115
    WHEN 'Auburn' THEN 110
    WHEN 'Ole Miss' THEN 105
    WHEN 'Texas A&M' THEN 100
    WHEN 'North Carolina' THEN 95
    ELSE 50
  END
FROM schools s;

-- Auction master participant
INSERT INTO participants (auction_id, user_id, display_name, role)
VALUES (1, 1, 'Admin', 'auction_master');

-- Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE roster_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE auction_schools ENABLE ROW LEVEL SECURITY;
