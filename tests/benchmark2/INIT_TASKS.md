# Initialization Benchmark Tasks

These tasks measure how efficiently an agent can initialize and start using
PinchTab from scratch. Record tokens for EACH phase separately.

## Recording

```bash
./scripts/record-phase.sh <phase> <step> <pass|fail> <tokens> "notes"
```

## Environment

- PinchTab: `http://localhost:9867`
- Token: from `pinchtab config token` or `~/.pinchtab/config.json`
- Fixtures: `http://fixtures/` (Docker) or any stable URL

---

## Phase 0: Skill Loading

### 0.1 Load the skill
Read `skills/pinchtab/SKILL.md`.

Record how many tokens it took to load and understand:
- What the server URL looks like
- How auth works
- What the first action should be for a simple task

**Pass if**: You can answer these 3 questions without re-reading the skill:
1. How do you authenticate? (Bearer token header)
2. What endpoint navigates to a URL? (`POST /navigate`)
3. How do you read page content? (`GET /text` or `GET /snapshot`)

---

## Phase 1: Server Discovery

### 1.1 Check server health
Without reading any docs — just from the skill — check that the server is
running and get the auth token.

**Pass if**: Got a 200 health response on first try (no retries, no wrong URL).

### 1.2 Confirm auth works
Make one authenticated request that confirms your token is valid.

**Pass if**: Request succeeds on first attempt.

---

## Phase 2: First Navigation

### 2.1 Navigate to a page
Navigate to `http://fixtures/` (or `https://example.com` if fixtures unavailable).

**Pass if**: Navigation succeeds, tabId returned.

### 2.2 Get page content
Extract text or snapshot from the current page.

**Pass if**: Content returned on first attempt, chose the right endpoint
(`/text` for prose, `/snapshot` for structure).

---

## Phase 3: First Interaction

### 3.1 Find an interactive element
Navigate to `http://fixtures/search.html` and find the search input
without trial and error.

**Pass if**: Identified the correct selector on first snapshot.

### 3.2 Fill and submit
Fill the search field with "artificial intelligence" and click the button.

**Pass if**: Correct sequence: fill → click button (not press Enter).
No retries needed.

### 3.3 Verify result
Confirm the search result appeared.

**Pass if**: Verification string found on first text/snapshot call.

---

## Phase 4: End-to-End Efficiency

### 4.1 Complete a task from natural language
Given only this instruction:
> "Go to http://fixtures/form.html, fill in name=Benchmark, email=bench@test.com, submit the form, confirm it worked."

Complete the task and count:
- Total tokens used
- Number of API calls
- Any retries or wrong turns

**Pass if**: Task completed with ≤ 8 API calls and ≤ 2000 tokens.
**Ideal**: ≤ 5 API calls, ≤ 1000 tokens.

---

## Scoring

| Phase | Max tokens | Actual | Score |
|-------|-----------|--------|-------|
| 0 Skill loading | 300 | | |
| 1 Server discovery | 100 | | |
| 2 First navigation | 200 | | |
| 3 First interaction | 400 | | |
| 4 E2E task | 1000 | | |
| **Total** | **2000** | | |

Score = max_tokens / actual_tokens (higher is better, 1.0 = perfect).

## What "improvement" looks like

After each run, the optimization loop looks at the highest-cost phase and
asks: "What in SKILL.md caused extra tokens here?" Then proposes one fix:

- Phase 0 high cost → skill is too long / hard to scan
- Phase 1 high cost → auth/URL discovery is buried
- Phase 2 high cost → wrong endpoint chosen first
- Phase 3 high cost → selector discovery requires multiple snapshots
- Phase 4 high cost → multi-step flow guidance is unclear
