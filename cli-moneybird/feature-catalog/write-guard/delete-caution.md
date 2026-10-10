---
title: "Delete caution"
description: "A successful DELETE prints a warning that 204 can mean nothing was deleted and asks for a separate read."
trigger_phrases:
  - "delete caution"
  - "moneybird delete caution"
  - "moneybird 204 delete"
  - "moneybird separate read after delete"
version: 1.0.0.0
---

# Delete caution (DELETE)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

A successful DELETE prints a warning that 204 can mean nothing was deleted and asks for a separate read.

Some Moneybird DELETE endpoints answer 204 even when nothing was removed. The warning keeps that status from being read as proof.

---

## 2. HOW IT WORKS

A DELETE goes through the same preview, confirmation lock and pilot gate as any other write. When it succeeds, the guard adds a line that a 204 response can mean nothing was deleted and that a separate read must confirm the removal. The guard does not run that read itself. The operator confirms absence with a later GET or synchronization read, as the correction recipe describes.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Prints the 204 caution after a successful DELETE |
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Shared | Correction recipe with the separate read |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | DELETE prints the 204 caution and the separate-read instruction |
| [MBD-004](../../manual-testing-playbook/write-safety/delete-needs-separate-read.md) | Manual playbook | Operator check of the caution with the stub |
| [MBD-012](../../manual-testing-playbook/write-safety/pilot-write-and-undo-rehearsal.md) | Manual playbook | Live delete and read-back on the pilot administration |

---

## 4. SOURCE METADATA

- Group: Write Guard
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `write-guard/delete-caution.md`

Related references:
- [write-log.md](write-log.md) - Logs the DELETE attempt
- [pilot-administration-gate.md](pilot-administration-gate.md) - Keeps deletes on the pilot
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
