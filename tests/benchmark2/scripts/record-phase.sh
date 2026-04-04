#!/bin/bash
# Record a benchmark 2 phase result
# Usage: ./record-phase.sh <phase> <step> <pass|fail> <tokens> "notes"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../results"
mkdir -p "${RESULTS_DIR}"

REPORT=$(ls -t "${RESULTS_DIR}"/init_run_*.json 2>/dev/null | head -1)
if [[ -z "${REPORT}" ]]; then
  echo "ERROR: No report file found. Initialize with init-run.sh first."
  exit 1
fi

PHASE="$1"; STEP="$2"; STATUS="$3"; TOKENS="$4"; NOTES="${5:-}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

ENTRY=$(cat << EOF
{
  "phase": ${PHASE},
  "step": ${STEP},
  "id": "P${PHASE}.${STEP}",
  "status": "${STATUS}",
  "tokens": ${TOKENS},
  "notes": "${NOTES}",
  "timestamp": "${TIMESTAMP}"
}
EOF
)

TMP=$(mktemp)
jq --argjson e "${ENTRY}" '
  .steps += [$e] |
  .totals.tokens += $e.tokens |
  if $e.status == "pass" then .totals.passed += 1 else .totals.failed += 1 end
' "${REPORT}" > "${TMP}" && mv "${TMP}" "${REPORT}"

echo "Recorded: P${PHASE}.${STEP} = ${STATUS} (${TOKENS} tokens)"
