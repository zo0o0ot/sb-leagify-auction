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
    console.log('[create-auction] request received')
    const body = await req.json()
    const {
      auction_name,
      join_code,
      participant_count,
      budget,
      creator_name,
      school_source,
      roster_positions,
      supabase_uid,
    } = body
    console.log(
      '[create-auction] parsed body ok, school_source=',
      school_source,
      'join_code=',
      join_code,
    )

    if (!auction_name || !join_code || !creator_name || !supabase_uid) {
      throw new Error('Missing required fields')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    console.log('[create-auction] supabase client created')

    // 1. Upsert user record
    const { data: userData, error: userErr } = await supabase
      .from('users')
      .upsert({ supabase_uid, email: null }, { onConflict: 'supabase_uid' })
      .select('id')
      .single()

    if (userErr || !userData) throw new Error('Failed to upsert user: ' + (userErr?.message ?? ''))
    const userId = userData.id
    console.log('[create-auction] user upserted, userId=', userId)

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
    console.log('[create-auction] auction created, auctionId=', auctionId)

    // 3. Create roster positions
    if (roster_positions?.length) {
      const { error: rpErr } = await supabase
        .from('roster_positions')
        .insert(
          roster_positions.map((rp: Record<string, unknown>) => ({ ...rp, auction_id: auctionId })),
        )

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
      await supabase.from('teams').update({ team_name: creator_name }).eq('id', creatorTeamId)
    }

    // 7. If default school set, copy from master schools table
    if (school_source === 'default') {
      console.log('[create-auction] fetching schools...')
      const { data: allSchools, error: schoolsErr } = await supabase
        .from('schools')
        .select(
          'id, conference, leagify_position, projected_points, number_of_prospects, points_above_average, points_above_replacement',
        )
        .order('projected_points', { ascending: false })
      console.log(
        '[create-auction] schools fetched, count=',
        allSchools?.length,
        'err=',
        schoolsErr?.message,
      )
      if (allSchools?.length) {
        const schoolInserts = allSchools.map((s: Record<string, unknown>, i: number) => ({
          auction_id: auctionId,
          school_id: s.id,
          leagify_position: s.leagify_position ?? 'Flex',
          conference: s.conference ?? 'Independent',
          projected_points: s.projected_points ?? 0,
          number_of_prospects: s.number_of_prospects ?? 0,
          points_above_average: s.points_above_average ?? null,
          points_above_replacement: s.points_above_replacement ?? null,
          import_order: i,
        }))
        console.log('[create-auction] inserting', schoolInserts.length, 'auction_schools...')
        const { error: asErr } = await supabase.from('auction_schools').insert(schoolInserts)
        if (asErr) console.error('[create-auction] auction_schools insert error:', asErr.message)
        else console.log('[create-auction] auction_schools inserted ok')
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
    console.error('[create-auction] CAUGHT ERROR:', msg)
    // Always return 200 so the Supabase JS client passes the body back to the caller.
    // A 4xx causes the client to throw FunctionsHttpError with a generic message,
    // discarding the actual error detail.
    return new Response(JSON.stringify({ ok: false, error: msg }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
