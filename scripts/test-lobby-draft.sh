#!/usr/bin/env bash
# Full integration test: readiness toggle, start draft, nomination, bidding, complete bid
# Run with: bash scripts/test-lobby-draft.sh
ANON="sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
BASE="http://127.0.0.1:54321"
PSQL="PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres"

OK=0; FAIL=0
pass() { echo "  ✓ $1"; OK=$((OK+1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
section() { echo ""; echo "=== $1 ==="; }
jq_ok() { echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('ok') else 1)" 2>/dev/null; }
jq_val() { echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print($2)" 2>/dev/null; }
db() { eval "$PSQL -At -c \"$1\"" 2>/dev/null | head -1 | tr -d '\n '; }

section "1. Create auction with two teams"
AUTH=$(curl -s -X POST "$BASE/auth/v1/signup" -H "Content-Type: application/json" -H "apikey: $ANON" -d '{}')
SUID=$(echo "$AUTH" | python3 -c "
import sys,json,base64; d=json.load(sys.stdin)
tok=d['access_token'].split('.')[1]; tok+='=='*(-len(tok)%4)
print(json.loads(base64.urlsafe_b64decode(tok))['sub'])")

AUCTION=$(curl -s -X POST "$BASE/functions/v1/create-auction" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_name\":\"Test Draft\",\"join_code\":\"TSTDR2\",\"participant_count\":2,\"budget\":200,\"creator_name\":\"Admin\",\"school_source\":\"default\",\"roster_positions\":[{\"position_name\":\"SEC\",\"slots_per_team\":1,\"is_flex\":false,\"display_order\":1,\"color_code\":\"#DC2626\"},{\"position_name\":\"Flex\",\"slots_per_team\":1,\"is_flex\":true,\"display_order\":2,\"color_code\":\"#6B7280\"}],\"supabase_uid\":\"$SUID\"}")

if jq_ok "$AUCTION"; then
  AID=$(jq_val "$AUCTION" "d['auction_id']")
  TID1=$(jq_val "$AUCTION" "d['team_id']")
  PID1=$(jq_val "$AUCTION" "d['participant_id']")
  TOK1=$(jq_val "$AUCTION" "d['session_token']")
  pass "Created auction $AID (admin: team=$TID1 participant=$PID1)"
else
  fail "create-auction failed: $AUCTION"; exit 1
fi

# Insert second participant directly via DB (simulates join flow)
TID2=$(db "SELECT id FROM teams WHERE auction_id=$AID AND id != $TID1 LIMIT 1;")
TOK2=$(python3 -c "import uuid; print(uuid.uuid4())")
PID2=$(db "INSERT INTO participants (auction_id, display_name, role, team_id, session_token, is_connected) VALUES ($AID, 'Coach2', 'team_coach', $TID2, '$TOK2', true) RETURNING id;")
pass "Second participant $PID2 joined (team=$TID2)"

section "2. Readiness toggle"
RDY=$(curl -s -X PATCH "$BASE/rest/v1/participants?id=eq.$PID2" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -H "x-session-token: $TOK2" -H "Prefer: return=representation" \
  -d '{"is_ready":true}')
IS_READY=$(jq_val "$RDY" "d[0]['is_ready']")
[ "$IS_READY" = "True" ] && pass "is_ready toggled to true" || fail "Ready toggle failed: $RDY"

RDY2=$(curl -s -X PATCH "$BASE/rest/v1/participants?id=eq.$PID2" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -H "x-session-token: $TOK2" -H "Prefer: return=representation" \
  -d '{"is_ready":false}')
IS_READY2=$(jq_val "$RDY2" "d[0]['is_ready']")
[ "$IS_READY2" = "False" ] && pass "is_ready toggled back to false" || fail "Toggle back failed"

section "3. Start draft (status + first nominator)"
# Simulate what startDraft does: set status + current_nominator_id = participant with team nomination_order=1
FIRST_TEAM=$(db "SELECT id FROM teams WHERE auction_id=$AID ORDER BY nomination_order LIMIT 1;")
FIRST_NOM=$(db "SELECT id FROM participants WHERE auction_id=$AID AND team_id=$FIRST_TEAM LIMIT 1;")
echo "  first_team=$FIRST_TEAM first_nominator=$FIRST_NOM"

DRAFT_START=$(curl -s -X PATCH "$BASE/rest/v1/auctions?id=eq.$AID" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -H "Prefer: return=representation" \
  -d "{\"status\":\"in_progress\",\"current_nominator_id\":$FIRST_NOM}")
STATUS=$(jq_val "$DRAFT_START" "d[0]['status']")
NOM_ID=$(jq_val "$DRAFT_START" "d[0]['current_nominator_id']")
[ "$STATUS" = "in_progress" ] && pass "Auction status=in_progress" || fail "Status update failed: $DRAFT_START"
[ "$NOM_ID" = "$FIRST_NOM" ] && pass "current_nominator_id=$NOM_ID set correctly" || fail "Nominator not set: $NOM_ID"

section "4. Nominate school (correct nominator)"
SCHOOL_ID=$(db "SELECT id FROM auction_schools WHERE auction_id=$AID ORDER BY id LIMIT 1;")
SCHOOL_NAME=$(db "SELECT s.name FROM auction_schools a JOIN schools s ON s.id=a.school_id WHERE a.id=$SCHOOL_ID;")
echo "  nominating: $SCHOOL_NAME (id=$SCHOOL_ID)"

NOM=$(curl -s -X POST "$BASE/functions/v1/nominate-school" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_id\":$AID,\"participant_id\":$FIRST_NOM,\"team_id\":$FIRST_TEAM,\"auction_school_id\":$SCHOOL_ID}")
jq_ok "$NOM" && pass "School nominated successfully" || fail "Nomination failed: $NOM"

# Wrong nominator should be rejected
WRONG_NOM=$(curl -s -X POST "$BASE/functions/v1/nominate-school" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_id\":$AID,\"participant_id\":$PID2,\"team_id\":$TID2,\"auction_school_id\":$SCHOOL_ID}")
jq_ok "$WRONG_NOM" && fail "Should have rejected wrong nominator" || pass "Wrong nominator correctly rejected"

section "5. Place bids"
BID1=$(curl -s -X POST "$BASE/functions/v1/place-bid" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_id\":$AID,\"participant_id\":$PID1,\"team_id\":$TID1,\"amount\":10}")
jq_ok "$BID1" && pass "Bid \$10 accepted" || fail "Bid failed: $BID1"
HIGH=$(db "SELECT current_high_bid FROM auctions WHERE id=$AID;")
[ "$HIGH" = "10.00" ] && pass "Auction shows high_bid=10.00" || fail "high_bid wrong: $HIGH"

LOW=$(curl -s -X POST "$BASE/functions/v1/place-bid" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_id\":$AID,\"participant_id\":$PID2,\"team_id\":$TID2,\"amount\":5}")
jq_ok "$LOW" && fail "Low bid should be rejected" || pass "Low bid correctly rejected"

BID2=$(curl -s -X POST "$BASE/functions/v1/place-bid" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_id\":$AID,\"participant_id\":$PID2,\"team_id\":$TID2,\"amount\":20}")
jq_ok "$BID2" && pass "Bid \$20 accepted (team2 outbids)" || fail "Bid failed: $BID2"

section "6. Team 1 passes → triggers complete-bid (only 2 teams, team2 is high bidder)"
PASS1=$(curl -s -X POST "$BASE/functions/v1/pass-bid" \
  -H "Content-Type: application/json" -H "apikey: $ANON" \
  -d "{\"auction_id\":$AID,\"participant_id\":$PID1,\"team_id\":$TID1}")
COMPLETED=$(jq_val "$PASS1" "str(d.get('completed',False))")
echo "  pass result: $PASS1"
[ "$COMPLETED" = "True" ] && pass "Bid auto-completed on last pass" || fail "Expected auto-complete: $PASS1"

section "7. Verify results"
PICK=$(db "SELECT team_id, winning_bid FROM draft_picks WHERE auction_id=$AID;")
BUDGET=$(db "SELECT remaining_budget FROM teams WHERE id=$TID2;")
AVAIL=$(db "SELECT is_available FROM auction_schools WHERE id=$SCHOOL_ID;")
NEXT_NOM=$(db "SELECT current_nominator_id FROM auctions WHERE id=$AID;")

[ -n "$PICK" ] && pass "Draft pick recorded: $PICK" || fail "No draft pick found"
[ "$BUDGET" = "180.00" ] && pass "Team2 budget deducted (200-20=180)" || fail "Budget wrong: $BUDGET"
[ "$AVAIL" = "f" ] && pass "School marked unavailable" || fail "School still available"
[ "$NEXT_NOM" != "$FIRST_NOM" ] && pass "Nominator advanced to next team" || fail "Nominator not advanced: $NEXT_NOM"

echo ""
echo "Results: $OK passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "ALL TESTS PASSED" || exit 1
