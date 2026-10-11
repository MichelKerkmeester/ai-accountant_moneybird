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

Selects the Jortt to Moneybird migration phase, reference, owner tags, and exit gate.

The index lists all 23 phases in execution order and carries the old-to-new phase map. Phase 17 is source freeze, Phase 18 switches to live bookkeeping, Phases 19 to 21 recur after Phase 18, and Phase 22 is a one-time completion and decommission gate.

## 2. HOW IT WORKS

The last verified gate and the request determine the next phase. Load the index, the matching phase file, and shared mechanisms. Load the control framework for gate, risk, exception, stop, or year-lock details. Preserve exact owner tags. Keep Jortt uncancelled until Phase 22 passes and the Operator records a cancel-or-keep decision.

Every phase uses the route contract in `shared-mechanisms.md`. Jortt reads run through jortt-cli only, XAF and other Jortt exports are Operator UI tasks, Moneybird reads run through moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, a Moneybird write needs a passed gate, Operator approval and `--confirm-write`, plus `--production` for a production batch, and an HTTP 429 stops the call sequence for a guarded read-back before any retry.

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Shared | Defines phase detection, reference routing, owner tags, and decommission boundary. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/README.md | Shared | Lists all phases, execution order, and old-to-new map. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines cross-phase controls and the route contract. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phases-17-to-18.md | Shared | Defines source freeze and live switch. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phases-19-to-21.md | Shared | Defines recurring monthly, VAT-period, and yearly loops. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/phase-22-completion.md | Shared | Defines one-time completion and Jortt decision gate. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/migration-phase-routing.md | Manual playbook | Offline phase map and routing scenario. |

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-phase-routing.md

Related references:
- [migration-write-keys-and-run-journal.md](migration-write-keys-and-run-journal.md) - Write gate and uncertain-outcome handling.
- [migration-archive-decommission-gate.md](migration-archive-decommission-gate.md) - Source freeze and completion gate.
- [migration-stop-and-resume.md](migration-stop-and-resume.md) - Stop recovery and checkpoint rules.
