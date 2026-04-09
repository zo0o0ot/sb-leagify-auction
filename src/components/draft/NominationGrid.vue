<script setup lang="ts">
import { ref, computed } from 'vue'
import { useAuctionStore } from '@/stores/auction'

const emit = defineEmits<{ close: [] }>()

const store = useAuctionStore()
const submitting = ref(false)
const selectedConference = ref('ALL')
const searchQuery = ref('')

const rosterSlots = computed(() => {
  const teamId = store.activeTeam?.id
  if (!teamId) return []
  return store.rosterPositions.map((rp) => {
    const filled = store.draftPicks.filter(
      (dp) => dp.team_id === teamId && dp.roster_position_id === rp.id,
    ).length
    const open = Math.max(0, rp.slots_per_team - filled)
    return { ...rp, filled, open }
  })
})

const conferences = computed(() => {
  const confs = new Set<string>()
  store.availableSchools.forEach((s) => {
    if (s.conference) confs.add(s.conference)
  })
  return ['ALL', ...Array.from(confs).sort()]
})

const filteredSchools = computed(() => {
  let list = store.availableSchools
  if (selectedConference.value !== 'ALL') {
    list = list.filter((s) => s.conference === selectedConference.value)
  }
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter((s) => s.school?.name.toLowerCase().includes(q))
  }
  return [...list].sort((a, b) => b.projected_points - a.projected_points)
})

async function nominate(auctionSchoolId: number) {
  submitting.value = true
  await store.nominateSchool(auctionSchoolId)
  submitting.value = false
  emit('close')
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
    @click.self="emit('close')"
  >
    <div
      class="bg-surface-container-low border border-outline-variant/30 w-full max-w-4xl max-h-[85vh] flex flex-col shadow-2xl"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-outline-variant/20 bg-surface-container-high"
      >
        <div>
          <div class="font-headline font-black uppercase text-on-surface tracking-tight text-xl">
            YOUR TURN TO NOMINATE
          </div>
          <div class="text-[10px] font-label text-outline uppercase tracking-widest">
            Remaining Budget: ${{ store.activeTeam?.remaining_budget ?? 0 }} &bull;
            {{ store.availableSchools.length }} schools available
          </div>
        </div>
        <button
          class="p-2 hover:bg-surface-container text-outline transition-colors"
          @click="emit('close')"
        >
          <span class="material-symbols-outlined">close</span>
        </button>
      </div>

      <!-- Roster summary -->
      <div
        class="px-6 py-3 border-b border-outline-variant/20 bg-surface-container-lowest flex items-center gap-2 flex-wrap"
      >
        <span class="text-[10px] font-label text-outline uppercase tracking-widest mr-1"
          >My Roster</span
        >
        <div
          v-for="slot in rosterSlots"
          :key="slot.id"
          class="flex items-center gap-1.5 px-2.5 py-1 border text-[10px] font-label font-bold uppercase"
          :class="
            slot.open > 0
              ? 'border-primary/30 bg-primary/10 text-primary'
              : 'border-outline-variant/20 bg-surface-container text-outline'
          "
        >
          <span>{{ slot.position_name }}</span>
          <span class="opacity-60">{{ slot.filled }}/{{ slot.slots_per_team }}</span>
          <span v-if="slot.open > 0" class="text-tertiary">· {{ slot.open }} open</span>
        </div>
      </div>

      <!-- Search + conference filter -->
      <div class="px-6 py-3 border-b border-outline-variant/20 flex items-center gap-4">
        <div class="relative flex-1">
          <span
            class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline text-sm"
            >search</span
          >
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Search programs..."
            class="w-full bg-surface-container border border-outline-variant/30 pl-10 pr-4 py-2 text-sm font-label text-on-surface placeholder:text-outline focus:outline-none focus:border-primary/50"
          />
        </div>
        <div class="flex gap-1 flex-wrap">
          <button
            v-for="conf in conferences"
            :key="conf"
            class="px-3 py-1 text-[10px] font-label font-bold uppercase transition-colors"
            :class="
              selectedConference === conf
                ? 'bg-secondary text-on-secondary'
                : 'bg-surface-container text-outline hover:bg-surface-container-high'
            "
            @click="selectedConference = conf"
          >
            {{ conf }}
          </button>
        </div>
      </div>

      <!-- School grid -->
      <div class="flex-1 overflow-y-auto p-4 grid grid-cols-2 gap-3">
        <div
          v-for="school in filteredSchools"
          :key="school.id"
          class="glass-panel p-4 flex items-center gap-4 border border-outline-variant/20 hover:border-primary/30 transition-colors group"
        >
          <!-- Logo -->
          <div class="w-14 h-14 bg-white p-1 flex-shrink-0 flex items-center justify-center">
            <img
              v-if="school.school?.logo_url"
              :src="school.school.logo_url"
              :alt="school.school.name"
              class="w-full h-full object-contain"
            />
            <span v-else class="font-headline font-black text-surface-container-lowest text-sm">
              {{ school.school?.name?.slice(0, 2).toUpperCase() }}
            </span>
          </div>

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <div
              class="font-headline font-bold uppercase text-on-surface text-sm tracking-tight truncate"
            >
              {{ school.school?.name }}
            </div>
            <div class="flex items-center gap-2 mt-0.5">
              <span class="text-[10px] font-label text-outline uppercase">{{
                school.conference
              }}</span>
              <span class="text-[10px] font-label text-tertiary font-bold uppercase"
                >{{ school.projected_points }} PTS</span
              >
            </div>
            <div class="text-[10px] font-label text-on-surface-variant uppercase mt-0.5">
              {{ school.leagify_position }}
            </div>
          </div>

          <!-- Nominate -->
          <button
            :disabled="submitting"
            class="flex-shrink-0 px-4 py-2 bg-secondary-container text-on-secondary-container font-label font-black text-xs uppercase hover:bg-secondary/20 transition-all active:scale-95 disabled:opacity-40"
            @click="nominate(school.id)"
          >
            NOMINATE
          </button>
        </div>

        <div
          v-if="filteredSchools.length === 0"
          class="col-span-2 py-16 text-center text-outline font-label uppercase text-sm"
        >
          No schools match — try a different conference or search
        </div>
      </div>
    </div>
  </div>
</template>
