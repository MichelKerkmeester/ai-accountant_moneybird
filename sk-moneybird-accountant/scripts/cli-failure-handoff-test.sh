#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: CLI FAILURE HANDOFF TEST
# ───────────────────────────────────────────────────────────────
# Tests the retry handoff around the two accounting CLIs without a network
# call. A fake curl drives the real Jortt request loop to 429 exhaustion, and
# the real guard with its stub makes one call per invocation under an upstream
# 429. The suite also checks that the documented retry owners, the
# no-non-GET-repeat rule and the blocked answer contract still hold in the
# skill files and the eval suite.
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
ROUTER_PAGE="$REPO_SRC/sk-moneybird-accountant/ROUTER.md"
EVALS="$REPO_SRC/sk-moneybird-accountant/evals/evals.json"
SCENARIO="$REPO_SRC/sk-moneybird-accountant/manual-testing-playbook/safety-and-privacy/cli-failure-blocked.md"

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

: > "$MONEYBIRD_TEST_LOG"
rate_limited_read
if [[ "$(count_log 'REAL GET ')" == "1" ]]; then
    pass "one guard invocation makes exactly one real GET call"
else
    fail "one guard invocation makes exactly one real GET call (calls $(count_log 'REAL GET '))"
fi

# ───────────────────────────────────────────────────────────────
# 8. BLOCKED ANSWER CONTRACT
# ───────────────────────────────────────────────────────────────

group "blocked answer contract"

if grep -qF 'Say blocked, name the missing capability and stop.' "$SKILL_PAGE" \
    && grep -qF -- '- `CLI_FAILURE`: on any nonzero CLI or guard exit' "$ROUTER_PAGE"; then
    pass "the skill keeps the blocked answer rule and its router the CLI_FAILURE route class"
else
    fail "the skill keeps the blocked answer rule and its router the CLI_FAILURE route class"
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
# 9. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
