---
title: "Skill health CI"
description: "Runs the Jortt offline suite and the sibling repository checks on every push and pull request in the skill-health workflow."
trigger_phrases:
  - "Skill health CI"
  - "skill-health workflow"
  - "Jortt CI suite"
  - "GitHub Actions skill health"
version: 1.0.0.0
---

# Skill health CI (.github/workflows/skill-health.yml)

## 1. OVERVIEW

Runs the Jortt offline suite and the sibling repository checks on every push and pull request in the skill-health workflow.

The workflow is the machine check behind the manual test contract. A change that breaks the CLI or one of its documented links fails the run before it reaches the operator.

---

## 2. HOW IT WORKS

### Core Behavior

The `offline` job runs on push, pull request and manual dispatch. It installs the pinned tokenizer, runs the Jortt suite and the sibling repository checks and finishes with route replay and the regression trailer on a push. Each check is its own step, so a failure stops the job at the check that failed.

### Links Job

The `links` job runs on a schedule and on manual dispatch. It checks the cited source links, the publication series and the year calendar. A link failure opens an issue and fails the job. A changed source or a stale year file opens an issue without failing the job, and a usage error fails it.

### Scope

The workflow also covers the Moneybird guard suite, exit code parity and the accounting scripts. Only the Jortt suite step and the fragment check touch cli-jortt, and both read the tracked tree, so credential values and record data are never part of a run. The offline job downloads the pinned tokenizer files at setup, and the links job checks external sources on its schedule.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`../../../.github/workflows/skill-health.yml`](../../../.github/workflows/skill-health.yml) | Script | The offline job with the Jortt suite step and the links job. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | The Jortt suite the offline job runs. |
| [`../../../sk-moneybird-accountant/scripts/check-fragments.py`](../../../sk-moneybird-accountant/scripts/check-fragments.py) | Test harness | Checks every relative link and fragment in the cli-jortt markdown. |

---

## 4. SOURCE METADATA

- Group: Testing and CI
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `testing/skill-health-ci.md`

Related references:
- [offline-cli-test-suite.md](offline-cli-test-suite.md) - Offline CLI test suite
