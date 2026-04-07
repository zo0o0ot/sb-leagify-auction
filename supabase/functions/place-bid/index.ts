import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-token',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { auction_id, participant_id, team_id, amount, on_behalf_of_team_id } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Lock the auction row to prevent race conditions
    const { data: auction, error: aErr } = await supabase.rpc('get_auction_for_update', {
      p_auction_id: auction_id,
    })

    if (aErr || !auction) {
      // Fall back to regular select if RPC not available
      const { data: a, error: ae } = await supabase
        .from('auctions')
        .select('id, status, current_school_id, current_high_bid, current_high_bidder_id')
        .eq('id', auction_id)
        .single()
      if (ae || !a) throw new Error('Auction not found')
      if (a.status !== 'in_progress' && a.status !== 'practice') throw new Error('Auction is not active')
      if (!a.current_school_id) throw new Error('No school is currently on the block')
      if (amount <= (a.current_high_bid ?? 0)) throw new Error(`Bid must exceed current high bid of $${a.current_high_bid ?? 0}`)

      // Validate team budget
      const effectiveTeamId = on_behalf_of_team_id ?? team_id
      const { data: team } = await supabase
        .from('teams')
        .select('remaining_budget')
        .eq('id', effectiveTeamId)
        .single()
      if (!team) throw new Error('Team not found')
      if (amount > team.remaining_budget) throw new Error('Bid exceeds remaining budget')

      // Update auction with new high bid
      const { error: updateErr } = await supabase
        .from('auctions')
        .update({ current_high_bid: amount, current_high_bidder_id: effectiveTeamId })
        .eq('id', auction_id)

      if (updateErr) throw new Error('Auction update failed: ' + updateErr.message)

      // Record bid
      await supabase.from('bid_history').insert({
        auction_id,
        auction_school_id: a.current_school_id,
        participant_id,
        team_id: effectiveTeamId,
        bid_type: 'bid',
        amount,
        is_winning_bid: false, // updated when bid completes
        is_practice: a.status === 'practice',
        on_behalf_of_team_id: on_behalf_of_team_id ?? null,
      })

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: (err as Error).message }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
