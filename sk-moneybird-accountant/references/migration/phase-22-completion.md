---
title: Migration completion, phase 22
description: One-time completion and Jortt decommission gate.
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration completion, phase 22

One-time completion and Jortt decommission gate. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 22: Migration completion and Jortt decommission

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M4](./shared-mechanisms.md#m4-evidence-privacy-and-session-boundary), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M9](./shared-mechanisms.md#m9-master-phase-dashboard), [M11](./shared-mechanisms.md#m11-stop-state-recovery-matrix), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Close the migration only after cutover, the first live VAT reconciliation, configured monitoring, final archive verification, retention recheck, definition of done, dashboard closure, and an Operator decommission decision. The Implementer drafts the completion report and definition-of-done evidence index, and the Verifier checks definition of done, archive, and retention evidence for Phase 22.

### 2. Nested sub-goals

- **SG-22.1**: Capture the final archive delta after cutover. Check: every post-freeze source change is represented in the final delta manifest with source totals, links, bytes, and hashes 100%, unexplained delta items 0.
- **SG-22.2**: Reverify archive restoration by record class. Check: Independent Auditor restore and readability evidence covers every required class 100%, failed class restores 0.
- **SG-22.3**: Recheck retention. Check: current Operator-approved source basis and rule cover 100% of classes, Independent Auditor recomputes each duration and start event to confirm the end date, archive location, owner, and readability evidence 100%, unsupported or unapproved rules 0.
- **SG-22.4**: Pass the migration definition-of-done gate. Check: required reconciliations and filed-return bridges 100%, unexplained differences 0, accepted exceptions complete 100%, historical years locked 100%, cutover approval 1, live ownership 100%.
- **SG-22.5**: Close the master dashboard. Check: current dashboard rows 23 of 23, missing owners, evidence links, due dates, exception counts, or resume checkpoints 0.
- **SG-22.6**: Record the Operator decommission decision. Check: decision is exactly cancel or keep and is supported by the completed evidence packet 1.

- **SG-22.7**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, definition-of-done items verified 100%, archive recheck pass 1, retention recheck pass 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 18 passed, the first live VAT period has reconciled under Phase 20, the configured monitoring end date has been reached, every configured monthly, VAT-period, and yearly cycle through that date has passed, and no blocking exception remains. Jortt cancellation is not required to enter or pass any other phase.

### 4. Inputs

Phase 17 archive and freeze evidence, all post-cutover source deltas, per-class restore reports, current retention matrix, year locks, filed-return bridges, exception ledger, live cadence reports, dashboard, and Operator decision record.

### 5. Owner-tagged actions

[Evidence Archivist] captures the post-cutover delta and refreshes class manifests. [Operator] confirms any situation-dependent retention rule and basis remain current. [Independent Auditor] independently recomputes retention end dates, verifies each class restore, and records mismatches. [Orchestrator] verifies the migration definition-of-done checklist and master dashboard. [Operator] approves completion and records cancel or keep. Gate verifier: [Independent Auditor] verifies archive and retention evidence. [Orchestrator] verifies completion and dashboard counts. [Operator] owns the decommission decision.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the completion report and definition-of-done evidence index. [Verifier] checks definition of done, archive, and retention evidence. [Final reviewer] reviews the phase before Operator approvals.

### 6. Tool route

Jortt remains read-only through jortt-cli and Operator UI exports until the decision is recorded. Moneybird reads use moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1 and explicit periods. No Jortt cancellation is performed by an agent.

### 7. Outputs and evidence artifacts

Final post-cutover archive delta, per-class restore report, retention recheck, migration definition-of-done record, master dashboard closure, Operator cancel-or-keep decision, and final handoff under Archive/, Manifests/, Reports/, Handoff/, and RunJournal/.

### 8. Numeric exit gate

Phase 18 pass 1, first live VAT reconciliation under Phase 20 pass 1, configured monitoring end reached 1, required recurring cycles complete 100%, final delta coverage 100%, per-class restore coverage 100%, failed restores 0, approved retention basis and schedule coverage 100%, independently recomputed end dates match 100%, unsupported or unapproved rules 0, definition-of-done elements complete 100%, unexplained differences 0, historical lock coverage 100%, live ownership coverage 100%, dashboard rows current 23 of 23, incomplete dashboard fields 0, Operator decision recorded as cancel or keep 1.

M12 gate: work units with Verifier PASS or Operator disposition 100%, definition-of-done items verified 100%, archive recheck pass 1, retention recheck pass 1, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

A required condition is not met, final delta is incomplete, a class cannot be restored, retention source basis is unsupported, a recomputed end date mismatches, or required Operator approval is missing, an unexplained difference or blocking exception remains, a dashboard row is stale, or the Operator has not recorded cancel or keep.

Stop on any M12 stop event.

### 10. Rollback or compensation

Keep Jortt uncancelled while any completion condition fails. Preserve the latest valid archive and dashboard versions. Reopen only affected reconciliation, retention, restore, or live cadence checks. If the Operator chose keep, record the continuing owner and review date. If the Operator chose cancel, the Operator performs that action after this gate.

### 11. Resume rule

Resume from the last verified Phase 22 sub-goal and its journal checkpoint. Recompute changed manifests, rerun affected class restores and retention checks, refresh the dashboard, and repeat the completion gate.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.
