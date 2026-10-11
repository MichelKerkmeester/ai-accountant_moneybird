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
export MONEYBIRD_GUARD_TEST=1
export MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$STUB"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
unset MONEYBIRD_PILOT_ADMINISTRATION_ID || true
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX || true
mkdir -p "$HOME/.config/moneybird-cli-writer" "$MONEYBIRD_ENV_DIR/migration-workspace" "$MONEYBIRD_WRITER_CONFIG_DIR"
: > "$MONEYBIRD_TEST_LOG"

JOURNAL_DIR="$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal"
JOURNAL="$JOURNAL_DIR/run-journal.jsonl"
write_journal() {
  mkdir -p "$JOURNAL_DIR"
  printf '%s\n' "$@" > "$JOURNAL"
}
write_journal '{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}' 'this line is not json' '[{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}]'

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
capture_guard --confirm-write --approval APPROVED-1 contacts create
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
capture_guard --confirm-write --production --approval APPROVED-1 contacts create
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
capture_guard --confirm-write --approval APPROVED-1 contacts delete stub-record
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

# A write without a writer configuration stops instead of falling back to the reader token.
reset_state
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/missing-writer-config"
capture_guard --confirm-write --approval APPROVED-1 contacts create
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
if [[ $STATUS -eq 7 && "$OUTPUT" == *"Writer configuration is missing"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A write without a writer configuration stops"
else
  fail "A write without a writer configuration stops"
fi

# A confirmed pilot write without --approval stops.
reset_state
capture_guard --confirm-write contacts create
if [[ $STATUS -eq 8 && "$OUTPUT" == *"requires --approval"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A confirmed write without --approval exits 8"
else
  fail "A confirmed write without --approval exits 8"
fi

# An approval reference the run journal does not record stops the write.
reset_state
capture_guard --confirm-write --approval NOT-APPROVED contacts create
if [[ $STATUS -eq 8 && "$OUTPUT" == *"no WRITE_INTENT entry"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "An approval reference that is not in the run journal exits 8"
else
  fail "An approval reference that is not in the run journal exits 8"
fi

# A matching reference with a different state stops the write.
reset_state
write_journal '{"approval_reference":"DRAFT-1","new_state":"DRAFT"}'
capture_guard --confirm-write --approval DRAFT-1 contacts create
if [[ $STATUS -eq 8 && "$OUTPUT" == *"no WRITE_INTENT entry"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A journal entry without the WRITE_INTENT state exits 8"
else
  fail "A journal entry without the WRITE_INTENT state exits 8"
fi

# A missing run journal stops the write.
reset_state
rm -f "$JOURNAL"
capture_guard --confirm-write --approval APPROVED-1 contacts create
if [[ $STATUS -eq 8 && "$OUTPUT" == *"run journal is missing"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A missing run journal exits 8"
else
  fail "A missing run journal exits 8"
fi

# A recorded WRITE_INTENT reference lets a pilot write run.
reset_state
write_journal 'this line is not json' '[{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}]' '{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT","path":"contacts"}'
capture_guard --confirm-write --approval APPROVED-1 contacts create
if [[ $STATUS -eq 0 ]] && grep -q '^REAL POST ' "$MONEYBIRD_TEST_LOG"; then
  pass "A recorded WRITE_INTENT reference lets a pilot write run"
else
  fail "A recorded WRITE_INTENT reference lets a pilot write run"
fi

# A production write needs the same approval reference.
reset_state
export MONEYBIRD_TEST_ADMINISTRATION_ID="PRODUCTION_ADMIN"
capture_guard --confirm-write --production contacts create
if [[ $STATUS -eq 8 && "$OUTPUT" == *"requires --approval"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A confirmed production write without --approval exits 8"
else
  fail "A confirmed production write without --approval exits 8"
fi
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"

# A read captures the body, prints a value-free summary and removes the temporary file.
reset_state
capture_guard contacts list --filter period:2023
SUMMARY_TMP="$MONEYBIRD_ENV_DIR/migration-workspace/tmp"
SUMMARY_MODE="missing"
if [[ -d "$SUMMARY_TMP" ]]; then
  SUMMARY_MODE="$(stat -f '%Lp' "$SUMMARY_TMP" 2>/dev/null || stat -c '%a' "$SUMMARY_TMP" 2>/dev/null || printf 'unknown')"
fi
if [[ $STATUS -eq 0 && "$OUTPUT" == *"response: 23 bytes"* && "$OUTPUT" == *"records: 1"* && "$OUTPUT" != *"stub-record"* ]] &&
   grep -q '^REAL GET ' "$MONEYBIRD_TEST_LOG" && [[ "$SUMMARY_MODE" == "700" && -z "$(ls -A "$SUMMARY_TMP")" ]]; then
  pass "A read prints a value-free summary and removes the temporary file"
else
  fail "A read prints a value-free summary and removes the temporary file"
fi

# A JSON object body summarises field names and a nested record count without values.
reset_state
capture_guard contacts get stub-record
if [[ $STATUS -eq 0 && "$OUTPUT" == *"fields: id,company_name,contacts"* && "$OUTPUT" == *"records: 1"* && "$OUTPUT" != *"Secret Name"* ]]; then
  pass "An object body summarises field names and a nested record count without values"
else
  fail "An object body summarises field names and a nested record count without values"
fi

# --print-body streams the response body for an operator run.
reset_state
capture_guard --print-body contacts list --filter period:2023
if [[ $STATUS -eq 0 && "$OUTPUT" == *"stub-record"* ]] && grep -q '^REAL GET ' "$MONEYBIRD_TEST_LOG"; then
  pass "--print-body streams the response body"
else
  fail "--print-body streams the response body"
fi

# An empty marker is not an agent session.
reset_state
if OUTPUT="$(export CLAUDECODE=; "$GUARD" --print-body contacts list --filter period:2023 2>&1)"; then
  STATUS=0
else
  STATUS="$?"
fi
if [[ $STATUS -eq 0 && "$OUTPUT" == *"stub-record"* ]]; then
  pass "An empty agent session marker still allows --print-body"
else
  fail "An empty agent session marker still allows --print-body"
fi

# Every agent session marker refuses --print-body.
for MARKER in CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX; do
  reset_state
  if OUTPUT="$(export "$MARKER=1"; "$GUARD" --print-body contacts list --filter period:2023 2>&1)"; then
    STATUS=0
  else
    STATUS="$?"
  fi
  if [[ $STATUS -eq 2 && "$OUTPUT" == *"--print-body is refused while $MARKER is set"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
    pass "--print-body is refused while $MARKER is set"
  else
    fail "--print-body is refused while $MARKER is set"
  fi
done

# A passthrough command rejects --out instead of silently dropping it.
reset_state
PASSTHROUGH_OUT="$MONEYBIRD_ENV_DIR/migration-workspace/help.json"
capture_guard --out "$PASSTHROUGH_OUT" --help
if [[ $STATUS -eq 2 && "$OUTPUT" == *"--out does not apply to passthrough commands"* ]] && [[ ! -e "$PASSTHROUGH_OUT" ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A passthrough command rejects --out"
else
  fail "A passthrough command rejects --out"
fi

# administration use for the pilot administration passes through.
reset_state
capture_guard administration use PILOT_ADMIN
if [[ $STATUS -eq 0 ]] && grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "administration use for the pilot administration passes through"
else
  fail "administration use for the pilot administration passes through"
fi

# administration use for another administration needs --production.
reset_state
capture_guard --confirm-write administration use OTHER_ADMIN
if [[ $STATUS -eq 4 && "$OUTPUT" == *"is not the pilot administration"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "administration use for another administration without --production exits 4"
else
  fail "administration use for another administration without --production exits 4"
fi

# administration use for another administration needs an approval reference.
reset_state
capture_guard --confirm-write --production administration use OTHER_ADMIN
if [[ $STATUS -eq 8 && "$OUTPUT" == *"requires --approval"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "administration use for another administration without --approval exits 8"
else
  fail "administration use for another administration without --approval exits 8"
fi

reset_state
capture_guard --confirm-write --production --approval NOT-APPROVED administration use OTHER_ADMIN
if [[ $STATUS -eq 8 && "$OUTPUT" == *"no WRITE_INTENT entry"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "administration use rejects an approval reference that is not in the run journal"
else
  fail "administration use rejects an approval reference that is not in the run journal"
fi

# administration use runs when the production and approval gates pass.
reset_state
capture_guard --confirm-write --production --approval APPROVED-1 administration use OTHER_ADMIN
if [[ $STATUS -eq 0 ]] && grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "administration use runs when the production and approval gates pass"
else
  fail "administration use runs when the production and approval gates pass"
fi

# The guard pins its own repository root, the CLI binary, the writer config and the pilot id.
PINNED_REPO="$TEST_ROOT/pinned-repo"
PINNED_BIN="$TEST_ROOT/pinned-bin"
mkdir -p "$PINNED_REPO/cli-moneybird/cli/moneybird-cli" "$PINNED_BIN"
cp "$GUARD" "$PINNED_REPO/cli-moneybird/cli/moneybird-cli/moneybird-guard"
chmod +x "$PINNED_REPO/cli-moneybird/cli/moneybird-cli/moneybird-guard"
cp "$STUB" "$PINNED_BIN/moneybird-cli"
chmod +x "$PINNED_BIN/moneybird-cli"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PINNED_PILOT\n' > "$PINNED_REPO/.env"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=DECOY_PILOT\n' > "$MONEYBIRD_ENV_DIR/.env"
reset_state
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
if OUTPUT="$(MONEYBIRD_GUARD_TEST= MONEYBIRD_PILOT_ADMINISTRATION_ID=ENV_PILOT MONEYBIRD_CLI="$TEST_ROOT/decoy-cli" MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/decoy-writer" PATH="$PINNED_BIN:$PATH" "$PINNED_REPO/cli-moneybird/cli/moneybird-cli/moneybird-guard" --confirm-write contacts create 2>&1)"; then
  STATUS=0
else
  STATUS="$?"
fi
if [[ $STATUS -eq 4 && "$OUTPUT" == *"Pilot administration 'PINNED_PILOT' differs from target 'PILOT_ADMIN'"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_ENV_DIR is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_CLI is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_WRITER_CONFIG_DIR is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_PILOT_ADMINISTRATION_ID is ignored"* ]] &&
   [[ "$OUTPUT" != *"ENV_PILOT"* && "$OUTPUT" != *"DECOY_PILOT"* && "$OUTPUT" != *"decoy-cli"* && "$OUTPUT" != *"decoy-writer"* ]] &&
   ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "The pinned root, binary, writer config and pilot id ignore environment overrides"
else
  fail "The pinned root, binary, writer config and pilot id ignore environment overrides"
fi
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"

printf 'Pass: %s  Fail: %s\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ $FAIL_COUNT -eq 0 ]]
