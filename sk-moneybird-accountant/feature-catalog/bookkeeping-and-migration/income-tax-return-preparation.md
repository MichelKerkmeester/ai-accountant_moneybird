---
title: Income tax return preparation
description: Entry index for preparing a Dutch sole-trader income tax return from Moneybird. The folder holds the ordered procedure, the Operator input checklist, the investment and claim register and the residual open points. It prepares and never files, submits or pays.
trigger_phrases:
  - income tax return preparation
  - prepare the income tax return
  - income-tax-return folder
  - IB-aangifte pack
  - income tax return review
version: 1.0.0.0
---

# Income tax return preparation

## 1. OVERVIEW

Entry index for preparing a Dutch sole-trader income tax return from Moneybird. The folder holds the ordered procedure, the Operator input checklist, the investment and claim register and the residual open points. It prepares and never files, submits or pays.

The T12 task-type row routes a prepare-the-income-tax-return request into `references/income-tax-return/`. The agent assembles the return pack for one year, names every Operator input, every evidence item and every open point, and stops before filing. The Operator reviews and confirms the pack and files the return in the Dutch Tax and Customs Administration (Belastingdienst) portal.

---

## 2. HOW IT WORKS

### The procedure and the disposition vocabulary

The procedure runs the ordered cross-year steps with one owner tag per step and a source map, followed by the evidence gates, the review pack and the stop rules. The Operator input checklist gives every item one disposition from `supplied`, `reconciled`, `confirmed`, `not applicable` or `unresolved`. An item that cannot be settled stays `unresolved` with the evidence that would settle it named, and it is never filled from memory.

### The register, the open points and the boundary

The investment and claim register is the dated per-asset record with the order date, the payment dates, the in-use date, the RVO reference and the prior deduction (aftrek) columns, and its amount cells are braced placeholders. The residual unknowns stay `unresolved`, each with what would settle it. Every figure is a link into `references/tax-rules/{year}/` and the folder never copies one. Filing, payment and the period lock stay Operator-only, and an explicit file, submit, pay or lock request leaves T12 for the T8 refusal.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/income-tax-return/README.md` | Shared | Entry index, the boundary, the figure link rule and the shared disposition vocabulary. |
| `sk-moneybird-accountant/references/income-tax-return/procedure.md` | Shared | The ordered cross-year procedure, the source map, the evidence gates, the pack shape and the stop rules. |
| `sk-moneybird-accountant/references/income-tax-return/operator-inputs.md` | Shared | The Operator evidence checklist with one disposition per item. |
| `sk-moneybird-accountant/references/income-tax-return/investment-and-claim-register.md` | Shared | The dated per-asset register that evidences an investment allowance claim. |
| `sk-moneybird-accountant/references/income-tax-return/risks-and-open-points.md` | Shared | The residual unknowns, each labelled unresolved with what would settle it. |
| `sk-moneybird-accountant/SKILL.md` | Shared | Holds the T12 row that routes a prepare-the-income-tax-return request into this folder. |
| `sk-moneybird-accountant/references/tax-rules/{year}/income-tax/figures.md` | Shared | Owns the income tax figures the procedure links. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/manual-testing-playbook/offline-routing/income-tax-return-pack.md` | Manual playbook | Scenario PACK-002 with gold row PACK-INCOME-01 and eval case income-tax-return-pack. |
| `sk-moneybird-accountant/scripts/route-replay/routing-gold.json` | Fixture | The PACK-INCOME-01 row with its covers tag and token ceiling. |
| `sk-moneybird-accountant/evals/evals.json` | Fixture | The income-tax-return-pack eval case with its required-token and forbidden-pattern lists. |
| `sk-moneybird-accountant/scripts/route-replay/route-replay-test.sh` | Automated test | The pass case for the pack row. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/income-tax-return-preparation.md

Related references:
- [task-type-routing.md](task-type-routing.md) - The T12 row, its signals and its read set.
- [fixed-asset-booking.md](fixed-asset-booking.md) - The asset register and the depreciation schedule the procedure reads.
- [operator-tax-boundary.md](operator-tax-boundary.md) - The filing boundary the pack stops at.
