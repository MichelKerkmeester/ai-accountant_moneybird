---
title: "Operation routing"
description: "ROUTER.md section 2 maps each request to a guarded CLI route or a Moneybird UI step and selects the reference set to load."
trigger_phrases:
  - "operation routing"
  - "moneybird operation table"
  - "guarded CLI route"
  - "moneybird UI handoff"
version: 1.0.0.0
---

# Operation routing (ROUTER.md)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

`ROUTER.md` section 2 maps each request to a guarded CLI route or a Moneybird UI step and selects the reference set to load.

The routing table is the boundary between what the skill may do through the API and what only the operator does in the UI. A wrong route is caught before a call rather than after it.

---

## 2. HOW IT WORKS

### Operation To Surface

The operation table names each task, its `moneybird-guard` route or UI boundary and its rule. Reads use the Read Step Contract. Writes use the confirmation, writer, pilot and approval gates. Administration sessions, contacts, ledger accounts, invoices and documents, financial mutations and accounts, payments, assets, reports, bulk reads and the auditfile export each have a named route.

### Resource Loading

The router scores the request against the intent model, loads only the references the winning route names and treats the feature catalog and the manual playbook as the inventory and validation routes. `references/cli.md` and `references/rest-api.md` stay conditional, and the migration recipes load only for a multi-record action.

### UI Boundaries And Unverified Fields

Bank file import, tax rate creation, period locking and historical VAT filing stay with the operator in the Moneybird UI. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` before a read. Body fields and report date arguments that the supplied facts do not name stay `UNVERIFIED` until pinned CLI help and a dry run confirm them.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`ROUTER.md`](../../ROUTER.md) | Shared | Owns the operation table, the intent router and the resource map |
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Shared | Gives the guarded command sequence behind each write route |
| [`references/rest-api.md`](../../references/rest-api.md) | Shared | Holds the read rules the routing table points to |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/routing/attachment-through-cli.md`](../../manual-testing-playbook/routing/attachment-through-cli.md) | Manual playbook | Routes a document attachment through the guarded CLI |
| [`manual-testing-playbook/routing/bank-file-import-goes-to-ui.md`](../../manual-testing-playbook/routing/bank-file-import-goes-to-ui.md) | Manual playbook | Routes a bank file import to the operator UI |
| [`references/cli.md`](../../references/cli.md) | Reference | Names the guard routes and their exit codes |

---

## 4. SOURCE METADATA

- Group: Routing
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `routing/operation-routing.md`

Related references:
- [guarded-migration-recipes.md](../migration-recipes/guarded-migration-recipes.md) - Command sequence behind each write route
- [read-step-contract.md](../reads-and-saved-output/read-step-contract.md) - Rules behind each read route
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
