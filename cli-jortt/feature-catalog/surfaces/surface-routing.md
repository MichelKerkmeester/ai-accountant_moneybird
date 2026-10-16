---
title: "Surface routing"
description: "Sends each Jortt request to the CLI or the operator's UI export and hands Moneybird work to the sibling skill."
trigger_phrases:
  - "Surface routing"
  - "Jortt operation to surface"
  - "XAF auditfile request"
  - "Moneybird handoff"
version: 1.0.0.0
---

# Surface routing (SKILL.md)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Sends each Jortt request to the CLI or the operator's UI export and hands Moneybird work to the sibling skill.

Routing is where most migration mistakes start, such as presenting a VAT summary as a filed return. The skill states the right surface before any call.

---

## 2. HOW IT WORKS

The skill maps each operation to one surface. Customers, invoices, expenses, receipts, bank records, reports, labels and projects come from `jortt-cli`. Use the smallest supported read that answers a data question.

The Jortt API has no XAF, annual accounts (jaarrekening) or filed VAT return (btw-aangifte) route, so those requests become instructions for the operator in the Jortt UI. No general ledger (grootboek) export exists in the API or the UI, and the skill says so rather than relabelling another report. Requests about Moneybird imports or target-side checks are handed to the sibling `cli-moneybird` skill.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`SKILL.md`](../../SKILL.md) | Shared | Holds the operation-to-surface table, the detection order and the router. |
| [`references/exports-and-limits.md`](../../references/exports-and-limits.md) | Shared | States which records need the Jortt UI. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/routing/xaf-request-goes-to-ui.md`](../../manual-testing-playbook/routing/xaf-request-goes-to-ui.md) | Manual playbook | JRT-005 routes an XAF request to the operator. |
| [`manual-testing-playbook/routing/moneybird-request-deferred.md`](../../manual-testing-playbook/routing/moneybird-request-deferred.md) | Manual playbook | JRT-006 hands a Moneybird request to the sibling skill. |

---

## 4. SOURCE METADATA

- Group: Surfaces and routing
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `surfaces/surface-routing.md`

Related references:
- [exports-and-limits.md](../../references/exports-and-limits.md) - UI-only exports and API limits
