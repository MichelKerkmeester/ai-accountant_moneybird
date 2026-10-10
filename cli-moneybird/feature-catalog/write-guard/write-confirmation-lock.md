---
title: "Write confirmation lock"
description: "A non-GET request without --confirm-write prints its dry-run line and exits 3 before any real call."
trigger_phrases:
  - "write confirmation lock"
  - "moneybird confirm write"
  - "moneybird guard exit 3"
  - "unconfirmed moneybird write"
version: 1.0.0.0
---

# Write confirmation lock (--confirm-write)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

A non-GET request without --confirm-write prints its dry-run line and exits 3 before any real call.

The lock turns every write into a two-step action. The first run shows what would happen and the second run, with the flag, is the decision.

---

## 2. HOW IT WORKS

After the preview, any method other than GET is a write. Without `--confirm-write` the guard prints the preview line to stderr, explains that the write is held and exits 3. The real CLI call never runs. The lock covers creates, updates, deletes, attachments and custom actions alike, because it reads the method rather than the command name. Repeating the same command with `--confirm-write` moves the request on to the pilot administration gate.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Holds non-GET requests that lack the confirmation flag |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Unconfirmed create exits 3 without a real call |
| [MBD-002](../../manual-testing-playbook/write-safety/unconfirmed-write-blocked.md) | Manual playbook | Operator check of the exit 3 path |

---

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/write-confirmation-lock.md`

Related references:
- [dry-run-first-pass.md](dry-run-first-pass.md) - Produces the preview this lock prints
- [pilot-administration-gate.md](pilot-administration-gate.md) - The gate a confirmed write meets next
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
