---
title: Hardening matrix check
description: Fails a P0 matrix row whose test path or case name no longer exists.
trigger_phrases:
  - Hardening matrix check
  - check-hardening-matrix.py
  - P0 failure mode
  - test path coverage
  - failure mode and control
version: 1.0.0.0
---

# Hardening matrix check (check-hardening-matrix.py)

## 1. OVERVIEW

Fails a P0 matrix row whose test path or case name no longer exists.

`hardening-matrix.md` holds one row per failure mode with its priority, control, test, owner and status. `scripts/check-hardening-matrix.py` parses that table and verifies every row.

---

## 2. HOW IT WORKS

Every row must name a failure mode, a priority, a control, a test, an owner and a status. A P0 row must name an existing test path as `path :: case name` and the case name must occur in that file as a quoted test name, so a deleted test, a renamed case, a quoted mention on a comment line and a name inside another word fail the check. A test path must stay inside the repository. A path that resolves outside the root, as an absolute path, a `..` segment or a symlink does, fails on any row. A P1 or P2 row may write `-` for no test, and a test it names must exist like a P0 one.

The suite builds fixture copies with a removed P0 test path, a blanked P0 cell, a renamed case, a symlink out of the root, a case name that only sits inside another word and a case name that only sits on a comment line and requires each to fail.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-hardening-matrix.py` | Script | Parses the matrix and checks every row and every named test. |
| `sk-moneybird-accountant/hardening-matrix.md` | Shared | Holds one row per failure mode with its control, test, owner and status. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/hardening-matrix-test.sh` | Automated test | Seeds a removed test path, a blank cell, a renamed case, a symlink out of the root, a case inside another word and a case on a comment line and requires each to fail. |
| `sk-moneybird-accountant/manual-testing-playbook/quality-gates/hardening-matrix-check.md` | Manual playbook | Scenario GATE-004, the matrix check run over the real rows. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the matrix check and the suite on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/hardening-matrix-check.md

Related references:
- [regression-trailer-check.md](regression-trailer-check.md) - Guards the commit that changes the matrix.
- [eval-grader.md](eval-grader.md) - Grades the eval cases the matrix rows name.
