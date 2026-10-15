---
title: Migration phases 10 to 16
description: Annual checks, continuity, locking and cutover preparation.
nav_label: "Migration phases 10 to 16"
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 10 to 16

Annual checks, continuity, locking and cutover preparation. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 10: Year-end check

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Prove the annual mirror against ledger, bank, source documents, filed VAT and annual accounts. The Implementer drafts the year-end comparison, and the Verifier independently recomputes year-end values for Phase 10.

### 2. Nested sub-goals

- **SG-10.1**: Compare annual reports. Check: required report classes and account rows compared 100%.
- **SG-10.2**: Generate or obtain a Moneybird XAF 4.0. Check: year and version match 1, the route actually used is verified, either the Phase 0 Operator UI route or the pinned guarded POST route with its Operator approval and flushed WRITE_INTENT 1, artifact receipt and SHA-256 recorded 1. Year-end closing entries in the exported year at export time 0, or the closing entry was removed before export and restored after it 1. Per Moneybird help reviewed on 2026-10-11, an auditfile downloaded after the year-end closing may lack the profit-and-loss data.
- **SG-10.3**: Reconcile account and period totals. Check: unexplained differences 0 and approved exception count equals the exception ledger.

- **SG-10.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, year-end recompute differences 0, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Periods for the year have passed Phase 9. The year is open for required corrections. The Phase 0 Operator UI auditfile export and export-only approval are current. Any guarded report-export POST in this phase follows the passed Phase 9 gate and requires exact Operator approval plus a flushed operation-scoped WRITE_INTENT.

### 4. Inputs

Source XAF, bank statements, canonical dataset, Moneybird reports, tax reconciliations, mapping and exception ledger.

### 5. Owner-tagged actions

[Independent Auditor] runs account-level comparisons. [Mapping Agent] maps source accounts. [Operator] approves the exact guarded report-export request, year and version after the Phase 9 gate. [Migration Writer] flushes an operation-scoped WRITE_INTENT containing the requested operation, payload hash and approval reference, then uses the separate writer session for that report export with `--approval <ref>`. [Red Team] checks missing accounts and periods. Gate verifier: [Independent Auditor] verifies the receipt, artifact hash and mapped account comparisons. The export approver cannot grant general write access to analysis sessions.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the year-end comparison. [Verifier] independently recomputes year-end values. [Final reviewer] reviews the phase before Operator approvals.

**Annual comparison steps retained from the original year-end check:**
1. [Independent Auditor] Request and compare one reporting year at a time.
2. [Reconciliation Agent] Compare bank closing balances per account with the official bank evidence.
3. [Reconciliation Agent] Compare revenue across documents, XAF, annual accounts and Moneybird.
4. [Reconciliation Agent] Compare costs by approved main group.
5. [VAT Agent] Confirm all assigned VAT periods and declarations passed.
6. [Independent Auditor] Compare asset purchase, historic processing, depreciation and book value.
7. [Reconciliation Agent] Review private deposits, withdrawals and business costs paid privately.
8. [Tax Filing Agent] Bridge Moneybird, XAF, annual accounts and filed income-tax evidence.
9. [Independent Auditor] Check bank, receivables, payables, VAT, assets, depreciation, debts and equity by account.
10. [Operator] Prefer the documented UI auditfile route or approve the operation-scoped route in the route contract. Compare target XAF 4.0 with the source XAF at mapped account level and explain each difference.
11. [Orchestrator] Record whether an optional Jortt ledger printout is available and usable. No gate relies on an unverified printout.

### 6. Tool route

Moneybird report reads use guarded read-only access with explicit year. The first guarded auditfile report-export POST occurs only after the Phase 9 gate passes, using the exact Operator approval, a flushed operation-scoped WRITE_INTENT, `--confirm-write`, and `--approval <ref>` for that entry in a separate approved writer session. The pinned route and dry-run must match the approved report operation and version. Download and hash the completed artifact in a separate locked reader session. Never clear the read-only lock in a reader session. Jortt XAF is Operator UI-only.

### 7. Outputs and evidence artifacts

Year check report, source and target XAF hashes, account crosswalk, balance and profit reports, auditfile export receipt and artifact hash, ledger printout capability decision, and linked exceptions.

### 8. Numeric exit gate

Annual comparisons 100%, XAF version check 1, source and target account mappings 100%, export receipt and hash 1, unverified ledger printout dependencies 0, unexplained account differences 0, unresolved material exceptions 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, year-end recompute differences 0, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Incomplete source export, report period ambiguity, guarded export route not verified, job incomplete, or artifact receipt or hash missing, missing receipt or artifact hash, unsupported account mismatch, unverified general-ledger printout dependency, missing filed evidence, or threshold not approved.

Stop on any M12 stop event.

### 10. Rollback or compensation

No deletion of year evidence. Reopen the affected report as a new version. Accounting corrections require an exception and approved correction entry.

### 11. Resume rule

Resume from the last complete annual report hash. Re-run any report whose source, mapping, period or export hash changed.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 11: IB cross-verification

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Bridge commercial accounting figures to actual filed income-tax figures and assessments without inventing adjustments. The Implementer drafts the income-tax bridge template, and the Verifier checks the bridge and confirms no adjustment was invented for Phase 11.

### 2. Nested sub-goals

- **SG-11.1**: Prepare year-by-year profit bridge. Check: commercial-to-tax bridge rows with evidence 100%.
- **SG-11.2**: Link filed return and assessment evidence or approved unavailability. Check: available evidence links 100%, each unavailable item has NOT_AVAILABLE or PENDING status with Operator or adviser approval 100%, unapproved evidence gaps 0.
- **SG-11.3**: Resolve tax differences. Check: unexplained bridge rows 0, operator or adviser approvals 100%.

- **SG-11.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, bridge checks pass 100%, invented adjustments 0, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 10 year reports are complete. Available filing evidence is linked. Evidence that is genuinely unavailable has an explicit status and Operator or adviser decision.

### 4. Inputs

Moneybird profit and balance reports, annual accounts, filed IB return and assessment where available, approved NOT_AVAILABLE or PENDING status evidence, fiscal adjustment schedule, and tax register.

### 5. Owner-tagged actions

`[Tax Filing Agent]` prepares the bridge. `[Operator]` or adviser reviews tax adjustments and any judgment. `[Independent Auditor]` checks arithmetic and source evidence. Gate verifier: `[Tax Filing Agent]` prepares. `[Operator]` or adviser decides. `[Independent Auditor]` verifies calculations and links.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the income-tax bridge template. [Verifier] checks the bridge and confirms no adjustment was invented. [Final reviewer] reviews the phase before Operator approvals.

**Filed income-tax comparison retained from the original bridge:**
Compare commercial results from Moneybird with annual accounts and actual filed income-tax values and assessments. Record each fiscal adjustment separately with its evidence and decision owner. Jortt has no income-tax report route in the current tool contract. Never add an unknown ledger item to force equality with a tax return.

| Comparison item | Moneybird | Annual accounts | Filed return or assessment |
|---|---|---|---|
| Commercial profit | Evidence and value | Evidence and value | Actual filed evidence or approved unavailable state |
| Fiscal adjustment | Linked schedule row | Supporting evidence | Decision owner and rationale |
| Tax profit | Recomputed total | Applicable annual value | Assessment evidence where available |


### 6. Tool route

Moneybird reads use `moneybird-guard` with read-only lock and explicit year. Filed return and assessment access uses the appropriate Operator portal or stored workspace artifact. No agent files or pays tax.

### 7. Outputs and evidence artifacts

Year-specific commercial-to-tax bridge, evidence index, adjustment schedule, review decision and linked exceptions under `Reports/` and `Exceptions/`.

### 8. Numeric exit gate

Bridge coverage 100%, available evidence links 100%, approved unavailable statuses 100%, arithmetic difference after named adjustments 0, unexplained bridge rows 0, human approvals 100%.

M12 gate: work units with Verifier PASS or Operator disposition 100%, bridge checks pass 100%, invented adjustments 0, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

No filed evidence and no approved unavailable status, tax judgment unresolved, assessment missing when required without an approved alternative, unexplained adjustment or request to force ledger profit to match a tax return.

Stop on any M12 stop event.

### 10. Rollback or compensation

Preserve the prior bridge and issue an amended version linked to its evidence. Ledger changes need a separate approved correction workflow.

### 11. Resume rule

Resume at the first unapproved bridge row after checking source and configuration hashes. A later return or assessment reopens only its affected bridge rows.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 12: Continuity between years

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Prove balance continuity account by account and preserve open-item settlement tracking. The Implementer drafts the continuity checker, and the Verifier checks each account boundary independently for Phase 12.

### 2. Nested sub-goals

- **SG-12.1**: Compare each continuing balance-sheet account. Check: mapped account coverage 100%, unexplained account differences 0.
- **SG-12.2**: Carry and age invoice-level open receivables and payables. Check: settled items linked to the same source item 100%, still-open items have aging and status coverage 100%, future settlements not yet due remain explicitly open, duplicate links 0.
- **SG-12.3**: Verify start-year opening position. Check: account lines and source components compared 100%, pre-business funds treatment approved 1, unexplained opening lines 0.

- **SG-12.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, account-by-account continuity check coverage 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 10 and 11 passed for year N. Phase 6 opening and subledger schedules are approved.

### 4. Inputs

Closing and opening balances, account mapping, bank statement balances, VAT and asset schedules, loans, equity, open-item aging, and journal read-back.

### 5. Owner-tagged actions

`[Reconciliation Agent]` builds the continuity matrix and records the supported start date, each opening account component and source, and treatment of pre-business funds. `[Independent Auditor]` verifies each account and open item. `[Operator]` approves the first-business-year rule and any judgmental entry. Gate verifier: `[Reconciliation Agent]` prepares. `[Independent Auditor]` verifies account and item-level equality. `[Operator]` approves judgmental entries.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the continuity checker. [Verifier] checks each account boundary independently. [Final reviewer] reviews the phase before Operator approvals.

**Year boundary details retained from the original continuity check:**
Compare each mapped balance-sheet account's prior closing balance with the next opening balance, using the account mapping and source schedule. Do not create another opening balance for later years in the same administration. The only opening position is at the configured migration start boundary. Preserve future settlements as open until evidence clears the same source item.

### 6. Tool route

Moneybird reads use guarded CLI with explicit periods and sync as needed. Any opening journal write follows M2, M3, M6 and the guarded write route. UI lock status is not changed here.

### 7. Outputs and evidence artifacts

Account-level continuity matrix, open AR/AP schedule, settlement links, opening-journal sync read-back and exceptions under `Reports/`, `Registers/`, and `Snapshots/`.

### 8. Numeric exit gate

Continuing account coverage 100%, open-item schedule and aging coverage 100%, settled-item linkage 100%, unbalanced opening journal count 0, unexplained account differences 0, unsupported opening lines 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, account-by-account continuity check coverage 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Any account mismatch without named support, total-only AR/AP opening, missing first-year opening evidence, settlement that does not clear the same source item or still-open item without aging status.

Stop on any M12 stop event.

### 10. Rollback or compensation

Retain prior schedules. Correct a target posting only through an approved linked reversal or adjustment and verify it later. Do not create a balancing entry to erase a difference.

### 11. Resume rule

Resume at the first account or open-item key not marked reconciled. Recompute dependent schedule hashes after a correction. Verify later settlement links as they occur in the monthly and VAT-period workflows.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 13: Year Red Team

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Independently attempt to falsify year completeness, classification and reconciliation results. The Implementer drafts fixes for Red Team findings only, and the Verifier runs the Red Team from a clean working copy without earlier findings, verdicts or final reviews for Phase 13.

### 2. Nested sub-goals

- **SG-13.1**: Review every high-risk item and boundary item. Check: required challenge population reviewed 100%.
- **SG-13.2**: Apply the approved reproducible sample to other items. Check: approved population and selection rule match 1, sample meets the configured minimum size 1, sample completed 100%, unexplained mismatches 0, sample configuration hash matches 1.
- **SG-13.3**: Resolve findings. Check: unresolved material findings 0.

- **SG-13.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, Red Team checks in a clean working copy completed 100%, unresolved findings have Operator disposition 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phases 10 through 12 passed. Frozen source and target manifests are available.

### 4. Inputs

Original sources, year snapshot, exception ledger, filed evidence and risk-based sample configuration.

### 5. Owner-tagged actions

`[Red Team]` challenges the year. `[Independent Auditor]` validates population and sample. `[Operator]` accepts or rejects residual differences. Gate verifier: `[Red Team]` owns challenge evidence. `[Independent Auditor]` verifies sample reproducibility. `[Operator]` owns residual acceptance.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts fixes for Red Team findings only. [Verifier] checks the year as Red Team from a clean working copy without earlier findings, verdicts or final reviews. [Final reviewer] reviews the phase before Operator approvals.

**Year challenge checkpoints retained from the original Red Team pass:**
Challenge missing or duplicate invoices, duplicate bank transactions, December to January cut-off, missing credit notes, unusual suppliers, reverse charge, private items, assets and depreciation, tax payments, internal transfers, unexplained journals, profit differences, and balance differences. Use a separate read-only session and the configured reproducible sample.

### 6. Tool route

Moneybird reads use guarded CLI, `MONEYBIRD_GUARD_READ_ONLY=1`, and explicit periods. Source evidence remains in the sealed workspace.

### 7. Outputs and evidence artifacts

`RED_TEAM_YEAR_REPORT`, sample selection evidence, new exceptions and final resolution links under `Reviews/`, `Reports/`, and `Exceptions/`.

### 8. Numeric exit gate

High-risk coverage 100%, approved minimum sample size met 1, sample completion 100%, unexplained sample mismatches 0, unresolved material findings 0, unsupported accepted exceptions 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, Red Team checks in a clean working copy completed 100%, unresolved findings have Operator disposition 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Sample population changed, missing evidence, any duplicate, unresolved tax or cut-off issue, or any unexplained material finding.

Stop on any M12 stop event.

### 10. Rollback or compensation

No Moneybird mutation. Reopen only impacted findings. Corrections return to the approved correction path and require another read-back.

### 11. Resume rule

Resume from the last verified sample key if the population hash is unchanged. If it changed, regenerate the sample from the approved rule.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 14: Year lock

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M10](./shared-mechanisms.md#m10-write-isolation-decision), [M11](./shared-mechanisms.md#m11-stop-state-recovery-matrix), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Lock a verified year and preserve a sealed evidence snapshot. The Implementer drafts snapshot sealing and the hash manifest, and the Verifier recomputes snapshot hashes for Phase 14.

### 2. Nested sub-goals

- **SG-14.1**: Verify all prerequisite gates. Check: prerequisite gates passed 100%, open exceptions above approved threshold 0.
- **SG-14.2**: Seal year evidence and source configuration. Check: snapshot includes the `MIGRATION_CONFIG` hash and source-manifest references 100%, snapshot artifacts with matching hashes 100%, read-only state after lock 1, missing source-manifest links 0.
- **SG-14.3**: Confirm pilot lock behavior and current year lock state. Check: Phase 7 lock matrix covers every used record class 100%, current lock read-back 1, live non-GET probes in the locked year 0.
- **SG-14.4**: Handle post-lock assessments and corrections. Check: exception, evidence, Operator or adviser filing decision, authorized unlock, linked correction, fresh read-back, and relock evidence present 100%.

- **SG-14.5**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, snapshot hash recomputation matches 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phases 10 through 13 passed. Exception owners and expiry dates are current. No pending write state exists.

### 4. Inputs

Annual reports, VAT and IB bridges, continuity matrix, red-team report, source manifests, schema hashes, write journal, and exception ledger.

### 5. Owner-tagged actions

[Operator] locks the year in Moneybird UI and approves each later unlock. [Independent Auditor] checks snapshot hashes, confirms the Phase 7 lock matrix, reads period_locked_until and verifies relock. [Tax Filing Agent] routes later assessments to the Operator or adviser. [Orchestrator] records gate status. Gate verifier: [Independent Auditor] verifies lock behavior and assessment lifecycle evidence.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts snapshot sealing and the hash manifest. [Verifier] recomputes snapshot hashes. [Final reviewer] reviews the phase before Operator approvals.

**Lock and snapshot details retained from the original year-lock procedure:**
Before locking, confirm document completeness, processed invoices, explained material ledger entries, exact bank reconciliation, verified VAT periods, balance and profit checks, income-tax bridge, and Red Team clearance.
[Operator] locks or unlocks through the UI. [Independent Auditor] reads the lock state through the guarded read-only route and confirms the Phase 7 probe results. Do not issue a live non-GET probe in a locked historical year. A later assessment opens a linked exception and requires an Operator or adviser decision, an authorized unlock, a linked correction, fresh read-back and confirmed relock.
Include the source manifest and invoice register, canonical records, exception ledger, Moneybird XAF and annual reports, general-ledger export, VAT and income-tax reconciliations, Red Team report, final verification report, write journal, `MIGRATION_CONFIG` hash, and source-manifest references in the sealed snapshot. After lock confirmation, make the snapshot read-only. Any later change creates a new version and invalidates dependent checks.

### 6. Tool route

Period lock and unlock are UI-only. Read lock status through `moneybird-guard` with `MONEYBIRD_GUARD_READ_ONLY=1`. Do not assume all record types are protected beyond documented behavior.

### 7. Outputs and evidence artifacts

Sealed read-only year snapshot with configuration and source-manifest references, snapshot checksum manifest, Phase 7 per-record-class lock probe results, current lock-state read-back, exception acceptance register, post-lock assessment record and gate event.

### 8. Numeric exit gate

Prerequisite coverage 100%, configuration and manifest binding 100%, snapshot hash coverage 100%, Phase 7 record-class probe coverage 100%, current lock-state read-back 1, live non-GET probes in locked year 0, unapproved unlocks 0, assessment lifecycle links 100%, unresolved material exceptions 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, snapshot hash recomputation matches 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Any prerequisite not passed, hash mismatch, open unknown write, missing Phase 7 lock evidence, unsupported lock behavior for a required record class, missing Operator approval, missing assessment decision owner or absent relock confirmation.

Stop on any M12 stop event.

### 10. Rollback or compensation

A locked year is never silently edited. A later assessment opens a linked exception with source evidence and Operator or adviser filing decision. The Operator authorizes any unlock. Corrections use linked reversal or adjustment, fresh read-back and verified relock.

### 11. Resume rule

Resume from the last snapshot hash and lock-state event. After a change, create a new immutable read-only snapshot and repeat every dependent check.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 15: Repeat from oldest to newest year

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M9](./shared-mechanisms.md#m9-master-phase-dashboard), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Complete historical years in deterministic chronological order without parallel year writes. The Implementer drafts the year-advance checklist, and the Verifier checks prior-year lock evidence for Phase 15.

### 2. Nested sub-goals

- **SG-15.1**: Process years from the approved start year forward. Check: completed year sequence has no skips, skipped year count 0.
- **SG-15.2**: Verify each year lock before advancing. Check: locked years advanced 100%, overlapping active year batches 0.
- **SG-15.3**: Carry prior closing balances. Check: Phase 12 passed for each boundary 100%.

- **SG-15.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, prior-year lock evidence checked 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Start year and sequence are approved. First eligible year passed Phases 6 through 14.

### 4. Inputs

Year matrix, phase gates, year snapshots, source manifests, run journal and approved start-year opening decision.

### 5. Owner-tagged actions

`[Orchestrator]` schedules year state. `[Mapping Agent]` prepares year-specific changes. `[Independent Auditor]` verifies year-to-year sequence. `[Operator]` approves exceptions and locks. Gate verifier: `[Orchestrator]` owns sequence. `[Independent Auditor]` verifies year count and order. `[Operator]` owns locks and accepted differences.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the year-advance checklist. [Verifier] checks prior-year lock evidence. [Final reviewer] reviews the phase before Operator approvals.

**Year sequencing retained from the original repeat rule:**
Run reconstruction, period batches, VAT verification, annual check, income-tax bridge, Red Team and year lock in order for each year. Finish and lock each year before advancing. Do not run multiple historical year write batches in parallel.

### 6. Tool route

Each phase uses its documented Jortt, Moneybird, bank or tax route. Moneybird reads remain guarded read-only. Writes remain guarded, approved and expiry-checked per batch.

### 7. Outputs and evidence artifacts

Chronological year ledger, year gate index, skipped-year report, continuation matrix and per-year snapshots under `Handoff/`, `Reports/`, and `Snapshots/`.

### 8. Numeric exit gate

In-scope years locked 100%, skipped years 0, concurrent historical year write batches 0, open blocking exceptions 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, prior-year lock evidence checked 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Missing year, failed lock, broken continuity, unsupported start year or any unresolved previous-year gate.

Stop on any M12 stop event.

### 10. Rollback or compensation

Reopen only the impacted year under Phase 14 controls. Do not undo later verified years without an explicit dependency impact report.

### 11. Resume rule

Resume at the first year without `GATE_PASSED`. Reconcile its last verified checkpoint and all later-year dependencies before continuing.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 16: Current-year parallel mirror and cutover preparation

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M10](./shared-mechanisms.md#m10-write-isolation-decision), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Compare the existing source administration and Moneybird mirror through a configured parallel period and prepare a complete cutover delta. The Implementer drafts the parallel comparison and delta schema, and the Verifier independently checks the delta for Phase 16.

### 2. Nested sub-goals

- **SG-16.1**: Derive the next work year from the configured start date and last locked year. Check: next historical year is the first unlocked year at or after the configured start year 1, current mirror year is the actual calendar year only when it is at or after the configured start date and is not locked 1, hard-coded current-year labels 0.
- **SG-16.2**: Complete configured parallel comparisons. Check: a positive minimum cycle count or duration and rationale are approved in `MIGRATION_CONFIG` as `parallel.cycles_required`, completed cycles meet that minimum 100%, unresolved differences 0.
- **SG-16.3**: Prepare the source freeze and final delta contract. Check: Operator-set freeze date and time, delta schema and source-total method recorded 100%. The actual freeze, its last source key and delta capture occur in Phase 17.
- **SG-16.4**: Prepare objective rollback controls. Check: numeric trigger thresholds and named decision owner 100%, rehearsal scenarios complete 100%, post-cutover write reconciliation rehearsal 100%.

- **SG-16.5**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, parallel delta checks independently pass 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Historical years through the approved boundary passed. The Operator approved a positive minimum parallel cycle count or duration, rationale, numeric stop thresholds and rollback triggers.

### 4. Inputs

Current-year source records, mirror reports, bank evidence, filing calendar, minimum parallel cycle or duration, planned Operator-set freeze date, compensation plan, rollback thresholds, and M6 access evidence.

### 5. Owner-tagged actions

`[Operator]` remains the source administration decision owner and approves parallel controls and rollback triggers. The live go or no-go decision is reserved for Phase 18 after final delta and boundary reconciliation. `[Reconciliation Agent]` compares periods. `[Red Team]` tests missing and duplicate deltas. `[Orchestrator]` assembles a cutover readiness packet without a live decision. Gate verifier: `[Reconciliation Agent]` prepares comparisons and `[Independent Auditor]` verifies deltas and rehearsal counts.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the parallel comparison and delta schema. [Verifier] independently checks the delta. [Final reviewer] reviews the phase before Operator approvals.

**Current-year mirror steps retained with a dynamic year rule:**
The next historical work year is the first unlocked year at or after the configured bookkeeping start year, using the year after the last locked year when the sequence is contiguous. For current-year mirroring, use the actual calendar year only when it is at or after the configured start date and is not already locked. Never store a hard-coded calendar year. While mirroring, the source ledger remains authoritative and Moneybird remains the shadow ledger.
For each assigned period: process new documents, compare to source ledger evidence, import and reconcile the bank through the UI, reconstruct only approved records in Moneybird, compare VAT, and file nothing again. After the current work year closes, verify all assigned periods, bank, profit, balance sheet, annual accounts and income-tax evidence. A positive minimum parallel duration or cycle count, rationale, numeric rollback triggers, decision owner and rehearsals must be configured before this phase.

### 6. Tool route

Jortt reads through `jortt-cli`. Moneybird reads through guarded read-only access with explicit periods. Approved mirror writes use `moneybird-guard` with `--confirm-write`, `--approval <ref>`, and M6. Bank imports remain Operator UI-only.

### 7. Outputs and evidence artifacts

Parallel comparison reports, minimum-cycle rationale, planned freeze date, delta schema, numeric rollback trigger table, rehearsal evidence and cutover readiness packet without a live GO or NO-GO decision.

### 8. Numeric exit gate

Configured minimum cycles or duration met 100%, final delta plan complete 100%, unexplained differences 0, unknown writes 0, rollback trigger coverage 100%, rehearsal scenarios pass 100%, cutover readiness packet complete 1, live GO or NO-GO decisions recorded 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, parallel delta checks independently pass 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

No positive minimum cycle count or duration, no rationale, no numeric rollback threshold, source activity after the planned freeze without a delta method, missing rollback owner, M6 failure or unresolved post-cutover write state.

Stop on any M12 stop event.

### 10. Rollback or compensation

Before live activity, resume the source ledger. After target accepts live entries, use the approved fail-forward, linked compensation or tested restoration strategy. Reconcile every post-cutover write before returning to the source system.

### 11. Resume rule

Resume from the last comparison-cycle hash. A new source entry after freeze creates a new delta and invalidates the prior cutover packet.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.
