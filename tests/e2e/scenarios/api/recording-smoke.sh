#!/bin/bash
# recording-smoke.sh — Recording smoke tests (API + CLI).

GROUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${GROUP_DIR}/../../helpers/api.sh"

# ─────────────────────────────────────────────────────────────────
start_test "record: status shows inactive"

pt_get /record/status
assert_ok "record status"
assert_json_eq "$RESULT" ".active" "false" "no active recording"

end_test

# ─────────────────────────────────────────────────────────────────
start_test "record: start → status → stop (API gif)"

pt_post /navigate -d "{\"url\":\"${FIXTURES_URL}/index.html\"}"
assert_ok "navigate"

pt_post /record/start -d '{"format":"gif","fps":2,"quality":60}'
assert_ok "record start"
assert_json_eq "$RESULT" ".status" "recording" "recording started"
assert_json_eq "$RESULT" ".format" "gif" "format is gif"

sleep 2

pt_get /record/status
assert_ok "record status"
assert_json_eq "$RESULT" ".active" "true" "recording active"

OUTFILE="/tmp/e2e-recording-test.gif"
e2e_curl -s -X POST "${E2E_SERVER}/record/stop" -o "$OUTFILE" \
  -H "Content-Type: application/json" -d '{}'
FILESIZE=$(wc -c < "$OUTFILE" 2>/dev/null | tr -d ' ')

if [ -f "$OUTFILE" ] && [ "$FILESIZE" -gt 0 ]; then
  pass_assert "recording file created ($FILESIZE bytes)"
else
  fail_assert "recording file missing or empty"
fi
rm -f "$OUTFILE"

pt_get /record/status
assert_ok "record status after stop"
assert_json_eq "$RESULT" ".active" "false" "recording inactive after stop"

end_test

# ─────────────────────────────────────────────────────────────────
start_test "record: stop without start returns 400"

pt_post /record/stop -d '{}'
assert_http_status 400 "stop without active recording"

end_test

# ─────────────────────────────────────────────────────────────────
start_test "record: CLI start → stop roundtrip"

rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/pinchtab/current-recording" 2>/dev/null || true
rm -f /tmp/pinchtab-current-recording 2>/dev/null || true

CLI_OUTFILE="/tmp/e2e-cli-recording.gif"

pt_post /navigate -d "{\"url\":\"${FIXTURES_URL}/index.html\"}"
assert_ok "navigate for CLI recording"

e2e_curl -s -X POST "${E2E_SERVER}/record/start" \
  -H "Content-Type: application/json" \
  -d '{"format":"gif","fps":2,"quality":60}' > /dev/null
sleep 2
e2e_curl -s -X POST "${E2E_SERVER}/record/stop" -o "$CLI_OUTFILE" \
  -H "Content-Type: application/json" -d '{}'
FILESIZE=$(wc -c < "$CLI_OUTFILE" 2>/dev/null | tr -d ' ')

if [ -f "$CLI_OUTFILE" ] && [ "$FILESIZE" -gt 0 ]; then
  pass_assert "CLI recording file created ($FILESIZE bytes)"
else
  fail_assert "CLI recording file missing or empty"
fi
rm -f "$CLI_OUTFILE"

end_test
