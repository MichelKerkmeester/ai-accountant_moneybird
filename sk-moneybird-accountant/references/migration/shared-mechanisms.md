---
title: Migration shared mechanisms and route contract
description: Shared controls used by every migration phase, with tool and export routes.
nav_label: "Migration shared mechanisms and route contract"
trigger_phrases:
  - migration write key and run journal
  - migration access expiry and stop recovery
  - Jortt and Moneybird migration route
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration shared mechanisms

These controls are defined once and referenced by the phase contracts. They describe required behavior and do not claim that a tool already implements each control. Load the [migration index](./README.md) to route a request to its phase. M12 defines the external agent route used with those phase contracts.

## 1. OVERVIEW

This reference defines the shared mechanisms that every migration phase contract references. The controls describe required behavior and do not claim that a tool already implements them. Each mechanism is defined once here so the phase contracts can point to it.

---

## M1. Register schemas and complete source manifests

Store versioned register schemas under `migration-workspace/Schemas/`. Each schema records its name, version and SHA-256 of canonical UTF-8 schema bytes with stable key ordering. Each export manifest records source, scope, period, timestamp, page size and count, record count, byte count, SHA-256, exclusions, and independent source control totals.

The Evidence Archivist captures an independent UI or portal count outside the exported artifact for every export. The Independent Auditor reproduces the count and compares full page and record counts with the manifest. A count derived from the same artifact is not independent. If the source has no independent control, stop acceptance until the Operator supplies a reproducible source-side count and its derivation. Recompute checksums after transfer and restore. A manifest proves file integrity and declared scope, not source completeness by itself.

## M2. Stable local write keys and uncertain outcomes

Build each duplicate key from source system, source administration alias, object type, source object ID and target administration alias. Store the mapping schema version beside the key. Do not include that version in the key. Store the key, schema version, source-manifest hash, source reference, planned payload hash (HMAC-SHA256 with the M12 key), planned payload fields, target match rule, attempt state and returned target ID under `migration-workspace/WriteJournal/`. During Phase 6, define a supported target reference field or a deterministic fingerprint from confirmed target fields, plus the complete read route and period scope used to find it. If uniqueness or complete retrieval cannot be proven, stop before writing.

Before every non-GET call, recompute all approved batch input and mapping hashes immediately before writing. Abort and journal a drift stop if any hash differs. Then append a durable `WRITE_INTENT` event with the key and payload hash, flush it to disk and issue the call. Repeat the hash check after a pause or session restart. Do not assume Moneybird provides server-side idempotency or unique-key enforcement. After an uncertain write, use the recorded target match rule over a complete synchronized or paginated target population. Adopt a target ID only when the source reference and every planned payload field defined for the object type match exactly. A missing field definition, zero matches, multiple matches or unequal field stops the batch.

Make wait-based retry decisions only after a read-back waits beyond the Operator-approved `bulk_read.cache_horizon` recorded in `MIGRATION_CONFIG` with its route, source basis, approval identity, and evidence path, and independently verified by the Independent Auditor. A missing or unapproved horizon blocks any wait-based retry. A complete timestamped synchronization read remains an allowed retry check. Never blindly retry an uncertain write.

## M3. Append-only run journal, approvals and crash resume

Keep one append-only JSONL run journal under `migration-workspace/RunJournal/`, with one event per state change. Required states are `PLANNED`, `INPUT_FROZEN`, `ACCESS_CHECK_RECORDED`, `WRITE_INTENT`, `IN_PROGRESS`, `WRITE_UNKNOWN`, `WRITE_CONFIRMED`, `READBACK_CONFIRMED`, `RECONCILED`, `AGENT_DRAFTED`, `AGENT_VERIFIED`, `FINAL_REVIEWED`, `GATE_PASSED`, and `STOPPED`.

Every non-GET call has a flushed `WRITE_INTENT` immediately before the call, and every non-GET intent carries the `payload_digest` of the approved payload. An intent without a digest is refused. Each event records phase, batch or checkpoint key, input-manifest hash, item counts, prior state, new state, timestamp, owner tag, evidence paths, approval reference, `payload_digest`, and stop reason when present. Each `ACCESS_CHECK_RECORDED` event records `session_profile` (reader or writer) and `read_only_lock`, the observed value of `MONEYBIRD_GUARD_READ_ONLY`. Each material human approval records identity, role, decision, timestamp, evidence references and accepted exceptions.

Each `AGENT_DRAFTED`, `AGENT_VERIFIED`, and `FINAL_REVIEWED` event records the seat, executor route, brief hash, artifact hash, round, verdict and payload-scan count. These events contain no record content.

Never rewrite journal history. Resume only from the last verified state. Reconcile every `WRITE_UNKNOWN` item before another write. `AGENT_DRAFTED` is not a verified state. Resume agent work only from `AGENT_VERIFIED`, `FINAL_REVIEWED`, or a later verified and approved state. If the last agent event is `AGENT_DRAFTED`, restart at verification.

## M4. Evidence, privacy and session boundary

Keep finance artifacts under the ignored `migration-workspace/`. Preserve existing folders and add `Schemas/`, `Manifests/`, `Registers/`, `Inputs/<role>/`, `Mappings/`, `Exceptions/`, `Reports/`, `Snapshots/`, `WriteJournal/`, `RunJournal/`, `Archive/`, `Reviews/`, `Handoff/`, `Plans/`, and `AgentDesk/`. Link each run-journal event to its checkpoint artifacts.

Local role sessions run by the Agent runner read only their assigned controlled input folders to prepare registers. No agent seat receives record-level content, the Migration Writer and Final reviewer included. Prompts, tool logs, and session transcripts may contain only schemas, field names, phase and record-class labels, opaque record keys, HMAC hashes, aggregate counts under the M12 small-count rule, status, approval references, and evidence paths. CLI calls in agent sessions print summaries only and never use `--print-body`. Do not put source payloads, personal names, supplier or customer details, account identifiers, invoice numbers, or amounts in those surfaces. Before sharing output, the Independent Auditor scans it against this allowlist and records the count of prohibited private fields. Keep record-level evidence in the controlled workspace. The recorded prohibited-field count must equal zero. External seats use the M12 route, which preserves this allowlist and scan rule.

## M5. Moneybird rate limits and recovery

The documented shared-IP limits are 150 requests per five minutes overall and 50 report requests per five minutes. The official CLI has no automatic 429 retry. Use one request ledger for every worker sharing an IP, serialize or pace calls within both limits, and record response status and `Retry-After`.

On 429, stop the affected call sequence and wait the stated interval. The Orchestrator may authorize one paced reissue for a read. For a non-GET call, first reconcile the outcome by guarded read-back and issue a new approved intent only when the target proves the write did not occur. If `Retry-After` is absent or the reissue returns 429, stop for Operator decision. Record the wait, authorization, read-back, new intent and result in the shared request ledger. Do not raise concurrency to catch up.

## M6. Access window through writes and verification

`MIGRATION_CONFIG` records the observed trial or package state, expiry date, evidence source, observation date, renewal owner and alert evidence. Before each Moneybird non-GET batch, the Operator reconfirms the state and date against expected batch completion, synchronization, read-back and verification. A missing, expired or uncertain access window blocks the batch.

By the Phase 17 gate, require an active paid package that covers the next live VAT period and year close, with a named renewal owner and alert evidence. Recheck the access window before Phase 22 verification. Confirm archive coverage and export before any lapse or decommission decision.

## M7. Exception and threshold control

Every exception has a stable exception key, phase, source and target references, owner, backup owner when applicable, reviewer, due date, escalation deadline, status, evidence path, resolution, acceptance authority, expiry or reopen date, and corrective-entry link. Thresholds are numeric and approved in `MIGRATION_CONFIG`.

Missing threshold values, cross-period netting, unapproved residual differences, incomplete exception fields and expired accepted exceptions block the gate. The default for exact copied data is zero unexplained differences. Corrections to committed records use an approved, linked, append-only reversal or credit and a replacement where supported. Do not edit or delete committed history in place. The Operator or adviser approves the correction type, and every changed target is read back and reconciled.

## M8. Jortt pagination and source request evidence

Jortt list reads use the documented `--all` behavior, which follows next links and merges pages. Record page size, page count, expected total when supplied, item count per page, request status, rate-limit events and the completed next-link chain in the manifest. The documented page limit is 100 items and request limit is 10 per second. The current CLI throttles each request by 0.11 seconds and retries HTTP 429 at most three times, honoring `Retry-After` or using exponential delay. Bind these implementation facts to the recorded tool revision and verify again if that revision changes. Issue one CLI invocation per logical extraction and do not start a second invocation while CLI-managed 429 recovery is active. Record the operation, tool revision, invocation time, final status and retry metadata when exposed. If the CLI does not expose internal attempt counts, record that they are not reported and do not claim attempt-level evidence.

A missing next link, unexplained page cap, incomplete chain or count mismatch blocks Phase 1 and every dependent export.

## M9. Master phase dashboard

Maintain one dashboard row for each phase from 0 through 22. Each row records phase ID, status, phase-contract check status and evidence, named owner, evidence link, due date, exception count, and last verified resume checkpoint. Before Phase 0 passes, the Independent Auditor verifies exactly one phase heading per phase and all 11 contract fields plus a numeric exit gate for every phase. Record 23 of 23 checks with evidence. Update rows on every gate, stop, resume and recurring cadence. Reconcile dashboard rows to the run journal and phase contracts. Phase 22 requires all 23 rows current with no missing evidence or checkpoint.

## M10. Write-isolation decision

The default is an isolated writer identity and session behind `moneybird-guard`, with reader and writer profiles kept separate. Every reader session sets `MONEYBIRD_GUARD_READ_ONLY=1`. A writer session is opened only for an approved batch, has that read-only variable absent, and is closed after its approved non-GET calls. Never reuse a writer session for reads. Start read-back in a separate reader session with the lock set. Record each session profile and the observed lock state in the journal. Guard-only isolation is allowed only when the Operator records why separate writer isolation is unavailable and accepts the residual risk.

Never place tokens in arguments, prompts, logs or tracked files. Record the isolation decision, rationale, owner, evidence and review date in `MIGRATION_CONFIG`. Review it before Phase 18. An absent or expired review blocks cutover.

## M11. Stop-state recovery matrix

Record one recovery row for every stop event, including its owner, evidence, retry rule and closure test. Unknown writes require guarded read-back before retry, 429 recovery requires a recorded wait and Orchestrator authorization, and validation failures require correction and reapproval. No batch resumes until its closure condition passes.

| Stop state | Owner | Required evidence | Retry rule | Closure condition |
|---|---|---|---|---|
| `WRITE_UNKNOWN` | Migration Writer | Flushed intent, request status, source reference, planned fields, target read-back | No retry until the documented cache wait or a complete timestamped synchronization read. Ambiguity stops the batch. | Adopt an exact source-reference and planned-field match, or evidence an approved safe retry with no duplicate. |
| `HTTP_429` | Orchestrator | Shared request ledger, response status, `Retry-After`, affected batch | Wait the documented interval. Authorize one read reissue, or require guarded read-back and a new approved intent before a write reissue. | Required request completes and the ledger records wait, authorization, read-back when needed, intent and status. |
| `VALIDATION_FAILURE` | Mapping Agent | CLI validation result, mapping version, planned payload | Do not retry the same payload. Correct the mapping, reapprove, rehash and issue a new intent. | Corrected payload passes validation and its approval and hash are recorded. |
| `MISSING_SOURCE_OR_HASH_MISMATCH` | Evidence Archivist | Source manifest, page chain, source total, file hash | Do not perform dependent writes. Re-extract or restore the affected class and create a new manifest version. | Required source coverage and independent totals reconcile to 100%. |
| `STALE_OR_INCOMPLETE_READ` | Independent Auditor | Synchronization timestamp, page counts, cache wait, expected total | Do not use zero-match results for retry or pass decisions. Repeat only after the documented wait or complete synchronization. | Freshness and completeness are evidenced and counts reconcile. |
| `RECONCILIATION_MISMATCH` | Reconciliation Agent | Source and target reports, linked exception, correction evidence | Do not net across periods or accounts. Correct only through the approved append-only correction path. | Difference is zero or a complete, approved exception is within configured limits. |
| `PRECALL_REFUSAL` | Orchestrator | Guard or CLI exit code, refusal text, named precondition, attempted route, run-journal stop entry | Fix the named precondition before a new call. Never reissue the same call unchanged. | The corrected call passes the gate and the precondition fix is recorded with its evidence. |
| `PAYLOAD_MISMATCH` | Migration Writer | Guard exit 9, the exit-3 preview digest line, the matched `WRITE_INTENT` and the writer-session dry run | Do not reissue. After a key rotation or a settled payload, record a new approved intent with the `payload_digest` of a fresh writer-session dry run. | The exit-9 refusal is recorded and a new intent carries a digest the guard accepts. |
| `POSTCONDITION_ABSENT` | Migration Writer | Write log, flushed `WRITE_INTENT`, response status, synchronized read-back, target match rule | Do not reissue. Confirm with a synchronized read that the write record is absent or that a 204 delete left the record present. A retry needs a new approved intent. | The synchronized read settles the write or delete outcome. A reissue carries a new approved intent and the write log links the result. |

## M12. External agent route

M12 runs every migration work unit through a deterministic local Agent runner. A work unit is one nested sub-goal, one batch artifact or one recurring cycle. The Operator keeps approvals, UI exports and imports, filing, period locks, source freeze, go-live, decommission, and local review of AMBER, high-risk, and content-judgment records.

| Seat | Operator default | Role and boundary |
|---|---|---|
| Operator | Operator | Decides, approves and reviews sensitive records locally. |
| Agent runner | Local deterministic runner | Orchestrates briefs, dispatch, local role sessions, sandbox runs, filtering, scanning, local payload assembly, journal events and dashboard rows. It does not book records. |
| Implementer | DeepSeek V4.1 Flash at max thinking through the Pi CLI with the llmgateway provider | Drafts scripts, schemas, mapping tables and report templates from summaries. Tools, extensions, skills, context files and sessions are disabled. |
| Verifier | GPT-6 Luna at max effort on the fast service tier through the Codex CLI | Owns independent checks, fixtures, privacy filter, payload scanner and adversarial corpus. It receives no record-level content. |
| Final reviewer | Claude, the session running this skill | Reviews the final phase after every work unit passes or has an Operator disposition. Reads filtered summaries, verdicts, gate results and alias-level evidence only. It receives no record-level content. |
| Migration Writer | Claude in a separate writer session | Issues only approved Moneybird writes under M2, M3 and M10. Receives batch and record aliases, payload hashes, counts and the approval reference, never payload content. Runs `moneybird-guard --confirm-write --approval <ref>` against the payload file the local payload assembler built. The guard loads its token from the local environment file. No seat sees the token. |
| Local role sessions | Agent runner executes Implementer drafts | Evidence Archivist, Document, Ledger, Bank, Tax Filing, VAT, Reconciliation and Mapping duties remain local and read only their assigned input folders. |
| Risk assignment | Local deterministic rules | The Implementer drafts the rules through the work unit loop. The Verifier checks rule logic and application counts. The Operator reviews AMBER and high-risk records locally. |
| Red Team | Verifier in a separate session | Uses a clean working copy without verdicts, final reviews or earlier findings. |

These table routes are the Operator's defaults. Implementer dispatch disables tools, extensions, skills, context files and sessions. Verifier dispatch uses a read-only sandbox in a fresh working copy of required agent-facing files, inside an OS-level boundary that denies protected reads and network egress except to its approved model endpoint. The operating system deny result proves the boundary, not the agent event log. Keep stdin closed and capture a JSON event log for each dispatch.

Create `migration-workspace/AgentDesk/` with `Briefs/`, `Drafts/`, `Fixtures/`, `Scripts/`, `Checks/`, `Summaries/`, `Verdicts/`, `FinalReviews/`, and `Logs/`. Only agent-facing material belongs there. Every other `migration-workspace/` location and the private source archive are protected by a deny-by-default boundary. A new folder is protected without a configuration change. Phase 0 proves the boundary with a canary marker in every protected location and a blocked outbound request. The Agent runner repeats the boundary canary at every phase entry and after any boundary path change. If the boundary cannot be proven, the Verifier does not run with tools. Verification falls back to the same configured model through Pi with tools disabled, or the work stops. No Operator residual-risk acceptance permits a tool-enabled Verifier without a proven boundary. Until the Phase 0 boundary canary passes, the Verifier runs only through that text-only route, except for the canary dispatch itself, which names only the canary marker files. In Phase 0 that passed route proof counts as the phase-entry boundary canary.

Every Implementer- or Verifier-drafted script runs in a local sandbox with read access to its own input folder only, write access to a local output folder outside `AgentDesk/` only, and no network. The Verifier reviews the code on independent fixtures before its first run on controlled data. Raw stdout, stderr and tracebacks go to a protected local log. The Agent runner, Claude and the agents see only a filtered summary and an error-class code.

Summaries are structured and fail closed. Only allowlisted keys with typed integer, boolean, enum or alias values pass. Never copy record free text. Field labels come from schemas, not records. Agent-facing record keys use one stable random alias per record for a whole phase, or for one cycle of a recurring phase, because a fix loop never crosses that boundary. A finding and its fix therefore name the same record. Aliases rotate only when a new phase or cycle starts. Artifact and evidence paths are opaque aliases with the real map kept locally. Digests of record-derived values and M2 planned payload hashes use HMAC-SHA256 with a 32-byte random key at `migration-workspace/.secrets/alias-hmac.key`, file mode 600. The Operator creates and owns the key, and no agent seat reads it. The Operator rotates it when a new phase or cycle starts, the same boundary at which aliases rotate. Retired keys stay in `migration-workspace/.secrets/retired/` for local journal checks only. Plain SHA-256 is used only for whole artifacts and brief hashes. Amount checks report equality or within-threshold results, mismatch counts and aliases, never amounts. Aggregate counts are allowed by the Operator's summaries-only choice, with small-count suppression at k=10. In any agent-facing summary, prompt, log or report, a count from 1 to 9 is shown as `<10`. Zero stays `0`, so pass and fail gates still read, and a count of 10 or more is shown as is. Local Operator-only reports keep exact counts. No real record leaves the machine, for any seat.

Writes use local payload assembly. The Agent runner's local deterministic payload assembler builds each exact Moneybird request payload from the frozen inputs and approved mapping tables, writes it under the protected workspace and records its HMAC payload hash in the write journal. The Migration Writer never reads or composes payload content. The guard prints only a response summary, so the response body stays out of the writer session too.

The Verifier owns the privacy filter, payload scanner and adversarial corpus. Scan the exact provider payload bytes before every dispatch and fail closed with prohibited-field count 0. The Independent Auditor rescans logged payload copies as its M4 check. The Verifier's independent fixtures, record-level check and summary extraction do not reuse Implementer code, fixtures or filters. The Agent runner executes the check over every record locally and returns only a filtered summary. A write cannot proceed until the independent local record-level check passes and all existing phase gates and Operator approvals pass.

### Work unit loop

Each phase's "Run the agent route" sub-goal is the phase's route record, not a work unit. It passes when every work unit of the phase has Verifier PASS or an Operator disposition, and its last check is the final review.

1. **Brief, Agent runner:** Build one brief from the phase contract with its sub-goal, check, allowed summary inputs, output format and END line. Save its SHA-256 and require payload-scan count 0.
2. **Draft, Implementer:** Return the artifact as text with a self-check. Require a normal stop reason and END line. An empty or cut answer means split the brief, not add a round. A provider failure permits one fallback route using the same model through another provider, logged as transport rather than a round.
3. **Code review, Verifier:** Review on independent fixtures before any controlled-data run. The Agent runner hashes the exact applied artifact and its dependencies. Nobody edits a draft. Any change, including a path fix, starts a new round and needs new verification.
4. **Run, Agent runner:** Run the script in the local sandbox when the sub-goal needs controlled data. Return only the filtered summary.
5. **Verify, Verifier:** Run its own record-level check through the Agent runner and compare every record, not only totals. Return PASS, FAIL with severity and reproduction for each finding, or BLOCKED for an Operator decision.
6. **Fix loop, Implementer and Operator:** A FAIL returns findings to the Implementer in a new brief. Stop after `agents.max_rounds` rounds, default 3. The Operator then directs a brief, approves an exception under M7, records a descope in configuration or stops the work under M11. Final review waits for that disposition.
7. **Final review, Final reviewer:** After every work unit has Verifier PASS or an Operator disposition, rerun the Verifier checks from the final state. Confirm every numeric exit-gate item against evidence, payload-scan and boundary audits at 0, and no agent or script write outside its allowed folder. Record Final review PASS or FAIL. Operator approvals follow as one decision summary per phase.
8. **Reuse fast path, Agent runner and Verifier:** In recurring phases, a read-only script with unchanged artifact hash, unchanged configuration hash and recorded input hash skips code review only. The record-level check still runs every cycle. A changed tax rate, rule, configuration or environment invalidates the fast path.

A provider failure on both configured routes, Verifier FAIL after the maximum rounds without disposition, payload-scan finding above 0, boundary canary failure, any write outside an allowed folder, an applied artifact hash that differs from the verified hash or an unverified artifact used in a gate stops the work. A rejected draft never touches the ledger and remains marked superseded.

### Per-phase agent work

| Phase | Implementer drafts | Verifier independently checks | Stays with the Operator |
|---|---|---|---|
| 0 | Agent runner, fixture generator, canary harness and sandbox profile | Own privacy filter, payload scanner and adversarial corpus. Boundary and egress canaries, planted private values blocked and both route canaries | Route configuration approval |
| 1 | Per-class extraction and manifest builders for M1 and M8 | Source counts and page-chain reproduction | UI-only exports and source-side counts |
| 2 | Missing-source checklist, archive seeding and hash scripts, and retention table template | Archive restore test and hash recompute | Collecting sources |
| 3 | One register builder per source, each in its own session | Register totals and static check that each builder reads only its folder | None new |
| 4 | Linker and stable-key builder | Match recount and duplicate-key check | None new |
| 5 | Anomaly scan rules | Planted-anomaly fixtures detected | Exception decisions |
| 6 | Mapping tables, opening schedules and continuity schedules | Every mapped field against the target schema and planted unmappable cases | Accounting treatment approval |
| 7 | Pilot batch builder, pre-write report and read-back comparer | Pre-write report and read-back comparison | Batch approval |
| 8 | Per-period batch plans and builders | Per-batch pre-write and read-back | Batch approvals |
| 9 | Per-period VAT reconciliation | VAT recompute from source registers | Filed-return evidence |
| 10 | Year-end comparison | Year-end recompute | Auditfile export and year-end closing (jaarafsluiting) |
| 11 | Income-tax bridge template | Bridge checks and no invented adjustment | Adviser decisions |
| 12 | Continuity checker | Account-by-account check | None new |
| 13 | Fixes for Red Team findings only | Red Team tries to falsify the year from a clean working copy | Accepting residual exceptions |
| 14 | Snapshot sealing and hash manifest | Hash recompute | Period lock in the UI |
| 15 | Year-advance checklist | Prior-year lock evidence | None new |
| 16 | Parallel comparison and delta schema | Delta check | Parallel cycle sign-off |
| 17 | Freeze delta extraction and archive restore test | Restore proof and freeze-boundary check | Freezing Jortt |
| 18 | Go-live checklist and final delta batch | Final delta and isolation review | Go-live approval |
| 19 to 21 | Monthly, VAT-period and yearly check scripts using the reuse fast path | Run summaries, with code review only when the hash changes and a record-level check every cycle | Filing and yearly approval |
| 22 | Completion report and definition-of-done evidence index | Definition of done, archive and retention recheck | Cancel-or-keep decision |

## Route contract

The external agent seats and work-unit handoffs follow M12. Jortt and Moneybird operations still use only the required routes below.

### Jortt reads and exports

Use [jortt-cli](../../../cli-jortt/SKILL.md) with read scopes only. List extraction uses `--all` and records the next-link chain, page counts, item counts, final response status and independent source-side total. The CLI owns its documented 429 wait and bounded retry behavior. A missing or failed result stops the extraction. XAF, annual accounts (jaarrekening) and filed-return exports are Operator UI work. The tool route does not provide a general-ledger API or UI export. A VAT summary is not a filed return.

### Moneybird reads and writes

Every Moneybird read follows the Read Step Contract in `cli-moneybird/SKILL.md` section 3. Use [moneybird-guard](../../../cli-moneybird/SKILL.md) with `MONEYBIRD_GUARD_READ_ONLY=1`, explicit periods, and synchronization for complete bulk reads. Record synchronization timestamps and completion counts. If synchronization is unavailable, wait beyond the Operator-approved and Independent Auditor verified cache horizon in `MIGRATION_CONFIG`, then use a complete paginated read with page counts before retry decisions. Missing or unapproved horizon blocks a wait-based retry. Token scopes do not create a read-only token.

Moneybird non-GET calls use `moneybird-guard` in the writer session only after the phase gate and Operator approval. This subsection is the single canonical write contract, and every other restatement keeps one safety line and points here. The gate tokens are `MONEYBIRD_GUARD_READ_ONLY=1`, `--confirm-write`, `--approval`, `--production`, `WRITE_INTENT` and `payload_digest`. A flushed `WRITE_INTENT` carrying the approval reference and the `payload_digest` of the approved payload must precede each call, and M3 makes that digest mandatory for every non-GET intent. The guard refuses the write when the run journal has no matching entry, when the writer configuration is missing, when the writer-session dry run does not reproduce the intent digest and when the reference and digest pair already has a write-log row. The guard's write path exits with 1, 2, 3, 4, 5, 6, 7, 8 and 9. Exit 9 is `PAYLOAD_MISMATCH`: the keyed HMAC-SHA256 digest of the writer-session dry run does not match the `payload_digest` of the matched `WRITE_INTENT`, or the intent has none.

Phase 7, 8 and 16 mirror batches use the single pilot and mirror administration and do not use `--production`. Phase 18 final-delta writes remain mirror batches until the Operator approves go-live. Phases 19 to 21 are production batches after Phase 18 passes and use `--production` only with the Operator's approval for that batch.

The contract keeps the evidence rule: the exit-3 preview prints one `payload-digest: <hex>` line, and the write log row holds the approval reference, the batch key, the digest and the exit status and never a body. It keeps the idempotency rule: a reference and digest pair is single use, so the guard refuses a pair that already has a write-log row and a retry needs a new approved intent. Read-back means a later synchronized read in a separate reader session with `MONEYBIRD_GUARD_READ_ONLY=1`, or a read after the configured cache wait, and never the write response itself.

### Auditfile export and Operator UI actions

Phase 0 tests the auditfile through an Operator-approved Moneybird UI export and verifies its artifact. The guarded report-export POST is first used only after a phase gate passes. For each POST, the Operator approves the exact year and version, and the Migration Writer flushes an operation-scoped `WRITE_INTENT` with the requested operation, payload hash and approval reference before using `--confirm-write --approval <ref>` in a separate writer session. The writer records approval and session boundaries, then closes the session. The Independent Auditor confirms job completion and verifies the downloaded artifact receipt and SHA-256 in a separate session with `MONEYBIRD_GUARD_READ_ONLY=1`. Never clear the lock in a reader session or treat an export approval as general write access.

CAMT.053 and MT940 imports, tax-rate creation, period locking, manual historical VAT status and Jortt UI exports remain Operator UI actions. Every Operator UI action that changes ledger or tax settings has a prior approval record, an action receipt and a guarded read-back where available, linked from M3.
