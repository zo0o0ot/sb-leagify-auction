import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabase'
import type {
  Auction,
  Team,
  Participant,
  AuctionSchool,
  DraftPick,
  RosterPosition,
  BidHistory,
  Session,
} from '@/types/auction'

export const useAuctionStore = defineStore('auction', () => {
  // ── State ──────────────────────────────────────────────────────────────────
  const session = ref<Session | null>(null)
  const auction = ref<Auction | null>(null)
  const teams = ref<Team[]>([])
  const participants = ref<Participant[]>([])
  const schools = ref<AuctionSchool[]>([])
  const draftPicks = ref<DraftPick[]>([])
  const rosterPositions = ref<RosterPosition[]>([])
  const bidHistory = ref<BidHistory[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  const isAdminMode = ref(false)
  const proxyTeamId = ref<number | null>(null)

  // ── Computed ───────────────────────────────────────────────────────────────
  const myTeam = computed(() =>
    session.value ? teams.value.find((t) => t.id === session.value!.teamId) ?? null : null,
  )

  const myParticipant = computed(() =>
    session.value
      ? participants.value.find((p) => p.id === session.value!.participantId) ?? null
      : null,
  )

  const isAuctionMaster = computed(() => session.value?.role === 'auction_master')

  const availableSchools = computed(() => schools.value.filter((s) => s.is_available))

  const currentNominator = computed(() =>
    auction.value?.current_nominator_id
      ? participants.value.find((p) => p.id === auction.value!.current_nominator_id) ?? null
      : null,
  )

  const currentHighBidder = computed(() =>
    auction.value?.current_high_bidder_id
      ? teams.value.find((t) => t.id === auction.value!.current_high_bidder_id) ?? null
      : null,
  )

  const activeTeam = computed(() =>
    isAdminMode.value && proxyTeamId.value
      ? teams.value.find((t) => t.id === proxyTeamId.value) ?? myTeam.value
      : myTeam.value,
  )

  const myMaxBid = computed(() => {
    const team = activeTeam.value
    if (!team) return 0
    const emptySlots = rosterPositions.value.reduce((sum, rp) => {
      const filled = draftPicks.value.filter(
        (dp) => dp.team_id === team.id && dp.roster_position_id === rp.id,
      ).length
      return sum + Math.max(0, rp.slots_per_team - filled)
    }, 0)
    return team.remaining_budget - Math.max(0, emptySlots - 1)
  })

  const allCoachesReady = computed(() =>
    participants.value
      .filter((p) => p.role === 'team_coach')
      .every((p) => p.is_connected && p.is_ready),
  )

  // ── Session ────────────────────────────────────────────────────────────────
  function saveSession(s: Session) {
    session.value = s
    localStorage.setItem('auction_session', JSON.stringify(s))
  }

  function clearSession() {
    session.value = null
    localStorage.removeItem('auction_session')
  }

  function loadSession(): Session | null {
    const raw = localStorage.getItem('auction_session')
    if (!raw) return null
    try {
      const s = JSON.parse(raw) as Session
      session.value = s
      return s
    } catch {
      return null
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  async function loadAuction(auctionId: number) {
    loading.value = true
    error.value = null

    const [auctionRes, teamsRes, participantsRes, schoolsRes, picksRes, positionsRes] =
      await Promise.all([
        supabase.from('auctions').select('*').eq('id', auctionId).single(),
        supabase.from('teams').select('*').eq('auction_id', auctionId).order('nomination_order'),
        supabase.from('participants').select('*').eq('auction_id', auctionId),
        supabase
          .from('auction_schools')
          .select('*, school:schools(*)')
          .eq('auction_id', auctionId),
        supabase.from('draft_picks').select('*, auction_school:auction_schools(*, school:schools(*))').eq('auction_id', auctionId),
        supabase.from('roster_positions').select('*').eq('auction_id', auctionId).order('display_order'),
      ])

    if (auctionRes.error) { error.value = auctionRes.error.message; loading.value = false; return }

    auction.value = auctionRes.data
    teams.value = teamsRes.data ?? []
    participants.value = participantsRes.data ?? []
    schools.value = schoolsRes.data ?? []
    draftPicks.value = picksRes.data ?? []
    rosterPositions.value = positionsRes.data ?? []
    loading.value = false
  }

  // ── Realtime mutations (called from subscription handlers) ─────────────────
  function updateAuction(data: Auction) {
    auction.value = data
  }

  function updateParticipant(data: Participant) {
    const idx = participants.value.findIndex((p) => p.id === data.id)
    if (idx >= 0) participants.value[idx] = data
    else participants.value.push(data)
  }

  function addBid(data: BidHistory) {
    bidHistory.value.unshift(data)
  }

  function updateDraftPick(data: DraftPick) {
    const idx = draftPicks.value.findIndex((p) => p.id === data.id)
    if (idx >= 0) draftPicks.value[idx] = data
    else draftPicks.value.push(data)
  }

  function markSchoolUnavailable(auctionSchoolId: number) {
    const s = schools.value.find((s) => s.id === auctionSchoolId)
    if (s) s.is_available = false
  }

  function updateTeamBudget(teamId: number, remainingBudget: number) {
    const team = teams.value.find((t) => t.id === teamId)
    if (team) team.remaining_budget = remainingBudget
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  async function setReady(ready: boolean) {
    if (!session.value) return
    await supabase
      .from('participants')
      .update({ is_ready: ready })
      .eq('id', session.value.participantId)
  }

  async function placeBid(amount: number) {
    if (!auction.value || !session.value) return { error: 'Not in auction' }
    const teamId = activeTeam.value?.id
    const { data, error } = await supabase.functions.invoke('place-bid', {
      body: {
        auction_id: auction.value.id,
        participant_id: session.value.participantId,
        team_id: teamId,
        amount,
        on_behalf_of_team_id: isAdminMode.value && proxyTeamId.value !== teamId ? proxyTeamId.value : null,
      },
    })
    if (error) return { error: error.message }
    if (data?.ok === false) return { error: data.error ?? 'Bid failed' }
    return { data }
  }

  async function pass() {
    if (!auction.value || !session.value) return { error: 'Not in auction' }
    const { data, error } = await supabase.functions.invoke('pass-bid', {
      body: {
        auction_id: auction.value.id,
        participant_id: session.value.participantId,
        team_id: activeTeam.value?.id,
      },
    })
    if (error) return { error: error.message }
    if (data?.ok === false) return { error: data.error ?? 'Pass failed' }
    return { data }
  }

  async function nominateSchool(auctionSchoolId: number) {
    if (!auction.value || !session.value) return { error: 'Not in auction' }
    const { data, error } = await supabase.functions.invoke('nominate-school', {
      body: {
        auction_id: auction.value.id,
        participant_id: session.value.participantId,
        team_id: activeTeam.value?.id,
        auction_school_id: auctionSchoolId,
      },
    })
    if (error) return { error: error.message }
    return { data }
  }

  async function assignPosition(draftPickId: number, rosterPositionId: number) {
    const { error } = await supabase
      .from('draft_picks')
      .update({ roster_position_id: rosterPositionId })
      .eq('id', draftPickId)
    if (error) return { error: error.message }
    return {}
  }

  async function completeBid() {
    if (!auction.value) return { error: 'Not in auction' }
    const { data, error } = await supabase.functions.invoke('complete-bid', {
      body: { auction_id: auction.value.id },
    })
    if (error) return { error: error.message }
    return { data }
  }

  async function setAuctionStatus(status: Auction['status']) {
    if (!auction.value) return
    await supabase.from('auctions').update({ status }).eq('id', auction.value.id)
  }

  return {
    // state
    session,
    auction,
    teams,
    participants,
    schools,
    draftPicks,
    rosterPositions,
    bidHistory,
    loading,
    error,
    isAdminMode,
    proxyTeamId,
    // computed
    myTeam,
    myParticipant,
    isAuctionMaster,
    availableSchools,
    currentNominator,
    currentHighBidder,
    activeTeam,
    myMaxBid,
    allCoachesReady,
    // session
    saveSession,
    clearSession,
    loadSession,
    // data
    loadAuction,
    // mutations
    updateAuction,
    updateParticipant,
    addBid,
    updateDraftPick,
    markSchoolUnavailable,
    updateTeamBudget,
    // actions
    setReady,
    placeBid,
    pass,
    completeBid,
    nominateSchool,
    assignPosition,
    setAuctionStatus,
  }
})
