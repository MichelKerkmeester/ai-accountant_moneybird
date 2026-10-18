---
title: "Read step contract"
description: "The Read Step Contract in SKILL.md section 3 sets the read-only lock, an explicit period, a completeness proof, the request caps and the retry rule for every guarded read."
trigger_phrases:
  - "read step contract"
  - "moneybird guarded read"
  - "moneybird completeness proof"
  - "moneybird read retry rule"
version: 1.0.0.0
---

# Read step contract (guarded reads)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

The Read Step Contract in `SKILL.md` section 3 sets the read-only lock, an explicit period, a completeness proof, the request caps and the retry rule for every guarded read.

The contract exists because a list read can succeed and still be incomplete. An omitted period, a capped endpoint and a cached GET each make a partial answer look whole, so every read states how it proves completeness.

---

## 2. HOW IT WORKS

### Read Lock

Every guarded read sets `MONEYBIRD_GUARD_READ_ONLY=1`, so the guard blocks a non-GET method before its real call, except a synchronization fetch, which only reads. The lock covers Moneybird calls only. Local workspace writes and attachment downloads are not blocked by it.

### Period And Completeness

Every list names an explicit period, because Moneybird defaults to `period:this_year`. A read proves completeness before it reports a count. It pages until a short page returns, dedupes by record id and records the count with the period it covers.

### Caps And Bulk Reads

A list endpoint is capped, so a larger read uses `sync` and `sync_fetch` within the batch cap. `sync_fetch` is a POST, and the guard runs it as a read, so the read-only lock lets it through. A report covers a bounded window, and a longer report splits into parts that each record period and count and reconcile to the whole. The exact caps and the window are in `references/rest-api.md` and `SKILL.md` section 3.

### Staleness And Retry

An immediate GET after a write can return cached data, so the write response status is the first proof and a later synchronization read is the verification. Retries are GET only, and a synchronization fetch counts as a GET, wait for `Retry-After` first and otherwise use capped exponential backoff with full jitter and a bounded attempt count. A failed GET that exhausts the attempts stops the read for the Operator. A non-GET call is never retried.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`SKILL.md`](../../SKILL.md) | Shared | Owns the Read Step Contract |
| [`references/rest-api.md`](../../references/rest-api.md) | Shared | Working detail for periods, paging, caps and rate limits |
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Enforces the read-only lock and the period warning |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Covers the read-only lock, the period warning and the output paths |
| [`manual-testing-playbook/reads/period-filter-warning.md`](../../manual-testing-playbook/reads/period-filter-warning.md) | Manual playbook | Operator check of the explicit period |
| [`manual-testing-playbook/write-safety/read-only-lock.md`](../../manual-testing-playbook/write-safety/read-only-lock.md) | Manual playbook | Operator check of the read lock |

---

## 4. SOURCE METADATA

- Group: Reads And Saved Output
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reads-and-saved-output/read-step-contract.md`

Related references:
- [period-filter-warning.md](period-filter-warning.md) - Makes the default period visible at read time
- [output-guard.md](output-guard.md) - Confines saved read output to the workspace
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
