---
title: Migration phases 6 to 9
description: Mapping, pilot, historical batches and VAT verification.
nav_label: "Migration phases 6 to 9"
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 6 to 9

Mapping, pilot, historical batches and VAT verification. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 6: Design the Moneybird mapping

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Map each approved migration object to a supported Moneybird object and establish source-based opening and continuity schedules. The Implementer drafts mapping tables, opening schedules, and continuity schedules, and the Verifier checks every mapped field against the target schema and verifies planted unmappable cases for Phase 6.

### 2. Nested sub-goals

- **SG-6.1**: Map every writable record class. Check: approved mapping coverage 100%, unmapped write candidates 0.
- **SG-6.2**: Validate source-type field detail and VAT treatment. Check: separate PDF and UBL field matrices cover each source type present 100%, unknown field names 0.
- **SG-6.3**: Prepare opening balances and invoice-level open-item schedules. Check: each AR/AP item has source key, counterparty, invoice number and date, amount, VAT, due date, target mapping, and settlement status 100%, unbalanced opening lines 0, duplicate open-item keys 0, unsupported target representation 0.
- **SG-6.4**: Resolve first-business-year case. Check: supported opening schedule approved 1 or phase stop remains active.
- **SG-6.5**: Select a target representation for opening AR/AP. Check: supported Moneybird object or Operator-approved subledger selected 1, settlement-link test plan approved 1.

- **SG-6.6**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, mapped fields supported by target schema 100%, planted unmappable cases blocked 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 5 has zero unresolved blockers for mapped records. Tax rates are approved and configured by the Operator in the UI.

### 4. Inputs

Canonical dataset, category and vendor tax data, RGS codes, source closing balance, aged invoice-level open AR/AP schedule with source key and settlement status, target representation evidence and approved thresholds.

### 5. Owner-tagged actions

[Mapping Agent] prepares category, tax and separate PDF and UBL field mappings. [Operator] creates tax rates in the UI and approves accounting judgments and any subledger. [Independent Auditor] checks mapping uniqueness and target support. [Reconciliation Agent] prepares source closing-to-opening schedules. Gate verifier: [Independent Auditor] verifies opening arithmetic, invoice-level links and the target representation plan.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts mapping tables, opening schedules and continuity schedules. [Verifier] checks every mapped field against the target schema and verifies planted unmappable cases. [Final reviewer] reviews the phase before Operator approvals.

**Mapping tables and object routes retained from the original mapping design:**


| Source category | Moneybird account | RGS code | Account type | VAT treatment | Confidence |
|---|---|---|---|---|---|
| Approved source label | Supported target account | Required code | Asset, liability, equity, income or expense | Approved treatment | Approved score or rationale |

| Legal entity (rechtspersoon) | Validity period | Country | VAT identifier | Vendor type | Moneybird tax rate |
|---|---|---|---|---|---|
| Approved vendor entity | Start and end dates | Source country | Controlled identifier | Supplier class | Existing approved rate |

| Historical item | Moneybird record |
|---|---|
| Issued sales invoice | External sales invoice with original number, date and original file |
| Purchase invoice (inkoopfactuur) | Purchase invoice document with original attachment |
| Receipt | Receipt document with original attachment |
| Journal, private item or correction | General journal document |
| Asset | Asset with historic value changes |
| Bank transaction | Financial statement imported through the Operator UI |
1. [Mapping Agent] Maintain CATEGORY_MAPPING with source category, Moneybird account, required RGS code, account type, VAT treatment and confidence. Every new ledger account has an RGS code.
2. [Mapping Agent] Maintain VENDOR_TAX_MATRIX with legal entity, validity period, country, VAT identifier, vendor type and approved Moneybird tax rate. The required rate must already exist.
3. [Mapping Agent] Map issued sales documents to external sales invoices with original number and date and the original file attached. Map purchase invoices and receipts to document records with attachments. Map journals, private items and corrections to general journal documents. Map assets with historic value changes.
4. [Operator] Import bank files through the UI. The writer links approved payments through the documented tool route.
5. [Mapping Agent] When a supplier changes country or legal entity, add a new validity period instead of reusing one permanent brand rule.
6. [Independent Auditor] Validate external document reporting behavior in the pilot before relying on a tax report.

### 6. Tool route

Moneybird reads use `moneybird-guard` with read-only lock. Tax-rate creation is Operator UI-only. Verify every write parameter using pinned CLI help before any pilot write.

### 7. Outputs and evidence artifacts

CATEGORY_MAPPING, VENDOR_TAX_MATRIX, PDF and UBL field matrices, document-class map, opening-balance schedule, invoice-level AR/AP schedule, target representation decision, settlement-link test plan, and field-validation report under Mappings/ and Reports/.

### 8. Numeric exit gate

Mapping coverage 100%, each applicable source-type field trace 100%, unknown write fields 0, account imbalance 0, item-level AR/AP schedule coverage 100%, duplicate open-item keys 0, target representation decision 1, accepted Operator decisions 100%.

M12 gate: work units with Verifier PASS or Operator disposition 100%, mapped fields supported by target schema 100%, planted unmappable cases blocked 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

No RGS code, unverified CLI field, absent tax rate, unsupported PDF-derived field, missing item-level AR/AP, unsupported target representation, no prior closing XAF without an approved alternative or non-zero unsupported opening difference.

Stop on any M12 stop event.

### 10. Rollback or compensation

Version mappings instead of overwriting. No Moneybird mutation occurs in this phase. Reopen affected mapping rows after a source or schema change.

### 11. Resume rule

Resume from the last approved mapping version and schema hash. Revalidate only rows that depend on changed source evidence.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 7: Pilot migration

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M10](./shared-mechanisms.md#m10-write-isolation-decision), [M11](./shared-mechanisms.md#m11-stop-state-recovery-matrix), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Prove the complete controlled write and verification path in the one empty trial administration, which remains the mirror. The Implementer drafts the pilot batch builder, pre-write report, and read-back comparer, and the Verifier checks the pre-write report and read-back comparison for Phase 7.

### 2. Nested sub-goals

- **SG-7.1**: Pilot each source document type and attachment path. Check: PDF and UBL are piloted separately where present, required field matrices match sources 100%, attachment bytes and SHA-256 match 100%, target attachment read route verified 1.
- **SG-7.2**: Prove duplicate control under an uncertain response. Check: stable local key and mapping schema version beside it 100%, durable WRITE_INTENT flushed before every non-GET call 100%, source reference and planned payload fields match before ID adoption 100%, ambiguous results stopped 100%.
- **SG-7.3**: Rehearse crash resume at the write boundary. Check: forced interruption after WRITE_INTENT, after response loss and after read-back 3, each resumes from the last verified journal state 100%, blind replay count 0.
- **SG-7.4**: Rehearse safe compensation. Check: approved undo or linked correction rehearsal passes 1, independent read confirms final state 1.
- **SG-7.5**: Test the item-level AR/AP target representation. Check: representative opening item and settlement link read-back pass 1, source item and target link coverage 100%.
- **SG-7.6**: Test lock behavior for each used record class in the safe pilot. Check: Operator-approved probe and correction plan 1, record-class coverage 100%, expected lock result recorded for every class, successful probes reversed or corrected and read back 100%, final lock state verified 1.

- **SG-7.7**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, pre-write report and read-back comparisons pass 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phases 0 through 6 passed. PDF and UBL pilot populations where present, attachment read route, pilot key manifest and pre-write report are frozen. Trial and subscription evidence covers write, synchronization, read-back and audit completion.

### 4. Inputs

Pilot records, mapping hash, source hashes, pre-write report, risk review, opening AR/AP sample, target representation decision and approved write batch.

### 5. Owner-tagged actions

[Operator] approves the exact batch and performs bank-file import in UI. [Migration Writer] records and flushes WRITE_INTENT before every non-GET call and journals returned IDs. [Operator] approves the temporary pilot lock and a disposable probe record for each used record class, with a correction path for any probe that succeeds. [Independent Auditor] reads back records, verifies every attachment byte hash and AR/AP settlement link, and confirms lock probe results and final lock state. [Red Team] challenges duplicates and field mapping. [Operator + AI] selects pilot items for crash and compensation rehearsals. Gate verifier: [Independent Auditor] verifies read-back, payload fields, attachment bytes, settlement linkage, lock coverage and resume states.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the pilot batch builder, pre-write report and read-back comparer. [Verifier] checks the pre-write report and read-back comparison. [Final reviewer] reviews the phase before Operator approvals.

**Pilot selection and numbered execution retained from the original plan:**
Select a representative period from the oldest eligible year. Include a sales invoice, a domestic purchase, an EU service purchase, a non-EU service purchase, a normal bank payment and a private payment if present.
1. [Migration Writer] Produce PILOT PRE-WRITE REPORT with each record, target object, account, tax rate, risk class and expected totals.
2. [Mapping Agent] Resolve mapping defects and keep RED or BLACK records out of the write set.
3. [Operator] Approve the exact pre-write report and batch scope.
4. [Migration Writer] Write only the approved records through moneybird-guard and record each returned ID in the write journal after a flushed intent.
5. [Operator] Import the pilot bank file through the UI. [Migration Writer] link approved payments through the documented guarded route.
6. [Independent Auditor] Compare planned values with write responses, then run a later synchronized read-back to account for cache delay.
7. [Independent Auditor] Recheck from original sources using the read-only lock and explicit periods.
8. [Red Team] Challenge field mapping, duplicates and completeness.
9. [Operator + AI] Rehearse recovery at the intent, response-loss and read-back boundaries with the local stub suite. Prove that an uncertain write is reconciled before resumption and that compensation is linked and verified. Do not delete issued or settled records as a routine undo.
10. [Operator] Temporarily locks the pilot period. [Independent Auditor] tests only the record classes used by the migration with the approved disposable probes. If a probe succeeds, stop, record the unexpected write, reverse or correct it through the approved linked path, read it back and restore the approved lock state before continuing.

### 6. Tool route

All Moneybird writes use moneybird-guard after dry-run review, with --confirm-write, --approval for the flushed WRITE_INTENT and the single pilot/mirror administration. Run separate PDF and UBL pilots where both source types exist. Verify every attachment through a documented target read route. Reads use the guard lock and synchronization with a recorded timestamp. No real write occurs during the crash-boundary stub rehearsal.

### 7. Outputs and evidence artifacts

Pilot pre-write report, PDF and UBL field matrices, pilot key manifest, opening AR/AP representation and settlement-link test, write journal with flushed intent events, run journal, timestamped synchronization read-back, attachment hash comparison, lock behavior matrix, temporary-probe correction evidence, independent audit, crash-resume rehearsal, red-team report and compensation rehearsal.

### 8. Numeric exit gate

Each source-type pilot coverage 100%, required field checks 100%, read-back coverage 100%, attachment read route verified 1, attachment byte and SHA-256 matches 100%, opening AR/AP representation and settlement-link test pass 1, lock behavior coverage 100%, successful probes corrected and read back 100%, final lock state verified 1, durable intent coverage 100%, ambiguous adoption count 0, unknown writes 0, duplicate records 0, unexplained differences 0, crash rehearsal pass 1, compensation rehearsal pass 1.

M12 gate: work units with Verifier PASS or Operator disposition 100%, pre-write report and read-back comparisons pass 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

M6 access window fails, any approved hash changes, uncertain write is unresolved, missing attachment read route, attachment mismatch, unsupported AR/AP representation or settlement link, unapproved lock probe, unexpected probe write without verified correction, failed or incomplete crash rehearsal, no safe correction route, 429 without recovery, ambiguous target match, or any record does not match the approved payload.

Stop on any M12 stop event.

### 10. Rollback or compensation

Use the approved safe pilot undo. For an issued or settled object, do not default to deletion. Use a linked credit or correction where supported and approved. Confirm the result with a later read-back.

### 11. Resume rule

Resume only from M3's last verified object state. Any WRITE_UNKNOWN key is reconciled first. Recheck hashes and M6 through the required verification window before opening another batch.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 8: Historical migration per period

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Rebuild approved historical records in controlled batches and reconcile each batch before advancing. The Implementer drafts per-period batch plans and builders, and the Verifier checks each batch pre-write report and read-back for Phase 8.

### 2. Nested sub-goals

- **SG-8.1**: Freeze input and recompute immediately before write. Check: approved input hashes match pre-write hashes 100%.
- **SG-8.2**: Track each source object through write and read-back. Check: objects with terminal state 100%, flushed WRITE_INTENT events before non-GET calls 100%, source-reference and planned-field equality before ID adoption 100%, WRITE_UNKNOWN count 0 before gate.
- **SG-8.3**: Reconcile counts, pilot identity and balances. Check: every source key already verified in the pilot reuses its matching target ID and is excluded from the historical write set 100%, exact source reference and planned fields match 100%, duplicates across pilot and historical key manifests 0, unexplained differences 0, write-key duplicates 0.
- **SG-8.4**: Verify every target attachment. Check: source and target byte counts and SHA-256 match 100%, unavailable attachment reads 0, mismatches 0.
- **SG-8.5**: Track opening AR/AP through settlement. Check: each cut-over item has settled-with-link, still-open-with-aging or approved-exception status 100%, settled items link to the same source key 100%, unexplained open items 0.

- **SG-8.6**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, per-batch pre-write and read-back checks pass 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 7 passed. A verified pilot key manifest exists for the same administration. The period is open. The duplicate gate includes the union (de unie) of pilot and historical keys. Matching verified pilot records are reused and never written again. Batch approval, current M6 evidence through read-back, mapping hash, exception state and numeric threshold config are present.

### 4. Inputs

Frozen canonical records, batch manifest, prior journal state, mapping, bank files, aged invoice-level AR/AP schedule, exception ledger and approved pre-write report.

### 5. Owner-tagged actions

[Migration Writer] writes only approved items and maintains stable keys. [Operator] approves each batch and imports bank files. [Independent Auditor] checks timestamped synchronization read-back. [Red Team] challenges period coverage and duplicates across pilot and historical manifests. Gate verifier: [Independent Auditor] verifies sync results, payload equality, union-key uniqueness and reconciliations.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts per-period batch plans and builders. [Verifier] checks each batch pre-write report and read-back. [Final reviewer] reviews the phase before Operator approvals.

**Historical batch sequence retained from the original per-period workflow:**
1. [Migration Writer] Freeze the period's source files and hashes in Snapshots/.
2. [Reconciliation Agent] Repeat the pre-write reconciliation against the frozen source set.
3. [Orchestrator] Report document and transaction counts, risk-class counts, expected revenue, costs, VAT and bank movement in the controlled workspace.
4. [Operator] Approve the report and exact batch.
5. [Migration Writer] Write only approved records within shared request budgets.
6. [Operator] Import the period's bank files through the UI. [Migration Writer] link approved payments.
7. [Independent Auditor] Read back every written record through a fresh complete synchronization or permitted complete fallback.
8. [Reconciliation Agent] Compare target documents with original evidence.
9. [Reconciliation Agent] Reconcile bank transactions and closing balances per account.
10. [Reconciliation Agent] Reconcile each opening AR/AP item as settled with a link to the same source key, still open with aging and status, or an approved exception.
11. [VAT Agent] Complete the assigned-period checks in Phase 9.
12. [Red Team] Challenge the period batch.
13. [Orchestrator] Mark a batch verified only after every sub-gate passes. Correct a wrong write through a linked exception, approved reversal or credit where applicable, replacement, read-back, and relock when required. Do not silently delete or update committed history.

### 6. Tool route

Before every non-GET call, flush WRITE_INTENT with the stable key, mapping schema version, source reference, planned payload hash and approval reference. Moneybird writes use guarded CLI with --confirm-write and --approval for that reference, against the payload file the local payload assembler built. Keep within general and reports request limits. Retry decisions use a timestamped synchronization read or wait beyond the Operator-approved, Independent Auditor verified `bulk_read.cache_horizon` in `MIGRATION_CONFIG`, then a complete paginated read. Missing or unapproved horizon blocks a wait-based retry. Bank-file imports are Operator UI-only.

### 7. Outputs and evidence artifacts

Frozen batch manifest, pre-write report, pilot key manifest, union duplicate report, flushed write-ahead events, run-journal checkpoints, timestamped sync read-back, attachment comparisons, reconciliation, exception updates and period verification report.

### 8. Numeric exit gate

Input hashes match immediately before writing 100%, approved objects with verified read-back 100%, attachment byte counts and SHA-256 match 100%, opening AR/AP status coverage 100%, settled-item links match source keys 100%, durable intent coverage 100%, unknown write states 0, duplicates across pilot and historical keys 0, unresolved exceptions above approved threshold 0, UNEXPLAINED count 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, per-batch pre-write and read-back checks pass 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

M6 access check fails, input drift, 429, unknown write state, schema error, duplicate in either manifest, missing source attachment, attachment byte or hash mismatch, failed or stale read-back, unsupported difference, or missing pilot key manifest.

Stop on any M12 stop event.

### 10. Rollback or compensation

Stop the affected batch. Never delete or overwrite a committed target record as routine correction. Link an approved correction to the original target ID and exception, create a reversal or credit where applicable, write a replacement, read it back, and relock the period when required. Do not replay a confirmed key.

### 11. Resume rule

Start at the last `READBACK_CONFIRMED` or `RECONCILED` checkpoint. Reconcile every unknown item and revalidate input hashes, approval scope and expiry before the next write.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 9: VAT verification loop

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M5](./shared-mechanisms.md#m5-moneybird-rate-limits-and-recovery), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M8](./shared-mechanisms.md#m8-jortt-pagination-and-source-request-evidence), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Reconcile document, ledger, filed and Moneybird tax values for every assigned tax period. The Implementer drafts the per-period VAT reconciliation, and the Verifier independently recomputes VAT from the source registers for Phase 9.

### 2. Nested sub-goals

- **SG-9.1**: Inventory each Operator-assigned filing cadence, period start and end, and filing status. Check: assigned-period calendar coverage 100%, actual filing evidence or evidence-backed not-applicable status 100%, unclassified periods 0.
- **SG-9.2**: Compare each return box across all available sources. Check: box comparisons 100%, unexplained boxes 0.
- **SG-9.3**: Enforce cumulative tolerances. Check: quarter and year cap fields are numeric and Operator-approved, cap breaches 0.
- **SG-9.4**: Reconcile external and missed-period corrections. Check: manual correction register has period, correction reference, owner, evidence, source and target linkage, and status 100%, unowned corrections 0.

- **SG-9.5**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, VAT recompute from source registers differences 0, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 2 has actual filed VAT return (btw-aangifte) and confirmation evidence for every filed VAT period or evidence-backed not-applicable status. A missing filed return or confirmation with an exception remains blocked and cannot pass this phase. Phase 8 period records are reconciled.

### 4. Inputs

Original invoices, XAF, actual filed VAT returns and portal confirmations, assigned tax calendar and declaration applicability matrix, Moneybird tax reports, manual correction register and approved cap values.

### 5. Owner-tagged actions

[VAT Agent] calculates document VAT independently. [Tax Filing Agent] checks filed periods, KOR, ICP, OSS and correction history. [Independent Auditor] checks boxes and manual correction links. [Operator] decides corrections and performs any filing. Gate verifier: [Independent Auditor] reproduces period, box, applicability and correction-owner counts.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the per-period VAT reconciliation. [Verifier] independently recomputes VAT from the source registers. [Final reviewer] reviews the phase before Operator approvals.

**Four-source VAT comparison retained from the original plan:**
For each actually assigned filing period, compare A) document VAT, B) ledger VAT, C) filed VAT, and D) Moneybird VAT by return box. Classify differences as EXACT, ROUNDING, EXPLAINED, SOURCE DIFFERENCE, FILING DIFFERENCE, MONEYBIRD DIFFERENCE or UNEXPLAINED. Record each manual correction with period, source and target links, evidence, owner, and status. Apply the configured per-box allowance and cumulative quarter and year caps without netting periods. The Operator may mark historical filing status in Moneybird through the UI in chronological order after evidence review. Agents never file or pay a return.

| Return box | Documents | Ledger | Filed return | Moneybird | Difference and classification |
|---|---|---|---|---|---|
| One row per assigned box | Evidence and value | Evidence and value | Actual filed evidence or approved unavailable state | Guarded report evidence | Numeric result and exception key |


### 6. Tool route

Jortt return exports use operator UI. Moneybird report reads use the guard read-only lock and explicit period. Historical manual filed status is Operator UI-only and chronological. Do not call a summary a filed return.

### 7. Outputs and evidence artifacts

Period-by-period four-source reconciliation, filed-return evidence index, rounding-cap summary, year-by-year declaration applicability matrix, manual correction reconciliation register, missed-period exception list and verification report.

### 8. Numeric exit gate

Assigned-period coverage 100%, filed evidence coverage 100% for applicable filed periods, declaration applicability or evidence-backed not-applicable status 100%, manual correction fields and ownership 100%, unowned corrections 0, box comparisons 100%, unexplained boxes 0, cumulative cap breaches 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, VAT recompute from source registers differences 0, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Unknown filing cadence or declaration status, any missing actual filed VAT return or confirmation for a filed VAT period, an exception used to waive that evidence, stale or incomplete Moneybird report, unowned manual correction, unsupported cap, cross-period netting, or unapproved supplementary filing.

Stop on any M12 stop event.

### 10. Rollback or compensation

No filing or payment is performed by agents. Preserve the prior reconciliation and open a linked exception. Operator or adviser determines filing or correction.

### 11. Resume rule

Resume at the first failed period after refreshing the source evidence manifest and assigned-period calendar. Prior passed periods remain immutable unless their source changes.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.
