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

`hardening-matrix.md` holds one row per failure mode with its priority, control, test, owner and status. `scripts/check-hardening-matrix.py --check` parses that table and verifies every row.

---

## 2. HOW IT WORKS

Every row must name a failure mode, a priority, a control, a test, an owner and a status. A P0 row must name an existing test path as `path :: case name` and the case name must occur in that file as a quoted test name, so a deleted test, a renamed case, a quoted mention on a comment line or after a trailing `#` or `//` comment, also one that starts right after a shell operator such as `)` or `&&`, and a name inside another word fail the check. A test path must stay inside the repository. An absolute path, a path with a `..` segment and a path that resolves outside the root through a symlink fail on any row. P1 and P2 rows with a missing test path are reported as notes instead.

The suite builds fixture copies with a removed P0 test path, a blanked P0 cell, a renamed case, an absolute path, a parent segment, a symlink out of the root and a case name that only sits inside another word and requires each to fail and name its row.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-hardening-matrix.py` | Script | Parses the matrix and checks every row, with the hard rule for P0. |
| `sk-moneybird-accountant/hardening-matrix.md` | Shared | Holds one row per failure mode with its control, test, owner and status. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/hardening-matrix-test.sh` | Automated test | Seeds a removed test path, a blank cell, a renamed case, three path escapes and a case inside another word and requires each to fail. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the matrix check and the suite on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/hardening-matrix-check.md

Related references:
- [regression-trailer-check.md](regression-trailer-check.md) - Guards the commit that changes the matrix.
- [eval-grader.md](eval-grader.md) - Grades the eval cases the matrix rows name.
