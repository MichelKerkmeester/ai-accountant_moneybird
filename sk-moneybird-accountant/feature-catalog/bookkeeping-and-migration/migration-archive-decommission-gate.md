---
title: Migration archive and decommission gate
description: Keeps Jortt available until final archive, monitoring and completion checks pass.
trigger_phrases:
  - Migration archive and decommission gate
  - archive restore and Jortt cancellation
  - migration decommission gate
  - cancel Jortt
version: 1.0.0.0
---

# Migration archive and decommission gate

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Keeps the source administration read-only and uncancelled until Phase 22 passes and the Operator records a cancel-or-keep decision.

Phase 17 freezes the source and proves archive readiness. Phase 22 rechecks the final delta, class restoration, retention, completion evidence and recurring monitoring.

---

## 2. HOW IT WORKS

A request to cancel Jortt before Phase 22 passes is refused and routed to the one-time completion gate. Cancellation remains an Operator action after the gate. Preserve independent archive manifests, source totals, checksums, restore reports, retention evidence and the final decision record.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/migration/phases-17-to-18.md | Shared | Defines source freeze and pre-cutover archive readiness. |
| sk-moneybird-accountant/references/migration/phase-22-completion.md | Shared | Defines post-monitoring completion and the Operator decision. |
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines source manifests, archive, access window and dashboard controls. |
| sk-moneybird-accountant/SKILL.md | Shared | Prevents early Jortt cancellation. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/migration/jortt-decommission-gate.md | Manual playbook | Offline refusal and Phase 22 routing scenario. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-archive-decommission-gate.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Phase selection and gate routing.
- [migration-trial-and-package-expiry.md](migration-trial-and-package-expiry.md) - Access coverage through writes and verification.
