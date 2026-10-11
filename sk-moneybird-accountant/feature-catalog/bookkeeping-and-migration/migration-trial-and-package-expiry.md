---
title: Migration trial and package expiry
description: Checks trial or paid-package coverage before each non-GET batch and before final verification.
trigger_phrases:
  - trial expiry before write batch
  - Moneybird package expiry
  - migration access window
  - MIG-004
version: 1.0.0.0
---

# Migration trial and package expiry

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Checks the observed trial or package state and expiry before each Moneybird non-GET batch.

The access window must cover the write, synchronization, read-back, and verification. Before Phase 17, the active paid package must cover the next live VAT period and year close.

## 2. HOW IT WORKS

Record state, expiry date, evidence source, observation time, renewal owner, and alert evidence in `MIGRATION_CONFIG`. The Operator reconfirms access before each write batch. Missing, expired, or uncertain access blocks the batch. Recheck access before Phase 22 verification and resolve archive coverage before any lapse.

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines the access-window control and write route. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/overview-and-setup.md | Shared | Lists access and expiry fields, owners, and evidence requirements. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phases-17-to-18.md | Shared | Requires paid-package coverage before the source freeze gate. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/trial-expiry-stop.md | Manual playbook | Offline access-expiry stop scenario. |

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-trial-and-package-expiry.md

Related references:
- [migration-write-keys-and-run-journal.md](migration-write-keys-and-run-journal.md) - Write-batch approval and journal behavior.
- [migration-archive-decommission-gate.md](migration-archive-decommission-gate.md) - Final archive and source-retention decision.
