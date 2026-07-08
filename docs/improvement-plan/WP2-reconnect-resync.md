# WP2 — State Resync on Reconnect / Tab Resume

**Complexity:** Simple
**Dependencies:** None — start immediately. Independent of all other WPs.
**Findings addressed:** F6 (see [README.md](README.md))
**Branch:** `wp2-resync`

## Problem

`src/composables/useAuctionRealtime.ts` loads auction state exactly once (`onMounted` →
`store.loadAuction(auctionId)`) and afterwards relies purely on Supabase Realtime deltas
(postgres_changes on `auctions`, `participants`, `teams`, `bid_history`, `draft_picks`,
`auction_schools`). There is **no refetch when the channel reconnects** — the `subscribe`
status callback (lines 75-83) only flips `isConnected` and writes `is_connected` to the DB.

Consequences:

- Mobile browsers suspend WebSockets when the tab/app is backgrounded. Coming back to the
  draft shows stale state (wrong school on the block, wrong high bid) until a manual reload.
- Any network blip mid-draft silently drops events with no recovery. The only recovery today
  is `ConnectionLostOverlay`'s full `window.location.reload()`.

This is a prerequisite for phone use (WP4) and complements WP1's server-side correctness:
clients must converge to correct state after missing events.

## Approach

All changes in `src/composables/useAuctionRealtime.ts` (you own this file). `store.loadAuction`
already refetches everything idempotently — reuse it as the resync primitive.

1. **Resync on channel recovery.** Track that the channel was previously disconnected
   (`CLOSED` / `CHANNEL_ERROR` / `TIMED_OUT`); when the status callback next reports
   `SUBSCRIBED`, call `store.loadAuction(auctionId)` before marking connected. Events that
   arrived during the gap are lost — the reload covers them.
2. **Resync on tab resume.** Add a `visibilitychange` listener (registered in `onMounted`,
   removed in `onUnmounted`): when `document.visibilityState === 'visible'`, call
   `store.loadAuction(auctionId)` and update `last_seen_at`. If the realtime channel died
   while backgrounded (common on iOS Safari), also tear down and resubscribe — check the
   channel state and rebuild via the existing `subscribe()`.
3. **Auth guard on resync.** Mirror the `onMounted` logic (lines 109-112): if the anonymous
   auth session expired while suspended, `signInAnonymously()` before reloading.
4. **Debounce.** Guard against overlapping resyncs (a simple in-flight flag is enough;
   `visibilitychange` and `SUBSCRIBED` can fire together on resume).

Keep the existing 30s heartbeat as-is.

## Watch out for

- `loadAuction` sets `loading = true`, which views may use to render a spinner. A background
  resync should not blank the whole draft screen — check how `loading` is consumed in
  `DraftView.vue` / `LobbyView.vue`; if it would flash, add a `silent` option to `loadAuction`
  (additive parameter, default false) rather than reshaping store state.
- Do not change the subscription filters or the store mutation functions — WP3 adds computeds
  to the store, and file ownership for `src/stores/auction.ts` is WP3's. If you need the
  `silent` param, that one additive change is allowed; note it in your PR.
- The 5s `connectionReady` suppression window in `DraftView.vue:23-28` masks handshake flapping;
  your changes shouldn't reintroduce a false "connection lost" flash on navigation.

## Acceptance criteria

- [ ] Kill the network (dev tools offline) mid-draft, place a bid from another window after
      reconnect-blocking, restore network: within a few seconds the first window shows the
      correct current bid **without a manual reload**.
- [ ] Background the tab (or switch apps on a phone / responsive-mode emulation), advance the
      draft from another window, return: state is correct without reload.
- [ ] No spinner/blank flash during background resync.
- [ ] Rapid visibility toggling does not stack concurrent `loadAuction` calls.
- [ ] Existing Vitest suite passes; `npm run build` clean.

## Verification recipe

`supabase start` + `npm run dev`, two browser windows (owner + coach via join code — see
memory of the join flow in `MVP-BUILD-PLAN.md`). Use Chrome DevTools Network → Offline and the
Rendering → "Emulate a focused page" toggle / tab switching to simulate suspend.
