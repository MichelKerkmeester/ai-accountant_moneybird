---
title: "MBD-004 -- Delete needs a separate read"
description: "This scenario validates Delete needs a separate read for `MBD-004`. It focuses on the need to confirm that a successful guarded DELETE prints the 204 caution and that a separate read follows it."
version: 1.0.0.0
---

# MBD-004 -- Delete needs a separate read

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-004`.

---

## 1. OVERVIEW

This scenario validates Delete needs a separate read for `MBD-004`. It focuses on the need to confirm that a successful guarded DELETE prints the 204 caution and that a separate read follows it.

### Why This Matters

Some Moneybird DELETE endpoints answer 204 when nothing was removed. The status alone is not proof.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-004` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a successful guarded DELETE prints the 204 caution and that a separate read follows it.
- Real user request: `Rehearse the correction path in the pilot administration.`
- Prompt: `Rehearse a pilot delete and then check the record with a separate read.`
- Expected execution process: The agent runs a confirmed DELETE against the stub with the pilot label `PILOT_ADMIN`, then a separate GET for the same record.
- Expected signals: The DELETE prints the 204 caution and the separate-read instruction. The stub log then shows a distinct `REAL GET` call.
- Desired user-visible outcome: The operator sees that the write response alone does not prove removal and that a read follows.
- Pass/fail: PASS if the caution appears after the DELETE and a separate `REAL GET` follows in the stub log. FAIL if the DELETE is reported as confirmed without a read.
- Feature catalog: [Delete caution](../../feature-catalog/write-guard/delete-caution.md)

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
| MBD-004 | Delete needs a separate read | Confirm that a successful guarded DELETE prints the 204 caution and that a separate read follows it | `Rehearse a pilot delete and then check the record with a separate read.` | 1. `bash: write PILOT_ADMIN to temporary .env` -> 2. `moneybird-guard --confirm-write contacts delete stub-record` -> 3. `moneybird-guard contacts get stub-record` -> 4. `bash: cat invocations.log` | Step 1: the temporary `.env` holds the pilot label. Step 2: `A DELETE response of 204 can mean nothing was deleted.` Step 3: a GET runs. Step 4: `REAL DELETE` then `REAL GET` | Captured guard output and the stub invocation log | PASS if the caution appears after the DELETE and a separate `REAL GET` follows in the stub log. FAIL if the DELETE is reported as confirmed without a read. | 1. Confirm the DELETE carried `--confirm-write` and targeted the pilot label. 2. Read the DELETE caution in `moneybird-guard`. 3. Compare with the correction recipe in `references/migration-recipes.md` |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`. The delete targets the pilot label only.

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
"$GUARD" --confirm-write contacts delete stub-record
echo "delete exit=$?"
"$GUARD" contacts get stub-record
echo "read exit=$?"
cat "$MONEYBIRD_TEST_LOG"
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/write-guard/delete-caution.md`](../../feature-catalog/write-guard/delete-caution.md) | Feature-catalog entry for Delete caution |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | DELETE caution |
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Correction recipe |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-004
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `write-safety/delete-needs-separate-read.md`
