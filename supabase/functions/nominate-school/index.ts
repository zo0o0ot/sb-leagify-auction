import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-token',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { auction_id, participant_id, team_id, auction_school_id, is_admin_override } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Validate auction is in_progress and no school is currently on the block
    const { data: auction, error: aErr } = await supabase
      .from('auctions')
      .select('id, status, current_school_id, current_nominator_id')
      .eq('id', auction_id)
      .single()

    if (aErr || !auction) throw new Error('Auction not found')
    if (auction.status !== 'in_progress') throw new Error('Auction is not in progress')
    if (auction.current_school_id) throw new Error('A school is already on the block')
    if (!is_admin_override && auction.current_nominator_id !== participant_id) throw new Error('It is not your turn to nominate')

    // Validate school is available
    const { data: school, error: sErr } = await supabase
      .from('auction_schools')
      .select('id, is_available')
      .eq('id', auction_school_id)
      .single()

    if (sErr || !school) throw new Error('School not found')
    if (!school.is_available) throw new Error('School is no longer available')

    // Set school on the block, start bidding at $1
    const { error: updateErr } = await supabase
      .from('auctions')
      .update({
        current_school_id: auction_school_id,
        current_high_bid: 0,
        current_high_bidder_id: null,
      })
      .eq('id', auction_id)

    if (updateErr) throw updateErr

    // Record nomination in bid history
    await supabase.from('bid_history').insert({
      auction_id,
      auction_school_id,
      participant_id,
      team_id,
      bid_type: 'nomination',
      amount: 0,
      is_winning_bid: false,
      is_practice: false,
    })

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
