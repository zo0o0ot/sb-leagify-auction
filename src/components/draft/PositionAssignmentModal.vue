<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useAuctionStore } from '@/stores/auction'
import type { DraftPick } from '@/types/auction'

const props = defineProps<{ pick: DraftPick | null }>()
const emit = defineEmits<{ assigned: []; close: [] }>()

const store = useAuctionStore()
const submitting = ref(false)
const selectedPositionId = ref<number | null>(null)

// Pre-select best eligible position
watch(
  () => props.pick,
  (pick) => {
    if (!pick) return
    selectedPositionId.value = null
    // Find positions with remaining slots
    const eligible = store.rosterPositions.filter((rp) => {
      const filled = store.draftPicks.filter(
        (dp) => dp.team_id === pick.team_id && dp.roster_position_id === rp.id,
      ).length
      return filled < rp.slots_per_team
    })
    if (eligible.length > 0) selectedPositionId.value = eligible[0]!.id
  },
  { immediate: true },
)

const school = computed(() => {
  if (!props.pick) return null
  return props.pick.auction_school ?? null
})

const winningTeam = computed(() => {
  if (!props.pick) return null
  return store.teams.find((t) => t.id === props.pick!.team_id) ?? null
})

function slotsRemaining(positionId: number): number {
  if (!props.pick) return 0
  const rp = store.rosterPositions.find((r) => r.id === positionId)
  if (!rp) return 0
  const filled = store.draftPicks.filter(
    (dp) => dp.team_id === props.pick!.team_id && dp.roster_position_id === positionId,
  ).length
  return Math.max(0, rp.slots_per_team - filled)
}

async function confirm() {
  if (!props.pick || !selectedPositionId.value) return
  submitting.value = true
  await store.assignPosition(props.pick.id, selectedPositionId.value)
  submitting.value = false
  emit('assigned')
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="pick"
      class="fixed inset-0 z-[90] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
    >
      <div class="bg-surface-container-low border border-outline-variant/30 w-full max-w-md shadow-2xl">

        <!-- Header -->
        <div class="px-6 py-4 border-b border-outline-variant/20 bg-surface-container-high text-center">
          <div class="text-xs font-label text-tertiary uppercase tracking-[0.2em] mb-1">AUCTION CLOSED</div>
          <div class="font-headline font-black uppercase text-on-surface text-lg">
            YOU WON {{ school?.school?.name ?? 'SCHOOL' }} FOR ${{ pick.winning_bid }}!
          </div>
          <div class="text-[10px] font-label text-outline uppercase mt-1">{{ winningTeam?.team_name }}</div>
        </div>

        <!-- School badge -->
        <div class="flex items-center gap-4 px-6 py-4 border-b border-outline-variant/20">
          <div class="w-16 h-16 bg-white p-1.5 flex items-center justify-center flex-shrink-0">
            <img
              v-if="school?.school?.logo_url"
              :src="school.school.logo_url"
              :alt="school.school.name"
              class="w-full h-full object-contain"
            />
            <span v-else class="font-headline font-black text-surface-container-lowest text-xl">
              {{ school?.school?.name?.slice(0, 2).toUpperCase() }}
            </span>
          </div>
          <div>
            <div class="font-headline font-bold uppercase text-on-surface">{{ school?.school?.name }}</div>
            <div class="text-[10px] font-label text-outline uppercase">{{ school?.conference }} • {{ school?.leagify_position }}</div>
          </div>
        </div>

        <!-- Position picker -->
        <div class="px-6 py-4">
          <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-3">SELECT ROSTER SLOT</div>
          <div class="space-y-2">
            <label
              v-for="rp in store.rosterPositions"
              :key="rp.id"
              class="flex items-center justify-between p-3 border cursor-pointer transition-colors"
              :class="[
                selectedPositionId === rp.id
                  ? 'border-primary bg-primary/10'
                  : slotsRemaining(rp.id) > 0
                    ? 'border-outline-variant/30 hover:border-primary/30 hover:bg-surface-container'
                    : 'border-outline-variant/10 opacity-40 cursor-not-allowed',
              ]"
            >
              <div class="flex items-center gap-3">
                <input
                  type="radio"
                  :value="rp.id"
                  v-model="selectedPositionId"
                  :disabled="slotsRemaining(rp.id) === 0"
                  class="accent-primary"
                />
                <div>
                  <div class="font-label font-bold text-sm text-on-surface uppercase">{{ rp.position_name }}</div>
                  <div class="text-[10px] font-label text-outline uppercase">
                    {{ rp.is_flex ? 'Flex — Any School' : school?.conference ?? 'Conference Primary' }}
                  </div>
                </div>
              </div>
              <div class="text-right">
                <div
                  class="text-xs font-label font-bold uppercase"
                  :class="slotsRemaining(rp.id) > 0 ? 'text-tertiary' : 'text-error'"
                >
                  {{ slotsRemaining(rp.id) > 0 ? `${slotsRemaining(rp.id)} SLOT${slotsRemaining(rp.id) !== 1 ? 'S' : ''} REMAINING` : 'FULL' }}
                </div>
              </div>
            </label>
          </div>
        </div>

        <!-- Actions -->
        <div class="px-6 pb-6 flex gap-3">
          <button
            :disabled="!selectedPositionId || submitting"
            class="flex-1 py-4 bg-secondary-container text-on-secondary-container font-headline font-black text-sm uppercase tracking-widest hover:bg-secondary/20 transition-all active:scale-[0.98] disabled:opacity-40 flex items-center justify-center gap-2"
            @click="confirm"
          >
            <span class="material-symbols-outlined text-sm">lock</span>
            {{ submitting ? 'ASSIGNING...' : 'CONFIRM ASSIGNMENT' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
