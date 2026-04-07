<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuctionStore } from '@/stores/auction'
import { useAuctionRealtime } from '@/composables/useAuctionRealtime'
import AppShell from '@/components/AppShell.vue'
import ParticipantCard from '@/components/lobby/ParticipantCard.vue'
import PracticeBiddingZone from '@/components/lobby/PracticeBiddingZone.vue'

const route = useRoute()
const router = useRouter()
const store = useAuctionStore()
const auctionId = Number(route.params.id)

useAuctionRealtime(auctionId)

const isAdmin = computed(() => store.isAuctionMaster)
const submitting = ref(false)

const coaches = computed(() =>
  store.participants.filter((p) => p.role === 'team_coach'),
)

function teamFor(participantId: number) {
  const p = store.participants.find((x) => x.id === participantId)
  return p?.team_id ? store.teams.find((t) => t.id === p.team_id) ?? null : null
}

const connectedCount = computed(() => store.participants.filter((p) => p.is_connected).length)
const readyCount = computed(() => coaches.value.filter((p) => p.is_ready).length)
const notReadyCoach = computed(() => coaches.value.find((p) => !p.is_connected || !p.is_ready))

// Ready toggle (coach sets own status)
async function toggleReady() {
  const me = store.myParticipant
  if (!me) return
  await store.setReady(!me.is_ready)
}

async function startDraft(skipCheck = false) {
  if (!skipCheck && !store.allCoachesReady) return
  submitting.value = true

  // Determine first nominator: participant whose team has nomination_order=1
  const firstTeam = store.teams.slice().sort((a, b) => a.nomination_order - b.nomination_order)[0]
  const firstNominator = store.participants.find((p) => p.team_id === firstTeam?.id)

  await supabase
    .from('auctions')
    .update({ status: 'in_progress', current_nominator_id: firstNominator?.id ?? null })
    .eq('id', auctionId)

  router.push(`/auction/${auctionId}/draft`)
}

const practiceSchoolId = ref<number | null>(null)
const practiceSubmitting = ref(false)

const practiceError = ref('')

async function startPractice() {
  if (!practiceSchoolId.value) return
  practiceError.value = ''
  practiceSubmitting.value = true
  const { error } = await supabase
    .from('auctions')
    .update({ status: 'practice', current_school_id: practiceSchoolId.value, current_high_bid: 0, current_high_bidder_id: null })
    .eq('id', auctionId)
  if (error) practiceError.value = error.message
  practiceSubmitting.value = false
}

async function stopPractice() {
  practiceError.value = ''
  const { error } = await supabase
    .from('auctions')
    .update({ status: 'draft', current_school_id: null, current_high_bid: null, current_high_bidder_id: null })
    .eq('id', auctionId)
  if (!error) practiceSchoolId.value = null
  else practiceError.value = error.message
}
</script>

<template>
  <AppShell>
    <!-- Nav -->
    <template #nav>
      <span class="text-primary border-b-2 border-primary pb-1">
        {{ isAdmin ? 'ADMIN CONSOLE' : 'COACH VIEW' }}
      </span>
      <span class="text-on-surface-variant">MARKET</span>
      <span class="text-on-surface-variant">ROSTERS</span>
    </template>

    <!-- Header actions -->
    <template #header-actions>
      <div
        v-if="isAdmin"
        class="flex items-center gap-2 px-3 py-1 bg-secondary-container/20 border border-secondary/20"
      >
        <span class="w-2 h-2 bg-secondary rounded-full animate-pulse"></span>
        <span class="text-[10px] text-secondary font-label font-black uppercase">ADMIN MODE</span>
      </div>
    </template>

    <!-- Sidebar header -->
    <template #sidebar-header>
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 bg-surface-container-highest flex items-center justify-center border border-primary/20">
          <span class="material-symbols-outlined text-primary text-3xl">
            {{ isAdmin ? 'admin_panel_settings' : 'sports_football' }}
          </span>
        </div>
        <div>
          <div class="text-on-surface text-sm tracking-tight">
            {{ isAdmin ? 'MASTER CONTROL' : 'COACH CONSOLE' }}
          </div>
          <div class="text-secondary text-xs">STATUS: LOBBY</div>
        </div>
      </div>
    </template>

    <!-- Sidebar nav -->
    <template #sidebar-nav>
      <a class="flex items-center px-6 py-4 bg-gradient-to-r from-primary/20 to-transparent text-primary border-l-4 border-primary">
        <span class="material-symbols-outlined mr-4">stadium</span> WAR ROOM
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">storefront</span> MARKET
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">groups</span> ROSTERS
      </a>
    </template>

    <!-- Sidebar footer -->
    <template #sidebar-footer>
      <!-- Admin system overrides -->
      <div v-if="isAdmin" class="mb-4 p-4 bg-surface-container border border-outline-variant/30">
        <div class="text-[10px] text-outline mb-2 font-label uppercase">System Override</div>
        <div class="flex gap-2">
          <button
            class="flex-1 bg-error-container hover:bg-error/20 text-error text-[10px] py-2 border border-error/30 uppercase font-label"
            @click="store.setAuctionStatus('paused')"
          >Pause</button>
          <button
            class="flex-1 bg-surface-container-highest hover:bg-white/10 text-on-surface text-[10px] py-2 border border-outline/30 uppercase font-label"
            @click="store.setAuctionStatus('practice')"
          >Reset</button>
        </div>
      </div>

      <!-- (Ready toggle moved to ParticipantCard) -->
    </template>

    <!-- Ticker -->
    <template #ticker-status>
      {{ isAdmin ? 'ADMIN CONSOLE LIVE' : 'SYSTEM STATUS: LOBBY' }}
    </template>
    <template #ticker-content>
      <span>AUCTION: {{ store.auction?.name ?? '—' }}</span>
      <span>CODE: {{ store.auction?.join_code ?? '—' }}</span>
      <span class="text-tertiary">COACHES CONNECTED: {{ connectedCount }}</span>
      <span>READY: {{ readyCount }} / {{ coaches.length }}</span>
    </template>

    <!-- ── Main content ── -->
    <div
      v-if="store.loading"
      class="h-[calc(100vh-104px)] flex items-center justify-center"
    >
      <span class="material-symbols-outlined text-4xl text-primary animate-spin">autorenew</span>
    </div>

    <div
      v-else-if="store.error"
      class="h-[calc(100vh-104px)] flex flex-col items-center justify-center gap-4"
    >
      <span class="material-symbols-outlined text-4xl text-error">error</span>
      <p class="text-sm font-label text-error uppercase">{{ store.error }}</p>
      <button
        class="px-6 py-2 border border-primary text-primary font-label uppercase text-xs hover:bg-primary/10"
        @click="router.go(0)"
      >
        Retry
      </button>
    </div>

    <div
      v-else
      class="p-8 h-[calc(100vh-104px)] overflow-hidden grid grid-cols-12 gap-8"
    >
      <!-- ── Left column: participant list ── -->
      <section class="col-span-4 flex flex-col space-y-6">
        <div class="flex items-center justify-between">
          <h2 class="font-headline text-2xl font-black uppercase tracking-tighter text-on-surface">
            {{ isAdmin ? 'Operational Manifest' : 'Staff Readiness' }}
          </h2>
          <span class="text-xs font-label text-outline bg-surface-container px-2 py-1">
            TOTAL: {{ store.participants.length }}
          </span>
        </div>

        <div class="flex-1 space-y-3 overflow-y-auto pr-2">
          <ParticipantCard
            v-for="p in store.participants"
            :key="p.id"
            :participant="p"
            :team="teamFor(p.id)"
            :is-admin="isAdmin"
            :is-me="p.id === store.myParticipant?.id"
            @toggle-ready="toggleReady"
          />
          <p v-if="store.participants.length === 0" class="text-sm text-outline font-label text-center py-8">
            No participants yet — share the join code.
          </p>
        </div>
      </section>

      <!-- ── Right column: practice zone or admin console ── -->

      <!-- COACH: practice bidding zone -->
      <section v-if="!isAdmin" class="col-span-8 flex flex-col space-y-6">
        <h2 class="font-headline text-2xl font-black uppercase tracking-tighter text-on-surface">
          Practice Bidding Zone
        </h2>
        <PracticeBiddingZone />
      </section>

      <!-- ADMIN: draft management console -->
      <section v-else class="col-span-8 flex flex-col space-y-6">
        <div class="flex items-center justify-between">
          <h2 class="font-headline text-2xl font-black uppercase tracking-tighter text-on-surface">
            Draft Management Console
          </h2>
          <div class="flex items-center gap-4">
            <div class="bg-surface-container-high px-4 py-1 flex flex-col items-end">
              <span class="text-[10px] font-label text-outline">REMAINING SCHOOLS</span>
              <span class="text-xl font-headline font-black text-primary">{{ store.availableSchools.length }}</span>
            </div>
            <div class="bg-secondary-container px-4 py-1 flex flex-col items-end">
              <span class="text-[10px] font-label text-on-secondary-container">COACHES READY</span>
              <span class="text-xl font-headline font-black text-on-secondary-container">
                {{ readyCount }} / {{ coaches.length }}
              </span>
            </div>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto space-y-6 pr-2">
          <!-- Current school on the block (if practice running) -->
          <div
            v-if="store.auction?.current_school_id"
            class="relative bg-surface-container border border-outline-variant/30"
          >
            <div class="p-6 grid grid-cols-3 gap-6">
              <div>
                <div class="text-[10px] font-label text-outline mb-1 uppercase">On The Block</div>
                <div class="text-lg font-headline font-bold text-on-surface">
                  {{ store.schools.find(s => s.id === store.auction!.current_school_id)?.school?.name ?? '—' }}
                </div>
              </div>
              <div>
                <div class="text-[10px] font-label text-outline mb-1 uppercase">Current Bid</div>
                <div class="text-lg font-headline font-bold text-primary">
                  ${{ store.auction.current_high_bid ?? 0 }}
                </div>
              </div>
              <div>
                <div class="text-[10px] font-label text-outline mb-1 uppercase">Status</div>
                <div class="text-sm font-label text-tertiary uppercase font-bold">
                  {{ store.auction.status }}
                </div>
              </div>
            </div>
          </div>

          <!-- Practice bidding zone (admin variant) -->
          <PracticeBiddingZone :is-admin="true" />

          <!-- Global action center -->
          <div class="bg-surface-container-high p-8 border-t-4 border-secondary flex flex-col items-center space-y-6">
            <div class="text-center">
              <div class="text-xs font-label text-outline uppercase tracking-[0.2em] mb-2">Pre-Draft Status</div>
              <div
                v-if="notReadyCoach"
                class="text-lg font-headline font-bold text-error uppercase italic"
              >
                Awaiting {{ notReadyCoach.display_name }}
              </div>
              <div v-else class="text-lg font-headline font-bold text-tertiary uppercase">
                All Coaches Ready
              </div>
            </div>

            <!-- Practice controls -->
            <div class="w-full max-w-lg space-y-3">
              <p v-if="practiceError" class="text-xs text-error font-label">{{ practiceError }}</p>
              <div v-if="!store.auction?.current_school_id" class="flex gap-2">
                <select
                  v-model="practiceSchoolId"
                  class="flex-1 bg-surface-container border border-outline-variant/50 text-on-surface text-xs font-label px-3 py-2 focus:outline-none focus:border-primary"
                >
                  <option :value="null">— Pick a practice school —</option>
                  <option
                    v-for="s in store.availableSchools.slice(0, 20)"
                    :key="s.id"
                    :value="s.id"
                  >{{ s.school?.name ?? s.id }}</option>
                </select>
                <button
                  :disabled="!practiceSchoolId || practiceSubmitting"
                  class="px-4 py-2 bg-surface-container hover:bg-primary/10 border border-primary/30 font-headline font-bold text-primary text-xs uppercase tracking-wider transition-all disabled:opacity-40"
                  @click="startPractice"
                >
                  {{ practiceSubmitting ? '...' : 'Start Practice' }}
                </button>
              </div>
              <button
                v-else
                class="w-full bg-error-container/30 hover:bg-error/20 border border-error/30 py-2 font-label text-error text-xs uppercase"
                @click="stopPractice"
              >
                Stop Practice
              </button>
            </div>

            <div class="flex gap-4 w-full max-w-lg">
              <button
                :disabled="!!notReadyCoach && !submitting"
                class="flex-[2] bg-secondary-container hover:bg-secondary/20 text-on-secondary-container border border-secondary/50 py-4 font-headline font-black text-xl transition-all uppercase tracking-[0.2em] shadow-xl active:scale-[0.98] disabled:opacity-40"
                @click="startDraft(false)"
              >
                {{ submitting ? 'STARTING...' : 'START DRAFT' }}
              </button>
            </div>

            <button
              class="text-xs font-label text-secondary underline hover:text-white transition-colors uppercase"
              @click="startDraft(true)"
            >
              Skip Readiness Check (Admin Override)
            </button>
          </div>
        </div>
      </section>
    </div>
  </AppShell>
</template>
