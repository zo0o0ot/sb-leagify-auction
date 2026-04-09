import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-session-token',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { auction_id, participant_id, team_id } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Get auction state
    const { data: auction, error: aErr } = await supabase
      .from('auctions')
      .select('id, status, current_school_id, current_high_bidder_id')
      .eq('id', auction_id)
      .single()

    if (aErr || !auction) throw new Error('Auction not found')
    if (!auction.current_school_id) throw new Error('No school is currently on the block')

    // Record pass
    await supabase.from('bid_history').insert({
      auction_id,
      auction_school_id: auction.current_school_id,
      participant_id,
      team_id,
      bid_type: 'pass',
      amount: 0,
      is_winning_bid: false,
      is_practice: auction.status === 'practice',
    })

    // If practice mode, do not auto-complete
    if (auction.status === 'practice') {
      return new Response(JSON.stringify({ ok: true, completed: false }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Count distinct teams that have passed (and aren't the current high bidder)
    const { data: passes } = await supabase
      .from('bid_history')
      .select('team_id')
      .eq('auction_id', auction_id)
      .eq('auction_school_id', auction.current_school_id)
      .eq('bid_type', 'pass')
      .neq('team_id', auction.current_high_bidder_id ?? -1)

    const passedTeamIds = new Set((passes ?? []).map((p) => p.team_id))

    // Count active teams that have at least one participant and a non-full roster.
    // Teams with no participant will never pass — excluding them prevents deadlocks.
    // Teams with a full roster can't use any more schools — excluding them too.
    const [activeTeamsRes, participantTeamsRes, rosterPositionsRes, allPicksRes] =
      await Promise.all([
        supabase
          .from('teams')
          .select('id')
          .eq('auction_id', auction_id)
          .eq('is_active', true)
          .neq('id', auction.current_high_bidder_id ?? -1),
        supabase
          .from('participants')
          .select('team_id')
          .eq('auction_id', auction_id)
          .not('team_id', 'is', null),
        supabase.from('roster_positions').select('slots_per_team').eq('auction_id', auction_id),
        supabase.from('draft_picks').select('team_id').eq('auction_id', auction_id),
      ])

    const teamIdsWithParticipants = new Set((participantTeamsRes.data ?? []).map((p) => p.team_id))

    const slotsPerTeam = (rosterPositionsRes.data ?? []).reduce(
      (sum, rp) => sum + rp.slots_per_team,
      0,
    )
    const pickCountByTeam = new Map<number, number>()
    for (const pick of allPicksRes.data ?? []) {
      pickCountByTeam.set(pick.team_id, (pickCountByTeam.get(pick.team_id) ?? 0) + 1)
    }
    const isRosterFull = (teamId: number) =>
      slotsPerTeam > 0 && (pickCountByTeam.get(teamId) ?? 0) >= slotsPerTeam

    const totalEligibleTeams = (activeTeamsRes.data ?? []).filter(
      (t) => teamIdsWithParticipants.has(t.id) && !isRosterFull(t.id),
    ).length

    // If no one has bid yet and all teams pass, it's a no-sale (skip school)
    const hasHighBidder = !!auction.current_high_bidder_id

    if (!hasHighBidder && passedTeamIds.size >= totalEligibleTeams) {
      // Everyone passed with no bids — clear the school without a pick
      await supabase
        .from('auctions')
        .update({
          current_school_id: null,
          current_high_bid: null,
          current_high_bidder_id: null,
        })
        .eq('id', auction_id)

      return new Response(JSON.stringify({ ok: true, completed: true, no_sale: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (hasHighBidder && passedTeamIds.size >= totalEligibleTeams) {
      // All non-high-bidders passed — trigger complete-bid
      const completeBidUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/complete-bid`
      await fetch(completeBidUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        },
        body: JSON.stringify({ auction_id }),
      })

      return new Response(JSON.stringify({ ok: true, completed: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ ok: true, completed: false }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: (err as Error).message }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
