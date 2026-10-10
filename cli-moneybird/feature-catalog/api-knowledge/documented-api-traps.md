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

Lists default to `period:this_year`, so every verification list names its period. An immediate GET after a write can return cached data, so the write response status is the first proof and synchronization is the later read. `GET /financial_mutations` is capped at one hundred records, so complete pulls use `sync` and `sync_fetch` in ID batches of no more than one hundred.

### Writes That Look Successful

Some DELETE endpoints return 204 when nothing was removed, so a separate read confirms the removal. Records in a locked period cannot be edited or deleted. The deprecated sales invoice `register_payment` action has a published sunset, so payments use `financial_mutations link_booking` or document payments.

### Limits and Pacing

The API allows 150 requests per five minutes and 50 per five minutes under `/reports/`. A `429` carries `Retry-After`, which the skill waits out. Reports cover at most twelve months per request.

### UI-Only Operations

CAMT.053 and MT940 bank files, tax rate creation, period locks and historical VAT filing with **Handmatig indienen** stay in the Moneybird UI. `financial_statements` is a JSON mutation route, not a file upload route.

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
