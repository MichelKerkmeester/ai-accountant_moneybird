---
title: CLI tool handoff
description: Routes Jortt reads through jortt-cli and Moneybird reads or writes through moneybird-guard.
trigger_phrases:
  - CLI tool handoff
  - API tool handoff
  - jortt-cli handoff
  - moneybird-guard handoff
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
| sk-moneybird-accountant/SKILL.md | Shared | Defines the CLI ownership and write gate. |
| cli-jortt/SKILL.md | Shared | Documents read-only Jortt CLI operations. |
| cli-moneybird/SKILL.md | Shared | Documents guarded Moneybird CLI reads, writes and verification. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/api-tool-handoff.md | Manual playbook | Offline routing scenario for this feature. |
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/cli-failure-blocked.md | Manual playbook | Offline blocked answer scenario after an exhausted CLI read. |
| sk-moneybird-accountant/scripts/cli-failure-handoff-test.sh | Automated test | Proves the Jortt 429 exhaustion, the bounded Moneybird GET attempts, the one authorized migration reissue and the blocked answer contract with a fake curl and the guard stub. |
| sk-moneybird-accountant/scripts/source-to-target-handoff-test.sh | Automated test | Builds a synthetic source manifest, mapping and WRITE_INTENT chain and proves a changed hash or digest fails before a fake call marker. |
| sk-moneybird-accountant/evals/evals.json | Automated test | Holds the cli-read-exhausted-blocked and retry-owner-split cases. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/api-tool-handoff.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
