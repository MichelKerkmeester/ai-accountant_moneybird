---
title: "cli-jortt: Manual Testing Playbook"
description: "Operator-facing reference combining the manual testing directory, review and orchestration guidance and the per-feature validation files for the cli-jortt skill."
version: 1.0.0.0
---

# cli-jortt: Manual Testing Playbook

This document combines the manual-validation contract for the `cli-jortt` skill into a single reference. The root playbook is the operator directory, review protocol and orchestration guide. It explains how realistic requests are run, how evidence is captured, how results are graded and where each per-feature validation file lives. The per-feature files carry the execution contract for each scenario.

---

This playbook package follows the feature catalog split-document pattern. The root document is the directory and review surface, and per-feature execution detail lives in the category folders at the playbook root. Each scenario links back to its entry in the [feature catalog](../feature-catalog/feature-catalog.md).

Canonical package artifacts:

- `manual-testing-playbook.md`
- `auth-and-scopes/`
- `setup/`
- `operation-discovery/`
- `extraction/`
- `routing/`

### Result persistence

<!-- MANUAL_PLAYBOOK_RESULT_PERSISTENCE_CONTRACT -->
A scenario run is complete only after its `PASS`, `FAIL` or `SKIP` outcome, its reason and its evidence paths are recorded in `../benchmark/reports/<dated-run-label>/`. Generated report Markdown is renderer-owned and never hand-authored. A run never edits this playbook.

---

## 1. OVERVIEW

This playbook validates the operator-visible behavior of the `cli-jortt` skill: the offline gates of `jortt-cli`, its read-only extraction path and the routing of requests the API cannot serve. The operator validator derives the scenario and category counts from the tree, so this root does not hand-maintain them. Each scenario keeps its published ID.

Coverage note: offline scenarios use the local OpenAPI file and never contact Jortt. Live scenarios make read-only requests and need an operator-approved read-only key. No scenario writes to Jortt.

### Realistic Test Model

1. A realistic user request is given to an agent that has loaded `SKILL.md`.
2. The agent decides whether the request belongs to the CLI, the operator's UI or the sibling Moneybird skill.
3. The operator captures the execution process and the user-visible outcome.
4. The scenario passes only when the workflow is sound and the answer would satisfy a real user.

### What Each Feature File Should Explain

- The realistic user request that should trigger the behavior
- The prompt that drives the test
- The expected execution process and whether it is offline or live
- The desired user-visible outcome
- The implementation, test and feature catalog anchors that justify the scenario

---

## 2. GLOBAL PRECONDITIONS

1. Working directory is the repository root. `jortt-cli` is on `PATH` through the symlink that `setup.sh` prints, or the operator calls it by its full path.
2. A local OpenAPI file exists, either in the spec cache or through `JORTT_OPENAPI_FILE`.
3. Live scenarios use a read-only key whose `JORTT_SCOPES` holds no `:write` scope, and the operator has approved the live read.
4. Evidence never contains credentials, record contents, signed URLs or organization values. Use the placeholders shown in each scenario.
5. No scenario is destructive. JRT-010 clears only a throwaway cache entry, and every saved file lands in the ignored `migration-workspace/` folder.

---

## 3. GLOBAL EVIDENCE REQUIREMENTS

- Command transcript with absolute paths and secrets redacted
- User request used
- Prompt used
- Exit code for every command
- Output snippets limited to status lines, counts and field names
- Final user-facing response or outcome summary
- Saved file name when a scenario writes into the workspace
- Scenario verdict with rationale

---

## 4. DETERMINISTIC COMMAND NOTATION

- CLI commands shown as `bash: jortt-cli <subcommand> [args]`.
- Script commands shown as `bash: bash <path>`.
- Agent actions shown as `agent: <instruction>`.
- `->` separates sequential steps.
- Uppercase words such as `RECEIPT_ID`, `SIGNED_HTTPS_URL` and `YYYY` are placeholders the operator fills at run time.

---

## 5. REVIEW PROTOCOL AND RELEASE READINESS

### Inputs Required

1. `manual-testing-playbook.md`
2. The per-feature files under the category folders
3. Scenario execution evidence
4. The feature catalog cross-reference index below
5. Triage notes for every non-pass outcome

### Scenario Acceptance Rules

For each executed scenario, check:

1. Preconditions were satisfied.
2. Prompt and command sequence were executed as written.
3. Expected signals are present.
4. Evidence is complete, readable and free of personal data.
5. Outcome rationale is explicit.

Scenario verdict:

- `PASS`: all acceptance checks are true
- `FAIL`: expected behavior is missing, output contradicts the contract or a critical check failed
- `SKIP`: a named sandbox or runtime blocker prevents execution, such as missing live credentials

### Feature Verdict Rules

- `PASS`: every mapped scenario for the feature is `PASS`
- `FAIL`: any mapped scenario is `FAIL`
- `SKIP`: every mapped scenario is stopped by a named sandbox or runtime blocker

Hard rule: a `FAIL` on JRT-002, JRT-003 or JRT-004 forces the feature verdict to `FAIL`, because those scenarios guard writes and output paths.

### Release Readiness Rule

A release is releasable only when:

1. No feature verdict is `FAIL`.
2. All critical scenarios are `PASS`.
3. Every scenario in the root index has a per-feature file.
4. No blocking triage item remains open.

### Root-vs-Feature Rule

Global verdict logic stays in this root playbook. Feature-specific caveats live in the matching per-feature files.

---

## 6. SUB-AGENT ORCHESTRATION AND WAVE PLANNING

### Purpose

This section records how to split the scenarios across workers. It is not a runtime support matrix.

### Operational Rules

1. Reserve one coordinator.
2. Run every offline scenario in the first wave: JRT-001, JRT-002, JRT-005, JRT-006, JRT-007, JRT-008, JRT-009, JRT-010 and JRT-013.
3. Run the live read scenarios JRT-003, JRT-004 and JRT-012 in a second wave, one worker at a time, so requests stay under the rate limit.
4. Pre-assign scenario IDs and their per-feature files to each worker before execution.
5. After each wave, record verdicts and evidence paths before starting the next wave.

### What Belongs In Per-Feature Files

- Real user request
- Prompt
- Expected routing between the CLI, the UI and the sibling skill
- Desired user-visible outcome
- Feature-specific caveats and the live or offline label

---

## 7. AUTH AND SCOPES

Scenarios: JRT-001, JRT-002, JRT-010, JRT-012.

### JRT-001 | Offline doctor

#### Description

Confirm the doctor checks local prerequisites and setup state without network access or printed secrets.

#### Scenario Contract

Prompt: `Run the cli-jortt doctor offline and tell me whether the CLI and prerequisites are present.`

The agent runs the doctor without `--live` and summarizes tool availability and setting presence.

Desired user-visible outcome: The operator learns which prerequisites and settings are present without seeing any credential value.

#### Test Execution

> **Feature File:** [JRT-001](auth-and-scopes/doctor-offline.md)
> **Catalog:** [diagnostics/offline-doctor.md](../feature-catalog/diagnostics/offline-doctor.md)

### JRT-002 | Write lock and missing scope

#### Description

Confirm a write without its explicit flag exits 3 and a write with the flag but a missing scope exits 4 before any network request.

#### Scenario Contract

Prompt: `Show the dry-run for a Jortt expense creation without sending a request.`

The agent runs both dry-run commands, reads each exit code and explains which gate stopped the call.

Desired user-visible outcome: The operator sees that the write flag is checked first and the scope second, with no request sent.

#### Test Execution

> **Feature File:** [JRT-002](auth-and-scopes/write-lock.md)
> **Catalog:** [safety-gates/write-lock.md](../feature-catalog/safety-gates/write-lock.md)

### JRT-010 | Token cache status

#### Description

Confirm token status and token clear report cache state without printing a token or calling the network.

#### Scenario Contract

Prompt: `Check whether jortt-cli has a cached token and clear it, without contacting Jortt.`

The agent uses a throwaway client ID so the real cache is untouched, then reads status, clears and reads status again.

Desired user-visible outcome: The operator sees cache state as yes or no with minutes, never the token itself.

#### Test Execution

> **Feature File:** [JRT-010](auth-and-scopes/token-status.md)
> **Catalog:** [transport/token-cache-and-retry.md](../feature-catalog/transport/token-cache-and-retry.md)

### JRT-012 | Organization check prints field names only

#### Description

Confirm whoami proves the live connection while printing only the HTTP status and top-level field names.

#### Scenario Contract

Prompt: `Check that my Jortt API key works, but do not show me any organization details.`

The agent confirms the operator approved a live read, runs `whoami` once and reports the status line.

Desired user-visible outcome: The operator learns the key works and sees no organization value.

#### Test Execution

> **Feature File:** [JRT-012](auth-and-scopes/whoami-field-names.md)
> **Catalog:** [api-calls/organization-check.md](../feature-catalog/api-calls/organization-check.md)

---

## 8. SETUP

Scenarios: JRT-013.

### JRT-013 | CLI setup check

#### Description

Confirm the setup script checks prerequisites and prints the symlink command without changing any file.

#### Scenario Contract

Prompt: `Check whether this machine is ready for jortt-cli and show me how to install it, but do not change anything.`

The agent runs the setup script without `--link` and relays the printed symlink command.

Desired user-visible outcome: The operator gets a readiness report and an install command to review.

#### Test Execution

> **Feature File:** [JRT-013](setup/setup-check.md)
> **Catalog:** [diagnostics/setup-check.md](../feature-catalog/diagnostics/setup-check.md)

---

## 9. OPERATION DISCOVERY

Scenarios: JRT-007, JRT-008.

### JRT-007 | List and describe operations

#### Description

Confirm ops filters by tag and describe prints the full contract of one operation from the local spec.

#### Scenario Contract

Prompt: `Which Jortt operations handle expenses, and what does the receipt download operation need?`

The agent lists the expense operations, then describes the receipt download operation and names its scope and parameter.

Desired user-visible outcome: The operator gets the expense operation list and the exact call shape for a receipt download.

#### Test Execution

> **Feature File:** [JRT-007](operation-discovery/list-and-describe-operations.md)
> **Catalog:** [operation-discovery/list-operations.md](../feature-catalog/operation-discovery/list-operations.md)

### JRT-008 | Spec info without network

#### Description

Confirm spec info reports the loaded spec and a missing spec without any network call.

#### Scenario Contract

Prompt: `Tell me which Jortt API spec jortt-cli is using, without going online.`

The agent reads the spec report, then points the CLI at a missing file to show the offline fallback report.

Desired user-visible outcome: The operator sees which spec is in use and how a missing spec is reported.

#### Test Execution

> **Feature File:** [JRT-008](operation-discovery/spec-info-offline.md)
> **Catalog:** [operation-discovery/openapi-spec-cache.md](../feature-catalog/operation-discovery/openapi-spec-cache.md)

---

## 10. EXTRACTION

Scenarios: JRT-003, JRT-004, JRT-009.

### JRT-003 | Paged extract to workspace

#### Description

Confirm a paged read saves its merged result under migration-workspace and rejects an outside path.

#### Scenario Contract

Prompt: `Extract expenses for one VAT year into the migration workspace and confirm an outside path is blocked.`

The agent confirms the operator approved a live read, runs the paged extract and then tries an outside destination.

Desired user-visible outcome: The allowed command stores one array and reports only status and count. The outside destination fails before a request.

#### Test Execution

> **Feature File:** [JRT-003](extraction/paged-extract-to-workspace.md)
> **Catalog:** [transport/paged-list-merge.md](../feature-catalog/transport/paged-list-merge.md)

### JRT-004 | Receipt download

#### Description

Confirm a receipt download link is fetched promptly into the workspace without sending the API bearer token to the signed URL.

#### Scenario Contract

Prompt: `Download one receipt through its Jortt link into the migration workspace.`

The agent confirms the operator approved a live read, requests the signed link and fetches it at once.

Desired user-visible outcome: The API call returns a signed URL and fetch saves its file under migration-workspace.

#### Test Execution

> **Feature File:** [JRT-004](extraction/receipt-download.md)
> **Catalog:** [api-calls/signed-download-fetch.md](../feature-catalog/api-calls/signed-download-fetch.md)

### JRT-009 | Raw GET path guard

#### Description

Confirm the raw GET command rejects a full URL, a parent-directory segment and a malformed query pair before any request.

#### Scenario Contract

Prompt: `Try a few unsafe raw Jortt GET requests and show me that jortt-cli refuses them.`

The agent runs three invalid `get` commands and reads each refusal and exit code.

Desired user-visible outcome: The operator sees three clear refusals and no request.

#### Test Execution

> **Feature File:** [JRT-009](extraction/raw-get-path-guard.md)
> **Catalog:** [api-calls/raw-get.md](../feature-catalog/api-calls/raw-get.md)

---

## 11. ROUTING

Scenarios: JRT-005, JRT-006.

### JRT-005 | XAF request goes to the UI

#### Description

Confirm an XAF request is routed to the operator and never sent to the API.

#### Scenario Contract

Prompt: `Export the Jortt XAF auditfile for a year.`

The agent loads the export reference, makes no API call and gives the operator the UI steps.

Desired user-visible outcome: The agent explains the UI route and asks the operator to generate one file per year.

#### Test Execution

> **Feature File:** [JRT-005](routing/xaf-request-goes-to-ui.md)
> **Catalog:** [surfaces/surface-routing.md](../feature-catalog/surfaces/surface-routing.md)

### JRT-006 | Moneybird request is deferred

#### Description

Confirm a target-side Moneybird operation is handed to the sibling skill without a Jortt call.

#### Scenario Contract

Prompt: `Create the imported invoice in Moneybird and verify it.`

The agent recognizes target-side work and hands it to the sibling skill.

Desired user-visible outcome: The agent hands off the request without calling Jortt.

#### Test Execution

> **Feature File:** [JRT-006](routing/moneybird-request-deferred.md)
> **Catalog:** [surfaces/surface-routing.md](../feature-catalog/surfaces/surface-routing.md)

## 12. AUTOMATED TEST CROSS-REFERENCE

| Test Module | Coverage | Playbook Overlap |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../cli/jortt-cli/tests/run-tests.sh) | Unique slugs, slug collision choice, describe output, dry-run URL, write lock, scope check, parameter validation and output path guard, all offline | JRT-002, JRT-003, JRT-004, JRT-007 |

---

## 13. FEATURE CATALOG CROSS-REFERENCE INDEX

| Feature ID | Feature Name | Category | Feature File | Catalog Entry |
|---|---|---|---|---|
| JRT-001 | Offline doctor | Auth and scopes | [JRT-001](auth-and-scopes/doctor-offline.md) | [diagnostics/offline-doctor.md](../feature-catalog/diagnostics/offline-doctor.md) |
| JRT-002 | Write lock and missing scope | Auth and scopes | [JRT-002](auth-and-scopes/write-lock.md) | [safety-gates/write-lock.md](../feature-catalog/safety-gates/write-lock.md) |
| JRT-003 | Paged extract to workspace | Extraction | [JRT-003](extraction/paged-extract-to-workspace.md) | [transport/paged-list-merge.md](../feature-catalog/transport/paged-list-merge.md) |
| JRT-004 | Receipt download | Extraction | [JRT-004](extraction/receipt-download.md) | [api-calls/signed-download-fetch.md](../feature-catalog/api-calls/signed-download-fetch.md) |
| JRT-005 | XAF request goes to the UI | Routing | [JRT-005](routing/xaf-request-goes-to-ui.md) | [surfaces/surface-routing.md](../feature-catalog/surfaces/surface-routing.md) |
| JRT-006 | Moneybird request is deferred | Routing | [JRT-006](routing/moneybird-request-deferred.md) | [surfaces/surface-routing.md](../feature-catalog/surfaces/surface-routing.md) |
| JRT-007 | List and describe operations | Operation discovery | [JRT-007](operation-discovery/list-and-describe-operations.md) | [operation-discovery/list-operations.md](../feature-catalog/operation-discovery/list-operations.md) |
| JRT-008 | Spec info without network | Operation discovery | [JRT-008](operation-discovery/spec-info-offline.md) | [operation-discovery/openapi-spec-cache.md](../feature-catalog/operation-discovery/openapi-spec-cache.md) |
| JRT-009 | Raw GET path guard | Extraction | [JRT-009](extraction/raw-get-path-guard.md) | [api-calls/raw-get.md](../feature-catalog/api-calls/raw-get.md) |
| JRT-010 | Token cache status | Auth and scopes | [JRT-010](auth-and-scopes/token-status.md) | [transport/token-cache-and-retry.md](../feature-catalog/transport/token-cache-and-retry.md) |
| JRT-012 | Organization check prints field names only | Auth and scopes | [JRT-012](auth-and-scopes/whoami-field-names.md) | [api-calls/organization-check.md](../feature-catalog/api-calls/organization-check.md) |
| JRT-013 | CLI setup check | Setup | [JRT-013](setup/setup-check.md) | [diagnostics/setup-check.md](../feature-catalog/diagnostics/setup-check.md) |
