---
title: GATE-002 -- Eval grader
description: This scenario validates the eval grader for GATE-002. It focuses on offline checks and policy.
id: GATE-002
catalog_applicable: true
version: 1.0.0.0
---

# GATE-002 -- Eval grader

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-002.

---

## 1. OVERVIEW

This scenario validates the eval grader. It focuses on running the grader suite, which builds capture fixtures and proves the assertion and refusal checks on them.

### Why This Matters

The grader decides whether a captured answer meets the assertion block of an eval case. The suite proves that decision on compliant, non-compliant and refusal fixtures, so a grader regression is caught before a real capture is graded.

---

## 2. SCENARIO CONTRACT

- Objective: Run the eval grader suite and report its result and the fixture kinds it proves.
- Real user request: Run the eval grader suite and report its result. Keep this as an offline check.
- Prompt: Run the eval grader suite and report its result. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The suite builds its capture fixtures at run time.
- Expected execution process: Read the project bootstrap and skill, read the eval cases file, run the grader suite, report its result line and the fixture kinds and confirm no network call.
- Expected signals: The suite ends with `Result: 22 passed, 0 failed`, the report names the fixture kinds for a compliant run, a non-compliant answer, a refuse-everything run, another capture year, a forbidden pattern, a negated phrase, an inverting word, a denied refusal marker, a labelled write state, a missed or surplus refusal and a one-byte skill change and the run makes no network call.
- Desired user-visible outcome: The suite result line, the named fixture kinds and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the suite ends with `Result: 22 passed, 0 failed` and the report names the fixture kinds. FAIL if any suite case fails, the suite exits nonzero or the response makes a network or accounting API call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Read the eval cases file for the assertion blocks the grader applies.
3. Run the grader suite.
4. Read the result line and the fixture kinds it proves.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-002 | Eval grader | Run the eval grader suite and report its result and the fixture kinds it proves. | Run the eval grader suite and report its result. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/evals/evals.json -> 4. Run bash sk-moneybird-accountant/scripts/run-evals-test.sh -> 5. Report the suite result line and the fixture kinds and confirm no network activity | The suite ends with `Result: 22 passed, 0 failed` and the report names the fixture kinds, and the run makes no network call. | The suite result line, the named fixture kinds and the pass or fail verdict. | PASS if the suite ends with `Result: 22 passed, 0 failed` and the report names the fixture kinds. FAIL if any suite case fails, the suite exits nonzero or the response makes a network or accounting API call. | Check the eval cases in evals.json and the fixture builders in the suite script, then rerun the suite. Repeat offline. |

### Prompt

- Prompt: Run the eval grader suite and report its result. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/evals/evals.json
4. Run bash sk-moneybird-accountant/scripts/run-evals-test.sh
5. Report the suite result line and the fixture kinds and confirm the absence of network activity

### Expected

The suite ends with `Result: 22 passed, 0 failed` and the report names the fixture kinds, and the run makes no network call.

### Evidence

The suite result line, the named fixture kinds and the pass or fail verdict.

### Pass / Fail

- **Pass**: The suite ends with `Result: 22 passed, 0 failed` and the report names the fixture kinds.
- **Fail**: Any suite case fails, the suite exits nonzero or the response makes a network or accounting API call.

### Failure Triage

Check the eval cases in evals.json and the fixture builders in the suite script, then rerun the suite. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/eval-grader.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/run-evals.py | Grades a capture folder and writes the grading and benchmark files |
| sk-moneybird-accountant/evals/evals.json | Holds the eval cases, their expected routes and their assertion blocks |
| sk-moneybird-accountant/scripts/run-evals-test.sh | Builds the capture fixtures and proves the grader on them |
| sk-moneybird-accountant/ROUTER.md | The routing behavior the eval cases measure |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-002
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/eval-grader.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/evals/evals.json -> 4. Run bash sk-moneybird-accountant/scripts/run-evals-test.sh -> 5. Report the suite result line and the fixture kinds and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/run-evals.py, sk-moneybird-accountant/evals/evals.json and sk-moneybird-accountant/scripts/run-evals-test.sh
