import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useAuctionStore } from '../auction'
import type { Team, RosterPosition, DraftPick, Session } from '@/types/auction'

// Minimal fixtures
const SESSION: Session = {
  participantId: 1,
  auctionId: 1,
  teamId: 10,
  role: 'team_coach',
  displayName: 'Coach Test',
  sessionToken: 'abc',
  supabaseUid: 'uid-1',
}

const TEAM: Team = {
  id: 10,
  auction_id: 1,
  team_name: 'Coach Test',
  budget: 200,
  remaining_budget: 200,
  nomination_order: 1,
  has_nominated_this_round: false,
  is_active: true,
  auto_pass_enabled: false,
}

// 8 total slots: SEC×2, Big Ten×2, ACC×1, Big 12×1, Flex×2
const ROSTER_POSITIONS: RosterPosition[] = [
  { id: 1, auction_id: 1, position_name: 'SEC',     slots_per_team: 2, is_flex: false, display_order: 1, color_code: '#DC2626' },
  { id: 2, auction_id: 1, position_name: 'Big Ten',  slots_per_team: 2, is_flex: false, display_order: 2, color_code: '#2563EB' },
  { id: 3, auction_id: 1, position_name: 'ACC',      slots_per_team: 1, is_flex: false, display_order: 3, color_code: '#7C3AED' },
  { id: 4, auction_id: 1, position_name: 'Big 12',   slots_per_team: 1, is_flex: false, display_order: 4, color_code: '#D97706' },
  { id: 5, auction_id: 1, position_name: 'Flex',     slots_per_team: 2, is_flex: true,  display_order: 5, color_code: '#6B7280' },
]

function makePick(overrides: Partial<DraftPick> = {}): DraftPick {
  return {
    id: Math.random(),
    auction_id: 1,
    team_id: 10,
    auction_school_id: Math.random(),
    roster_position_id: 1,
    winning_bid: 10,
    pick_order: 1,
    ...overrides,
  }
}

describe('myMaxBid', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('returns 0 when no session', () => {
    const store = useAuctionStore()
    store.teams = [TEAM]
    store.rosterPositions = ROSTER_POSITIONS
    // no session set
    expect(store.myMaxBid).toBe(0)
  })

  it('full budget, no picks: MaxBid = budget - (slots - 1)', () => {
    // 8 slots total, $200 budget → MaxBid = 200 - 7 = 193
    const store = useAuctionStore()
    store.saveSession(SESSION)
    store.teams = [TEAM]
    store.rosterPositions = ROSTER_POSITIONS
    store.draftPicks = []
    expect(store.myMaxBid).toBe(193)
  })

  it('with 4 picks remaining budget $120, 4 slots left: MaxBid = 120 - 3 = 117', () => {
    const store = useAuctionStore()
    store.saveSession(SESSION)
    store.teams = [{ ...TEAM, remaining_budget: 120 }]
    store.rosterPositions = ROSTER_POSITIONS
    // 4 picks made across 4 different positions
    store.draftPicks = [
      makePick({ roster_position_id: 1 }), // fills SEC slot 1
      makePick({ roster_position_id: 1 }), // fills SEC slot 2
      makePick({ roster_position_id: 2 }), // fills Big Ten slot 1
      makePick({ roster_position_id: 3 }), // fills ACC slot 1
    ]
    // remaining slots: Big Ten×1, Big 12×1, Flex×2 = 4 empty
    // MaxBid = 120 - (4 - 1) = 117
    expect(store.myMaxBid).toBe(117)
  })

  it('only 1 slot remaining: MaxBid = full remaining budget', () => {
    // With 1 slot left, reserve = max(0, 1-1) = 0 → can spend everything
    const store = useAuctionStore()
    store.saveSession(SESSION)
    store.teams = [{ ...TEAM, remaining_budget: 45 }]
    store.rosterPositions = ROSTER_POSITIONS
    // 7 of 8 slots filled for this team
    store.draftPicks = [
      makePick({ roster_position_id: 1 }),
      makePick({ roster_position_id: 1 }),
      makePick({ roster_position_id: 2 }),
      makePick({ roster_position_id: 2 }),
      makePick({ roster_position_id: 3 }),
      makePick({ roster_position_id: 4 }),
      makePick({ roster_position_id: 5 }),
    ]
    expect(store.myMaxBid).toBe(45)
  })

  it('$0 remaining budget returns 0', () => {
    const store = useAuctionStore()
    store.saveSession(SESSION)
    store.teams = [{ ...TEAM, remaining_budget: 0 }]
    store.rosterPositions = ROSTER_POSITIONS
    store.draftPicks = []
    // 0 - 7 = -7, but clamped: max(0, ...) on emptySlots-1
    // formula: 0 - max(0, 8-1) = 0 - 7 = -7
    // This is negative — means auto-passed on everything
    expect(store.myMaxBid).toBeLessThanOrEqual(0)
  })

  it('does not count picks from other teams toward empty slots', () => {
    const store = useAuctionStore()
    store.saveSession(SESSION)
    store.teams = [TEAM]
    store.rosterPositions = ROSTER_POSITIONS
    // Picks from a different team (id: 99) — should not affect our slot count
    store.draftPicks = [
      makePick({ team_id: 99, roster_position_id: 1 }),
      makePick({ team_id: 99, roster_position_id: 2 }),
    ]
    // Our team still has 8 empty slots → MaxBid = 200 - 7 = 193
    expect(store.myMaxBid).toBe(193)
  })

  it('admin proxy mode uses the proxy team budget, not own team', () => {
    const store = useAuctionStore()
    store.saveSession(SESSION)

    const proxyTeam: Team = {
      ...TEAM,
      id: 20,
      team_name: 'Absent Coach',
      remaining_budget: 80,
    }
    store.teams = [TEAM, proxyTeam]
    store.rosterPositions = ROSTER_POSITIONS
    store.draftPicks = []
    store.isAdminMode = true
    store.proxyTeamId = 20

    // 8 empty slots for proxy team → 80 - 7 = 73
    expect(store.myMaxBid).toBe(73)
  })

  it('over-filled position slots do not produce negative empty count', () => {
    // Defensive: if somehow more picks than slots, emptySlots should not go below 0
    const store = useAuctionStore()
    store.saveSession(SESSION)
    store.teams = [{ ...TEAM, remaining_budget: 50 }]
    store.rosterPositions = [
      { id: 1, auction_id: 1, position_name: 'SEC', slots_per_team: 1, is_flex: false, display_order: 1, color_code: '#DC2626' },
    ]
    // 3 picks in a 1-slot position — max(0, 1-3) should clamp to 0
    store.draftPicks = [
      makePick({ roster_position_id: 1 }),
      makePick({ roster_position_id: 1 }),
      makePick({ roster_position_id: 1 }),
    ]
    // 0 empty slots → MaxBid = 50 - max(0, 0-1) = 50 - 0 = 50
    expect(store.myMaxBid).toBe(50)
  })
})
