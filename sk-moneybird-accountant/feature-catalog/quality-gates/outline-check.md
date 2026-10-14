---
title: Outline check
description: Checks the carry-forward rule over the year and general topic files and reports every decision step that names no alternative or default branch.
trigger_phrases:
  - outline check
  - outline-check.py
  - carry-forward rule
  - decision step branch
  - failing branch check
version: 1.0.0.0
---

# Outline check (outline-check.py)

## 1. OVERVIEW

Checks the carry-forward rule over the year and general topic files and reports every decision step that names no alternative or default branch.

A condition names its alternative or its default. A decision step is a step that asks a question or opens with a decision verb. The check requires a branch and never judges the branch, so it reports the step and stays silent on whether the branch is the right one.

---

## 2. HOW IT WORKS

### The rule and the reading

The rule is stated in `references/tax-rules/year-rollover.md`, the authoring note for the next year's files. `outline-check.py` reads the split part files below `references/tax-rules/`, a flat year topic file and the general topic files beside them. It skips the year README, the changelog, the change note and fenced code blocks, and it makes no network call. The default mode and `--check` read only and `--root` reads another copy of the repository.

### The output and the CI route

The run prints one line per decision step without an alternative branch and then the count line `outline-check: N decision steps, M without an alternative branch`. It exits 0 when no step misses its branch, 1 when one does and 2 on a read error. `check-route-table.py` runs the check beside the word and split checks, so the skill health job fails on a decision step that names none.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/outline-check.py` | Script | Reads the year and general topic files, requires a branch on every decision step and reports the count. |
| `sk-moneybird-accountant/references/tax-rules/year-rollover.md` | Shared | States the carry-forward authoring rule the check enforces. |
| `sk-moneybird-accountant/scripts/check-route-table.py` | Script | Runs the outline check beside the word and split checks in the skill health step. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/outline-check-test.sh` | Automated test | Builds a fixture repository for the rejected and accepted step shapes and proves the real corpus clean beside a seeded decision step in a copy. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the route table step, and with it the outline check, on push and pull request. |

---

## 4. SOURCE METADATA

- Group: quality-gates
- Canonical catalog source: feature-catalog.md
- Feature file path: quality-gates/outline-check.md

Related references:
- [fragment-link-check.md](fragment-link-check.md) - The sibling structural check over links and fragments.
- [token-budget-baseline.md](token-budget-baseline.md) - The sibling budget check the route table also runs.
- [../reference-and-state/year-rollover-runbook.md](../reference-and-state/year-rollover-runbook.md) - The runbook that owns the carry-forward rule.
