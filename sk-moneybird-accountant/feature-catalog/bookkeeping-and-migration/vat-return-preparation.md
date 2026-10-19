---
title: VAT return (btw-aangifte) preparation
description: Entry index for preparing a Dutch VAT period from Moneybird. The folder holds the ordered procedure, the section and derivation rules, the year-end branch and the review pack. It prepares and never files, submits or pays.
trigger_phrases:
  - VAT return preparation
  - prepare the VAT return
  - vat-return folder
  - quarterly VAT return
  - btw-aangifte voorbereiden
version: 1.0.0.0
---

# VAT return (btw-aangifte) preparation

## 1. OVERVIEW

Entry index for preparing a Dutch VAT period from Moneybird. The folder holds the ordered procedure, the section and derivation rules, the year-end branch and the review pack. It prepares and never files, submits or pays.

The T10 task-type row routes a prepare-the-VAT-return request into `references/vat-return/`. The agent assembles the section (rubriek) table, the checks and the review pack for one period, names every exception and stops before filing. The Operator checks, confirms, files and pays.

---

## 2. HOW IT WORKS

### The period route

A request that names the VAT return (btw-aangifte), a quarterly return or a preparation of either wins T10 and reads the folder README, the resolved year VAT figures and, when a deadline, a correction or tax interest (belastingrente) applies, the year procedure figures. The mode is LIVE. The administration data is read at run time with moneybird-guard under `MONEYBIRD_GUARD_READ_ONLY=1`, following `cli-moneybird/SKILL.md`. Period unlocking, tax-rate creation and filing stay UI and Operator actions. A supplementary return (suppletie) corrects a VAT return, so `suppletie`, `correctie vorige periode`, `VAT correction`, `correct a VAT error` and `supplementary return` are T10 signals. They route here and never to the yearly overview (jaaroverzicht).

### The review pack and the boundary

Every figure, rate, threshold and deadline is a link into `references/tax-rules/{year}/`. The folder never copies one. The output is the review pack with the blocks P1 to P9 and the confirmation parts C1 to C3, plus the deadline and payment block and the escalation list. Every human decision carries an `[Operator]` marker. The procedure prepares the period and never files, submits or pays, and an explicit file, submit, pay or lock request leaves T10 for the T8 refusal.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/vat-return/README.md` | Shared | Entry index, the boundary, the figure link rule and the open points O1 to O5. |
| `sk-moneybird-accountant/references/vat-return/preparation.md` | Shared | The ordered period procedure, steps 0 to 12, each with its check, its evidence and its Operator point. |
| `sk-moneybird-accountant/references/vat-return/return-boxes.md` | Shared | The section (rubriek) table for 1a to 5b, the derivation map, the run-time rate step and the reverse-charge, small businesses scheme (kleineondernemersregeling, KOR), ICP and OSS rules. |
| `sk-moneybird-accountant/references/vat-return/year-end-and-corrections.md` | Shared | The year-end settlements S1 to S4 and the correction and supplementary return (suppletie) routing. |
| `sk-moneybird-accountant/references/vat-return/review-pack.md` | Shared | The pack blocks P1 to P9, the confirmation parts C1 to C3 and the deadline and payment block. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | Holds the T10 row that routes a prepare-the-VAT-return request into this folder. |
| `sk-moneybird-accountant/references/tax-rules/{year}/vat/figures.md` | Shared | Owns every VAT figure and rate the procedure links. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/manual-testing-playbook/vat-and-tax-returns/vat-return-normal-quarter.md` | Manual playbook | Scenario VAT-001, the normal quarter with gold row VAT-BRANCH-Q1-01 and eval case vat-return-normal-quarter. |
| `sk-moneybird-accountant/manual-testing-playbook/vat-and-tax-returns/vat-return-reverse-charge.md` | Manual playbook | Scenario VAT-002, the reverse-charge quarter with gold row VAT-BRANCH-RC-01. |
| `sk-moneybird-accountant/manual-testing-playbook/vat-and-tax-returns/vat-return-small-business-scheme.md` | Manual playbook | Scenario VAT-003, the small businesses scheme (KOR) quarter with a reverse-charged purchase and gold row VAT-BRANCH-KOR-01. |
| `sk-moneybird-accountant/manual-testing-playbook/vat-and-tax-returns/vat-return-last-quarter.md` | Manual playbook | Scenario VAT-004, the final quarter of the year with gold row VAT-BRANCH-YE-01. |
| `sk-moneybird-accountant/manual-testing-playbook/vat-and-tax-returns/vat-return-correction-boundary.md` | Manual playbook | Scenario VAT-005, the correction above and below the boundary with gold row VAT-BRANCH-COR-01. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | The five VAT-BRANCH rows with their token ceilings. |
| `sk-moneybird-accountant/evals/evals.json` | Fixture | The five VAT branch eval cases with their required-token and forbidden-pattern lists. |
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | One pass case per branch row plus the seeded mutants. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/vat-return-preparation.md

Related references:
- [task-type-routing.md](task-type-routing.md) - The T10 row, its signals and its read set.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - The live period cadence that feeds the quarterly preparation.
- [operator-tax-boundary.md](operator-tax-boundary.md) - The filing boundary the pack stops at.
