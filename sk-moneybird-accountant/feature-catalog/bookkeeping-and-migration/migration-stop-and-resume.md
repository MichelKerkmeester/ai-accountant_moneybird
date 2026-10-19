---
title: Migration stop and resume
description: Routes a stopped migration through its owner, evidence, retry rule and closure test.
trigger_phrases:
  - Migration stop and resume
  - resume interrupted write batch
  - migration recovery table
  - stop-state recovery matrix
version: 1.0.0.0
---

# Migration stop and resume

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Stops the affected batch on a falsifiable failure and resumes only from the last verified journal state after its closure test passes.

Every stop records owner, evidence, retry rule and closure condition. An uncertain write requires read-back. It is never blindly retried.

---

## 2. HOW IT WORKS

Classify the stop as an unknown write, rate limit, validation failure, missing source or hash mismatch, stale or incomplete read or reconciliation mismatch. Follow the owner, evidence, retry rule and closure test in the shared stop-state recovery matrix. Keep the exception and run journal append-only.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines journal states and the complete stop-state recovery matrix. |
| sk-moneybird-accountant/references/migration/control-framework.md | Shared | Defines stop conditions, recovery ownership and the resume rule. |
| sk-moneybird-accountant/SKILL.md | Shared | Routes a stopped batch through the last verified checkpoint. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/migration/write-journal-crash-resume.md | Manual playbook | Offline interrupted-write and resume scenario. |
| sk-moneybird-accountant/manual-testing-playbook/migration/migration-stop-and-resume.md | Manual playbook | Scenario MIG-008, the stop-state classification and verified-state resume. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-stop-and-resume.md

Related references:
- [migration-write-keys-and-run-journal.md](migration-write-keys-and-run-journal.md) - Stable key and write-event evidence.
- [migration-phase-routing.md](migration-phase-routing.md) - Phase gate and resume routing.
