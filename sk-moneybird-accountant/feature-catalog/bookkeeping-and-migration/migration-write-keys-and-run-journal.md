---
title: Migration write keys and run journal
description: Defines stable local write keys and append-only run-journal evidence for each migration batch.
trigger_phrases:
  - Migration write keys and run journal
  - migration write key
  - migration run journal
  - WRITE_INTENT run journal
version: 1.0.0.0
---

# Migration write keys and run journal

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Uses a stable local write key and an append-only journal to make each migration write traceable and recoverable.

The plan requires a durable `WRITE_INTENT` before every non-GET call except a synchronization fetch, which only reads. An uncertain result is reconciled with source-reference and planned-field read-back before any retry.

---

## 2. HOW IT WORKS

The writer records the source and target aliases, object type, source key, schema version, input hash, planned payload hash, state, approval, evidence path and returned target ID. The mapping schema version is stored beside the stable key and does not change that key. On restart, resume from the last verified journal state. Never blindly replay an uncertain write.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines stable keys, durable intent, journal states and uncertain-write recovery. |
| sk-moneybird-accountant/references/migration/phases-6-to-9.md | Shared | Defines pilot and historical batch write and read-back gates. |
| sk-moneybird-accountant/SKILL.md | Shared | Routes writes through the gate, approval, access check and journal. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/migration/write-journal-crash-resume.md | Manual playbook | Offline crash and uncertain-outcome routing scenario. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-write-keys-and-run-journal.md

Related references:
- [migration-stop-and-resume.md](migration-stop-and-resume.md) - Recovery after a stopped or interrupted batch.
- [migration-phase-routing.md](migration-phase-routing.md) - Phase gates and write routing.
