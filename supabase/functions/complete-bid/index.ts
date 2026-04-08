import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-token',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { auction_id } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Get current auction state
    const { data: auction, error: aErr } = await supabase
      .from('auctions')
      .select('id, status, current_school_id, current_high_bid, current_high_bidder_id, current_nominator_id')
      .eq('id', auction_id)
      .single()

    if (aErr || !auction) throw new Error('Auction not found')
    if (!auction.current_school_id) throw new Error('No school on the block')
    if (!auction.current_high_bidder_id) throw new Error('No winning bidder')

    const winningBid = auction.current_high_bid ?? 0
    const winningTeamId = auction.current_high_bidder_id
    const schoolId = auction.current_school_id

    // 1. Deduct budget from winning team
    const { data: team, error: tErr } = await supabase
      .from('teams')
      .select('remaining_budget, nomination_order')
      .eq('id', winningTeamId)
      .single()

    if (tErr || !team) throw new Error('Winning team not found')

    await supabase
      .from('teams')
      .update({ remaining_budget: team.remaining_budget - winningBid })
      .eq('id', winningTeamId)

    // 2. Get pick order (count existing picks + 1)
    const { count: pickCount } = await supabase
      .from('draft_picks')
      .select('id', { count: 'exact', head: true })
      .eq('auction_id', auction_id)

    // 3. Find the winning participant (team coach for this team)
    const { data: winnerParticipant } = await supabase
      .from('participants')
      .select('id')
      .eq('auction_id', auction_id)
      .eq('team_id', winningTeamId)
      .maybeSingle()

    // 4. Create draft pick (roster_position_id null — assigned via modal)
    const { data: draftPick, error: dpErr } = await supabase
      .from('draft_picks')
      .insert({
        auction_id,
        team_id: winningTeamId,
        auction_school_id: schoolId,
        winning_bid: winningBid,
        pick_order: (pickCount ?? 0) + 1,
        won_by_id: winnerParticipant?.id ?? null,
      })
      .select()
      .single()

    if (dpErr) throw dpErr

    // 5. Mark school as unavailable
    await supabase
      .from('auction_schools')
      .update({ is_available: false })
      .eq('id', schoolId)

    // 6. Mark the winning bid in bid_history
    await supabase
      .from('bid_history')
      .update({ is_winning_bid: true })
      .eq('auction_id', auction_id)
      .eq('auction_school_id', schoolId)
      .eq('team_id', winningTeamId)
      .eq('bid_type', 'bid')
      .order('created_at', { ascending: false })
      .limit(1)

    // 7. Advance nominator (circular by nomination_order)
    const { data: allTeams } = await supabase
      .from('teams')
      .select('id, nomination_order')
      .eq('auction_id', auction_id)
      .eq('is_active', true)
      .order('nomination_order')

    const { data: nominatorParticipant } = await supabase
      .from('participants')
      .select('id, team_id')
      .eq('id', auction.current_nominator_id)
      .single()

    // Build a map of team_id → participant_id for quick lookup (only teams with participants)
    const { data: allParticipants } = await supabase
      .from('participants')
      .select('id, team_id')
      .eq('auction_id', auction_id)
      .not('team_id', 'is', null)

    const participantByTeam = new Map((allParticipants ?? []).map((p) => [p.team_id, p.id]))

    let nextNominatorId = auction.current_nominator_id
    if (allTeams && nominatorParticipant) {
      const currentIdx = allTeams.findIndex((t) => t.id === nominatorParticipant.team_id)
      // Walk forward circularly until we find a team that has a participant
      for (let i = 1; i <= allTeams.length; i++) {
        const candidate = allTeams[(currentIdx + i) % allTeams.length]!
        const candidateParticipantId = participantByTeam.get(candidate.id)
        if (candidateParticipantId) {
          nextNominatorId = candidateParticipantId
          break
        }
      }
    }

    // 8. Reset auction state, advance nominator
    await supabase
      .from('auctions')
      .update({
        current_school_id: null,
        current_high_bid: null,
        current_high_bidder_id: null,
        current_nominator_id: nextNominatorId,
      })
      .eq('id', auction_id)

    return new Response(JSON.stringify({ ok: true, draft_pick: draftPick }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: (err as Error).message }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
