---
title: Migration auditfile export route
description: Routes an auditfile request through the documented export path while preserving the read-only lock.
trigger_phrases:
  - Migration auditfile export route
  - Moneybird auditfile under read-only lock
  - auditfile export route
  - read-only migration session
version: 1.0.0.0
---

# Migration auditfile export route

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Uses the verified Operator UI route for a Moneybird auditfile by default and preserves the global read-only lock for analysis sessions.

A guarded POST is permitted only through an operation-scoped export allowance with a named route, approval and artifact receipt hash.

---

## 2. HOW IT WORKS

Verify the export route in Phase 0. For a later auditfile request, load the documented route and keep `MONEYBIRD_GUARD_READ_ONLY=1` in the analysis session. The Operator UI route is preferred. Never weaken the global lock. If the approved scoped POST route is used, capture approval, the completion receipt and the artifact SHA-256.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines the auditfile route and lock boundary. |
| sk-moneybird-accountant/references/migration/overview-and-setup.md | Shared | Defines Phase 0 route verification and config evidence. |
| sk-moneybird-accountant/references/migration/phases-10-to-16.md | Shared | Uses the verified auditfile route for annual checking. |
| sk-moneybird-accountant/references/yearly-overview/preparation-checklist.md | Shared | Puts the auditfile export before the jaarafsluiting as an evidence gate. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/auditfile-read-only-route.md | Manual playbook | Offline auditfile routing and lock-preservation scenario. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-auditfile-export-route.md

Related references:
- [api-tool-handoff.md](api-tool-handoff.md) - CLI ownership boundary.
- [migration-phase-routing.md](migration-phase-routing.md) - Phase 0 route-verification gate.
