---
title: Migration phase routing
description: Selects a Jortt to Moneybird migration phase, its reference, owner tags, and exit gate.
trigger_phrases:
  - Migration phase routing
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - MODE-001
version: 1.0.0.0
---

# Migration phase routing

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Selects a Jortt to Moneybird migration phase, its reference, owner tags, and exit gate.

The skill routes historical Jortt to Moneybird work to a phase-group reference and its gate. The index maps phase groups, while the control framework carries cross-phase verification and stop conditions.

---

## 2. HOW IT WORKS

The operator request and last passed exit gate determine the current phase. The agent loads the migration index, one phase group, and the control framework when gate, risk, exception, or year-lock details apply. Each source plan owner tag remains attached to its step.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Shared | Defines phase detection, reference routing, owner-tag handling, and gate behavior. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/README.md | Shared | Maps phase ranges to the preserved migration references. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phases-3-to-5.md | Shared | Carries the reconstruction and reconciliation phase group. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/migration-phase-routing.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-phase-routing.md

Related references:
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
- [year-specific-zzp-guidance.md](year-specific-zzp-guidance.md) - Related workflow behavior.
