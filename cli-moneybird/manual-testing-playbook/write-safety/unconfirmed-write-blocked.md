---
title: "MBD-002 -- Unconfirmed write is blocked"
description: "This scenario validates Unconfirmed write is blocked for `MBD-002`. It focuses on the need to confirm that a write without --confirm-write shows its preview and exits 3 before any real call."
version: 1.0.0.0
---

# MBD-002 -- Unconfirmed write is blocked

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-002`.

---

## 1. OVERVIEW

This scenario validates Unconfirmed write is blocked for `MBD-002`. It focuses on the need to confirm that a write without `--confirm-write` shows its preview and exits 3 before any real call.

### Why This Matters

Every write must be a deliberate second step. The first run only shows the method, path and administration the write would use.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-002` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a write without `--confirm-write` shows its preview and exits 3 before any real call.
- Real user request: `Create a contact in the pilot administration.`
- Prompt: `Preview a Moneybird contact create in the pilot administration without confirming the write.`
- Expected execution process: The agent generates a temporary key and runs the create through the guard without `--confirm-write`, against the stub and the pilot label `PILOT_ADMIN`.
- Expected signals: The preview line shows `POST` and the pilot path, with one `payload-digest:` line. The guard exits 3. The stub log has no `REAL` line.
- Desired user-visible outcome: The write is held until the operator approves the exact batch.
- Pass/fail: PASS if the guard exits 3, prints the `POST` preview and the stub log holds no `REAL` line. FAIL if a real call is logged or the exit status differs.
- Feature catalog: [Write confirmation lock](../../feature-catalog/write-guard/write-confirmation-lock.md)

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
| MBD-002 | Unconfirmed write is blocked | Confirm that a write without `--confirm-write` shows its preview and exits 3 before any real call | `Preview a Moneybird contact create in the pilot administration without confirming the write.` | 1. `bash: generate the temporary key` -> 2. `moneybird-guard contacts create` -> 3. `bash: grep -c "^REAL " invocations.log` | Step 1: the key is generated in the temporary folder. Step 2: `POST https://moneybird.com/api/v2/PILOT_ADMIN/contacts.json`, one `payload-digest:` line, `Write blocked.` and exit 3. Step 3: `0` | Captured guard output, exit status and the stub invocation log | PASS if the guard exits 3, prints the `POST` preview and the stub log holds no `REAL` line. FAIL if a real call is logged or the exit status differs. | 1. Confirm the command carried no `--confirm-write`. 2. Read the confirmation branch in `moneybird-guard`. 3. Run the automated suite and compare the exit 3 case |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`. `MONEYBIRD_GUARD_TEST=1` is a test-only setting for the offline test suite. Never set it in a real session. The key is generated inside the temporary folder and removed with it.

```bash
bash <<'SCENARIO'
set -euo pipefail
SKILL_ROOT="$PWD"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cli-moneybird.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/writer-config" "$TEST_ROOT/accountant/migration-workspace/RunJournal"
export HOME="$TEST_ROOT/home" MONEYBIRD_GUARD_TEST=1 MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$SKILL_ROOT/cli/moneybird-cli/tests/stub-moneybird-cli"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log" MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
KEY_FILE="$TEST_ROOT/alias-hmac.key"
python3 -I -c 'import secrets; print(secrets.token_hex(32), end="")' > "$KEY_FILE"
export MONEYBIRD_HMAC_KEY_FILE="$KEY_FILE"
: > "$MONEYBIRD_TEST_LOG"
APPROVAL_REF="APR-EXAMPLE"
printf '{"new_state":"WRITE_INTENT","approval_reference":"%s"}\n' "$APPROVAL_REF" > "$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal/run-journal.jsonl"
if "$GUARD" contacts create; then
  printf '%s\n' 'unexpected write success' >&2
  exit 1
else
  status="$?"
fi
printf 'exit=%s\n' "$status"
[[ "$status" -eq 3 ]]
grep -c '^REAL ' "$MONEYBIRD_TEST_LOG" || true
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/write-guard/write-confirmation-lock.md`](../../feature-catalog/write-guard/write-confirmation-lock.md) | Feature-catalog entry for Write confirmation lock |
| [`feature-catalog/write-guard/dry-run-first-pass.md`](../../feature-catalog/write-guard/dry-run-first-pass.md) | Feature-catalog entry for Dry-run first pass |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Confirmation lock |
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated exit 3 case |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-002
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `write-safety/unconfirmed-write-blocked.md`
