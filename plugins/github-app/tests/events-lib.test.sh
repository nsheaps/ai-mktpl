#!/usr/bin/env bash
# events-lib.test.sh — unit tests for plugins/github-app/bin/events-lib.sh
#
# Pure-function tests (no network, no token): exercises the delivery JSON
# shape per eventsDelivery mode and the non-monotonic-id cursor extraction.
#
# Run from anywhere:
#   bash plugins/github-app/tests/events-lib.test.sh

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR_TEST="$(mktemp -d -t github-app-events-lib.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# events-lib.sh derives audit log / state paths from CLAUDE_PLUGIN_DATA at source time.
export CLAUDE_PLUGIN_DATA="$TMPDIR_TEST"
PLUGIN_NAME="github-app"
SCRIPT_DIR="$PLUGIN_ROOT/bin"

# shellcheck source=/dev/null
source "$PLUGIN_ROOT/bin/events-lib.sh"

pass=0; fail=0
ok()  { echo "  ✓ $*"; pass=$((pass + 1)); }
bad() { echo "  ✗ $*"; fail=$((fail + 1)); }

# jqok <json> <filter> <desc>
jqok() { printf '%s' "$1" | jq -e "$2" >/dev/null 2>&1 && ok "$3" || bad "$3 -- json: ${1:0:80}"; }

DISCLAIMER="not every event may be related to your current working task"

echo "== evlib_deliver: sync (SessionStart) JSON shape =="
out="$(evlib_deliver "x" both "hdr" sync SessionStart)"
jqok "$out" '.systemMessage | startswith("'"$DISCLAIMER"'")'                         "both: top-level systemMessage with disclaimer"
jqok "$out" '.hookSpecificOutput.hookEventName == "SessionStart"'                     "both: hookEventName present"
jqok "$out" '.hookSpecificOutput.additionalContext | startswith("'"$DISCLAIMER"'")'   "both: additionalContext present"

out="$(evlib_deliver "x" user "hdr" sync SessionStart)"
jqok "$out" '.systemMessage | startswith("'"$DISCLAIMER"'")'                          "user: systemMessage present"
jqok "$out" 'has("hookSpecificOutput") | not'                                         "user: no hookSpecificOutput"

out="$(evlib_deliver "x" summary "hdr" sync SessionStart)"
jqok "$out" '.systemMessage == "events received from github"'                         "summary: user sees short line"
jqok "$out" '.hookSpecificOutput.additionalContext | startswith("'"$DISCLAIMER"'")'   "summary: Claude sees details"
out="$(evlib_deliver "x" summary "hdr" sync Stop)"
jqok "$out" '.hookSpecificOutput.hookEventName == "Stop"'                              "summary: hookEventName threads through"

out="$(evlib_deliver "x" file "hdr" sync SessionStart)"
[ -z "$out" ] && ok "file: no stdout" || bad "file: stdout leaked"
out="$(evlib_deliver "x" disabled "hdr" sync SessionStart)"
[ -z "$out" ] && ok "disabled: no stdout" || bad "disabled: stdout leaked"

echo "== evlib_deliver: async (rewake) — plain text, no JSON =="
# Run without command-substitution so EVLIB_DELIVERED_TO_CLAUDE survives.
evlib_deliver "x" both "hdr" async UserPromptSubmit > "$TMPDIR_TEST/a.out"
printf '%s' "$(cat "$TMPDIR_TEST/a.out")" | jq -e . >/dev/null 2>&1 && bad "async both: emitted JSON (should be plain)" || ok "async both: plain text (not JSON)"
head -1 "$TMPDIR_TEST/a.out" | grep -q "^$DISCLAIMER" && ok "async both: starts with disclaimer" || bad "async both: missing disclaimer"
[ "$EVLIB_DELIVERED_TO_CLAUDE" = "true" ] && ok "async both: DELIVERED_TO_CLAUDE=true" || bad "async both: flag not set"
evlib_deliver "x" user "hdr" async UserPromptSubmit > "$TMPDIR_TEST/u.out"
{ [ ! -s "$TMPDIR_TEST/u.out" ] && [ "$EVLIB_DELIVERED_TO_CLAUDE" = "false" ]; } && ok "async user: no output, flag=false (no rewake)" || bad "async user: leaked/rewaked"

echo "== evlib_extract_new_events: non-monotonic ids + overflow =="
# Newest-first; note id 100 (newest by order) is LOWER magnitude than 999/998.
EVLIB_RESP='[
  {"id":"100","created_at":"t4","type":"PullRequestReviewEvent","actor":{"login":"a"},"repo":{"name":"o/r"}},
  {"id":"999","created_at":"t3","type":"PushEvent","actor":{"login":"b"},"repo":{"name":"o/r"}},
  {"id":"998","created_at":"t2","type":"PushEvent","actor":{"login":"b"},"repo":{"name":"o/r"}},
  {"id":"50","created_at":"t1","type":"CreateEvent","actor":{"login":"c"},"repo":{"name":"o/r"}}
]'

evlib_extract_new_events "998"
[ "$EVLIB_NEWEST_ID" = "100" ] && ok "newest id tracked by API order (100), not max magnitude" || bad "newest id wrong: $EVLIB_NEWEST_ID"
# Items above index-of(998)=2 are [100,999]; emitted oldest-first => 999 then 100.
got="$(printf '%s' "$EVLIB_NEW_EVENTS" | grep -oE 'id [0-9]+' | tr '\n' ',')"
[ "$got" = "id 999,id 100," ] && ok "new events oldest-first, lower-id newest event included ($got)" || bad "ordering wrong: $got"

evlib_extract_new_events "deadbeef"   # not on page -> overflow branch (// length) -> all, reversed
got="$(printf '%s' "$EVLIB_NEW_EVENTS" | grep -oE 'id [0-9]+' | tr '\n' ',')"
[ "$got" = "id 50,id 998,id 999,id 100," ] && ok "overflow branch (cursor off page) emits whole page oldest-first" || bad "overflow wrong: $got"

EVLIB_RESP='[]'
evlib_extract_new_events "100"
{ [ -z "$EVLIB_NEWEST_ID" ] && [ -z "$EVLIB_NEW_EVENTS" ]; } && ok "empty feed -> empty newest id + events" || bad "empty feed not handled"

echo ""
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
