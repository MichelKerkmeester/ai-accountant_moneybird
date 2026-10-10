---
title: "MBD-009 -- Pilot write is logged"
description: "This scenario validates Pilot write is logged for `MBD-009`. It focuses on the need to confirm that a confirmed pilot write appends one body-free line to the write log."
version: 1.0.0.0
---

# MBD-009 -- Pilot write is logged

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-009`.

---

## 1. OVERVIEW

This scenario validates Pilot write is logged for `MBD-009`. It focuses on the need to confirm that a confirmed pilot write appends one body-free line to the write log.

### Why This Matters

The write log is the local journal of what was attempted. It must record every write without copying financial content.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-009` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a confirmed pilot write appends one body-free line to the write log.
- Real user request: `Make the approved pilot write and show me what was recorded locally.`
- Prompt: `Run a confirmed contact create in the pilot administration and show me the write log line it leaves.`
- Expected execution process: The agent sets the pilot label `PILOT_ADMIN`, runs a confirmed create against the stub and reads the last log line with `jq`.
- Expected signals: The guard reports the write and the cache note. The log line holds the method, path, administration, exit status and time, with no body field.
- Desired user-visible outcome: The operator sees one log line per write and no record content in it.
- Pass/fail: PASS if the guard exits 0, the log line shows `POST`, `PILOT_ADMIN` and exit status 0 and `jq` finds no `body` key. FAIL if no line is written or the line carries a request or response body.
- Feature catalog: [Write log](../../feature-catalog/write-guard/write-log.md)

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
| MBD-009 | Pilot write is logged | Confirm that a confirmed pilot write appends one body-free line to the write log | `Run a confirmed contact create in the pilot administration and show me the write log line it leaves.` | 1. `bash: write PILOT_ADMIN to temporary .env` -> 2. `moneybird-guard --confirm-write contacts create` -> 3. `bash: jq . moneybird-writes.jsonl` -> 4. `bash: jq -e "has(\"body\") | not"` | Step 1: the temporary `.env` holds the pilot label. Step 2: `Moneybird write succeeded: POST` and the cached GET note. Step 3: one JSON line. Step 4: `true` | Captured guard output and the single log line | PASS if the guard exits 0, the log line shows `POST`, `PILOT_ADMIN` and exit status 0 and `jq` finds no `body` key. FAIL if no line is written or the line carries a request or response body. | 1. Confirm `jq` is installed. 2. Confirm the write passed the pilot gate. 3. Read the log block at the end of `moneybird-guard` |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`. The write targets the pilot label only and goes to the stub, not to Moneybird.

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
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
"$GUARD" --confirm-write contacts create
echo "exit=$?"
LOG="$MONEYBIRD_ENV_DIR/migration-workspace/logs/moneybird-writes.jsonl"
jq . "$LOG"
jq -e 'has("body") | not' "$LOG"
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/write-guard/write-log.md`](../../feature-catalog/write-guard/write-log.md) | Feature-catalog entry for Write log |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Write log |
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated body-free log case |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-009
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `write-safety/pilot-write-is-logged.md`
