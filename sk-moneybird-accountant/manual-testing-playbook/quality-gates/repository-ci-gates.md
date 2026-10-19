---
title: GATE-006 -- Repository CI gates
description: This scenario validates the repository CI gates for GATE-006. It focuses on offline checks and policy.
id: GATE-006
catalog_applicable: true
version: 1.0.0.0
---

# GATE-006 -- Repository CI gates

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-006.

---

## 1. OVERVIEW

This scenario validates the repository CI gates. It focuses on running the suite registration check, which proves every offline suite on disk has a run line in the skill health workflow.

### Why This Matters

A suite that no workflow run line names never executes in CI, so its coverage claim is empty. The registration check compares every suite on disk with the workflow run lines and fails any suite left unregistered.

---

## 2. SCENARIO CONTRACT

- Objective: Run the suite registration check and report whether every offline suite has a run line in the skill health workflow.
- Real user request: Run the suite registration check and report whether every offline suite has a run line in the skill health workflow. Keep this as an offline check.
- Prompt: Run the suite registration check and report whether every offline suite has a run line in the skill health workflow. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The checker reads the real workflow.
- Expected execution process: Read the project bootstrap and skill, run the registration check, read the registered count line, name the three workflows that gate the package and confirm no network call.
- Expected signals: The checker prints `check-ci-suites: ok, 22 suites registered`, the report names the plan kit, privacy and skill health workflows and the run makes no network call.
- Desired user-visible outcome: The registered count line, the named workflows and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the checker exits 0 and prints the registered count line and the report names the three workflows. FAIL if the checker names a missing run line, exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the registration check.
3. Read the registered count line.
4. Name the three workflows that gate the package.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-006 | Repository CI gates | Run the suite registration check and report whether every offline suite has a run line in the skill health workflow. | Run the suite registration check and report whether every offline suite has a run line in the skill health workflow. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-ci-suites.py -> 4. Report the registered count line and the three workflows and confirm no network activity | The checker prints `check-ci-suites: ok, 22 suites registered`, the report names the three workflows and the run makes no network call. | The checker count line, the named workflows and the pass or fail verdict. | PASS if the checker exits 0 and prints the registered count line and the report names the three workflows. FAIL if the checker names a missing run line, exits nonzero or the response makes a network call. | Check the workflow run lines and the suite list the checker compares, then rerun the check. Repeat offline. |

### Prompt

- Prompt: Run the suite registration check and report whether every offline suite has a run line in the skill health workflow. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-ci-suites.py
4. Report the registered count line and the three workflows and confirm the absence of network activity

### Expected

The checker prints `check-ci-suites: ok, 22 suites registered`, the report names the three workflows and the run makes no network call.

### Evidence

The checker count line, the named workflows and the pass or fail verdict.

### Pass / Fail

- **Pass**: The checker exits 0 and prints the registered count line and the report names the three workflows.
- **Fail**: The checker names a missing run line, exits nonzero or the response makes a network call.

### Failure Triage

Check the workflow run lines and the suite list the checker compares, then rerun the check. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/repository-ci-gates.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/check-ci-suites.py | Compares every suite on disk with the skill health workflow run lines |
| .github/workflows/skill-health.yml | Runs the guard, Jortt, routing, reference and gate suites and the monthly link job |
| .github/workflows/plan-kit.yml | Checks the generated kit |
| .github/workflows/privacy-gate.yml | Runs the privacy gate modes and its suite |
| sk-moneybird-accountant/scripts/check-ci-suites-test.sh | Proves the suite registration check on fixture repositories |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-006
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/repository-ci-gates.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-ci-suites.py -> 4. Report the registered count line and the three workflows and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/check-ci-suites.py and .github/workflows/skill-health.yml
