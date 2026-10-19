---
title: GATE-009 -- Write contract check
description: This scenario validates the write contract check for GATE-009. It focuses on offline checks and policy.
id: GATE-009
catalog_applicable: true
version: 1.0.0.0
---

# GATE-009 -- Write contract check

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-009.

---

## 1. OVERVIEW

This scenario validates the write contract check. It focuses on running the checker over the bootstrap and skill files and reporting whether every restatement matches the one canonical contract.

### Why This Matters

The write contract lives in one canonical file and is restated in the bootstrap and the skill files. A restatement that drops a gate token, a rule or an exit code, or that adds one the contract does not own, leaves a writer session following a different contract than the guard enforces.

---

## 2. SCENARIO CONTRACT

- Objective: Run the write contract check and report whether the restatements match the canonical contract.
- Real user request: Run the write contract check and report whether the restatements match the canonical contract. Keep this as an offline check.
- Prompt: Run the write contract check and report whether the restatements match the canonical contract. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The checker runs on the real files.
- Expected execution process: Read the project bootstrap and skill, run the checker over the canonical contract and each restatement, read the ok line and confirm no network call.
- Expected signals: The checker prints `write-contract: ok`, the report names the canonical owner in shared-mechanisms.md and the restatement files AGENTS.md, ROUTER.md, cli-moneybird/SKILL.md and the SKILL.md pointer lines and the run makes no network call.
- Desired user-visible outcome: The ok line, the named contract owner and restatements and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the checker exits 0 and prints `write-contract: ok` and the report names the canonical owner and the restatement files. FAIL if the checker names a drifting file, exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the checker over the canonical contract and each restatement.
3. Read the ok line.
4. Report the canonical owner and the checked restatements.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-009 | Write contract check | Run the write contract check and report whether the restatements match the canonical contract. | Run the write contract check and report whether the restatements match the canonical contract. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/write-contract-check.py -> 4. Report the ok line and the checked restatements and confirm no network activity | The checker prints `write-contract: ok`, the report names the canonical owner and the restatement files and the run makes no network call. | The checker ok line, the named files and the pass or fail verdict. | PASS if the checker exits 0 and prints `write-contract: ok` and the report names the canonical owner and the restatement files. FAIL if the checker names a drifting file, exits nonzero or the response makes a network call. | Check the canonical tokens, rules and exits in shared-mechanisms.md against the file the checker names, then rerun the check. Repeat offline. |

### Prompt

- Prompt: Run the write contract check and report whether the restatements match the canonical contract. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/write-contract-check.py
4. Report the ok line and the checked restatements and confirm the absence of network activity

### Expected

The checker prints `write-contract: ok`, the report names the canonical owner and the restatement files and the run makes no network call.

### Evidence

The checker ok line, the named files and the pass or fail verdict.

### Pass / Fail

- **Pass**: The checker exits 0 and prints `write-contract: ok` and the report names the canonical owner and the restatement files.
- **Fail**: The checker names a drifting file, exits nonzero or the response makes a network call.

### Failure Triage

Check the canonical tokens, rules and exits in shared-mechanisms.md against the file the checker names, then rerun the check. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/write-contract-check.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/write-contract-check.py | Parses the canonical contract and every restatement and fails on drift |
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Owns the canonical gate tokens, exit codes and read-back sentence |
| cli-moneybird/SKILL.md | Holds one restatement of the contract |
| sk-moneybird-accountant/scripts/write-contract-test.sh | Seeds the contract divergences and requires each to fail |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-009
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/write-contract-check.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/write-contract-check.py -> 4. Report the ok line and the checked restatements and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/write-contract-check.py and sk-moneybird-accountant/references/migration/shared-mechanisms.md
