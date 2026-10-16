---
title: Year rollover
description: The 1 January runbook that carries the year corpus into the next tax year, the five-checkpoint release calendar with its check-by dates and the owner of both.
nav_label: "Year rollover"
trigger_phrases:
  - year rollover
  - 1 january runbook
  - release calendar
  - prinsjesdag
  - december indexation
  - february reconciliation
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Year rollover

**Rule:** Follow this runbook on 1 January, or on the first working day after it. Every step names the path it touches. A figure stays in the year file that owns it, and this reference changes no value. Every condition names its alternative or its default, so a decision step carries a branch, and `sk-moneybird-accountant/scripts/outline-check.py` fails one that names none.

---

## 1. OVERVIEW

**Owner:** the Operator. The decision date is 2026-10-12.

The corpus holds one folder per tax year under `sk-moneybird-accountant/references/tax-rules/`, from 2020 to 2027. Each folder holds a README, twelve topic files and a changelog. The rollover adds the next folder and moves the checked dates forward.

The rules that span tax years live in `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md`. The sources that back them live in `sk-moneybird-accountant/references/tax-rules/source-library.md`.

---

## 2. THE 1 JANUARY RUNBOOK

Run these steps in order against the files of the newest year folder.

1. Create the new year folder beside `sk-moneybird-accountant/references/tax-rules/2027/` and copy `sk-moneybird-accountant/references/tax-rules/2027/README.md` and the twelve topic files of `sk-moneybird-accountant/references/tax-rules/2027/` into it.
2. Set the year preference in `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md` by adding the new year to its tax years and to its year folders table.
3. Set every figure in the new topic files for the new tax year, keep a source URL on every row, and name the alternative or the default of every condition, so a decision step carries a branch.
4. Set `checked_on` in the README of every touched year folder under `sk-moneybird-accountant/references/tax-rules/` and in `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md`.
5. Run `python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check` and refresh the generated blocks when it reports drift.
6. Run `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check` and record every new source in `sk-moneybird-accountant/assets/source-library.json`. Classify each new source's access, and check every new `pdf-needs-reader` row against `python3 -I sk-moneybird-accountant/scripts/read-pdf-source.py --list` before you rely on it.
7. Run `python3 -I sk-moneybird-accountant/scripts/build-source-library.py --check-calendar` and move every year README date that lags a checkpoint already passed.
8. Give the new year folder a changelog with the shape of `sk-moneybird-accountant/references/tax-rules/2027/changelog.md`, log every correction there as one row per changed value, and link the log from the new year README.

---

## 3. THE RELEASE CALENDAR

| Checkpoint | Date | Refresh |
|---|---|---|
| Prinsjesdag | 2026-09-15 | Every `proposed` row under `sk-moneybird-accountant/references/tax-rules/2027/` |
| House of Representatives (Tweede Kamer) vote | 2026-11-30 | The bill rows under `sk-moneybird-accountant/references/tax-rules/2027/` and the staged-bill rule in `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md` |
| Senate (Eerste Kamer) vote | 2026-12-31 | The status tags under `sk-moneybird-accountant/references/tax-rules/2027/` and the year preference in `sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md` |
| December indexation | 2027-01-05 | The indexation rows under `sk-moneybird-accountant/references/tax-rules/2027/` and the counts in `sk-moneybird-accountant/references/tax-rules/source-library.md` |
| February reconciliation | 2027-02-15 | Every `Corrected` and `UNVERIFIED` row under `sk-moneybird-accountant/references/tax-rules/2026/` and `sk-moneybird-accountant/references/tax-rules/2027/` |

These are check-by dates, not event dates, and the Operator moves them each cycle.

---

## 4. RELATED RESOURCES

- [source-library.md](./source-library.md) for the refresh interval per file kind and the source index.
- [dutch-tax-rules.md](./dutch-tax-rules.md) for the year preference, the staged-bill rule and the status tags.
- [2027/README.md](./2027/README.md) for the newest year folder and its checked date.
