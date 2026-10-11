---
title: Migration shared mechanisms and route contract
description: Shared controls used by every migration phase, with tool and export routes.
trigger_phrases:
  - migration write key and run journal
  - migration access expiry and stop recovery
  - Jortt and Moneybird migration route
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration shared mechanisms

These controls are defined once and referenced by the phase contracts. They describe required behavior and do not claim that a tool already implements each control. Load the [migration index](./README.md) to route a request to its phase.

## M1. Register schemas and complete source manifests

Store versioned register schemas under `migration-workspace/Schemas/`. Each schema records its name, version, and SHA-256 of canonical UTF-8 schema bytes with stable key ordering. Each export manifest records source, scope, period, timestamp, page size and count, record count, byte count, SHA-256, exclusions, and independent source control totals.

The Evidence Archivist captures an independent UI or portal count outside the exported artifact for every export. The Independent Auditor reproduces the count and compares full page and record counts with the manifest. A count derived from the same artifact is not independent. If the source has no independent control, stop acceptance until the Operator supplies a reproducible source-side count and its derivation. Recompute checksums after transfer and restore. A manifest proves file integrity and declared scope, not source completeness by itself.

## M2. Stable local write keys and uncertain outcomes

Build each duplicate key from source system, source administration alias, object type, source object ID, and target administration alias. Store the mapping schema version beside the key. Do not include that version in the key. Store the key, schema version, source-manifest hash, source reference, planned payload hash, planned payload fields, target match rule, attempt state, and returned target ID under `migration-workspace/WriteJournal/`. During Phase 6, define a supported target reference field or a deterministic fingerprint from confirmed target fields, plus the complete read route and period scope used to find it. If uniqueness or complete retrieval cannot be proven, stop before writing.

Before every non-GET call, recompute all approved batch input and mapping hashes immediately before writing. Abort and journal a drift stop if any hash differs. Then append a durable `WRITE_INTENT` event with the key and payload hash, flush it to disk, and issue the call. Repeat the hash check after a pause or session restart. Do not assume Moneybird provides server-side idempotency or unique-key enforcement. After an uncertain write, use the recorded target match rule over a complete synchronized or paginated target population. Adopt a target ID only when the source reference and every planned payload field defined for the object type match exactly. A missing field definition, zero matches, multiple matches, or unequal field stops the batch.

Make wait-based retry decisions only after a read-back waits beyond the Operator-approved `bulk_read.cache_horizon` recorded in `MIGRATION_CONFIG` with its route, source basis, approval identity, and evidence path, and independently verified by the Independent Auditor. A missing or unapproved horizon blocks any wait-based retry. A complete timestamped synchronization read remains an allowed retry check. Never blindly retry an uncertain write.

## M3. Append-only run journal, approvals, and crash resume

Keep one append-only JSONL run journal under `migration-workspace/RunJournal/`, with one event per state change. Required states are `PLANNED`, `INPUT_FROZEN`, `ACCESS_CHECK_RECORDED`, `WRITE_INTENT`, `IN_PROGRESS`, `WRITE_UNKNOWN`, `WRITE_CONFIRMED`, `READBACK_CONFIRMED`, `RECONCILED`, `GATE_PASSED`, and `STOPPED`.

Every non-GET call has a flushed `WRITE_INTENT` immediately before the call. Each event records phase, batch or checkpoint key, input-manifest hash, item counts, prior state, new state, timestamp, owner tag, evidence paths, approval reference, payload hash when applicable, and stop reason when present. Each material human approval records identity, role, decision, timestamp, evidence references, and accepted exceptions.

Never rewrite journal history. Resume only from the last verified state. Reconcile every `WRITE_UNKNOWN` item before another write.

## M4. Evidence, privacy, and session boundary

Keep finance artifacts under the ignored `migration-workspace/`. Preserve existing folders and add `Schemas/`, `Manifests/`, `Registers/`, `Inputs/<role>/`, `Mappings/`, `Exceptions/`, `Reports/`, `Snapshots/`, `WriteJournal/`, `RunJournal/`, `Archive/`, `Reviews/`, and `Handoff/`. Link each run-journal event to its checkpoint artifacts.

Agents may read record-level fields inside their assigned controlled input folders to prepare their registers. Prompts, tool logs, and session transcripts may contain only schemas, field names, phase and record-class labels, opaque record keys, aggregate counts, status, and evidence paths. Do not put source payloads, personal names, supplier or customer details, account identifiers, invoice numbers, or amounts in those surfaces. Before sharing output, the Independent Auditor scans it against this allowlist and records the count of prohibited private fields. Keep record-level evidence in the controlled workspace. The recorded prohibited-field count must equal zero.

## M5. Moneybird rate limits and recovery

The documented shared-IP limits are 150 requests per five minutes overall and 50 report requests per five minutes. The official CLI has no automatic 429 retry. Use one request ledger for every worker sharing an IP, serialize or pace calls within both limits, and record response status and `Retry-After`.

On 429, stop the affected call sequence and wait the stated interval. The Orchestrator may authorize one paced reissue for a read. For a non-GET call, first reconcile the outcome by guarded read-back and issue a new approved intent only when the target proves the write did not occur. If `Retry-After` is absent or the reissue returns 429, stop for Operator decision. Record the wait, authorization, read-back, new intent, and result in the shared request ledger. Do not raise concurrency to catch up.

## M6. Access window through writes and verification

`MIGRATION_CONFIG` records the observed trial or package state, expiry date, evidence source, observation date, renewal owner, and alert evidence. Before each Moneybird non-GET batch, the Operator reconfirms the state and date against expected batch completion, synchronization, read-back, and verification. A missing, expired, or uncertain access window blocks the batch.

By the Phase 17 gate, require an active paid package that covers the next live VAT period and year close, with a named renewal owner and alert evidence. Recheck the access window before Phase 22 verification. Confirm archive coverage and export before any lapse or decommission decision.

## M7. Exception and threshold control

Every exception has a stable exception key, phase, source and target references, owner, backup owner when applicable, reviewer, due date, escalation deadline, status, evidence path, resolution, acceptance authority, expiry or reopen date, and corrective-entry link. Thresholds are numeric and approved in `MIGRATION_CONFIG`.

Missing threshold values, cross-period netting, unapproved residual differences, incomplete exception fields, and expired accepted exceptions block the gate. The default for exact copied data is zero unexplained differences. Corrections to committed records use an approved, linked, append-only reversal or credit and a replacement where supported. Do not edit or delete committed history in place. The Operator or adviser approves the correction type, and every changed target is read back and reconciled.

## M8. Jortt pagination and source request evidence

Jortt list reads use the documented `--all` behavior, which follows next links and merges pages. Record page size, page count, expected total when supplied, item count per page, request status, rate-limit events, and the completed next-link chain in the manifest. The documented page limit is 100 items and request limit is 10 per second. The current CLI throttles each request by 0.11 seconds and retries HTTP 429 at most three times, honoring `Retry-After` or using exponential delay. Bind these implementation facts to the recorded tool revision and verify again if that revision changes. Issue one CLI invocation per logical extraction and do not start a second invocation while CLI-managed 429 recovery is active. Record the operation, tool revision, invocation time, final status, and retry metadata when exposed. If the CLI does not expose internal attempt counts, record that they are not reported and do not claim attempt-level evidence.

A missing next link, unexplained page cap, incomplete chain, or count mismatch blocks Phase 1 and every dependent export.

## M9. Master phase dashboard

Maintain one dashboard row for each phase from 0 through 22. Each row records phase ID, status, phase-contract check status and evidence, named owner, evidence link, due date, exception count, and last verified resume checkpoint. Before Phase 0 passes, the Independent Auditor verifies exactly one phase heading per phase and all 11 contract fields plus a numeric exit gate for every phase. Record 23 of 23 checks with evidence. Update rows on every gate, stop, resume, and recurring cadence. Reconcile dashboard rows to the run journal and phase contracts. Phase 22 requires all 23 rows current with no missing evidence or checkpoint.

## M10. Write-isolation decision

The default is an isolated writer identity and session behind `moneybird-guard`, with reader and writer profiles kept separate. Every reader session sets `MONEYBIRD_GUARD_READ_ONLY=1`. A writer session is opened only for an approved batch, has that read-only variable absent, and is closed after its approved non-GET calls. Never reuse a writer session for reads. Start read-back in a separate reader session with the lock set. Record each session profile and the observed lock state in the journal. Guard-only isolation is allowed only when the Operator records why separate writer isolation is unavailable and accepts the residual risk.

Never place tokens in arguments, prompts, logs, or tracked files. Record the isolation decision, rationale, owner, evidence, and review date in `MIGRATION_CONFIG`. Review it before Phase 18. An absent or expired review blocks cutover.

## M11. Stop-state recovery matrix

Record one recovery row for every stop event, including its owner, evidence, retry rule, and closure test. Unknown writes require guarded read-back before retry, 429 recovery requires a recorded wait and Orchestrator authorization, and validation failures require correction and reapproval. No batch resumes until its closure condition passes.

| Stop state | Owner | Required evidence | Retry rule | Closure condition |
|---|---|---|---|---|
| `WRITE_UNKNOWN` | Migration Writer | Flushed intent, request status, source reference, planned fields, target read-back | No retry until the documented cache wait or a complete timestamped synchronization read. Ambiguity stops the batch. | Adopt an exact source-reference and planned-field match, or evidence an approved safe retry with no duplicate. |
| `HTTP_429` | Orchestrator | Shared request ledger, response status, `Retry-After`, affected batch | Wait the documented interval. Authorize one read reissue, or require guarded read-back and a new approved intent before a write reissue. | Required request completes and the ledger records wait, authorization, read-back when needed, intent, and status. |
| `VALIDATION_FAILURE` | Mapping Agent | CLI validation result, mapping version, planned payload | Do not retry the same payload. Correct the mapping, reapprove, rehash, and issue a new intent. | Corrected payload passes validation and its approval and hash are recorded. |
| `MISSING_SOURCE_OR_HASH_MISMATCH` | Evidence Archivist | Source manifest, page chain, source total, file hash | Do not perform dependent writes. Re-extract or restore the affected class and create a new manifest version. | Required source coverage and independent totals reconcile to 100%. |
| `STALE_OR_INCOMPLETE_READ` | Independent Auditor | Synchronization timestamp, page counts, cache wait, expected total | Do not use zero-match results for retry or pass decisions. Repeat only after the documented wait or complete synchronization. | Freshness and completeness are evidenced and counts reconcile. |
| `RECONCILIATION_MISMATCH` | Reconciliation Agent | Source and target reports, linked exception, correction evidence | Do not net across periods or accounts. Correct only through the approved append-only correction path. | Difference is zero or a complete, approved exception is within configured limits. |

## Route contract

### Jortt reads and exports

Use [jortt-cli](../../../cli-jortt/SKILL.md) with read scopes only. List extraction uses `--all` and records the next-link chain, page counts, item counts, final response status, and independent source-side total. The CLI owns its documented 429 wait and bounded retry behavior. A missing or failed result stops the extraction. XAF, annual accounts, and filed-return exports are Operator UI work. The tool route does not provide a general-ledger API or UI export. A VAT summary is not a filed return.

### Moneybird reads and writes

Use [moneybird-guard](../../../cli-moneybird/SKILL.md) with `MONEYBIRD_GUARD_READ_ONLY=1`, explicit periods, and synchronization for complete bulk reads. Record synchronization timestamps and completion counts. If synchronization is unavailable, wait beyond the Operator-approved and Independent Auditor verified cache horizon in `MIGRATION_CONFIG`, then use a complete paginated read with page counts before retry decisions. Missing or unapproved horizon blocks a wait-based retry. Token scopes do not create a read-only token.

Moneybird non-GET calls use `moneybird-guard` only after the phase gate and Operator approval, with `--confirm-write`. A flushed `WRITE_INTENT` must precede each call. Phase 7, 8, and 16 mirror batches use the single pilot and mirror administration and do not use `--production`. Phase 18 final-delta writes remain mirror batches until the Operator approves go-live. Phases 19 to 21 are production batches after Phase 18 passes and use `--production` only with the Operator's approval for that batch. Verify writes by a later synchronized read or after the configured cache wait.

### Auditfile export and Operator UI actions

Phase 0 tests the auditfile through an Operator-approved Moneybird UI export and verifies its artifact. The guarded report-export POST is first used only after a phase gate passes. For each POST, the Operator approves the exact year and version, and the Migration Writer flushes an operation-scoped `WRITE_INTENT` with the requested operation and payload hash before using `--confirm-write` in a separate writer session. The writer records approval and session boundaries, then closes the session. The Independent Auditor confirms job completion and verifies the downloaded artifact receipt and SHA-256 in a separate session with `MONEYBIRD_GUARD_READ_ONLY=1`. Never clear the lock in a reader session or treat an export approval as general write access.

CAMT.053 and MT940 imports, tax-rate creation, period locking, manual historical VAT status, and Jortt UI exports remain Operator UI actions. Every Operator UI action that changes ledger or tax settings has a prior approval record, an action receipt, and a guarded read-back where available, linked from M3.
