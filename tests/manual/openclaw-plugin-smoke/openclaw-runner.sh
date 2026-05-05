#!/usr/bin/env bash
set -euo pipefail

: "${PINCHTAB_BASE_URL:?missing PINCHTAB_BASE_URL}"
: "${PINCHTAB_TOKEN:?missing PINCHTAB_TOKEN}"
: "${FIXTURES_URL:?missing FIXTURES_URL}"

node /workspace/plugin/scripts/sync-skills.mjs

openclaw plugins install /workspace/plugin --link >/artifacts/plugin-install.log 2>&1

(openclaw gateway >/artifacts/gateway.log 2>&1) &
GW_PID=$!
cleanup() {
  kill "$GW_PID" >/dev/null 2>&1 || true
  wait "$GW_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 45); do
  if openclaw health >/artifacts/health.json 2>/artifacts/health.err; then
    break
  fi
  sleep 2
done
openclaw health >/artifacts/health.json 2>/artifacts/health.err

python3 <<'PY'
import json
import subprocess
from pathlib import Path

artifacts = Path('/artifacts')
fixtures_url = 'http://fixtures:8080'
scenarios = [
    {
        'id': 'alpha',
        'agent': 'main',
        'prompt': f'Use the pinchtab tool to navigate to {fixtures_url}/alpha and reply with only the verification code on the page.',
        'expected': 'ALPHA-17',
        'paths': ['/alpha'],
        'requiredTool': 'pinchtab',
    },
    {
        'id': 'journey',
        'agent': 'main',
        'prompt': f'Use the pinchtab tool to navigate to {fixtures_url}/journey/start, click the Begin journey button, wait for the next page, and reply with only the final verification code.',
        'expected': 'ORBIT-42',
        'paths': ['/journey/start', '/journey/final'],
        'requiredTool': 'pinchtab',
    },
    {
        'id': 'chain',
        'agent': 'main',
        'prompt': f'Use the pinchtab tool to navigate to {fixtures_url}/chain/one, click through until you reach the last page, and reply with only the full final verification code.',
        'expected': 'BLUE-SUN-9',
        'paths': ['/chain/one', '/chain/two', '/chain/final'],
        'requiredTool': 'pinchtab',
    },
    {
        'id': 'browser-alias',
        'agent': 'main',
        'prompt': f'Use the browser tool to navigate to {fixtures_url}/alpha and reply with only the verification code on the page.',
        'expected': 'ALPHA-17',
        'paths': ['/alpha'],
        'requiredTool': 'browser',
    },
]

session_scenarios = [
    {
        'id': 'agent-alpha-start',
        'agent': 'alpha',
        'prompt': f'Use the pinchtab tool to navigate to {fixtures_url}/journey/start, click the Begin journey button, wait for the next page to load, and reply with only READY.',
        'expected': 'READY',
        'paths': ['/journey/start', '/journey/final'],
        'requiredTool': 'pinchtab',
    },
    {
        'id': 'agent-alpha-reuse',
        'agent': 'alpha',
        'prompt': f'Use the pinchtab tool to continue the existing browser session for this agent, navigate to {fixtures_url}/journey/final, and reply with only the verification code on the page.',
        'expected': 'ORBIT-42',
        'paths': ['/journey/final'],
        'requiredTool': 'pinchtab',
    },
    {
        'id': 'agent-beta-isolated',
        'agent': 'beta',
        'prompt': f'Use the pinchtab tool to continue the existing browser session for this agent, navigate to {fixtures_url}/journey/final, and reply with only the verification code on the page.',
        'expected': 'MISSING-STATE',
        'paths': ['/journey/final'],
        'requiredTool': 'pinchtab',
    },
]

def run_agent_scenario(scenario):
    out_path = artifacts / f"agent-{scenario['id']}.json"
    cmd = [
        'openclaw', 'agent',
        '--agent', scenario['agent'],
        '--message', scenario['prompt'],
        '--json',
        '--timeout', '240',
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit(f"agent command failed for {scenario['id']}:\nSTDOUT:\n{completed.stdout}\nSTDERR:\n{completed.stderr}")
    out_path.write_text(completed.stdout)
    payload = json.loads(completed.stdout)
    text = payload['result']['payloads'][0]['text'].strip()
    tool_summary = payload['result']['meta'].get('toolSummary', {})
    tools_used = tool_summary.get('tools', []) or []
    return {
        'id': scenario['id'],
        'agent': scenario['agent'],
        'expected': scenario['expected'],
        'actual': text,
        'ok': text == scenario['expected'],
        'paths': scenario['paths'],
        'requiredTool': scenario['requiredTool'],
        'toolsUsed': tools_used,
        'toolOk': scenario['requiredTool'] in tools_used,
    }

results = [run_agent_scenario(scenario) for scenario in scenarios]
session_results = [run_agent_scenario(scenario) for scenario in session_scenarios]

log_path = artifacts / 'fixtures-access.log'
entries = []
if log_path.exists():
    for line in log_path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        entries.append(json.loads(line))

pinchtab_log = (artifacts / 'pinchtab.log').read_text() if (artifacts / 'pinchtab.log').exists() else ''
pinchtab_api_lines = [
    line for line in pinchtab_log.splitlines()
    if 'path=/health' not in line and ' path=/' in line
]

for result in results + session_results:
    missing = []
    for path in result['paths']:
        hits = [
            entry for entry in entries
            if entry.get('path', '').split('?', 1)[0] == path
        ]
        if not hits:
            missing.append(path)
    result['fixtureLogOk'] = not missing
    result['missingFixturePaths'] = missing

session_proof = {
    'ok': all(r['ok'] and r['toolOk'] and r['fixtureLogOk'] for r in session_results),
    'sameAgentReuse': next(r for r in session_results if r['id'] == 'agent-alpha-reuse'),
    'crossAgentIsolation': next(r for r in session_results if r['id'] == 'agent-beta-isolated'),
}

summary = {
    'ok': all(r['ok'] and r['fixtureLogOk'] and r['toolOk'] for r in results) and session_proof['ok'] and bool(pinchtab_api_lines),
    'results': results,
    'sessionProof': session_proof,
    'sessionScenarios': session_results,
    'logEntries': len(entries),
    'pinchtabApiCallCount': len(pinchtab_api_lines),
    'pinchtabApiSample': pinchtab_api_lines[:10],
}
(artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
if not summary['ok']:
    raise SystemExit('mock smoke verification failed')
PY
