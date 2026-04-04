# Benchmark 2 Optimization Cron Task

**Goal: Reduce tokens-to-first-result. Every run should find the most expensive
phase and make SKILL.md easier to scan/use for that phase.**

## Task

### Step 1 — Setup
```bash
cd ~/dev/pinchtab
git checkout feat/benchmark-2 && git pull --rebase origin feat/benchmark-2
```

### Step 2 — Start PinchTab (if not running)
```bash
./pinchtab server &
sleep 5
./pinchtab health
```

### Step 3 — Start Docker fixtures
```bash
cd tests/benchmark && docker compose up -d && cd ../..
```

### Step 4 — Run the initialization benchmark
Read `tests/benchmark2/INIT_TASKS.md`. Work through ALL phases.
Read `skills/pinchtab/SKILL.md` ONCE at the start — no re-reading.
Record tokens per phase with:
```bash
./tests/benchmark2/scripts/record-phase.sh <phase> <step> <pass|fail> <tokens> "notes"
```

### Step 5 — Analyze Results
Identify the highest-cost phase. Ask:
- What in SKILL.md caused extra tokens here?
- Was the right endpoint unclear?
- Did auth discovery require re-reading?
- Was the selector/snapshot guidance confusing?

### Step 6 — One Improvement to SKILL.md
Make exactly 1 change to `skills/pinchtab/SKILL.md`:
- Move critical info (auth, base URL, first endpoint) closer to the top
- Add a "Quick Start — 3 lines" section if none exists
- Compress verbose examples into a tighter format
- Remove content that caused confusion

Commit as: `docs(skill): <what changed and why it reduces init tokens>`

### Step 7 — Log and Push
```bash
cd ~/dev/pinchtab
git add skills/pinchtab/SKILL.md tests/benchmark2/results/
git commit -m "docs(skill): <description>"
git push origin feat/benchmark-2
```

Append to `tests/benchmark2/results/optimization_log.md`:
```markdown
## Run #N — YYYY-MM-DD HH:MM

| Phase | Tokens | Pass |
|-------|--------|------|
| 0 Skill loading | N | ✅/❌ |
| 1 Server discovery | N | ✅/❌ |
| 2 First navigation | N | ✅/❌ |
| 3 First interaction | N | ✅/❌ |
| 4 E2E task | N | ✅/❌ |
| **Total** | **N** | |

**Highest cost phase**: X
**Root cause**: [what caused extra tokens]
**Fix**: [what changed in SKILL.md]
**Commit**: [hash]
```

### Step 8 — Report
```
Benchmark 2 Run #N complete
Phase costs: P0=N P1=N P2=N P3=N P4=N  Total=N
Highest cost: Phase X (N tokens)
Fix: [description] ([commit])
```

## Target Progression

| Run | Total tokens target |
|-----|---------------------|
| 1 | Baseline (measure) |
| 2 | -10% |
| 5 | -30% |
| 10 | < 1500 total |
