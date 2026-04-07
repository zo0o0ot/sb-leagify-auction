<script setup lang="ts">
import { ref, computed } from 'vue'
import { useAuctionStore } from '@/stores/auction'
import { supabase } from '@/lib/supabase'

defineProps<{
  isAdmin?: boolean
}>()

const store = useAuctionStore()
const submitting = ref(false)
const bidError = ref('')
const adminError = ref('')

const practiceSchool = computed(() => {
  if (!store.auction?.current_school_id) return null
  return store.schools.find((s) => s.id === store.auction!.current_school_id) ?? null
})

const currentHighBid = computed(() => store.auction?.current_high_bid ?? 0)
const nextMinBid = computed(() => currentHighBid.value + 1)
const myBudget = computed(() => store.activeTeam?.remaining_budget ?? 0)
const maxBid = computed(() => store.myMaxBid)
const isAutoPass = computed(() => maxBid.value < nextMinBid.value)

async function bid(amount: number) {
  const total = nextMinBid.value - 1 + amount
  if (total > maxBid.value) return
  bidError.value = ''
  submitting.value = true
  const result = await store.placeBid(total)
  if (result?.error) bidError.value = result.error
  submitting.value = false
}

async function pass() {
  submitting.value = true
  await store.pass()
  submitting.value = false
}

// Admin-only: force bid amounts
async function forceBid(delta: number) {
  if (!store.auction) return
  submitting.value = true
  await store.placeBid((currentHighBid.value || 0) + delta)
  submitting.value = false
}

async function clearLastBid() {
  const auction = store.auction
  if (!auction?.current_school_id) return
  adminError.value = ''
  submitting.value = true

  // Find two most recent practice bids for this school
  const { data: history } = await supabase
    .from('bid_history')
    .select('id, amount, team_id')
    .eq('auction_id', auction.id)
    .eq('auction_school_id', auction.current_school_id)
    .eq('bid_type', 'bid')
    .eq('is_practice', true)
    .order('id', { ascending: false })
    .limit(2)

  if (!history || history.length === 0) {
    adminError.value = 'No bids to clear'
    submitting.value = false
    return
  }

  const last = history[0]!
  const prev = history[1]
  // Delete the most recent bid
  await supabase.from('bid_history').delete().eq('id', last.id)
  // Restore previous high bid (or 0 if this was the first)
  const { error } = await supabase
    .from('auctions')
    .update({
      current_high_bid: prev ? prev.amount : 0,
      current_high_bidder_id: prev ? prev.team_id : null,
    })
    .eq('id', auction.id)

  if (error) adminError.value = error.message
  submitting.value = false
}

async function clearAllBids() {
  const auction = store.auction
  if (!auction?.current_school_id) return
  adminError.value = ''
  submitting.value = true

  // Delete all practice bids for the current school
  await supabase
    .from('bid_history')
    .delete()
    .eq('auction_id', auction.id)
    .eq('auction_school_id', auction.current_school_id)
    .eq('is_practice', true)

  // Reset bid state on the auction
  const { error } = await supabase
    .from('auctions')
    .update({ current_high_bid: 0, current_high_bidder_id: null })
    .eq('id', auction.id)

  if (error) adminError.value = error.message
  submitting.value = false
}

async function endBidding() {
  const auction = store.auction
  if (!auction) return
  adminError.value = ''
  submitting.value = true

  // Clear all practice bids and stop practice
  await supabase
    .from('bid_history')
    .delete()
    .eq('auction_id', auction.id)
    .eq('is_practice', true)

  const { error } = await supabase
    .from('auctions')
    .update({ status: 'draft', current_school_id: null, current_high_bid: null, current_high_bidder_id: null })
    .eq('id', auction.id)

  if (error) adminError.value = error.message
  submitting.value = false
}
</script>

<template>
  <div class="flex-1 glass-panel overflow-hidden flex flex-col border border-outline-variant/30">

    <!-- No practice school selected yet -->
    <div
      v-if="!practiceSchool"
      class="flex-1 flex flex-col items-center justify-center gap-4 p-8 text-center"
    >
      <span class="material-symbols-outlined text-5xl text-outline">sports_football</span>
      <p class="font-headline font-bold uppercase text-on-surface-variant tracking-tight">
        {{ isAdmin ? 'No school on the block yet' : 'Waiting for practice to begin...' }}
      </p>
      <p class="text-xs font-label text-outline uppercase tracking-wider">
        {{ isAdmin ? 'Use the nomination grid to put a school on the clock' : 'The admin will start practice shortly' }}
      </p>
    </div>

    <template v-else>
      <!-- School Identity -->
      <div class="bg-surface-container p-6 border-b border-outline-variant/30 flex items-center justify-between">
        <div class="flex items-center gap-6">
          <div class="w-20 h-20 bg-white p-2 shadow-2xl flex-shrink-0 flex items-center justify-center">
            <img
              v-if="practiceSchool.school?.logo_url"
              :src="practiceSchool.school.logo_url"
              :alt="practiceSchool.school.name"
              class="w-full h-full object-contain"
            />
            <span v-else class="font-headline font-black text-3xl text-surface-container-lowest">
              {{ practiceSchool.school?.name?.slice(0, 2).toUpperCase() }}
            </span>
          </div>
          <div>
            <h3 class="text-4xl font-headline font-black uppercase text-on-surface tracking-tighter">
              {{ practiceSchool.school?.name }}
            </h3>
            <div class="flex items-center gap-4 mt-1">
              <span class="text-sm font-label text-outline uppercase">{{ practiceSchool.leagify_position }}</span>
              <span class="text-sm font-label text-tertiary uppercase font-bold">
                {{ practiceSchool.projected_points }} PROJ PTS
              </span>
            </div>
          </div>
        </div>
        <div class="text-right">
          <div class="text-xs font-label text-outline uppercase">Practice</div>
          <div class="text-2xl font-headline font-black text-secondary animate-pulse">LIVE</div>
        </div>
      </div>

      <!-- Financials -->
      <div class="bg-surface-container-low border-b border-outline-variant/20">
        <!-- Row 1: Current high bidder + current high bid -->
        <div class="grid grid-cols-2 border-b border-outline-variant/20" :class="currentHighBid > 0 ? 'bg-secondary-container/10' : ''">
          <div class="p-4 border-r border-outline-variant/20 flex flex-col items-center justify-center">
            <span class="text-xs font-label text-outline uppercase tracking-widest mb-1">Current High Bidder</span>
            <span class="text-xl font-headline font-black text-on-surface uppercase truncate">
              {{ store.currentHighBidder?.display_name ?? '—' }}
            </span>
          </div>
          <div class="p-4 flex flex-col items-center justify-center">
            <span class="text-xs font-label text-outline uppercase tracking-widest mb-1">Current High Bid</span>
            <span class="text-xl font-headline font-black" :class="currentHighBid > 0 ? 'text-secondary animate-pulse' : 'text-outline'">
              ${{ currentHighBid || '—' }}
            </span>
          </div>
        </div>
        <!-- Row 2: Your budget + next minimum bid -->
        <div class="grid grid-cols-2">
          <div class="p-4 border-r border-outline-variant/20 flex flex-col items-center justify-center">
            <span class="text-xs font-label text-outline uppercase tracking-widest mb-1">Your Budget</span>
            <span class="text-xl font-headline font-black text-primary">${{ myBudget }}</span>
          </div>
          <div class="p-4 flex flex-col items-center justify-center">
            <span class="text-xs font-label text-outline uppercase tracking-widest mb-1">Next Minimum Bid</span>
            <span class="text-xl font-headline font-black text-on-surface">${{ nextMinBid }}</span>
          </div>
        </div>
      </div>

      <!-- Bidding Controls -->
      <div class="p-8 space-y-6 flex-1 overflow-y-auto">

        <!-- Auto-passed state -->
        <div v-if="isAutoPass" class="text-center py-4">
          <div class="inline-flex items-center gap-3 bg-surface-container-high px-6 py-4 border border-outline-variant/30">
            <span class="material-symbols-outlined text-outline">block</span>
            <div>
              <div class="font-headline font-bold uppercase text-on-surface-variant text-sm">AUTO-PASSED</div>
              <div class="text-[10px] font-label text-outline uppercase tracking-wider">Max bid ${{ maxBid }} — below current</div>
            </div>
          </div>
        </div>

        <template v-else>
          <!-- Quick bid buttons -->
          <div class="grid grid-cols-3 gap-4">
            <button
              v-for="delta in [1, 5, 10]"
              :key="delta"
              :disabled="nextMinBid - 1 + delta > maxBid || submitting"
              class="bg-surface-container-high hover:bg-primary/20 border border-primary/30 py-6 font-headline font-black text-2xl text-primary transition-all active:scale-95 disabled:opacity-30 disabled:cursor-not-allowed"
              @click="bid(delta)"
            >
              +${{ delta }}
            </button>
          </div>

          <button
            :disabled="submitting"
            class="w-full metallic-primary py-6 font-headline font-black text-2xl text-on-primary-fixed shadow-stadium active:scale-[0.98] uppercase tracking-widest disabled:opacity-40"
            @click="bid(1)"
          >
            {{ submitting ? 'SUBMITTING...' : 'SUBMIT BID' }}
          </button>

          <button
            :disabled="submitting"
            class="w-full bg-surface-container hover:bg-secondary/10 border border-secondary/20 py-4 font-headline font-bold text-secondary transition-all active:scale-95 uppercase tracking-tighter disabled:opacity-40"
            @click="pass"
          >
            Pass
          </button>
        </template>

        <p v-if="bidError" class="text-xs text-error font-label text-center">{{ bidError }}</p>
      </div>

      <!-- Admin-only override controls -->
      <div v-if="isAdmin" class="p-6 border-t border-outline-variant/20 bg-surface-container-high/50 space-y-3">
        <div class="text-[10px] font-label text-outline uppercase tracking-widest mb-2">Admin Controls</div>
        <div class="grid grid-cols-2 gap-2 mb-2">
          <button
            class="bg-surface-container hover:bg-primary/20 border border-primary/30 py-3 font-headline font-black text-primary transition-all text-xs uppercase"
            @click="forceBid(1)"
          >Force +$1</button>
          <button
            class="bg-surface-container hover:bg-primary/20 border border-primary/30 py-3 font-headline font-black text-primary transition-all text-xs uppercase"
            @click="forceBid(5)"
          >Force +$5</button>
        </div>
        <div class="grid grid-cols-3 gap-2">
          <button
            :disabled="submitting"
            class="bg-surface-container hover:bg-secondary/20 border border-secondary/30 py-3 font-headline font-bold text-secondary transition-all text-xs uppercase disabled:opacity-40"
            @click="clearLastBid"
          >Clear Last Bid</button>
          <button
            :disabled="submitting"
            class="bg-surface-container hover:bg-secondary/20 border border-secondary/30 py-3 font-headline font-bold text-secondary transition-all text-xs uppercase disabled:opacity-40"
            @click="clearAllBids"
          >Clear All Bids</button>
          <button
            :disabled="submitting"
            class="bg-error-container/30 hover:bg-error/20 border border-error/30 py-3 font-headline font-bold text-error transition-all text-xs uppercase disabled:opacity-40"
            @click="endBidding"
          >End Bidding</button>
        </div>
        <p v-if="adminError" class="text-xs text-error font-label text-center">{{ adminError }}</p>
      </div>
    </template>
  </div>
</template>
