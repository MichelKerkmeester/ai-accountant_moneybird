---
title: Moneybird migration reference index
description: Phase map for historical Jortt to Moneybird work, with the migration phase groups and control reference.
trigger_phrases:
  - moneybird migration phase
  - jortt to moneybird
  - migration plan index
  - historical bookkeeping migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Moneybird migration reference index

This index routes historical bookkeeping work to the phase group that owns its instructions and gate. The phase files preserve the migration plan body text.

---

## 1. OVERVIEW

Use the last documented passed exit gate and the request to identify the current phase. Read this index first, then load the smallest applicable phase group. Preserve the plan's owner tags: [Operator], [AI], and [Operator + AI].

---

## 2. PHASE MAP

| Plan area | Reference |
|---|---|
| Opening, goal, tools, work folders, and materiality thresholds | [overview-and-setup.md](./overview-and-setup.md) |
| Phases 0 to 2: setup, inventory, and source collection | [phases-0-to-2.md](./phases-0-to-2.md) |
| Phases 3 to 5: reconstruction, reconciliation, and anomalies | [phases-3-to-5.md](./phases-3-to-5.md) |
| Phases 6 to 9: mapping, pilot, historical quarters, and VAT verification | [phases-6-to-9.md](./phases-6-to-9.md) |
| Phases 10 to 16: year-end, cross-checks, continuity, review, and locking | [phases-10-to-16.md](./phases-10-to-16.md) |
| Phases 17 to 20: transition to live bookkeeping | [live-workflows-phases-17-to-20.md](./live-workflows-phases-17-to-20.md) |
| Agent roles, verification loop, risk model, exception handling, stop conditions, dashboard, first runs, and completion | [control-framework.md](./control-framework.md) |

---

## 3. ROUTING RULES

- Never advance until the previous phase's exit gate has passed.
- Preserve the owner tag on every step. Operator-only actions stay with the operator.
- Load the control framework when checking a gate, handling an exception, reviewing a risk, or locking a year.
- Route Jortt API reads to [cli-jortt](../../../cli-jortt/SKILL.md).
- Route Moneybird API reads and writes to [cli-moneybird](../../../cli-moneybird/SKILL.md).
- The references are the migration policy and work sequence. The sibling tool skills own API mechanics.

---

## 4. RELATED RESOURCES

- [Moneybird bookkeeping](../moneybird-bookkeeping.md) covers accounting treatment for common events.
- [Jortt to Moneybird mapping](../jortt-to-moneybird-mapping.md) covers concept matches and migration traps.
