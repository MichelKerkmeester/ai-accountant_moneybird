---
title: "MBD-003 -- Production write is blocked"
description: "This scenario validates Production write is blocked for `MBD-003`. It focuses on the need to confirm that a confirmed write to an administration other than the pilot exits 4 without --production."
version: 1.0.0.0
---

# MBD-003 -- Production write is blocked

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-003`.

---

## 1. OVERVIEW

This scenario validates Production write is blocked for `MBD-003`. It focuses on the need to confirm that a confirmed write to an administration other than the pilot exits 4 without `--production`.

### Why This Matters

A confirmation cannot move a record into a different administration. The production flag is a separate decision per approved batch.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-003` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a confirmed write to an administration other than the pilot exits 4 without `--production`.
- Real user request: `Write the approved test record to another administration.`
- Prompt: `Try a confirmed Moneybird contact create in a non-pilot administration without production approval.`
- Expected execution process: The agent sets the pilot label `PILOT_ADMIN` in a temporary `.env`, points the stub at `OTHER_ADMIN` and runs a confirmed create.
- Expected signals: The guard names both labels, asks for `--production` and exits 4. The stub log has no `REAL` line.
- Desired user-visible outcome: The guard blocks the write before anything reaches a production administration.
- Pass/fail: PASS if the guard exits 4 with the pilot mismatch message and the stub log holds no `REAL` line. FAIL if the write runs or the exit status differs.
- Feature catalog: [Pilot administration gate](../../feature-catalog/write-guard/pilot-administration-gate.md)

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
| MBD-003 | Production write is blocked | Confirm that a confirmed write to an administration other than the pilot exits 4 without `--production` | `Try a confirmed Moneybird contact create in a non-pilot administration without production approval.` | 1. `bash: write PILOT_ADMIN to temporary .env` -> 2. `moneybird-guard --confirm-write contacts create` -> 3. `bash: count the REAL lines in invocations.log` | Step 1: the temporary `.env` holds the pilot label. Step 2: `Pilot administration 'PILOT_ADMIN' differs from target 'OTHER_ADMIN'` and exit 4. Step 3: `0` | Captured guard output, exit status and the stub invocation log | PASS if the guard exits 4 with the pilot mismatch message and the stub log holds no `REAL` line. FAIL if the write runs or the exit status differs. | 1. Confirm the temporary `.env` holds `MONEYBIRD_PILOT_ADMINISTRATION_ID`. 2. Confirm no `--production` flag was passed. 3. Read the pilot gate in `moneybird-guard` |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`. `MONEYBIRD_GUARD_TEST=1` is a test-only setting. It lets the guard honor the scratch root, the stub CLI and the temporary writer configuration folder. Never set it in a real session. The final count prints 0 when no real call ran and the stub log was never created.

```bash
bash <<'SCENARIO'
SKILL_ROOT="$PWD"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cli-moneybird.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/accountant/migration-workspace" "$TEST_ROOT/writer"
export HOME="$TEST_ROOT/home" MONEYBIRD_GUARD_TEST=1 MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$SKILL_ROOT/cli/moneybird-cli/tests/stub-moneybird-cli"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer"
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log" MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
export MONEYBIRD_TEST_ADMINISTRATION_ID="OTHER_ADMIN"
"$GUARD" --confirm-write contacts create
echo "exit=$?"
if [[ -f "$MONEYBIRD_TEST_LOG" ]]; then
  grep -c '^REAL ' "$MONEYBIRD_TEST_LOG" || true
else
  echo 0
fi
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/write-guard/pilot-administration-gate.md`](../../feature-catalog/write-guard/pilot-administration-gate.md) | Feature-catalog entry for Pilot administration gate |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Pilot gate |
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated exit 4 case |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-003
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `write-safety/production-write-blocked.md`
