import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-session-token',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const {
      auction_name,
      join_code,
      participant_count,
      budget,
      creator_name,
      school_source,
      roster_positions,
      supabase_uid,
    } = await req.json()

    if (!auction_name || !join_code || !creator_name || !supabase_uid) {
      throw new Error('Missing required fields')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. Upsert user record
    const { data: userData, error: userErr } = await supabase
      .from('users')
      .upsert({ supabase_uid, email: null }, { onConflict: 'supabase_uid' })
      .select('id')
      .single()

    if (userErr || !userData) throw new Error('Failed to upsert user: ' + (userErr?.message ?? ''))
    const userId = userData.id

    // 2. Create auction
    const { data: auction, error: auctionErr } = await supabase
      .from('auctions')
      .insert({
        join_code,
        name: auction_name,
        status: 'draft',
        created_by: userId,
        default_budget: budget,
      })
      .select('id')
      .single()

    if (auctionErr || !auction) {
      if (auctionErr?.code === '23505') throw new Error('JOIN_CODE_CONFLICT')
      throw new Error('Failed to create auction: ' + (auctionErr?.message ?? ''))
    }

    const auctionId = auction.id

    // 3. Create roster positions
    if (roster_positions?.length) {
      const { error: rpErr } = await supabase
        .from('roster_positions')
        .insert(roster_positions.map((rp: Record<string, unknown>) => ({ ...rp, auction_id: auctionId })))

      if (rpErr) throw new Error('Failed to create roster positions: ' + rpErr.message)
    }

    // 4. Create team placeholder slots
    const teamInserts = Array.from({ length: participant_count }, (_: unknown, i: number) => ({
      auction_id: auctionId,
      team_name: `Team ${i + 1}`,
      budget,
      remaining_budget: budget,
      nomination_order: i + 1,
    }))
    const { data: teams, error: teamsErr } = await supabase
      .from('teams')
      .insert(teamInserts)
      .select('id')

    if (teamsErr || !teams) throw new Error('Failed to create teams: ' + (teamsErr?.message ?? ''))
    const creatorTeamId = teams[0]?.id ?? null

    // 5. Create session token and auction master participant
    const sessionToken = crypto.randomUUID()

    const { data: participant, error: participantErr } = await supabase
      .from('participants')
      .insert({
        auction_id: auctionId,
        user_id: userId,
        display_name: creator_name,
        role: 'auction_master',
        team_id: creatorTeamId,
        session_token: sessionToken,
        is_connected: true,
      })
      .select('id, role, team_id')
      .single()

    if (participantErr || !participant) {
      throw new Error('Failed to create participant: ' + (participantErr?.message ?? ''))
    }

    // 6. Rename team 1 to creator's name
    if (creatorTeamId) {
      await supabase
        .from('teams')
        .update({ team_name: creator_name })
        .eq('id', creatorTeamId)
    }

    // 7. If default school set, copy from master schools table
    if (school_source === 'default') {
      const { data: allSchools } = await supabase.from('schools').select('id, name')
      if (allSchools?.length) {
        const schoolInserts = allSchools.map((s: { id: unknown; name: string }, i: number) => ({
          auction_id: auctionId,
          school_id: s.id,
          leagify_position: guessPosition(s.name),
          conference: guessConference(s.name),
          projected_points: 100,
          import_order: i,
        }))
        await supabase.from('auction_schools').insert(schoolInserts)
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        auction_id: auctionId,
        participant_id: participant.id,
        team_id: creatorTeamId,
        session_token: sessionToken,
        role: 'auction_master',
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    const msg = (err as Error).message
    // Always return 200 so the Supabase JS client passes the body back to the caller.
    // A 4xx causes the client to throw FunctionsHttpError with a generic message,
    // discarding the actual error detail.
    return new Response(JSON.stringify({ ok: false, error: msg }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

function guessPosition(name: string): string {
  const sec = ['Alabama', 'Georgia', 'LSU', 'Tennessee', 'Auburn', 'Ole Miss', 'Texas A&M', 'Mississippi State', 'Arkansas', 'Kentucky', 'Missouri', 'Vanderbilt', 'South Carolina', 'Florida']
  const bigTen = ['Ohio State', 'Michigan', 'Penn State', 'Wisconsin', 'Iowa', 'Minnesota', 'Illinois', 'Northwestern', 'Indiana', 'Purdue', 'Rutgers', 'Maryland', 'Nebraska', 'Michigan State']
  const acc = ['Clemson', 'Florida State', 'Miami', 'North Carolina', 'NC State', 'Virginia', 'Virginia Tech', 'Georgia Tech', 'Pittsburgh', 'Boston College', 'Wake Forest', 'Duke', 'Syracuse', 'Louisville', 'Notre Dame']
  const big12 = ['Texas', 'Oklahoma', 'Texas Tech', 'TCU', 'Baylor', 'Kansas State', 'Kansas', 'Iowa State', 'Oklahoma State', 'West Virginia', 'UCF', 'BYU', 'Cincinnati', 'Houston']
  if (sec.includes(name)) return 'SEC'
  if (bigTen.includes(name)) return 'Big Ten'
  if (acc.includes(name)) return 'ACC'
  if (big12.includes(name)) return 'Big 12'
  return 'Flex'
}

function guessConference(name: string): string {
  const pos = guessPosition(name)
  if (pos === 'Flex') return 'Independent'
  return pos
}
