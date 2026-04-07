<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuctionStore } from '@/stores/auction'

const router = useRouter()
const store = useAuctionStore()

// ── Form state ─────────────────────────────────────────────────────────────
const auctionName = ref('')
const joinCode = ref(generateCode())
const participantCount = ref(6)
const budget = ref(200)
const schoolSource = ref<'default' | 'csv'>('default')
const submitting = ref(false)
const errorMsg = ref('')
const creatorName = ref('')

// Roster positions (editable)
const rosterPositions = ref([
  { position_name: 'SEC', slots_per_team: 2, is_flex: false, display_order: 1, color_code: '#DC2626' },
  { position_name: 'Big Ten', slots_per_team: 2, is_flex: false, display_order: 2, color_code: '#2563EB' },
  { position_name: 'ACC', slots_per_team: 1, is_flex: false, display_order: 3, color_code: '#7C3AED' },
  { position_name: 'Big 12', slots_per_team: 1, is_flex: false, display_order: 4, color_code: '#D97706' },
  { position_name: 'Flex', slots_per_team: 2, is_flex: true, display_order: 5, color_code: '#6B7280' },
])

const codeCopied = ref(false)

function generateCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  return Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

function refreshCode() {
  joinCode.value = generateCode()
}

async function copyCode() {
  await navigator.clipboard.writeText(joinCode.value)
  codeCopied.value = true
  setTimeout(() => (codeCopied.value = false), 2000)
}

const canCreate = computed(
  () => auctionName.value.trim().length >= 2 && creatorName.value.trim().length >= 2,
)

// ── Submit ──────────────────────────────────────────────────────────────────
async function createAuction() {
  if (!canCreate.value) return
  submitting.value = true
  errorMsg.value = ''

  // 1. Anonymous auth (get a supabase_uid; no RLS-sensitive DB calls on the client)
  const { data: authData, error: authErr } = await supabase.auth.signInAnonymously()
  if (authErr || !authData.user) {
    errorMsg.value = 'Authentication failed.'
    submitting.value = false
    return
  }

  // 2. Call create-auction edge function (uses service role key, bypasses RLS)
  const { data, error } = await supabase.functions.invoke('create-auction', {
    body: {
      auction_name: auctionName.value.trim(),
      join_code: joinCode.value,
      participant_count: participantCount.value,
      budget: budget.value,
      creator_name: creatorName.value.trim(),
      school_source: schoolSource.value,
      roster_positions: rosterPositions.value,
      supabase_uid: authData.user.id,
    },
  })

  if (error || !data?.ok) {
    const msg = data?.error ?? error?.message ?? 'Failed to create auction.'
    errorMsg.value =
      msg === 'JOIN_CODE_CONFLICT'
        ? 'That join code is already in use. Click the refresh icon to generate a new one.'
        : msg
    submitting.value = false
    return
  }

  const { auction_id, participant_id, team_id, session_token, role } = data

  // 3. Persist session locally
  localStorage.setItem('auction_session', JSON.stringify({ sessionToken: session_token }))

  store.saveSession({
    participantId: participant_id,
    auctionId: auction_id,
    teamId: team_id,
    role,
    displayName: creatorName.value.trim(),
    sessionToken: session_token,
    supabaseUid: authData.user.id,
  })

  if (schoolSource.value === 'csv') {
    router.push({ name: 'admin-schools', query: { auction_id, setup: '1' } })
    return
  }

  router.push(`/auction/${auction_id}/lobby`)
}


function updateSlotCount(idx: number, delta: number) {
  const rp = rosterPositions.value[idx]
  if (!rp) return
  const newVal = rp.slots_per_team + delta
  if (newVal >= 1 && newVal <= 10) rp.slots_per_team = newVal
}
</script>

<template>
  <div class="min-h-screen bg-surface-container-lowest text-on-surface">
    <!-- Simple header for this pre-session page -->
    <header
      class="fixed top-0 w-full z-50 flex justify-between items-center px-8 h-16 font-headline uppercase"
      style="background: #0a0e14; border-bottom: 1px solid rgba(49,53,60,0.3);"
    >
      <span class="text-2xl font-black italic tracking-widest text-primary">LEAGIFY</span>
      <router-link to="/join" class="text-xs font-label text-outline hover:text-primary transition-colors tracking-wider uppercase">
        ← Join Instead
      </router-link>
    </header>

    <main class="pt-24 pb-32 px-4 md:px-8 max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-8">

      <!-- Left Column -->
      <div class="lg:col-span-7 space-y-8">

        <!-- Title -->
        <div class="flex items-center gap-3">
          <div class="w-2 h-8 bg-tertiary" style="transform: skewX(-10deg)"></div>
          <h1 class="text-3xl font-black font-headline uppercase tracking-tighter">Initialize New Auction</h1>
        </div>

        <div class="glass-panel p-8 space-y-8">

          <!-- Auction Name + Creator Name -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="space-y-2">
              <label class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block">
                Auction Name
              </label>
              <input
                v-model="auctionName"
                type="text"
                placeholder="e.g. B1G COMMANDER 2026"
                class="input-underline w-full text-lg py-2 font-headline font-bold"
              />
            </div>
            <div class="space-y-2">
              <label class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block">
                Your Name
              </label>
              <input
                v-model="creatorName"
                type="text"
                maxlength="20"
                placeholder="e.g. Commissioner Ross"
                class="input-underline w-full text-lg py-2 font-headline font-bold"
              />
            </div>
          </div>

          <!-- Join Code -->
          <div class="space-y-2">
            <label class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block">
              Join Code
            </label>
            <div class="flex items-center gap-2">
              <div class="flex-1 relative">
                <input
                  :value="joinCode"
                  readonly
                  class="w-full bg-surface-container-low px-4 py-3 font-mono text-2xl tracking-[0.4em] text-primary font-black rounded-sm"
                />
              </div>
              <button
                class="p-3 bg-surface-container-high hover:bg-surface-container-highest transition-colors text-on-surface-variant hover:text-primary"
                title="Generate new code"
                @click="refreshCode"
              >
                <span class="material-symbols-outlined">refresh</span>
              </button>
              <button
                class="p-3 bg-surface-container-high hover:bg-surface-container-highest transition-colors"
                :class="codeCopied ? 'text-tertiary' : 'text-on-surface-variant hover:text-primary'"
                title="Copy code"
                @click="copyCode"
              >
                <span class="material-symbols-outlined">{{ codeCopied ? 'check' : 'content_copy' }}</span>
              </button>
            </div>
          </div>

          <!-- Participant Count + Budget -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div class="bg-surface-container-low p-6">
              <label class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block mb-4">
                Participant Limit
              </label>
              <div class="flex items-center justify-between">
                <button
                  class="w-10 h-10 border border-outline-variant hover:border-primary flex items-center justify-center active:scale-90 transition-transform"
                  :disabled="participantCount <= 2"
                  @click="participantCount--"
                >
                  <span class="material-symbols-outlined">remove</span>
                </button>
                <span class="text-4xl font-black font-headline">{{ String(participantCount).padStart(2, '0') }}</span>
                <button
                  class="w-10 h-10 border border-outline-variant hover:border-primary flex items-center justify-center active:scale-90 transition-transform"
                  :disabled="participantCount >= 12"
                  @click="participantCount++"
                >
                  <span class="material-symbols-outlined">add</span>
                </button>
              </div>
              <p class="text-[10px] text-on-surface-variant mt-3 text-center uppercase tracking-widest font-bold">
                Standard Coaches
              </p>
            </div>

            <div class="bg-surface-container-low p-6">
              <label class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block mb-4">
                Total Budget
              </label>
              <div class="flex items-center justify-between px-2 py-3">
                <span class="text-2xl font-bold text-outline-variant">$</span>
                <input
                  v-model.number="budget"
                  type="number"
                  min="10"
                  max="1000"
                  step="1"
                  class="bg-transparent border-none text-4xl font-black font-headline text-center focus:outline-none w-32 text-on-surface"
                />
                <span class="text-xs font-bold text-outline uppercase">USD</span>
              </div>
              <p class="text-[10px] text-on-surface-variant mt-1 text-center uppercase tracking-widest font-bold">
                Whole Dollars Only
              </p>
            </div>
          </div>
        </div>

        <!-- School Data Source -->
        <section>
          <div class="flex items-center gap-3 mb-4">
            <span class="material-symbols-outlined text-primary">database</span>
            <h2 class="text-xl font-black font-headline uppercase tracking-tighter">School Database</h2>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <button
              class="group relative overflow-hidden p-6 text-left border transition-all"
              :class="schoolSource === 'default'
                ? 'bg-surface-container-high border-primary'
                : 'bg-surface-container border-outline-variant/30 hover:border-primary/50'"
              @click="schoolSource = 'default'"
            >
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="font-headline font-bold text-lg mb-1">DEFAULT 2026 SET</h3>
                  <p class="text-xs text-on-surface-variant leading-relaxed">Use the built-in school roster from the database.</p>
                </div>
                <span
                  class="material-symbols-outlined transition-colors"
                  :class="schoolSource === 'default' ? 'text-primary' : 'text-outline'"
                  :style="schoolSource === 'default' ? 'font-variation-settings: \'FILL\' 1' : ''"
                >check_circle</span>
              </div>
              <div v-if="schoolSource === 'default'" class="absolute bottom-0 left-0 w-full h-1 bg-primary"></div>
            </button>

            <button
              class="group p-6 text-left border transition-all"
              :class="schoolSource === 'csv'
                ? 'bg-surface-container-high border-tertiary'
                : 'bg-surface-container border-outline-variant/30 hover:border-outline-variant'"
              @click="schoolSource = 'csv'"
            >
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="font-headline font-bold text-lg mb-1">UPLOAD CSV</h3>
                  <p class="text-xs text-on-surface-variant leading-relaxed">Import custom school data after creating. You'll be redirected to the schools manager.</p>
                </div>
                <span
                  class="material-symbols-outlined transition-colors"
                  :class="schoolSource === 'csv' ? 'text-tertiary' : 'text-outline'"
                >cloud_upload</span>
              </div>
            </button>
          </div>
        </section>

        <p v-if="errorMsg" class="text-sm text-error font-label bg-error-container/20 px-4 py-3">
          {{ errorMsg }}
        </p>

        <button
          :disabled="!canCreate || submitting"
          class="w-full metallic-primary py-6 font-headline font-black text-2xl uppercase tracking-widest text-on-primary-fixed transition-opacity disabled:opacity-40 active:scale-[0.98] shadow-stadium"
          @click="createAuction"
        >
          {{ submitting ? 'INITIALIZING...' : 'LAUNCH AUCTION →' }}
        </button>
      </div>

      <!-- Right Column: Roster Architecture -->
      <div class="lg:col-span-5">
        <aside class="sticky top-24 space-y-6">
          <div
            class="px-4 py-2 flex items-center justify-between border-l-4 border-secondary font-headline font-black text-sm tracking-widest uppercase"
            style="background: #31353c; transform: skewX(-10deg);"
          >
            <span style="transform: skewX(10deg)">Roster Architecture</span>
            <span class="material-symbols-outlined text-secondary text-sm" style="transform: skewX(10deg)">architecture</span>
          </div>

          <div class="glass-panel p-6 space-y-3">
            <div
              v-for="(rp, idx) in rosterPositions"
              :key="idx"
              class="flex items-center justify-between bg-surface-container-low p-3 hover:bg-surface-container transition-colors"
            >
              <div class="flex items-center gap-4">
                <div
                  class="w-10 h-10 bg-surface-container-highest flex items-center justify-center font-black font-headline text-primary"
                >
                  {{ String(rp.slots_per_team).padStart(2, '0') }}
                </div>
                <div>
                  <div class="font-headline font-bold text-sm tracking-tight">{{ rp.position_name }}</div>
                  <div class="text-[10px] text-on-surface-variant uppercase font-bold tracking-tighter">
                    {{ rp.is_flex ? 'Flex — Any School' : 'Conference Primary' }}
                  </div>
                </div>
              </div>
              <div class="flex items-center gap-1">
                <button
                  class="w-7 h-7 flex items-center justify-center text-outline hover:text-primary transition-colors"
                  @click="updateSlotCount(idx, -1)"
                >
                  <span class="material-symbols-outlined text-base">remove</span>
                </button>
                <button
                  class="w-7 h-7 flex items-center justify-center text-outline hover:text-primary transition-colors"
                  @click="updateSlotCount(idx, 1)"
                >
                  <span class="material-symbols-outlined text-base">add</span>
                </button>
              </div>
            </div>

            <div class="pt-4 border-t border-outline-variant/20">
              <div class="flex justify-between text-xs font-label text-outline uppercase tracking-wider">
                <span>Total slots per team</span>
                <span class="text-primary font-bold">
                  {{ rosterPositions.reduce((s, rp) => s + rp.slots_per_team, 0) }}
                </span>
              </div>
            </div>
          </div>
        </aside>
      </div>

    </main>
  </div>
</template>
