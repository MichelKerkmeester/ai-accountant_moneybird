---
title: Repository CI gates
description: Runs the plan kit, privacy and skill health workflows that check this package on every push and pull request.
trigger_phrases:
  - Repository CI gates
  - skill-health workflow
  - plan-kit workflow
  - privacy-gate workflow
  - CI jobs
version: 1.0.0.0
---

# Repository CI gates

## 1. OVERVIEW

Runs the plan kit, privacy and skill health workflows that check this package on every push and pull request.

Three workflows own the automation. `plan-kit.yml` checks the generated kit and runs the plan kit and session context suites. `privacy-gate.yml` runs the privacy self test, the tree check, the history check and the gate suite. `skill-health.yml` runs the guard and Jortt suites, the routing, reference and gate checks and every package suite and its scheduled job checks the cited source links.

---

## 2. HOW IT WORKS

The offline skill health job seeds the pinned tokenizer cache, runs each check and suite on its own step and runs the regression trailer check on a pushed range. The links job runs on a schedule or on demand, checks every cited source link, watches the publication series and checks the year files against the release calendar. A changed watch or a stale year is reported as an issue for the Operator and only a failing link check fails the job.

Every suite in the workflows is named on its own line, because the regression trailer check reads this file to learn which tests are registered. The workflows run on a clean checkout with read-only contents permission and no persisted credentials.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `.github/workflows/plan-kit.yml` | Shared | Checks the generated kit and runs the plan kit and session context suites. |
| `.github/workflows/privacy-gate.yml` | Shared | Runs the privacy gate modes and its suite. |
| `.github/workflows/skill-health.yml` | Shared | Runs the guard, Jortt, routing, reference and gate suites and the monthly link job. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/plan-kit-test.sh` | Automated test | The suite the plan kit job runs. |
| `scripts/privacy-gate-test.sh` | Automated test | The suite the privacy job runs. |
| `sk-moneybird-accountant/scripts/write-contract-test.sh` | Automated test | One of the suites the skill health job runs. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/repository-ci-gates.md

Related references:
- [privacy-gate.md](privacy-gate.md) - The gate the privacy workflow runs.
- [regression-trailer-check.md](regression-trailer-check.md) - The check that reads the suite list in the workflows.
