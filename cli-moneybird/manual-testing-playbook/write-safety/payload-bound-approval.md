---
title: "MBD-014 -- Payload-bound approval"
description: "This scenario validates that a write runs only for the approved payload digest, that a changed payload exits 9 and that a replayed reference and digest pair exits 8."
id: MBD-014
catalog_applicable: true
version: 1.0.0.0
---

# MBD-014 -- Payload-bound approval

This document captures the user-testing contract, current behavior, execution flow, source anchors and metadata for MBD-014.

---

## 1. OVERVIEW

This scenario validates that a confirmed write runs only for the payload digest the Operator approved, that a changed payload is refused with exit 9 and that the same reference and digest pair runs once.

### Why This Matters

An approval reference alone can be replayed and does not say what was approved. Binding the approval to the payload digest makes the write run for the exact approved payload only, and the write log then joins the write back to its approval.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for MBD-014 and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a matching payload writes once, a changed payload exits 9 and a replayed pair exits 8.
- Real user request: Approve one contact create by its payload digest, run it, then try a changed payload and the same reference again.
- Prompt: Approve one contact create by its payload digest, run it, then try a changed payload and the same reference again.
- Expected execution process: Set a temporary environment with a generated key, run the preview to capture the digest, record it in the `WRITE_INTENT`, run the confirmed write, then repeat with a changed body and with the same reference.
- Expected signals: The preview prints one `payload-digest:` line and exits 3. The matching write exits 0 with one `REAL POST` line. The changed body exits 9 with `PAYLOAD_MISMATCH` and no real call. The replay exits 8 with a consumed message and no real call.
- Desired user-visible outcome: The operator sees that only the approved payload writes, exactly once.
- Pass/fail: PASS if the matching write exits 0 and both the changed payload and the replay are refused before a real call. FAIL if a changed payload writes or a consumed pair runs again.
- Feature catalog: [Payload-bound approval](../../feature-catalog/write-guard/payload-bound-approval.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Generate a temporary key and record the preview digest in the run journal.
2. Run the matching write, the changed-payload write and the replay against the packaged stub.
3. Check the exit statuses, the guard output and the stub invocation log.
4. Return a concise result with the captured evidence.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-014 | Payload-bound approval | Confirm that a matching payload writes once, a changed payload exits 9 and a replayed pair exits 8 | Approve one contact create by its payload digest, run it, then try a changed payload and the same reference again. | 1. Run the block below from the cli-moneybird package root -> 2. Check the three exit statuses 0, 9 and 8 -> 3. Check the stub invocation log for one REAL POST only | Step 1: the preview prints one `payload-digest:` line and exits 3. Step 2: the matching write exits 0, the changed body exits 9 with `PAYLOAD_MISMATCH`, the replay exits 8 with a consumed message. Step 3: the log holds one REAL POST from the matching write | Captured guard output, the three exit statuses and the stub invocation log | PASS if the matching write exits 0 and both refusals happen before a real call. FAIL if a changed payload writes or a consumed pair runs again. | 1. Confirm the key file exists at `migration-workspace/.secrets/alias-hmac.key`. 2. Confirm the journal entry carries the digest from the preview. 3. Rerun the offline guard suite |

### Prompt

Approve one contact create by its payload digest, run it, then try a changed payload and the same reference again.

### Exact Command Sequence

1. Run the block below from the cli-moneybird package root.
2. Confirm the preview exits 3 with one `payload-digest:` line.
3. Confirm the matching write exits 0, the changed body exits 9 and the replay exits 8.

### Evidence

Capture the prompt, the preview digest line, the three exit statuses, the refusal messages and the stub invocation log.

### Pass / Fail

- Pass: The matching write exits 0 with one real call, and the changed payload and the replay are both refused with no real call.
- Fail: A changed payload writes, or the same reference and digest pair runs twice.

### Failure Triage

Confirm the key file is present and readable, and that the `WRITE_INTENT` entry carries the `payload_digest` the preview printed. Check the digest and single-use branches in the guard, then rerun the offline guard tests.

### Command Block

Run from the cli-moneybird package root. It uses only the packaged stub and a temporary folder. `MONEYBIRD_GUARD_TEST=1` is a test-only setting for the offline test suite. Never set it in a real session. The key is generated inside the temporary folder and removed with it.

```bash
set -euo pipefail
SKILL_ROOT="$PWD"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/moneybird-payload-binding.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/writer-config" "$TEST_ROOT/accountant/migration-workspace/RunJournal" "$TEST_ROOT/accountant/migration-workspace/.secrets"
export HOME="$TEST_ROOT/home" MONEYBIRD_GUARD_TEST=1 MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$SKILL_ROOT/cli/moneybird-cli/tests/stub-moneybird-cli"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log" MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
KEY_FILE="$MONEYBIRD_ENV_DIR/migration-workspace/.secrets/alias-hmac.key"
python3 -I -c 'import secrets; print(secrets.token_hex(32), end="")' > "$KEY_FILE"
APPROVAL_REF="APR-EXAMPLE"
PREVIEW="$("$GUARD" contacts create 2>&1 || true)"
PAYLOAD_DIGEST="$(printf '%s\n' "$PREVIEW" | sed -n 's/^payload-digest: //p')"
[[ -n "$PAYLOAD_DIGEST" ]]
printf '{"new_state":"WRITE_INTENT","approval_reference":"%s","payload_digest":"%s","batch_key":"batch-pilot"}\n' "$APPROVAL_REF" "$PAYLOAD_DIGEST" > "$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal/run-journal.jsonl"
"$GUARD" --confirm-write --approval "$APPROVAL_REF" contacts create
grep -q '^REAL POST ' "$MONEYBIRD_TEST_LOG"
: > "$MONEYBIRD_TEST_LOG"
if MONEYBIRD_TEST_DRY_BODY='{"contacts":{"company_name":"changed"}}' "$GUARD" --confirm-write --approval "$APPROVAL_REF" contacts create 2>"$TEST_ROOT/changed.txt"; then
  printf '%s\n' 'unexpected write success' >&2
  exit 1
else
  status="$?"
  [[ "$status" -eq 9 ]]
fi
grep -q 'PAYLOAD_MISMATCH' "$TEST_ROOT/changed.txt"
! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"
if "$GUARD" --confirm-write --approval "$APPROVAL_REF" contacts create 2>"$TEST_ROOT/replay.txt"; then
  printf '%s\n' 'unexpected replay success' >&2
  exit 1
else
  status="$?"
  [[ "$status" -eq 8 ]]
fi
grep -q 'already consumed' "$TEST_ROOT/replay.txt"
! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog/write-guard/payload-bound-approval.md](../../feature-catalog/write-guard/payload-bound-approval.md) | Feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [moneybird-guard](../../cli/moneybird-cli/moneybird-guard) | Computes the digests and refuses a changed payload or a consumed pair |
| [run-tests.sh](../../cli/moneybird-cli/tests/run-tests.sh) | Automated digest, replay and attachment checks |
| [references/cli.md](../../references/cli.md) | Documents exit 9 and the digest rule |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-014
- Canonical root source: manual-testing-playbook.md
- Feature file path: write-safety/payload-bound-approval.md
