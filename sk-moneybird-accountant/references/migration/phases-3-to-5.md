---
title: Migration phases 3 to 5
description: Independent reconstruction, reconciliation, and anomaly review.
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 3 to 5

Independent reconstruction, reconciliation, and anomaly review. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 3: Reconstruct each source independently

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M4](./shared-mechanisms.md#m4-evidence-privacy-and-session-boundary). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Produce independent document, ledger, bank, tax, and VAT registers without cross-contamination.

### 2. Nested sub-goals

- **SG-3.1**: Seal one input folder per role. Check: role folders with schema and checksum manifest 100%, VAT folder contains original invoices only 100%, Jortt booking exports in VAT inputs 0, unapproved files 0.
- **SG-3.2**: Process each applicable source. Check: in-scope source items assigned a terminal register status 100%.
- **SG-3.3**: Validate ledger arithmetic. Check: unbalanced journal or year totals 0.

### 3. Entry criteria

Phase 2 passed for the year and source set. Role-specific input manifests are frozen.

### 4. Inputs

Original document archive, XAF files, bank files, filed returns and assessments, annual accounts, and assigned tax periods.

### 5. Owner-tagged actions

[Document Agent] processes original documents. [Ledger Agent] processes XAF only. [Bank Agent] processes bank files only. [Tax Filing Agent] processes filings and accounts only. [VAT Agent] classifies original invoices without bookings. [Orchestrator] seals each folder and verifies the VAT input manifest classifies every file as an original invoice. Gate verifier: [Independent Auditor] verifies folder hashes, zero booking exports, arithmetic, and session output redaction.

**Independent register fields retained from the original reconstruction:**
1. [Document Agent] From original documents only, record supplier, legal entity, country, invoice number and date, VAT identifier, currency, net, VAT, gross, reverse-charge status, and purchase or sale type.
2. [Ledger Agent] From XAF only, record booking date, account, amount, debit or credit, VAT code, document reference, relation, invoice number, journal entries, assets, private items, opening entries, and year-end closing entries. Prove debits equal credits per journal and year.
3. [Bank Agent] From bank files only, record account, date, amount, currency, counterparty, description, payment reference, and opening and closing balances per file.
4. [Tax Filing Agent] From actual filings, assessments, and annual accounts only, record VAT and income-tax filings, supplementary filings, final assessments, annual accounts, and Jortt VAT summaries as a separate source class.
5. [VAT Agent] From original invoices only, classify Dutch VAT, EU reverse charge, non-EU reverse charge, zero rate, no VAT, foreign VAT, or unclear treatment.

### 6. Tool route

Jortt source reads use `jortt-cli`. Independent agents read only `Inputs/<role>/`. Moneybird is not written. Any Moneybird read uses the guard read-only lock.

### 7. Outputs and evidence artifacts

DOCUMENT_REGISTER, LEDGER_REGISTER, BANK_REGISTER, TAX_REGISTER, VAT_CLASSIFICATION_REGISTER, sealed folder manifests, independent session checkpoints, and transcript privacy scan under Registers/, Inputs/, and Reviews/.

### 8. Numeric exit gate

Input folders sealed 100%, applicable source items processed 100%, VAT input originals 100%, booking export files in VAT input 0, private record fields in prompts, logs, and session outputs 0, unbalanced journals 0, cross-register reads before Phase 4 equal 0.

### 9. Stop conditions

Hash mismatch, wrong-role file, booking export in the VAT folder, missing source, unsupported file type, register schema mismatch, private record data in an uncontrolled prompt or log, or agent access to another role's register.

### 10. Rollback or compensation

Preserve the register version and mark it invalid. Reprocess only the affected source set from the frozen input. Do not merge independently prepared results.

### 11. Resume rule

Resume by role and last source-item key whose register state is verified. Reconcile its input-manifest hash before continuing.

## Phase 4: Cross-reconciliation

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M2](./shared-mechanisms.md#m2-stable-local-write-keys-and-uncertain-outcomes), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Link independent evidence into one canonical record set with a stable source identity.

### 2. Nested sub-goals

- **SG-4.1**: Link source evidence for each event. Check: in-scope source items linked or explicitly excepted 100%.
- **SG-4.2**: Assign deterministic migration keys. Check: key collisions 0 and duplicate source keys 0.
- **SG-4.3**: Preserve source-to-target identity fields. Check: canonical records with source key, period, and evidence reference 100%.

### 3. Entry criteria

Phase 3 registers are sealed and their checksums pass.

### 4. Inputs

The five independent registers, schema manifests, and approved source scope.

### 5. Owner-tagged actions

`[Reconciliation Agent]` creates event links and canonical records. `[Orchestrator]` checks counts and exception linkage. `[Independent Auditor]` samples identity uniqueness. Gate verifier: `[Reconciliation Agent]` owns the dataset. `[Independent Auditor]` verifies uniqueness and link counts.

**Canonical event fields retained from the original cross-reconciliation:**
1. [Reconciliation Agent] Link DOCUMENT, XAF ENTRY, BANK TRANSACTION, and TAX PERIOD where each source exists. Record explicit exceptions for absent links.
2. [Reconciliation Agent] Assign one permanent migration record key to each event. Keep it stable across mapping revisions and store the mapping schema version beside it.
3. [Reconciliation Agent] Store source keys, period, evidence references, historical category, historical VAT code, independent VAT classification, risk class, confidence, source-to-target reference, and differences.

### 6. Tool route

Workspace registers only. No Moneybird writes. Read-only Moneybird route is available for limited mapping facts after setting the guard lock.

### 7. Outputs and evidence artifacts

`CANONICAL_DATASET`, source-key index, link coverage report, collision report, and journal checkpoint under `Registers/` and `Reports/`.

### 8. Numeric exit gate

Source-item linkage coverage 100%, canonical records with required identity fields 100%, key collisions 0, unlinked items without an exception 0.

### 9. Stop conditions

Conflicting identity, duplicate source key, unsupported cross-source match, or checksum mismatch.

### 10. Rollback or compensation

Retain the prior canonical dataset and issue a new version with a changed key or link. Never overwrite the frozen source registers.

### 11. Resume rule

Continue from the last canonical key in the journal. Reconcile source-register hashes before processing the next key.

## Phase 5: Completeness and anomaly scan

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M11](./shared-mechanisms.md#m11-stop-state-recovery-matrix). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Find unmatched, duplicate, high-risk, or unsupported items before mapping and writing.

### 2. Nested sub-goals

- **SG-5.1**: Classify the full population. Check: canonical records with risk class 100%.
- **SG-5.2**: Review every high-risk record. Check: high-risk reviewed count equals high-risk population, coverage 100%.
- **SG-5.3**: Draw a reproducible sample for remaining records. Check: sample rule, positive minimum size or population coverage floor, and rationale are numeric in approved config, selected records reviewed 100%, unexplained material findings 0.

### 3. Entry criteria

Phase 4 canonical dataset is sealed. Risk thresholds, minimum sample size or coverage floor, and reproducible selection rationale are approved in MIGRATION_CONFIG.

### 4. Inputs

Canonical dataset, original evidence references, risk model, sample configuration, and exception schema.

### 5. Owner-tagged actions

`[Red Team]` searches for adversarial failure cases. `[Independent Auditor]` executes the sample. `[Reconciliation Agent]` records exceptions. `[Operator]` approves threshold values and accepts any residual accounting judgment. Gate verifier: `[Red Team]` owns adversarial checks. `[Independent Auditor]` verifies sample reproducibility. `[Operator]` owns acceptance decisions.

**Completeness checks retained from the original anomaly scan:**
1. [Reconciliation Agent] Check documents without ledger entries and classify each as unbooked, duplicate, private, another period, or a supported alternate relation.
2. [Reconciliation Agent] Check ledger entries without documents and bank transactions without explanations.
3. [Reconciliation Agent] For documents without a payment, identify whether the item is open, paid privately, settled by a credit, or offset by a supported amount.
4. [Red Team] Detect duplicates by exact file hash and by a fingerprint of supplier, invoice number, date, currency, and gross value. Keep sensitive values in the controlled workspace.
5. [Red Team] Review international software, subscriptions, hosting, developer services, and other foreign suppliers.
6. [Red Team] Challenge duplicate invoices or payments, missing credit notes, wrong currency or entity, EU versus non-EU treatment, zero rate versus reverse charge, private versus business treatment, tax payments, assets treated as costs, and duplicate depreciation.

### 6. Tool route

Read source artifacts from the workspace. Moneybird reads use guarded read-only access and explicit periods. No writes.

### 7. Outputs and evidence artifacts

`EXCEPTION_LEDGER`, high-risk review report, sample selection seed and population report, and anomaly report under `Exceptions/` and `Reports/`.

### 8. Numeric exit gate

Risk-classified records 100%, high-risk review coverage 100%, configured sample meets its approved minimum 100%, duplicate candidates unresolved 0, unresolved material findings 0.

### 9. Stop conditions

Missing sample configuration, duplicate fingerprint, RED or BLACK record in a proposed write set, uncertain tax treatment, unsupported exception acceptance, or missing original evidence.

### 10. Rollback or compensation

No account mutation. Preserve the review run and re-open only impacted exception rows with a new status event.

### 11. Resume rule

Continue from the last reviewed canonical key after confirming the input hash and sample seed. Re-run the affected selection if the population hash changed.
