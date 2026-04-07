<script setup lang="ts">
import { computed, watch, ref } from 'vue'
import { useAuctionStore } from '@/stores/auction'

const emit = defineEmits<{ dismissed: [] }>()

const store = useAuctionStore()

// The sting triggers when a draft pick arrives with no roster_position_id yet
// (i.e., the bid just completed). We track the latest pick we've shown a sting for.
const shownPickId = ref<number | null>(null)
const visible = ref(false)
const stingPick = ref<typeof store.draftPicks[0] | null>(null)

const latestPick = computed(() => {
  // Most recently created pick (highest pick_order, no position assigned yet)
  const picks = [...store.draftPicks].sort((a, b) => b.pick_order - a.pick_order)
  return picks[0] ?? null
})

watch(latestPick, (pick) => {
  if (!pick) return
  if (pick.id === shownPickId.value) return
  shownPickId.value = pick.id
  stingPick.value = pick
  visible.value = true
  // Auto-dismiss after 4 seconds
  setTimeout(() => dismiss(), 4000)
})

function dismiss() {
  visible.value = false
  emit('dismissed')
}

const winningTeam = computed(() => {
  if (!stingPick.value) return null
  return store.teams.find((t) => t.id === stingPick.value!.team_id) ?? null
})

const winningSchool = computed(() => {
  if (!stingPick.value) return null
  return stingPick.value.auction_school ?? null
})
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-all duration-400 ease-out"
      enter-from-class="opacity-0 scale-110"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition-all duration-300 ease-in"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="visible"
        class="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-black/90 backdrop-blur-md cursor-pointer"
        @click="dismiss"
      >
        <!-- Animated gold border sweep -->
        <div class="absolute inset-0 border-4 border-tertiary animate-pulse pointer-events-none"></div>

        <!-- School logo -->
        <div class="w-40 h-40 bg-white p-4 shadow-2xl mb-8 flex items-center justify-center animate-[sting-in_0.4s_cubic-bezier(0.16,1,0.3,1)]">
          <img
            v-if="winningSchool?.school?.logo_url"
            :src="winningSchool.school.logo_url"
            :alt="winningSchool.school?.name"
            class="w-full h-full object-contain"
          />
          <span v-else class="font-headline font-black text-surface-container-lowest text-4xl">
            {{ winningSchool?.school?.name?.slice(0, 2).toUpperCase() }}
          </span>
        </div>

        <div class="text-center space-y-3">
          <div class="text-xs font-label text-outline uppercase tracking-[0.4em]">THE PICK IS IN</div>
          <h2 class="font-headline font-black uppercase text-on-surface tracking-tighter text-6xl leading-none [filter:drop-shadow(0_0_25px_rgba(233,196,0,0.8))]">
            {{ winningSchool?.school?.name ?? 'AUCTION WON' }}
          </h2>
          <div class="flex items-center justify-center gap-6 mt-4">
            <div class="text-center">
              <div class="text-[10px] font-label text-outline uppercase tracking-widest">WINNER</div>
              <div class="font-headline font-bold uppercase text-primary text-xl">{{ winningTeam ? store.getTeamDisplayName(winningTeam.id) : '—' }}</div>
            </div>
            <div class="w-px h-12 bg-outline-variant/50"></div>
            <div class="text-center">
              <div class="text-[10px] font-label text-outline uppercase tracking-widest">PRICE</div>
              <div class="font-headline font-bold text-tertiary text-xl">${{ stingPick?.winning_bid ?? 0 }}</div>
            </div>
          </div>
        </div>

        <div class="absolute bottom-8 text-[10px] font-label text-outline uppercase tracking-widest animate-pulse">
          Click anywhere to continue
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
