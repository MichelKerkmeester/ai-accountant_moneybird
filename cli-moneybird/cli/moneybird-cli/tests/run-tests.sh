#!/usr/bin/env bash
# WHY: Verify moneybird-guard with a local stub and a temporary workspace only.
set -euo pipefail

TESTS_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
SKILL_ROOT="$(cd -P "$TESTS_DIR/../../.." >/dev/null 2>&1 && pwd -P)"
GUARD="$SKILL_ROOT/cli/moneybird-cli/moneybird-guard"
STUB="$TESTS_DIR/stub-moneybird-cli"
TMP_PARENT="${TMPDIR:-/tmp}"
TEST_ROOT="$(mktemp -d "$TMP_PARENT/moneybird-guard-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$STUB"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
mkdir -p "$HOME" "$MONEYBIRD_ENV_DIR/migration-workspace" "$MONEYBIRD_WRITER_CONFIG_DIR"
: > "$MONEYBIRD_TEST_LOG"

PASS_COUNT=0
FAIL_COUNT=0
OUTPUT=""
STATUS=0

capture_guard() {
  if OUTPUT="$("$GUARD" "$@" 2>&1)"; then
    STATUS=0
  else
    STATUS="$?"
  fi
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$1"
}

reset_state() {
  : > "$MONEYBIRD_TEST_LOG"
}

# Lists warn about the API's default period while preserving the read.
reset_state
capture_guard contacts list
if [[ $STATUS -eq 0 && "$OUTPUT" == *"default to period:this_year"* ]] && grep -q '^REAL GET ' "$MONEYBIRD_TEST_LOG"; then
  pass "GET list warns about the default period and runs"
else
  fail "GET list warns about the default period and runs"
fi

# An explicit period filter suppresses that warning.
reset_state
capture_guard contacts list --filter period:2023
if [[ $STATUS -eq 0 && "$OUTPUT" != *"default to period:this_year"* ]] && grep -q '^REAL GET ' "$MONEYBIRD_TEST_LOG"; then
  pass "GET list with a period filter runs without a warning"
else
  fail "GET list with a period filter runs without a warning"
fi

# An unconfirmed create prints its preview and never reaches the real call.
reset_state
capture_guard contacts create
if [[ $STATUS -eq 3 && "$OUTPUT" == *"POST https://moneybird.com/api/v2/PILOT_ADMIN/contacts.json"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Unconfirmed create exits 3 without a real call"
else
  fail "Unconfirmed create exits 3 without a real call"
fi

# A confirmed write to a non-pilot administration is blocked.
reset_state
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
export MONEYBIRD_TEST_ADMINISTRATION_ID="OTHER_ADMIN"
capture_guard --confirm-write contacts create
if [[ $STATUS -eq 4 && "$OUTPUT" == *"Pilot administration 'PILOT_ADMIN' differs from target 'OTHER_ADMIN'"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Non-pilot create exits 4"
else
  fail "Non-pilot create exits 4"
fi

# A pilot write runs and appends a body-free JSON line.
reset_state
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
capture_guard --confirm-write contacts create
WRITE_LOG="$MONEYBIRD_ENV_DIR/migration-workspace/logs/moneybird-writes.jsonl"
if [[ $STATUS -eq 0 ]] && grep -q '^REAL POST ' "$MONEYBIRD_TEST_LOG" && [[ -f "$WRITE_LOG" ]] && jq -e 'select(.method == "POST" and .administration_id == "PILOT_ADMIN" and .exit_status == 0 and (has("body") | not))' "$WRITE_LOG" >/dev/null; then
  pass "Pilot create runs and logs a body-free JSON record"
else
  fail "Pilot create runs and logs a body-free JSON record"
fi

# An unset pilot treats the target as production and needs the production flag.
reset_state
unset MONEYBIRD_PILOT_ADMINISTRATION_ID || true
printf 'MONEYBIRD_API_TOKEN=temporary-test-token\n' > "$MONEYBIRD_ENV_DIR/.env"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PRODUCTION_ADMIN"
capture_guard --confirm-write --production contacts create
if [[ $STATUS -eq 0 ]] && grep -q '^REAL POST ' "$MONEYBIRD_TEST_LOG"; then
  pass "Confirmed production create runs with --production"
else
  fail "Confirmed production create runs with --production"
fi

# The read-only lock wins over both write flags and never reaches the real call.
reset_state
export MONEYBIRD_GUARD_READ_ONLY=1
export MONEYBIRD_TEST_ADMINISTRATION_ID="PRODUCTION_ADMIN"
capture_guard --confirm-write --production contacts create
if [[ $STATUS -eq 6 && "$OUTPUT" == *"Read-only lock is enabled. Non-GET POST calls are blocked."* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Read-only lock blocks a confirmed production write before the real call"
else
  fail "Read-only lock blocks a confirmed production write before the real call"
fi

# The read-only lock allows GET calls through.
reset_state
capture_guard contacts list --filter period:2023
if [[ $STATUS -eq 0 ]] && grep -q '^REAL GET ' "$MONEYBIRD_TEST_LOG"; then
  pass "Read-only lock allows GET calls"
else
  fail "Read-only lock allows GET calls"
fi
unset MONEYBIRD_GUARD_READ_ONLY

# DELETE retains the 204 and separate-read warning.
reset_state
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
capture_guard --confirm-write contacts delete stub-record
if [[ $STATUS -eq 0 && "$OUTPUT" == *"204 can mean nothing was deleted"* ]] && [[ "$OUTPUT" == *"separate read"* ]]; then
  pass "DELETE prints the 204 caution and separate-read instruction"
else
  fail "DELETE prints the 204 caution and separate-read instruction"
fi

# An output outside the workspace is rejected before any CLI call.
reset_state
capture_guard --out "$TEST_ROOT/outside.json" contacts list
if [[ $STATUS -eq 5 ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "--out outside migration-workspace exits 5 before the CLI call"
else
  fail "--out outside migration-workspace exits 5 before the CLI call"
fi

# An output under the workspace is raw JSON and stdout contains only a count.
reset_state
OUT_FILE="$MONEYBIRD_ENV_DIR/migration-workspace/contacts.json"
capture_guard --out "$OUT_FILE" contacts list --filter period:2023
if [[ $STATUS -eq 0 && "$OUTPUT" == "items: 1" && -f "$OUT_FILE" ]] && jq -e '.[0].id == "stub-record"' "$OUT_FILE" >/dev/null; then
  pass "--out inside migration-workspace writes JSON and prints only the item count"
else
  fail "--out inside migration-workspace writes JSON and prints only the item count"
fi

# Reader login reads a token through stdin and suppresses all CLI output.
reset_state
printf 'MONEYBIRD_API_TOKEN=FAKE_READER_TOKEN_DO_NOT_ECHO\n' > "$MONEYBIRD_ENV_DIR/.env"
capture_guard login-from-env
if [[ $STATUS -eq 0 && "$OUTPUT" != *"FAKE_READER_TOKEN_DO_NOT_ECHO"* ]] && grep -q '^LOGIN default$' "$MONEYBIRD_TEST_LOG"; then
  pass "login-from-env keeps the reader token out of output and argv"
else
  fail "login-from-env keeps the reader token out of output and argv"
fi

# Writer login reads .env.writer and selects the separate CLI config directory.
reset_state
printf 'MONEYBIRD_API_TOKEN=FAKE_WRITER_TOKEN_DO_NOT_ECHO\n' > "$MONEYBIRD_ENV_DIR/.env.writer"
capture_guard login-from-env --writer
if [[ $STATUS -eq 0 && "$OUTPUT" != *"FAKE_WRITER_TOKEN_DO_NOT_ECHO"* ]] && grep -q "^LOGIN $MONEYBIRD_WRITER_CONFIG_DIR$" "$MONEYBIRD_TEST_LOG"; then
  pass "writer login uses .env.writer and a separate config directory"
else
  fail "writer login uses .env.writer and a separate config directory"
fi

printf 'Pass: %s  Fail: %s\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ $FAIL_COUNT -eq 0 ]]
