---
title: GATE-008 -- Token budget baseline
description: This scenario validates the token budget baseline for GATE-008. It focuses on offline checks and policy.
id: GATE-008
catalog_applicable: true
version: 1.0.0.0
---

# GATE-008 -- Token budget baseline

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-008.

---

## 1. OVERVIEW

This scenario validates the token budget baseline. It focuses on running the baseline check with the pinned encoding cache and reporting whether the corpus still matches the recorded counts.

### Why This Matters

Every read budget in the route table stands on the recorded token counts. A reference change that moves a budgeted row must fail the check, and a missing or changed encoding data file stops the run instead of downloading anything.

---

## 2. SCENARIO CONTRACT

- Objective: Run the token baseline check with the pinned encoding cache and report whether the corpus still matches the baseline.
- Real user request: Run the token baseline check with the pinned encoding cache and report whether the corpus still matches the baseline. Keep this as an offline check.
- Prompt: Run the token baseline check with the pinned encoding cache and report whether the corpus still matches the baseline. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The check runs on the real corpus.
- Expected execution process: Read the project bootstrap and skill, point `TIKTOKEN_CACHE_DIR` at the pinned cache, run the baseline check, read the ok line and the unit rows and confirm no download.
- Expected signals: The check prints `token-baseline: check ok, 476 files, 1427 sections`, prints one row per named unit, the report names the pinned encodings, the request line of 12,000 `o200k_base` tokens over the three skill files and the run downloads nothing.
- Desired user-visible outcome: The check ok line with its counts, the named pin and request line and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the check exits 0 and prints the ok line with its file and section counts and the report names the pin and the request line. FAIL if the check names a drifted row or an over-line file, exits nonzero or the response downloads an encoding.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Point `TIKTOKEN_CACHE_DIR` at the pinned encoding cache.
3. Run the baseline check.
4. Read the ok line and the per-unit rows.
5. Record a concise verdict and evidence without a download.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-008 | Token budget baseline | Run the token baseline check with the pinned encoding cache and report whether the corpus still matches the baseline. | Run the token baseline check with the pinned encoding cache and report whether the corpus still matches the baseline. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Point TIKTOKEN_CACHE_DIR at the pinned encoding cache -> 4. Run python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check -> 5. Report the ok line and the unit rows and confirm no download | The check prints `token-baseline: check ok, 476 files, 1427 sections` with one row per named unit, the report names the pin and the request line and the run downloads nothing. | The check ok line, the named pin and request line and the pass or fail verdict. | PASS if the check exits 0 and prints the ok line with its file and section counts and the report names the pin and the request line. FAIL if the check names a drifted row or an over-line file, exits nonzero or the response downloads an encoding. | Check TIKTOKEN_CACHE_DIR against the pinned cache files and the baseline file row the check names, then rerun the check. Repeat offline. |

### Prompt

- Prompt: Run the token baseline check with the pinned encoding cache and report whether the corpus still matches the baseline. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Point TIKTOKEN_CACHE_DIR at the pinned encoding cache
4. Run python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check
5. Report the ok line and the unit rows and confirm the absence of a download

### Expected

The check prints `token-baseline: check ok, 476 files, 1427 sections` with one row per named unit, the report names the pin and the request line and the run downloads nothing.

### Evidence

The check ok line, the named pin and request line and the pass or fail verdict.

### Pass / Fail

- **Pass**: The check exits 0 and prints the ok line with its file and section counts and the report names the pin and the request line.
- **Fail**: The check names a drifted row or an over-line file, exits nonzero or the response downloads an encoding.

### Failure Triage

Check TIKTOKEN_CACHE_DIR against the pinned cache files and the baseline file row the check names, then rerun the check. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/token-budget-baseline.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/token-baseline.py | Counts every reference file, the corpus total and the three request files and checks the pinned baseline |
| sk-moneybird-accountant/benchmark/token-baseline.json | Holds the pinned counts without a timestamp |
| sk-moneybird-accountant/ROUTER.md | States the read budget ladder the table rows use |
| sk-moneybird-accountant/scripts/token-canary-test.sh | Runs a swapped-encoding mutant, a router grown past the request line and a baseline gone stale |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-008
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/token-budget-baseline.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Point TIKTOKEN_CACHE_DIR at the pinned encoding cache -> 4. Run python3 -I sk-moneybird-accountant/scripts/token-baseline.py --check -> 5. Report the ok line and the unit rows and confirm no download

**Expected resources:** sk-moneybird-accountant/scripts/token-baseline.py and sk-moneybird-accountant/benchmark/token-baseline.json
