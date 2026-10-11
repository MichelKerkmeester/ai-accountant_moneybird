---
title: Migration overview and setup
description: Migration goal, tool boundaries, workspace layout, and required configuration.
trigger_phrases:
  - moneybird migration setup
  - migration configuration and thresholds
  - Jortt to Moneybird start date
  - migration workspace
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration overview and setup

Read this reference before Phase 0. The [migration index](./README.md) maps every phase. The [shared mechanisms](./shared-mechanisms.md) define the routes, journal, manifests, access checks, and recovery behavior.

## Goal and evidence sources

Rebuild the administration in Moneybird and verify it against four independent evidence sources:

1. Original invoices and receipts in the approved document archive.
2. Historical bookkeeping records and reports from Jortt.
3. Official bank transaction exports.
4. VAT and income-tax returns that were actually filed.

Moneybird becomes the authoritative historical record only after the four sources agree within numeric thresholds recorded in `MIGRATION_CONFIG`. The Operator owns credentials, UI exports, approvals, bank-file imports, tax-rate creation, period locks, return filing, and all tax or accounting decisions.

The public skill package contains no personal or financial records. Keep record-level evidence in the ignored controlled `migration-workspace/`. Do not alter original source files. Only approved inputs enter the workspace.

## Tool and access boundaries

### Jortt

Use `jortt-cli` for read-only API extraction with read scopes. List reads use `--all`, follow the complete next-link chain, and record page counts, item counts, statuses, rate-limit events, and independent source totals. The documented page size is at most 100 items and the request limit is 10 per second. Missing pages, unexplained page caps, or mismatched totals stop dependent work.

The tool contract does not provide a Jortt XAF export, general-ledger export, general journal, or filed VAT or income-tax return. The Operator uses the UI for XAF auditfiles, annual accounts, filed returns, and other UI-only exports. A Jortt VAT summary is not a filed return. Do not request Jortt write access or cancel Jortt before Phase 22 passes.

### Moneybird

Use `moneybird-guard` for reads and approved writes. Every read session sets `MONEYBIRD_GUARD_READ_ONLY=1`, uses explicit periods, and uses synchronization with timestamp and completion counts for complete bulk reads. If synchronization is unavailable, wait beyond the Operator-approved and Independent Auditor verified cache horizon in `MIGRATION_CONFIG` and use a complete paginated read before making a retry decision. A missing or unapproved horizon blocks a wait-based retry. Token scopes do not create a read-only token.

The documented shared-IP limit is 150 requests per five minutes overall and 50 report requests per five minutes. Keep one shared request ledger. On 429, stop the affected sequence and wait the recorded `Retry-After`. Do not automatically replay a request.

Every non-GET call requires a passed phase gate, Operator approval, a flushed `WRITE_INTENT`, and `--confirm-write`. Phases 7, 8, and 16 are pilot or mirror batches and do not use `--production`. Phase 18 final-delta writes remain mirror batches until the Operator approves go-live. Phases 19 to 21 are production batches after Phase 18 passes and require the Operator's approval for each use of `--production`. Verify each write with a later synchronized read or after the approved and independently verified cache wait. Reader sessions always keep the read-only lock enabled. Phase 0 auditfile testing uses the Operator UI. A guarded auditfile POST is allowed only after a phase gate passes and uses an operation-scoped approval and flushed intent in a separate writer session. Never clear the lock in a reader session.

CAMT.053 and MT940 imports, tax-rate creation, period locking, manual historical VAT status, and Jortt UI exports are Operator UI actions. Moneybird list and report behavior can be period-limited or cached. Use explicit periods, complete reads, and the current sibling tool instructions before relying on a result. Reports cover no more than the documented period per request. Confirm any delete or correction with a separate read-back.

### Supported target operation routes

| Need | Guarded route | Operator UI or decision |
|---|---|---|
| Historical sales invoices | External sales invoice route with original number, date, and source file attached. | Operator approves the batch. |
| Purchase invoices and receipts | Document record with the original attachment. | Operator handles any UI-only setup. |
| Journal entries, private items, and corrections | General journal document after the phase gate and approval. | Operator approves accounting treatment. |
| Bank history | Read and reconcile imported statement records. | Operator imports CAMT.053 or MT940 files through the UI. |
| Link payments to documents | Guarded payment-link route with a write intent and read-back. | Operator approves the batch. |
| Ledger accounts | Create or update only with the required RGS code and approved mapping. | Operator approves accounting judgments. |
| Tax rates | Read existing rates through the guarded route. | Operator creates rates in the UI. |
| Fixed assets and depreciation | Asset records with historic value changes and read-back. | Operator approves asset treatment. |
| Profit, balance, and general-ledger reports | Guarded read with explicit periods. Reports may cover at most 12 months per request. | Operator may use UI reports as independent evidence. |
| Moneybird auditfile | Operator UI test export in Phase 0. Guarded report-export POST followed by a download read only after a phase gate passes. | Operator approves the exact year and version. Each POST has an operation-scoped flushed `WRITE_INTENT`, separate writer session, receipt, and artifact hash. |
| Historical VAT filing status | No agent write route. | Operator uses the documented manual filing-status action. |
| Period lock or unlock | Guarded read for lock state only. | Operator locks or unlocks through the UI. |
| Wrong record correction or deletion | Gated guarded write, linked exception, and separate read-back. | Operator approves the correction and any unlock. |

The detailed command syntax and current API fields belong to the sibling [cli-jortt](../../../cli-jortt/SKILL.md) and [cli-moneybird](../../../cli-moneybird/SKILL.md) skills. Never put a token in an argument, prompt, log, report, or tracked file.

### Credential and session boundary

| Access profile | Owner and allowed use |
|---|---|
| Jortt read identity | Operator provisions it with read scopes. Source readers use it only through the approved CLI route. |
| Moneybird read session | Analysis, mapping, audit, and Red Team roles set `MONEYBIRD_GUARD_READ_ONLY=1`. |
| Moneybird writer identity | Migration Writer only, isolated behind `moneybird-guard`. The read-only variable is absent only in the separate approved writer session. Close it after the approved calls and perform read-back in a locked reader session. |
| Pilot administration alias | Operator sets pilot and mirror selectors to the same empty administration. Phases 7, 8, and 16 use its pilot or mirror route. Phases 19 to 21 use production mode only after Phase 18 approval. |

### Administration and write isolation

Use one empty Moneybird administration for both pilot and mirror. Both administration selectors must resolve to the same administration. Do not create a second pilot administration. Keep the reader and writer sessions separate. Default to an isolated writer identity behind `moneybird-guard`. Guard-only isolation is permitted only when the Operator records why separation is unavailable, accepts the residual risk, and confirms every read uses the global read-only lock.

## Workspace layout

Keep finance artifacts in the ignored `migration-workspace/` and preserve existing folders. Use these locations:

- `Schemas/` for versioned register schemas.
- `Manifests/` for export scope, source totals, pages, file size, and hashes.
- `Registers/` for source-specific agent registers.
- `Inputs/<role>/` for the sealed input folder assigned to each role.
- `Mappings/` for category, tax, ledger, and document mappings.
- `Exceptions/` for the append-only exception ledger.
- `Reports/` for pre-write, pilot, period, year, and audit reports.
- `Snapshots/` for frozen inputs and year-lock snapshots.
- `WriteJournal/` for local stable keys, payload hashes, attempt state, and target IDs.
- `RunJournal/` for the append-only JSONL state and approval history.
- `Archive/` for source exports, post-freeze deltas, and restoration evidence.
- `Reviews/` for independent audit and red-team reports.
- `Handoff/` for the approved final handoff.

Prompts and tool transcripts contain only schemas, field names, phase or record-class labels, opaque record keys, aggregate counts, status, and evidence paths. Keep personal names, supplier or customer details, account identifiers, invoice numbers, amounts, and source payloads in the controlled workspace only. Redact tool output before it enters a session transcript.

## Required `MIGRATION_CONFIG` fields

The Orchestrator maintains the versioned config. The Operator supplies or approves human decisions. Every value has an owner, evidence path, timestamp, and approval where required. No current year is hard-coded. Derive the next historical work year from the configured start date and last locked year. Use the actual calendar year for parallel current-year work only when it is at or after the configured start date and is not already locked.

| Field | Owner | Required value or evidence |
|---|---|---|
| `config_version` | [Orchestrator] | Monotonic config version and schema hash. |
| `configured_start_date` | [Operator] | Approved bookkeeping start boundary. |
| `start_year_basis` | [Operator] | Prior closing evidence or an approved first-business-year opening schedule. |
| `opening_position.rule` | [Operator] | Prior closing position or source-based first-business-year schedule with its evidence basis. |
| `opening_position.components` | [Operator] | Account composition, supported start date, source schedule, and treatment of pre-business funds. |
| `opening_position.approval` | [Operator] | Approval identity, role, timestamp, rationale, and evidence path. |
| `last_locked_year` | [Orchestrator] | Latest year with verified lock evidence, or empty before a lock exists. |
| `next_historical_year` | [Orchestrator] | Derived as the first unlocked year at or after the configured start year, using `last_locked_year + 1` where years are contiguous. Never enter a fixed calendar year. |
| `source_scope` | [Operator] | Approved source systems, record classes, periods, exclusions, and source-total method. |
| `pilot_administration_alias` | [Operator] | Opaque alias for the single empty target administration. |
| `mirror_administration_alias` | [Operator] | Must equal the pilot alias. |
| `selector_equality_evidence` | [Orchestrator] | Read-only evidence that both selectors resolve to the same administration. |
| `second_administration_count` | [Independent Auditor] | Must be zero. |
| `source_freeze_at` | [Operator] | Approved freeze date and time. Set before Phase 17. |
| `last_source_key` | [Evidence Archivist] | Last included source key at the freeze boundary. |
| `delta_schema` | [Evidence Archivist] | Versioned fields for capturing post-freeze changes. |
| `source_total_method` | [Evidence Archivist] | Independent UI or portal control outside each exported artifact, with derivation and verifier. |
| `jortt.read_scope_evidence` | [Operator] | Provider evidence of read-only granted scopes and result of the local no-write check. No credential value is recorded. |
| `access.state` | [Operator] | Observed trial or paid-package state before each write batch. |
| `access.expiry_date` | [Operator] | Observed trial or package expiry date. |
| `access.evidence_source` | [Operator] | Evidence path and source used to confirm access state. |
| `access.observed_at` | [Operator] | Observation date and time. Refresh before every non-GET batch. |
| `access.renewal_owner` | [Operator] | Named role or person responsible for renewal. |
| `access.alert_evidence` | [Orchestrator] | Evidence that an expiry alert is active and assigned. |
| `access.paid_package_horizon` | [Operator] | Before Phase 17, confirm coverage through the next live VAT period and year close. |
| `monitoring.start_date` | [Orchestrator] | Date Phase 18 passes. |
| `monitoring.duration` | [Operator] | Positive configured monitoring duration and unit. |
| `monitoring.end_date` | [Orchestrator] | Derived from the approved start date and duration. |
| `monitoring.monthly_cycles_required` | [Operator] | Positive minimum number of monthly cycles or an approved schedule rule. |
| `monitoring.vat_cycles_required` | [Operator] | Positive minimum number of VAT-period cycles or an approved schedule rule. |
| `monitoring.yearly_cycles_required` | [Operator] | Required yearly cycle count or explicit applicability rule. |
| `sample.rule` | [Operator] | Reproducible sampling method and population boundary. |
| `sample.minimum_size` | [Operator] | Positive minimum sample size or approved population coverage floor. |
| `sample.seed` | [Orchestrator] | Fixed seed or reproducible seed source. |
| `sample.rationale` | [Operator] | Why the sample size and rule provide adequate coverage. |
| `sample.approver` | [Operator] | Approval identity and role. |
| `sample.approved_at` | [Orchestrator] | Approval timestamp and evidence reference. |
| `thresholds.*.value` | [Operator] | Numeric value and unit for every reconciliation, risk, materiality, and cumulative VAT limit. |
| `thresholds.*.approver` | [Operator] | Approval identity and role for each threshold. |
| `thresholds.*.approved_at` | [Orchestrator] | Approval timestamp and evidence reference. |
| `thresholds.*.rationale` | [Operator] | Source-linked reason for each value. |
| `thresholds.*.evidence_path` | [Orchestrator] | Controlled evidence supporting the value and approval. |
| `isolation.decision` | [Operator] | Isolated writer identity or approved guard-only exception. |
| `isolation.rationale` | [Operator] | Reason and residual risk accepted if isolation is unavailable. |
| `isolation.owner` | [Orchestrator] | Owner responsible for the control. |
| `isolation.evidence_path` | [Orchestrator] | Evidence for the selected boundary. |
| `isolation.review_date` | [Operator] | Current review date. An absent or expired review blocks Phase 18. |
| `auditfile.route` | [Operator] | Phase 0 Operator UI export route, requested product and XAF versions, year, and artifact evidence. Record the pinned guarded POST route at its first use after a phase gate passes. |
| `auditfile.approval_reference` | [Operator] | Human approval for the exact year and version before each UI export or guarded export POST. |
| `auditfile.receipt_hash` | [Evidence Archivist] | Receipt and SHA-256 for the exported artifact. |
| `bulk_read.route` | [Independent Auditor] | Verified synchronization route or complete paginated fallback. |
| `bulk_read.completeness_evidence` | [Independent Auditor] | Timestamp, page counts, completion counts, and independent verification of the approved cache-wait rule. |
| `bulk_read.cache_horizon` | [Operator] | Operator-approved value and unit, applicable route, source basis, approval identity and time, and evidence path. Missing or unapproved values block wait-based retries. |
| `retention.rules[]` | [Operator] | For every class, record source-supported basis, duration, start event, derived end date, independent archive, owner, approver, approval, and readability. Apply seven years to basic administration and ten years to immovable-property and OSS records where those source facts apply. Record any longer contract-survival term as an Operator-approved value with its basis. |
| `auditfile.session_boundary` | [Orchestrator] | For a guarded POST, dedicated writer session reference, start and close evidence, and separate locked read-back session. Mark pending until the first gated POST. |
| `auditfile.job_status` | [Evidence Archivist] | Completed Moneybird export job, product version, XAF version, year, receipt, and artifact SHA-256. |
| `write_approval_reference` | [Operator] | Approval for each non-GET batch, linked from the journal. |
| `run_journal_path` | [Orchestrator] | Controlled JSONL journal location. |

Missing fields, unapproved thresholds, unknown access expiry, unsupported source scope, unsupported retention basis, missing approver, or an incomplete read route block Phase 0 or the affected gate. The guarded auditfile POST route may remain pending through Phase 0 and must be verified before its first use after a phase gate passes. Situation-dependent retention terms require an Operator-approved `MIGRATION_CONFIG` value with its approver and basis recorded. Threshold values do not authorize a balancing entry.

## Proposed threshold rows

The historical plan's starting values are proposals only. The Operator confirms each value, unit, rationale, evidence, and approval timestamp in `MIGRATION_CONFIG` during Phase 0. Do not apply an unapproved proposal.

| Check | Initial proposal to confirm | Applies to |
|---|---:|---|
| Bank balance per account at period end | EUR 0.00 unexplained difference | Period and year reconciliation |
| VAT per return box | At most EUR 1.00 as a `ROUNDING` difference | VAT verification |
| Revenue and costs per main group per year | At most EUR 5.00 unexplained | Annual check |
| Profit compared with annual accounts and filed income-tax evidence | EUR 0.00 unexplained, every difference explained | Annual and income-tax bridge |
| Balance-sheet line per year | EUR 0.00 unexplained | Annual check |
| Original-document support | 100% above EUR 50.00 and at least 98% overall by count | Completeness and risk review |
| Missing original document | Always create an exception | All phases |
| Exact copied data | Zero unexplained difference | All exact-copy reconciliations |

Thresholds are applied only to their named check. Do not net values across accounts, boxes, or periods. The quarter and year cumulative VAT caps are separate numeric config fields with Operator approval.

## Phase 0 setup sequence

1. [Operator] Confirms the one empty Moneybird administration and sets both pilot and mirror selectors to it.
2. [Operator] Records the configured start date and start-year evidence.
3. [Orchestrator] Creates the workspace folders and versioned `MIGRATION_CONFIG`.
4. [Operator] Records the trial or package state, observed expiry, evidence source, renewal owner, and expiry alert evidence.
5. [Operator] Proposes and approves numeric thresholds, sample sizes, the sample rule, and monitoring period with rationale.
6. [Operator] Decides whether writer isolation is available, records the decision, and sets a review date.
7. [Operator + AI] Verifies the local guard stub suite and the read-only negative test. A non-GET under the read-only lock must exit with code 6 before a real call. Real call count is zero.
8. [Operator] Performs an approved auditfile test export through the Moneybird UI. Record the exact year and version, job completion, receipt, and artifact SHA-256. [Independent Auditor] verifies the artifact and complete Moneybird bulk-read route. Defer the guarded report-export POST until a phase gate has passed.
9. [Operator] Records provider evidence that the Jortt identity has read-only scopes. [Operator + AI] Run the local no-write check and capture the documented block before any real Jortt call.
10. [Independent Auditor] Verifies every phase contract once before Phase 0 passes. Confirm phases 0 through 22 each have one heading, all 11 fields, and a numeric exit gate.
11. [Orchestrator] Records the config hash, workspace index, owners, and first journal checkpoint.

Do not write historical records in Phase 0. Do not create a second pilot administration. Never run the auditfile POST before a phase gate passes or in a reader session. Read the selected phase contract only after setup evidence is recorded.
