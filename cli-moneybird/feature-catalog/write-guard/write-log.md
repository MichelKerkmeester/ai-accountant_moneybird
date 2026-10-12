---
title: "Write log"
description: "Each confirmed write attempt appends one body-free JSON line with time, method, path, administration, exit status, approval reference, batch key and payload digest under the migration workspace."
trigger_phrases:
  - "write log"
  - "moneybird write log"
  - "moneybird writes jsonl"
  - "body-free write record"
version: 1.0.0.0
---

# Write log (moneybird-writes.jsonl)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Each confirmed write attempt appends one body-free JSON line with time, method, path, administration, exit status, approval reference, batch key and payload digest under the migration workspace.

The log gives the migration a local journal of what was attempted without copying financial content. It holds no request or response body.

---

## 2. HOW IT WORKS

After a confirmed write passes the pilot gate and runs, the guard appends one JSON line to `migration-workspace/logs/moneybird-writes.jsonl` under the Accountant folder. The line holds the UTC time, the method, the API path, the administration ID, the CLI exit status, the approval reference, the batch key and the payload digest. Failed attempts are logged with their nonzero status. The folder is created with an owner-only umask and the file is set to owner-only permissions.

The approval reference, the batch key and the payload digest join the row back to the approved payload. Before a confirmed write reaches the real call, the guard checks this log and refuses a reference and digest pair that already has a row, whatever the row's exit status, and stops with a consumed message. A retry needs a new `WRITE_INTENT` entry.

A successful write also prints the method and path, plus a note that an immediate GET may return cached data, so the write response status is the proof. When the line cannot be appended, the guard says so and still returns the write status.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Builds the JSON line with jq and appends it to the log |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Pilot create logs the join keys without a body field and a replayed pair is refused as consumed |
| [MBD-009](../../manual-testing-playbook/write-safety/pilot-write-is-logged.md) | Manual playbook | Operator check of the log line in a temporary workspace |

---

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/write-log.md`

Related references:
- [payload-bound-approval.md](payload-bound-approval.md) - The digest binding and single-use rule behind the join keys
- [pilot-administration-gate.md](pilot-administration-gate.md) - The gate a logged write has passed
- [delete-caution.md](delete-caution.md) - The extra warning a logged DELETE prints
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
