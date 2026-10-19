---
title: GATE-007 -- Route replay harness
description: This scenario validates the route replay harness for GATE-007. It focuses on offline checks and policy.
id: GATE-007
catalog_applicable: true
version: 1.0.0.0
---

# GATE-007 -- Route replay harness

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-007.

---

## 1. OVERVIEW

This scenario validates the route replay harness. It focuses on running the replay suite with the pinned encoding cache, which proves both harness modes on a temp copy of the skill.

### Why This Matters

The harness scores the routing corpus in resolve mode and replays the refusal and hostile rows through the guard and the stub in replay mode. The suite proves a clean corpus passes, each seeded defect turns the right row red and a missing encoding cache stops the run before any download.

---

## 2. SCENARIO CONTRACT

- Objective: Run the route replay suite offline with the pinned encoding cache and report its result and the harness pass lines.
- Real user request: Run the route replay suite offline with the pinned encoding cache and report its result. Keep this as an offline check.
- Prompt: Run the route replay suite offline with the pinned encoding cache and report its result. Keep this as an offline check.
- Fixture rows: none in routing-gold.json as playbook rows. The suite scores the whole routing corpus on a temp copy.
- Expected execution process: Read the project bootstrap and skill, point `TIKTOKEN_CACHE_DIR` at the pinned cache, run the suite, read the result line and the harness pass lines and confirm no network call.
- Expected signals: The suite ends with `Result: 27 passed, 0 failed`, the report names the resolve pass line `route-replay: ok, 445 rows passed` and the replay pass line `route-replay: ok, 31 replay rows passed`, states that a missing cache exits 2 and the run makes no network call.
- Desired user-visible outcome: The suite result line, the two harness pass lines and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the suite ends with `Result: 27 passed, 0 failed` and the report names both harness pass lines and the missing-cache exit. FAIL if any suite case fails, the suite exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Point `TIKTOKEN_CACHE_DIR` at the pinned encoding cache.
3. Run the suite, which copies the skill to a temp root and proves both modes.
4. Read the result line and the harness pass lines.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-007 | Route replay harness | Run the route replay suite offline with the pinned encoding cache and report its result and the harness pass lines. | Run the route replay suite offline with the pinned encoding cache and report its result. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Point TIKTOKEN_CACHE_DIR at the pinned encoding cache -> 4. Run bash sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh -> 5. Report the suite result line and the harness pass lines and confirm no network activity | The suite ends with `Result: 27 passed, 0 failed`, the report names `route-replay: ok, 445 rows passed` and `route-replay: ok, 31 replay rows passed` and the missing-cache exit 2, and the run makes no network call. | The suite result line, the two harness pass lines and the pass or fail verdict. | PASS if the suite ends with `Result: 27 passed, 0 failed` and the report names both harness pass lines and the missing-cache exit. FAIL if any suite case fails, the suite exits nonzero or the response makes a network call. | Check TIKTOKEN_CACHE_DIR against the pinned cache files, then the corpus and the harness modes. Repeat offline. |

### Prompt

- Prompt: Run the route replay suite offline with the pinned encoding cache and report its result. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Point TIKTOKEN_CACHE_DIR at the pinned encoding cache
4. Run bash sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh
5. Report the suite result line and the harness pass lines and confirm the absence of network activity

### Expected

The suite ends with `Result: 27 passed, 0 failed`, the report names `route-replay: ok, 445 rows passed` and `route-replay: ok, 31 replay rows passed` and the missing-cache exit 2, and the run makes no network call.

### Evidence

The suite result line, the two harness pass lines and the pass or fail verdict.

### Pass / Fail

- **Pass**: The suite ends with `Result: 27 passed, 0 failed` and the report names both harness pass lines and the missing-cache exit.
- **Fail**: Any suite case fails, the suite exits nonzero or the response makes a network call.

### Failure Triage

Check TIKTOKEN_CACHE_DIR against the pinned cache files, then the corpus and the harness modes. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/route-replay-harness.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/route-replay/route-replay.py | Reads the route table, scores the corpus and replays the guard rows |
| sk-moneybird-accountant/scripts/route-replay/routing-gold.json | Holds the offline routing scenarios, their twins and their labels |
| sk-moneybird-accountant/references/routing-signals.md | Owns the tie margin, the specificity clauses and the filing grammar the resolver reads |
| sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh | Proves both modes on a temp copy of the skill |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-007
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/route-replay-harness.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Point TIKTOKEN_CACHE_DIR at the pinned encoding cache -> 4. Run bash sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh -> 5. Report the suite result line and the harness pass lines and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/route-replay/route-replay.py, sk-moneybird-accountant/scripts/route-replay/routing-gold.json and sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh
