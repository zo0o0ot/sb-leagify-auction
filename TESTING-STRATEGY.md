# Leagify Fantasy Auction - Testing Strategy

## Philosophy

**Tests are not optional.** The previous implementation had bugs reach users that tests should have caught. This project follows test-first development: write the test, watch it fail, implement the feature, watch it pass.

### Core Principles

1. **Test Before Code**: Every feature starts with a failing test
2. **Bug Fix Protocol**: Every bug fix starts with a test that reproduces the bug
3. **No Commit Without Tests**: Pre-commit hook enforces test passage
4. **Local First**: All tests run locally against Supabase local stack
5. **Fast Feedback**: Unit tests complete in <5 seconds, full suite in <60 seconds

---

## Test Categories

### 1. Unit Tests (Frontend)

Test individual functions and composables in isolation.

**Location:** `src/**/*.test.ts`
**Runner:** Vitest
**Coverage Target:** 80% for business logic

**What to Test:**
- Budget calculations (MaxBid formula)
- Position eligibility checks
- State derivations (available schools, current turn, etc.)
- CSV parsing and validation
- Fuzzy string matching

**Example:**
```typescript
// src/utils/budget.test.ts
import { describe, it, expect } from 'vitest'
import { calculateMaxBid } from './budget'

describe('calculateMaxBid', () => {
  it('returns full budget when only one slot remaining', () => {
    const result = calculateMaxBid({
      remainingBudget: 50,
      remainingSlots: 1
    })
    expect(result).toBe(50)  // No need to reserve for other slots
  })

  it('reserves $1 per remaining slot after current', () => {
    const result = calculateMaxBid({
      remainingBudget: 100,
      remainingSlots: 5
    })
    expect(result).toBe(96)  // 100 - (5-1) = 96
  })

  it('returns 0 when budget insufficient for remaining slots', () => {
    const result = calculateMaxBid({
      remainingBudget: 3,
      remainingSlots: 5
    })
    expect(result).toBe(0)  // Can't even cover $1 per slot
  })

  it('returns 0 when no slots remaining', () => {
    const result = calculateMaxBid({
      remainingBudget: 100,
      remainingSlots: 0
    })
    expect(result).toBe(0)  // Roster full
  })
})
```

### 2. Component Tests (Frontend)

Test Vue components with mock data.

**Location:** `src/components/**/*.test.ts`
**Runner:** Vitest + Vue Test Utils
**Coverage Target:** Key interactive components

**What to Test:**
- Bid button disabled states
- Role-based UI visibility
- Form validation feedback
- Loading and error states

**Example:**
```typescript
// src/components/BidControls.test.ts
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import BidControls from './BidControls.vue'

describe('BidControls', () => {
  it('disables bid buttons when user has passed', () => {
    const wrapper = mount(BidControls, {
      props: {
        currentBid: 50,
        maxBid: 100,
        hasPassed: true
      }
    })

    expect(wrapper.find('[data-test="bid-button"]').attributes('disabled')).toBeDefined()
  })

  it('disables bid buttons when bid would exceed maxBid', () => {
    const wrapper = mount(BidControls, {
      props: {
        currentBid: 95,
        maxBid: 100,
        hasPassed: false
      }
    })

    // +$10 button should be disabled (95 + 10 > 100)
    expect(wrapper.find('[data-test="bid-10"]').attributes('disabled')).toBeDefined()
    // +$1 button should be enabled
    expect(wrapper.find('[data-test="bid-1"]').attributes('disabled')).toBeUndefined()
  })

  it('shows auto-pass message when maxBid <= currentBid', () => {
    const wrapper = mount(BidControls, {
      props: {
        currentBid: 100,
        maxBid: 95,
        hasPassed: false
      }
    })

    expect(wrapper.text()).toContain('Auto-passed')
  })
})
```

### 3. Integration Tests (API/Edge Functions)

Test Supabase Edge Functions with real database.

**Location:** `supabase/functions/**/index.test.ts`
**Runner:** Deno test (built into Supabase)
**Database:** Supabase local (Docker)

**What to Test:**
- Bid validation and placement
- Turn advancement logic
- Budget updates after winning bid
- Position assignment validation
- Concurrent bid handling (race conditions)

**Example:**
```typescript
// supabase/functions/place-bid/index.test.ts
import { assertEquals, assertRejects } from 'https://deno.land/std/testing/asserts.ts'
import { createClient } from '@supabase/supabase-js'
import { setupTestAuction, cleanupTestAuction } from '../test-utils.ts'

Deno.test('place-bid: rejects bid below current high bid', async () => {
  const { auction, participant, team } = await setupTestAuction({
    currentHighBid: 50
  })

  const response = await fetch(`${SUPABASE_URL}/functions/v1/place-bid`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${participant.session_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      auctionId: auction.id,
      amount: 45  // Below current bid of 50
    })
  })

  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error.code, 'BID_TOO_LOW')

  await cleanupTestAuction(auction.id)
})

Deno.test('place-bid: rejects bid exceeding maxBid', async () => {
  const { auction, participant, team } = await setupTestAuction({
    teamBudget: 100,
    remainingSlots: 3,  // maxBid = 100 - (3-1) = 98
    currentHighBid: 50
  })

  const response = await fetch(`${SUPABASE_URL}/functions/v1/place-bid`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${participant.session_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      auctionId: auction.id,
      amount: 99  // Exceeds maxBid of 98
    })
  })

  const result = await response.json()
  assertEquals(result.success, false)
  assertEquals(result.error.code, 'BID_EXCEEDS_MAX')

  await cleanupTestAuction(auction.id)
})

Deno.test('place-bid: advances turn when all others auto-passed', async () => {
  // Setup: 3 teams, team 2 and 3 can't afford to continue
  const { auction, teams, participants } = await setupTestAuction({
    teamCount: 3,
    currentHighBid: 95,
    teamBudgets: [200, 100, 100],  // Team 2,3 maxBid < 95
    remainingSlots: [5, 2, 2]
  })

  // Team 1 bids
  await placeBid(participants[0], 96)

  // Verify bidding ended (teams 2,3 auto-passed)
  const updatedAuction = await getAuction(auction.id)
  assertEquals(updatedAuction.status, 'assigning')  // Moved to assignment phase

  await cleanupTestAuction(auction.id)
})
```

### 4. Database Tests

Test PostgreSQL functions and RLS policies.

**Location:** `supabase/tests/*.sql`
**Runner:** pgTAP (via Supabase)

**What to Test:**
- `calculate_max_bid()` function
- `is_position_eligible()` function
- RLS policies block cross-auction access
- Constraints prevent invalid data

**Example:**
```sql
-- supabase/tests/budget_calculation.test.sql
BEGIN;
SELECT plan(4);

-- Setup test data
INSERT INTO auctions (id, join_code, name, status)
VALUES (1, 'TEST01', 'Test Auction', 'in_progress');

INSERT INTO teams (id, auction_id, team_name, budget, remaining_budget, nomination_order)
VALUES (1, 1, 'Test Team', 200, 100, 1);

INSERT INTO roster_positions (auction_id, position_name, slots_per_team, is_flex, display_order)
VALUES (1, 'SEC', 2, false, 1), (1, 'Flex', 3, true, 2);

-- Test: MaxBid with 5 slots remaining
-- MaxBid = 100 - (5-1) = 96
SELECT is(
  calculate_max_bid(1, 1),
  96::DECIMAL,
  'MaxBid should be budget minus reserved slots'
);

-- Add some draft picks (2 filled)
INSERT INTO draft_picks (auction_id, team_id, auction_school_id, roster_position_id, winning_bid, pick_order)
VALUES (1, 1, 1, 1, 50, 1), (1, 1, 2, 1, 30, 2);

-- Test: MaxBid with 3 slots remaining
-- MaxBid = 100 - (3-1) = 98
SELECT is(
  calculate_max_bid(1, 1),
  98::DECIMAL,
  'MaxBid increases as slots fill'
);

-- Test: Full roster returns 0
INSERT INTO draft_picks (auction_id, team_id, auction_school_id, roster_position_id, winning_bid, pick_order)
VALUES (1, 1, 3, 2, 5, 3), (1, 1, 4, 2, 5, 4), (1, 1, 5, 2, 5, 5);

SELECT is(
  calculate_max_bid(1, 1),
  0::DECIMAL,
  'Full roster returns 0 maxBid'
);

-- Test: Last slot gets full remaining budget
DELETE FROM draft_picks WHERE id > 4;
UPDATE teams SET remaining_budget = 50 WHERE id = 1;

SELECT is(
  calculate_max_bid(1, 1),
  50::DECIMAL,
  'Last slot gets full remaining budget'
);

SELECT * FROM finish();
ROLLBACK;
```

### 5. End-to-End Tests

Test complete user flows in browser.

**Location:** `e2e/*.spec.ts`
**Runner:** Playwright
**Database:** Supabase local (fresh seed per test)

**What to Test:**
- Complete auction flow (create → join → bid → complete)
- Reconnection after disconnect
- Role-based access enforcement
- CSV import and export
- Multi-user bidding (simulated)

**Example:**
```typescript
// e2e/auction-flow.spec.ts
import { test, expect } from '@playwright/test'
import { seedTestAuction, getAuctionJoinCode } from './helpers'

test.describe('Complete Auction Flow', () => {
  test.beforeEach(async () => {
    await seedTestAuction({
      teams: 2,
      schools: 5,
      slotsPerTeam: 2
    })
  })

  test('team coach can nominate and win school', async ({ page }) => {
    const joinCode = await getAuctionJoinCode()

    // Join as Team 1 (first nominator)
    await page.goto('/')
    await page.fill('[data-test="join-code"]', joinCode)
    await page.fill('[data-test="display-name"]', 'Ross')
    await page.click('[data-test="join-button"]')

    // Wait for auction lobby
    await expect(page.locator('[data-test="auction-lobby"]')).toBeVisible()

    // Start auction (assuming we're auction master for test)
    await page.click('[data-test="start-auction"]')

    // Nominate a school
    await page.click('[data-test="school-Ohio State"] [data-test="nominate"]')

    // Verify nomination placed auto-bid
    await expect(page.locator('[data-test="current-bid"]')).toHaveText('$1')
    await expect(page.locator('[data-test="high-bidder"]')).toHaveText('Ross')

    // Other team passes (simulated via API for this test)
    await simulatePass('Team 2')

    // Verify we won
    await expect(page.locator('[data-test="winner-announcement"]')).toContainText('Ross won Ohio State')

    // Assign to position
    await page.click('[data-test="position-Big Ten"]')
    await page.click('[data-test="confirm-assignment"]')

    // Verify roster updated
    await expect(page.locator('[data-test="roster-Big Ten-1"]')).toContainText('Ohio State')
  })

  test('user cannot bid more than maxBid', async ({ page }) => {
    // Setup: Join as team with low budget
    await joinAsTeam(page, 'Team 2', 50)  // $50 budget, 2 slots = maxBid $49

    // Another team nominates
    await simulateNomination('Team 1', 'Alabama')

    // Try to bid $50 (exceeds maxBid of $49)
    await page.fill('[data-test="custom-bid"]', '50')
    await page.click('[data-test="place-bid"]')

    // Should show error
    await expect(page.locator('[data-test="bid-error"]')).toContainText('exceeds your maximum')
  })
})
```

---

## Critical Paths (Must Have Tests)

These are the bugs from the previous implementation that **must** have tests before any code is written.

### 1. Budget Calculation Edge Cases

| Scenario | Expected Behavior | Test Name |
|----------|-------------------|-----------|
| 1 slot remaining | MaxBid = full remaining budget | `maxBid_oneSlotRemaining_returnsFullBudget` |
| 0 slots remaining | MaxBid = 0 (roster full) | `maxBid_noSlotsRemaining_returnsZero` |
| Budget < remaining slots | MaxBid = 0 (can't fill roster) | `maxBid_insufficientBudget_returnsZero` |
| Exactly enough budget | MaxBid = 1 (just enough) | `maxBid_exactBudget_returnsOne` |

### 2. Bid Validation

| Scenario | Expected Behavior | Test Name |
|----------|-------------------|-----------|
| Bid below current | Reject with BID_TOO_LOW | `placeBid_belowCurrent_rejects` |
| Bid equals current | Reject (must exceed) | `placeBid_equalsCurrent_rejects` |
| Bid exceeds maxBid | Reject with BID_EXCEEDS_MAX | `placeBid_exceedsMax_rejects` |
| Bid exactly maxBid | Accept | `placeBid_exactlyMax_accepts` |
| Non-numeric bid | Reject with validation error | `placeBid_nonNumeric_rejects` |

### 3. Turn Advancement

| Scenario | Expected Behavior | Test Name |
|----------|-------------------|-----------|
| User roster full | Skip to next user | `advanceTurn_rosterFull_skipsUser` |
| User budget $0 | Skip to next user | `advanceTurn_zeroBudget_skipsUser` |
| All users full | End auction | `advanceTurn_allFull_endsAuction` |
| Round complete | Reset nomination flags, start new round | `advanceTurn_roundComplete_resetsFlags` |

### 4. Concurrent Operations

| Scenario | Expected Behavior | Test Name |
|----------|-------------------|-----------|
| Simultaneous bids | Only highest wins, others rejected | `concurrentBids_highestWins` |
| Simultaneous passes | Bidding ends once, not multiple times | `concurrentPasses_endsOnce` |
| Bid during pass processing | Consistent state | `bidDuringPass_consistentState` |

### 5. Position Assignment

| Scenario | Expected Behavior | Test Name |
|----------|-------------------|-----------|
| School to wrong position | Reject with INVALID_POSITION | `assignPosition_wrongPosition_rejects` |
| School to flex | Accept (flex takes any) | `assignPosition_flex_acceptsAny` |
| Position slot full | Reject with SLOT_FULL | `assignPosition_slotFull_rejects` |
| Auto-assign prefers specific | Choose SEC slot before Flex for SEC school | `autoAssign_prefersSpecific` |

---

## Test Infrastructure

### Local Setup

```bash
# Install dependencies
npm install

# Start Supabase local
supabase start

# Run database tests
supabase test db

# Run unit tests
npm run test:unit

# Run integration tests
npm run test:integration

# Run e2e tests
npm run test:e2e

# Run all tests
npm test
```

### Pre-Commit Hook

```bash
#!/bin/sh
# .husky/pre-commit

# Run unit tests
npm run test:unit -- --run

# Type check
npm run typecheck

# Lint
npm run lint

# If any command fails, abort commit
```

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Start Supabase
        run: |
          npx supabase start
          npx supabase db reset

      - name: Run unit tests
        run: npm run test:unit -- --coverage

      - name: Run database tests
        run: npx supabase test db

      - name: Run integration tests
        run: npm run test:integration

      - name: Run e2e tests
        run: npm run test:e2e

      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## Test Naming Conventions

### Format

```
[unit/method]_[scenario]_[expectedResult]
```

### Examples

```typescript
// Good
calculateMaxBid_oneSlotRemaining_returnsFullBudget()
placeBid_exceedsMaxBid_rejectsWithError()
advanceTurn_userRosterFull_skipsToNextUser()

// Bad
testBudget()  // What about budget?
bidTest1()    // Meaningless
shouldWork()  // What should work?
```

### File Naming

```
src/utils/budget.ts        → src/utils/budget.test.ts
src/components/BidCard.vue → src/components/BidCard.test.ts
supabase/functions/place-bid/index.ts → supabase/functions/place-bid/index.test.ts
```

---

## Test Data Management

### Seed Scripts

```typescript
// scripts/seed-test-data.ts
import { createClient } from '@supabase/supabase-js'

export async function seedTestAuction(options: {
  teams?: number
  schools?: number
  budget?: number
}) {
  const { teams = 6, schools = 50, budget = 200 } = options

  // Create auction
  const auction = await supabase
    .from('auctions')
    .insert({ join_code: generateCode(), name: 'Test Auction', status: 'draft' })
    .select()
    .single()

  // Create teams
  for (let i = 1; i <= teams; i++) {
    await supabase.from('teams').insert({
      auction_id: auction.id,
      team_name: `Team ${i}`,
      budget,
      remaining_budget: budget,
      nomination_order: i
    })
  }

  // Create schools
  // ... etc

  return auction
}
```

### Cleanup

```typescript
// After each test
afterEach(async () => {
  await supabase.rpc('cleanup_test_data')
})
```

```sql
-- supabase/migrations/xxx_cleanup_function.sql
CREATE OR REPLACE FUNCTION cleanup_test_data()
RETURNS void AS $$
BEGIN
  DELETE FROM auctions WHERE join_code LIKE 'TEST%';
END;
$$ LANGUAGE plpgsql;
```

---

## Coverage Requirements

| Area | Minimum Coverage | Notes |
|------|-----------------|-------|
| Budget calculations | 100% | Critical business logic |
| Bid validation | 100% | Money operations |
| Position eligibility | 100% | Core auction mechanic |
| Edge Functions | 90% | Server-side validation |
| Vue components | 70% | Focus on interactive elements |
| Utility functions | 80% | General coverage |

### Coverage Commands

```bash
# Generate coverage report
npm run test:unit -- --coverage

# View HTML report
open coverage/index.html
```

---

## Bug Fix Protocol

When a bug is reported:

1. **Create failing test** that reproduces the bug
2. **Verify test fails** with current code
3. **Fix the bug**
4. **Verify test passes**
5. **Commit test and fix together**

```bash
# Example commit message
git commit -m "Fix: Budget calculation wrong with 1 slot remaining

Added test: maxBid_oneSlotRemaining_returnsFullBudget
The formula was subtracting 1 even when only 1 slot remained,
resulting in maxBid being $1 less than actual remaining budget.

Fixes #42"
```

---

## Documentation Updates

Each test file should have a header comment explaining what it tests:

```typescript
/**
 * Budget Calculation Tests
 *
 * Tests the MaxBid formula: MaxBid = RemainingBudget - (RemainingSlots - 1)
 *
 * Critical edge cases:
 * - Last slot gets full budget (no reservation needed)
 * - Zero slots means maxBid = 0
 * - Insufficient budget for remaining slots
 *
 * Related: PRODUCT-DESIGN.md#business-rules
 */
```

When tests change, update related documentation in same commit.
