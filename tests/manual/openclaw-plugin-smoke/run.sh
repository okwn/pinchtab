#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../.." && pwd)
SMOKE_DIR="$ROOT_DIR/tests/manual/openclaw-plugin-smoke"
STATE_SOURCE=${OPENCLAW_STATE_SOURCE:-$HOME/.openclaw}
OPENCLAW_VERSION=${OPENCLAW_VERSION:-$(openclaw --version | awk '{print $2}')}
PROJECT_NAME=${PROJECT_NAME:-pinchtab-openclaw-mock-$(date +%s)}
TEMP_STATE=$(mktemp -d /tmp/pinchtab-openclaw-state.XXXXXX)
TEMP_ARTIFACTS=$(mktemp -d /tmp/pinchtab-openclaw-artifacts.XXXXXX)
FINAL_ARTIFACTS_DIR=${FINAL_ARTIFACTS_DIR:-$SMOKE_DIR/artifacts/$(date +%Y%m%d-%H%M%S)}

cleanup() {
  docker compose -p "$PROJECT_NAME" -f "$SMOKE_DIR/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

require_file() {
  local path=$1
  if [[ ! -f "$path" ]]; then
    echo "missing required file: $path" >&2
    exit 1
  fi
}

require_file "$STATE_SOURCE/openclaw.json"
require_file "$STATE_SOURCE/agents/main/agent/auth-profiles.json"

for agent in main alpha beta; do
  mkdir -p "$TEMP_STATE/agents/$agent/agent"
done
cp "$STATE_SOURCE/openclaw.json" "$TEMP_STATE/openclaw.json"
for agent in main alpha beta; do
  cp "$STATE_SOURCE/agents/main/agent/auth-profiles.json" "$TEMP_STATE/agents/$agent/agent/auth-profiles.json"
done
for dir in credentials identity gateway service-env; do
  if [[ -d "$STATE_SOURCE/$dir" ]]; then
    cp -R "$STATE_SOURCE/$dir" "$TEMP_STATE/$dir"
  fi
done

python3 - "$TEMP_STATE/openclaw.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
obj = json.loads(path.read_text())
plugins = obj.setdefault('plugins', {}).setdefault('entries', {})
plugins.setdefault('pinchtab', {})['enabled'] = True
pinchtab_cfg = plugins.setdefault('pinchtab', {}).setdefault('config', {})
pinchtab_cfg['baseUrl'] = 'http://pinchtab:9999'
pinchtab_cfg['token'] = 'smoke-token'
pinchtab_cfg['registerBrowserTool'] = True
plugins.setdefault('browser', {})['enabled'] = False
allow = plugins.get('allow')
if isinstance(allow, list) and 'pinchtab' not in allow:
    allow.append('pinchtab')
obj['browser'] = {'enabled': False}
tools = obj.setdefault('tools', {})
existing = list(tools.get('allow', [])) if isinstance(tools.get('allow'), list) else []
if 'pinchtab' not in existing:
    existing.append('pinchtab')
tools['allow'] = existing
path.write_text(json.dumps(obj, indent=2) + '\n')
PY

mkdir -p "$FINAL_ARTIFACTS_DIR"
export OPENCLAW_STATE_DIR="$TEMP_STATE"
export ARTIFACTS_DIR="$TEMP_ARTIFACTS"
export OPENCLAW_VERSION

echo "running docker mock smoke..."
if ! docker compose -p "$PROJECT_NAME" -f "$SMOKE_DIR/docker-compose.yml" up --build --abort-on-container-exit --exit-code-from openclaw 2>&1 | tee "$TEMP_ARTIFACTS/docker-compose.log"; then
  cp -R "$TEMP_ARTIFACTS/." "$FINAL_ARTIFACTS_DIR/"
  echo
  echo "failed — artifacts copied to $FINAL_ARTIFACTS_DIR" >&2
  exit 1
fi

cp -R "$TEMP_ARTIFACTS/." "$FINAL_ARTIFACTS_DIR/"
echo
echo "ok: artifacts copied to $FINAL_ARTIFACTS_DIR"
cat "$FINAL_ARTIFACTS_DIR/summary.json"
