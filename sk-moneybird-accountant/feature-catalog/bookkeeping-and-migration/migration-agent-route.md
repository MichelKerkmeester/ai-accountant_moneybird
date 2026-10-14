---
title: Migration agent route
description: Defines the M12 external agent route for migration work units.
trigger_phrases:
  - Migration agent route
  - M12 external agent route
  - migration agent verification
  - summaries-only migration checks
version: 1.0.0.0
---

# Migration agent route

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Migration work units follow M12 through the Agent runner, Implementer, Verifier and Final reviewer seats. The Operator keeps approvals, local sensitive-record review and the phase decision.

---

## 2. HOW IT WORKS

Every seat receives typed allowlisted summaries only. Local role sessions and sandboxed scripts perform record-level work. The Verifier owns independent fixtures, privacy filtering, payload scanning and the adversarial corpus. Each phase requires a work-unit verdict or Operator disposition, a passing phase-entry boundary canary, a clean payload scan and Final review PASS. The separate Claude Migration Writer session keeps the existing write gates and approvals.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Shared | Defines M12 seats, privacy, loop, journal, stops and rollback. |
| sk-moneybird-accountant/references/migration/control-framework.md | Shared | Maps functional roles to seats and names the per-record verification owner. |
| sk-moneybird-accountant/references/migration/overview-and-setup.md | Shared | Defines AgentDesk and Operator-owned agent configuration. |
| sk-moneybird-accountant/references/migration/phases-0-to-2.md | Phase contract | Defines the Phase 0 route proof. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/migration-agent-route.md | Manual playbook | Checks the M12 seats, summaries-only boundary and verified-state resume rule without service calls. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-agent-route.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Phase selection and owner-tagged gates.
- [migration-data-privacy.md](migration-data-privacy.md) - Local record boundary and private data rules.
- [migration-write-keys-and-run-journal.md](migration-write-keys-and-run-journal.md) - Write approval and journal recovery.
