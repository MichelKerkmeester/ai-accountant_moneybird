---
title: Live bookkeeping cadence
description: Routes current monthly, quarterly, and yearly bookkeeping through the appropriate review steps.
trigger_phrases:
  - Live bookkeeping cadence
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - LIVE-001
version: 1.0.0.0
---

# Live bookkeeping cadence

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Routes current monthly, quarterly, and yearly bookkeeping through the appropriate review steps.

The LIVE mode guides recurring bookkeeping for current periods. It separates monthly reconciliation, quarterly VAT review, and yearly close work.

---

## 2. HOW IT WORKS

The agent reviews sales, purchase records, bank transactions, private movements, and exceptions at the relevant cadence. Quarterly work prepares a review for the operator and never submits a return. Yearly work checks balance, assets, depreciation, mileage, private use, and closing evidence.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Shared | Defines live mode and monthly, quarterly, and yearly workflows. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/moneybird-bookkeeping.md | Shared | Explains common posting and reconciliation treatment. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/live-workflows-phases-17-to-20.md | Shared | Preserves the transition and live workflow instructions. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/live-monthly-bookkeeping.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/live-bookkeeping-cadence.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [year-specific-zzp-guidance.md](year-specific-zzp-guidance.md) - Related workflow behavior.
