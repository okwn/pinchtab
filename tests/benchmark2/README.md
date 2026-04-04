# PinchTab Benchmark 2 — Initialization & Time-to-First-Result

## Goal

Measure and improve how fast an agent can go from zero context to first
useful browser result. Every token spent on setup is waste; the benchmark
quantifies it and drives improvements.

## What We Measure

### Phase 1 — Skill Loading
- Tokens to load and parse SKILL.md
- Time to identify the right endpoint for a simple task
- Correctness of first API call (no trial-and-error)

### Phase 2 — Server Discovery
- Tokens to confirm server is running and healthy
- Tokens to discover auth requirements
- Time from task start to first successful API call

### Phase 3 — First Navigation
- Tokens to navigate to a URL
- Tokens to extract content from the page
- Round trips needed (ideally 1)

### Phase 4 — First Interaction
- Tokens to identify an interactive element
- Tokens to fill + submit a form
- Verification of result

## Key Metrics

| Metric | Target |
|--------|--------|
| Tokens to first result | < 500 |
| API calls before success | 1 (no retries) |
| Skill-to-action accuracy | 100% correct endpoint first try |
| Setup group token cost | < 200 tokens |

## Optimization Loop

Each run:
1. Run INIT_TASKS.md (agent only — no baseline, init is agent-specific)
2. Record tokens per phase
3. Find the phase with highest token cost
4. Propose 1 improvement to SKILL.md to reduce that cost
5. Commit, repeat

## Files

- `INIT_TASKS.md` — initialization task sequence
- `INIT_BASELINE.md` — explicit reference (what perfect looks like)
- `scripts/` — recording helpers
- `results/` — gitignored run outputs
