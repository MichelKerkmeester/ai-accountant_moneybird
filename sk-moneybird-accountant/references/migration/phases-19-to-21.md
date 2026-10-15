---
title: Live workflows, phases 19 to 21
description: Recurring monthly, VAT-period and yearly reviews.
nav_label: "Live workflows, phases 19 to 21"
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Live workflows, phases 19 to 21

Recurring monthly, VAT-period and yearly reviews. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 19: Live monthly workflow

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M9](./shared-mechanisms.md#m9-master-phase-dashboard), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Detect and resolve monthly document, bank and Moneybird differences before they accumulate. The Implementer drafts monthly check scripts using the reuse fast path, and the Verifier checks the run summary and record-level result every cycle, with code review only when a hash changes for Phase 19.

### 2. Nested sub-goals

- **SG-19.1**: Compare monthly document and target populations. Check: linked or excepted records 100%, unexplained records 0.
- **SG-19.2**: Review bank and open-item state. Check: bank statement transactions linked or excepted 100%, unexplained bank items 0.
- **SG-19.3**: Assign every open exception. Check: owner and due date coverage 100%, expired accepted exceptions 0.

- **SG-19.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, read-only run summary checks pass 100%, record-level check pass 100%, changed-hash code reviews complete 100%, reuse fast path valid 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

The configured recurring monitoring window is active. Current month is identified, prior month status is recorded and primary and backup owners are available.

### 4. Inputs

New document inventory, Moneybird period report, bank statement, open invoice schedule, risk model and prior exceptions.

### 5. Owner-tagged actions

[Document Agent] inventories source documents. [Reconciliation Agent] compares records and bank items. [VAT Agent] reviews high-risk invoices. [Operator] approves corrections and owns escalations. A named backup owner covers absence. Gate verifier: [Reconciliation Agent] owns the monthly report. [Independent Auditor] reproduces counts. [Operator] owns decisions.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts monthly check scripts using the reuse fast path. [Verifier] checks the run summary and record-level result every cycle, with code review only when a hash changes. [Final reviewer] reviews the phase before Operator approvals.

**Monthly review steps retained from the original live workflow:**
1. [Document Agent] Detect new source documents from the approved archive route.
2. [Reconciliation Agent] Compare documents with Moneybird.
3. [Mapping Agent] Classify new suppliers with a dated validity rule.
4. [Bank Agent] Check bank transactions and statement completeness.
5. [Reconciliation Agent] Find documents without target records, target records without documents, unexplained bank transactions, unpaid or open invoices, and duplicates.
6. [VAT Agent] Review every high-risk invoice.
7. [Reconciliation Agent] issue the exception report with zero unexplained items or stop the cycle.

### 6. Tool route

Moneybird reads use `moneybird-guard` with read-only lock and explicit month. After Phase 18 passes, each Operator-approved production correction uses the separate guarded writer session, `--production`, and `--approval <ref>`. Bank import is Operator UI-only.

### 7. Outputs and evidence artifacts

Monthly input snapshot and report hash, bank and open-item report, complete M7 exception ledger, corrective journal, owner and backup schedule, due date, escalation deadline, resume checkpoint, and monthly status.

### 8. Numeric exit gate

Monthly check coverage 100%, source and report hashes 100%, unexplained items 0, M7 exception fields complete 100%, primary and backup owner coverage 100%, due dates and escalation deadlines 100%, corrective journal links 100%, unknown writes 0, expired accepted exceptions 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, read-only run summary checks pass 100%, record-level check pass 100%, changed-hash code reviews complete 100%, reuse fast path valid 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Missing statement, incomplete month, duplicate, uncertain tax class, unexplained difference, incomplete M7 exception, absent backup owner, missed escalation deadline or overdue unaccepted exception.

Stop on any M12 stop event.

### 10. Rollback or compensation

Preserve the month report. Correct through linked records and approved entries. Never delete issued or settled history as the default correction.

### 11. Resume rule

Resume from the first unresolved monthly exception or journal checkpoint after confirming the source snapshot hash, assigned backup owner, corrective journal and escalation state.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 20: Live VAT-period workflow

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M9](./shared-mechanisms.md#m9-master-phase-dashboard), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

Per-step content for a LIVE VAT period: [`references/vat-return/README.md`](../vat-return/README.md).

### 1. Goal

Prepare each VAT return for the assigned cadence and period from complete evidence, with filing owned by the Operator. The Implementer drafts VAT-period check scripts using the reuse fast path, and the Verifier checks the run summary and record-level result every cycle, with code review only when a hash changes for Phase 20.

### 2. Nested sub-goals

- **SG-20.1**: Confirm each Operator-assigned filing cadence, period start and end, and required declarations. Check: assigned-period calendar coverage 100%, actual filing evidence or evidence-backed not-applicable status 100%, unknown periods 0.
- **SG-20.2**: Reconcile each VAT box and prior-period correction. Check: box coverage 100%, unexplained box count 0, cumulative cap breaches 0.
- **SG-20.3**: File and retain confirmation. Check: Operator filing action 1, portal confirmation artifact 1 for each filed period.

- **SG-20.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, read-only run summary checks pass 100%, record-level check pass 100%, changed-hash code reviews complete 100%, reuse fast path valid 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

The configured recurring monitoring window is active. The assigned tax calendar, annual declaration applicability matrix and prior-period status are current.

### 4. Inputs

Source invoices, Moneybird tax report, filing calendar, KOR, ICP, OSS and other declaration applicability evidence, manual correction register, prior-period exception ledger, and actual filing evidence.

### 5. Owner-tagged actions

[VAT Agent] recalculates VAT. [Tax Filing Agent] checks period, declaration and correction history. [Independent Auditor] verifies boxes and correction links. [Operator] alone decides and files the return. A named backup owner covers absence. Gate verifier: [Independent Auditor] reproduces period, box, correction and owner counts.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts VAT-period check scripts using the reuse fast path. [Verifier] checks the run summary and record-level result every cycle, with code review only when a hash changes. [Final reviewer] reviews the phase before Operator approvals.

**VAT-period review steps retained from the original filing workflow:**
1. [Document Agent] Check source document completeness.
2. [Reconciliation Agent] Check Moneybird completeness.
3. [Bank Agent] Reconcile the bank statement.
4. [Reconciliation Agent] Check revenue.
5. [Reconciliation Agent] Check costs.
6. [VAT Agent] Review reverse-charge treatment.
7. [VAT Agent] Review foreign suppliers.
8. [VAT Agent] Recalculate VAT independently.
9. [Independent Auditor] Compare the recalculation with Moneybird by box and period.
10. [Reconciliation Agent] Process prior-period corrections through a linked correction record.
11. [Independent Auditor] Review every exception and its owner.
12. [Operator] Decide and file only after all required evidence passes, then retain portal confirmation. Agents do not submit or pay returns.

### 6. Tool route

Moneybird reads use guarded read-only access. Tax portal and filing use Operator UI. Historical manual filing status in Moneybird uses the UI in chronological order. Agents do not submit or pay returns.

### 7. Outputs and evidence artifacts

VAT-period reconciliation, year-by-year declaration applicability matrix, manual correction register, Operator filing decision, portal confirmation, primary and backup owners, corrective journal, escalation deadline, resume checkpoint, and exceptions.

### 8. Numeric exit gate

Assigned-period coverage 100%, KOR, ICP, OSS and other declarations marked applicable or evidence-backed not applicable 100%, box comparison coverage 100%, manual correction ownership 100%, unexplained boxes 0, cap breaches 0, M7 exception fields complete 100%, backup owner and escalation coverage 100%, filed-period confirmation coverage 100%.

M12 gate: work units with Verifier PASS or Operator disposition 100%, read-only run summary checks pass 100%, record-level check pass 100%, changed-hash code reviews complete 100%, reuse fast path valid 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Unknown cadence or declaration status, missing source or portal evidence, unowned manual correction, unsupported correction, unapproved cap, unresolved previous period, absent backup owner, missed escalation deadline, or request for agent filing.

Stop on any M12 stop event.

### 10. Rollback or compensation

No automated filing reversal. Operator or adviser decides any amendment. Link it to the prior return and retain both confirmations.

### 11. Resume rule

Resume at the first failed period after refreshing evidence hashes. Record the corrective journal and backup owner. Do not advance while an earlier required period is unresolved.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 21: Live yearly workflow

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M9](./shared-mechanisms.md#m9-master-phase-dashboard), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Close each live year with complete monthly, VAT, balance, asset, tax and human review evidence. The Implementer drafts yearly check scripts using the reuse fast path, and the Verifier checks the run summary and record-level result every cycle, with code review only when a hash changes for Phase 21.

### 2. Nested sub-goals

- **SG-21.1**: Confirm all subordinate cycles. Check: applicable monthly and filing-period checks passed 100%.
- **SG-21.2**: Reconcile continuity, assets, profit and tax bridge. Check: account and bridge coverage 100%, unexplained differences 0.
- **SG-21.3**: Approve and preserve close evidence. Check: sealed snapshot hash 1, Operator close approval 1.

- **SG-21.4**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, read-only run summary checks pass 100%, record-level check pass 100%, changed-hash code reviews complete 100%, reuse fast path valid 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

The configured recurring monitoring window is active. Required monthly and VAT-period cycles for the year passed. Current year and applicable tax obligations are identified.

### 4. Inputs

Monthly reports, VAT reconciliations, bank statements, receivable and payable schedules, asset records, tax bridge, and exception ledger.

### 5. Owner-tagged actions

[Tax Filing Agent] prepares the tax bridge and post-lock assessment routing. [Independent Auditor] challenges year close. [Operator] decides accounting and tax judgments, files returns and approves lock or close. A named backup owner covers absence. [Orchestrator] checks gate evidence. Gate verifier: [Independent Auditor] verifies arithmetic and evidence links. [Operator] owns filings and close.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts yearly check scripts using the reuse fast path. [Verifier] checks the run summary and record-level result every cycle, with code review only when a hash changes. [Final reviewer] reviews the phase before Operator approvals.

**Year-end checklist retained from the original annual workflow:**
1. Confirm every required month and filing period is closed.
2. Reconcile the bank.
3. Reconcile receivables.
4. Reconcile payables.
5. Verify VAT.
6. Review assets.
7. Review depreciation.
8. Review private items.
9. Reconcile profit.
10. Reconcile the balance sheet.
11. Record supported tax differences.
12. Have the Operator approve the year close and any UI period lock.
13. Prepare the income-tax bridge and filing evidence for the Operator or adviser.
14. Complete the Independent Auditor year review.

### 6. Tool route

Moneybird reads use guarded read-only access with explicit periods. Period lock is Operator UI-only. Tax filing and portal evidence are Operator-only. After Phase 18 passes, each Operator-approved production correction uses the separate guarded writer session, `--production`, and `--approval <ref>`.

### 7. Outputs and evidence artifacts

Annual close report, balance continuity, filed return and assessment links, tax bridge, complete M7 exception disposition, post-lock assessment and correction records, snapshot manifest, corrective journal, primary and backup owners, escalation deadline, resume checkpoint, and owner handoff.

### 8. Numeric exit gate

Subordinate cycle coverage 100%, annual comparison coverage 100%, unexplained differences 0, M7 exception fields complete 100%, expired accepted exceptions 0, snapshot hash verified 1, backup owner and escalation coverage 100%, Operator close approval 1.

M12 gate: work units with Verifier PASS or Operator disposition 100%, read-only run summary checks pass 100%, record-level check pass 100%, changed-hash code reviews complete 100%, reuse fast path valid 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Missing month, tax period, filing confirmation or required assessment without approved unavailability, unsupported adjustment, incomplete exception, absent backup owner, missed escalation deadline, unresolved exception or failed snapshot hash.

Stop on any M12 stop event.

### 10. Rollback or compensation

Reopen only through the Operator exception and unlock process. Link any correction to prior evidence, read it back and reseal the year snapshot.

### 11. Resume rule

Resume from the first failed annual check. Record the corrective journal, escalation and backup owner. If new evidence changes a prior period, reopen dependent VAT, continuity and tax checks before closing.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.
