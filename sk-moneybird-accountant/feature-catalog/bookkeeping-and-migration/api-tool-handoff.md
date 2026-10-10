---
title: CLI tool handoff
description: Routes Jortt reads through jortt-cli and Moneybird reads or writes through moneybird-guard.
trigger_phrases:
  - API tool handoff
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - API-001
version: 1.0.0.0
---

# CLI tool handoff

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Routes Jortt reads through jortt-cli and Moneybird reads or writes through moneybird-guard.

The skill does not reproduce CLI mechanics. It hands Jortt reads to jortt-cli and Moneybird reads or writes to moneybird-guard through cli-jortt and cli-moneybird.

---

## 2. HOW IT WORKS

Before any CLI action, the agent loads the sibling tool skill that owns the requested system and operation. Jortt remains read-only. A Moneybird write also needs the active migration gate and operator approval.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Shared | Defines the CLI ownership and write gate. |
| AI Systems/Moneybird Accountant/cli-jortt/SKILL.md | Shared | Documents read-only Jortt CLI operations. |
| AI Systems/Moneybird Accountant/cli-moneybird/SKILL.md | Shared | Documents guarded Moneybird CLI reads, writes, and verification. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/api-tool-handoff.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/api-tool-handoff.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
