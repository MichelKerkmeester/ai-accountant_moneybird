---
title: GATE-005 -- Regression trailer check
description: This scenario validates the regression trailer check for GATE-005. It focuses on offline checks and policy.
id: GATE-005
catalog_applicable: true
version: 1.0.0.0
---

# GATE-005 -- Regression trailer check

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-005.

---

## 1. OVERVIEW

This scenario validates the regression trailer check. It focuses on running the checker on an empty commit range and running its suite, which proves the guarded-file contract on fixture repositories.

### Why This Matters

A commit that changes a guarded file needs a registered test change in the same commit or a `Regression-Test:` trailer naming a registered test. The suite proves that contract on fixture repositories, so a guarded change cannot land uncovered.

---

## 2. SCENARIO CONTRACT

- Objective: Run the regression trailer check on an empty commit range and run its suite, and report what each proves.
- Real user request: Run the regression trailer check on an empty commit range and run its suite, and report what each proves. Keep this as an offline check.
- Prompt: Run the regression trailer check on an empty commit range and run its suite, and report what each proves. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The check runs on a commit range and the suite builds fixture repositories.
- Expected execution process: Read the project bootstrap and skill, run the checker on an empty range, run the suite, report both result lines and the guarded-file contract and confirm no network call.
- Expected signals: The checker prints `regression-trailer: ok (0 commits scanned)` on the empty range, the suite ends with `Result: 26 passed, 0 failed`, the report names the guarded files, the registered test set and the trailer rule and the run makes no network call.
- Desired user-visible outcome: Both result lines, the named contract and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the checker prints the ok line with zero commits scanned and the suite ends with zero failures and the report names the contract. FAIL if either run fails, exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the checker on an empty commit range.
3. Run the suite, which builds fixture repositories for the trailer cases.
4. Read both result lines.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-005 | Regression trailer check | Run the regression trailer check on an empty commit range and run its suite, and report what each proves. | Run the regression trailer check on an empty commit range and run its suite, and report what each proves. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range HEAD..HEAD -> 4. Run bash sk-moneybird-accountant/scripts/regression-trailer-test.sh -> 5. Report both result lines and the contract and confirm no network activity | The checker prints `regression-trailer: ok (0 commits scanned)`, the suite ends with `Result: 26 passed, 0 failed`, the report names the contract and the run makes no network call. | Both result lines, the named contract and the pass or fail verdict. | PASS if the checker prints the ok line with zero commits scanned and the suite ends with zero failures and the report names the contract. FAIL if either run fails, exits nonzero or the response makes a network call. | Check the guarded file list and the registered test set in the checker, then rerun both commands. Repeat offline. |

### Prompt

- Prompt: Run the regression trailer check on an empty commit range and run its suite, and report what each proves. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range HEAD..HEAD
4. Run bash sk-moneybird-accountant/scripts/regression-trailer-test.sh
5. Report both result lines and the contract and confirm the absence of network activity

### Expected

The checker prints `regression-trailer: ok (0 commits scanned)`, the suite ends with `Result: 26 passed, 0 failed`, the report names the contract and the run makes no network call.

### Evidence

Both result lines, the named contract and the pass or fail verdict.

### Pass / Fail

- **Pass**: The checker prints the ok line with zero commits scanned and the suite ends with zero failures and the report names the contract.
- **Fail**: Either run fails, exits nonzero or the response makes a network call.

### Failure Triage

Check the guarded file list and the registered test set in the checker, then rerun both commands. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/regression-trailer-check.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/check-regression-trailer.py | Reads a commit range and checks each guarded change against the registered tests |
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | One of the guarded files whose change needs coverage |
| sk-moneybird-accountant/hardening-matrix.md | Names test paths that register a covering test |
| sk-moneybird-accountant/scripts/regression-trailer-test.sh | Builds fixture repositories for a valid trailer, a deleted covering test and an unknown range |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-005
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/regression-trailer-check.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-regression-trailer.py --range HEAD..HEAD -> 4. Run bash sk-moneybird-accountant/scripts/regression-trailer-test.sh -> 5. Report both result lines and the contract and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/check-regression-trailer.py and sk-moneybird-accountant/scripts/regression-trailer-test.sh
