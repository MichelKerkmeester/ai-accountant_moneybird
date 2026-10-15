#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: CLI FAILURE HANDOFF TEST
# ───────────────────────────────────────────────────────────────
# Tests the retry handoff around the two accounting CLIs without a network
# call. A fake curl drives the real Jortt request loop to 429 exhaustion. The
# real guard and its stub are invoked through a small parent loop that reads
# its attempt bound from the sibling skill. The suite also checks that the
# documented retry owners, the no-non-GET-repeat rule and the blocked answer
# contract still hold in the skill files and the eval suite.
# Usage: cli-failure-handoff-test.sh [repository root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing files
#
# WHY: retry ownership is restated in five places, and a second retry layer or
# an answer built from memory is invisible until a live read fails. This suite
# rehearses each owner offline so the contract drifts loudly.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND FILE VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: cli-failure-handoff-test.sh [repository root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

GUARD="$REPO_SRC/cli-moneybird/cli/moneybird-cli/moneybird-guard"
STUB="$REPO_SRC/cli-moneybird/cli/moneybird-cli/tests/stub-moneybird-cli"
JORTT_COMMON="$REPO_SRC/cli-jortt/cli/jortt-cli/lib/common.sh"
JORTT_API="$REPO_SRC/cli-jortt/cli/jortt-cli/lib/api.sh"
JORTT_SKILL="$REPO_SRC/cli-jortt/SKILL.md"
MONEYBIRD_SKILL="$REPO_SRC/cli-moneybird/SKILL.md"
SHARED="$REPO_SRC/sk-moneybird-accountant/references/migration/shared-mechanisms.md"
SKILL_PAGE="$REPO_SRC/sk-moneybird-accountant/SKILL.md"
EVALS="$REPO_SRC/sk-moneybird-accountant/evals/evals.json"
SCENARIO="$REPO_SRC/sk-moneybird-accountant/manual-testing-playbook/offline-routing/cli-failure-blocked.md"

for required in "$GUARD" "$STUB" "$JORTT_COMMON" "$JORTT_API" "$JORTT_SKILL" \
    "$MONEYBIRD_SKILL" "$SHARED" "$SKILL_PAGE" "$EVALS" "$SCENARIO"; do
    if [[ ! -f "$required" ]]; then
        printf 'error: missing %s\n' "$required" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/cli-failure-handoff-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TEST_ROOT:-}" ]] && [[ -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}
trap cleanup EXIT

# WHY: the guard is offline only under its test flag, and the flag exists for
# the offline suite alone, so the harness pins the stub, the temp workspace and
# the writer folder here and never reads a real credential.
export HOME="$TEST_ROOT/home"
export MONEYBIRD_GUARD_TEST=1
export MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$STUB"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
unset MONEYBIRD_PILOT_ADMINISTRATION_ID MONEYBIRD_GUARD_READ_ONLY MONEYBIRD_HMAC_KEY_FILE || true
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX || true
mkdir -p "$HOME/.config/moneybird-cli-writer" "$MONEYBIRD_ENV_DIR/migration-workspace" "$MONEYBIRD_WRITER_CONFIG_DIR"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' >"$MONEYBIRD_ENV_DIR/.env"
: > "$MONEYBIRD_TEST_LOG"

KEY_FILE="$MONEYBIRD_ENV_DIR/migration-workspace/.secrets/alias-hmac.key"
mkdir -p "$(dirname "$KEY_FILE")"
if ! python3 -I -c 'import secrets, sys; open(sys.argv[1], "w").write(secrets.token_hex(32))' "$KEY_FILE"; then
    printf 'error: could not write the fake key file\n' >&2
    exit 2
fi
JOURNAL_DIR="$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal"
JOURNAL="$JOURNAL_DIR/run-journal.jsonl"

# ───────────────────────────────────────────────────────────────
# 4. TEST HELPERS
# ───────────────────────────────────────────────────────────────

passed=0
failed=0

# Record a passing check and print its report line
# Args:
#   $1 - Check description
pass() {
    passed=$((passed + 1))
    printf 'PASS %s\n' "$1"
}

# Record a failing check and print its report line
# Args:
#   $1 - Check description
fail() {
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
}

# Print a section heading before the next block of checks
# Args:
#   $1 - Group title
group() {
    printf '\n== %s\n' "$1"
}

# Count the stub log lines that start with one marker
# Args:
#   $1 - Marker text
count_log() {
    grep -c "^$1" "$MONEYBIRD_TEST_LOG" 2>/dev/null || true
}

# Run the real guard once and capture its output
# Args:
#   $1... - Guard arguments
# Returns:
#   The guard exit status, with its output in $TEST_ROOT/guard.out
run_guard() {
    "$GUARD" "$@" >"$TEST_ROOT/guard.out" 2>&1
}

# Run one rate-limited guarded GET through the real guard and stub
# Returns:
#   The guard exit status from the injected upstream status
rate_limited_read() {
    MONEYBIRD_GUARD_READ_ONLY=1 MONEYBIRD_TEST_REAL_STATUS=429 "$GUARD" contacts list --filter period:2023 >"$TEST_ROOT/guard.out" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 5. CONTRACT TEXT
# ───────────────────────────────────────────────────────────────

group "documented retry owners"

if grep -qF 'is the retry owner for its own 429 responses' "$JORTT_SKILL" \
    && grep -qF 'never add a second retry layer' "$JORTT_SKILL"; then
    pass "the Jortt skill keeps jortt-cli the 429 retry owner"
else
    fail "the Jortt skill keeps jortt-cli the 429 retry owner"
fi

LIVE_LIMIT="$(sed -n 's/.*bounded attempt count `LIVE_GET_MAX_ATTEMPTS` of \([0-9][0-9]*\).*/\1/p' "$MONEYBIRD_SKILL")"
if [[ "$LIVE_LIMIT" == "3" ]] \
    && grep -qF 'A third failed GET stops the read for the Operator' "$MONEYBIRD_SKILL" \
    && grep -qF 'Never retry a non-GET call' "$MONEYBIRD_SKILL"; then
    pass "the Moneybird skill keeps the three-attempt GET bound and the non-GET stop"
else
    fail "the Moneybird skill keeps the three-attempt GET bound and the non-GET stop"
fi

if grep -qF 'may authorize one paced reissue for a read' "$SHARED" \
    && grep -qF 'stop for Operator decision' "$SHARED"; then
    pass "the shared mechanism keeps one authorized reissue and the stop after it"
else
    fail "the shared mechanism keeps one authorized reissue and the stop after it"
fi

# ───────────────────────────────────────────────────────────────
# 6. JORTT 429 EXHAUSTION
# ───────────────────────────────────────────────────────────────

group "Jortt 429 exhaustion"

JORTT_COUNT="$TEST_ROOT/jortt-calls.txt"
JORTT_RESULT="$TEST_ROOT/jortt-result.txt"
JORTT_STDERR="$TEST_ROOT/jortt-stderr.txt"
: > "$JORTT_COUNT"
: > "$JORTT_STDERR"

# WHY: the real request loop runs against a fake curl, so the retry count is
# the CLI's own and no wrapper can be added without moving the number.
if bash -c '
    set +e
    . "$1"
    . "$2"
    set +e
    count_file="$3"
    JORTT_ACCESS_TOKEN="fake-fixture-value"
    CALLS=0
    curl() {
        local headers_file="" value
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -D) headers_file="$2"; shift 2 ;;
                -sS|-L|-w|--config|--data-binary|-o|--output) shift 2 ;;
                *) shift ;;
            esac
        done
        CALLS=$((CALLS + 1))
        printf "%s\n" "$CALLS" >>"$count_file"
        if [ -n "$headers_file" ]; then
            printf "HTTP/1.1 429 Too Many Requests\r\nRetry-After: 0\r\n" >"$headers_file"
        fi
        printf "%s\n" "{\"error\":\"rate limited\"}"
        printf "\n429\n"
    }
    sleep() { :; }
    jortt_get_token() { :; }
    jortt_request GET "https://example.invalid/customers" ""
    status=$?
    printf "request_status=%s http=%s\n" "$status" "$JORTT_HTTP_STATUS"
    exit 0
' bash "$JORTT_COMMON" "$JORTT_API" "$JORTT_COUNT" >"$JORTT_RESULT" 2>"$JORTT_STDERR"; then
    JORTT_STATUS="$(sed -n 's/^request_status=\([0-9][0-9]*\) http=.*/\1/p' "$JORTT_RESULT")"
    JORTT_HTTP="$(sed -n 's/^request_status=[0-9][0-9]* http=//p' "$JORTT_RESULT")"
    JORTT_CALLS="$(wc -l <"$JORTT_COUNT" | tr -d '[:space:]')"
    if [[ "$JORTT_STATUS" == "1" && "$JORTT_HTTP" == "429" && "$JORTT_CALLS" == "4" ]] \
        && grep -q 'jortt-cli: HTTP 429' "$JORTT_STDERR"; then
        pass "the Jortt loop makes one call plus three retries and stops at the CLI"
    else
        fail "the Jortt loop makes one call plus three retries and stops at the CLI (status $JORTT_STATUS, http $JORTT_HTTP, calls $JORTT_CALLS)"
    fi
else
    fail "the Jortt loop makes one call plus three retries and stops at the CLI"
fi

# ───────────────────────────────────────────────────────────────
# 7. MONEYBIRD BOUNDED GET READS
# ───────────────────────────────────────────────────────────────

group "Moneybird bounded GET reads"

# Run the parent's bounded GET loop through the real guard and stub
# Args:
#   $1 - Attempts before a reissue may be authorized
#   $2 - 1 when the Orchestrator authorizes one reissue for a read
#   $3 - File that receives the attempt count
#   $4 - File that receives the parent answer
# Returns:
#   0, printing nothing. Attempts and answer land in the two files.
bounded_get_read() {
    local limit="$1"
    local authorized="$2"
    local count_file="$3"
    local answer_file="$4"
    local attempt=0 status=1
    : > "$MONEYBIRD_TEST_LOG"
    while [[ "$attempt" -lt "$limit" ]]; do
        attempt=$((attempt + 1))
        if rate_limited_read; then
            status=0
            break
        fi
    done
    if [[ "$status" -ne 0 && "$authorized" -eq 1 ]]; then
        attempt=$((attempt + 1))
        if rate_limited_read; then
            status=0
        fi
    fi
    printf '%s\n' "$attempt" >"$count_file"
    if [[ "$status" -eq 0 ]]; then
        printf 'read ok\n' >"$answer_file"
    else
        printf 'BLOCKED: the missing capability is the contacts read. No value is taken from memory and the answer stops.\n' >"$answer_file"
    fi
}

: > "$MONEYBIRD_TEST_LOG"
rate_limited_read
if [[ "$(count_log 'REAL GET ')" == "1" ]]; then
    pass "one guard invocation makes exactly one real GET call"
else
    fail "one guard invocation makes exactly one real GET call (calls $(count_log 'REAL GET '))"
fi

LIVE_COUNT="$TEST_ROOT/live-count.txt"
LIVE_ANSWER="$TEST_ROOT/live-answer.txt"
bounded_get_read "$LIVE_LIMIT" 0 "$LIVE_COUNT" "$LIVE_ANSWER"
LIVE_ATTEMPTS="$(tr -d '[:space:]' <"$LIVE_COUNT")"
LIVE_CALLS="$(count_log 'REAL GET ')"
if [[ "$LIVE_ATTEMPTS" == "3" && "$LIVE_CALLS" == "3" ]] \
    && grep -q '^BLOCKED' "$LIVE_ANSWER" && grep -q 'missing capability' "$LIVE_ANSWER"; then
    pass "a LIVE GET stops after three attempts and the parent answers blocked"
else
    fail "a LIVE GET stops after three attempts and the parent answers blocked (attempts $LIVE_ATTEMPTS, calls $LIVE_CALLS)"
fi

MIG_COUNT="$TEST_ROOT/migration-count.txt"
MIG_ANSWER="$TEST_ROOT/migration-answer.txt"
bounded_get_read 1 1 "$MIG_COUNT" "$MIG_ANSWER"
MIG_ATTEMPTS="$(tr -d '[:space:]' <"$MIG_COUNT")"
MIG_CALLS="$(count_log 'REAL GET ')"
if [[ "$MIG_ATTEMPTS" == "2" && "$MIG_CALLS" == "2" ]] && grep -q '^BLOCKED' "$MIG_ANSWER"; then
    pass "a MIGRATION read gets one authorized reissue and then stops"
else
    fail "a MIGRATION read gets one authorized reissue and then stops (attempts $MIG_ATTEMPTS, calls $MIG_CALLS)"
fi

# ───────────────────────────────────────────────────────────────
# 8. NO NON-GET REPEAT
# ───────────────────────────────────────────────────────────────

group "no non-GET repeat"

CREATE_URL="https://moneybird.com/api/v2/PILOT_ADMIN/contacts.json"

# Print the guard payload digest of one method, URL and body
# Args:
#   $1 - Method
#   $2 - URL
#   $3 - Body
payload_digest() {
    python3 -I - "$KEY_FILE" "$1" "$2" "$3" <<'PY'
import hashlib
import hmac
import sys

key_path, method, url, body = sys.argv[1:5]
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

mkdir -p "$JOURNAL_DIR"
DIGEST="$(payload_digest POST "$CREATE_URL" '{"contacts":{}}')"
printf '{"approval_reference":"HANDOFF-1","new_state":"WRITE_INTENT","payload_digest":"%s","batch_key":"handoff"}\n' "$DIGEST" >"$JOURNAL"
: > "$MONEYBIRD_TEST_LOG"

if run_guard --confirm-write --approval HANDOFF-1 contacts create; then
    FIRST_STATUS=0
else
    FIRST_STATUS=$?
fi
FIRST_POSTS="$(count_log 'REAL POST ')"

if run_guard --confirm-write --approval HANDOFF-1 contacts create; then
    SECOND_STATUS=0
else
    SECOND_STATUS=$?
fi
SECOND_POSTS="$(count_log 'REAL POST ')"

if [[ "$FIRST_STATUS" -eq 0 && "$FIRST_POSTS" == "1" && "$SECOND_STATUS" -eq 8 \
    && "$SECOND_POSTS" == "1" ]] \
    && grep -q 'already consumed' "$TEST_ROOT/guard.out"; then
    pass "a replayed non-GET intent is refused with no second real call"
else
    fail "a replayed non-GET intent is refused with no second real call (first $FIRST_STATUS, second $SECOND_STATUS, posts $SECOND_POSTS)"
fi

# ───────────────────────────────────────────────────────────────
# 9. BLOCKED ANSWER CONTRACT
# ───────────────────────────────────────────────────────────────

group "blocked answer contract"

if grep -qF 'Say blocked, name the missing capability and stop.' "$SKILL_PAGE" \
    && grep -qF 'CLI_FAILURE' "$SKILL_PAGE"; then
    pass "the skill keeps the blocked answer rule and the CLI_FAILURE route class"
else
    fail "the skill keeps the blocked answer rule and the CLI_FAILURE route class"
fi

if python3 -I - "$EVALS" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    suite = json.load(handle)
case = [row for row in suite["cases"] if row["id"] == "cli-read-exhausted-blocked"]
if len(case) != 1:
    raise SystemExit(1)
required = case[0]["assertions"]["required"]
flat = [value for entry in required for value in (entry if isinstance(entry, list) else [entry])]
if "BLOCKED" not in flat or "missing capability" not in flat:
    raise SystemExit(1)
PY
then
    pass "the eval suite holds the blocked answer case with its required tokens"
else
    fail "the eval suite holds the blocked answer case with its required tokens"
fi

if grep -qF 'cli-failure-blocked.md' "$REPO_SRC/sk-moneybird-accountant/manual-testing-playbook/manual-testing-playbook.md"; then
    pass "the playbook index links the blocked answer scenario"
else
    fail "the playbook index links the blocked answer scenario"
fi

# ───────────────────────────────────────────────────────────────
# 10. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
