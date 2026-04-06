import { onMounted, onUnmounted, ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuctionStore } from '@/stores/auction'
import type { Auction, Participant, Team, DraftPick, BidHistory } from '@/types/auction'

export function useAuctionRealtime(auctionId: number) {
  const store = useAuctionStore()
  const isConnected = ref(false)
  let channel: ReturnType<typeof supabase.channel> | null = null
  let heartbeatInterval: ReturnType<typeof setInterval> | null = null

  function subscribe() {
    channel = supabase
      .channel(`auction:${auctionId}`)

      // Auction state (status, current bid, nominator)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'auctions', filter: `id=eq.${auctionId}` },
        (payload) => {
          store.updateAuction(payload.new as Auction)
        },
      )

      // Participant presence (connected, ready)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'participants', filter: `auction_id=eq.${auctionId}` },
        (payload) => {
          if (payload.eventType === 'DELETE') return
          store.updateParticipant(payload.new as Participant)
        },
      )

      // Team budgets (updated after each completed bid)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'teams', filter: `auction_id=eq.${auctionId}` },
        (payload) => {
          const team = payload.new as Team
          store.updateTeamBudget(team.id, team.remaining_budget)
        },
      )

      // Live bid log
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'bid_history', filter: `auction_id=eq.${auctionId}` },
        (payload) => {
          store.addBid(payload.new as BidHistory)
        },
      )

      // Draft picks (position assignments)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'draft_picks', filter: `auction_id=eq.${auctionId}` },
        (payload) => {
          if (payload.eventType === 'DELETE') return
          store.updateDraftPick(payload.new as DraftPick)
        },
      )

      // School availability (marked unavailable after nomination)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'auction_schools', filter: `auction_id=eq.${auctionId}` },
        (payload) => {
          if (payload.new.is_available === false) {
            store.markSchoolUnavailable(payload.new.id as number)
          }
        },
      )

      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          isConnected.value = true
          markConnected(true)
        } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
          isConnected.value = false
          markConnected(false)
        }
      })
  }

  async function markConnected(connected: boolean) {
    if (!store.session) return
    await supabase
      .from('participants')
      .update({ is_connected: connected, last_seen_at: new Date().toISOString() })
      .eq('id', store.session.participantId)
  }

  function startHeartbeat() {
    // Update last_seen_at every 30s so others can detect stale connections
    heartbeatInterval = setInterval(() => {
      if (!store.session) return
      supabase
        .from('participants')
        .update({ last_seen_at: new Date().toISOString() })
        .eq('id', store.session.participantId)
    }, 30_000)
  }

  onMounted(async () => {
    await store.loadAuction(auctionId)
    subscribe()
    startHeartbeat()
  })

  onUnmounted(() => {
    isConnected.value = false
    markConnected(false)
    if (channel) supabase.removeChannel(channel)
    if (heartbeatInterval) clearInterval(heartbeatInterval)
  })

  return { isConnected }
}
