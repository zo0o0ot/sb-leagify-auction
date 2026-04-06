<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import AppShell from '@/components/AppShell.vue'
import type { School, AuctionSchool } from '@/types/auction'

const route = useRoute()
const router = useRouter()

const auctionId = route.query.auction_id ? Number(route.query.auction_id) : null
const isSetup = route.query.setup === '1'

// ── State ──────────────────────────────────────────────────────────────────
type SchoolRow = School & {
  auction_school?: {
    conference: string | null
    projected_points: number
    leagify_position: string
  }
}

const schools = ref<SchoolRow[]>([])
const loading = ref(true)
const searchQuery = ref('')
const sortMode = ref<'points' | 'alpha'>('points')

// CSV upload state
const showUploadModal = ref(isSetup) // auto-open if coming from create flow
const csvFile = ref<File | null>(null)
const csvRows = ref<CsvRow[]>([])
const csvError = ref('')
const csvStep = ref<'pick' | 'preview' | 'importing' | 'done'>('pick')
const importCount = ref(0)

// Logo edit state
const editingSchool = ref<SchoolRow | null>(null)

interface CsvRow {
  name: string
  conference: string
  leagify_position: string
  projected_points: number
  suggested_value: number | null
  error?: string
}

// ── Computed ────────────────────────────────────────────────────────────────
const filteredSchools = computed(() => {
  let list = schools.value
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter((s) => s.name.toLowerCase().includes(q))
  }
  if (sortMode.value === 'alpha') {
    return [...list].sort((a, b) => a.name.localeCompare(b.name))
  }
  return [...list].sort(
    (a, b) =>
      (b.auction_school?.projected_points ?? 0) - (a.auction_school?.projected_points ?? 0),
  )
})

const totalPoints = computed(() =>
  schools.value.reduce((s, r) => s + (r.auction_school?.projected_points ?? 0), 0),
)

const unassignedLogos = computed(() => schools.value.filter((s) => !s.logo_url).length)

// ── Load ───────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  if (auctionId) {
    // Load schools linked to this auction
    const { data } = await supabase
      .from('auction_schools')
      .select('*, school:schools(*)')
      .eq('auction_id', auctionId)
      .order('projected_points', { ascending: false })
    schools.value = (data ?? []).map((as: AuctionSchool) => ({
      ...(as.school as School),
      auction_school: {
        conference: as.conference,
        projected_points: as.projected_points,
        leagify_position: as.leagify_position,
      },
    }))
  } else {
    // No auction context — show master schools table
    const { data } = await supabase.from('schools').select('*').order('name')
    schools.value = data ?? []
  }
  loading.value = false
}

// ── CSV Template ───────────────────────────────────────────────────────────
function downloadTemplate() {
  const headers = 'name,conference,leagify_position,projected_points,suggested_value'
  const example =
    'Alabama Crimson Tide,SEC,QB1,98.5,45\nOhio State Buckeyes,Big Ten,RB1,96.2,42'
  const blob = new Blob([headers + '\n' + example], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = 'schools_template.csv'
  a.click()
  URL.revokeObjectURL(url)
}

// ── CSV Parse ──────────────────────────────────────────────────────────────
function handleFileChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  csvFile.value = file
  csvError.value = ''
  csvRows.value = []

  const reader = new FileReader()
  reader.onload = (ev) => {
    const text = ev.target?.result as string
    parseCSV(text)
  }
  reader.readAsText(file)
}

function parseCSV(text: string) {
  const lines = text.trim().split('\n').filter(Boolean)
  if (lines.length < 2) {
    csvError.value = 'CSV must have a header row and at least one data row.'
    return
  }

  const header = lines[0]!.split(',').map((h) => h.trim().toLowerCase())
  const requiredCols = ['name', 'conference', 'leagify_position', 'projected_points']
  for (const col of requiredCols) {
    if (!header.includes(col)) {
      csvError.value = `Missing required column: "${col}"`
      return
    }
  }

  const nameIdx = header.indexOf('name')
  const confIdx = header.indexOf('conference')
  const posIdx = header.indexOf('leagify_position')
  const ptsIdx = header.indexOf('projected_points')
  const valIdx = header.indexOf('suggested_value')

  const rows: CsvRow[] = []
  for (let i = 1; i < lines.length; i++) {
    const cols = lines[i]!.split(',').map((c) => c.trim())
    const name = cols[nameIdx] ?? ''
    const pts = parseFloat(cols[ptsIdx] ?? '0')
    const valRaw = valIdx >= 0 ? cols[valIdx] : undefined
    const row: CsvRow = {
      name,
      conference: cols[confIdx] ?? '',
      leagify_position: cols[posIdx] ?? '',
      projected_points: isNaN(pts) ? 0 : pts,
      suggested_value: valRaw !== undefined ? (parseFloat(valRaw) || null) : null,
    }
    if (!name) row.error = 'Missing name'
    rows.push(row)
  }

  csvRows.value = rows
  csvStep.value = 'preview'
}

// ── CSV Import ─────────────────────────────────────────────────────────────
async function confirmImport() {
  if (!auctionId) return
  csvStep.value = 'importing'

  const validRows = csvRows.value.filter((r) => !r.error)
  let imported = 0

  for (const row of validRows) {
    // Upsert school into master table
    const { data: schoolData } = await supabase
      .from('schools')
      .upsert({ name: row.name }, { onConflict: 'name' })
      .select('id')
      .single()

    if (!schoolData) continue

    // Insert auction_school link
    await supabase.from('auction_schools').upsert(
      {
        auction_id: auctionId,
        school_id: schoolData.id,
        conference: row.conference,
        leagify_position: row.leagify_position,
        projected_points: row.projected_points,
        suggested_value: row.suggested_value,
        is_available: true,
      },
      { onConflict: 'auction_id,school_id' },
    )
    imported++
  }

  importCount.value = imported
  csvStep.value = 'done'
  await load()
}

function closeUpload() {
  showUploadModal.value = false
  csvStep.value = 'pick'
  csvFile.value = null
  csvRows.value = []
  csvError.value = ''
  // Navigation to lobby happens via the "Go to Lobby" button after successful import
}

function goToLobby() {
  if (auctionId) router.push(`/auction/${auctionId}/lobby`)
}

onMounted(load)
</script>

<template>
  <AppShell>
    <!-- Nav -->
    <template #nav>
      <span class="text-on-surface-variant">WAR ROOM</span>
      <span class="text-tertiary border-b-2 border-tertiary pb-1">AUCTION SCHOOLS</span>
      <span class="text-on-surface-variant">STANDINGS</span>
    </template>

    <!-- Header actions -->
    <template #header-actions>
      <button
        v-if="isSetup && auctionId"
        class="flex items-center gap-2 px-4 py-1 bg-secondary-container/20 border border-secondary/30 text-secondary text-[10px] font-label font-black uppercase hover:bg-secondary/10 transition-colors"
        @click="goToLobby"
      >
        <span class="material-symbols-outlined text-sm">arrow_forward</span>
        SKIP TO LOBBY
      </button>
    </template>

    <!-- Sidebar header -->
    <template #sidebar-header>
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 bg-surface-container-highest flex items-center justify-center border border-tertiary/20">
          <span class="material-symbols-outlined text-tertiary text-3xl">school</span>
        </div>
        <div>
          <div class="text-on-surface text-sm tracking-tight">STRATEGIC COMMAND</div>
          <div class="text-tertiary text-xs">PHASE: NOMINATION</div>
        </div>
      </div>
    </template>

    <!-- Sidebar nav -->
    <template #sidebar-nav>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">dashboard</span> DRAFT BOARD
      </a>
      <a class="flex items-center px-6 py-4 bg-gradient-to-r from-tertiary/20 to-transparent text-tertiary border-l-4 border-tertiary">
        <span class="material-symbols-outlined mr-4">school</span> SCHOOLS
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">payments</span> BID
      </a>
      <a class="flex items-center px-6 py-4 text-on-surface-variant hover:bg-surface-container">
        <span class="material-symbols-outlined mr-4">history</span> HISTORY
      </a>
    </template>

    <!-- Sidebar footer -->
    <template #sidebar-footer>
      <div class="p-4 bg-surface-container border border-outline-variant/30">
        <div class="text-[10px] text-outline mb-3 font-label uppercase">Quick Actions</div>
        <button
          class="w-full bg-gradient-to-br from-primary to-on-primary-container text-on-primary-fixed font-label font-black text-xs py-3 flex items-center justify-center gap-2 uppercase tracking-tighter active:scale-95 transition-transform"
          @click="showUploadModal = true"
        >
          <span class="material-symbols-outlined text-sm">cloud_upload</span>
          BULK UPLOAD
        </button>
      </div>
    </template>

    <!-- Ticker -->
    <template #ticker-status>SCHOOL MANAGEMENT</template>
    <template #ticker-content>
      <span>TOTAL SCHOOLS: {{ schools.length }}</span>
      <span class="text-tertiary">PROJ PTS: {{ totalPoints.toFixed(1) }}</span>
      <span class="text-secondary">UNASSIGNED LOGOS: {{ unassignedLogos }}</span>
      <span v-if="auctionId">AUCTION ID: {{ auctionId }}</span>
    </template>

    <!-- ── Main content ── -->
    <div v-if="loading" class="h-[calc(100vh-104px)] flex items-center justify-center">
      <span class="material-symbols-outlined text-4xl text-primary animate-spin">autorenew</span>
    </div>

    <div v-else class="p-8 h-[calc(100vh-104px)] overflow-hidden flex flex-col gap-6">

      <!-- Page header -->
      <div class="flex items-end justify-between">
        <div>
          <h1 class="font-headline text-5xl font-black italic tracking-tighter uppercase text-on-surface leading-none">
            MAINTAIN <span class="text-tertiary">SCHOOLS</span>
          </h1>
          <div class="font-label text-outline text-xs tracking-[0.2em] font-bold mt-2 uppercase">
            Core Database Management &bull; {{ schools.length }} Entities Identified
          </div>
        </div>
        <div class="flex items-center gap-3">
          <button
            class="bg-surface-container-highest border-b-2 border-primary/30 px-6 py-3 font-label text-primary font-bold text-sm hover:bg-surface-bright transition-all active:scale-95 flex items-center gap-2"
            @click="downloadTemplate"
          >
            <span class="material-symbols-outlined text-sm">download</span>
            EXPORT TEMPLATE
          </button>
          <button
            class="bg-gradient-to-r from-tertiary to-tertiary-container text-on-tertiary-fixed font-label font-black text-sm px-8 py-3 flex items-center gap-2 hover:shadow-[0_0_20px_rgba(233,196,0,0.4)] transition-all active:scale-95"
            @click="showUploadModal = true"
          >
            <span class="material-symbols-outlined">cloud_upload</span>
            BULK UPLOAD SCHOOLS
          </button>
        </div>
      </div>

      <!-- Stats -->
      <div class="grid grid-cols-3 gap-6">
        <div class="bg-surface-container border-l-4 border-primary p-6 shadow-xl relative overflow-hidden">
          <div class="font-label text-outline text-[10px] uppercase tracking-widest mb-1">Total Institutions</div>
          <div class="font-headline text-4xl font-bold text-on-surface">{{ schools.length }}</div>
        </div>
        <div class="bg-surface-container border-l-4 border-tertiary p-6 shadow-xl relative overflow-hidden">
          <div class="font-label text-outline text-[10px] uppercase tracking-widest mb-1">Projected Capture</div>
          <div class="font-headline text-4xl font-bold text-on-surface">{{ totalPoints.toFixed(0) }} <span class="text-lg text-outline">PTS</span></div>
        </div>
        <div class="bg-surface-container border-l-4 border-secondary p-6 shadow-xl relative overflow-hidden">
          <div class="font-label text-outline text-[10px] uppercase tracking-widest mb-1">Unassigned Logos</div>
          <div class="font-headline text-4xl font-bold" :class="unassignedLogos > 0 ? 'text-secondary' : 'text-tertiary'">
            {{ String(unassignedLogos).padStart(2, '0') }}
          </div>
        </div>
      </div>

      <!-- Search + sort toolbar -->
      <div class="flex items-center gap-4">
        <div class="flex-1 relative">
          <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline text-sm">search</span>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Search schools..."
            class="w-full bg-surface-container border border-outline-variant/30 pl-10 pr-4 py-2 text-sm font-label text-on-surface placeholder:text-outline focus:outline-none focus:border-primary/50"
          />
        </div>
        <div class="flex border border-outline-variant/30 overflow-hidden">
          <button
            class="px-4 py-2 text-xs font-label font-bold uppercase transition-colors"
            :class="sortMode === 'points' ? 'bg-primary text-on-primary' : 'bg-surface-container text-outline hover:bg-surface-container-high'"
            @click="sortMode = 'points'"
          >POINTS</button>
          <button
            class="px-4 py-2 text-xs font-label font-bold uppercase transition-colors"
            :class="sortMode === 'alpha' ? 'bg-primary text-on-primary' : 'bg-surface-container text-outline hover:bg-surface-container-high'"
            @click="sortMode = 'alpha'"
          >A-Z</button>
        </div>
      </div>

      <!-- Schools table -->
      <div class="flex-1 overflow-y-auto border border-outline-variant/20">
        <table class="w-full text-sm">
          <thead class="bg-surface-container-high sticky top-0">
            <tr class="text-left">
              <th class="px-4 py-3 font-label text-[10px] text-outline uppercase tracking-widest w-16">Icon</th>
              <th class="px-4 py-3 font-label text-[10px] text-outline uppercase tracking-widest">School Name</th>
              <th class="px-4 py-3 font-label text-[10px] text-outline uppercase tracking-widest">Conference</th>
              <th class="px-4 py-3 font-label text-[10px] text-outline uppercase tracking-widest">Position</th>
              <th class="px-4 py-3 font-label text-[10px] text-outline uppercase tracking-widest text-right">Proj. Points</th>
              <th class="px-4 py-3 font-label text-[10px] text-outline uppercase tracking-widest text-center w-28">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="school in filteredSchools"
              :key="school.id"
              class="border-t border-outline-variant/10 hover:bg-surface-container-high/50 transition-colors"
            >
              <!-- Logo -->
              <td class="px-4 py-3">
                <div class="w-10 h-10 bg-surface-container-highest flex items-center justify-center border border-outline-variant/20">
                  <img
                    v-if="school.logo_url"
                    :src="school.logo_url"
                    :alt="school.name"
                    class="w-8 h-8 object-contain"
                  />
                  <span v-else class="material-symbols-outlined text-outline text-lg">add_a_photo</span>
                </div>
              </td>
              <!-- Name -->
              <td class="px-4 py-3">
                <div class="font-headline font-bold uppercase tracking-tight text-on-surface text-sm">
                  {{ school.name }}
                </div>
                <div class="text-[10px] font-label text-outline">ID: {{ school.id }}</div>
              </td>
              <!-- Conference -->
              <td class="px-4 py-3">
                <span class="text-xs font-label text-on-surface-variant uppercase">
                  {{ school.auction_school?.conference ?? '—' }}
                </span>
              </td>
              <!-- Position -->
              <td class="px-4 py-3">
                <span class="text-xs font-label text-tertiary font-bold uppercase">
                  {{ school.auction_school?.leagify_position ?? '—' }}
                </span>
              </td>
              <!-- Points -->
              <td class="px-4 py-3 text-right">
                <span class="font-headline font-bold text-primary">
                  {{ school.auction_school ? school.auction_school.projected_points.toFixed(1) : '—' }}
                </span>
              </td>
              <!-- Actions -->
              <td class="px-4 py-3">
                <div class="flex items-center justify-center gap-2">
                  <button
                    class="p-1 hover:bg-primary/10 text-primary transition-colors"
                    title="Edit logo"
                    @click="editingSchool = school"
                  >
                    <span class="material-symbols-outlined text-sm">image</span>
                  </button>
                  <button
                    class="p-1 hover:bg-outline/10 text-outline transition-colors"
                    title="Settings"
                  >
                    <span class="material-symbols-outlined text-sm">settings_suggest</span>
                  </button>
                </div>
              </td>
            </tr>
            <tr v-if="filteredSchools.length === 0">
              <td colspan="6" class="py-12 text-center text-outline font-label text-sm uppercase">
                {{ searchQuery ? 'No schools match your search' : 'No schools yet — upload a CSV to get started' }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ── CSV Upload Modal ── -->
    <Teleport to="body">
      <div
        v-if="showUploadModal"
        class="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
        @click.self="csvStep !== 'importing' && closeUpload()"
      >
        <div class="bg-surface-container-low border border-outline-variant/30 w-full max-w-2xl shadow-2xl">
          <!-- Modal header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-outline-variant/20">
            <div>
              <div class="font-headline font-black uppercase text-on-surface tracking-tight">
                Bulk Upload Schools
              </div>
              <div class="text-[10px] font-label text-outline uppercase tracking-widest">
                {{ csvStep === 'pick' ? 'Select CSV file' : csvStep === 'preview' ? `${csvRows.length} rows detected` : csvStep === 'importing' ? 'Importing...' : `${importCount} schools imported` }}
              </div>
            </div>
            <button
              v-if="csvStep !== 'importing'"
              class="p-1 hover:bg-surface-container text-outline transition-colors"
              @click="closeUpload"
            >
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>

          <!-- Step: pick file -->
          <div v-if="csvStep === 'pick'" class="p-6 space-y-4">
            <div
              class="border-2 border-dashed border-outline-variant/40 p-12 text-center cursor-pointer hover:border-primary/40 hover:bg-primary/5 transition-all"
              @click="($refs.fileInput as HTMLInputElement)?.click()"
            >
              <span class="material-symbols-outlined text-5xl text-outline mb-4 block">upload_file</span>
              <div class="font-headline font-bold uppercase text-on-surface-variant mb-1">
                {{ csvFile ? csvFile.name : 'Click to select CSV file' }}
              </div>
              <div class="text-xs font-label text-outline uppercase">
                Required columns: name, conference, leagify_position, projected_points
              </div>
            </div>
            <input
              ref="fileInput"
              type="file"
              accept=".csv"
              class="hidden"
              @change="handleFileChange"
            />
            <p v-if="csvError" class="text-xs text-error font-label text-center">{{ csvError }}</p>
            <div class="flex gap-3">
              <button
                class="flex-1 bg-surface-container border border-outline-variant/30 py-3 font-label text-outline text-sm uppercase hover:bg-surface-container-high transition-colors"
                @click="downloadTemplate"
              >
                <span class="material-symbols-outlined text-sm align-text-bottom mr-1">download</span>
                Download Template
              </button>
            </div>
          </div>

          <!-- Step: preview -->
          <div v-else-if="csvStep === 'preview'" class="flex flex-col max-h-[60vh]">
            <div class="flex-1 overflow-y-auto">
              <table class="w-full text-xs">
                <thead class="bg-surface-container-high sticky top-0">
                  <tr>
                    <th class="px-4 py-2 text-left font-label text-[10px] text-outline uppercase">#</th>
                    <th class="px-4 py-2 text-left font-label text-[10px] text-outline uppercase">Name</th>
                    <th class="px-4 py-2 text-left font-label text-[10px] text-outline uppercase">Conf</th>
                    <th class="px-4 py-2 text-left font-label text-[10px] text-outline uppercase">Position</th>
                    <th class="px-4 py-2 text-right font-label text-[10px] text-outline uppercase">Pts</th>
                    <th class="px-4 py-2 text-center font-label text-[10px] text-outline uppercase">Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(row, i) in csvRows"
                    :key="i"
                    class="border-t border-outline-variant/10"
                    :class="row.error ? 'bg-error-container/10' : ''"
                  >
                    <td class="px-4 py-2 text-outline">{{ i + 1 }}</td>
                    <td class="px-4 py-2 font-bold text-on-surface">{{ row.name || '(empty)' }}</td>
                    <td class="px-4 py-2 text-on-surface-variant">{{ row.conference }}</td>
                    <td class="px-4 py-2 text-tertiary font-bold">{{ row.leagify_position }}</td>
                    <td class="px-4 py-2 text-right text-primary">{{ row.projected_points }}</td>
                    <td class="px-4 py-2 text-center">
                      <span v-if="row.error" class="text-error text-[10px] font-label uppercase">{{ row.error }}</span>
                      <span v-else class="material-symbols-outlined text-tertiary text-sm" style="font-variation-settings: 'FILL' 1">check_circle</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="p-4 border-t border-outline-variant/20 bg-surface-container flex items-center justify-between">
              <div class="text-xs font-label text-outline uppercase">
                {{ csvRows.filter((r) => !r.error).length }} valid / {{ csvRows.filter((r) => r.error).length }} errors
              </div>
              <div class="flex gap-3">
                <button
                  class="px-6 py-2 bg-surface-container-high border border-outline-variant/30 text-outline text-xs font-label font-bold uppercase hover:bg-surface-bright transition-colors"
                  @click="csvStep = 'pick'"
                >
                  Back
                </button>
                <button
                  :disabled="!auctionId || csvRows.filter((r) => !r.error).length === 0"
                  class="px-8 py-2 bg-tertiary text-on-tertiary font-label font-black text-xs uppercase hover:bg-tertiary-container transition-colors disabled:opacity-40"
                  @click="confirmImport"
                >
                  Import {{ csvRows.filter((r) => !r.error).length }} Schools
                </button>
              </div>
            </div>
            <p v-if="!auctionId" class="px-4 pb-3 text-[10px] text-error font-label uppercase text-center">
              No auction selected — navigate here from Create Auction to import schools.
            </p>
          </div>

          <!-- Step: importing -->
          <div v-else-if="csvStep === 'importing'" class="p-12 flex flex-col items-center gap-4">
            <span class="material-symbols-outlined text-5xl text-primary animate-spin">autorenew</span>
            <div class="font-headline font-bold uppercase text-on-surface">Importing Schools...</div>
          </div>

          <!-- Step: done -->
          <div v-else class="p-8 flex flex-col items-center gap-4 text-center">
            <span class="material-symbols-outlined text-5xl text-tertiary" style="font-variation-settings: 'FILL' 1">check_circle</span>
            <div class="font-headline font-black uppercase text-on-surface text-2xl">
              {{ importCount }} Schools Imported
            </div>
            <div class="text-xs font-label text-outline uppercase">School database updated successfully</div>
            <div class="flex gap-3 mt-2">
              <button
                class="px-6 py-2 bg-surface-container border border-outline-variant/30 text-outline text-xs font-label font-bold uppercase hover:bg-surface-container-high transition-colors"
                @click="closeUpload"
              >
                Close
              </button>
              <button
                v-if="auctionId"
                class="px-8 py-2 bg-secondary-container text-on-secondary-container font-label font-black text-xs uppercase hover:bg-secondary/20 transition-colors"
                @click="goToLobby"
              >
                Go to Lobby
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Logo Edit Modal ── -->
    <Teleport to="body">
      <div
        v-if="editingSchool"
        class="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
        @click.self="editingSchool = null"
      >
        <div class="bg-surface-container-low border border-outline-variant/30 w-full max-w-md shadow-2xl">
          <div class="flex items-center justify-between px-6 py-4 border-b border-outline-variant/20">
            <div class="font-headline font-black uppercase text-on-surface tracking-tight">
              Manage Asset: {{ editingSchool.name }}
            </div>
            <button class="p-1 hover:bg-surface-container text-outline" @click="editingSchool = null">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>
          <div class="p-6 space-y-4">
            <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-3">Current Asset</div>
            <div class="w-24 h-24 bg-surface-container-highest border border-outline-variant/20 flex items-center justify-center mx-auto">
              <img
                v-if="editingSchool.logo_url"
                :src="editingSchool.logo_url"
                :alt="editingSchool.name"
                class="w-full h-full object-contain p-2"
              />
              <span v-else class="material-symbols-outlined text-outline text-4xl">image</span>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <button class="bg-surface-container-high border border-primary/30 py-3 font-label text-primary text-xs font-bold uppercase flex items-center justify-center gap-2">
                <span class="material-symbols-outlined text-sm">upload</span>
                UPLOAD SVG/PNG
              </button>
              <button class="bg-surface-container-high border border-outline-variant/30 py-3 font-label text-outline text-xs font-bold uppercase flex items-center justify-center gap-2">
                <span class="material-symbols-outlined text-sm">grid_view</span>
                BROWSE GALLERY
              </button>
            </div>
            <div class="flex gap-3 pt-2">
              <button
                class="flex-1 py-2 border border-outline-variant/30 text-outline text-xs font-label font-bold uppercase hover:bg-surface-container transition-colors"
                @click="editingSchool = null"
              >
                Cancel
              </button>
              <button
                class="flex-1 py-2 bg-primary text-on-primary text-xs font-label font-black uppercase hover:bg-primary/80 transition-colors"
                @click="editingSchool = null"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </AppShell>
</template>
