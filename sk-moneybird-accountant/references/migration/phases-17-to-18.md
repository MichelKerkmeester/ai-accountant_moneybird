---
title: Migration phases 17 to 18
description: Source freeze, archive readiness and the live switch.
nav_label: "Migration phases 17 to 18"
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 17 to 18

Source freeze, archive readiness and the live switch. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 17: Source freeze and archive readiness

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M4](./shared-mechanisms.md#m4-evidence-privacy-and-session-boundary), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M8](./shared-mechanisms.md#m8-jortt-pagination-and-source-request-evidence), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Freeze Jortt for new entries at an Operator-set date, capture the final source delta and prove the independent archive is complete and restorable for every required record class. The Implementer drafts freeze delta extraction and the archive restore test, and the Verifier proves the restore and checks the freeze boundary for Phase 17.

### 2. Nested sub-goals

- **SG-17.1**: Set and apply the source freeze. Check: Operator-approved freeze date and time recorded 1, last included source key at the freeze boundary recorded 1, new Jortt entries after that boundary 0 or captured in a dated delta 100%.
- **SG-17.2**: Capture the final source delta. Check: source page, record, attachment and control-total coverage 100%, unexplained delta items 0.
- **SG-17.3**: Reconcile mandatory archive classes. Check: invoices, expenses, receipts, loose Inbox items, attachments, bank files, XAF files, annual accounts, filed returns, assessments and reconstructed asset schedules accounted for 100%, unexplained exclusions 0.
- **SG-17.4**: Complete and validate each retention rule. Check: Operator-approved source basis, class duration, start event, derived end date, independent archive location, owner and readability evidence 100%, Independent Auditor recomputation matches 100%, unsupported or unapproved rules 0.
- **SG-17.5**: Restore every archive class independently. Check: class restore and readability checks verified by the Independent Auditor 100%, failed class restores 0.
- **SG-17.6**: Preserve target access through verification. Check: active paid package covers the next live VAT period and year close 1, renewal owner and alert evidence recorded 1.

- **SG-17.7**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, archive restore proof pass 1, freeze-boundary violations 0, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 16 passed. The Operator-approved freeze date and source scope are recorded. The access window covers the expected final delta and independent restore verification.

### 4. Inputs

Phase 16 cutover readiness packet, Jortt source inventory, page manifests, source-side totals, attachment and Inbox inventory, XAF and UI exports, retention matrix, and current access evidence.

### 5. Owner-tagged actions

[Operator] sets and applies the freeze, supplies UI exports, approves each situation-dependent retention rule from its source basis, and confirms access and renewal evidence. [Evidence Archivist] captures the final delta, completes class counts and hashes, and assembles the archive. [Independent Auditor] verifies source totals, recomputes retention end dates and restores every class. [Orchestrator] reconciles the gate and updates the dashboard. Gate verifier: [Independent Auditor] verifies completeness and restoration. The Operator does not cancel Jortt in this phase.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts freeze delta extraction and the archive restore test. [Verifier] proves the restore and checks the freeze boundary. [Final reviewer] reviews the phase before Operator approvals.

### 6. Tool route

Jortt API reads use jortt-cli with read scopes and a complete next-link chain. XAF, annual accounts, filed returns and freeze actions use Operator UI. Archive checks use local files under migration-workspace/Archive/. No Jortt write or cancellation is performed.

### 7. Outputs and evidence artifacts

Source freeze decision and timestamp, last source key at the freeze boundary, final delta manifest, boundary reconciliation, independent source-side control totals, mandatory class inventory, byte and link reconciliation, Operator-approved retention matrix with verified end dates, per-class restore reports, access and renewal evidence, and gate checkpoint under Archive/, Manifests/, Reports/, Handoff/, and RunJournal/. The go-live decision belongs to Phase 18 after both reconciliations pass.

### 8. Numeric exit gate

Freeze decision recorded 1, final delta coverage 100%, mandatory class coverage 100%, attachment count, links, bytes and hashes reconciled 100%, unexplained exclusions 0, retention approvals and source basis complete 100%, independently recomputed end dates match 100%, unsupported or unapproved retention rules 0, per-class restore coverage 100%, failed restores 0, package horizon coverage 1, renewal owner and alert evidence 1.

M12 gate: work units with Verifier PASS or Operator disposition 100%, archive restore proof pass 1, freeze-boundary violations 0, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Jortt receives a new entry after the freeze without a captured delta, missing page or independent source total, missing required class, attachment or loose Inbox mismatch, unsupported or unapproved retention basis, duration or start event, failed class restore, or insufficient access window.

Stop on any M12 stop event.

### 10. Rollback or compensation

Keep Jortt uncancelled. If the freeze is disrupted, the Operator records a new freeze date, captures every intervening source change and repeats the affected archive and restore checks before go-live.

### 11. Resume rule

Resume from the last complete source page and class checkpoint. Reconcile its manifest and source total, append a journal event and rerun the affected class restore before the gate is reconsidered.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 18: Switch to live bookkeeping

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M10](./shared-mechanisms.md#m10-write-isolation-decision), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Move authority to Moneybird only after source freeze, final delta reconciliation, archive acceptance and human go-live approval. The Implementer drafts the go-live checklist and final delta batch, and the Verifier checks the final delta and isolation review for Phase 18.

### 2. Nested sub-goals

- **SG-18.1**: Reconcile the final Jortt delta. Check: source and target delta coverage 100%, duplicate delta keys 0.
- **SG-18.2**: Establish live start boundary. Check: boundary date 1, opening and closing balance continuity by account 100%.
- **SG-18.3**: Approve the new authority. Check: final delta manifest and boundary reconciliation both pass 100%, all cutover blockers resolved 0, signed Operator GO recorded only after both checks 1. An open Operator NO-GO is STOPPED and does not pass. A NO-GO stays open until its owner journals a resolution event linked to it.

- **SG-18.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, final delta checks pass 100%, isolation review pass 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phases 16 and 17 passed. Archive is independently readable and the source freeze is recorded. The write-isolation review date is current. M6 access covers any final write, synchronization, read-back and verification.

### 4. Inputs

Signed freeze decision, last source key, final delta manifest, account continuity matrix, archive manifest and rollback plan.

### 5. Owner-tagged actions

`[Migration Writer]` handles only approved final-delta writes. `[Independent Auditor]` verifies the final delta read-back and boundary reconciliation. `[Orchestrator]` confirms both Phase 18 checks pass, archive readiness and zero unresolved cutover blockers. After those records, `[Operator]` may record a signed GO. The Operator may record NO-GO whenever a stop condition is met. A NO-GO records a named owner and resolution path, leaves the phase STOPPED and does not pass the gate. Gate verifier: `[Independent Auditor]` confirms both reconciliations before any signed GO, which `[Operator]` records only after that confirmation.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the go-live checklist and final delta batch. [Verifier] checks the final delta and isolation review. [Final reviewer] reviews the phase before Operator approvals.

**Original live-switch role table retained with decommission moved to Phase 22:**

| Role | System |
|---|---|
| Primary ledger | Moneybird after the Operator approved boundary |
| Primary document archive | Controlled archive with its retention schedule |
| Cash evidence | Official bank statements |
| Filing evidence | Tax portal and stored confirmations |
| Historical source and verification | Jortt read-only data plus the independent archive |

The old instruction to cancel Jortt after the early source download is superseded. Jortt stays read-only and uncancelled until the Operator has passed Phase 22 and recorded a cancel-or-keep decision.

### 6. Tool route

Jortt reads remain CLI read-only. Moneybird reads use guarded read-only access. The final-delta writes use the approved mirror route until the Operator go-live decision passes. After Phase 18 passes, production batches in Phases 19 to 21 require Operator approval and use `--production` with `--approval <ref>`. Tax filing remains Operator-only.

### 7. Outputs and evidence artifacts

Freeze and delta package, live boundary schedule, target read-back and rollback owner record under `Handoff/`, `Snapshots/`, and `RunJournal/`. After both reconciliations pass, record the signed Operator GO. For NO-GO, record STOPPED with a named owner and resolution path.

### 8. Numeric exit gate

Final delta coverage 100%, boundary reconciliation 100%, unexplained boundary differences 0, duplicate keys 0, pending unknown writes 0, archive readiness pass 1, all cutover blockers resolved 0, signed Operator GO after both reconciliations pass 1, live owner and backup assigned 100%.

M12 gate: work units with Verifier PASS or Operator disposition 100%, final delta checks pass 100%, isolation review pass 1, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Source activity after freeze, archive failure, incomplete delta, unknown write, missing compensation owner, an absent or expired write-isolation review, any open Operator NO-GO without a linked resolution event, or missing signed Operator GO after both reconciliations pass. A NO-GO leaves the phase STOPPED with a named owner and resolution path and cannot pass the gate.

Stop on any M12 stop event.

### 10. Rollback or compensation

If no live target entries exist, resume the source ledger under an approved plan. If target entries exist, use the Phase 16 approved compensation or restoration plan and reconcile every post-cutover entry before any reversal.

### 11. Resume rule

Resume from the last confirmed delta checkpoint. For a NO-GO, the named owner resolves each recorded blocker, links its evidence and journals a resolution event that references the NO-GO. The append-only journal keeps the NO-GO, and the resolution event closes it. Recheck the affected Phase 16 or 17 controls, capture any changed source delta and rerun Phase 18.1 through 18.3. No later live phase starts until a new signed GO follows passing delta and boundary checks. A changed freeze date or new source activity invalidates the cutover packet.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.
