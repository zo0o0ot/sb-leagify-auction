# Draft Readiness — Pre-April 8 Fix Tracker

Issues identified through audit and testing. Ordered by impact on the real draft.

---

## CRITICAL — Will visibly break the draft

### [ ] 1. "Winning Coach" always shows `—` in the bid status row

**Where:** `src/stores/auction.ts` — `currentHighBidderParticipant` computed  
**Problem:** After migration 011, `current_high_bidder_id` stores a **team ID**. The store looks for a *participant* whose `id === current_high_bidder_id` — those are different ID sequences. The lookup always returns null, so `currentHighBidder.display_name` and the "Winning Coach" cell in the bid status row always shows `—`.  
**Fix:** Rewrite `currentHighBidderTeam` to look up directly by team ID, then find the participant from that team:
```ts
const currentHighBidderTeam = computed(() =>
  auction.value?.current_high_bidder_id
    ? teams.value.find((t) => t.id === auction.value!.current_high_bidder_id) ?? null
    : null,
)
const currentHighBidderParticipant = computed(() => {
  const team = currentHighBidderTeam.value
  if (!team) return null
  return participants.value.find((p) => p.team_id === team.id) ?? null
})
```
**Test:** Place a bid → "Winning Coach" cell shows correct team/coach name.

---

### [ ] 2. Admin "Force Nomination" fails silently

**Where:** `supabase/functions/nominate-school/index.ts`  
**Problem:** `nominate-school` checks `auction.current_nominator_id !== participant_id` and throws. When admin clicks "Force Nomination" or "Admin: Force Nomination", they send their own `participant_id`, which will never match the current nominator. Result: nothing happens, no error shown to the user.  
**Fix:** Pass `is_admin_override: true` in the request body. In the edge function, skip the nominator check when override is true (service role key validates this is a legitimate admin call, not a spoofed user request). Update `store.nominateSchool()` to include the flag when `store.isAuctionMaster`.  
**Test:** Set current nominator to coach A. Admin opens NominationGrid and nominates — school should go on the block.

---

### [ ] 3. Bids never auto-complete when any team has no connected participant

**Where:** `supabase/functions/pass-bid/index.ts`  
**Problem:** `pass-bid` counts ALL active teams (minus high bidder) and waits for all to pass. Teams with no participant linked (empty slots in a partially-filled league) or disconnected coaches will never press pass. Every bid in a real draft will require admin "Force End Bidding".  
**Fix:** In the eligible team count, exclude teams that have no participant row, or that have no connected participant. Query `participants` joined to `teams` and only count teams that have at least one participant:
```ts
const { data: teamsWithParticipants } = await supabase
  .from('participants')
  .select('team_id')
  .eq('auction_id', auction_id)
  .not('team_id', 'is', null)
const teamIdsWithParticipants = new Set((teamsWithParticipants ?? []).map(p => p.team_id))
const totalEligibleTeams = (activeTeams ?? [])
  .filter(t => teamIdsWithParticipants.has(t.id))
  .filter(t => t.id !== auction.current_high_bidder_id)
  .length
```
**Test:** Run `scripts/test-lobby-draft.sh` — all 17 still pass. Then test with a 4-team auction where only 2 teams have participants; bid should auto-complete after those 2 teams act.

---

## IMPORTANT — Admin workarounds exist but awkward

### [ ] 4. Auto-pass checkboxes are non-functional

**Where:** `src/views/auction/DraftView.vue` lines 251–260  
**Problem:** Per-team auto-pass checkboxes in admin mode sidebar have no `v-model`, no store state, and no logic. This was in-scope per the MVP plan. Without it, admin must manually Force End Bidding on every pick where a coach is unresponsive.  
**Fix:**
1. Add `autoPassTeamIds = ref<Set<number>>(new Set())` to DraftView (or store)
2. Wire checkboxes with a computed getter/setter
3. In `pass()` / the realtime `auctions` update handler: when auction state changes to a new school on the block, auto-submit passes for any team in `autoPassTeamIds`
4. Alternatively (simpler): when admin ticks auto-pass for a team, immediately call `store.pass()` with that team's participant any time a new school is nominated  
**Test:** Tick auto-pass for Team B. Admin nominates a school. Team B's pass should appear in the bid log automatically.

---

### [ ] 5. Nominator doesn't skip teams without participants

**Where:** `supabase/functions/complete-bid/index.ts` — nominator advance logic  
**Problem:** When advancing the nominator after a completed pick, if the next team in `nomination_order` has no participant row, `nextNominatorId` stays unchanged (same person nominates again). In a full 6-coach draft this won't matter, but if anyone drops mid-draft the rotation breaks.  
**Fix:** Walk `allTeams` in order starting from `currentIdx + 1`, wrapping around, until finding a team that has a participant. Use that participant as `nextNominatorId`.  
**Test:** Create a 4-team auction with participants only on teams 1 and 3 (nomination_order 1 and 3). Complete a bid — verify nominator advances to team 3's participant, not team 2 (no participant).

---

## MINOR — Low risk if all coaches are present

### [ ] 6. No bid history on initial page load

**Where:** `src/stores/auction.ts` — `loadAuction()`  
**Problem:** `loadAuction` does not fetch any `bid_history`. The bid log in the draft view starts empty and only fills as new bids arrive via realtime. If you load the draft mid-auction (refresh, late join) you see no prior bidding context for the current school.  
**Fix:** Add a `bid_history` fetch to the `Promise.all` in `loadAuction`, scoped to the current `auction_school_id` if one is active, or the last 20 bids:
```ts
supabase.from('bid_history')
  .select('*')
  .eq('auction_id', auctionId)
  .eq('is_practice', false)
  .order('id', { ascending: false })
  .limit(30)
```
Store results in `bidHistory.value` (reversed so newest-first).  
**Test:** Place 3 bids. Refresh the draft page. All 3 bids should appear in the bid log.

---

## STATUS SUMMARY

| # | Issue | Status | Priority |
|---|-------|--------|----------|
| 1 | Winning Coach always shows `—` | ⬜ Not started | Critical |
| 2 | Admin Force Nomination fails | ⬜ Not started | Critical |
| 3 | Bids don't auto-complete with absent teams | ⬜ Not started | Critical |
| 4 | Auto-pass checkboxes non-functional | ⬜ Not started | Important |
| 5 | Nominator skips teams without participants | ⬜ Not started | Important |
| 6 | No bid history on initial load | ⬜ Not started | Minor |

---

## Already Fixed This Session

- ✅ RLS blocking join/lobby/draft flows (migrations 006–009)
- ✅ `current_high_bidder_id` FK pointed to participants instead of teams (migration 011)
- ✅ `startDraft` never set `current_nominator_id` (LobbyView fix)
- ✅ All edge functions returning 4xx (swallowed by Supabase JS) → all return 200 + `{ok, error}`
- ✅ Practice bidding school picker (LobbyView)
- ✅ 64 default schools seeded via migration (migration 010)
- ✅ `draft_picks` UPDATE policy blocked `assignPosition` (migration 012)
- ✅ `bid_history` had no DELETE policy (migration 013)
- ✅ `PickIsInSting` showed blank school (realtime payload has no joins — enriched in `updateDraftPick`)
- ✅ Readiness toggle and start draft tested locally before deploy
- ✅ 404 on page refresh (Vercel SPA routing via `vercel.json`)
- ✅ Practice bidding admin controls (clear last bid, clear all bids, end bidding)
- ✅ Pass error handling in DraftView
