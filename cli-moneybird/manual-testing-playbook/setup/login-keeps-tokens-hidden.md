---
title: "MBD-011 -- Login keeps tokens hidden"
description: "This scenario validates Login keeps tokens hidden for `MBD-011`. It focuses on the need to confirm that reader and writer login pass the token through stdin and never show it."
version: 1.0.0.0
---

# MBD-011 -- Login keeps tokens hidden

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-011`.

---

## 1. OVERVIEW

This scenario validates Login keeps tokens hidden for `MBD-011`. It focuses on the need to confirm that reader and writer login pass the token through stdin and never show it.

### Why This Matters

A token on a command line or in chat output is a leaked credential. The writer session must also stay separate from the reader session.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-011` and confirm the expected signals without contradictory evidence.

- Objective: Confirm that reader and writer login pass the token through stdin and never show it.
- Real user request: `Log the Moneybird CLI in from the credential files without showing me the token.`
- Prompt: `Log in the Moneybird reader and writer sessions from their credential files and prove the tokens never appear in the output.`
- Expected execution process: The agent writes throwaway tokens into a temporary Accountant folder, runs both logins against the stub and searches the output for the tokens.
- Expected signals: Both logins print only the completion line. The stub log shows one default login and one login under the temporary writer folder. Neither token appears in the output.
- Desired user-visible outcome: The operator sees that login works from the files and that no token value reaches the screen.
- Pass/fail: PASS if both logins exit 0, the output holds no `FAKE_` token and the stub log shows `LOGIN default` and the writer folder. FAIL if a token appears in the output or the writer login reuses the reader session.
- Feature catalog: [Reader and writer login](../../feature-catalog/sessions-and-diagnostics/reader-and-writer-login.md)

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
| MBD-011 | Login keeps tokens hidden | Confirm that reader and writer login pass the token through stdin and never show it | `Log in the Moneybird reader and writer sessions from their credential files and prove the tokens never appear in the output.` | 1. `bash: write throwaway .env and .env.writer` -> 2. `moneybird-guard login-from-env` -> 3. `moneybird-guard login-from-env --writer` -> 4. `bash: grep -c FAKE_ output` | Step 1: two temporary files exist. Step 2: `Moneybird login completed. CLI output was suppressed.` Step 3: the same line. Step 4: `0` token matches and two `LOGIN` lines in the stub log | Captured login output, the grep count and the stub invocation log | PASS if both logins exit 0, the output holds no `FAKE_` token and the stub log shows `LOGIN default` and the writer folder. FAIL if a token appears in the output or the writer login reuses the reader session. | 1. Confirm the block wrote only to the temporary folder. 2. Check that the login branch in `moneybird-guard` discards CLI output. 3. Run `bash cli/moneybird-cli/tests/run-tests.sh` and compare the two login cases |

### Command Block

Run the block from the `cli-moneybird/` package root. It uses only the packaged stub and a temporary folder that the block removes on exit. It never touches the real CLI session, `.env` or `.env.writer`. The tokens are throwaway strings, never real credentials. The block sets `MONEYBIRD_GUARD_TEST=1`, a test-only setting for the offline test suite. Never set it in a real session.

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
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
printf 'MONEYBIRD_API_TOKEN=FAKE_READER_TOKEN\n' > "$MONEYBIRD_ENV_DIR/.env"
printf 'MONEYBIRD_API_TOKEN=FAKE_WRITER_TOKEN\n' > "$MONEYBIRD_ENV_DIR/.env.writer"
OUTPUT="$("$GUARD" login-from-env 2>&1)"
echo "reader exit=$?"
OUTPUT="$OUTPUT$("$GUARD" login-from-env --writer 2>&1)"
echo "writer exit=$?"
printf '%s\n' "$OUTPUT"
printf '%s\n' "$OUTPUT" | grep -c FAKE_
cat "$MONEYBIRD_TEST_LOG"
SCENARIO
```

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/sessions-and-diagnostics/reader-and-writer-login.md`](../../feature-catalog/sessions-and-diagnostics/reader-and-writer-login.md) | Feature-catalog entry for Reader and writer login |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Login branch |
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated login cases |

---

## 5. SOURCE METADATA

- Group: Setup and diagnostics
- Playbook ID: MBD-011
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `setup/login-keeps-tokens-hidden.md`
