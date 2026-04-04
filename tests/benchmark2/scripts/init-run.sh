#!/bin/bash
# Initialize a new benchmark 2 run report
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../results"
mkdir -p "${RESULTS_DIR}"

RUN_NUMBER=$(ls "${RESULTS_DIR}"/init_run_*.json 2>/dev/null | wc -l | tr -d ' ')
RUN_NUMBER=$((RUN_NUMBER + 1))
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="${RESULTS_DIR}/init_run_${TIMESTAMP}.json"

cat > "${REPORT}" << EOF
{
  "benchmark": {
    "name": "benchmark-2-init",
    "run_number": ${RUN_NUMBER},
    "timestamp": "${TIMESTAMP}",
    "goal": "minimize tokens-to-first-result"
  },
  "totals": { "tokens": 0, "passed": 0, "failed": 0 },
  "steps": []
}
EOF

echo "Run #${RUN_NUMBER} initialized: ${REPORT}"
echo "TIMESTAMP=${TIMESTAMP}"
