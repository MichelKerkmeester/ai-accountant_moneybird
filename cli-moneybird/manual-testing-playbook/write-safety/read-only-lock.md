---
title: "MBD-013 -- Read-only lock blocks writes"
description: "This scenario validates that MONEYBIRD_GUARD_READ_ONLY=1 allows GET calls and blocks non-GET methods even with write flags."
id: MBD-013
catalog_applicable: true
version: 1.0.0.0
---

# MBD-013 -- Read-only lock blocks writes

This document captures the user-testing contract, current behavior, execution flow, source anchors and metadata for MBD-013.

---

## 1. OVERVIEW

This scenario validates that the read-only lock lets a GET through and blocks a confirmed production write before a real call.

### Why This Matters

Moneybird tokens do not separate read and write scopes. The local lock gives read-only roles a clear boundary for CLI calls.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for MBD-013 and confirm the expected signals without contradictory evidence.

- Objective: Confirm that MONEYBIRD_GUARD_READ_ONLY=1 allows GET and blocks a non-GET method even with the write flags.
- Real user request: Check that a read-only Moneybird session can read contacts but cannot create one, even with the write flags.
- Prompt: Check that a read-only Moneybird session can read contacts but cannot create one, even with the write flags.
- Expected execution process: Set the lock in a temporary scenario environment, run a GET against the packaged stub, then run a confirmed production create against the stub.
- Expected signals: The GET exits 0 and has a REAL GET log line. The create exits 6, prints its POST dry-run line and lock message, and has no REAL POST log line.
- Desired user-visible outcome: The operator sees that the read-only CLI can read and that a write is blocked before the real call.
- Pass/fail: PASS if the GET runs and the write exits 6 without a real call. FAIL if the GET is blocked or a real write is logged.
- Feature catalog: [Read-only lock](../../feature-catalog/write-guard/read-only-lock.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Set the read-only lock in the temporary environment.
2. Run the GET and confirmed production write against the packaged stub.
3. Check the exit codes and invocation log.
4. Return a concise result with the captured evidence.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-013 | Read-only lock blocks writes | Confirm that the lock permits GET and refuses a confirmed production write | Check that a read-only Moneybird session can read contacts but cannot create one, even with the write flags. | 1. Set MONEYBIRD_GUARD_READ_ONLY=1 and run moneybird-guard contacts list --filter period:2023 -> 2. Run moneybird-guard --confirm-write --production --approval "$APPROVAL_REF" contacts create -> 3. Check exit status 6 and inspect the invocation log | The GET exits 0 and logs REAL GET. The write exits 6 with a POST preview and lock message, with no REAL POST log line. | Record both exit statuses, guard output and the stub invocation log. | PASS if GET succeeds and the write exits 6 without a real POST. FAIL if the GET is blocked or the stub records a real POST. | Confirm the lock is exactly 1, inspect the non-GET lock branch, then rerun the automated guard suite. |

### Prompt

Check that a read-only Moneybird session can read contacts but cannot create one, even with the write flags.

### Exact Command Sequence

1. Run the block below from the cli-moneybird package root.
2. Confirm the GET returns 0 and the production create returns 6.
3. Confirm the log has a REAL GET line and no REAL POST line.

### Evidence

Capture the prompt, the two exit statuses, the POST preview and lock message, and the stub invocation log.

### Pass / Fail

- Pass: The GET runs and the confirmed production write exits 6 before a real POST.
- Fail: The GET is blocked, the write does not exit 6 or the stub records a real POST.

### Failure Triage

Confirm MONEYBIRD_GUARD_READ_ONLY is set to exactly 1. Check the guard lock branch and the test stub log. Rerun the offline guard tests.

### Command Block

Run from the cli-moneybird package root. It uses only the packaged stub and a temporary folder. `MONEYBIRD_GUARD_TEST=1` is a test-only setting for the offline test suite. Never set it in a real session.

```bash
set -euo pipefail
SKILL_ROOT="$PWD"
TEST_ROOT="$(mktemp -d "/tmp/moneybird-read-only.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/writer-config" "$TEST_ROOT/accountant/migration-workspace/RunJournal"
export HOME="$TEST_ROOT/home" MONEYBIRD_GUARD_TEST=1 MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$SKILL_ROOT/cli/moneybird-cli/tests/stub-moneybird-cli"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log" MONEYBIRD_TEST_ADMINISTRATION_ID="PRODUCTION_ADMIN"
export MONEYBIRD_GUARD_READ_ONLY=1
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
"$GUARD" contacts list --filter period:2023
APPROVAL_REF="APR-EXAMPLE"
printf '{"new_state":"WRITE_INTENT","approval_reference":"%s"}\n' "$APPROVAL_REF" > "$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal/run-journal.jsonl"
if "$GUARD" --confirm-write --production --approval "$APPROVAL_REF" contacts create; then
  printf '%s
' 'unexpected write success' >&2
  exit 1
else
  status="$?"
  [[ "$status" -eq 6 ]]
fi
grep -q '^REAL GET ' "$MONEYBIRD_TEST_LOG"
! grep -q '^REAL POST ' "$MONEYBIRD_TEST_LOG"
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog/write-guard/read-only-lock.md](../../feature-catalog/write-guard/read-only-lock.md) | Feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [moneybird-guard](../../cli/moneybird-cli/moneybird-guard) | Implements the environment lock |
| [run-tests.sh](../../cli/moneybird-cli/tests/run-tests.sh) | Automated lock checks |
| [references/cli.md](../../references/cli.md) | Documents the lock and exit code |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-013
- Canonical root source: manual-testing-playbook.md
- Feature file path: write-safety/read-only-lock.md
