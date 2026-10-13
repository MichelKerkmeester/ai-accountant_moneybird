---
title: Year rollover runbook
description: Runs the yearly corpus rollover and keeps the year files checked against the release calendar the runbook owns.
trigger_phrases:
  - Year rollover runbook
  - 1 january runbook
  - release calendar
  - prinsjesdag checkpoint
  - build-source-library.py --check-calendar
version: 1.0.0.0
---

# Year rollover runbook

## 1. OVERVIEW

Runs the yearly corpus rollover and keeps the year files checked against the release calendar the runbook owns.

`references/year-rollover.md` holds the runbook, the release calendar with its check-by dates and the Operator as the owner of both. The runbook adds the next year folder, sets its figures and sources, moves the checked dates forward and refreshes the generated reference blocks.

---

## 2. HOW IT WORKS

The Operator follows the runbook in order against the newest year folder. Every step names the path it touches and a figure stays in the year file that owns it. The runbook includes the reference-index check, the source-library check and the calendar check.

The monthly job watches the publication series in `assets/source-watchlist.json` and compares each answer with the state file. `build-source-library.py --check-calendar` reads the checked dates from the year READMEs and the rules file and fails when a current or future year predates the latest passed checkpoint. A watch change or a stale year is reported to the Operator as an issue and does not fail the skill.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/year-rollover.md` | Shared | Owns the runbook, the release calendar and the owner of both. |
| `sk-moneybird-accountant/assets/source-watchlist.json` | Shared | Lists the publication series the monthly watch checks. |
| `sk-moneybird-accountant/assets/source-watch-state.json` | Shared | Records the last answer per watched URL so a page that goes live is reported. |
| `sk-moneybird-accountant/scripts/build-source-library.py` | Script | Implements the watch and the calendar check modes. |
| `sk-moneybird-accountant/references/source-library.md` | Shared | Records the access result for every cited source. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/source-library-test.sh` | Automated test | Proves the watch, its state and the calendar check on fixture repositories and the real corpus. |
| `.github/workflows/skill-health.yml` | Test harness | Runs the monthly watch and calendar steps and opens an issue on a change. |

---

## 4. SOURCE METADATA

- Group: reference-and-state
- Canonical catalog source: feature-catalog.md
- Feature file path: reference-and-state/year-rollover-runbook.md

Related references:
- [session-context-and-year-state.md](session-context-and-year-state.md) - The route-time year resolver the corpus feeds.
- [reference-index-and-year-changes.md](reference-index-and-year-changes.md) - The generated blocks the runbook refreshes.
