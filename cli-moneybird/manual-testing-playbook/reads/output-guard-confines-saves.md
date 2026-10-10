---
title: "MBD-010 -- Output guard confines saves"
description: "This scenario validates Output guard confines saves for `MBD-010`. It focuses on the need to confirm that --out saves only inside the migration workspace and prints only the shape of the data."
version: 1.0.0.0
---

# MBD-010 -- Output guard confines saves

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-010`.

---

## 1. OVERVIEW

This scenario validates Output guard confines saves for `MBD-010`. It focuses on the need to confirm that `--out` saves only inside the migration workspace and prints only the shape of the data.

### Why This Matters

Saved Moneybird data must stay in the ignored migration workspace and out of chat output.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-010` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that `--out` saves only inside the migration workspace and prints only the shape of the data.
- Real user request: `Save the contact list to a file so I can review it later.`
- Prompt: `Save a Moneybird contact list with the guard, once outside the migration workspace, once through a symlink and once inside it.`
- Expected execution process: The agent tries an outside path, a symlinked path and an inside path against the stub and checks the stub log and the saved file.
- Expected signals: The outside and symlinked paths exit 5 before any CLI call. The inside path prints only `items: 1` and the file holds the stub record.
- Desired user-visible outcome: The operator sees that saved data can only land in the migration workspace.
- Pass/fail: PASS if both refused paths exit 5 with no `REAL` line and the inside path prints `items: 1` and writes the file. FAIL if a file is written outside the workspace or records are printed to the terminal.
- Feature catalog: [Output guard](../../feature-catalog/reads-and-saved-output/output-guard.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Decide whether the scenario stays local or needs the operator for a live step.
3. Execute the deterministic steps exactly as written.
4. Compare the observed output against the desired user-visible outcome.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-010 | Output guard confines saves | Confirm that `--out` saves only inside the migration workspace and prints only the shape of the data | `Save a Moneybird contact list with the guard, once outside the migration workspace, once through a symlink and once inside it.` | 1. `moneybird-guard --out "$TEST_ROOT/outside.json" contacts list` -> 2. `moneybird-guard --out migration-workspace/link/x.json contacts list` -> 3. `moneybird-guard --out migration-workspace/contacts.json contacts list --filter period:2023` -> 4. `bash: jq length contacts.json` | Step 1: exit 5 and no `REAL` line. Step 2: exit 5. Step 3: stdout is `items: 1`. Step 4: `1` | Captured output, exit statuses and the stub invocation log | PASS if both refused paths exit 5 with no `REAL` line and the inside path prints `items: 1` and writes the file. FAIL if a file is written outside the workspace or records are printed to the terminal. | 1. Confirm the inside path resolves under `migration-workspace/`. 2. Read the path validation in `moneybird-guard`. 3. Run the automated suite and compare the two `--out` cases |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`.

```bash
bash <<'SCENARIO'
SKILL_ROOT="$PWD"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cli-moneybird.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/accountant/migration-workspace"
export HOME="$TEST_ROOT/home" MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$SKILL_ROOT/cli/moneybird-cli/tests/stub-moneybird-cli"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log" MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
"$GUARD" --out "$TEST_ROOT/outside.json" contacts list
echo "outside exit=$?"
grep -c '^REAL ' "$MONEYBIRD_TEST_LOG"
ln -s "$TEST_ROOT" "$MONEYBIRD_ENV_DIR/migration-workspace/link"
"$GUARD" --out "migration-workspace/link/x.json" contacts list
echo "symlink exit=$?"
"$GUARD" --out "migration-workspace/contacts.json" contacts list --filter period:2023
echo "inside exit=$?"
jq length "$MONEYBIRD_ENV_DIR/migration-workspace/contacts.json"
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/reads-and-saved-output/output-guard.md`](../../feature-catalog/reads-and-saved-output/output-guard.md) | Feature-catalog entry for Output guard |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Output path validation |
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated --out cases |

---

## 5. SOURCE METADATA

- Group: Reads and saved output
- Playbook ID: MBD-010
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `reads/output-guard-confines-saves.md`
