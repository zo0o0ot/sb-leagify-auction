<script setup lang="ts">
import type { Participant, Team } from '@/types/auction'
import { useAuctionStore } from '@/stores/auction'

const store = useAuctionStore()

const props = defineProps<{
  participant: Participant
  team: Team | null
  isAdmin?: boolean
  isMe?: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle-ready'): void
}>()

const initials = props.participant.display_name
  .split(' ')
  .map((w) => w[0])
  .join('')
  .slice(0, 2)
  .toUpperCase()
</script>

<template>
  <div
    class="glass-panel p-4 flex items-center justify-between"
    :class="
      props.participant.is_connected && props.participant.is_ready
        ? 'border-l-4 border-primary'
        : !props.participant.is_connected
          ? 'border-l-4 border-error opacity-80'
          : 'border-l-4 border-surface-variant'
    "
  >
    <div class="flex items-center gap-4">
      <!-- Avatar -->
      <div
        class="w-12 h-12 flex items-center justify-center font-headline font-black text-xl rounded-sm"
        :class="
          props.participant.is_connected
            ? 'bg-gradient-to-br from-primary to-surface-container-highest text-on-primary-fixed'
            : 'bg-surface-container-high text-outline'
        "
        style="transform: skewX(-10deg)"
      >
        <span style="transform: skewX(10deg)">{{ initials }}</span>
      </div>
      <div>
        <div class="font-headline font-bold uppercase tracking-tight text-on-surface text-sm">
          {{ props.participant.display_name }}
        </div>
        <div class="text-[10px] font-label text-outline uppercase">
          {{ props.team ? store.getTeamDisplayName(props.team.id) : 'No team' }}
        </div>
      </div>
    </div>

    <!-- Status indicators -->
    <div class="flex items-center gap-6">
      
      <!-- Ready Toggle (Me only) -->
      <div v-if="props.isMe" class="flex flex-col items-center">
        <button
          class="relative inline-flex items-center cursor-pointer"
          @click="emit('toggle-ready')"
        >
          <div
            class="w-11 h-6 rounded-full transition-colors"
            :class="props.participant.is_ready ? 'bg-primary' : 'bg-surface-variant'"
          >
            <div
              class="absolute top-[2px] left-[2px] w-5 h-5 bg-white rounded-full shadow transition-transform"
              :class="props.participant.is_ready ? 'translate-x-5' : 'translate-x-0'"
            ></div>
          </div>
        </button>
        <span class="text-[9px] font-label mt-1 text-primary-fixed uppercase leading-tight">Ready</span>
      </div>

      <div v-else class="flex flex-col items-center">
        <span
          class="material-symbols-outlined text-xl"
          :class="props.participant.is_ready ? 'text-primary' : 'text-outline'"
          :style="props.participant.is_ready ? 'font-variation-settings: \'FILL\' 1' : ''"
        >check_box{{ props.participant.is_ready ? '' : '_outline_blank' }}</span>
        <span class="text-[9px] font-label mt-0.5 text-on-surface-variant uppercase">Ready</span>
      </div>

      <div class="flex flex-col items-center">
        <span
          class="w-2 h-2 rounded-full"
          :class="props.participant.is_connected ? 'bg-green-500 shadow-[0_0_6px_rgba(34,197,94,0.6)]' : 'bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.6)]'"
        ></span>
        <span class="text-[9px] font-label mt-1 text-on-surface-variant uppercase">Tech</span>
      </div>
    </div>
  </div>
</template>
