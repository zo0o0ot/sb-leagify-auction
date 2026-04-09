<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuctionStore } from '@/stores/auction'

const router = useRouter()
const store = useAuctionStore()

const joinCode = ref('')
const displayName = ref('')
const errorMsg = ref('')
const submitting = ref(false)

// Step 1: look up auction + unclaimed slots
const step = ref<'form' | 'pick-slot'>('form')
const foundAuction = ref<{ id: number; name: string } | null>(null)
const unclaimedTeams = ref<{ id: number; team_name: string }[]>([])
const selectedTeamId = ref<number | null>(null)

const codeError = computed(() => {
  if (!joinCode.value) return ''
  if (!/^[A-Z0-9]{6}$/i.test(joinCode.value)) return 'Code must be 6 alphanumeric characters'
  return ''
})

const nameError = computed(() => {
  if (!displayName.value) return ''
  if (displayName.value.length < 2) return 'Name must be at least 2 characters'
  if (displayName.value.length > 20) return 'Name must be 20 characters or less'
  return ''
})

const canLookup = computed(
  () => !codeError.value && joinCode.value.length === 6 && displayName.value.length >= 2,
)

async function lookupAuction() {
  errorMsg.value = ''
  submitting.value = true

  // Find auction by join code
  const { data: auction, error: auctionErr } = await supabase
    .from('auctions')
    .select('id, name, status')
    .eq('join_code', joinCode.value.toUpperCase())
    .single()

  if (auctionErr || !auction) {
    errorMsg.value = 'Auction not found. Check your join code.'
    submitting.value = false
    return
  }

  if (auction.status === 'completed' || auction.status === 'archived') {
    errorMsg.value = 'This auction has already ended.'
    submitting.value = false
    return
  }

  // Check if display name already taken by a connected user
  const { data: existing } = await supabase
    .from('participants')
    .select('id, is_connected, session_token, team_id, role')
    .eq('auction_id', auction.id)
    .eq('display_name', displayName.value)
    .maybeSingle()

  // We intentionally allow reconnection even if is_connected is still true —
  // the flag may not have been cleared if the previous session crashed.

  // Find unclaimed team slots (teams with no participant linked)
  const { data: teams } = await supabase
    .from('teams')
    .select('id, team_name')
    .eq('auction_id', auction.id)
    .order('nomination_order')

  // Find which teams already have a participant
  const { data: participants } = await supabase
    .from('participants')
    .select('team_id')
    .eq('auction_id', auction.id)
    .not('team_id', 'is', null)

  const claimedTeamIds = new Set((participants ?? []).map((p) => p.team_id))

  // If reconnecting, their old team is still theirs
  const reconTeamId = existing?.team_id ?? null
  unclaimedTeams.value = (teams ?? []).filter(
    (t) => !claimedTeamIds.has(t.id) || t.id === reconTeamId,
  )

  foundAuction.value = auction
  step.value = 'pick-slot'
  submitting.value = false
}

async function joinAuction() {
  if (!foundAuction.value || !selectedTeamId.value) return
  errorMsg.value = ''
  submitting.value = true

  // Anonymous auth — sign out first to clear any stale session from a previous join or admin flow
  await supabase.auth.signOut()
  const { data: authData, error: authErr } = await supabase.auth.signInAnonymously()
  if (authErr || !authData.user) {
    errorMsg.value = 'Authentication failed. Please try again.'
    submitting.value = false
    return
  }

  const sessionToken = crypto.randomUUID()
  const auctionId = foundAuction.value.id

  // Check for existing participant (reconnect)
  const { data: existing } = await supabase
    .from('participants')
    .select('id, role, team_id')
    .eq('auction_id', auctionId)
    .eq('display_name', displayName.value)
    .maybeSingle()

  let participantId: number
  let role: 'auction_master' | 'team_coach' | 'viewer'
  let teamId: number | null

  if (existing) {
    // Reconnect — update session token + connection status
    const { error: updateErr } = await supabase
      .from('participants')
      .update({ session_token: sessionToken, is_connected: true })
      .eq('id', existing.id)

    if (updateErr) {
      errorMsg.value = 'Failed to reconnect. Please try again.'
      submitting.value = false
      return
    }
    participantId = existing.id
    role = existing.role
    teamId = existing.team_id
  } else {
    // New participant
    const { data: newP, error: insertErr } = await supabase
      .from('participants')
      .insert({
        auction_id: auctionId,
        display_name: displayName.value,
        role: 'team_coach',
        team_id: selectedTeamId.value,
        session_token: sessionToken,
        is_connected: true,
      })
      .select('id, role, team_id')
      .single()

    if (insertErr || !newP) {
      errorMsg.value = insertErr?.message ?? 'Failed to join. Please try again.'
      submitting.value = false
      return
    }

    // Update team name to display name
    await supabase
      .from('teams')
      .update({ team_name: displayName.value })
      .eq('id', selectedTeamId.value)

    participantId = newP.id
    role = newP.role
    teamId = newP.team_id
  }

  store.saveSession({
    participantId,
    auctionId,
    teamId,
    role,
    displayName: displayName.value,
    sessionToken,
    supabaseUid: authData.user.id,
  })

  router.push(`/auction/${auctionId}/lobby`)
}
</script>

<template>
  <div class="min-h-screen bg-surface-container-lowest flex items-center justify-center p-4">
    <!-- Background accent -->
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-primary/5 rounded-full blur-3xl"></div>
      <div
        class="absolute bottom-1/4 right-1/4 w-96 h-96 bg-secondary/5 rounded-full blur-3xl"
      ></div>
    </div>

    <div class="relative w-full max-w-md">
      <!-- Logo -->
      <div class="text-center mb-10">
        <h1
          class="text-4xl font-black italic tracking-widest text-primary font-headline uppercase mb-2"
        >
          LEAGIFY DRAFT COMMAND
        </h1>
        <p class="text-xs font-label text-outline uppercase tracking-[0.3em]">
          Fantasy Auction System
        </p>
      </div>

      <!-- Step 1: Code + Name form -->
      <div v-if="step === 'form'" class="glass-panel p-8 space-y-8">
        <div class="space-y-2 border-l-4 border-primary pl-4">
          <h2 class="font-headline font-black text-2xl uppercase tracking-tighter text-on-surface">
            Join Auction
          </h2>
          <p class="text-xs text-on-surface-variant font-label uppercase tracking-wider">
            Enter your code and display name
          </p>
        </div>

        <div class="space-y-6">
          <!-- Join Code -->
          <div class="space-y-2">
            <label
              class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block"
            >
              Join Code
            </label>
            <input
              v-model="joinCode"
              type="text"
              maxlength="6"
              placeholder="e.g. XP882G"
              class="input-underline w-full text-2xl font-headline font-black tracking-[0.3em] uppercase py-2"
              :class="{ 'border-b-error': codeError }"
              @keyup.enter="canLookup && lookupAuction()"
            />
            <p v-if="codeError" class="text-xs text-error font-label">{{ codeError }}</p>
          </div>

          <!-- Display Name -->
          <div class="space-y-2">
            <label
              class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block"
            >
              Your Name
            </label>
            <input
              v-model="displayName"
              type="text"
              maxlength="20"
              placeholder="e.g. Coach Riley"
              class="input-underline w-full text-lg font-headline font-bold py-2"
              :class="{ 'border-b-error': nameError }"
              @keyup.enter="canLookup && lookupAuction()"
            />
            <p v-if="nameError" class="text-xs text-error font-label">{{ nameError }}</p>
          </div>
        </div>

        <p v-if="errorMsg" class="text-sm text-error font-label bg-error-container/20 px-4 py-3">
          {{ errorMsg }}
        </p>

        <button
          :disabled="!canLookup || submitting"
          class="w-full metallic-primary py-5 font-headline font-black text-xl uppercase tracking-widest text-on-primary-fixed transition-opacity disabled:opacity-40 active:scale-[0.98]"
          @click="lookupAuction"
        >
          {{ submitting ? 'LOOKING UP...' : 'FIND AUCTION →' }}
        </button>

        <div class="text-center">
          <router-link
            to="/create"
            class="text-xs font-label text-outline hover:text-primary transition-colors uppercase tracking-wider"
          >
            Create a new auction instead
          </router-link>
        </div>
      </div>

      <!-- Step 2: Pick team slot -->
      <div v-else-if="step === 'pick-slot'" class="glass-panel p-8 space-y-6">
        <div class="space-y-1">
          <div class="text-xs font-label text-outline uppercase tracking-wider">Joining</div>
          <h2 class="font-headline font-black text-2xl uppercase tracking-tighter text-on-surface">
            {{ foundAuction?.name }}
          </h2>
          <p class="text-sm text-on-surface-variant font-label">
            Pick your team slot, <span class="text-primary font-bold">{{ displayName }}</span>
          </p>
        </div>

        <div class="space-y-2">
          <label class="font-label text-xs font-bold text-tertiary uppercase tracking-wider block">
            Available Slots
          </label>
          <div class="space-y-2">
            <button
              v-for="team in unclaimedTeams"
              :key="team.id"
              class="w-full flex items-center justify-between p-4 border-l-4 transition-all font-headline font-bold uppercase text-sm"
              :class="
                selectedTeamId === team.id
                  ? 'border-primary bg-primary/10 text-primary'
                  : 'border-surface-variant bg-surface-container hover:border-primary/50 hover:bg-surface-container-high text-on-surface-variant'
              "
              @click="selectedTeamId = team.id"
            >
              <span>{{ team.team_name }}</span>
              <span
                v-if="selectedTeamId === team.id"
                class="material-symbols-outlined text-primary text-lg"
                style="font-variation-settings: 'FILL' 1"
                >check_circle</span
              >
            </button>
          </div>
          <p v-if="unclaimedTeams.length === 0" class="text-sm text-error font-label py-2">
            No open team slots. Contact the auction host.
          </p>
        </div>

        <p v-if="errorMsg" class="text-sm text-error font-label bg-error-container/20 px-4 py-3">
          {{ errorMsg }}
        </p>

        <div class="flex gap-3">
          <button
            class="flex-1 bg-surface-container border border-outline-variant/30 py-4 font-headline font-bold text-sm uppercase text-on-surface-variant hover:text-on-surface transition-colors"
            @click="step = 'form'"
          >
            ← Back
          </button>
          <button
            :disabled="!selectedTeamId || submitting"
            class="flex-[2] metallic-primary py-4 font-headline font-black text-lg uppercase tracking-widest text-on-primary-fixed transition-opacity disabled:opacity-40 active:scale-[0.98]"
            @click="joinAuction"
          >
            {{ submitting ? 'JOINING...' : 'LOCK IN →' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
