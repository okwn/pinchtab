# OpenClaw + Pinchtab Docker Mock Test

Deterministic end-to-end harness for the Pinchtab OpenClaw plugin.

What it does:
- builds a local Pinchtab image from this repo
- starts a local fixture server inside Docker
- installs the repo plugin into a fresh OpenClaw container
- disables the bundled OpenClaw browser plugin so `browser` resolves to Pinchtab's compatibility alias
- runs several `openclaw agent` prompts against the fixture site
- verifies the returned answers
- verifies fixture access logs show real browser traffic from Pinchtab
- proves same-agent session reuse and cross-agent isolation with dedicated `alpha` / `beta` smoke turns

## Requirements

- Docker
- valid OpenClaw auth in `~/.openclaw/agents/main/agent/auth-profiles.json`
- a usable `~/.openclaw/openclaw.json`

## Run

```bash
./tests/manual/openclaw-plugin-smoke/run.sh
# or
./dev e2e smoke-plugin
```

Optional overrides:

```bash
OPENCLAW_STATE_SOURCE=$HOME/.openclaw \
OPENCLAW_VERSION=2026.5.2 \
./tests/manual/openclaw-plugin-smoke/run.sh
```

## Artifacts

The script copies results into `tests/manual/openclaw-plugin-smoke/artifacts/<timestamp>/`:

- `summary.json` — scenario results + log checks, including `sessionProof`
- `agent-*.json` — raw OpenClaw CLI output per prompt
- `gateway.log` — OpenClaw gateway log
- `plugin-install.log` — plugin install log
- `fixtures-access.log` — JSONL access log from the fixture server
- `docker-compose.log` — combined compose output

## Why this proves Pinchtab was used

Two layers:

1. The bundled OpenClaw browser plugin is disabled, while the Pinchtab plugin re-registers `browser`.
2. The fixture log must show Chrome/Chromium-style traffic for the exercised pages, including a JS-driven cookie/state flow that plain `web_fetch` cannot satisfy.
