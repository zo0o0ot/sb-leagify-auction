<script setup lang="ts">
import type { Participant, Team } from '@/types/auction'

const props = defineProps<{
  participant: Participant
  team: Team | null
  isAdmin?: boolean
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
      participant.is_connected && participant.is_ready
        ? 'border-l-4 border-primary'
        : !participant.is_connected
          ? 'border-l-4 border-error opacity-80'
          : 'border-l-4 border-surface-variant'
    "
  >
    <div class="flex items-center gap-4">
      <!-- Avatar -->
      <div
        class="w-12 h-12 flex items-center justify-center font-headline font-black text-xl rounded-sm"
        :class="
          participant.is_connected
            ? 'bg-gradient-to-br from-primary to-surface-container-highest text-on-primary-fixed'
            : 'bg-surface-container-high text-outline'
        "
        style="transform: skewX(-10deg)"
      >
        <span style="transform: skewX(10deg)">{{ initials }}</span>
      </div>
      <div>
        <div class="font-headline font-bold uppercase tracking-tight text-on-surface text-sm">
          {{ participant.display_name }}
        </div>
        <div class="text-[10px] font-label text-outline uppercase">
          {{ team ? team.team_name : 'No team' }}
        </div>
      </div>
    </div>

    <!-- Status indicators -->
    <div class="flex gap-4">
      <div class="flex flex-col items-center">
        <span
          class="w-2 h-2 rounded-full"
          :class="participant.is_connected ? 'bg-green-500 shadow-[0_0_6px_rgba(34,197,94,0.6)]' : 'bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.6)]'"
        ></span>
        <span class="text-[9px] font-label mt-1 text-on-surface-variant uppercase">Tech</span>
      </div>
      <div class="flex flex-col items-center">
        <span
          class="material-symbols-outlined text-xl"
          :class="participant.is_ready ? 'text-primary' : 'text-outline'"
          :style="participant.is_ready ? 'font-variation-settings: \'FILL\' 1' : ''"
        >check_box{{ participant.is_ready ? '' : '_outline_blank' }}</span>
        <span class="text-[9px] font-label mt-0.5 text-on-surface-variant uppercase">Ready</span>
      </div>
    </div>
  </div>
</template>
