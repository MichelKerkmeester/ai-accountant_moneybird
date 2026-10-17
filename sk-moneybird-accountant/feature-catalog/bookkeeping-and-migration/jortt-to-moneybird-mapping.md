---
title: Jortt to Moneybird mapping
description: Explains the Jortt to Moneybird concept mapping and the source-export traps that a migration route depends on.
trigger_phrases:
  - Jortt to Moneybird mapping
  - concept mapping
  - Jortt export traps
  - which account maps where
  - jortt-to-moneybird-mapping.md
version: 1.0.0.0
---

# Jortt to Moneybird mapping

## 1. OVERVIEW

Explains the Jortt to Moneybird concept mapping and the source-export traps that a migration route depends on.

`references/migration/jortt-to-moneybird-mapping.md` is the read set for the T2 migration concept row. It maps the Jortt concepts that carry into Moneybird and names the traps in the source exports that a mapping choice depends on.

---

## 2. HOW IT WORKS

The guide covers the concept mapping and the source-system export traps, including attachments, the asset list and categories with the opening balance. It closes with the migration checks that prove a mapping is complete.

The route never maps a Jortt category to Moneybird by label alone. It maps by accounting purpose and tax treatment. The guide points to the phase references for the phase that applies a mapping, so a concept question does not advance a phase.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| `sk-moneybird-accountant/references/migration/jortt-to-moneybird-mapping.md` | Shared | Defines the concept mapping, the export traps and the migration checks. |
| `sk-moneybird-accountant/ROUTER.md` | Shared | Routes a migration concept request to this reference in the T2 row. |
| `sk-moneybird-accountant/references/migration/README.md` | Shared | Places the mapping guide in the phase route. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| `sk-moneybird-accountant/scripts/check-route-table.py` | Test harness | Checks the T2 read set that names this reference. |
| `sk-moneybird-accountant/manual-testing-playbook/offline-routing/api-tool-handoff.md` | Manual playbook | Reads the mapping guide as part of its offline command sequence. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/jortt-to-moneybird-mapping.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Phase selection and gate routing.
- [task-type-routing.md](task-type-routing.md) - The T2 row that reads this guide.
