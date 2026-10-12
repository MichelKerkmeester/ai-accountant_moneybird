---
title: "cli-moneybird: Manual Testing Playbook"
description: "Operator-facing reference combining the manual testing directory, integrated review and orchestration guidance, execution expectations and per-feature validation files for the cli-moneybird skill."
version: 1.0.0.0
---

# cli-moneybird: Manual Testing Playbook

This document combines the full manual-validation contract for the `cli-moneybird` skill into a single reference. The root playbook acts as the operator directory, review protocol and orchestration guide: it explains how realistic user-driven tests are run, how evidence is captured, how results are graded and where each per-feature validation file lives. The per-feature files carry the deeper execution contract for each scenario, including the user request, the prompt, the command block, the source anchors and the validation criteria.

---

This playbook package adopts the Feature Catalog split-document pattern for the `cli-moneybird` skill. The root document acts as the directory, review surface and orchestration guide, while per-feature execution detail lives in the category folders at the playbook root. Every scenario links back to its entry in [`../feature-catalog/feature-catalog.md`](../feature-catalog/feature-catalog.md).

Canonical package artifacts:
- `manual-testing-playbook.md`
- `setup/`
- `write-safety/`
- `reads/`
- `routing/`

### Result persistence

<!-- MANUAL_PLAYBOOK_RESULT_PERSISTENCE_CONTRACT -->
A scenario run is complete only after its `PASS`, `FAIL` or `SKIP` outcome, its reason and its evidence paths are recorded into `cli-moneybird/benchmark/reports/<dated-run-label>/`. The run index lives in [`../benchmark/reports/README.md`](../benchmark/reports/README.md). Evidence never carries a token, a real administration ID or record content.

---

## 1. OVERVIEW

This playbook validates the `cli-moneybird` skill surface with deterministic scenarios grouped by capability. The operator validator derives the scenario and category counts from the walked tree, so this page does not maintain them by hand. Each scenario keeps its published ID and links to a dedicated feature file with the full execution contract.

Coverage note: offline scenarios exercise `moneybird-guard`, `setup.sh` and `doctor.sh` against the packaged CLI stub in a temporary folder. Routing scenarios check the agent's answer against the skill sources. MBD-012 is the only live scenario and writes to the pilot administration. Accounting reconciliation and production batches stay outside this playbook.

### Realistic Test Model

1. A realistic user request is given to an agent that has loaded the skill.
2. The agent decides whether the work stays local, runs against the stub or needs the operator for a live step.
3. The operator captures both the execution process and the user-visible outcome.
4. The scenario passes only when the workflow is sound and the returned result would satisfy a real user.

### What Each Feature File Explains

- The realistic user request that triggers the behavior
- The prompt that drives the test
- The expected execution process, including any operator step
- The desired user-visible outcome
- The implementation, test and feature catalog anchors that justify the scenario

---

## 2. GLOBAL PRECONDITIONS

1. The working directory is the `cli-moneybird/` package root unless a scenario names the Moneybird Accountant folder.
2. Offline scenarios use only the packaged stub `cli/moneybird-cli/tests/stub-moneybird-cli` and a temporary folder from `mktemp`. They set `MONEYBIRD_GUARD_TEST=1` beside `MONEYBIRD_ENV_DIR` and `MONEYBIRD_CLI`, and point `MONEYBIRD_WRITER_CONFIG_DIR` at a temporary writer configuration folder. `MONEYBIRD_GUARD_TEST=1` is a test-only setting for the offline suite and is never set in a real session. They write a generated test key at `<root>/migration-workspace/.secrets/alias-hmac.key`. They write a run journal at `<root>/migration-workspace/RunJournal/run-journal.jsonl`. It holds a `WRITE_INTENT` line with an `approval_reference` and the `payload_digest` the preview printed, so stub writes pass `--approval` with that reference. They never touch the real CLI session, `.env` or `.env.writer`.
3. `bash`, `jq` and `rg` are installed. `jq` is required for the write log scenarios.
4. Live scenario MBD-012 runs only after the operator approves it. It needs a real `WRITE_INTENT` entry for each write, with an approval reference the operator recorded and the payload digest its preview printed. Every live write targets the pilot administration named by the `MONEYBIRD_PILOT_ADMINISTRATION_ID=` line in the root `.env` file and never another administration.
5. Destructive scenario MBD-012 MUST verify recovery is possible: it deletes the record it created, confirms removal with a separate read and falls back to the correction recipe in `references/migration-recipes.md`.
6. No scenario reads or lists `personal database/`. No evidence carries a token, a real administration ID or record content.

---

## 3. GLOBAL EVIDENCE REQUIREMENTS

- Command transcript with identifiers replaced by placeholders
- User request used
- Prompt used
- Operator steps for live scenarios
- Output snippets and exit statuses
- Final user-facing response or outcome summary
- Artifact path or output reference inside the temporary folder or `migration-workspace/`
- Scenario verdict with rationale

---

## 4. DETERMINISTIC COMMAND NOTATION

- Guard commands shown as `moneybird-guard <guard flags> <moneybird-cli args>`.
- CLI help shown as `moneybird-cli <resource> <action> --help`.
- Guard calls shown as `moneybird-guard <guard flags> <moneybird-cli args>`.
- Bash commands shown as `bash: <command>`.
- Agent prompts shown as `agent: <instruction>`.
- `->` separates sequential steps.
- A command block in a feature file holds the exact commands for its numbered steps.

---

## 5. REVIEW PROTOCOL AND RELEASE READINESS

### Inputs Required

1. `manual-testing-playbook.md`
2. Referenced per-feature files under `manual-testing-playbook/<category>/`
3. Scenario execution evidence
4. Feature-to-scenario coverage map from Section 13
5. Triage notes for all non-pass outcomes

### Scenario Acceptance Rules

For each executed scenario, check:

1. Preconditions were satisfied.
2. Prompt and command sequence were executed as written.
3. Expected signals are present.
4. Evidence is complete, readable and free of credentials.
5. Outcome rationale is explicit.

Scenario verdict:
- `PASS`: all acceptance checks are true
- `FAIL`: expected behavior is missing, output contradicts it or a critical check failed
- `SKIP`: a specific sandbox or runtime blocker prevents execution, such as a missing operator approval or an unavailable OAuth credential for a live scenario

### Feature Verdict Rules

- `PASS`: all mapped scenarios for the feature are `PASS`
- `FAIL`: any mapped scenario is `FAIL`
- `SKIP`: every mapped scenario is blocked by a named sandbox or runtime blocker

Hard rule:
- Any write-safety scenario `FAIL` forces the feature verdict to `FAIL`.

### Release Readiness Rule

Release is releasable only when:

1. No feature verdict is `FAIL`.
2. All write-safety scenarios are `PASS`.
3. Coverage is 100% of playbook scenarios defined by the root index and backed by per-feature files (`COVERED_FEATURES == TOTAL_FEATURES`).
4. No unresolved blocking triage item remains.

### Root-vs-Feature Rule

Keep global verdict logic in the root playbook. Put feature-specific acceptance caveats in the matching per-feature files.

---

## 6. SUB-AGENT ORCHESTRATION AND WAVE PLANNING

### Purpose

This section records wave planning for the manual testing package. It is not a runtime support matrix.

### Operational Rules

1. Probe runtime capacity at start and reserve one coordinator.
2. Wave 1 runs the offline stub scenarios in parallel. Each block creates its own temporary folder, so they do not share state.
3. Wave 2 runs the routing scenarios, which only need the agent's answer and a source check.
4. Wave 3 runs the live scenario with the operator present. MBD-012 runs alone in a dedicated pilot-only wave.
5. Pre-assign scenario IDs and their per-feature files to each wave before execution.
6. After each wave, save the evidence, then begin the next wave.
7. Record the wave plan, per-feature file references and evidence paths in the run report.

### What Belongs In Per-Feature Files

- Real user request
- Prompt in natural user voice
- Expected operator step for live scenarios
- Desired user-visible outcome
- Feature-specific acceptance caveats or isolation constraints

---

## 7. SETUP AND DIAGNOSTICS

### MBD-001 | Doctor runs offline

#### Description

Confirm that the doctor reports local state without a network call or a credential value.

#### Scenario Contract

Prompt: `Run the Moneybird doctor offline and tell me whether it read or printed any credential.`

The report ends with the read-only line and shows only yes or no and set or unset values.

Desired user-visible outcome: A local diagnostic summary with no token, no administration ID and no network result.

#### Test Execution

> **Feature File:** [MBD-001](setup/doctor-offline.md)
> **Catalog:** [Local doctor](../feature-catalog/sessions-and-diagnostics/local-doctor.md)

### MBD-008 | Setup plan and pin check

#### Description

Confirm that the setup script prints its plan without installing and that the check reports the pin state.

#### Scenario Contract

Prompt: `Show me the Moneybird CLI install plan and the pin check without installing anything.`

The plan names the official repository and a detached checkout of the pinned commit. The temporary location stays absent. The check prints three yes or no lines.

Desired user-visible outcome: The operator sees the exact install and removal commands and the current pin state, with no change on disk.

#### Test Execution

> **Feature File:** [MBD-008](setup/setup-plan-and-check.md)
> **Catalog:** [Setup script](../feature-catalog/official-cli-and-setup/setup-script.md)

### MBD-011 | Login keeps tokens hidden

#### Description

Confirm that reader and writer login pass the token through stdin and never show it.

#### Scenario Contract

Prompt: `Log in the Moneybird reader and writer sessions from their credential files and prove the tokens never appear in the output.`

Both logins print only the completion line. The stub log shows one default login and one login under the temporary writer folder. Neither token appears in the output.

Desired user-visible outcome: The operator sees that login works from the files and that no token value reaches the screen.

#### Test Execution

> **Feature File:** [MBD-011](setup/login-keeps-tokens-hidden.md)
> **Catalog:** [Reader and writer login](../feature-catalog/sessions-and-diagnostics/reader-and-writer-login.md)

---

## 8. WRITE SAFETY

### MBD-002 | Unconfirmed write is blocked

#### Description

Confirm that a write without `--confirm-write` shows its preview and exits 3 before any real call.

#### Scenario Contract

Prompt: `Preview a Moneybird contact create in the pilot administration without confirming the write.`

The preview line shows `POST` and the pilot path. The guard exits 3. The stub log has no `REAL` line.

Desired user-visible outcome: The write is held until the operator approves the exact batch.

#### Test Execution

> **Feature File:** [MBD-002](write-safety/unconfirmed-write-blocked.md)
> **Catalog:** [Write confirmation lock](../feature-catalog/write-guard/write-confirmation-lock.md)

### MBD-003 | Production write is blocked

#### Description

Confirm that a confirmed write to an administration other than the pilot exits 4 without `--production`.

#### Scenario Contract

Prompt: `Try a confirmed Moneybird contact create in a non-pilot administration without production approval.`

The guard names both labels, asks for `--production` and exits 4. The stub log has no `REAL` line.

Desired user-visible outcome: The guard blocks the write before anything reaches a production administration.

#### Test Execution

> **Feature File:** [MBD-003](write-safety/production-write-blocked.md)
> **Catalog:** [Pilot administration gate](../feature-catalog/write-guard/pilot-administration-gate.md)

### MBD-004 | Delete needs a separate read

#### Description

Confirm that a successful guarded DELETE prints the 204 caution and that a separate read follows it.

#### Scenario Contract

Prompt: `Rehearse a pilot delete and then check the record with a separate read.`

The DELETE prints the 204 caution and the separate-read instruction. The stub log then shows a distinct `REAL GET` call.

Desired user-visible outcome: The operator sees that the write response alone does not prove removal and that a read follows.

#### Test Execution

> **Feature File:** [MBD-004](write-safety/delete-needs-separate-read.md)
> **Catalog:** [Delete caution](../feature-catalog/write-guard/delete-caution.md)

### MBD-009 | Pilot write is logged

#### Description

Confirm that a confirmed pilot write appends one body-free line to the write log.

#### Scenario Contract

Prompt: `Run a confirmed contact create in the pilot administration and show me the write log line it leaves.`

The guard reports the write and the cache note. The log line holds the method, path, administration, exit status, approval reference, batch key and payload digest, with no body field.

Desired user-visible outcome: The operator sees one log line per write and no record content in it.

#### Test Execution

> **Feature File:** [MBD-009](write-safety/pilot-write-is-logged.md)
> **Catalog:** [Write log](../feature-catalog/write-guard/write-log.md)

### MBD-012 | Pilot write and undo rehearsal

#### Description

Rehearse one live create and its undo in the pilot administration through the guard.

#### Scenario Contract

Prompt: `In the pilot administration only, create one throwaway test contact through the guard, delete it again and prove with a separate read that it is gone.`

The preview path contains the pilot administration. Each write carries `--approval` with its own fresh reference matching its own `WRITE_INTENT` entry the operator recorded. The create succeeds. The delete prints the 204 caution. The log ends with a POST line and a DELETE line. The later read finds no record.

Desired user-visible outcome: The operator has evidence that the pilot write path and its undo both work, with nothing left behind in the pilot administration.

#### Test Execution

> **Feature File:** [MBD-012](write-safety/pilot-write-and-undo-rehearsal.md)
> **Catalog:** [Pilot administration gate](../feature-catalog/write-guard/pilot-administration-gate.md)

### MBD-014 | Payload-bound approval

#### Description

Confirm that a write runs only for the approved payload digest, that a changed payload exits 9 and that a replayed reference and digest pair exits 8.

#### Scenario Contract

Prompt: `Approve one contact create by its payload digest, run it, then try a changed payload and the same reference again.`

The preview prints one `payload-digest:` line. The matching write exits 0 with one `REAL POST` line. The changed body exits 9 with `PAYLOAD_MISMATCH`, and the replay exits 8 as consumed, both without a real call.

Desired user-visible outcome: The operator sees that only the approved payload writes, exactly once.

#### Test Execution

> **Feature File:** [MBD-014](write-safety/payload-bound-approval.md)
> **Catalog:** [Payload-bound approval](../feature-catalog/write-guard/payload-bound-approval.md)

---

## 9. READS AND SAVED OUTPUT

### MBD-005 | Period filter warning

#### Description

Confirm that a list without a period warns and a list with an explicit period does not.

#### Scenario Contract

Prompt: `List Moneybird contacts without a period, then repeat with an explicit year filter.`

The first list warns about `period:this_year`. The second list runs without the warning. Both reads reach the stub.

Desired user-visible outcome: The agent uses an explicit period for verification reads.

#### Test Execution

> **Feature File:** [MBD-005](reads/period-filter-warning.md)
> **Catalog:** [Period filter warning](../feature-catalog/reads-and-saved-output/period-filter-warning.md)

### MBD-010 | Output guard confines saves

#### Description

Confirm that `--out` saves only inside the migration workspace and prints only the shape of the data.

#### Scenario Contract

Prompt: `Save a Moneybird contact list with the guard, once outside the migration workspace, once through a symlink and once inside it.`

The outside and symlinked paths exit 5 before any CLI call. The inside path prints only `items: 1` and the file holds the stub record.

Desired user-visible outcome: The operator sees that saved data can only land in the migration workspace.

#### Test Execution

> **Feature File:** [MBD-010](reads/output-guard-confines-saves.md)
> **Catalog:** [Output guard](../feature-catalog/reads-and-saved-output/output-guard.md)

---

## 10. ROUTING BOUNDARIES

### MBD-006 | Attachment goes to the CLI

#### Description

Confirm that an invoice attachment routes through the guarded CLI and requires write confirmation.

#### Scenario Contract

Prompt: `Which guarded CLI command attaches a PDF to an invoice in the pilot administration?`

The answer names a `moneybird-guard --confirm-write --approval "$APPROVAL_REF" ... attachment` command and identifies the pilot administration.

Desired user-visible outcome: The operator receives the guarded command pattern and knows that the write needs approval.

#### Test Execution

> **Feature File:** [MBD-006](routing/attachment-through-cli.md)
> **Catalog:** [Write confirmation lock](../feature-catalog/write-guard/write-confirmation-lock.md)

### MBD-007 | Bank file import goes to the UI

#### Description

Confirm that a CAMT.053 or MT940 import routes to the Moneybird UI.

#### Scenario Contract

Prompt: `Which Moneybird surface imports a CAMT.053 or MT940 file?`

The answer sends the operator to the Moneybird UI and describes `financial_statements` as a JSON mutation route.

Desired user-visible outcome: The operator gets the UI path and no upload command runs.

#### Test Execution

> **Feature File:** [MBD-007](routing/bank-file-import-goes-to-ui.md)
> **Catalog:** [Documented API traps](../feature-catalog/api-knowledge/documented-api-traps.md)

---

## 11. READ-ONLY LOCK

### MBD-013 | Read-only lock blocks writes

#### Description

Confirm that `MONEYBIRD_GUARD_READ_ONLY=1` blocks writes even when the write flags are present and still allows GET calls.

#### Scenario Contract

Prompt: `Check that a read-only Moneybird session can read contacts but cannot create one, even with the write flags.`

The contact list reaches the stub. The confirmed production create exits 6, prints the POST preview and has no `REAL` log line.

Desired user-visible outcome: The operator sees that the read-only session can read and that a write is blocked before the real CLI call.

#### Test Execution

> **Feature File:** [MBD-013](write-safety/read-only-lock.md)
> **Catalog:** [Read-only lock](../feature-catalog/write-guard/read-only-lock.md)

---

## 12. AUTOMATED TEST CROSS-REFERENCE

| Test Module | Coverage | Playbook Overlap |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../cli/moneybird-cli/tests/run-tests.sh) | Offline guard suite for the period warning, the confirmation lock, the pilot gate, the writer configuration gate, the approval gate, the payload digest binding, the single-use check, the attachment digest, the write log, the DELETE caution, the output guard, the summary output, the `--print-body` refusal under an agent marker, the `--out` refusal on a passthrough, the ignored environment overrides without the test flag, the `administration use` gate, both logins and one fault case per guard exit code 1 to 9 | MBD-002, MBD-003, MBD-004, MBD-005, MBD-009, MBD-010, MBD-011, MBD-013, MBD-014 |
| [`cli/moneybird-cli/tests/stub-moneybird-cli`](../cli/moneybird-cli/tests/stub-moneybird-cli) | Deterministic CLI stand-in that prints dry-run lines and logs real calls, with `MONEYBIRD_TEST_FAULT` for the upstream failure and the malformed dry-run line | Every offline guard scenario |

---

## 13. FEATURE CATALOG CROSS-REFERENCE INDEX

| Feature ID | Feature Name | Category | Feature File | Catalog Entry |
|---|---|---|---|---|
| MBD-001 | Doctor runs offline | Setup and diagnostics | [MBD-001](setup/doctor-offline.md) | [Local doctor](../feature-catalog/sessions-and-diagnostics/local-doctor.md) |
| MBD-002 | Unconfirmed write is blocked | Write safety | [MBD-002](write-safety/unconfirmed-write-blocked.md) | [Write confirmation lock](../feature-catalog/write-guard/write-confirmation-lock.md) and [Dry-run first pass](../feature-catalog/write-guard/dry-run-first-pass.md) |
| MBD-003 | Production write is blocked | Write safety | [MBD-003](write-safety/production-write-blocked.md) | [Pilot administration gate](../feature-catalog/write-guard/pilot-administration-gate.md) |
| MBD-004 | Delete needs a separate read | Write safety | [MBD-004](write-safety/delete-needs-separate-read.md) | [Delete caution](../feature-catalog/write-guard/delete-caution.md) |
| MBD-005 | Period filter warning | Reads and saved output | [MBD-005](reads/period-filter-warning.md) | [Period filter warning](../feature-catalog/reads-and-saved-output/period-filter-warning.md) and [Documented API traps](../feature-catalog/api-knowledge/documented-api-traps.md) |
| MBD-006 | Attachment routes through the CLI | Routing boundaries | [MBD-006](routing/attachment-through-cli.md) | [Write confirmation lock](../feature-catalog/write-guard/write-confirmation-lock.md) |
| MBD-007 | Bank file import goes to the UI | Routing boundaries | [MBD-007](routing/bank-file-import-goes-to-ui.md) | [Documented API traps](../feature-catalog/api-knowledge/documented-api-traps.md) |
| MBD-008 | Setup plan and pin check | Setup and diagnostics | [MBD-008](setup/setup-plan-and-check.md) | [Setup script](../feature-catalog/official-cli-and-setup/setup-script.md) and [Official CLI at a pinned commit](../feature-catalog/official-cli-and-setup/official-cli-pinned-commit.md) |
| MBD-009 | Pilot write is logged | Write safety | [MBD-009](write-safety/pilot-write-is-logged.md) | [Write log](../feature-catalog/write-guard/write-log.md) |
| MBD-010 | Output guard confines saves | Reads and saved output | [MBD-010](reads/output-guard-confines-saves.md) | [Output guard](../feature-catalog/reads-and-saved-output/output-guard.md) |
| MBD-011 | Login keeps tokens hidden | Setup and diagnostics | [MBD-011](setup/login-keeps-tokens-hidden.md) | [Reader and writer login](../feature-catalog/sessions-and-diagnostics/reader-and-writer-login.md) |
| MBD-012 | Pilot write and undo rehearsal | Write safety | [MBD-012](write-safety/pilot-write-and-undo-rehearsal.md) | [Pilot administration gate](../feature-catalog/write-guard/pilot-administration-gate.md) and [Write log](../feature-catalog/write-guard/write-log.md) and [Delete caution](../feature-catalog/write-guard/delete-caution.md) |
| MBD-013 | Read-only lock blocks writes | Write safety | [MBD-013](write-safety/read-only-lock.md) | [Read-only lock](../feature-catalog/write-guard/read-only-lock.md) |
| MBD-014 | Payload-bound approval | Write safety | [MBD-014](write-safety/payload-bound-approval.md) | [Payload-bound approval](../feature-catalog/write-guard/payload-bound-approval.md) |
