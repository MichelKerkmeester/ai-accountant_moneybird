---
title: GATE-004 -- Hardening matrix check
description: This scenario validates the hardening matrix check for GATE-004. It focuses on offline checks and policy.
id: GATE-004
catalog_applicable: true
version: 1.0.0.0
---

# GATE-004 -- Hardening matrix check

This document captures the offline prompt, local read sequence, expected signals and evidence for GATE-004.

---

## 1. OVERVIEW

This scenario validates the hardening matrix check. It focuses on running the checker over the matrix and reporting whether every P0 row still names a test path and case name that exist.

### Why This Matters

The matrix claims a test for every failure mode. A deleted test, a renamed case or a path that escapes the repository would leave a P0 row pointing at nothing. The checker parses every row so the claim is verified instead of asserted.

---

## 2. SCENARIO CONTRACT

- Objective: Run the hardening matrix check and report whether every P0 row still names a test that exists.
- Real user request: Run the hardening matrix check and report whether every P0 row still names a test that exists. Keep this as an offline check.
- Prompt: Run the hardening matrix check and report whether every P0 row still names a test that exists. Keep this as an offline check.
- Fixture rows: none in routing-gold.json. The checker runs on the real matrix.
- Expected execution process: Read the project bootstrap and skill, run the checker over the matrix, read the ok line and confirm no network call.
- Expected signals: The checker prints `hardening-matrix: ok (27 rows, 21 P0 rows)`, the report names the path and case name contract a P0 row must meet, the quoted-name rule and the inside-root rule and the run makes no network call.
- Desired user-visible outcome: The ok line with its row counts, the named contract and a clear PASS or FAIL verdict.
- Pass/fail: PASS if the checker exits 0 and prints the ok line with its row counts and the report names the P0 contract. FAIL if the checker names a failing row, exits nonzero or the response makes a network call.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Run the checker over the matrix.
3. Read the ok line and its row counts.
4. Report the contract a P0 row must meet.
5. Record a concise verdict and evidence without a network call.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| GATE-004 | Hardening matrix check | Run the hardening matrix check and report whether every P0 row still names a test that exists. | Run the hardening matrix check and report whether every P0 row still names a test that exists. Keep this as an offline check. | 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py -> 4. Report the ok line and the P0 contract and confirm no network activity | The checker prints `hardening-matrix: ok (27 rows, 21 P0 rows)`, the report names the P0 contract and the inside-root rule and the run makes no network call. | The checker ok line, the named contract and the pass or fail verdict. | PASS if the checker exits 0 and prints the ok line with its row counts and the report names the P0 contract. FAIL if the checker names a failing row, exits nonzero or the response makes a network call. | Check the row and the test path the checker names, then rerun the checker. Repeat offline. |

### Prompt

- Prompt: Run the hardening matrix check and report whether every P0 row still names a test that exists. Keep this as an offline check.

### Commands

1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md
2. Read sk-moneybird-accountant/SKILL.md
3. Run python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py
4. Report the ok line and the P0 contract and confirm the absence of network activity

### Expected

The checker prints `hardening-matrix: ok (27 rows, 21 P0 rows)`, the report names the P0 contract and the inside-root rule and the run makes no network call.

### Evidence

The checker ok line, the named contract and the pass or fail verdict.

### Pass / Fail

- **Pass**: The checker exits 0 and prints the ok line with its row counts and the report names the P0 contract.
- **Fail**: The checker names a failing row, exits nonzero or the response makes a network call.

### Failure Triage

Check the row and the test path the checker names, then rerun the checker. Repeat offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/quality-gates/hardening-matrix-check.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/scripts/check-hardening-matrix.py | Parses the matrix and checks every row and every named test |
| sk-moneybird-accountant/hardening-matrix.md | Holds one row per failure mode with its control, test, owner and status |
| sk-moneybird-accountant/scripts/hardening-matrix-test.sh | Proves the matrix check on seeded fixture copies |

---

## 5. SOURCE METADATA

- Group: quality-gates
- Playbook ID: GATE-004
- Canonical root source: manual-testing-playbook.md
- Feature file path: quality-gates/hardening-matrix-check.md

**Exact command sequence:** 1. Read AGENTS.md, the hub SKILL.md and sk-moneybird-accountant/ROUTER.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Run python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py -> 4. Report the ok line and the P0 contract and confirm no network activity

**Expected resources:** sk-moneybird-accountant/scripts/check-hardening-matrix.py and sk-moneybird-accountant/hardening-matrix.md
