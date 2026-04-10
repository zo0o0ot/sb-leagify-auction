<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuctionStore } from '@/stores/auction'
import { useAuctionRealtime } from '@/composables/useAuctionRealtime'
import AppShell from '@/components/AppShell.vue'

const route = useRoute()
const store = useAuctionStore()
const auctionId = Number(route.params.id)

useAuctionRealtime(auctionId)

const activeTeamId = ref<number | null>(null)

const sortedTeams = computed(() =>
  store.teams.filter((t) => t.is_active).sort((a, b) => a.nomination_order - b.nomination_order),
)

const selectedTeam = computed(
  () => sortedTeams.value.find((t) => t.id === activeTeamId.value) ?? sortedTeams.value[0] ?? null,
)

// For a team, build ordered slot list: each position × slots_per_team, filled or null
function rosterSlots(teamId: number) {
  return store.rosterPositions
    .map((rp) => {
      const picks = store.draftPicks.filter(
        (p) => p.team_id === teamId && p.roster_position_id === rp.id,
      )
      const slots = []
      for (let i = 0; i < rp.slots_per_team; i++) {
        slots.push({ position: rp, pick: picks[i] ?? null })
      }
      return slots
    })
    .flat()
}

function teamSpent(teamId: number) {
  return store.draftPicks
    .filter((p) => p.team_id === teamId)
    .reduce((sum, p) => sum + (p.winning_bid ?? 0), 0)
}

function teamProjectedPoints(teamId: number) {
  return store.draftPicks
    .filter((p) => p.team_id === teamId)
    .reduce((sum, p) => {
      const school = store.schools.find((s) => s.id === p.auction_school_id)
      return sum + (school?.projected_points ?? 0)
    }, 0)
}

function totalSlots() {
  return store.rosterPositions.reduce((sum, rp) => sum + rp.slots_per_team, 0)
}

function filledSlots(teamId: number) {
  return store.draftPicks.filter((p) => p.team_id === teamId && p.roster_position_id).length
}

function schoolFor(pick: ReturnType<typeof rosterSlots>[0]['pick']) {
  if (!pick) return null
  return store.schools.find((s) => s.id === pick.auction_school_id) ?? null
}

function exportCsv() {
  const rows: string[][] = [
    ['Team', 'School', 'Conference', 'Position', 'Price Paid', 'Projected Points'],
  ]

  for (const team of sortedTeams.value) {
    const teamName = store.getTeamDisplayName(team.id)
    for (const slot of rosterSlots(team.id)) {
      if (!slot.pick) {
        rows.push([teamName, '(empty)', '', slot.position.position_name, '', ''])
      } else {
        const school = schoolFor(slot.pick)
        rows.push([
          teamName,
          school?.school?.name ?? '',
          school?.conference ?? '',
          slot.position.position_name + (slot.position.is_flex ? ' (FLEX)' : ''),
          String(slot.pick.winning_bid ?? 0),
          String(school?.projected_points ?? ''),
        ])
      }
    }
  }

  const csv = rows
    .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(','))
    .join('\n')

  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${store.auction?.name ?? 'draft'}-results.csv`
  a.click()
  URL.revokeObjectURL(url)
}
</script>

<template>
  <AppShell>
    <!-- Nav -->
    <template #nav>
      <span class="text-on-surface-variant">WAR ROOM</span>
      <span class="text-on-surface-variant opacity-50 cursor-help" title="Coming soon">MARKET</span>
      <span class="text-primary border-b-2 border-primary pb-1">ROSTERS</span>
    </template>

    <!-- Sidebar header -->
    <template #sidebar-header>
      <div class="flex items-center gap-3">
        <div
          class="w-12 h-12 bg-surface-container-highest flex items-center justify-center border border-primary/20"
        >
          <span class="material-symbols-outlined text-primary text-3xl">groups</span>
        </div>
        <div>
          <div class="text-on-surface text-sm tracking-tight">ROSTER VIEW</div>
          <div class="text-secondary text-xs">LIVE DRAFT</div>
        </div>
      </div>
    </template>

    <!-- Sidebar nav -->
    <template #sidebar-nav>
      <RouterLink
        :to="`/auction/${auctionId}/draft`"
        class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container"
      >
        <span class="material-symbols-outlined mr-4">gavel</span> WAR ROOM
      </RouterLink>
      <a
        class="flex items-center px-6 py-4 bg-gradient-to-r from-primary/20 to-transparent text-primary border-l-4 border-primary"
      >
        <span class="material-symbols-outlined mr-4">groups</span> ROSTERS
      </a>
    </template>

    <!-- Sidebar footer: team budget summary -->
    <template #sidebar-footer>
      <div class="p-4 space-y-2">
        <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-3">
          All Team Budgets
        </div>
        <div
          v-for="team in sortedTeams"
          :key="team.id"
          class="flex items-center justify-between py-1.5 px-2 cursor-pointer transition-colors hover:bg-surface-container"
          :class="selectedTeam?.id === team.id ? 'bg-primary/10 border-l-2 border-primary' : ''"
          @click="activeTeamId = team.id"
        >
          <div class="flex-1 min-w-0">
            <div class="text-xs font-label font-bold text-on-surface truncate">
              {{ store.getTeamDisplayName(team.id) }}
            </div>
            <div class="w-full h-1 bg-surface-container-highest mt-1">
              <div
                class="h-full bg-primary transition-all"
                :style="{
                  width: `${Math.round((team.remaining_budget / (store.auction?.default_budget ?? 200)) * 100)}%`,
                }"
              ></div>
            </div>
          </div>
          <span class="text-xs font-headline font-bold text-primary ml-3 flex-shrink-0"
            >${{ team.remaining_budget }}</span
          >
        </div>
      </div>
    </template>

    <!-- Ticker -->
    <template #ticker-status>{{
      store.auction?.status === 'completed' ? 'DRAFT COMPLETE' : 'ROSTER VIEW: LIVE'
    }}</template>
    <template #ticker-content>
      <span>AUCTION: {{ store.auction?.name ?? '—' }}</span>
      <span class="text-tertiary">PICKS MADE: {{ store.draftPicks.length }}</span>
      <span>SCHOOLS REMAINING: {{ store.availableSchools.length }}</span>
    </template>

    <!-- Main content -->
    <div v-if="store.loading" class="h-[calc(100vh-104px)] flex items-center justify-center">
      <span class="material-symbols-outlined text-4xl text-primary animate-spin">autorenew</span>
    </div>

    <div v-else class="h-[calc(100vh-104px)] flex flex-col overflow-hidden">
      <!-- Team tabs -->
      <div
        class="flex items-end gap-0 border-b border-outline-variant/20 bg-surface-container-low px-6 overflow-x-auto flex-shrink-0 justify-between"
      >
        <div class="flex items-end gap-0">
          <button
            v-for="team in sortedTeams"
            :key="team.id"
            class="px-6 py-3 font-headline font-bold text-xs uppercase tracking-wider whitespace-nowrap transition-colors border-b-2 -mb-px"
            :class="
              selectedTeam?.id === team.id
                ? 'text-primary border-primary bg-surface-container'
                : 'text-on-surface-variant border-transparent hover:text-on-surface hover:border-outline-variant/50'
            "
            @click="activeTeamId = team.id"
          >
            {{ store.getTeamDisplayName(team.id) }}
          </button>
        </div>
        <button
          class="flex-shrink-0 flex items-center gap-2 px-4 py-2 my-1.5 mr-1 border border-outline-variant/30 text-on-surface-variant hover:bg-surface-container hover:text-on-surface text-[10px] font-label font-bold uppercase tracking-wider transition-colors"
          @click="exportCsv"
        >
          <span class="material-symbols-outlined text-sm">download</span>
          Export CSV
        </button>
      </div>

      <!-- Selected team content -->
      <div v-if="selectedTeam" class="flex-1 overflow-y-auto p-6 space-y-6">
        <!-- Stats bar -->
        <div class="grid grid-cols-3 gap-4">
          <div
            class="bg-surface-container border border-outline-variant/20 p-4 relative overflow-hidden"
          >
            <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">
              Budget Remaining
            </div>
            <div class="text-3xl font-headline font-black text-primary">
              ${{ selectedTeam.remaining_budget }}
            </div>
            <div class="w-full h-0.5 bg-primary/20 absolute bottom-0 left-0">
              <div
                class="h-full bg-primary transition-all"
                :style="{
                  width: `${Math.round((selectedTeam.remaining_budget / (store.auction?.default_budget ?? 200)) * 100)}%`,
                }"
              ></div>
            </div>
          </div>
          <div
            class="bg-surface-container border border-outline-variant/20 p-4 relative overflow-hidden"
          >
            <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">
              Budget Spent
            </div>
            <div class="text-3xl font-headline font-black text-tertiary">
              ${{ teamSpent(selectedTeam.id) }}
            </div>
            <div class="w-full h-0.5 bg-tertiary/20 absolute bottom-0 left-0">
              <div
                class="h-full bg-tertiary transition-all"
                :style="{
                  width: `${Math.round((teamSpent(selectedTeam.id) / (store.auction?.default_budget ?? 200)) * 100)}%`,
                }"
              ></div>
            </div>
          </div>
          <div
            class="bg-surface-container border border-outline-variant/20 p-4 relative overflow-hidden"
          >
            <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-1">
              Projected Points
            </div>
            <div class="text-3xl font-headline font-black text-on-surface">
              {{ teamProjectedPoints(selectedTeam.id) }}
            </div>
            <div class="text-[10px] font-label text-outline mt-1 uppercase">
              {{ filledSlots(selectedTeam.id) }} / {{ totalSlots() }} slots filled
            </div>
          </div>
        </div>

        <!-- Roster grid -->
        <div class="grid grid-cols-1 xl:grid-cols-2 gap-3">
          <div
            v-for="(slot, idx) in rosterSlots(selectedTeam.id)"
            :key="`${slot.position.id}-${idx}`"
            class="group flex items-center p-4 relative overflow-hidden border transition-colors"
            :class="
              slot.pick
                ? 'bg-surface-container border-outline-variant/20 hover:bg-surface-container-high'
                : 'bg-surface-container-low border-outline-variant/10'
            "
          >
            <!-- Position color bar -->
            <div
              class="absolute top-0 left-0 w-1 h-full transition-opacity"
              :class="slot.pick ? 'opacity-70 group-hover:opacity-100' : 'opacity-20'"
              :style="{ backgroundColor: slot.position.color_code ?? '#8d9199' }"
            ></div>

            <!-- School logo or empty placeholder -->
            <div
              class="w-14 h-14 flex-shrink-0 mr-4 flex items-center justify-center ml-2"
              :class="
                slot.pick
                  ? 'bg-white p-1.5 shadow-lg'
                  : 'bg-surface-container-highest border border-outline-variant/20'
              "
            >
              <template v-if="slot.pick && schoolFor(slot.pick)?.school?.logo_url">
                <img
                  :src="schoolFor(slot.pick)!.school!.logo_url!"
                  :alt="schoolFor(slot.pick)?.school?.name"
                  class="w-full h-full object-contain grayscale group-hover:grayscale-0 transition-all"
                />
              </template>
              <span
                v-else-if="slot.pick"
                class="font-headline font-black text-surface-container-lowest text-lg"
              >
                {{ schoolFor(slot.pick)?.school?.name?.slice(0, 2).toUpperCase() ?? '??' }}
              </span>
              <span v-else class="material-symbols-outlined text-outline text-2xl">add</span>
            </div>

            <!-- Slot content -->
            <div class="flex-1 min-w-0">
              <!-- Position badge -->
              <div class="flex items-center gap-2 mb-1">
                <span
                  class="text-[9px] font-label font-bold uppercase px-1.5 py-0.5"
                  :style="{
                    backgroundColor: (slot.position.color_code ?? '#8d9199') + '33',
                    color: slot.position.color_code ?? '#8d9199',
                  }"
                >
                  {{ slot.position.position_name }}{{ slot.position.is_flex ? ' (FLEX)' : '' }}
                </span>
              </div>

              <template v-if="slot.pick">
                <div
                  class="text-base font-headline font-black text-on-surface uppercase tracking-tight truncate"
                >
                  {{ schoolFor(slot.pick)?.school?.name ?? '—' }}
                </div>
                <div class="flex items-center gap-4 mt-0.5">
                  <span class="text-[10px] font-label text-outline uppercase">
                    {{ schoolFor(slot.pick)?.conference ?? '—' }}
                  </span>
                  <span class="text-[10px] font-label text-tertiary font-bold uppercase">
                    {{ schoolFor(slot.pick)?.projected_points ?? 0 }} pts
                  </span>
                </div>
              </template>
              <div v-else class="text-sm font-label text-outline uppercase tracking-wider">
                Empty slot
              </div>
            </div>

            <!-- Price tag -->
            <div v-if="slot.pick" class="text-right flex-shrink-0 ml-3">
              <div class="text-[10px] font-label text-tertiary uppercase tracking-wider">Paid</div>
              <div class="text-lg font-headline font-bold text-tertiary">
                ${{ slot.pick.winning_bid }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div
        v-else
        class="flex-1 flex items-center justify-center text-outline font-label uppercase text-sm"
      >
        No teams found
      </div>
    </div>
  </AppShell>
</template>
