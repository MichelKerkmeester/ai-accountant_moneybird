---
title: "Documented API traps"
description: "The references record the Moneybird API behaviors that make an incomplete read or write look complete, with the safe route for each."
trigger_phrases:
  - "documented api traps"
  - "moneybird api traps"
  - "moneybird stale get"
  - "moneybird financial mutations cap"
version: 1.0.0.0
---

# Documented API traps (Moneybird REST API v2)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

The references record the Moneybird API behaviors that make an incomplete read or write look complete, with the safe route for each.

Each trap is paired with the route the skill uses instead, so an agent can follow the safe path without rediscovering the problem.

---

## 2. HOW IT WORKS

### Reads That Look Complete

Lists default to `period:this_year`, so every verification list names its period. An immediate GET after a write can return cached data, so the write response status is the first proof and synchronization is the later read. `GET /financial_mutations` is capped, so complete pulls use `sync` and `sync_fetch`. The cap and the batch rule are in `references/rest-api.md` and the Read Step Contract.

### Unmatched Bank Transactions

An unmatched bank transaction reports `state:unprocessed`, a processed one `state:processed` and one booked from a suggestion `state:auto_booked`. The bank read uses the "Bank transactions to match" row in section 2 of `cli-moneybird/ROUTER.md` and names the state with an explicit period. The bank list defaults to `period:this_year`, and a passed filter replaces every default. The comma filter form `--filter "period:$YEAR,state:unprocessed"` matches the pinned CLI's OpenAPI spec. The bank list is capped, so a larger read goes through `sync` and `sync_fetch` with a local state filter. The cap is in `references/rest-api.md`, and the read and its fallback follow the Read Step Contract in `cli-moneybird/SKILL.md` section 3.

### Writes That Look Successful

Some DELETE endpoints return 204 when nothing was removed, so a separate read confirms the removal. Records in a locked period cannot be edited or deleted. The deprecated sales invoice `register_payment` action has a published sunset, so payments use `financial_mutations link_booking` or document payments.

### Limits and Pacing

The API sets a general request rate and a lower rate under `/reports/`. A `429` carries `Retry-After`, which the skill waits out. A report request stays within the window `references/rest-api.md` names. The limits and the retry rule are in `references/rest-api.md` and the Read Step Contract.

### UI-Only Operations

CAMT.053 and MT940 bank files, tax rate creation, period locks and historical VAT filing with **Submit manually (Handmatig indienen)** stay in the Moneybird UI. `financial_statements` is a JSON mutation route, not a file upload route.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/rest-api.md`](../../references/rest-api.md) | Shared | Periods, caching, synchronization, limits and delete behavior |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Shared | Recovery steps for each API response |
| [`SKILL.md`](../../SKILL.md) | Shared | Rules that turn the traps into always and never steps |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [MBD-005](../../manual-testing-playbook/reads/period-filter-warning.md) | Manual playbook | The default period trap |
| [MBD-007](../../manual-testing-playbook/routing/bank-file-import-goes-to-ui.md) | Manual playbook | A UI-only operation routes to the operator |
| [`references/rest-api.md`](../../references/rest-api.md) | Reference | Source of the documented API behavior |

---

## 4. SOURCE METADATA

- Group: API Knowledge
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `api-knowledge/documented-api-traps.md`

Related references:
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
