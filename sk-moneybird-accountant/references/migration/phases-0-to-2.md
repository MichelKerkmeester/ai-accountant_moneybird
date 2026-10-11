---
title: Migration phases 0 to 2
description: Safety, source inventory, and evidence collection.
trigger_phrases:
  - Jortt to Moneybird migration
  - migration phase gate and exit criteria
  - Dutch bookkeeping migration workflow
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 0 to 2

Safety, source inventory, and evidence collection. Load the [migration index](./README.md) first and use the shared controls in [shared mechanisms](./shared-mechanisms.md).

---

## 1. OVERVIEW

Each phase below uses the same eleven-field contract. Run only the phase selected by the last verified gate. Do not advance while a stop condition remains open.

## Phase 0: Safety and system setup

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M3](./shared-mechanisms.md#m3-append-only-run-journal-approvals-and-crash-resume), [M4](./shared-mechanisms.md#m4-evidence-privacy-and-session-boundary), [M6](./shared-mechanisms.md#m6-access-window-through-writes-and-verification), [M10](./shared-mechanisms.md#m10-write-isolation-decision), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Build a controlled migration workspace and establish the single empty Moneybird trial as both pilot and mirror. The Implementer drafts agent runner, fixture generator, canary harness, and sandbox profile, and the Verifier owns the privacy filter, payload scanner, and adversarial corpus and checks the boundary, egress, and route canaries for Phase 0.

### 2. Nested sub-goals

- **SG-0.1**: Record the administration selector relationship. Check: both selector values resolve to the same administration, equality count 1, separate pilot administration count 0.
- **SG-0.2**: Prove the guard boundary. Check: local stub suite cli-moneybird/cli/moneybird-cli/tests/run-tests.sh passes 1, an official CLI non-GET invocation under MONEYBIRD_GUARD_READ_ONLY=1 returns exit code 6 before any real call 1, real call count 0.
- **SG-0.3**: Set threshold and expiry fields. Check: config fields due by Phase 0 in the Needed by column populated 100%, unapproved threshold rows 0, next expiry date recorded 1.
- **SG-0.4**: Verify the Phase 0 auditfile UI export route. Check: the Operator UI completes an approved test auditfile export in Phase 0 1, product version, XAF version, and year match the approved request 1, receipt and artifact SHA-256 recorded 1.
- **SG-0.5**: Verify a complete Moneybird bulk-read route. Check: synchronization with timestamp and completion counts or a complete paginated fallback with page counts is verified 1, Operator-approved cache-wait value and source basis recorded 1, Independent Auditor verification 1.
- **SG-0.6**: Verify Jortt read-only access. Check: provider scope evidence shows read-only access 1, a local non-GET `jortt-cli call` without `--allow-write` exits 3 before any token request as documented in `cli-jortt/README.md` 1, API request count 0, real Jortt write calls 0.

- **SG-0.7**: Run the agent route. Check: M12 route proof: runner ready 1, script sandbox canary pass 1, OS read-boundary canary pass 1, egress canary pass 1, planted private values blocked 100%, both route canary dispatches complete 2 of 2, agents.* config populated 100%, work units with Verifier PASS or Operator disposition 100%, payload-scan prohibited fields 0, phase-entry boundary canary passed 1, Final review PASS 1.

### 3. Entry criteria

The frozen gap register and approved source scope are recorded. No Phase 1 evidence is required to begin Phase 0. No ledger mutation or guarded API non-GET call is authorized before a phase gate passes. Phase 0 may use the approved Operator UI auditfile export for its test artifact.

### 4. Inputs

Tool skills, frozen gap register, approved source scope, empty trial setup facts, threshold proposals, and source route inventory.

### 5. Owner-tagged actions

[Operator] confirms the single administration, expiry evidence, numeric thresholds, isolation decision, Jortt read scopes, test export approval, and cache-horizon value and source basis. [Orchestrator] records configuration, source scope, and owner assignments. [Evidence Archivist] verifies archive read-only boundaries. [Operator + AI] runs the official Moneybird CLI dry-run test under the read-only lock and captures exit code 6 before any real call. [Operator + AI] invokes a local non-GET `jortt-cli call` without `--allow-write` and records exit code 3 before token request, with zero API requests. Gate verifier: [Independent Auditor] checks both local test results, zero-call evidence, completed Operator UI auditfile artifact, and bulk-read completeness and cache-horizon approval.

[Agent runner] runs the M12 route proof for every sub-goal. [Implementer] drafts the runner, fixtures, canary harness, and sandbox profile. [Verifier] owns the privacy filter, payload scanner, and adversarial corpus, then checks boundary, egress, and both route canaries. [Final reviewer] reviews the phase before Operator approvals.

**Detailed operating sequence retained from the original setup steps:**
1. [Operator] Select one empty Moneybird administration for both pilot and mirror. Set both selectors to that administration. Do not create a second pilot administration and do not write historical records during setup.
2. [Operator + AI] Configure approved tool sessions using the sibling CLI skills. Read-only Moneybird work uses MONEYBIRD_GUARD_READ_ONLY=1 and explicit periods. Do not expose credentials in prompts, arguments, logs, reports, or tracked files.
3. [Operator + AI] Confirm read routes and the selected administration with safe local evidence only. Report status codes and field names, not source names or amounts.
4. [Operator + AI] Confirm the source archive boundary without opening, listing, searching, or reorganizing private source locations. Record the allowed input route and read-only rule.
5. [Orchestrator] Create the folders listed in overview-and-setup.md under migration-workspace/.
6. [Operator] Record the operating rules: no historical VAT, supplementary VAT, or income-tax filing, no historical tax payment, no invented amounts, no unexplained balancing entry, and no newly issued sales invoice. Historical sales documents use the approved external-invoice mapping.
7. [Operator] Create required Moneybird tax rates in the UI and record the configured bookkeeping start date.
8. [Operator] Verify the Jortt provider grant is limited to the required read scopes. Record scope evidence without credential values.
9. [Operator] Complete the approved auditfile test export through the Moneybird UI and record the requested product version, XAF version, year, receipt, and artifact SHA-256. [Independent Auditor] verifies the artifact. Defer the guarded report-export POST until a phase gate has passed.

### 6. Tool route

Jortt uses jortt-cli with read scopes only. The local test invokes a non-GET `jortt-cli call` without `--allow-write` and requires exit code 3 before any token request, as documented in `cli-jortt/README.md`, with zero API requests. Moneybird reads use moneybird-guard with MONEYBIRD_GUARD_READ_ONLY=1 and explicit periods. The Moneybird negative test invokes the official CLI dry-run for a non-GET route under the lock and must exit 6 before a real call. Run the guard stub suite at cli-moneybird/cli/moneybird-cli/tests/run-tests.sh. Phase 0 auditfile testing uses the approved Operator UI export and a separate artifact check. A guarded report-export POST may run only after a prior phase gate passes, with exact Operator approval, a flushed operation-scoped WRITE_INTENT for the requested year, version, and payload hash, `--confirm-write`, a separate writer session, and a locked reader session for download verification. Verify a timestamped synchronization or complete paginated read route and an Operator-approved cache horizon independently checked by the Independent Auditor. UI setup remains Operator-only.

### 7. Outputs and evidence artifacts

MIGRATION_CONFIG, threshold approval, subscription observation, isolation decision and review date, Jortt read-scope evidence, local exit-code-3 no-write result with zero token and API requests, guard stub suite result, locked non-GET exit result, zero-call evidence for both local tests, completed Operator UI auditfile test export with receipt and artifact SHA-256, timestamped synchronization or paginated-read evidence, approved and independently verified cache horizon, phase-contract completeness result, and workspace folder index.

### 8. Numeric exit gate

Config fields due by Phase 0 populated 100%, selector equality 1, second administration count 0, guard stub suite pass count 1, locked non-GET exit code 6 count 1, Jortt read-scope evidence 1, Jortt no-write exit code 3 before token request 1, Jortt API requests 0, real calls from local tests 0, completed Operator UI auditfile test export 1, receipt and artifact hash 1, complete bulk-read route verification 1, cache horizon approved and independently verified 1, phase-contract checks 23 of 23, exposed secret count 0, missing threshold values 0.

M12 gate: runner ready 1, script sandbox canary pass 1, OS read-boundary canary pass 1, egress canary pass 1, planted private values blocked 100%, both route canary dispatches complete 2 of 2, agents.* config populated 100%, work units with Verifier PASS or Operator disposition 100%, Final review PASS 1, payload-scan prohibited fields 0, phase-entry boundary canary passed 1.

### 9. Stop conditions

Selector mismatch, unknown expiry, missing numeric threshold, stub suite failure, locked non-GET exit other than 6, Jortt no-write exit other than 3 or any token or API request, unverified Jortt scope, any real call from a local test, failed UI auditfile export or artifact hash, no complete bulk-read route, missing or unapproved cache horizon, any failed phase-contract check, missing isolation review date, or any request for unapproved write access.

Stop on any M12 stop event.

### 10. Rollback or compensation

No bookkeeping mutation is permitted. Retain prior config versions and mark a superseded version in the run journal. Correct configuration before entry to Phase 1.

### 11. Resume rule

Resume from the last config hash and journal checkpoint. Repeat the failed read-only check and record a new event. Never reuse a failed gate result.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 1: Full source inventory

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M4](./shared-mechanisms.md#m4-evidence-privacy-and-session-boundary), [M8](./shared-mechanisms.md#m8-jortt-pagination-and-source-request-evidence), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Establish the source population and inventory each relevant record class before reconstruction. The Implementer drafts per-class extraction and manifest builders for M1 and M8, and the Verifier independently reproduces source counts and the page chain for Phase 1.

### 2. Nested sub-goals

- **SG-1.1**: Enumerate mandatory source classes and years. Check: invoices, expenses, receipts, each attachment class, loose Inbox items, bank files, XAF files, annual accounts, filed returns, assessments, and reconstructed asset schedules have inventory rows 100%, unclassified classes 0.
- **SG-1.2**: Map each Jortt bank account and IBAN to source bank files per year. Check: account-year pairs with a file or explicit exception 100%, unexplained unmatched pairs 0.
- **SG-1.3**: Inventory annual tax regimes and filing periods. Check: year-regime rows 100%, every KOR, ICP, OSS, and other relevant declaration marked applicable or not applicable with evidence, unknown statuses 0.
- **SG-1.4**: Resolve the Jortt general-ledger printout status. Check: capability decision recorded 1, gates relying on an unverified printout 0.
- **SG-1.5**: Build the document registry with source identity and file evidence. Check: required registry fields populated 100%, source hash coverage 100%.

- **SG-1.6**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, source counts and page-chain reproduction 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 0 passed and source scope is approved. Source records remain read-only.

### 4. Inputs

Source archive inventory, Jortt account and transaction lists, bank file catalog, tax documents, and `MIGRATION_CONFIG`.

### 5. Owner-tagged actions

[Evidence Archivist] inventories classes, captures source-side totals, and hashes. [Document Agent] builds the invoice inventory. [Operator] supplies UI-only XAF, annual accounts, return, assessment, and bank export evidence. [Tax Filing Agent] records annual regimes and declaration applicability. [Orchestrator] records whether a Jortt ledger printout is usable, unavailable, or unverified. Gate verifier: [Independent Auditor] reproduces source totals, full page counts, account-to-file counts, and declaration coverage.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts per-class extraction and manifest builders for M1 and M8. [Verifier] independently reproduces source counts and the page chain. [Final reviewer] reviews the phase before Operator approvals.

**Detailed inventory fields retained from the original source scan:**
1. [Evidence Archivist] Inventory sales invoices, purchase invoices, receipts, credit notes, annual accounts, XAF files, bank exports, VAT returns, income-tax returns, assessments, and asset evidence.
2. [Document Agent] Build CLOUD_INVOICE_REGISTRY with source key, controlled archive path, file name, SHA-256, document type, invoice number and date, entity and country, VAT identifier, currency, net, VAT, gross, reverse-charge flag, and confidence. Record sensitive row-level values only in the controlled workspace.
3. [Evidence Archivist] Count Jortt customers, sales invoices, expenses, receipts, every attachment class, Inbox items, bank accounts, and bank transactions by period. Inventory Inbox items separately from booking-linked exports and reconcile attachment and Inbox counts and links by class.
4. [Orchestrator] Derive the first business year from the earliest supported business event, including a sale, purchase, business bank transaction, VAT filing, income-tax filing with business income, or XAF.
5. [Tax Filing Agent] Build YEAR_SOURCE_MATRIX with each source class marked COMPLETE, PARTIAL, or MISSING. Keep actual assigned filing cadence and declaration applicability in the tax calendar.

**Original year availability matrix retained as a controlled template:**

| Year derived from source scope | Documents | XAF | Bank | VAT | Income tax | Annual accounts | Assets |
|---|---|---|---|---|---|---|---|
| One row per in-scope year | Status and evidence link | Status and evidence link | Status and evidence link | Status and evidence link | Status and evidence link | Status and evidence link | Status and evidence link |


### 6. Tool route

Jortt reads use jortt-cli with --all and complete next-link paging. Record page size, page count, item counts, status, and the independent source UI or portal total for every export. Jortt has no general-ledger API or UI export under the current tool contract, so no gate relies on an unverified printout. Moneybird reads use the guard read-only lock and explicit periods. No source API writes.

### 7. Outputs and evidence artifacts

Versioned SOURCE_MANIFEST, CLOUD_INVOICE_REGISTRY, YEAR_SOURCE_MATRIX, bank account and IBAN-to-file matrix, tax regime and declaration calendar, per-export source control totals, pagination evidence, ledger printout capability decision, exclusions report, and schema manifest under Manifests/ and Registers/.

### 8. Numeric exit gate

Source class and attachment or Inbox link coverage 100%, independent source totals compared 100%, paged-list completion 100%, account-year bank pair coverage 100%, year regime and declaration rows 100%, unverified printout dependencies 0, unexplained missing source links 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, source counts and page-chain reproduction 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Missing page link, unexplained empty result, unavailable year scope, unclassified declaration, missing bank account file, missing attachment class, absent source-side export total, or total and manifest count mismatch.

Stop on any M12 stop event.

### 10. Rollback or compensation

Do not change source records. Quarantine an incomplete extract, preserve its hash, and replace it only with a new version after a complete re-extract.

### 11. Resume rule

Continue from the last manifest page or file checkpoint. Re-read the affected source scope and compare its new artifact hash before resuming downstream work.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.

## Phase 2: Collect missing sources and seed archive

Mechanisms used: [M1](./shared-mechanisms.md#m1-register-schemas-and-complete-source-manifests), [M4](./shared-mechanisms.md#m4-evidence-privacy-and-session-boundary), [M7](./shared-mechanisms.md#m7-exception-and-threshold-control), [M12](./shared-mechanisms.md#m12-external-agent-route). Use the [route contract](./shared-mechanisms.md#route-contract) for every Jortt or Moneybird operation.

### 1. Goal

Complete the required evidence set and create an independently inspectable source archive before any reconstruction. The Implementer drafts the missing-source checklist, archive seeding and hash scripts, and retention table template, and the Verifier repeats the archive restore test and hash recompute for Phase 2.

### 2. Nested sub-goals

- **SG-2.1**: Obtain required evidence by year and source. Check: every mandatory source class in Phase 1 is present or has an approved exception 100%, actual filed VAT return and confirmation evidence for every filed VAT period or evidence-backed not-applicable status 100%, exceptions waiving filed VAT return evidence 0, income-tax returns and assessments present or carrying the approved unavailability status that Phase 11 accepts 100%, unexplained missing classes 0.
- **SG-2.2**: Reconcile every Jortt account to full-year bank evidence. Check: covered account-year pairs 100%, unexplained exceptions 0.
- **SG-2.3**: Seed and test the archive. Check: manifest checksums and independent source totals match 100%, independent sample readability passes 100%, each record-class retention rule has an Operator-approved source basis, duration, start event, derived end date, owner, independent location, and readability evidence 100%, unresolved retention rules 0.
- **SG-2.4**: Establish first-business-year opening support. Check: start-year basis recorded 1, each opening account component has source evidence 100%, approver and treatment of pre-business funds recorded 100%, unsupported opening positions 0. Without prior closing evidence, the Operator or adviser approves a source-based schedule before the gate passes.
- **SG-2.5**: Select the start boundary. Check: configured start date and start-year basis recorded 100%, unsupported opening positions 0.

- **SG-2.6**: Run the agent route. Check: M12 checks: work units with Verifier PASS or Operator disposition 100%, archive restore test pass 1, archive hash recompute 100%, payload-scan prohibited fields 0, boundary canary at phase entry passed 1, Final review PASS 1.

### 3. Entry criteria

Phase 1 inventory is complete. Each missing source has an Operator task and a due date.

### 4. Inputs

Missing-source report, Jortt inventory, operator UI exports, bank files, filed returns and confirmations, annual accounts, and any adviser schedules.

### 5. Owner-tagged actions

[Operator] exports Jortt XAF, annual accounts, filed VAT evidence, tax evidence, and bank files and records independent source UI or portal totals for every export. [Evidence Archivist] downloads supported records and attachments through Jortt CLI, reconciles pages and class links, and builds the archive manifest. [Tax Filing Agent] distinguishes filed returns from summaries. [Operator] approves each situation-dependent retention rule from its source basis and approves the first-business-year opening schedule. Gate verifier: [Independent Auditor] reproduces all class counts, source totals, retention date calculations, and restore samples. [Operator] owns missing UI exports and opening-balance approval.

[Agent runner] runs the M12 loop for every sub-goal. [Implementer] drafts the missing-source checklist, archive seeding and hash scripts, and retention table template. [Verifier] repeats the archive restore test and hash recompute. [Final reviewer] reviews the phase before Operator approvals.

**Detailed source collection sequence retained from the original plan:**
1. [Operator] For each in-scope period, export Jortt XAF, annual accounts, and actual filed VAT returns through the documented UI routes. A VAT summary is not a filed return.
2. [Evidence Archivist] Retrieve supported sales invoice PDFs, purchase documents, attachments, and Inbox receipts through the documented read route. Record excluded and unavailable classes.
3. [Operator] Supply bank evidence per business account and full period. Prefer CAMT.053, then MT940, then official PDF statements. Other exports are analysis evidence only.
4. [Operator] Supply filed income-tax returns, final and amended assessments, available VAT documents, and relevant filing correspondence through the approved portal route.
5. [Operator] Request accountant schedules when available, including annual figures, tax-profit calculations, asset schedules, correction entries, supplementary filings, and VAT reconciliations.
6. [Orchestrator] Select the Moneybird start year as the earliest year for which that year and every following in-scope year meet the evidence gate. Earlier years remain archive-only. Determine a supported opening position from prior closing evidence or an Operator-approved first-business-year schedule. The schedule records the supported start date, each account component and source, and treatment of pre-business funds. Never infer a missing balance.

### 6. Tool route

Jortt records use `jortt-cli` read-only. XAF and annual reports use Jortt UI. Bank and tax portals are Operator-only. Moneybird reads use guarded read-only access only when needed for scope checks.

### 7. Outputs and evidence artifacts

SOURCE_MANIFEST_v2, Archive/ source bundle, mandatory class inventory, independent source-total reconciliation, complete retention matrix, restore and readability report, filed-return evidence index, and opening-position decision record.

### 8. Numeric exit gate

Required source class coverage 100%, actual filed VAT return and confirmation evidence for every filed VAT period or evidence-backed not-applicable status 100%, exceptions waiving filed VAT return evidence 0, source totals and account-year pairs reconciled 100%, artifact hashes verified after transfer 100%, retention rules and approvals complete 100%, independently recomputed end dates match 100%, unresolved retention rules 0, first-business-year component support complete 100%, independent restore sample pass 1, missing required sources 0, unsupported opening positions 0.

M12 gate: work units with Verifier PASS or Operator disposition 100%, archive restore test pass 1, archive hash recompute 100%, Final review PASS 1, payload-scan prohibited fields 0, boundary canary at phase entry passed 1.

### 9. Stop conditions

Missing actual filed VAT return or confirmation for any filed VAT period, any exception offered to waive that evidence, income-tax return or assessment missing without approved unavailability status, unverified archive file, missing attachment or loose Inbox class, missing independent source-side total, bank account without full-period source, unsupported or unapproved retention rule, or opening position without supported account components and an approved basis.

Stop on any M12 stop event.

### 10. Rollback or compensation

Preserve Jortt unchanged. Mark the archive snapshot incomplete and create a new version. Do not cancel or modify any source subscription in this phase.

### 11. Resume rule

Resume from the failed artifact or source class. Recompute its hash, append a journal event, then rerun archive reconciliation for the affected class.

For M12 work, resume only from AGENT_VERIFIED or a later verified state. AGENT_DRAFTED restarts at verification.
