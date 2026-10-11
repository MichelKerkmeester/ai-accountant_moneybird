---
title: "MBD-005 -- Period filter warning"
description: "This scenario validates Period filter warning for `MBD-005`. It focuses on the need to confirm that a list without a period warns and a list with an explicit period does not."
version: 1.0.0.0
---

# MBD-005 -- Period filter warning

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-005`.

---

## 1. OVERVIEW

This scenario validates Period filter warning for `MBD-005`. It focuses on the need to confirm that a list without a period warns and a list with an explicit period does not.

### Why This Matters

Moneybird lists default to `period:this_year`. A successful list can omit every older year unless the caller sets a period.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-005` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that a list without a period warns and a list with an explicit period does not.
- Real user request: `Read a year of Moneybird records.`
- Prompt: `List Moneybird contacts without a period, then repeat with an explicit year filter.`
- Expected execution process: The agent runs the same list twice against the stub, once without a filter and once with `--filter period:2023`.
- Expected signals: The first list warns about `period:this_year`. The second list runs without the warning. Both reads reach the stub.
- Desired user-visible outcome: The agent uses an explicit period for verification reads.
- Pass/fail: PASS if only the unfiltered list warns and the stub log shows two `REAL GET` lines. FAIL if the warning is missing or stays with the explicit period.
- Feature catalog: [Period filter warning](../../feature-catalog/reads-and-saved-output/period-filter-warning.md)

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
| MBD-005 | Period filter warning | Confirm that a list without a period warns and a list with an explicit period does not | `List Moneybird contacts without a period, then repeat with an explicit year filter.` | 1. `moneybird-guard contacts list` -> 2. `moneybird-guard contacts list --filter period:2023` -> 3. `bash: grep -c "^REAL GET" invocations.log` | Step 1: `Warning: Moneybird lists default to period:this_year.` Step 2: no warning. Step 3: `2` | Captured output of both reads and the stub invocation log | PASS if only the unfiltered list warns and the stub log shows two `REAL GET` lines. FAIL if the warning is missing or stays with the explicit period. | 1. Confirm the second command carried `--filter period:2023`. 2. Read the period check in `moneybird-guard`. 3. Compare with the default period trap in `references/rest-api.md` |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`. The block sets `MONEYBIRD_GUARD_TEST=1`, a test-only setting for the offline test suite. Never set it in a real session.

```bash
bash <<'SCENARIO'
SKILL_ROOT="$PWD"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cli-moneybird.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/accountant/migration-workspace"
export HOME="$TEST_ROOT/home" MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_GUARD_TEST=1
export MONEYBIRD_CLI="$SKILL_ROOT/cli/moneybird-cli/tests/stub-moneybird-cli"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log" MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
"$GUARD" contacts list
"$GUARD" contacts list --filter period:2023
grep -c '^REAL GET' "$MONEYBIRD_TEST_LOG"
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/reads-and-saved-output/period-filter-warning.md`](../../feature-catalog/reads-and-saved-output/period-filter-warning.md) | Feature-catalog entry for Period filter warning |
| [`feature-catalog/api-knowledge/documented-api-traps.md`](../../feature-catalog/api-knowledge/documented-api-traps.md) | Feature-catalog entry for Documented API traps |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Period check |
| [`references/rest-api.md`](../../references/rest-api.md) | Default period trap |

---

## 5. SOURCE METADATA

- Group: Reads and saved output
- Playbook ID: MBD-005
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `reads/period-filter-warning.md`
