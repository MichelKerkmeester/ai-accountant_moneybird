---
title: Live bookkeeping cadence
description: Routes current monthly, quarterly and yearly bookkeeping through the appropriate review steps.
trigger_phrases:
  - Live bookkeeping cadence
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - live bookkeeping cycles
version: 1.0.0.0
---

# Live bookkeeping cadence

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Routes current monthly, quarterly and yearly bookkeeping through the appropriate review steps.

The LIVE mode guides recurring bookkeeping for current periods. It separates monthly reconciliation, VAT-period review and yearly close work. Migration Phases 19 to 21 start when Phase 18 passes and recur through the configured monitoring period.

---

## 2. HOW IT WORKS

The agent reviews sales, purchase records, bank transactions, private movements and exceptions at the relevant cadence. Quarterly work prepares a review for the operator and never submits a return. Yearly work checks balance, assets, depreciation, mileage, private use (privégebruik) and closing evidence.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/SKILL.md | Shared | Defines live mode and monthly, quarterly and yearly workflows. |
| sk-moneybird-accountant/references/moneybird-bookkeeping.md | Shared | Explains common posting and reconciliation treatment. |
| sk-moneybird-accountant/references/migration/phases-17-to-18.md | Shared | Defines the source freeze and live switch. |
| sk-moneybird-accountant/references/migration/phases-19-to-21.md | Shared | Defines recurring monthly, VAT-period and yearly workflows. |
| sk-moneybird-accountant/references/vat-return/README.md | Shared | The quarterly VAT return (btw-aangifte) preparation procedure the VAT-period review routes into. |
| sk-moneybird-accountant/references/yearly-overview/README.md | Shared | The yearly close and overview preparation procedure. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/live-monthly-bookkeeping.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/live-bookkeeping-cadence.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [year-specific-zzp-guidance.md](year-specific-zzp-guidance.md) - Related workflow behavior.
