---
title: Mixed-use cost booking
description: Routes a cost used partly for the business and partly privately to the business share, the VAT split and the Moneybird booking.
trigger_phrases:
  - Mixed-use cost booking
  - book a phone subscription partly private
  - gemengde kosten boeken
  - mixed use VAT split
version: 1.0.0.0
---

# Mixed-use cost booking

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Routes a cost used partly for the business and partly privately to the business share, the VAT split and the Moneybird booking.

The reference covers a mobile phone subscription, a home internet connection, a phone or laptop handset and the fixed telephone line in the own home. It states the income tax (inkomstenbelasting) share, the VAT share, the evidence the business share needs and the Moneybird steps that split the private part.

---

## 2. HOW IT WORKS

The agent establishes the business share and records its basis, then books the document through the shared purchase flow. A service such as a subscription deducts only the VAT on the business share and settles private use (privégebruik) in the last VAT return (btw-aangifte) of the year. A good above the asset threshold follows the fixed asset route for the VAT choice and the revision period. A changed business share, a doubtful estimate or a home in business assets (bedrijfsmiddelen) goes to the Operator or a bookkeeper. Moneybird writes still need a passed gate and Operator approval. The Operator files the return.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/mixed-use-costs.md | Shared | Defines the income tax (inkomstenbelasting) share, the VAT split and the Moneybird booking steps. |
| sk-moneybird-accountant/references/purchase-invoices.md | Shared | Defines the shared document flow and the VAT choice for each invoice kind. |
| sk-moneybird-accountant/references/fixed-assets.md | Shared | Defines the asset route for a good used for mixed purposes. |
| sk-moneybird-accountant/ROUTER.md | Shared | Loads the mixed-use reference conditionally in the T4 row. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/mixed-use-cost-booking.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/mixed-use-cost-booking.md

Related references:
- [purchase-invoice-booking.md](purchase-invoice-booking.md) - Related workflow behavior.
- [fixed-asset-booking.md](fixed-asset-booking.md) - Related workflow behavior.
