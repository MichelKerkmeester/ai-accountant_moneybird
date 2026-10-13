---
title: Regression trailer check
description: Requires a covering test or a Regression-Test trailer when a guarded file changes in one commit.
trigger_phrases:
  - Regression trailer check
  - check-regression-trailer.py
  - Regression-Test trailer
  - guarded file change
  - commit range coverage
version: 1.0.0.0
---

# Regression trailer check (check-regression-trailer.py)

## 1. OVERVIEW

Requires a covering test or a Regression-Test trailer when a guarded file changes in one commit.

`scripts/check-regression-trailer.py --range <base>..<head>` lists the range and reads one commit at a time. A commit that changes a guarded file must add, modify or type-change a registered test in the same commit or carry a `Regression-Test:` trailer naming a registered test that exists at that commit.

---

## 2. HOW IT WORKS

The guarded set covers the bootstrap, the accountant skill file, the two tool skill files, the Moneybird guard and the shared mechanisms file. The registered test set is read from the parent of the commit and holds the test paths the hardening matrix names plus the test files the skill health workflow runs. A named test registers only when it exists both at the parent and at the commit, so a test created in the commit under check cannot cover it. A deleted path never counts as a test change, while a rename reads as a deletion of its source and an addition of its destination, so both paths reach the gate match.

The suite builds fixture repositories with signing and hooks off and proves a missing trailer fails, a valid trailer passes, a deleted covering test does not register and an unknown range or missing root is refused.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-regression-trailer.py` | Script | Reads a commit range and checks each guarded change against the registered tests. |
| `sk-moneybird-accountant/references/migration/shared-mechanisms.md` | Shared | One of the guarded files whose change needs coverage. |
| `sk-moneybird-accountant/hardening-matrix.md` | Shared | Names test paths that register a covering test. |
| `.github/workflows/skill-health.yml` | Shared | Names the suites that register a covering test. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/regression-trailer-test.sh` | Automated test | Builds fixture repositories for a valid trailer, a deleted covering test and an unknown range. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the check on the pushed range. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/regression-trailer-check.md

Related references:
- [hardening-matrix-check.md](hardening-matrix-check.md) - The matrix whose test paths register.
- [write-contract-check.md](write-contract-check.md) - Another check that a commit can change.
