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
unset MONEYBIRD_HMAC_KEY_FILE || true
mkdir -p "$HOME/.config/moneybird-cli-writer" "$MONEYBIRD_ENV_DIR/migration-workspace" "$MONEYBIRD_WRITER_CONFIG_DIR"
: > "$MONEYBIRD_TEST_LOG"

KEY_FILE="$MONEYBIRD_ENV_DIR/migration-workspace/.secrets/alias-hmac.key"
mkdir -p "$(dirname "$KEY_FILE")"
KEY_FILE="$(cd -P "$(dirname "$KEY_FILE")" && pwd -P)/$(basename "$KEY_FILE")"
TEST_KEY="$(python3 -I -c 'import secrets; print(secrets.token_hex(32), end="")')"
printf '%s' "$TEST_KEY" > "$KEY_FILE"
CAPTURED="$TEST_ROOT/captured-output.log"
: > "$CAPTURED"
WRITE_LOG="$MONEYBIRD_ENV_DIR/migration-workspace/logs/moneybird-writes.jsonl"

JOURNAL_DIR="$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal"
JOURNAL="$JOURNAL_DIR/run-journal.jsonl"
write_journal() {
  mkdir -p "$JOURNAL_DIR"
  printf '%s\n' "$@" > "$JOURNAL"
}
write_intent() {
  mkdir -p "$JOURNAL_DIR"
  printf '{"approval_reference":"%s","new_state":"WRITE_INTENT","payload_digest":"%s","attachment_digest":"%s","batch_key":"%s"}\n' "$1" "$2" "${3:-}" "${4:-batch-test}" > "$JOURNAL"
}
payload_digest() {
  python3 -I - "$KEY_FILE" "$1" "$2" "$3" <<'PY'
import hashlib
import hmac
import sys

key_path = sys.argv[1]
method = sys.argv[2]
url = sys.argv[3]
body = sys.argv[4]
with open(key_path, "rb") as handle:
    key = handle.read()
host_path = url.split("://", 1)[-1]
path = "/" + host_path.split("/", 1)[1]
path = path.split("?")[0].split("#")[0]
lines = [] if body == "" else body.split("\n")
canonical = method + "\n" + path + "\n"
for line in lines:
    if line.endswith("\r"):
        line = line[:-1]
    canonical += line + "\n"
print(hmac.new(key, canonical.encode("utf-8"), hashlib.sha256).hexdigest())
PY
}
attachment_digest() {
  python3 -I - "$KEY_FILE" "$1" <<'PY'
import hashlib
import hmac
import sys

with open(sys.argv[1], "rb") as handle:
    key = handle.read()
with open(sys.argv[2], "rb") as handle:
    data = handle.read()
print(hmac.new(key, data, hashlib.sha256).hexdigest())
PY
}
write_journal '{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}' 'this line is not json' '[{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}]'

CREATE_URL="https://moneybird.com/api/v2/PILOT_ADMIN/contacts.json"
CREATE_BODY='{"contacts":{}}'
CREATE_DIGEST="$(payload_digest POST "$CREATE_URL" "$CREATE_BODY")"

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
  printf '%s\n' "$OUTPUT" >> "$CAPTURED"
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

# An unconfirmed create prints its preview, one payload digest line and no body, and never reaches the real call.
reset_state
capture_guard contacts create
PREVIEW_DIGEST="$(printf '%s\n' "$OUTPUT" | sed -n 's/^payload-digest: //p')"
PREVIEW_DIGEST_LINES="$(printf '%s\n' "$OUTPUT" | grep -cE '^payload-digest: [0-9a-f]{64}$' || true)"
if [[ $STATUS -eq 3 && "$OUTPUT" == *"POST https://moneybird.com/api/v2/PILOT_ADMIN/contacts.json"* ]] &&
   [[ "$PREVIEW_DIGEST_LINES" -eq 1 && "$PREVIEW_DIGEST" == "$CREATE_DIGEST" ]] &&
   [[ "$OUTPUT" != *'{"contacts":{}}'* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Unconfirmed create exits 3 with one payload digest line and no body"
else
  fail "Unconfirmed create exits 3 with one payload digest line and no body"
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

# A matching payload writes once and appends a body-free JSON line with the join keys.
reset_state
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"
write_intent "APPROVED-1" "$CREATE_DIGEST" "" "batch-pilot"
capture_guard --confirm-write --approval APPROVED-1 contacts create
if [[ $STATUS -eq 0 ]] && [[ "$(grep -c '^REAL ' "$MONEYBIRD_TEST_LOG" || true)" -eq 1 ]] && [[ -f "$WRITE_LOG" ]] &&
   printf '%s\n' "$(tail -n1 "$WRITE_LOG")" | jq -e --arg ref "APPROVED-1" --arg digest "$CREATE_DIGEST" 'has("approval_reference") and has("batch_key") and has("payload_digest") and (has("body") | not) and .method == "POST" and .administration_id == "PILOT_ADMIN" and .exit_status == 0 and .approval_reference == $ref and .batch_key == "batch-pilot" and .payload_digest == $digest' >/dev/null; then
  pass "A matching payload writes once and logs the join keys without a body"
else
  fail "A matching payload writes once and logs the join keys without a body"
fi

# A non-GET intent with no payload digest is refused before the real call.
reset_state
write_journal '{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}'
capture_guard --confirm-write --approval APPROVED-1 contacts create
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A non-GET intent with no payload digest exits 9"
else
  fail "A non-GET intent with no payload digest exits 9"
fi

# A changed body is refused before the real call.
reset_state
write_intent "CHANGED-1" "$CREATE_DIGEST" "" "batch-changed"
if OUTPUT="$(MONEYBIRD_TEST_DRY_BODY='{"contacts":{"company_name":"changed"}}' "$GUARD" --confirm-write --approval CHANGED-1 contacts create 2>&1)"; then
  STATUS=0
else
  STATUS="$?"
fi
printf '%s\n' "$OUTPUT" >> "$CAPTURED"
CHANGED_DIGEST_LINES="$(printf '%s\n' "$OUTPUT" | grep -cE '^payload-digest: [0-9a-f]{64}$' || true)"
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* && "$CHANGED_DIGEST_LINES" -eq 1 ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A changed body exits 9 with one payload digest line"
else
  fail "A changed body exits 9 with one payload digest line"
fi

# The same payload with reordered JSON keys is refused before the real call.
reset_state
ORDERED_DIGEST="$(payload_digest POST "$CREATE_URL" '{"contacts":{"id":"1","name":"stub"}}')"
write_intent "REORDERED-1" "$ORDERED_DIGEST" "" "batch-reordered"
if OUTPUT="$(MONEYBIRD_TEST_DRY_BODY='{"contacts":{"name":"stub","id":"1"}}' "$GUARD" --confirm-write --approval REORDERED-1 contacts create 2>&1)"; then
  STATUS=0
else
  STATUS="$?"
fi
printf '%s\n' "$OUTPUT" >> "$CAPTURED"
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Reordered JSON keys exit 9"
else
  fail "Reordered JSON keys exit 9"
fi

# The same body aimed at another record path is refused before the real call.
reset_state
UPDATE_URL="https://moneybird.com/api/v2/PILOT_ADMIN/contacts/stub-record.json"
write_intent "RETARGETED-1" "$(payload_digest PATCH "$UPDATE_URL" "$CREATE_BODY")" "" "batch-retargeted"
capture_guard --confirm-write --approval RETARGETED-1 contacts update other-record
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "The same body sent to another record path exits 9"
else
  fail "The same body sent to another record path exits 9"
fi

# A replayed reference and digest pair is refused with the consumed message.
reset_state
write_intent "REPLAY-1" "$CREATE_DIGEST" "" "batch-replay"
capture_guard --confirm-write --approval REPLAY-1 contacts create
FIRST_STATUS="$STATUS"
reset_state
capture_guard --confirm-write --approval REPLAY-1 contacts create
if [[ $FIRST_STATUS -eq 0 && $STATUS -eq 8 && "$OUTPUT" == *"already consumed"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A replayed reference and digest pair exits 8 as consumed"
else
  fail "A replayed reference and digest pair exits 8 as consumed"
fi

# An attachment preview prints both digests and matches the test key.
ATTACHMENT="$TEST_ROOT/receipt.pdf"
printf 'synthetic receipt bytes\n' > "$ATTACHMENT"
ATTACHMENT_URL="https://moneybird.com/api/v2/PILOT_ADMIN/documents/attachments.json"
ATTACHMENT_BODY='{"documents":{}}'$'\n'"multipart field file=$ATTACHMENT"
ATTACHMENT_PAYLOAD_DIGEST="$(payload_digest POST "$ATTACHMENT_URL" "$ATTACHMENT_BODY")"
ATTACHMENT_BYTES_DIGEST="$(attachment_digest "$ATTACHMENT")"
reset_state
capture_guard documents receipts attachments stub-document --file "$ATTACHMENT"
PREVIEW_PAYLOAD_DIGEST="$(printf '%s\n' "$OUTPUT" | sed -n 's/^payload-digest: //p')"
PREVIEW_ATTACHMENT_DIGEST="$(printf '%s\n' "$OUTPUT" | sed -n 's/^attachment-digest: //p')"
if [[ $STATUS -eq 3 && "$PREVIEW_PAYLOAD_DIGEST" == "$ATTACHMENT_PAYLOAD_DIGEST" && "$PREVIEW_ATTACHMENT_DIGEST" == "$ATTACHMENT_BYTES_DIGEST" ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "An attachment preview prints both digests"
else
  fail "An attachment preview prints both digests"
fi

# An attachment whose bytes match the approved digest writes once.
reset_state
write_intent "ATTACH-1" "$ATTACHMENT_PAYLOAD_DIGEST" "$ATTACHMENT_BYTES_DIGEST" "batch-attachment"
capture_guard --confirm-write --approval ATTACH-1 documents receipts attachments stub-document --file "$ATTACHMENT"
if [[ $STATUS -eq 0 ]] && [[ "$(grep -c '^REAL POST ' "$MONEYBIRD_TEST_LOG" || true)" -eq 1 ]]; then
  pass "An attachment whose bytes match writes once"
else
  fail "An attachment whose bytes match writes once"
fi

# Attachment bytes that changed after approval are refused before the real call.
reset_state
printf 'changed receipt bytes\n' > "$ATTACHMENT"
write_intent "ATTACH-2" "$ATTACHMENT_PAYLOAD_DIGEST" "$ATTACHMENT_BYTES_DIGEST" "batch-attachment-changed"
capture_guard --confirm-write --approval ATTACH-2 documents receipts attachments stub-document --file "$ATTACHMENT"
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Changed attachment bytes exit 9"
else
  fail "Changed attachment bytes exit 9"
fi

# A file write against an intent with no attachment digest is refused.
reset_state
write_intent "ATTACH-3" "$ATTACHMENT_PAYLOAD_DIGEST" "" "batch-attachment-absent"
capture_guard --confirm-write --approval ATTACH-3 documents receipts attachments stub-document --file "$ATTACHMENT"
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A file write without an approved attachment digest exits 9"
else
  fail "A file write without an approved attachment digest exits 9"
fi

# A missing key file exits 1 before the real call and names the location only.
reset_state
write_intent "NOKEY-1" "$CREATE_DIGEST" "" "batch-nokey"
mv "$KEY_FILE" "$KEY_FILE.away"
capture_guard --confirm-write --approval NOKEY-1 contacts create
mv "$KEY_FILE.away" "$KEY_FILE"
if [[ $STATUS -eq 1 && "$OUTPUT" == *"$KEY_FILE"* && "$OUTPUT" != *"$TEST_KEY"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "A missing key file exits 1 before the real call"
else
  fail "A missing key file exits 1 before the real call"
fi

# An unset pilot treats the target as production and needs the production flag.
reset_state
unset MONEYBIRD_PILOT_ADMINISTRATION_ID || true
printf 'MONEYBIRD_API_TOKEN=temporary-test-token\n' > "$MONEYBIRD_ENV_DIR/.env"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PRODUCTION_ADMIN"
PRODUCTION_URL="https://moneybird.com/api/v2/PRODUCTION_ADMIN/contacts.json"
write_intent "APPROVED-1" "$(payload_digest POST "$PRODUCTION_URL" "$CREATE_BODY")" "" "batch-production"
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
DELETE_URL="https://moneybird.com/api/v2/PILOT_ADMIN/contacts/stub-record.json"
write_intent "APPROVED-1" "$(payload_digest DELETE "$DELETE_URL" "")" "" "batch-delete"
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

# A recorded WRITE_INTENT reference with a matching digest lets a pilot write run even beside malformed journal lines.
reset_state
write_journal 'this line is not json' '[{"approval_reference":"APPROVED-1","new_state":"WRITE_INTENT"}]' "{\"approval_reference\":\"APPROVED-2\",\"new_state\":\"WRITE_INTENT\",\"payload_digest\":\"$CREATE_DIGEST\",\"batch_key\":\"batch-journal\"}"
capture_guard --confirm-write --approval APPROVED-2 contacts create
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
capture_guard --confirm-write --production --approval APPROVED-2 administration use OTHER_ADMIN
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
if OUTPUT="$(MONEYBIRD_GUARD_TEST= MONEYBIRD_PILOT_ADMINISTRATION_ID=ENV_PILOT MONEYBIRD_CLI="$TEST_ROOT/decoy-cli" MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/decoy-writer" MONEYBIRD_HMAC_KEY_FILE="$TEST_ROOT/decoy-key" PATH="$PINNED_BIN:$PATH" "$PINNED_REPO/cli-moneybird/cli/moneybird-cli/moneybird-guard" --confirm-write contacts create 2>&1)"; then
  STATUS=0
else
  STATUS="$?"
fi
if [[ $STATUS -eq 4 && "$OUTPUT" == *"Pilot administration 'PINNED_PILOT' differs from target 'PILOT_ADMIN'"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_ENV_DIR is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_CLI is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_WRITER_CONFIG_DIR is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_PILOT_ADMINISTRATION_ID is ignored"* ]] &&
   [[ "$OUTPUT" == *"MONEYBIRD_HMAC_KEY_FILE is ignored"* ]] &&
   [[ "$OUTPUT" != *"ENV_PILOT"* && "$OUTPUT" != *"DECOY_PILOT"* && "$OUTPUT" != *"decoy-cli"* && "$OUTPUT" != *"decoy-writer"* && "$OUTPUT" != *"decoy-key"* ]] &&
   ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "The pinned root, binary, writer config, key file and pilot id ignore environment overrides"
else
  fail "The pinned root, binary, writer config, key file and pilot id ignore environment overrides"
fi
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' > "$MONEYBIRD_ENV_DIR/.env"

# Fault injection: one case per guard exit code, 1 to 8 plus the payload-mismatch 9.
# The stub injects the upstream failures and the guard's own gates drive the rest.

# An upstream CLI failure is surfaced as exit 1, never swallowed.
reset_state
export MONEYBIRD_TEST_FAULT=upstream-fail
capture_guard contacts list --filter period:2023
unset MONEYBIRD_TEST_FAULT
if [[ $STATUS -eq 1 && "$OUTPUT" == *"the upstream CLI failed"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 1: an upstream CLI failure exits 1 (stub fault)"
else
  fail "Fault 1: an upstream CLI failure exits 1 (stub fault)"
fi

# A dry-run line that is not METHOD URL is refused with exit 2.
reset_state
export MONEYBIRD_TEST_FAULT=bad-dry-line
capture_guard contacts list --filter period:2023
unset MONEYBIRD_TEST_FAULT
if [[ $STATUS -eq 2 && "$OUTPUT" == *"did not begin with a METHOD URL line"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 2: a malformed dry-run line exits 2 (stub fault)"
else
  fail "Fault 2: a malformed dry-run line exits 2 (stub fault)"
fi

# An unconfirmed write is blocked with exit 3.
reset_state
capture_guard contacts create
if [[ $STATUS -eq 3 && "$OUTPUT" == *"Write blocked"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 3: an unconfirmed write exits 3 (guard gate)"
else
  fail "Fault 3: an unconfirmed write exits 3 (guard gate)"
fi

# A non-pilot target without --production is blocked with exit 4.
reset_state
export MONEYBIRD_TEST_ADMINISTRATION_ID="OTHER_ADMIN"
capture_guard --confirm-write contacts create
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
if [[ $STATUS -eq 4 && "$OUTPUT" == *"differs from target"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 4: a non-pilot target exits 4 (guard gate)"
else
  fail "Fault 4: a non-pilot target exits 4 (guard gate)"
fi

# An --out path outside migration-workspace is rejected with exit 5.
reset_state
capture_guard --out "$TEST_ROOT/outside.json" contacts list
if [[ $STATUS -eq 5 && "$OUTPUT" == *"inside migration-workspace"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 5: an output path outside the workspace exits 5 (guard gate)"
else
  fail "Fault 5: an output path outside the workspace exits 5 (guard gate)"
fi

# The read-only lock blocks a non-GET call with exit 6.
reset_state
export MONEYBIRD_GUARD_READ_ONLY=1
capture_guard --confirm-write --production contacts create
unset MONEYBIRD_GUARD_READ_ONLY
if [[ $STATUS -eq 6 && "$OUTPUT" == *"Read-only lock is enabled"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 6: the read-only lock exits 6 (guard gate)"
else
  fail "Fault 6: the read-only lock exits 6 (guard gate)"
fi

# A missing writer configuration stops the write with exit 7.
reset_state
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/missing-writer-config"
capture_guard --confirm-write --approval APPROVED-1 contacts create
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
if [[ $STATUS -eq 7 && "$OUTPUT" == *"Writer configuration is missing"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 7: a missing writer configuration exits 7 (guard gate)"
else
  fail "Fault 7: a missing writer configuration exits 7 (guard gate)"
fi

# A confirmed write without an approval reference stops with exit 8.
reset_state
capture_guard --confirm-write contacts create
if [[ $STATUS -eq 8 && "$OUTPUT" == *"requires --approval"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 8: a missing approval reference exits 8 (guard gate)"
else
  fail "Fault 8: a missing approval reference exits 8 (guard gate)"
fi

# A payload that changed after approval is refused with exit 9.
reset_state
write_intent "FAULT-9" "$CREATE_DIGEST" "" "batch-fault"
if OUTPUT="$(MONEYBIRD_TEST_DRY_BODY='{"contacts":{"company_name":"changed"}}' "$GUARD" --confirm-write --approval FAULT-9 contacts create 2>&1)"; then
  STATUS=0
else
  STATUS="$?"
fi
printf '%s\n' "$OUTPUT" >> "$CAPTURED"
if [[ $STATUS -eq 9 && "$OUTPUT" == *"PAYLOAD_MISMATCH"* ]] && ! grep -q '^REAL ' "$MONEYBIRD_TEST_LOG"; then
  pass "Fault 9: a changed payload exits 9 (guard gate)"
else
  fail "Fault 9: a changed payload exits 9 (guard gate)"
fi

# The key never reaches the captured output, the write log or the journal.
KEY_HITS="$(grep -rlF "$TEST_KEY" "$MONEYBIRD_ENV_DIR/migration-workspace" 2>/dev/null | grep -v '/\.secrets/' || true)"
if [[ -z "$KEY_HITS" ]] && ! grep -Fq "$TEST_KEY" "$CAPTURED" && ! grep -Fq "$TEST_KEY" "$WRITE_LOG" && ! grep -Fq "$TEST_KEY" "$JOURNAL"; then
  pass "The key never reaches the captured output, the write log or the journal"
else
  fail "The key never reaches the captured output, the write log or the journal"
fi

printf 'Pass: %s  Fail: %s\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ $FAIL_COUNT -eq 0 ]]
