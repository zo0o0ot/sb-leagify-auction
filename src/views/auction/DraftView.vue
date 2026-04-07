<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
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

// ── UI State ────────────────────────────────────────────────────────────────
const showNominationGrid = ref(false)
const pendingAssignmentPick = ref<DraftPick | null>(null)
const submitting = ref(false)
const bidError = ref('')
const customBidAmount = ref('')

// Admin mode UI
const localAdminMode = ref(false)
const localProxyTeamId = ref<number | null>(null)

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

const isMyTurnToNominate = computed(() =>
  store.auction?.current_nominator_id === store.myParticipant?.id,
)

const nominationOrder = computed(() =>
  store.teams.filter((t) => t.is_active).sort((a, b) => a.nomination_order - b.nomination_order),
)

const recentBids = computed(() => store.bidHistory.slice(0, 10))

// Watch for new picks that need position assignment (only for this team's picks)
watch(
  () => store.draftPicks,
  (picks) => {
    const myTeamId = store.activeTeam?.id
    if (!myTeamId) return
    const unassigned = picks.find(
      (p) => p.team_id === myTeamId && !p.roster_position_id,
    )
    if (unassigned && unassigned.id !== pendingAssignmentPick.value?.id) {
      pendingAssignmentPick.value = unassigned
    }
  },
  { deep: true },
)

// Sync admin mode to store
watch(localAdminMode, (v) => { store.isAdminMode = v })
watch(localProxyTeamId, (v) => { store.proxyTeamId = v })

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

function budgetPct(team: typeof store.teams[0]) {
  if (!store.auction) return 0
  return Math.round((team.remaining_budget / store.auction.default_budget) * 100)
}

function bidderNameFor(bid: typeof store.bidHistory[0]) {
  const team = store.teams.find((t) => t.id === bid.team_id)
  return team?.team_name ?? 'Unknown'
}
</script>

<template>
  <AppShell>
    <!-- Nav -->
    <template #nav>
      <span class="text-primary border-b-2 border-primary pb-1">WAR ROOM</span>
      <span class="text-on-surface-variant">AUCTION</span>
      <span class="text-on-surface-variant">SCHOOLS</span>
      <span class="text-on-surface-variant">ROSTERS</span>
    </template>

    <!-- Header actions -->
    <template #header-actions>
      <div class="flex items-center gap-3">
        <!-- Admin mode toggle -->
        <button
          v-if="isAdmin"
          class="flex items-center gap-2 px-3 py-1 border text-[10px] font-label font-black uppercase transition-colors"
          :class="localAdminMode
            ? 'bg-secondary-container/20 border-secondary/30 text-secondary'
            : 'bg-surface-container border-outline/20 text-outline'"
          @click="localAdminMode = !localAdminMode"
        >
          <span class="material-symbols-outlined text-sm">security</span>
          {{ localAdminMode ? 'ADMIN MODE' : 'ADMIN OFF' }}
        </button>

        <!-- Status badge -->
        <div class="flex items-center gap-2 px-3 py-1 bg-surface-container border border-outline/20">
          <span
            class="w-2 h-2 rounded-full"
            :class="store.auction?.status === 'in_progress' ? 'bg-tertiary animate-pulse' : 'bg-outline'"
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
        <div class="w-12 h-12 bg-surface-container-highest flex items-center justify-center border border-primary/20">
          <span class="material-symbols-outlined text-primary text-3xl">gavel</span>
        </div>
        <div>
          <div class="text-on-surface text-sm tracking-tight">{{ isAdmin ? 'COMMANDER' : store.activeTeam?.team_name ?? 'COACH' }}</div>
          <div class="text-primary text-xs">BUDGET: ${{ store.activeTeam?.remaining_budget ?? '—' }}</div>
        </div>
      </div>
    </template>

    <!-- Sidebar nav -->
    <template #sidebar-nav>
      <a class="flex items-center px-6 py-4 bg-gradient-to-r from-primary/20 to-transparent text-primary border-l-4 border-primary">
        <span class="material-symbols-outlined mr-4">gavel</span> WAR ROOM
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">leaderboard</span> BOARD
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">groups</span> ROSTER
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">history</span> HISTORY
      </a>
    </template>

    <!-- Sidebar footer -->
    <template #sidebar-footer>
      <!-- Nomination order -->
      <div class="p-4 space-y-2">
        <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">Nomination Order</div>
        <div
          v-for="(team, idx) in nominationOrder"
          :key="team.id"
          class="flex items-center gap-3 py-2 px-2 transition-colors"
          :class="participantFor(team.id)?.id === store.auction?.current_nominator_id
            ? 'bg-secondary-container/20 border-l-2 border-secondary'
            : ''"
        >
          <span class="text-[10px] font-label text-outline w-4">{{ String(idx + 1).padStart(2, '0') }}</span>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-label font-bold text-on-surface truncate">{{ team.team_name }}</div>
            <div class="text-[10px] font-label text-outline">${{ team.remaining_budget }}</div>
          </div>
          <span
            class="w-2 h-2 rounded-full flex-shrink-0"
            :class="participantFor(team.id)?.is_connected ? 'bg-green-500' : 'bg-red-500'"
          ></span>
        </div>
      </div>

      <!-- Admin: proxy bidding -->
      <div v-if="isAdmin && localAdminMode" class="p-4 border-t border-outline-variant/20 space-y-3">
        <div class="text-[10px] font-label text-outline uppercase tracking-widest">Admin Override Bid</div>
        <select
          v-model="localProxyTeamId"
          class="w-full bg-surface-container border border-outline-variant/30 text-on-surface text-xs font-label py-2 px-3 focus:outline-none focus:border-primary/50"
        >
          <option :value="null">SELECT COACH...</option>
          <option v-for="team in store.teams" :key="team.id" :value="team.id">
            {{ team.team_name }} (${{ team.remaining_budget }})
          </option>
        </select>
        <div class="text-[10px] font-label text-outline uppercase">Auto-Pass</div>
        <div class="space-y-1">
          <label
            v-for="team in store.teams"
            :key="team.id"
            class="flex items-center justify-between py-1.5 px-2 hover:bg-surface-container cursor-pointer"
          >
            <span class="text-[10px] font-label text-on-surface-variant">{{ team.team_name }}</span>
            <input type="checkbox" class="accent-primary" />
          </label>
        </div>

        <!-- Admin auction controls -->
        <div class="pt-2 space-y-2 border-t border-outline-variant/20">
          <button
            class="w-full bg-error-container hover:bg-error/20 text-error text-[10px] py-2 border border-error/30 uppercase font-label"
            @click="store.setAuctionStatus('paused')"
          >
            <span class="material-symbols-outlined text-sm align-text-bottom mr-1">pause_circle</span>
            PAUSE AUCTION
          </button>
          <button
            v-if="store.auction?.status === 'paused'"
            class="w-full bg-surface-container hover:bg-primary/10 text-primary text-[10px] py-2 border border-primary/30 uppercase font-label"
            @click="store.setAuctionStatus('in_progress')"
          >RESUME</button>
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
      <div v-if="!isAdmin && isMyTurnToNominate && !currentSchool" class="p-4 border-t border-outline-variant/20">
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
      {{ store.auction?.status === 'in_progress' ? 'DRAFT CLOCK: ACTIVE' : store.auction?.status?.toUpperCase() ?? 'LOADING' }}
    </template>
    <template #ticker-content>
      <span>AUCTION: {{ store.auction?.name ?? '—' }}</span>
      <span class="text-tertiary">REMAINING SCHOOLS: {{ store.availableSchools.length }}</span>
      <span v-if="store.currentNominator">NEXT UP: {{ store.currentNominator.display_name }}</span>
      <span v-if="recentBids[0]">PREVIOUS: {{ bidderNameFor(recentBids[0]) }} — ${{ recentBids[0].amount }}</span>
    </template>

    <!-- ── Main content ── -->
    <div v-if="store.loading" class="h-[calc(100vh-104px)] flex items-center justify-center">
      <span class="material-symbols-outlined text-4xl text-primary animate-spin">autorenew</span>
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
            <div class="font-headline font-black uppercase text-on-surface-variant text-2xl tracking-tighter">
              {{ isMyTurnToNominate ? 'YOUR TURN TO NOMINATE' : 'AWAITING NOMINATION' }}
            </div>
            <div class="text-sm font-label text-outline uppercase tracking-wider mt-2">
              <template v-if="isMyTurnToNominate">
                Select a school to put on the block
              </template>
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
          <div class="bg-surface-container p-6 border-b border-outline-variant/20 flex items-center gap-8">
            <div class="w-24 h-24 bg-white p-2 shadow-2xl flex-shrink-0 flex items-center justify-center">
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
              <h2 class="font-headline font-black uppercase text-on-surface text-4xl leading-none tracking-tighter">
                {{ currentSchool.school?.name }}
              </h2>
              <div class="flex items-center gap-6 mt-2">
                <div>
                  <span class="text-[10px] font-label text-outline uppercase">Proj. Points</span>
                  <span class="ml-2 font-headline font-bold text-tertiary">{{ currentSchool.projected_points }}</span>
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
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">Current High Bid</div>
              <div
                class="text-4xl font-headline font-black"
                :class="currentHighBid > 0 ? 'text-secondary animate-pulse' : 'text-outline'"
              >
                ${{ currentHighBid || '—' }}
              </div>
            </div>
            <div class="p-5 border-r border-outline-variant/20 text-center" :class="isHighBidder ? 'bg-secondary-container/10' : ''">
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">Winning Coach</div>
              <div class="text-lg font-headline font-bold text-on-surface uppercase truncate">
                {{ store.currentHighBidder?.team_name ?? '—' }}
              </div>
            </div>
            <div class="p-5 text-center">
              <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">Your Budget</div>
              <div class="text-4xl font-headline font-black text-primary">${{ store.activeTeam?.remaining_budget ?? '—' }}</div>
            </div>
          </div>

          <!-- Bid controls + log row -->
          <div class="flex-1 overflow-hidden grid grid-cols-5">

            <!-- Bid controls (3/5 width) -->
            <div class="col-span-3 p-6 space-y-4 overflow-y-auto border-r border-outline-variant/20">

              <!-- Leading badge -->
              <div
                v-if="isHighBidder"
                class="text-center py-2 bg-secondary-container/20 border border-secondary/30"
              >
                <span class="text-xs font-label font-bold text-secondary uppercase tracking-widest">YOU ARE WINNING</span>
              </div>

              <!-- Auto-passed state -->
              <div v-if="isAutoPass" class="text-center py-6">
                <div class="inline-flex items-center gap-3 bg-surface-container-high px-6 py-4 border border-outline-variant/30">
                  <span class="material-symbols-outlined text-error" style="font-variation-settings: 'FILL' 1">lock</span>
                  <div class="text-left">
                    <div class="font-headline font-bold uppercase text-on-surface-variant text-sm">BIDDING LOCKED</div>
                    <div class="text-[10px] font-label text-outline uppercase tracking-wider">
                      Max bid ${{ maxBid }} — below minimum ${{ nextMinBid }}
                    </div>
                    <div class="text-[10px] font-label text-error uppercase mt-1">
                      $1 min per remaining slot required
                    </div>
                  </div>
                </div>
              </div>

              <template v-else>
                <!-- Next min bid -->
                <div class="text-center">
                  <div class="text-xs font-label text-outline uppercase tracking-widest">Next Minimum Bid</div>
                  <div class="text-5xl font-headline font-black text-on-surface mt-1">${{ nextMinBid }}</div>
                  <div class="text-[10px] font-label text-outline uppercase mt-1">Max: ${{ maxBid }}</div>
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
                    <span class="absolute left-3 top-1/2 -translate-y-1/2 font-headline font-black text-outline">$</span>
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
                <span class="material-symbols-outlined align-text-bottom mr-1" :style="(isAutoPass || isHighBidder) ? 'font-variation-settings: \'FILL\' 1' : ''">{{ isAutoPass ? 'lock' : 'block' }}</span>
                {{ isHighBidder ? 'Cannot Pass — You\'re Winning' : isAutoPass ? 'LOCKED IN: PASS' : 'Pass' }}
              </button>

              <p v-if="bidError" class="text-xs text-error font-label text-center">{{ bidError }}</p>
            </div>

            <!-- Bid log (2/5 width) -->
            <div class="col-span-2 flex flex-col overflow-hidden">
              <div class="px-4 py-3 border-b border-outline-variant/20 bg-surface-container-high">
                <span class="text-[10px] font-label text-outline uppercase tracking-widest">Bidding Log</span>
              </div>
              <div class="flex-1 overflow-y-auto">
                <div
                  v-for="entry in recentBids"
                  :key="entry.id"
                  class="px-4 py-2 border-b border-outline-variant/10 flex items-center justify-between hover:bg-surface-container/50"
                  :class="entry.bid_type === 'pass' ? 'opacity-50' : ''"
                >
                  <div>
                    <div class="text-xs font-label font-bold text-on-surface">{{ bidderNameFor(entry) }}</div>
                    <div class="text-[10px] font-label text-outline uppercase">
                      {{ entry.bid_type === 'pass' ? 'PASSED' : entry.bid_type === 'nomination' ? 'NOMINATED' : `+$${entry.amount}` }}
                    </div>
                  </div>
                  <div
                    class="font-headline font-bold text-sm"
                    :class="entry.bid_type === 'bid' ? 'text-primary' : 'text-outline'"
                  >
                    {{ entry.bid_type === 'bid' ? `$${entry.amount}` : '—' }}
                  </div>
                </div>
                <div v-if="recentBids.length === 0" class="px-4 py-8 text-center text-outline font-label text-xs uppercase">
                  No bids yet
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- ── Admin right panel (admin mode only) ── -->
      <div v-if="isAdmin && localAdminMode" class="col-span-4 flex flex-col overflow-hidden border-l border-outline-variant/20">
        <div class="px-4 py-3 border-b border-outline-variant/20 bg-surface-container-high">
          <span class="text-[10px] font-label text-secondary uppercase tracking-widest">ADMIN CONTROL RESTRICTED</span>
        </div>

        <!-- Team budgets overview -->
        <div class="flex-1 overflow-y-auto p-4 space-y-3">
          <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">Team Budgets</div>
          <div
            v-for="team in store.teams"
            :key="team.id"
            class="bg-surface-container p-3 border border-outline-variant/20"
          >
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-label font-bold text-on-surface uppercase">{{ team.team_name }}</span>
              <span class="text-xs font-headline font-bold text-primary">${{ team.remaining_budget }}</span>
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
            <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">Recent Picks</div>
            <div
              v-for="pick in [...store.draftPicks].sort((a, b) => b.pick_order - a.pick_order).slice(0, 5)"
              :key="pick.id"
              class="py-2 border-b border-outline-variant/10 flex items-center justify-between"
            >
              <div>
                <div class="text-xs font-label font-bold text-on-surface">
                  {{ pick.auction_school?.school?.name ?? 'School' }}
                </div>
                <div class="text-[10px] font-label text-outline">
                  {{ store.teams.find((t) => t.id === pick.team_id)?.team_name ?? '—' }}
                </div>
              </div>
              <span class="font-headline font-bold text-tertiary text-sm">${{ pick.winning_bid }}</span>
            </div>
            <div v-if="store.draftPicks.length === 0" class="text-[10px] font-label text-outline uppercase text-center py-4">
              No picks yet
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ── Overlays ── -->
    <NominationGrid v-if="showNominationGrid" @close="showNominationGrid = false" />
    <PickIsInSting @dismissed="onStingDismissed" />
    <PositionAssignmentModal :pick="pendingAssignmentPick" @assigned="onPositionAssigned" @close="pendingAssignmentPick = null" />
    <ConnectionLostOverlay :visible="!isConnected" @retry="retryConnection" />
  </AppShell>
</template>
