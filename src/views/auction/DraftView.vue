<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuctionStore } from '@/stores/auction'
import { useAuctionRealtime } from '@/composables/useAuctionRealtime'
import AppShell from '@/components/AppShell.vue'
import NominationGrid from '@/components/draft/NominationGrid.vue'
import PickIsInSting from '@/components/draft/PickIsInSting.vue'
import PositionAssignmentModal from '@/components/draft/PositionAssignmentModal.vue'
import ConnectionLostOverlay from '@/components/draft/ConnectionLostOverlay.vue'
import type { DraftPick } from '@/types/auction'

const route = useRoute()
const store = useAuctionStore()
const auctionId = Number(route.params.id)

const { isConnected } = useAuctionRealtime(auctionId)

// Suppress the connection overlay during the initial subscription handshake.
// Navigating from Lobby tears down the old channel before the new one confirms,
// causing a false "disconnected" flash. 5s is ample for the handshake to complete.
const connectionReady = ref(false)
onMounted(() => {
  setTimeout(() => {
    connectionReady.value = true
  }, 5000)
})

// ── UI State ────────────────────────────────────────────────────────────────
const showNominationGrid = ref(false)
const pendingAssignmentPick = ref<DraftPick | null>(null)
const submitting = ref(false)
const bidError = ref('')
const customBidAmount = ref('')

// Admin mode UI
const localAdminMode = ref(false)
const localProxyTeamId = ref<number | null>(null)
const autoPassTeamIds = ref<Set<number>>(new Set())

// Admin manual pick entry
const manualSchoolId = ref<number | null>(null)
const manualTeamId = ref<number | null>(null)
const manualAmount = ref('')
const manualError = ref('')
const manualSubmitting = ref(false)

// ── Derived state ────────────────────────────────────────────────────────────
const isAdmin = computed(() => store.isAuctionMaster)

const currentSchool = computed(() => {
  if (!store.auction?.current_school_id) return null
  return store.schools.find((s) => s.id === store.auction!.current_school_id) ?? null
})

const currentHighBid = computed(() => store.auction?.current_high_bid ?? 0)
const nextMinBid = computed(() => currentHighBid.value + 1)
const maxBid = computed(() => store.myMaxBid)
const isAutoPass = computed(() => maxBid.value < nextMinBid.value)
const isHighBidder = computed(() => store.activeTeam?.id === store.auction?.current_high_bidder_id)

const myRosterFull = computed(() => {
  const team = store.activeTeam
  if (!team) return false
  const totalSlots = store.rosterPositions.reduce((sum, rp) => sum + rp.slots_per_team, 0)
  return store.draftPicks.filter((p) => p.team_id === team.id).length >= totalSlots
})

const totalDraftSlots = computed(() => {
  const slotsPerTeam = store.rosterPositions.reduce((sum, rp) => sum + rp.slots_per_team, 0)
  return slotsPerTeam * store.teams.filter((t) => t.is_active).length
})

const isMyTurnToNominate = computed(
  () => !myRosterFull.value && store.auction?.current_nominator_id === store.myParticipant?.id,
)

const nominationOrder = computed(() =>
  store.teams.filter((t) => t.is_active).sort((a, b) => a.nomination_order - b.nomination_order),
)

const recentBids = computed(() => store.bidHistory.slice(0, 10))

const currentNominatorName = computed(() => {
  if (!store.auction?.current_school_id) return null
  const nomination = store.bidHistory.find(
    (b) => b.auction_school_id === store.auction!.current_school_id && b.bid_type === 'nomination',
  )
  if (!nomination) return null
  const participant = store.participants.find((p) => p.id === nomination.participant_id)
  return participant?.display_name ?? null
})

// All picks missing a roster position — admin safety net
const unassignedPicks = computed(() => store.draftPicks.filter((p) => !p.roster_position_id))

// ── Post-draft assignment ─────────────────────────────────────────────────────
const assignSchoolId = ref<number | null>(null)
const assignTeamId = ref<number | null>(null)
const assignPositionId = ref<number | null>(null)
const assignPrice = ref('0')
const assignSubmitting = ref(false)
const assignError = ref('')

const teamsWithOpenSlots = computed(() => {
  const slotsPerTeam = store.rosterPositions.reduce((sum, rp) => sum + rp.slots_per_team, 0)
  return store.teams
    .filter((t) => t.is_active)
    .map((t) => ({
      ...t,
      openSlots: slotsPerTeam - store.draftPicks.filter((p) => p.team_id === t.id).length,
    }))
    .filter((t) => t.openSlots > 0)
    .sort((a, b) => a.nomination_order - b.nomination_order)
})

const openPositionsForAssignTeam = computed(() => {
  if (!assignTeamId.value) return []
  return store.rosterPositions.filter((rp) => {
    const filled = store.draftPicks.filter(
      (p) => p.team_id === assignTeamId.value && p.roster_position_id === rp.id,
    ).length
    return filled < rp.slots_per_team
  })
})

watch(assignTeamId, () => {
  assignPositionId.value = null
})

// Transfer an existing pick from one team to another
const transferPickId = ref<number | null>(null)
const transferToTeamId = ref<number | null>(null)
const transferPositionId = ref<number | null>(null)
const transferSubmitting = ref(false)
const transferError = ref('')

const openPositionsForTransferTeam = computed(() => {
  if (!transferToTeamId.value) return []
  return store.rosterPositions.filter((rp) => {
    const filled = store.draftPicks.filter(
      (p) => p.team_id === transferToTeamId.value && p.roster_position_id === rp.id,
    ).length
    return filled < rp.slots_per_team
  })
})

watch(transferToTeamId, () => {
  transferPositionId.value = null
})

async function transferPick() {
  if (!transferPickId.value || !transferToTeamId.value) {
    transferError.value = 'Select a pick and a destination team'
    return
  }
  transferError.value = ''
  transferSubmitting.value = true

  const pick = store.draftPicks.find((p) => p.id === transferPickId.value)
  if (!pick) {
    transferError.value = 'Pick not found'
    transferSubmitting.value = false
    return
  }

  // Refund the bid amount to the original team, charge the new team
  const [origTeam, destTeam] = [
    store.teams.find((t) => t.id === pick.team_id),
    store.teams.find((t) => t.id === transferToTeamId.value),
  ]

  const { error: pickErr } = await supabase
    .from('draft_picks')
    .update({
      team_id: transferToTeamId.value,
      roster_position_id: transferPositionId.value ?? null,
    })
    .eq('id', transferPickId.value)

  if (pickErr) {
    transferError.value = pickErr.message
    transferSubmitting.value = false
    return
  }

  // Adjust budgets: refund original team, deduct from new team
  if (origTeam && pick.winning_bid) {
    await supabase
      .from('teams')
      .update({ remaining_budget: origTeam.remaining_budget + (pick.winning_bid ?? 0) })
      .eq('id', origTeam.id)
  }
  if (destTeam && pick.winning_bid) {
    await supabase
      .from('teams')
      .update({ remaining_budget: destTeam.remaining_budget - (pick.winning_bid ?? 0) })
      .eq('id', destTeam.id)
  }

  transferPickId.value = null
  transferToTeamId.value = null
  transferPositionId.value = null
  transferSubmitting.value = false
}

async function directAssign() {
  if (!assignSchoolId.value || !assignTeamId.value || !assignPositionId.value) {
    assignError.value = 'Select a school, team, and position'
    return
  }
  assignError.value = ''
  assignSubmitting.value = true

  const price = Math.max(0, parseInt(assignPrice.value) || 0)
  const pickOrder = store.draftPicks.length + 1

  const { error: pickErr } = await supabase.from('draft_picks').insert({
    auction_id: auctionId,
    team_id: assignTeamId.value,
    auction_school_id: assignSchoolId.value,
    roster_position_id: assignPositionId.value,
    winning_bid: price,
    pick_order: pickOrder,
    won_by_id: null,
  })

  if (pickErr) {
    assignError.value = pickErr.message
    assignSubmitting.value = false
    return
  }

  await supabase
    .from('auction_schools')
    .update({ is_available: false })
    .eq('id', assignSchoolId.value)

  if (price > 0) {
    const team = store.teams.find((t) => t.id === assignTeamId.value)
    if (team) {
      await supabase
        .from('teams')
        .update({ remaining_budget: team.remaining_budget - price })
        .eq('id', assignTeamId.value)
    }
  }

  assignSchoolId.value = null
  assignTeamId.value = null
  assignPositionId.value = null
  assignPrice.value = '0'
  assignSubmitting.value = false
}

// Watch for new picks that need position assignment.
// Coaches: only their own team's picks. Admin (with proxy): proxy team's picks.
// Admin (no proxy): any unassigned pick — so admin can always step in.
watch(
  () => store.draftPicks,
  (picks) => {
    const myTeamId = store.activeTeam?.id
    let unassigned: (typeof picks)[0] | undefined
    if (myTeamId) {
      unassigned = picks.find((p) => p.team_id === myTeamId && !p.roster_position_id)
    } else if (isAdmin.value && localAdminMode.value) {
      unassigned = picks.find((p) => !p.roster_position_id)
    }
    if (unassigned && unassigned.id !== pendingAssignmentPick.value?.id) {
      pendingAssignmentPick.value = unassigned
    }
  },
  { deep: true, immediate: true },
)

// Sync admin mode to store
watch(localAdminMode, (v) => {
  store.isAdminMode = v
})
watch(localProxyTeamId, (v) => {
  store.proxyTeamId = v
})

// Auto-pass: when a new school comes on the block, immediately pass for:
//   1. Admin-proxied teams that have auto-pass ticked
//   2. The current coach if their budget is too low or their roster is full
watch(
  () => store.auction?.current_school_id,
  async (schoolId) => {
    if (!schoolId) return

    // Admin-proxied auto-pass
    if (localAdminMode.value) {
      for (const teamId of autoPassTeamIds.value) {
        const participant = store.participants.find((p) => p.team_id === teamId)
        if (!participant || teamId === store.auction?.current_high_bidder_id) continue
        await supabase.functions.invoke('pass-bid', {
          body: {
            auction_id: store.auction!.id,
            participant_id: participant.id,
            team_id: teamId,
          },
        })
      }
    }

    // Coach auto-pass: can't afford the minimum bid or roster is already full
    const me = store.myParticipant
    const myTeam = store.activeTeam
    if (
      me &&
      myTeam &&
      !isAdmin.value &&
      myTeam.id !== store.auction?.current_high_bidder_id &&
      (myRosterFull.value || isAutoPass.value)
    ) {
      await supabase.functions.invoke('pass-bid', {
        body: {
          auction_id: store.auction!.id,
          participant_id: me.id,
          team_id: myTeam.id,
        },
      })
    }
  },
)

function toggleAutoPass(teamId: number) {
  const next = new Set(autoPassTeamIds.value)
  if (next.has(teamId)) next.delete(teamId)
  else next.add(teamId)
  autoPassTeamIds.value = next
}

// ── Actions ──────────────────────────────────────────────────────────────────
async function bid(delta: number) {
  const amount = nextMinBid.value - 1 + delta
  if (amount > maxBid.value) return
  bidError.value = ''
  submitting.value = true
  const result = await store.placeBid(amount)
  if (result?.error) bidError.value = result.error
  submitting.value = false
}

async function submitCustomBid() {
  const amount = parseInt(customBidAmount.value, 10)
  if (isNaN(amount) || amount < nextMinBid.value) {
    bidError.value = `Minimum bid is $${nextMinBid.value}`
    return
  }
  if (amount > maxBid.value) {
    bidError.value = `Cannot exceed max bid of $${maxBid.value}`
    return
  }
  bidError.value = ''
  submitting.value = true
  const result = await store.placeBid(amount)
  if (result?.error) bidError.value = result.error
  else customBidAmount.value = ''
  submitting.value = false
}

async function pass() {
  submitting.value = true
  bidError.value = ''
  const result = await store.pass()
  if (result?.error) bidError.value = result.error
  submitting.value = false
}

async function forceEndBidding() {
  if (!store.auction) return
  submitting.value = true
  await store.completeBid()
  submitting.value = false
}

function onStingDismissed() {
  // Position assignment modal will appear via the watcher
}

function onPositionAssigned() {
  pendingAssignmentPick.value = null
}

function retryConnection() {
  window.location.reload()
}

function participantFor(teamId: number) {
  return store.participants.find((p) => p.team_id === teamId) ?? null
}

async function manualRecordPick() {
  if (!manualSchoolId.value || !manualTeamId.value) return
  const amount = parseInt(manualAmount.value, 10)
  if (isNaN(amount) || amount < 1) {
    manualError.value = 'Enter a valid bid amount'
    return
  }
  if (store.auction?.current_school_id) {
    manualError.value = 'A school is already on the block. Use Force End Bidding first.'
    return
  }
  manualError.value = ''
  manualSubmitting.value = true

  // Step 1: put the school on the block with the winning bid already set
  const { error: e1 } = await supabase
    .from('auctions')
    .update({
      current_school_id: manualSchoolId.value,
      current_high_bid: amount,
      current_high_bidder_id: manualTeamId.value,
    })
    .eq('id', auctionId)

  if (e1) {
    manualError.value = e1.message
    manualSubmitting.value = false
    return
  }

  // Step 2: complete-bid reads auction state and creates the pick
  const result = await store.completeBid()
  if (result?.error) {
    manualError.value = result.error
    manualSubmitting.value = false
    return
  }

  manualSchoolId.value = null
  manualTeamId.value = null
  manualAmount.value = ''
  manualSubmitting.value = false
}

function budgetPct(team: (typeof store.teams)[0]) {
  if (!store.auction) return 0
  return Math.round((team.remaining_budget / store.auction.default_budget) * 100)
}

function bidderNameFor(bid: (typeof store.bidHistory)[0]) {
  if (!bid.team_id) return 'Unknown'
  return store.getTeamDisplayName(bid.team_id)
}
</script>

<template>
  <AppShell>
    <!-- Nav -->
    <template #nav>
      <span class="text-primary border-b-2 border-primary pb-1">WAR ROOM</span>
      <span class="text-on-surface-variant opacity-50 cursor-help" title="Coming soon"
        >AUCTION</span
      >
      <span class="text-on-surface-variant opacity-50 cursor-help" title="Coming soon"
        >SCHOOLS</span
      >
      <RouterLink
        :to="`/auction/${auctionId}/roster`"
        class="text-on-surface-variant hover:text-on-surface"
        >ROSTERS</RouterLink
      >
    </template>

    <!-- Header actions -->
    <template #header-actions>
      <div class="flex items-center gap-3">
        <!-- Admin mode toggle -->
        <button
          v-if="isAdmin"
          class="flex items-center gap-2 px-3 py-1 border text-[10px] font-label font-black uppercase transition-colors"
          :class="
            localAdminMode
              ? 'bg-secondary-container/20 border-secondary/30 text-secondary'
              : 'bg-surface-container border-outline/20 text-outline'
          "
          @click="localAdminMode = !localAdminMode"
        >
          <span class="material-symbols-outlined text-sm">security</span>
          {{ localAdminMode ? 'ADMIN MODE' : 'ADMIN OFF' }}
        </button>

        <!-- Status badge -->
        <div
          class="flex items-center gap-2 px-3 py-1 bg-surface-container border border-outline/20"
        >
          <span
            class="w-2 h-2 rounded-full"
            :class="
              store.auction?.status === 'in_progress' ? 'bg-tertiary animate-pulse' : 'bg-outline'
            "
          ></span>
          <span class="text-[10px] font-label font-black uppercase text-on-surface-variant">
            {{ store.auction?.status?.replace('_', ' ').toUpperCase() ?? 'LOADING' }}
          </span>
        </div>
      </div>
    </template>

    <!-- Sidebar header -->
    <template #sidebar-header>
      <div class="flex items-center gap-3">
        <div
          class="w-12 h-12 bg-surface-container-highest flex items-center justify-center border border-primary/20"
        >
          <span class="material-symbols-outlined text-primary text-3xl">gavel</span>
        </div>
        <div>
          <div class="text-on-surface text-sm tracking-tight">
            {{
              isAdmin
                ? 'COMMANDER'
                : store.activeTeam
                  ? store.getTeamDisplayName(store.activeTeam.id)
                  : 'COACH'
            }}
          </div>
          <div class="text-primary text-xs">
            BUDGET: ${{ store.activeTeam?.remaining_budget ?? '—' }}
          </div>
        </div>
      </div>
    </template>

    <!-- Sidebar nav -->
    <template #sidebar-nav>
      <a
        class="flex items-center px-6 py-4 bg-gradient-to-r from-primary/20 to-transparent text-primary border-l-4 border-primary"
      >
        <span class="material-symbols-outlined mr-4">gavel</span> WAR ROOM
      </a>
      <a
        class="flex items-center px-6 py-4 text-on-surface-variant opacity-50 cursor-help"
        title="Coming soon"
      >
        <span class="material-symbols-outlined mr-4">leaderboard</span> BOARD
      </a>
      <RouterLink
        :to="`/auction/${auctionId}/roster`"
        class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container"
      >
        <span class="material-symbols-outlined mr-4">groups</span> ROSTER
      </RouterLink>
      <a
        class="flex items-center px-6 py-4 text-on-surface-variant opacity-50 cursor-help"
        title="Coming soon"
      >
        <span class="material-symbols-outlined mr-4">history</span> HISTORY
      </a>
    </template>

    <!-- Sidebar footer -->
    <template #sidebar-footer>
      <!-- Nomination order -->
      <div class="p-4 space-y-2">
        <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">
          Nomination Order
        </div>
        <div
          v-for="(team, idx) in nominationOrder"
          :key="team.id"
          class="flex items-center gap-3 py-2 px-2 transition-colors"
          :class="
            participantFor(team.id)?.id === store.auction?.current_nominator_id
              ? 'bg-secondary-container/20 border-l-2 border-secondary'
              : ''
          "
        >
          <span class="text-[10px] font-label text-outline w-4">{{
            String(idx + 1).padStart(2, '0')
          }}</span>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-label font-bold text-on-surface truncate">
              {{ store.getTeamDisplayName(team.id) }}
            </div>
            <div class="text-[10px] font-label text-outline">${{ team.remaining_budget }}</div>
          </div>
          <span
            class="w-2 h-2 rounded-full flex-shrink-0"
            :class="participantFor(team.id)?.is_connected ? 'bg-green-500' : 'bg-red-500'"
          ></span>
        </div>
      </div>

      <!-- Admin: proxy bidding -->
      <div
        v-if="isAdmin && localAdminMode"
        class="p-4 border-t border-outline-variant/20 space-y-3"
      >
        <div class="text-[10px] font-label text-outline uppercase tracking-widest">
          Admin Override Bid
        </div>
        <select
          v-model="localProxyTeamId"
          class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label py-2 px-3 focus:outline-none focus:border-primary/50"
        >
          <option :value="null">SELECT COACH...</option>
          <option v-for="team in store.teams" :key="team.id" :value="team.id">
            {{ store.getTeamDisplayName(team.id) }} (${{ team.remaining_budget }})
          </option>
        </select>
        <div class="text-[10px] font-label text-outline uppercase">Auto-Pass</div>
        <div class="space-y-1">
          <label
            v-for="team in store.teams"
            :key="team.id"
            class="flex items-center justify-between py-1.5 px-2 hover:bg-surface-container cursor-pointer"
            :class="autoPassTeamIds.has(team.id) ? 'bg-secondary-container/10' : ''"
          >
            <span class="text-[10px] font-label text-on-surface-variant">{{
              store.getTeamDisplayName(team.id)
            }}</span>
            <input
              type="checkbox"
              class="accent-primary"
              :checked="autoPassTeamIds.has(team.id)"
              @change="toggleAutoPass(team.id)"
            />
          </label>
        </div>

        <!-- Admin auction controls -->
        <div class="pt-2 space-y-2 border-t border-outline-variant/20">
          <button
            class="w-full bg-error-container hover:bg-error/20 text-error text-[10px] py-2 border border-error/30 uppercase font-label"
            @click="store.setAuctionStatus('paused')"
          >
            <span class="material-symbols-outlined text-sm align-text-bottom mr-1"
              >pause_circle</span
            >
            PAUSE AUCTION
          </button>
          <button
            v-if="store.auction?.status === 'paused'"
            class="w-full bg-surface-container hover:bg-primary/10 text-primary text-[10px] py-2 border border-primary/30 uppercase font-label"
            @click="store.setAuctionStatus('in_progress')"
          >
            RESUME
          </button>
          <button
            class="w-full bg-surface-container hover:bg-tertiary/10 text-tertiary text-[10px] py-2 border border-tertiary/30 uppercase font-label"
            @click="forceEndBidding"
          >
            <span class="material-symbols-outlined text-sm align-text-bottom mr-1">gavel</span>
            FORCE END BIDDING
          </button>
        </div>
      </div>

      <!-- Coach: nominate button (when it's their turn and no school on block) -->
      <div
        v-if="!isAdmin && isMyTurnToNominate && !currentSchool"
        class="p-4 border-t border-outline-variant/20"
      >
        <button
          class="w-full metallic-secondary text-on-secondary py-4 font-headline font-black text-sm uppercase tracking-widest animate-pulse"
          @click="showNominationGrid = true"
        >
          <span class="material-symbols-outlined align-text-bottom mr-2">gavel</span>
          NOMINATE NOW
        </button>
      </div>
    </template>

    <!-- Ticker -->
    <template #ticker-status>
      {{
        store.auction?.status === 'in_progress'
          ? 'DRAFT CLOCK: ACTIVE'
          : (store.auction?.status?.toUpperCase() ?? 'LOADING')
      }}
    </template>
    <template #ticker-content>
      <span>AUCTION: {{ store.auction?.name ?? '—' }}</span>
      <span class="text-tertiary">REMAINING SCHOOLS: {{ store.availableSchools.length }}</span>
      <span>PICKS: {{ store.draftPicks.length }} / {{ totalDraftSlots }}</span>
      <span v-if="store.currentNominator">NEXT UP: {{ store.currentNominator.display_name }}</span>
      <span v-if="recentBids[0]"
        >PREVIOUS: {{ bidderNameFor(recentBids[0]) }} — ${{ recentBids[0].amount }}</span
      >
    </template>

    <!-- ── Main content ── -->
    <div v-if="store.loading" class="h-[calc(100vh-104px)] flex items-center justify-center">
      <span class="material-symbols-outlined text-4xl text-primary animate-spin">autorenew</span>
    </div>

    <!-- Draft complete -->
    <div
      v-else-if="store.auction?.status === 'completed'"
      class="h-[calc(100vh-104px)] overflow-y-auto"
    >
      <div class="grid gap-0" :class="isAdmin ? 'grid-cols-12' : 'grid-cols-1'">
        <!-- Trophy / completion summary -->
        <div
          class="flex flex-col items-center justify-center gap-6 text-center p-12"
          :class="isAdmin ? 'col-span-5 border-r border-outline-variant/20' : ''"
        >
          <span
            class="material-symbols-outlined text-6xl text-tertiary"
            style="font-variation-settings: 'FILL' 1"
            >emoji_events</span
          >
          <div>
            <div
              class="font-headline font-black uppercase text-on-surface text-4xl tracking-tighter"
            >
              DRAFT COMPLETE
            </div>
            <div class="text-sm font-label text-outline uppercase tracking-wider mt-2">
              {{
                teamsWithOpenSlots.length > 0
                  ? 'Some rosters still have open slots'
                  : 'All rosters are full'
              }}
            </div>
          </div>
          <RouterLink
            :to="`/auction/${auctionId}/roster`"
            class="px-8 py-4 metallic-primary text-on-primary-fixed font-headline font-black text-lg uppercase tracking-widest active:scale-[0.98] transition-transform"
          >
            View Final Rosters
          </RouterLink>
        </div>

        <!-- Admin: post-draft assignment panel -->
        <div v-if="isAdmin" class="col-span-7 p-8 space-y-8 overflow-y-auto">
          <!-- ── Assign new school ── -->
          <div class="space-y-4">
            <div>
              <div
                class="font-headline font-black uppercase text-on-surface text-xl tracking-tighter"
              >
                Finalize Roster Assignments
              </div>
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mt-1">
                Assign remaining schools to teams with open slots
              </div>
            </div>

            <!-- All done -->
            <div
              v-if="teamsWithOpenSlots.length === 0 || store.availableSchools.length === 0"
              class="flex items-center gap-3 p-4 bg-surface-container border border-outline-variant/20"
            >
              <span
                class="material-symbols-outlined text-tertiary"
                style="font-variation-settings: 'FILL' 1"
                >check_circle</span
              >
              <span class="text-sm font-label text-outline uppercase">
                {{
                  store.availableSchools.length === 0
                    ? 'No schools remaining'
                    : 'All teams have full rosters'
                }}
              </span>
            </div>

            <!-- Assignment form -->
            <template v-else>
              <!-- Teams with open slots summary -->
              <div class="space-y-2">
                <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                  Teams with open slots
                </div>
                <div class="flex flex-wrap gap-2">
                  <div
                    v-for="team in teamsWithOpenSlots"
                    :key="team.id"
                    class="px-3 py-1.5 border text-[10px] font-label font-bold uppercase cursor-pointer transition-colors"
                    :class="
                      assignTeamId === team.id
                        ? 'border-primary bg-primary/10 text-primary'
                        : 'border-outline-variant/30 bg-surface-container text-on-surface-variant hover:border-primary/40'
                    "
                    @click="assignTeamId = team.id"
                  >
                    {{ store.getTeamDisplayName(team.id) }} · {{ team.openSlots }} open
                  </div>
                </div>
              </div>

              <!-- Form fields -->
              <div class="grid grid-cols-2 gap-4">
                <!-- School -->
                <div class="space-y-1">
                  <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                    School
                  </div>
                  <select
                    v-model="assignSchoolId"
                    class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label px-3 py-2.5 focus:outline-none focus:border-primary"
                  >
                    <option :value="null">— Select school —</option>
                    <option v-for="s in store.availableSchools" :key="s.id" :value="s.id">
                      {{ s.school?.name ?? s.id }} ({{ s.conference }})
                    </option>
                  </select>
                </div>

                <!-- Team -->
                <div class="space-y-1">
                  <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                    Team
                  </div>
                  <select
                    v-model="assignTeamId"
                    class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label px-3 py-2.5 focus:outline-none focus:border-primary"
                  >
                    <option :value="null">— Select team —</option>
                    <option v-for="team in teamsWithOpenSlots" :key="team.id" :value="team.id">
                      {{ store.getTeamDisplayName(team.id) }} ({{ team.openSlots }} open)
                    </option>
                  </select>
                </div>

                <!-- Position -->
                <div class="space-y-1">
                  <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                    Position
                  </div>
                  <select
                    v-model="assignPositionId"
                    :disabled="!assignTeamId"
                    class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label px-3 py-2.5 focus:outline-none focus:border-primary disabled:opacity-40"
                  >
                    <option :value="null">— Select position —</option>
                    <option v-for="rp in openPositionsForAssignTeam" :key="rp.id" :value="rp.id">
                      {{ rp.position_name }}{{ rp.is_flex ? ' (FLEX)' : '' }}
                    </option>
                  </select>
                </div>

                <!-- Price -->
                <div class="space-y-1">
                  <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                    Price ($0 = uncontested)
                  </div>
                  <div class="relative">
                    <span
                      class="absolute left-3 top-1/2 -translate-y-1/2 font-headline font-black text-outline"
                      >$</span
                    >
                    <input
                      v-model="assignPrice"
                      type="number"
                      min="0"
                      class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label pl-7 pr-3 py-2.5 focus:outline-none focus:border-primary"
                    />
                  </div>
                </div>
              </div>

              <p v-if="assignError" class="text-xs text-error font-label">{{ assignError }}</p>

              <button
                :disabled="
                  !assignSchoolId || !assignTeamId || !assignPositionId || assignSubmitting
                "
                class="px-8 py-3 metallic-primary text-on-primary-fixed font-headline font-black text-sm uppercase tracking-widest active:scale-[0.98] transition-transform disabled:opacity-40"
                @click="directAssign"
              >
                {{ assignSubmitting ? 'ASSIGNING...' : 'ASSIGN PICK' }}
              </button>
            </template>
          </div>

          <!-- ── Transfer existing pick ── -->
          <div class="space-y-4 border-t border-outline-variant/20 pt-6">
            <div>
              <div
                class="font-headline font-black uppercase text-on-surface text-xl tracking-tighter"
              >
                Transfer Existing Pick
              </div>
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mt-1">
                Move a drafted school from one team to another — budgets adjust automatically
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <!-- Pick to transfer -->
              <div class="col-span-2 space-y-1">
                <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                  Pick to transfer
                </div>
                <select
                  v-model="transferPickId"
                  class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label px-3 py-2.5 focus:outline-none focus:border-primary"
                >
                  <option :value="null">— Select a pick —</option>
                  <optgroup
                    v-for="team in store.teams.filter((t) => t.is_active)"
                    :key="team.id"
                    :label="store.getTeamDisplayName(team.id)"
                  >
                    <option
                      v-for="pick in store.draftPicks.filter((p) => p.team_id === team.id)"
                      :key="pick.id"
                      :value="pick.id"
                    >
                      {{
                        store.schools.find((s) => s.id === pick.auction_school_id)?.school?.name ??
                        pick.auction_school_id
                      }}
                      (${{ pick.winning_bid ?? 0 }})
                    </option>
                  </optgroup>
                </select>
              </div>

              <!-- Destination team -->
              <div class="space-y-1">
                <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                  Move to team
                </div>
                <select
                  v-model="transferToTeamId"
                  class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label px-3 py-2.5 focus:outline-none focus:border-primary"
                >
                  <option :value="null">— Select team —</option>
                  <option
                    v-for="team in store.teams.filter((t) => t.is_active)"
                    :key="team.id"
                    :value="team.id"
                  >
                    {{ store.getTeamDisplayName(team.id) }}
                  </option>
                </select>
              </div>

              <!-- Position on destination team -->
              <div class="space-y-1">
                <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                  Assign to position (optional)
                </div>
                <select
                  v-model="transferPositionId"
                  :disabled="!transferToTeamId"
                  class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label px-3 py-2.5 focus:outline-none focus:border-primary disabled:opacity-40"
                >
                  <option :value="null">— Keep current / unassigned —</option>
                  <option v-for="rp in openPositionsForTransferTeam" :key="rp.id" :value="rp.id">
                    {{ rp.position_name }}{{ rp.is_flex ? ' (FLEX)' : '' }}
                  </option>
                </select>
              </div>
            </div>

            <p v-if="transferError" class="text-xs text-error font-label">{{ transferError }}</p>

            <button
              :disabled="!transferPickId || !transferToTeamId || transferSubmitting"
              class="px-8 py-3 bg-surface-container-high border border-outline-variant/30 text-on-surface font-headline font-black text-sm uppercase tracking-widest active:scale-[0.98] transition-transform disabled:opacity-40 hover:bg-surface-container-highest"
              @click="transferPick"
            >
              {{ transferSubmitting ? 'TRANSFERRING...' : 'TRANSFER PICK' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div
      v-else
      class="h-[calc(100vh-104px)] overflow-hidden grid gap-0"
      :class="isAdmin && localAdminMode ? 'grid-cols-12' : 'grid-cols-12'"
    >
      <!-- ── Primary bidding column ── -->
      <div
        class="flex flex-col overflow-hidden border-r border-outline-variant/20"
        :class="isAdmin && localAdminMode ? 'col-span-8' : 'col-span-12'"
      >
        <!-- Awaiting nomination -->
        <div
          v-if="!currentSchool"
          class="flex-1 flex flex-col items-center justify-center gap-6 text-center p-8"
        >
          <span class="material-symbols-outlined text-6xl text-outline animate-pulse">stadium</span>
          <div>
            <div
              class="font-headline font-black uppercase text-on-surface-variant text-2xl tracking-tighter"
            >
              {{ isMyTurnToNominate ? 'YOUR TURN TO NOMINATE' : 'AWAITING NOMINATION' }}
            </div>
            <div class="text-sm font-label text-outline uppercase tracking-wider mt-2">
              <template v-if="isMyTurnToNominate"> Select a school to put on the block </template>
              <template v-else>
                {{ store.currentNominator?.display_name ?? '—' }} is selecting a school
              </template>
            </div>
          </div>
          <button
            v-if="isMyTurnToNominate"
            class="px-10 py-4 metallic-secondary text-on-secondary font-headline font-black text-xl uppercase tracking-widest active:scale-[0.98] transition-transform"
            @click="showNominationGrid = true"
          >
            <span class="material-symbols-outlined align-text-bottom mr-2">gavel</span>
            NOMINATE NOW
          </button>
          <button
            v-if="isAdmin"
            class="px-6 py-3 bg-surface-container border border-primary/30 text-primary font-label font-bold text-xs uppercase hover:bg-primary/10 transition-colors"
            @click="showNominationGrid = true"
          >
            Admin: Force Nomination
          </button>
        </div>

        <!-- School on the block -->
        <template v-else>
          <!-- School identity hero -->
          <div
            class="bg-surface-container p-6 border-b border-outline-variant/20 flex items-center gap-8"
          >
            <div
              class="w-24 h-24 bg-white p-2 shadow-2xl flex-shrink-0 flex items-center justify-center"
            >
              <img
                v-if="currentSchool.school?.logo_url"
                :src="currentSchool.school.logo_url"
                :alt="currentSchool.school.name"
                class="w-full h-full object-contain"
              />
              <span v-else class="font-headline font-black text-surface-container-lowest text-3xl">
                {{ currentSchool.school?.name?.slice(0, 2).toUpperCase() }}
              </span>
            </div>
            <div class="flex-1">
              <div class="text-xs font-label text-outline uppercase tracking-widest mb-1">
                {{ currentSchool.conference }} • {{ currentSchool.leagify_position }}
              </div>
              <h2
                class="font-headline font-black uppercase text-on-surface text-4xl leading-none tracking-tighter"
              >
                {{ currentSchool.school?.name }}
              </h2>
              <div class="flex items-center gap-6 mt-2">
                <div>
                  <span class="text-[10px] font-label text-outline uppercase">Proj. Points</span>
                  <span class="ml-2 font-headline font-bold text-tertiary">{{
                    currentSchool.projected_points
                  }}</span>
                </div>
                <div v-if="currentNominatorName">
                  <span class="text-[10px] font-label text-outline uppercase">Nominated by</span>
                  <span class="ml-2 font-headline font-bold text-on-surface-variant">{{
                    currentNominatorName
                  }}</span>
                </div>
              </div>
            </div>
            <div class="text-right">
              <div class="text-xs font-label text-outline uppercase">Auction State</div>
              <div class="text-2xl font-headline font-black text-secondary animate-pulse">LIVE</div>
            </div>
          </div>

          <!-- Bid status row -->
          <div class="grid grid-cols-3 bg-surface-container-low border-b border-outline-variant/20">
            <div class="p-5 border-r border-outline-variant/20 text-center">
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">
                Current High Bid
              </div>
              <div
                class="text-4xl font-headline font-black"
                :class="currentHighBid > 0 ? 'text-secondary animate-pulse' : 'text-outline'"
              >
                ${{ currentHighBid || '—' }}
              </div>
            </div>
            <div
              class="p-5 border-r border-outline-variant/20 text-center"
              :class="isHighBidder ? 'bg-secondary-container/10' : ''"
            >
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">
                Winning Coach
              </div>
              <div class="text-lg font-headline font-bold text-on-surface uppercase truncate">
                {{ store.currentHighBidder?.display_name ?? '—' }}
              </div>
            </div>
            <div class="p-5 text-center">
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">
                Your Budget
              </div>
              <div class="text-4xl font-headline font-black text-primary">
                ${{ store.activeTeam?.remaining_budget ?? '—' }}
              </div>
            </div>
          </div>

          <!-- Bid controls + log row -->
          <div class="flex-1 overflow-hidden grid grid-cols-5">
            <!-- Bid controls (3/5 width) -->
            <div
              class="col-span-3 p-6 space-y-4 overflow-y-auto border-r border-outline-variant/20"
            >
              <!-- Leading badge -->
              <div
                v-if="isHighBidder"
                class="text-center py-2 bg-secondary-container/20 border border-secondary/30"
              >
                <span class="text-xs font-label font-bold text-secondary uppercase tracking-widest"
                  >YOU ARE WINNING</span
                >
              </div>

              <!-- Roster full state -->
              <div v-if="myRosterFull && !isHighBidder" class="text-center py-6">
                <div
                  class="inline-flex items-center gap-3 bg-surface-container-high px-6 py-4 border border-outline-variant/30"
                >
                  <span
                    class="material-symbols-outlined text-tertiary"
                    style="font-variation-settings: 'FILL' 1"
                    >check_circle</span
                  >
                  <div class="text-left">
                    <div class="font-headline font-bold uppercase text-on-surface-variant text-sm">
                      ROSTER FULL
                    </div>
                    <div class="text-[10px] font-label text-outline uppercase tracking-wider">
                      Your team cannot bid on more schools
                    </div>
                  </div>
                </div>
              </div>

              <!-- Auto-passed state -->
              <div v-else-if="isAutoPass && !myRosterFull" class="text-center py-6">
                <div
                  class="inline-flex items-center gap-3 bg-surface-container-high px-6 py-4 border border-outline-variant/30"
                >
                  <span
                    class="material-symbols-outlined text-error"
                    style="font-variation-settings: 'FILL' 1"
                    >lock</span
                  >
                  <div class="text-left">
                    <div class="font-headline font-bold uppercase text-on-surface-variant text-sm">
                      BIDDING LOCKED
                    </div>
                    <div class="text-[10px] font-label text-outline uppercase tracking-wider">
                      Max bid ${{ maxBid }} — below minimum ${{ nextMinBid }}
                    </div>
                    <div class="text-[10px] font-label text-error uppercase mt-1">
                      $1 min per remaining slot required
                    </div>
                  </div>
                </div>
              </div>

              <template v-else-if="!myRosterFull">
                <!-- Next min bid -->
                <div class="text-center">
                  <div class="text-xs font-label text-outline uppercase tracking-widest">
                    Next Minimum Bid
                  </div>
                  <div class="text-5xl font-headline font-black text-on-surface mt-1">
                    ${{ nextMinBid }}
                  </div>
                  <div class="text-[10px] font-label text-outline uppercase mt-1">
                    Max: ${{ maxBid }}
                  </div>
                </div>

                <!-- Quick bid buttons -->
                <div class="grid grid-cols-3 gap-3">
                  <button
                    v-for="delta in [1, 5, 10]"
                    :key="delta"
                    :disabled="nextMinBid - 1 + delta > maxBid || submitting"
                    class="bg-surface-container-high hover:bg-primary/20 border border-primary/30 py-5 font-headline font-black text-2xl text-primary transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed"
                    @click="bid(delta)"
                  >
                    +${{ delta }}
                  </button>
                </div>

                <!-- Custom bid -->
                <div class="flex gap-2">
                  <div class="flex-1 relative">
                    <span
                      class="absolute left-3 top-1/2 -translate-y-1/2 font-headline font-black text-outline"
                      >$</span
                    >
                    <input
                      v-model="customBidAmount"
                      type="number"
                      :min="nextMinBid"
                      :max="maxBid"
                      placeholder="Custom amount"
                      class="w-full bg-surface-container border border-outline-variant/30 pl-8 pr-4 py-3 text-on-surface font-label focus:outline-none focus:border-primary/50"
                      @keyup.enter="submitCustomBid"
                    />
                  </div>
                  <button
                    :disabled="submitting"
                    class="px-6 py-3 metallic-primary text-on-primary-fixed font-label font-black text-sm uppercase disabled:opacity-40 active:scale-95 transition-transform"
                    @click="submitCustomBid"
                  >
                    BID
                  </button>
                </div>

                <!-- Submit / Pass -->
                <button
                  :disabled="submitting"
                  class="w-full metallic-primary py-5 font-headline font-black text-2xl text-on-primary-fixed shadow-xl active:scale-[0.98] uppercase tracking-widest disabled:opacity-40"
                  @click="bid(1)"
                >
                  {{ submitting ? 'SUBMITTING...' : 'SUBMIT BID' }}
                </button>
              </template>

              <button
                :disabled="submitting || isHighBidder"
                class="w-full bg-surface-container hover:bg-secondary/10 border border-secondary/20 py-4 font-headline font-bold text-secondary transition-all active:scale-95 uppercase tracking-tighter disabled:opacity-40"
                @click="pass"
              >
                <span
                  class="material-symbols-outlined align-text-bottom mr-1"
                  :style="isAutoPass || isHighBidder ? 'font-variation-settings: \'FILL\' 1' : ''"
                  >{{ isAutoPass ? 'lock' : 'block' }}</span
                >
                {{
                  isHighBidder
                    ? "Cannot Pass — You're Winning"
                    : isAutoPass
                      ? 'LOCKED IN: PASS'
                      : 'Pass'
                }}
              </button>

              <p v-if="bidError" class="text-xs text-error font-label text-center">
                {{ bidError }}
              </p>
            </div>

            <!-- Bid log (2/5 width) -->
            <div class="col-span-2 flex flex-col overflow-hidden">
              <div class="px-4 py-3 border-b border-outline-variant/20 bg-surface-container-high">
                <span class="text-[10px] font-label text-outline uppercase tracking-widest"
                  >Bidding Log</span
                >
              </div>
              <div class="flex-1 overflow-y-auto">
                <div
                  v-for="entry in recentBids"
                  :key="entry.id"
                  class="px-4 py-2 border-b border-outline-variant/10 flex items-center justify-between hover:bg-surface-container/50"
                  :class="entry.bid_type === 'pass' ? 'opacity-50' : ''"
                >
                  <div>
                    <div class="text-xs font-label font-bold text-on-surface">
                      {{ bidderNameFor(entry) }}
                    </div>
                    <div class="text-[10px] font-label text-outline uppercase">
                      {{
                        entry.bid_type === 'pass'
                          ? 'PASSED'
                          : entry.bid_type === 'nomination'
                            ? 'NOMINATED'
                            : `+$${entry.amount}`
                      }}
                    </div>
                  </div>
                  <div
                    class="font-headline font-bold text-sm"
                    :class="entry.bid_type === 'bid' ? 'text-primary' : 'text-outline'"
                  >
                    {{ entry.bid_type === 'bid' ? `$${entry.amount}` : '—' }}
                  </div>
                </div>
                <div
                  v-if="recentBids.length === 0"
                  class="px-4 py-8 text-center text-outline font-label text-xs uppercase"
                >
                  No bids yet
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- ── Admin right panel (admin mode only) ── -->
      <div
        v-if="isAdmin && localAdminMode"
        class="col-span-4 flex flex-col overflow-hidden border-l border-outline-variant/20"
      >
        <div class="px-4 py-3 border-b border-outline-variant/20 bg-surface-container-high">
          <span class="text-[10px] font-label text-secondary uppercase tracking-widest"
            >ADMIN CONTROL RESTRICTED</span
          >
        </div>

        <!-- Team budgets overview -->
        <div class="flex-1 overflow-y-auto p-4 space-y-3">
          <!-- Unassigned picks alert -->
          <div
            v-if="unassignedPicks.length > 0"
            class="bg-error-container/20 border border-error/40 p-3 space-y-2"
          >
            <div class="text-[10px] font-label text-error uppercase tracking-widest font-bold">
              {{ unassignedPicks.length }} Unassigned Pick{{
                unassignedPicks.length !== 1 ? 's' : ''
              }}
            </div>
            <div
              v-for="pick in unassignedPicks"
              :key="pick.id"
              class="flex items-center justify-between py-1"
            >
              <div>
                <div class="text-xs font-label font-bold text-on-surface">
                  {{ pick.auction_school?.school?.name ?? 'School' }}
                </div>
                <div class="text-[10px] font-label text-outline">
                  {{ store.getTeamDisplayName(pick.team_id) }} — ${{ pick.winning_bid }}
                </div>
              </div>
              <button
                class="text-[10px] font-label font-bold text-primary border border-primary/30 px-2 py-1 hover:bg-primary/10 uppercase"
                @click="pendingAssignmentPick = pick"
              >
                Assign
              </button>
            </div>
          </div>

          <!-- Manual pick entry -->
          <details class="bg-surface-container border border-outline-variant/30">
            <summary
              class="px-3 py-2 text-[10px] font-label text-outline uppercase tracking-widest cursor-pointer hover:bg-surface-container-high select-none"
            >
              Manual Pick Entry (Emergency)
            </summary>
            <div class="px-3 pb-3 pt-2 space-y-2">
              <div class="text-[10px] font-label text-outline uppercase mb-1">
                Use if bidding happened offline or app failed
              </div>
              <select
                v-model="manualSchoolId"
                class="w-full bg-surface-container-lowest border border-outline-variant/30 text-on-surface text-xs font-label py-1.5 px-2 focus:outline-none focus:border-primary/50"
              >
                <option :value="null">— School —</option>
                <option v-for="s in store.availableSchools" :key="s.id" :value="s.id">
                  {{ s.school?.name ?? s.id }}
                </option>
              </select>
              <select
                v-model="manualTeamId"
                class="w-full bg-surface-container-lowest border border-outline-variant/30 text-on-surface text-xs font-label py-1.5 px-2 focus:outline-none focus:border-primary/50"
              >
                <option :value="null">— Winning Team —</option>
                <option v-for="team in store.teams" :key="team.id" :value="team.id">
                  {{ store.getTeamDisplayName(team.id) }} (${{ team.remaining_budget }})
                </option>
              </select>
              <div class="flex gap-2">
                <div class="relative flex-1">
                  <span
                    class="absolute left-2 top-1/2 -translate-y-1/2 text-outline font-headline font-black text-xs"
                    >$</span
                  >
                  <input
                    v-model="manualAmount"
                    type="number"
                    min="1"
                    placeholder="Winning bid"
                    class="w-full bg-surface-container-lowest border border-outline-variant/30 text-on-surface text-xs font-label py-1.5 pl-6 pr-2 focus:outline-none focus:border-primary/50"
                  />
                </div>
                <button
                  :disabled="!manualSchoolId || !manualTeamId || !manualAmount || manualSubmitting"
                  class="px-3 bg-secondary-container hover:bg-secondary/20 text-on-secondary-container font-label font-bold text-[10px] uppercase border border-secondary/30 disabled:opacity-40"
                  @click="manualRecordPick"
                >
                  {{ manualSubmitting ? '...' : 'Record' }}
                </button>
              </div>
              <p v-if="manualError" class="text-[10px] text-error font-label">{{ manualError }}</p>
            </div>
          </details>

          <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">
            Team Budgets
          </div>
          <div
            v-for="team in store.teams"
            :key="team.id"
            class="bg-surface-container p-3 border border-outline-variant/20"
          >
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-label font-bold text-on-surface uppercase">{{
                store.getTeamDisplayName(team.id)
              }}</span>
              <span class="text-xs font-headline font-bold text-primary"
                >${{ team.remaining_budget }}</span
              >
            </div>
            <!-- Budget bar -->
            <div class="w-full h-1 bg-surface-container-highest rounded-full overflow-hidden">
              <div
                class="h-full bg-primary transition-all duration-500"
                :style="{ width: `${budgetPct(team)}%` }"
              ></div>
            </div>
            <div class="text-[9px] font-label text-outline mt-1 uppercase">
              {{ budgetPct(team) }}% remaining
            </div>
          </div>

          <!-- Draft picks summary -->
          <div class="mt-4">
            <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">
              Recent Picks
            </div>
            <div
              v-for="pick in [...store.draftPicks]
                .sort((a, b) => b.pick_order - a.pick_order)
                .slice(0, 5)"
              :key="pick.id"
              class="py-2 border-b border-outline-variant/10 flex items-center justify-between"
            >
              <div>
                <div class="text-xs font-label font-bold text-on-surface">
                  {{ pick.auction_school?.school?.name ?? 'School' }}
                </div>
                <div class="text-[10px] font-label text-outline">
                  {{ store.getTeamDisplayName(pick.team_id) }}
                </div>
              </div>
              <span class="font-headline font-bold text-tertiary text-sm"
                >${{ pick.winning_bid }}</span
              >
            </div>
            <div
              v-if="store.draftPicks.length === 0"
              class="text-[10px] font-label text-outline uppercase text-center py-4"
            >
              No picks yet
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ── Overlays ── -->
    <NominationGrid v-if="showNominationGrid" @close="showNominationGrid = false" />
    <PickIsInSting @dismissed="onStingDismissed" />
    <PositionAssignmentModal
      :pick="pendingAssignmentPick"
      @assigned="onPositionAssigned"
      @close="pendingAssignmentPick = null"
    />
    <ConnectionLostOverlay :visible="connectionReady && !isConnected" @retry="retryConnection" />
  </AppShell>
</template>
