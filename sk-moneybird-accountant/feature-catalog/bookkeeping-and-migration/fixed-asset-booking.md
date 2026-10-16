---
title: Fixed asset booking
description: Routes a large purchase or an equipment item to the cost-or-asset test, depreciation, the VAT revision period and the Moneybird asset screens.
trigger_phrases:
  - Fixed asset booking
  - inventaris afschrijven
  - laptop afschrijven in Moneybird
  - fixed asset route
version: 1.0.0.0
---

# Fixed asset booking

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Routes a large purchase or an equipment item to the cost-or-asset test, depreciation, the VAT revision period and the Moneybird asset screens.

The reference states when a purchase is capitalised, the small-amount rule, the depreciation base and yearly limit, the investment deductions and disposal. It also covers the Moneybird asset flow from the invoice line to the asset (bezitting) and the existing-asset opening path.

---

## 2. HOW IT WORKS

The agent checks whether the business uses the purchase for more than one year and whether the amount is at or above the activation threshold. A capitalised purchase gets an asset record (bezitting) with its acquisition cost (aanschafwaarde), in-use date, useful life and residual value. Depreciation follows the yearly limit. A good used partly privately goes through the labelling (etikettering) first. A building, a private item moved into the business or a change of use inside the revision period goes to the Operator or a bookkeeper. Moneybird writes still need a passed gate and Operator approval. The Operator files the return.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/fixed-assets.md | Shared | Defines the cost-or-asset test, depreciation, the VAT revision period and disposal. |
| sk-moneybird-accountant/references/mixed-use-costs.md | Shared | Defines the labelling (etikettering) and the booking split for a partly private asset. |
| sk-moneybird-accountant/references/purchase-invoices.md | Shared | Defines the invoice flow that creates the asset line. |
| sk-moneybird-accountant/references/income-tax-return/investment-and-claim-register.md | Shared | The dated per-asset register that evidences an investment allowance claim. |
| sk-moneybird-accountant/SKILL.md | Shared | Loads the fixed-asset reference conditionally in the T4 row. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/fixed-asset-booking.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/fixed-asset-booking.md

Related references:
- [purchase-invoice-booking.md](purchase-invoice-booking.md) - Related workflow behavior.
- [mixed-use-cost-booking.md](mixed-use-cost-booking.md) - Related workflow behavior.
