---
title: Moneybird migration reference index
description: Execution-order route to all migration phases and shared controls.
trigger_phrases:
  - moneybird migration phase
  - Jortt to Moneybird
  - migration plan index
  - historical bookkeeping migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Moneybird migration reference index

> Execution-order route to every migration phase and its shared controls.

---

## 1. OVERVIEW

Use the last verified gate and the request to select the next phase. Read this index first, then the matching phase file and the [shared mechanisms](./shared-mechanisms.md). Read the [control framework](./control-framework.md) for risk, exceptions, approvals, stop recovery or the dashboard.

---

## 2. PHASE MAP

| Phase | Gate | Reference file |
|---:|---|---|
| 0 | Safety and system setup | [phases-0-to-2.md](./phases-0-to-2.md) |
| 1 | Full source inventory | [phases-0-to-2.md](./phases-0-to-2.md) |
| 2 | Collect missing sources and seed archive | [phases-0-to-2.md](./phases-0-to-2.md) |
| 3 | Reconstruct each source independently | [phases-3-to-5.md](./phases-3-to-5.md) |
| 4 | Cross-reconciliation | [phases-3-to-5.md](./phases-3-to-5.md) |
| 5 | Completeness and anomaly scan | [phases-3-to-5.md](./phases-3-to-5.md) |
| 6 | Design the Moneybird mapping | [phases-6-to-9.md](./phases-6-to-9.md) |
| 7 | Pilot migration | [phases-6-to-9.md](./phases-6-to-9.md) |
| 8 | Historical migration per period | [phases-6-to-9.md](./phases-6-to-9.md) |
| 9 | VAT verification loop | [phases-6-to-9.md](./phases-6-to-9.md) |
| 10 | Year-end check | [phases-10-to-16.md](./phases-10-to-16.md) |
| 11 | Income-tax cross-verification | [phases-10-to-16.md](./phases-10-to-16.md) |
| 12 | Continuity between years | [phases-10-to-16.md](./phases-10-to-16.md) |
| 13 | Year Red Team | [phases-10-to-16.md](./phases-10-to-16.md) |
| 14 | Year lock | [phases-10-to-16.md](./phases-10-to-16.md) |
| 15 | Repeat from oldest to newest year | [phases-10-to-16.md](./phases-10-to-16.md) |
| 16 | Current-year parallel mirror and cutover preparation | [phases-10-to-16.md](./phases-10-to-16.md) |
| 17 | Source freeze and archive readiness | [phases-17-to-18.md](./phases-17-to-18.md) |
| 18 | Switch to live bookkeeping | [phases-17-to-18.md](./phases-17-to-18.md) |
| 19 | Live monthly workflow | [phases-19-to-21.md](./phases-19-to-21.md) |
| 20 | Live VAT-period workflow | [phases-19-to-21.md](./phases-19-to-21.md) |
| 21 | Live yearly workflow | [phases-19-to-21.md](./phases-19-to-21.md) |
| 22 | Migration completion and Jortt decommission | [phase-22-completion.md](./phase-22-completion.md) |

Phases 19 to 21 are recurring loops. They start when Phase 18 passes and continue through the configured monitoring period. Phase 22 is a one-time gate. It requires Phase 18, the first live VAT reconciliation under Phase 20, the monitoring end date and all recurring cycles through that date to pass. Do not cancel Jortt before Phase 22 passes and the Operator records a cancel-or-keep decision.

---

## 3. OLD-TO-NEW PHASE NUMBER MAP

| Previous phase | New phase | Responsibility |
|---:|---:|---|
| 0 to 16 | 0 to 16 | Existing phase numbers remain unchanged. |
| 17 | 18 | Switch to live bookkeeping. |
| 18 | 19 | Live monthly workflow. |
| 19 | 20 | Live VAT-period workflow. |
| 20 | 21 | Live yearly workflow. |
| 21 | 17 and 22 | Split into pre-cutover source freeze and post-monitoring completion. |
| New | 17 | Source freeze and archive readiness. |
| New | 22 | Migration completion and Jortt decommission. |

---

## 4. ROUTING RULES

- Do not advance until the prior gate passes and its evidence is linked in the run journal.
- Keep the exact owner tags on actions and approvals. Operator decisions remain human decisions.
- Use the phase file for its 11-field contract. Use shared mechanisms for write controls, evidence, route behavior and recovery. Use M12 for the Agent runner, Implementer, Verifier, Final reviewer and separate Migration Writer seats.
- Route Jortt reads through [cli-jortt](../../../cli-jortt/SKILL.md). Route Moneybird reads and approved writes through `moneybird-guard`, using the sibling [cli-moneybird](../../../cli-moneybird/SKILL.md) instructions.
- Keep the Moneybird read-only lock enabled in every reader session. An auditfile request follows the guarded report-export route in a separate approved writer session. Never clear the lock in a reader session.
- Load [overview and setup](./overview-and-setup.md) for configuration, workspace structure and numeric threshold approvals.

---

## 5. RELATED REFERENCES

- [Control framework](./control-framework.md) defines roles, risk review, exception handling, dashboard status and completion.
- [Shared mechanisms](./shared-mechanisms.md) defines M1 to M12, the external agent route and the tool route contract.
- [Moneybird bookkeeping](../moneybird-bookkeeping.md) covers accounting treatment for common events.
- [Jortt to Moneybird mapping](./jortt-to-moneybird-mapping.md) covers concept matches and migration traps.
