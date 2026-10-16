---
title: Purchase invoice booking
description: Routes the booking of a purchase invoice, receipt or order to the flow and VAT rate that fit the invoice.
trigger_phrases:
  - Purchase invoice booking
  - book a purchase invoice in Moneybird
  - reverse-charged purchase VAT
  - Moneybird purchase invoice booking
version: 1.0.0.0
---

# Purchase invoice (inkoopfactuur) booking

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Routes the booking of a purchase invoice (inkoopfactuur), receipt or order to the flow and VAT rate (btw-tarief) that fit the invoice.

The reference sorts each invoice into a case before booking: a Dutch invoice with Dutch VAT, a foreign invoice with 0% VAT because the VAT is reverse charged, an invoice with foreign VAT, an import or domestic reverse charge. Each case names its Moneybird VAT rate and the VAT return (btw-aangifte) section (rubriek).

---

## 2. HOW IT WORKS

The agent checks the document first: invoice or order, invoice requirements, supplier location, goods or service, the VAT shown and the small businesses scheme (kleineondernemersregeling, KOR) or exemption status. It then follows the shared Moneybird flow from the incoming inbox to a saved document and picks the VAT rate (btw-tarief) per line. A reverse-charged invoice is reported as owed and deducted in the same return, except for a small businesses scheme or exempt business. Moneybird writes still need a passed gate and Operator approval. The Operator files the return.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/purchase-invoices.md | Shared | Defines the booking flow, the case table and the VAT rate (btw-tarief) per case. |
| sk-moneybird-accountant/references/moneybird-bookkeeping.md | Shared | Explains categories, mixed costs (gemengde-kosten) and bank matching. |
| sk-moneybird-accountant/SKILL.md | Shared | Loads the purchase invoice (inkoopfactuur) reference in LIVE bookkeeping. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/purchase-invoice-booking.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/purchase-invoice-booking.md

Related references:
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
- [api-tool-handoff.md](api-tool-handoff.md) - Related workflow behavior.
