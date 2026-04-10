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
    const { auction_id, auction_school_id, team_id, roster_position_id, winning_bid } =
      await req.json()

    if (!auction_id || !auction_school_id || !team_id) {
      throw new Error('Missing required fields: auction_id, auction_school_id, team_id')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const price = Math.max(0, winning_bid ?? 0)

    // Get current pick count for pick_order
    const { count: pickCount } = await supabase
      .from('draft_picks')
      .select('id', { count: 'exact', head: true })
      .eq('auction_id', auction_id)

    // Insert draft pick
    const { error: pickErr } = await supabase.from('draft_picks').insert({
      auction_id,
      team_id,
      auction_school_id,
      roster_position_id: roster_position_id ?? null,
      winning_bid: price,
      pick_order: (pickCount ?? 0) + 1,
      won_by_id: null,
    })

    if (pickErr) throw pickErr

    // Mark school unavailable
    await supabase
      .from('auction_schools')
      .update({ is_available: false })
      .eq('id', auction_school_id)

    // Deduct from team budget
    if (price > 0) {
      const { data: team } = await supabase
        .from('teams')
        .select('remaining_budget')
        .eq('id', team_id)
        .single()

      if (team) {
        await supabase
          .from('teams')
          .update({ remaining_budget: team.remaining_budget - price })
          .eq('id', team_id)
      }
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
