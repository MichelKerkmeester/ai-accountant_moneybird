---
title: "Pilot administration gate"
description: "A confirmed write must target the pilot administration unless the operator passes --production for an approved batch. Otherwise the guard exits 4."
trigger_phrases:
  - "pilot administration gate"
  - "moneybird pilot administration"
  - "moneybird guard exit 4"
  - "moneybird production flag"
version: 1.0.0.0
---

# Pilot administration gate (--production)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

A confirmed write must target the pilot administration unless the operator passes --production for an approved batch. Otherwise the guard exits 4.

A confirmation cannot move a record into a different administration. The production flag is a separate decision that the operator makes per batch.

---

## 2. HOW IT WORKS

The pilot ID comes only from the `MONEYBIRD_PILOT_ADMINISTRATION_ID=` line in the Accountant folder `.env`. The environment variable of that name is ignored unless the test-only `MONEYBIRD_GUARD_TEST=1` flag is set. That flag is for the offline test suite only. The guard compares it with the administration in the preview path. A mismatch exits 4 and names both IDs. With no pilot set, every confirmed write is treated as production and also exits 4. `--production` lifts the gate and is reserved for a batch the operator has approved.

The guard repeats the preview with the writer session before this comparison, so the gate checks the session that will perform the write. A missing writer configuration stops the write with exit 7 and the guard never falls back to the reader session. A write that passes the gate also needs `--approval <ref>` matching the `approval_reference` of a `WRITE_INTENT` event in `migration-workspace/RunJournal/run-journal.jsonl`, for pilot writes and production writes alike. A missing flag, a missing journal or no match stops the write with exit 8. A write that passes the gates also needs `jq`, which the write log uses.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Compares the preview administration with the pilot ID |
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Shared | Pilot-first recipes and the correction path |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Non-pilot create exits 4, pilot create runs and --production runs |
| [MBD-003](../../manual-testing-playbook/write-safety/production-write-blocked.md) | Manual playbook | Operator check of the exit 4 path |
| [MBD-012](../../manual-testing-playbook/write-safety/pilot-write-and-undo-rehearsal.md) | Manual playbook | Live write and undo on the pilot administration |

---

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/pilot-administration-gate.md`

Related references:
- [write-confirmation-lock.md](write-confirmation-lock.md) - The lock a write passes first
- [write-log.md](write-log.md) - Records every attempt that passes this gate
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
