---
title: Migration data privacy
description: Keeps migration records in migration-workspace and limits private-database reads to a named file during migration.
trigger_phrases:
  - Migration data privacy
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - private database read rule
version: 1.0.0.0
---

# Migration data privacy

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Keeps migration records in migration-workspace and limits private-database reads to a named file during migration.

The project bootstrap and skill set a strict boundary around private finance records. The agent does not list or search the private database and stores migration work only in migration-workspace.

---

## 2. HOW IT WORKS

A request to search private data without naming one specific file is refused without accessing the path. During a migration phase only, a specifically named file may be read without directory listing, wildcard search or traversal. Migration output stays in the designated workspace.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AGENTS.md | Shared | Defines the project privacy and data-location rules. |
| sk-moneybird-accountant/SKILL.md | Shared | Defines the migration privacy exception and output location. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/privacy-boundary.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-data-privacy.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
