#!/bin/bash
# network-retain-body.sh — retained network response body smoke.

GROUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${GROUP_DIR}/../../helpers/api.sh"

start_test "network detail: retained response body"

pt_post /navigate -d "{\"url\":\"${FIXTURES_URL}/network-retain-body.html\"}"
assert_ok "navigate to retention fixture"

# Give the fixture fetch a moment to complete and land in the network buffer.
sleep 1

NETWORK_JSON=$(e2e_curl -s "${E2E_SERVER}/network?type=XHR&limit=20")
REQ_ID=$(echo "$NETWORK_JSON" | jq -r '.items[] | select(.url | contains("network-retain-body.json")) | .requestId' | head -n1)
if [ -z "$REQ_ID" ] || [ "$REQ_ID" = "null" ]; then
  echo -e "  ${RED}✗${NC} could not find retained-body request in network buffer"
  ((ASSERTIONS_FAILED++)) || true
  end_test
  exit 0
fi

echo -e "  ${GREEN}✓${NC} found request id: $REQ_ID"
((ASSERTIONS_PASSED++)) || true

DETAIL=$(e2e_curl -s "${E2E_SERVER}/network/${REQ_ID}?body=true")

echo "$DETAIL" | jq -e '.bodyRetained == true' >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓${NC} bodyRetained=true"
  ((ASSERTIONS_PASSED++)) || true
else
  echo -e "  ${RED}✗${NC} expected bodyRetained=true"
  echo "$DETAIL" | jq .
  ((ASSERTIONS_FAILED++)) || true
fi

echo "$DETAIL" | jq -e '.responseBody | contains("retained-body-ok")' >/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}✓${NC} retained response body contains expected payload"
  ((ASSERTIONS_PASSED++)) || true
else
  echo -e "  ${RED}✗${NC} retained response body missing expected payload"
  echo "$DETAIL" | jq .
  ((ASSERTIONS_FAILED++)) || true
fi

end_test
