---
title: Migration control framework
description: Agent roles, risk and verification rules, exception controls, stop recovery, dashboard, and completion.
nav_label: "Migration control framework"
trigger_phrases:
  - moneybird migration control
  - migration exception and stop recovery
  - migration phase dashboard
  - Jortt historical bookkeeping
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration control framework

Use this reference with the [migration index](./README.md), the selected phase contract, and [shared mechanisms](./shared-mechanisms.md). The phase contract sets its own gate. This file defines controls that apply across phases.

## Phase contract schema

Every phase from 0 through 22 uses these 11 fields in this order. Each nested sub-goal has a check that names a count, percentage, date, equality, or artifact result that a verifier can reproduce. Before Phase 0 passes, the Independent Auditor records exactly one phase heading and all 11 fields plus a numeric exit gate for each phase. The check covers all 23 phases and is linked from the master dashboard.

| # | Field | Required content |
|---:|---|---|
| 1 | Goal | The phase outcome. |
| 2 | Nested sub-goals | One or more measurable outcomes under the goal, each with its own check. |
| 3 | Entry criteria | Prior gate, approvals, date or scope facts, and a zero-blocker condition. |
| 4 | Inputs | Named source records, registers, configuration, or prior evidence. |
| 5 | Owner-tagged actions | Exact owner tags for actions and the gate verifier. Human decisions stay with the Operator. |
| 6 | Tool route | Named CLI or UI route with read, write, approval, and privacy boundary. |
| 7 | Outputs and evidence artifacts | Exact artifact class and location under `migration-workspace/`. |
| 8 | Numeric exit gate | Reproducible count, percentage, date, equality, or explicit zero. Numeric thresholds come from approved `MIGRATION_CONFIG` values. |
| 9 | Stop conditions | A falsifiable event that blocks the phase or affected batch. |
| 10 | Rollback or compensation | Reversal, correction, preservation, or safe no-op rule. |
| 11 | Resume rule | Journal state and evidence required to continue after a stop or crash. |

## Agent structure

| Owner | Seat | Reads | Writes | Moneybird route |
|---|---|---|---|---|
| [Operator] | Operator | Source system, portals, approvals, reports, and local record evidence for AMBER or high-risk items | Human decisions, UI exports and imports, filing and lock actions | Operator UI or approved guarded route |
| [Orchestrator] | Agent runner, local and deterministic | Phase contracts, configuration, filtered summaries, and gate status | MIGRATION_CONFIG, briefs, AgentDesk artifacts, journal, and dashboard rows | None |
| [Agent runner] | Agent runner, local and deterministic | Assigned input folders only for local role sessions, plus approved schemas and phase inputs | Local role artifacts, sandbox outputs, assembled write payloads with their HMAC hashes, filtered summaries, logs, journal, and dashboard rows | Runs local reader sessions with the required read-only lock. It does not book records. |
| [Evidence Archivist] | Implementer drafts, Agent runner executes local role session | Assigned archive input folder through its local role session | Manifests, registry, archive, and restore evidence | None |
| [Document Agent] | Implementer drafts, Agent runner executes local role session | Inputs/document/ through its local role session | DOCUMENT_REGISTER | None |
| [Ledger Agent] | Implementer drafts, Agent runner executes local role session | Inputs/ledger/ through its local role session | LEDGER_REGISTER | None |
| [Bank Agent] | Implementer drafts, Agent runner executes local role session | Inputs/bank/ through its local role session | BANK_REGISTER | None |
| [Tax Filing Agent] | Implementer drafts, Agent runner executes local role session | Inputs/tax/ through its local role session | TAX_REGISTER | None |
| [VAT Agent] | Implementer drafts, Agent runner executes local role session | Inputs/vat/ with original invoices only through its local role session | VAT_CLASSIFICATION_REGISTER | None |
| [Reconciliation Agent] | Implementer drafts, Agent runner executes local role session | Approved local registers | CANONICAL_DATASET and reconciliation reports | None |
| [Mapping Agent] | Implementer drafts, Agent runner executes local role session | Approved local canonical data and supported target fields | Mapping tables and validation reports | Guarded reads stay in the local runner session with MONEYBIRD_GUARD_READ_ONLY=1 |
| [Migration Writer] | Separate writer session using the configured write-executor seat | Batch and record aliases, payload hashes, counts, and the approval reference. Never payload content. | Target records and write journal | Isolated writer through moneybird-guard with `--confirm-write --approval <ref>` against the locally assembled payload file |
| [Independent Auditor] | Verifier designs and judges, Agent runner executes locally | Schemas, independent fixtures, filtered summaries, and local check results | Independent audit verdicts and filtered findings | No direct record-level read. The Agent runner executes local checks. |
| [Red Team] | Verifier in a separate session | Clean working copy of agent-facing inputs without verdicts, final reviews, or earlier findings | Challenge and sample verdicts | No direct record-level read. The Agent runner executes local checks. |
| [Final reviewer] | Final reviewer seat | Alias-level phase evidence, filtered summaries, verdicts, and gate results. No record-level content. | Final review record and one decision summary for the Operator | None |
| [Operator + AI] | Operator with the named seat | Approved task inputs | Prepared evidence and human approval record | Human action remains with Operator |

The Orchestrator manages phase checkpoints and prepares a gate decision. It does not book records. The Migration Writer is the only agent role that may issue an approved Moneybird write. Keep independent analysis roles in separate sessions and folders. The Operator owns credentials, UI exports, bank-file imports, tax-rate creation, return filing, period locks, account lifecycle choices, and production go or no-go. M12 defines the external seats and their data boundary. No seat receives record-level content, and the local payload assembler builds every write payload.

## Verification loop per record

Risk determines the amount of review. Every written record follows the same evidence path.

1. [Implementer] drafts each role's schema, script, mapping table, or report template from allowlisted summaries. [Agent runner] executes one local role session per assigned input folder and keeps record-level work local.
2. [Implementer] drafts the reconciliation logic. [Agent runner] runs the local Reconciliation Agent session to link approved registers and create the canonical record.
3. [Implementer] drafts the deterministic risk rules and the batch pre-write report template. [Agent runner] applies the rules and builds the pre-write report locally. [Verifier] independently checks the rules, their application counts, and the batch pre-write report. [Operator] reviews AMBER and high-risk records locally.
4. [Operator] approves the batch and all required access checks.
5. [Migration Writer] issues a write only after a flushed WRITE_INTENT and records the response under M2, M3, and M10.
6. [Verifier] designs an independent record-level check with its own fixtures. [Agent runner] executes the check locally against every target record, through a later synchronized read or a complete read after the documented cache wait, and returns only a filtered summary.
7. [Verifier, Red Team session] challenges each historical period and year from a clean working copy. The named phase contract may require broader coverage.
8. [Agent runner] records target read-back and reconciliation. [Final reviewer] confirms the verified phase evidence. Mark a record `VERIFIED` only after read-back and reconciliation pass.

AMBER and high-risk records receive an individual Verifier record-level check and local Operator review before they count as verified. RED and BLACK records are never written. An uncertain result is handled under M2, M3, and M11. Never replay a write from a missing or ambiguous read.

## Risk model

| Class | Meaning | Write rule |
|---|---|---|
| GREEN | Multiple independent sources support the same conclusion. | Allowed after the phase gate and approved batch review. |
| AMBER | Likely correct, with a missing secondary source or a documented difference. | Individual review and an approved exception or evidence note are required. |
| RED | Primary sources contradict one another. | Never write until the contradiction is resolved and the record is reclassified. |
| BLACK | Evidence is insufficient to support a conclusion. | Never write. Obtain evidence or stop the record. |

Risk assignment rules and any count or monetary threshold are numeric, recorded in `MIGRATION_CONFIG`, and approved by the Operator with rationale and evidence. Missing threshold values or an unapproved assignment rule block the gate.

## High-risk transactions

Require an extra review for:

- EU or non-EU reverse charge and foreign VAT.
- A new international supplier or a change in supplier legal entity.
- Assets, historic value changes, and depreciation.
- Private versus business use.
- General journal documents.
- Opening balances and year-end closing balances.
- Historical tax differences, credit notes, and unusual currencies.
- Invoice-level open receivables or payables and their settlement links.
- Any write with an uncertain response, a changed schema, or a correction after a period lock.

## Exception ledger and thresholds

Every exception remains visible under a stable key. Preserve the following M7 fields for every row:

| Required field | Meaning |
|---|---|
| Stable exception key | Immutable identifier used by reports and journal events. |
| Phase | Phase where the issue was found and any dependent gate. |
| Source and target references | Opaque keys or evidence links that let an auditor reproduce the issue. |
| Owner | Named role accountable for the next action. |
| Backup owner | Named alternate when the primary owner is unavailable or the due date requires coverage. |
| Reviewer | Independent person or role checking resolution or acceptance. |
| Due date | Date for the next action. |
| Escalation deadline | Date to escalate an unresolved item. |
| Status | Current controlled status from the list below. |
| Evidence path | Controlled workspace location for supporting evidence. |
| Resolution | Action taken and reproducible result, or why it remains open. |
| Acceptance authority | Human role and decision record for any accepted residual. |
| Expiry or reopen date | Date when accepted status must be reviewed again. |
| Corrective-entry link | Linked reversal, replacement, or correction entry when one exists. |

Use these statuses: `OPEN`, `INVESTIGATING`, `RESOLVED`, `ACCEPTED HISTORICAL DIFFERENCE`, `TAX REVIEW REQUIRED`, `SOURCE MISSING`, and `EXPIRED`. An expired accepted item returns to active review and blocks dependent gates. Do not delete exceptions or net differences across periods.

Each threshold row in `MIGRATION_CONFIG` carries a numeric value, unit, affected check, approval identity and role, approval timestamp, rationale, and evidence reference. The historical plan's proposed figures remain proposals until the Operator approves them. Exact copied data defaults to zero unexplained difference. No threshold authorizes a balancing entry.

| Check | Configured threshold |
|---|---|
| Bank balance per account at period end | Numeric amount, normally zero unexplained difference. |
| VAT per return box and cumulative period caps | Numeric amount per box, plus numeric quarter and year caps. |
| Revenue and costs by main group per year | Numeric amount for explained residuals. |
| Profit compared with annual accounts and filed income-tax evidence | Zero unexplained difference, with every accepted difference documented. |
| Balance-sheet line by year | Zero unexplained difference, with any approved threshold explicit. |
| Original-document coverage | Numeric required coverage by risk or amount band. |
| Missing original document | Always an exception. Never ignore it. |

## Stop conditions and recovery

Stop the affected batch and block dependent phases on any of these events:

- Duplicate fingerprint or conflicting source and target identity.
- An invoice field or total differs from the approved plan.
- Unexplained currency, bank, VAT, opening-balance, annual-account, or ledger difference.
- Uncertain supplier, tax treatment, VAT treatment, or record risk.
- RED or BLACK risk classification.
- Missing original evidence, attachment hash mismatch, or incomplete source page chain.
- Unexpected depreciation or unsupported opening item.
- A 429 without the required wait and request-ledger evidence.
- A write response that does not match the planned record.
- Missing, expired, or uncertain access window before a write batch.
- An incomplete M7 exception, missing approval, or expired accepted exception.

Use this stop-state recovery table. Record one recovery row for every stop event, then follow the full field definitions in [M11](./shared-mechanisms.md#m11-stop-state-recovery-matrix).

| Stop state | Owner | Recovery evidence | Retry rule | Closure test |
|---|---|---|---|---|
| `WRITE_UNKNOWN` | Migration Writer | Flushed intent, request status, source reference, planned fields, target read-back | Wait beyond the Operator-approved and Independent Auditor verified `bulk_read.cache_horizon`, or use complete timestamped synchronization. Missing or unapproved horizon blocks wait-based retry. No retry while ambiguous. | Exact source-reference and planned-field match is adopted, or an approved safe retry has no duplicate. |
| `HTTP_429` | Orchestrator | Shared request ledger, response status, `Retry-After`, affected batch | Wait the stated interval. The Orchestrator may authorize one paced read reissue. For a write, require guarded read-back and a new approved intent proving the target is absent. | The ledger records wait, authorization, read-back when needed, intent, and result. |
| `VALIDATION_FAILURE` | Mapping Agent | Validation result, mapping version, planned payload | Correct, approve, rehash, and issue a new intent. Do not retry the same payload. | Corrected payload passes validation and approval evidence is linked. |
| `MISSING_SOURCE_OR_HASH_MISMATCH` | Evidence Archivist | Manifest, page chain, source total, file hash | No dependent write. Re-extract or restore the affected class under a new manifest version. | Required coverage and independent totals reconcile to 100%. |
| `STALE_OR_INCOMPLETE_READ` | Independent Auditor | Sync timestamp, page counts, cache wait, expected total | Repeat only after the documented wait or complete synchronization. | Freshness and completeness are evidenced and counts reconcile. |
| `RECONCILIATION_MISMATCH` | Reconciliation Agent | Source and target reports, exception, correction evidence | No cross-period netting. Use the approved append-only correction path. | Difference is zero or a complete approved exception is within configured limits. |
| `PRECALL_REFUSAL` | Orchestrator | Guard or CLI exit code, refusal text, named precondition, attempted route, run-journal stop entry | Fix the named precondition before a new call. Never reissue the same call unchanged. | The corrected call passes the gate and the precondition fix is recorded with its evidence. |
| `POSTCONDITION_ABSENT` | Migration Writer | Write log, flushed intent, response status, synchronized read-back, target match rule | Do not reissue. Confirm with a synchronized read that the write record is absent or that a 204 delete left the record present. A retry needs a new approved intent. | The synchronized read settles the write or delete outcome. A reissue carries a new approved intent and the write log links the result. |

Never invent a closing entry to make a difference disappear. Compensation uses the approved append-only reversal or credit and replacement where supported, followed by independent read-back and reconciliation. Resume from the last verified journal state, not from the last attempted action.

## Master dashboard

Keep one row per phase. Every row carries phase ID, status, phase-contract check status and evidence, named owner, evidence link, due date, exception count, and last verified resume checkpoint. Update the dashboard for every gate, stop, resume, and recurring cycle. Reconcile it with the run journal.

Allowed dashboard statuses are:

- `NOT_STARTED`: no work event is recorded for this phase.
- `IN_PROGRESS`: the phase has started and no stop is active.
- `STOPPED`: a stop event is active and its closure test has not passed.
- `GATE_PASSED`: all exit criteria passed and evidence is linked.
- `REOPENED`: changed evidence invalidated a prior pass and the affected checks must run again.

| Phase | Gate | Status | Contract check |
|---:|---|---|---|
| 0 | Safety and system setup | `NOT_STARTED`  | `NOT_RUN` |
| 1 | Full source inventory | `NOT_STARTED`  | `NOT_RUN` |
| 2 | Collect missing sources and seed archive | `NOT_STARTED`  | `NOT_RUN` |
| 3 | Reconstruct each source independently | `NOT_STARTED`  | `NOT_RUN` |
| 4 | Cross-reconciliation | `NOT_STARTED`  | `NOT_RUN` |
| 5 | Completeness and anomaly scan | `NOT_STARTED`  | `NOT_RUN` |
| 6 | Design the Moneybird mapping | `NOT_STARTED`  | `NOT_RUN` |
| 7 | Pilot migration | `NOT_STARTED`  | `NOT_RUN` |
| 8 | Historical migration per period | `NOT_STARTED`  | `NOT_RUN` |
| 9 | VAT verification loop | `NOT_STARTED`  | `NOT_RUN` |
| 10 | Year-end check | `NOT_STARTED`  | `NOT_RUN` |
| 11 | Income-tax cross-verification | `NOT_STARTED`  | `NOT_RUN` |
| 12 | Continuity between years | `NOT_STARTED`  | `NOT_RUN` |
| 13 | Year Red Team | `NOT_STARTED`  | `NOT_RUN` |
| 14 | Year lock | `NOT_STARTED`  | `NOT_RUN` |
| 15 | Repeat from oldest to newest year | `NOT_STARTED`  | `NOT_RUN` |
| 16 | Current-year parallel mirror and cutover preparation | `NOT_STARTED`  | `NOT_RUN` |
| 17 | Source freeze and archive readiness | `NOT_STARTED`  | `NOT_RUN` |
| 18 | Switch to live bookkeeping | `NOT_STARTED`  | `NOT_RUN` |
| 19 | Live monthly workflow | `NOT_STARTED`  | `NOT_RUN` |
| 20 | Live VAT-period workflow | `NOT_STARTED`  | `NOT_RUN` |
| 21 | Live yearly workflow | `NOT_STARTED`  | `NOT_RUN` |
| 22 | Migration completion and Jortt decommission | `NOT_STARTED`  | `NOT_RUN` |

Phases 19 to 21 are recurring loops that begin after Phase 18. Phase 22 is a one-time gate. It requires all 23 rows to be current and complete for their applicable status, with every phase-contract check marked PASS and no missing owners, evidence, due dates, exception counts, or resume checkpoints.

Keep the historical per-year summary as a companion to the phase dashboard. It does not replace the 23 phase rows.

| Year | Documents | Ledger | Bank | VAT | Income tax | Balance | Exceptions | Status |
|---|---|---|---|---|---|---|---|---|
| Derived year from configured start and lock ledger | Evidence link or count | Evidence link or count | Evidence link or count | Evidence link or count | Evidence link or count | Evidence link or count | Exception count | One allowed dashboard status |


## Concrete first runs

1. Run Phase 0 and Phase 1 only. Produce an initial inventory report with business years found, archive class counts, source-system availability, bank and tax evidence availability, missing-source tasks, duplicate candidates, proposed start-year basis, and proposed pilot period. Make no Moneybird write.
2. After missing sources are collected, run Phases 2 to 6 and produce the migration blueprint.
3. Run Phase 7 as the pilot in the same empty Moneybird administration used as the mirror.
4. Run one approved historical period at a time through Phases 8 and 9. Continue only when both gates pass.
5. After a complete year, run Phases 10 to 14. Continue oldest to newest through Phase 15 without skipping a year.
6. Run Phase 16 for current-year parallel work and cutover preparation. Derive the next historical year from the configured start date and last locked year. Do not store a hard-coded current year.
7. Run Phase 17 for source freeze and archive readiness, then Phase 18 for the live switch.
8. After Phase 18 passes, run Phases 19 to 21 on their configured monthly, VAT-period, and yearly schedules.
9. Run Phase 22 once, after the first live VAT reconciliation, the monitoring end date, and every recurring cycle through that date have passed.

## Definition of done

The migration is complete only after Phase 22 passes. The gate requires Phase 18 and the first live VAT period under Phase 20 to pass, the configured monitoring period to end, all recurring cycles through that date to pass, final archive delta and class restores to reconcile, retention evidence to be current, all required reconciliations and filed-return bridges to be complete, unexplained differences to equal zero, accepted exceptions to be complete and current, historical years to be locked, cutover approval to be recorded, and live ownership to be assigned. The Operator then records whether Jortt will be kept or cancelled. No agent cancels it.
