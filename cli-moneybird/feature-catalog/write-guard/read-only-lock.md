---
title: "Read-only lock"
description: "When MONEYBIRD_GUARD_READ_ONLY=1, the guard blocks every non-GET method before the real call and exits 6, even when --confirm-write or --production is present. GET calls still run."
trigger_phrases:
  - "moneybird read-only lock"
  - "MONEYBIRD_GUARD_READ_ONLY"
  - "block moneybird writes"
  - "read-only moneybird session"
version: 1.0.0.0
---

# Read-only lock (MONEYBIRD_GUARD_READ_ONLY)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

When `MONEYBIRD_GUARD_READ_ONLY=1`, `moneybird-guard` blocks every non-GET method before the real CLI call and exits 6. GET calls still run.

## 2. HOW IT WORKS

The guard classifies the request from the CLI dry-run line. The read-only lock then takes precedence over `--confirm-write` and `--production`. Values other than `1` leave the lock off. Moneybird token scopes do not split read access from write access, so read-only roles set this variable for guarded CLI reads.

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Blocks non-GET methods when the environment lock is set |
| [`references/cli.md`](../../references/cli.md) | Reference | Documents exit 6 and lock precedence |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Confirms a flagged production write is blocked and a GET passes |
| [MBD-013](../../manual-testing-playbook/write-safety/read-only-lock.md) | Manual playbook | Checks the read and blocked-write behavior |

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/read-only-lock.md`
