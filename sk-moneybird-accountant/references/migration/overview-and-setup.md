---
title: Migration overview and setup
description: Migration goal, tool boundaries, workspace layout, and required configuration.
nav_label: "Migration overview and setup"
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

## 1. OVERVIEW

This reference covers the migration goal, the tool boundaries, the workspace layout and the required configuration. Read it before Phase 0, with the migration index for the phase map and the shared mechanisms for the routes and controls.

---

## Goal and evidence sources

Rebuild the administration in Moneybird and verify it against four independent evidence sources:

1. Original invoices and receipts in the approved document archive.
2. Historical bookkeeping records and reports from Jortt.
3. Official bank transaction exports.
4. VAT and income-tax returns that were actually filed.

Moneybird becomes the authoritative historical record only after the four sources agree within numeric thresholds recorded in `MIGRATION_CONFIG`. The Operator owns credentials, UI exports, approvals, bank-file imports, tax-rate creation, period locks, return filing, and all tax or accounting decisions.

The public skill package contains no personal or financial records. Keep record-level evidence in the ignored controlled `migration-workspace/`. Do not alter original source files. Only approved inputs enter the workspace.

The work runs on the M12 agent route. DeepSeek drafts, Codex verifies, Claude gives the final review per phase, and the Operator decides. No real record leaves the machine.

## Tool and access boundaries

### Jortt

Use `jortt-cli` for read-only API extraction with read scopes. List reads use `--all`, follow the complete next-link chain, and record page counts, item counts, statuses, rate-limit events, and independent source totals. The documented page size is at most 100 items and the request limit is 10 per second. Missing pages, unexplained page caps, or mismatched totals stop dependent work.

The tool contract does not provide a Jortt XAF export, general-ledger export, general journal, or filed VAT or income-tax return. The Operator uses the UI for XAF auditfiles, annual accounts, filed returns, and other UI-only exports. A Jortt VAT summary is not a filed return. Do not request Jortt write access or cancel Jortt before Phase 22 passes.

### Moneybird

Use `moneybird-guard` for reads and approved writes. Every read session sets `MONEYBIRD_GUARD_READ_ONLY=1`, uses explicit periods, and uses synchronization with timestamp and completion counts for complete bulk reads. If synchronization is unavailable, wait beyond the Operator-approved and Independent Auditor verified cache horizon in `MIGRATION_CONFIG` and use a complete paginated read before making a retry decision. A missing or unapproved horizon blocks a wait-based retry. Token scopes do not create a read-only token.

The documented shared-IP limit is 150 requests per five minutes overall and 50 report requests per five minutes. Keep one shared request ledger. On 429, stop the affected sequence and wait the recorded `Retry-After`. Do not automatically replay a request.

Every non-GET call requires a passed phase gate, Operator approval, a flushed `WRITE_INTENT` with its approval reference, `--confirm-write`, and `--approval <ref>`. The guard checks the reference against the run journal and refuses a write without the writer configuration. Phases 7, 8, and 16 are pilot or mirror batches and do not use `--production`. Phase 18 final-delta writes remain mirror batches until the Operator approves go-live. Phases 19 to 21 are production batches after Phase 18 passes and require the Operator's approval for each use of `--production`. Verify each write with a later synchronized read or after the approved and independently verified cache wait. Reader sessions always keep the read-only lock enabled. Phase 0 auditfile testing uses the Operator UI. A guarded auditfile POST is allowed only after a phase gate passes and uses an operation-scoped approval and flushed intent in a separate writer session. Never clear the lock in a reader session.

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
| Moneybird auditfile | Operator UI test export in Phase 0. Guarded report-export POST followed by a download read only after a phase gate passes. | Operator approves the exact year and version. Each POST has an operation-scoped flushed `WRITE_INTENT`, `--approval <ref>`, separate writer session, receipt, and artifact hash. |
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
- `Plans/` for the phase dashboard copied from the plan kit in `assets/migration/`. The phase packets live in the git-ignored working copy of `specs/000-migration-template/`.
- `AgentDesk/` for agent-facing briefs, drafts, fixtures, scripts, checks, summaries, verdicts, final reviews, and logs.

Prompts and tool transcripts contain only schemas, field names, phase or record-class labels, opaque record keys, HMAC hashes, aggregate counts with values from 1 to 9 shown as `<10`, status, approval references, and evidence paths. CLI calls in agent sessions print summaries only and never use `--print-body`. Keep personal names, supplier or customer details, account identifiers, invoice numbers, amounts, and source payloads in the controlled workspace only. Redact tool output before it enters a session transcript.

## Required `MIGRATION_CONFIG` fields

The Orchestrator maintains the versioned config. The Operator supplies or approves human decisions. Every value has an owner, evidence path, timestamp, and approval where required. The Needed by column names the first phase whose gate requires the field. A phase gate counts only fields due at or before that phase, so a field due later never blocks an earlier phase. A field may be recorded during its listed phase. A field still missing at that phase gate stops the phase. A derived or event field is outside gate counting until its named event happens. From then on, every phase that uses the field checks it, and a missing value stops that phase. No current year is hard-coded. Derive the next historical work year from the configured start date and last locked year. Use the actual calendar year for parallel current-year work only when it is at or after the configured start date and is not already locked.

| Field | Owner | Needed by | Required value or evidence |
|---|---|---|---|
| `config_version` | [Orchestrator] | Phase 0 | Monotonic config version and schema hash. |
| `configured_start_date` | [Operator] | Phase 0 | Approved bookkeeping start boundary. |
| `start_year_basis` | [Operator] | Phase 2 | Prior closing evidence or an approved first-business-year opening schedule. |
| `opening_position.rule` | [Operator] | Phase 2 | Prior closing position or source-based first-business-year schedule with its evidence basis. |
| `opening_position.components` | [Operator] | Phase 2 | Account composition, supported start date, source schedule, and treatment of pre-business funds. |
| `opening_position.approval` | [Operator] | Phase 2 | Approval identity, role, timestamp, rationale, and evidence path. |
| `last_locked_year` | [Orchestrator] | Derived after each Phase 14 lock | Latest year with verified lock evidence, or empty before a lock exists. |
| `next_historical_year` | [Orchestrator] | Derived after each Phase 14 lock | Derived as the first unlocked year at or after the configured start year, using `last_locked_year + 1` where years are contiguous. Never enter a fixed calendar year. |
| `source_scope` | [Operator] | Phase 0 | Approved source systems, record classes, periods, exclusions, and source-total method. |
| `pilot_administration_alias` | [Operator] | Phase 0 | Opaque alias for the single empty target administration. |
| `mirror_administration_alias` | [Operator] | Phase 0 | Must equal the pilot alias. |
| `selector_equality_evidence` | [Orchestrator] | Phase 0 | Read-only evidence that both selectors resolve to the same administration. |
| `second_administration_count` | [Independent Auditor] | Phase 0 | Must be zero. |
| `source_freeze_at` | [Operator] | Phase 16 | Approved freeze date and time, recorded in Phase 16 before the Phase 17 freeze. |
| `last_source_key` | [Evidence Archivist] | Phase 17 | Last included source key at the freeze boundary. |
| `delta_schema` | [Evidence Archivist] | Phase 16 | Versioned fields for capturing post-freeze changes. |
| `source_total_method` | [Evidence Archivist] | Phase 1 | Independent UI or portal control outside each exported artifact, with derivation and verifier. |
| `jortt.read_scope_evidence` | [Operator] | Phase 0 | Provider evidence of read-only granted scopes and result of the local no-write check. No credential value is recorded. |
| `access.state` | [Operator] | Phase 0 | Observed trial or paid-package state before each write batch. |
| `access.expiry_date` | [Operator] | Phase 0 | Observed trial or package expiry date. |
| `access.evidence_source` | [Operator] | Phase 0 | Evidence path and source used to confirm access state. |
| `access.observed_at` | [Operator] | Phase 0 | Observation date and time. First recorded by Phase 0. M6 requires a fresh observation before every non-GET batch and blocks the batch when it is stale or missing. |
| `access.renewal_owner` | [Operator] | Phase 0 | Named role or person responsible for renewal. |
| `access.alert_evidence` | [Orchestrator] | Phase 0 | Evidence that an expiry alert is active and assigned. |
| `access.paid_package_horizon` | [Operator] | Phase 17 | By the Phase 17 gate, confirm coverage through the next live VAT period and year close. |
| `parallel.cycles_required` | [Operator] | Phase 0 | Positive minimum number of pre-cutover parallel comparison cycles or a duration, with rationale. Phase 16 checks completed cycles against it. |
| `monitoring.start_date` | [Orchestrator] | Derived when Phase 18 passes | Date Phase 18 passes. |
| `monitoring.duration` | [Operator] | Phase 0 | Positive configured monitoring duration and unit, or `OPEN_ENDED`, where monitoring runs until the Operator records its end. |
| `monitoring.end_date` | [Orchestrator] | Derived when Phase 18 passes, or when the Operator ends `OPEN_ENDED` monitoring | Derived from the approved start date and duration. For `OPEN_ENDED`, the date of the Operator's recorded end decision, with approval and evidence path. The Phase 22 entry checks still apply in full. |
| `monitoring.monthly_cycles_required` | [Operator] | Phase 0 | Positive minimum number of monthly cycles or an approved schedule rule. |
| `monitoring.vat_cycles_required` | [Operator] | Phase 0 | Positive minimum number of VAT-period cycles or an approved schedule rule. |
| `monitoring.yearly_cycles_required` | [Operator] | Phase 0 | Required yearly cycle count or explicit applicability rule. |
| `sample.rule` | [Operator] | Phase 0 | Reproducible sampling method and population boundary. |
| `sample.minimum_size` | [Operator] | Phase 0 | Positive minimum sample size or approved population coverage floor. |
| `sample.seed` | [Orchestrator] | Phase 0 | Fixed seed or reproducible seed source. |
| `sample.rationale` | [Operator] | Phase 0 | Why the sample size and rule provide adequate coverage. |
| `sample.approver` | [Operator] | Phase 0 | Approval identity and role. |
| `sample.approved_at` | [Orchestrator] | Phase 0 | Approval timestamp and evidence reference. |
| `thresholds.*.value` | [Operator] | Phase 0 | Numeric value and unit for every reconciliation, risk, materiality, and cumulative VAT limit, and for every cutover stop threshold and rollback trigger that Phase 16 checks. |
| `thresholds.*.approver` | [Operator] | Phase 0 | Approval identity and role for each threshold. |
| `thresholds.*.approved_at` | [Orchestrator] | Phase 0 | Approval timestamp and evidence reference. |
| `thresholds.*.rationale` | [Operator] | Phase 0 | Source-linked reason for each value. |
| `thresholds.*.evidence_path` | [Orchestrator] | Phase 0 | Controlled evidence supporting the value and approval. |
| `isolation.decision` | [Operator] | Phase 0 | Isolated writer identity or approved guard-only exception. |
| `isolation.rationale` | [Operator] | Phase 0 | Reason and residual risk accepted if isolation is unavailable. |
| `isolation.owner` | [Orchestrator] | Phase 0 | Owner responsible for the control. |
| `isolation.evidence_path` | [Orchestrator] | Phase 0 | Evidence for the selected boundary. |
| `isolation.review_date` | [Operator] | Phase 0, current again at Phase 18 entry | Current review date. An absent or expired review blocks Phase 18. |
| `auditfile.route` | [Operator] | Phase 0 for the UI route, first guarded export POST for the pinned route | Phase 0 Operator UI export route, requested product and XAF versions, year, and artifact evidence. Record the pinned guarded POST route at its first use after a phase gate passes. |
| `auditfile.approval_reference` | [Operator] | Phase 0 | Human approval for the exact year and version before each UI export or guarded export POST. |
| `auditfile.receipt_hash` | [Evidence Archivist] | Phase 0 | Receipt and SHA-256 for the exported artifact. |
| `bulk_read.route` | [Independent Auditor] | Phase 0 | Verified synchronization route or complete paginated fallback. |
| `bulk_read.completeness_evidence` | [Independent Auditor] | Phase 0 | Timestamp, page counts, completion counts, and independent verification of the approved cache-wait rule. |
| `bulk_read.cache_horizon` | [Operator] | Phase 0 | Operator-approved value and unit, applicable route, source basis, approval identity and time, and evidence path. Missing or unapproved values block wait-based retries. |
| `retention.rules[]` | [Operator] | Phase 2 | For every class, record source-supported basis, duration, start event, derived end date, independent archive, owner, approver, approval, and readability. Apply seven years to basic administration and ten years to immovable-property and OSS records where those source facts apply. Record any longer contract-survival term as an Operator-approved value with its basis. |
| `auditfile.session_boundary` | [Orchestrator] | First guarded export POST, Phase 10 at the earliest | For a guarded POST, dedicated writer session reference, start and close evidence, and separate locked read-back session. Mark pending until the first gated POST. |
| `auditfile.job_status` | [Evidence Archivist] | Phase 0 | Completed Moneybird export job, product version, XAF version, year, receipt, and artifact SHA-256. |
| `write_approval_reference` | [Operator] | Phase 7 | Approval for each non-GET batch, linked from the journal. |
| `run_journal_path` | [Orchestrator] | Phase 0 | Controlled JSONL journal location. |
| `agents.implementer.route` | [Operator] | Phase 0 | DeepSeek V4.1 Flash at max thinking through the Pi CLI with the llmgateway provider. Disable tools, extensions, skills, context files, and sessions. |
| `agents.implementer.fallback_route` | [Operator] | Phase 0 | One fallback provider for the same configured model. Record the route and use it only after a provider failure. |
| `agents.verifier.route` | [Operator] | Phase 0 | GPT-6 Luna at max effort on the fast service tier through the Codex CLI. Require a read-only sandbox and proven OS boundary. |
| `agents.final_reviewer` | [Operator] | Phase 0 | Claude in the skill-running session for final phase review. |
| `agents.data_policy` | [Operator] | Phase 0 | SUMMARIES_ONLY. No names, amounts, IBANs, addresses, emails, descriptions, invoice numbers, document or administration IDs, or source payloads leave the machine. Agent-facing counts from 1 to 9 show as <10. |
| `agents.write_executor` | [Operator] | Phase 0 | CONDUCTOR. Claude uses a separate Migration Writer session after Verifier PASS and Operator approval. The local payload assembler builds every payload, and the writer receives only aliases, payload hashes, counts, and the approval reference. The guard loads the token locally and no seat sees it. |
| `agents.max_rounds` | [Operator] | Phase 0 | Positive round limit. Default 3. |
| `agents.read_boundary_evidence` | [Operator] | Phase 0 | Operating-system deny results for every protected path, outbound egress canary, phase-entry canary evidence, and evidence for any path change. |
| `agents.script_sandbox_evidence` | [Operator] | Phase 0 | Local script sandbox profile, fixture review, own-input-folder read boundary, output path outside AgentDesk, and blocked network evidence. |
| `agents.alias_secret_location` | [Operator] | Phase 0 | Local path to the HMAC-SHA256 key only, by default migration-workspace/.secrets/alias-hmac.key with 32 random bytes and file mode 600. The Operator creates it, owns it, and rotates it when a new phase or cycle starts. Never record or share the key value. |

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
2. [Operator] Records the configured start date and any start-year evidence already available. Phase 2 completes the start-year basis and opening position.
3. [Orchestrator] Runs `bash sk-moneybird-accountant/scripts/init-workspace.sh` from the repository root. It creates the workspace folders, the versioned `MIGRATION_CONFIG` from its template and the phase dashboard under `Plans/`, copies the 23 phase packets to the git-ignored `specs/001-migration/`, and never overwrites an existing file.
4. [Operator] Records the trial or package state, observed expiry, evidence source, renewal owner, and expiry alert evidence.
5. [Operator] Proposes and approves numeric thresholds, sample sizes, the sample rule, the minimum pre-cutover parallel comparison cycles, the monitoring period, and the minimum monthly, VAT-period, and yearly cycle counts, each with rationale. Fixing the cycle counts now keeps the monitoring target from moving once live results exist.
6. [Operator] Decides whether writer isolation is available, records the decision, and sets a review date.
7. [Operator + AI] Verifies the local guard stub suite and the read-only negative test. A non-GET under the read-only lock must exit with code 6 before a real call. Real call count is zero.
8. [Operator] Performs an approved auditfile test export through the Moneybird UI. Record the exact year and version, job completion, receipt, and artifact SHA-256. [Independent Auditor] verifies the artifact and complete Moneybird bulk-read route. Defer the guarded report-export POST until a phase gate has passed.
9. [Operator] Records provider evidence that the Jortt identity has read-only scopes. [Operator + AI] Run the local no-write check and capture the documented block before any real Jortt call.
10. [Independent Auditor] Verifies every phase contract once before Phase 0 passes. Confirm phases 0 through 22 each have one heading, all 11 fields, and a numeric exit gate.
11. [Orchestrator] Records the config hash, workspace index, owners, and first journal checkpoint.

Do not write historical records in Phase 0. Do not create a second pilot administration. Never run the auditfile POST before a phase gate passes or in a reader session. Read the selected phase contract only after setup evidence is recorded.
