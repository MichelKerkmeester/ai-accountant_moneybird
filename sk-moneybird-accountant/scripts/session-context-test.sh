#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SESSION CONTEXT TEST
# ───────────────────────────────────────────────────────────────
# Tests build-session-context.py against temp fixture workspaces for the clock,
# the interactive flag, the config projection, the check rules, the staleness
# window and the post-cutover route states.
# Usage: session-context-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the generated context decides the mode, the year and the route, so a
# wrong clock, a leaked field or a wrong state must fail loudly. This suite
# proves each one does.
# WHY: the route state must depend on the stored dates alone, never on the
# absolute year, so the same seven fixtures run under two pinned epochs.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND SKILL VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: session-context-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

REPO_ROOT=$(dirname "$SKILL_SRC")
BUILDER="$SKILL_SRC/scripts/build-session-context.py"
AGENTS_MD="$REPO_ROOT/AGENTS.md"
SKILL_MD="$SKILL_SRC/SKILL.md"
ROUTER_MD="$SKILL_SRC/ROUTER.md"

if [[ ! -f "$BUILDER" ]]; then
    printf 'error: missing scripts/build-session-context.py in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$AGENTS_MD" ]]; then
    printf 'error: missing AGENTS.md next to the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_MD" ]]; then
    printf 'error: missing SKILL.md in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$ROUTER_MD" ]]; then
    printf 'error: missing ROUTER.md in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/session-context-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 4. TEST HELPERS AND FIXTURE BUILDERS
# ───────────────────────────────────────────────────────────────

# The suite sets the clock and the terminal probe itself, so ambient values are
# cleared before the first case runs
unset SOURCE_DATE_EPOCH
unset CI

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

# Print the captured builder output, indented, for a failed check
show_output() {
    if [[ -s "$TMP_ROOT/out.txt" ]]; then
        sed 's/^/  /' "$TMP_ROOT/out.txt"
    fi
}

# Print one field of a session context file
# Args:
#   $1 - Context file
#   $2 - Field name
context_field() {
    python3 -I -c '
import json, sys
data = json.load(open(sys.argv[1]))
value = data.get(sys.argv[2])
if value is None:
    print("null")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
' "$1" "$2" 2>/dev/null
}

# Print a calendar date a number of days away from a pinned epoch
# Args:
#   $1 - Pinned epoch in seconds
#   $2 - Day offset, which may be negative
day_from_epoch() {
    python3 -I -c '
import sys
from datetime import datetime, timedelta, timezone
stamp = datetime.fromtimestamp(int(sys.argv[1]), timezone.utc)
print((stamp.date() + timedelta(days=int(sys.argv[2]))).isoformat())
' "$1" "$2"
}

# Print the ISO 8601 UTC text of a pinned epoch
# Args:
#   $1 - Pinned epoch in seconds
utc_from_epoch() {
    python3 -I -c '
import sys
from datetime import datetime, timezone
print(datetime.fromtimestamp(int(sys.argv[1]), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
' "$1"
}

# Print the epoch seconds of a UTC date at midnight
# Args:
#   $1 - Calendar date
epoch_from_date() {
    python3 -I -c '
import sys
from datetime import datetime, timezone
print(int(datetime.fromisoformat(sys.argv[1]).replace(tzinfo=timezone.utc).timestamp()))
' "$1"
}

# Write a fixture workspace with a dashboard and a migration config
# Args:
#   $1 - Directory to create
#   $2 - Dashboard JSON text
#   $3 - Migration config JSON text
# Returns:
#   0 when both files are written, 1 when a write fails
make_workspace() {
    local dir="$1" dashboard="$2" config="$3"
    mkdir -p "$dir" || return 1
    printf '%s\n' "$dashboard" >"$dir/dashboard.json" || return 1
    printf '%s\n' "$config" >"$dir/MIGRATION_CONFIG.json" || return 1
    return 0
}

# Run the builder and capture its combined output
# Args:
#   $1... - Builder arguments
run_builder() {
    python3 -I "$BUILDER" "$@" >"$TMP_ROOT/out.txt" 2>&1
}

# Run the builder with stdout and stderr kept apart
# Args:
#   $1... - Builder arguments
run_builder_split() {
    python3 -I "$BUILDER" "$@" >"$TMP_ROOT/out.txt" 2>"$TMP_ROOT/err.txt"
}

# Run one check-mode case and record the result
# Args:
#   $1 - Check name
#   $2 - Expected exit status
#   $3 - Text the output must mention
#   $4 - Context file passed to --out
check_case() {
    local name="$1" expected="$2" needle="$3" out="$4"
    local status
    run_builder --check --out "$out"
    status=$?
    if [[ "$status" -ne "$expected" ]]; then
        fail "$name"
        printf '  exit %s, expected %s\n' "$status" "$expected"
        show_output
        return 0
    fi
    if ! grep -Fq "$needle" "$TMP_ROOT/out.txt"; then
        fail "$name"
        printf '  output does not mention: %s\n' "$needle"
        show_output
        return 0
    fi
    pass "$name"
}

# Write a context copy with one field removed
# Args:
#   $1 - Source context file
#   $2 - Destination file
#   $3 - Field to remove
drop_field() {
    python3 -I -c '
import json, sys
src, dst, field = sys.argv[1:4]
data = json.load(open(src))
data.pop(field, None)
open(dst, "w").write(json.dumps(data, indent=2, sort_keys=True) + "\n")
' "$1" "$2" "$3"
}

# Write a context copy with one field set to a JSON value
# Args:
#   $1 - Source context file
#   $2 - Destination file
#   $3 - Field to set
#   $4 - New value as JSON text
set_field() {
    python3 -I -c '
import json, sys
src, dst, field, raw = sys.argv[1:5]
data = json.load(open(src))
data[field] = json.loads(raw)
open(dst, "w").write(json.dumps(data, indent=2, sort_keys=True) + "\n")
' "$1" "$2" "$3" "$4"
}

# Write a context copy with one extra field added
# Args:
#   $1 - Source context file
#   $2 - Destination file
#   $3 - Field to add
add_field() {
    python3 -I -c '
import json, sys
src, dst, field = sys.argv[1:4]
data = json.load(open(src))
data[field] = True
open(dst, "w").write(json.dumps(data, indent=2, sort_keys=True) + "\n")
' "$1" "$2" "$3"
}

# Print the seven route case keys, one per line
route_case_list() {
    printf '%s\n' pre-cutover window-open window-lapsed window-open-ended final-gate window-conflict gate-no-start
}

# Print the report name of one route case
# Args:
#   $1 - Route case key
route_case_name() {
    case "$1" in
        pre-cutover) printf 'gate 17 -> pre_cutover\n' ;;
        window-open) printf 'gate 18 open window -> monitoring_active\n' ;;
        window-lapsed) printf 'gate 18 window ended yesterday with Phase 22 open -> monitoring_lapsed_phase22_open\n' ;;
        window-open-ended) printf 'gate 18 OPEN_ENDED -> monitoring_active\n' ;;
        final-gate) printf 'Phase 22 passed -> migration_complete\n' ;;
        window-conflict) printf 'end date before start date -> gate_window_conflict\n' ;;
        gate-no-start) printf 'gate 18 with no start date -> gate_window_conflict\n' ;;
    esac
}

# Print the expected state of one route case
# Args:
#   $1 - Route case key
route_case_state() {
    case "$1" in
        pre-cutover) printf 'pre_cutover\n' ;;
        window-open) printf 'monitoring_active\n' ;;
        window-lapsed) printf 'monitoring_lapsed_phase22_open\n' ;;
        window-open-ended) printf 'monitoring_active\n' ;;
        final-gate) printf 'migration_complete\n' ;;
        window-conflict) printf 'gate_window_conflict\n' ;;
        gate-no-start) printf 'gate_window_conflict\n' ;;
    esac
}

# Write the fixture workspace for one route case
# Args:
#   $1 - Route case key
#   $2 - Pinned epoch
# Returns:
#   0 when the fixture is written, 1 on an unknown key or a write error
make_route_fixture() {
    local key="$1" epoch="$2"
    local dir="$TMP_ROOT/route-$key"
    local start end config dashboard
    case "$key" in
        pre-cutover)
            config='{"configured_start_date": "2019-01-01", "last_locked_year": 2024}'
            dashboard='[{"phase": 12, "status": "GATE_PASSED"}, {"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "NOT_STARTED"}, {"phase": 22, "status": "NOT_STARTED"}]'
            ;;
        window-open)
            start=$(day_from_epoch "$epoch" -2)
            end=$(day_from_epoch "$epoch" 20)
            config=$(printf '{"monitoring": {"start_date": "%s", "end_date": "%s"}}' "$start" "$end")
            dashboard='[{"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "GATE_PASSED"}, {"phase": 22, "status": "IN_PROGRESS"}]'
            ;;
        window-lapsed)
            start=$(day_from_epoch "$epoch" -3)
            end=$(day_from_epoch "$epoch" -1)
            config=$(printf '{"monitoring": {"start_date": "%s", "end_date": "%s"}}' "$start" "$end")
            dashboard='[{"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "GATE_PASSED"}, {"phase": 22, "status": "IN_PROGRESS"}]'
            ;;
        window-open-ended)
            start=$(day_from_epoch "$epoch" -2)
            config=$(printf '{"monitoring": {"start_date": "%s", "end_date": "OPEN_ENDED"}}' "$start")
            dashboard='[{"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "GATE_PASSED"}, {"phase": 22, "status": "IN_PROGRESS"}]'
            ;;
        final-gate)
            start=$(day_from_epoch "$epoch" -30)
            end=$(day_from_epoch "$epoch" -5)
            config=$(printf '{"monitoring": {"start_date": "%s", "end_date": "%s"}}' "$start" "$end")
            dashboard='[{"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "GATE_PASSED"}, {"phase": 22, "status": "GATE_PASSED"}]'
            ;;
        window-conflict)
            start=$(day_from_epoch "$epoch" 10)
            end=$(day_from_epoch "$epoch" 2)
            config=$(printf '{"monitoring": {"start_date": "%s", "end_date": "%s"}}' "$start" "$end")
            # WHY: the final gate has passed as well, so only the conflict
            # check running first can yield the conflict state.
            dashboard='[{"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "GATE_PASSED"}, {"phase": 22, "status": "GATE_PASSED"}]'
            ;;
        gate-no-start)
            config='{"configured_start_date": "2019-01-01", "last_locked_year": 2024}'
            # WHY: a passed cutover gate with no recorded start date leaves no
            # window, so the router must report the conflict.
            dashboard='[{"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "GATE_PASSED"}, {"phase": 22, "status": "IN_PROGRESS"}]'
            ;;
        *)
            return 1
            ;;
    esac
    make_workspace "$dir" "$dashboard" "$config"
}

# Build the context file for one route case
# Args:
#   $1 - Route case key
#   $2 - Pinned epoch
#   $3 - Context file to write
# Returns:
#   The builder exit status, with output in $TMP_ROOT/out.txt
build_route_case() {
    local key="$1" epoch="$2" out="$3"
    local dir="$TMP_ROOT/route-$key"
    make_route_fixture "$key" "$epoch" || return 1
    SOURCE_DATE_EPOCH="$epoch" python3 -I "$BUILDER" \
        --config "$dir/MIGRATION_CONFIG.json" \
        --dashboard "$dir/dashboard.json" \
        --out "$out" >"$TMP_ROOT/out.txt" 2>&1
}

# Print the route state of an existing context file
# Args:
#   $1 - Context file
#   $2 - Pinned epoch
state_from_file() {
    local out="$1" epoch="$2"
    SOURCE_DATE_EPOCH="$epoch" python3 -I "$BUILDER" --route-state --out "$out" 2>>"$TMP_ROOT/out.txt"
}

# Print the state names of all seven route cases for one pinned epoch
# Args:
#   $1 - Pinned epoch
# Returns:
#   The seven state names, one per line, or 1 when a case cannot be built
route_state_list() {
    local epoch="$1" key out
    for key in $(route_case_list); do
        out="$TMP_ROOT/route-$key.json"
        build_route_case "$key" "$epoch" "$out" || return 1
        state_from_file "$out" "$epoch" || return 1
    done
}

# Run one route case and record the state and the untouched context file
# Args:
#   $1 - Route case key
#   $2 - Pinned epoch
route_case() {
    local key="$1" epoch="$2"
    local name expected out state
    name=$(route_case_name "$key")
    expected=$(route_case_state "$key")
    out="$TMP_ROOT/route-$key.json"
    if ! build_route_case "$key" "$epoch" "$out"; then
        fail "$name"
        show_output
        return 0
    fi
    cp "$out" "$TMP_ROOT/route-before.json"
    state=$(state_from_file "$out" "$epoch")
    if [[ "$state" = "$expected" ]]; then
        pass "$name"
    else
        fail "$name"
        printf '  expected %s, got %s\n' "$expected" "${state:-no state}"
        show_output
    fi
    if cmp -s "$TMP_ROOT/route-before.json" "$out"; then
        pass "file unchanged after route-state: $name"
    else
        fail "file unchanged after route-state: $name"
    fi
}

# ───────────────────────────────────────────────────────────────
# 5. CLOCK, INTERACTIVE AND WRITE MODE
# ───────────────────────────────────────────────────────────────

BASE_DIR="$TMP_ROOT/base"
CONFIG="$BASE_DIR/MIGRATION_CONFIG.json"
DASHBOARD="$BASE_DIR/dashboard.json"
CONTEXT="$TMP_ROOT/context.json"
CLEAN="$TMP_ROOT/clean.json"

# WHY: two pinned stamps a year apart prove the states ignore the absolute
# year, and the base stamp is computed from a date so this tracked file holds
# no long digit run.
EPOCH_A=$(epoch_from_date 2026-01-01)
if [[ -z "$EPOCH_A" ]]; then
    printf 'error: cannot compute the pinned epoch\n' >&2
    exit 2
fi
EPOCH_B=$((EPOCH_A + 397 * 86400))
EPOCH_TEXT_A=$(utc_from_epoch "$EPOCH_A")

if ! make_workspace "$BASE_DIR" \
    '[{"phase": 12, "status": "GATE_PASSED"}, {"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "IN_PROGRESS"}, {"phase": 22, "status": "NOT_STARTED"}]' \
    '{"configured_start_date": "2019-01-01", "last_locked_year": 2024, "monitoring": {"start_date": "2026-01-05", "end_date": "2026-02-05"}}'; then
    printf 'error: cannot write the fixture workspace\n' >&2
    exit 2
fi

group "clock and interactive"

SOURCE_DATE_EPOCH=$EPOCH_A run_builder --config "$CONFIG" --dashboard "$DASHBOARD" --out "$CONTEXT"
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ "$(context_field "$CONTEXT" clock_source)" = "SOURCE_DATE_EPOCH" ]] \
    && [[ "$(context_field "$CONTEXT" clock_utc)" = "$EPOCH_TEXT_A" ]]; then
    pass "clock pinned"
else
    fail "clock pinned"
    printf '  exit %s, clock_source %s, clock_utc %s\n' \
        "$status" "$(context_field "$CONTEXT" clock_source)" "$(context_field "$CONTEXT" clock_utc)"
fi

run_builder --config "$CONFIG" --dashboard "$DASHBOARD" --out "$CONTEXT"
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" clock_source)" = "runtime" ]]; then
    pass "clock runtime"
else
    fail "clock runtime"
    printf '  exit %s, clock_source %s\n' "$status" "$(context_field "$CONTEXT" clock_source)"
fi

SOURCE_DATE_EPOCH=abc run_builder_split --config "$CONFIG" --dashboard "$DASHBOARD" --out "$CONTEXT"
status=$?
if [[ "$status" -eq 3 ]] && grep -Fq 'clock_missing' "$TMP_ROOT/err.txt" && [[ ! -s "$TMP_ROOT/out.txt" ]]; then
    pass "clock missing"
else
    fail "clock missing"
    printf '  exit %s, stderr: %s\n' "$status" "$(tr '\n' ' ' <"$TMP_ROOT/err.txt")"
fi

CI=1 run_builder --config "$CONFIG" --dashboard "$DASHBOARD" --out "$CONTEXT"
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" interactive)" = "false" ]]; then
    pass "interactive false under CI"
else
    fail "interactive false under CI"
    printf '  exit %s, interactive %s\n' "$status" "$(context_field "$CONTEXT" interactive)"
fi

CI=1 run_builder --config "$CONFIG" --dashboard "$DASHBOARD" --out "$CONTEXT" --interactive true
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" interactive)" = "true" ]]; then
    pass "interactive override"
else
    fail "interactive override"
    printf '  exit %s, interactive %s\n' "$status" "$(context_field "$CONTEXT" interactive)"
fi

group "config projection"

# WHY: a config date field holding a path must be dropped rather than copied,
# and the written file must still pass the check.
PATHDATE_DIR="$TMP_ROOT/path-date"
PATHDATE_OUT="$TMP_ROOT/path-date.json"
if ! make_workspace "$PATHDATE_DIR" \
    '[{"phase": 12, "status": "GATE_PASSED"}, {"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "IN_PROGRESS"}, {"phase": 22, "status": "NOT_STARTED"}]' \
    '{"configured_start_date": "migration-workspace/2026", "last_locked_year": 2024, "monitoring": {"start_date": "2026-01-05", "end_date": "2026-02-05"}}'; then
    printf 'error: cannot write the fixture workspace\n' >&2
    exit 2
fi
SOURCE_DATE_EPOCH=$EPOCH_A run_builder --config "$PATHDATE_DIR/MIGRATION_CONFIG.json" --dashboard "$PATHDATE_DIR/dashboard.json" --out "$PATHDATE_OUT"
write_status=$?
path_date=$(context_field "$PATHDATE_OUT" configured_start_date)
SOURCE_DATE_EPOCH=$EPOCH_A run_builder --check --out "$PATHDATE_OUT"
check_status=$?
if [[ "$write_status" -eq 0 ]] && [[ "$path_date" = "null" ]] \
    && [[ "$check_status" -eq 0 ]] && grep -Fq 'session-context: ok' "$TMP_ROOT/out.txt"; then
    pass "date field holding a path is dropped"
else
    fail "date field holding a path is dropped"
    printf '  write exit %s, check exit %s, configured_start_date %s\n' \
        "$write_status" "$check_status" "$path_date"
    show_output
fi

# WHY: a config year field holding an object must be dropped as well.
NESTED_DIR="$TMP_ROOT/nested-year"
NESTED_OUT="$TMP_ROOT/nested-year.json"
if ! make_workspace "$NESTED_DIR" \
    '[{"phase": 12, "status": "GATE_PASSED"}, {"phase": 17, "status": "GATE_PASSED"}, {"phase": 18, "status": "IN_PROGRESS"}, {"phase": 22, "status": "NOT_STARTED"}]' \
    '{"configured_start_date": "2019-01-01", "last_locked_year": {"year": 2024}, "monitoring": {"start_date": "2026-01-05", "end_date": "2026-02-05"}}'; then
    printf 'error: cannot write the fixture workspace\n' >&2
    exit 2
fi
SOURCE_DATE_EPOCH=$EPOCH_A run_builder --config "$NESTED_DIR/MIGRATION_CONFIG.json" --dashboard "$NESTED_DIR/dashboard.json" --out "$NESTED_OUT"
write_status=$?
locked_year=$(context_field "$NESTED_OUT" last_locked_year)
if [[ "$write_status" -eq 0 ]] && [[ "$locked_year" = "null" ]]; then
    pass "nested object in last_locked_year is dropped"
else
    fail "nested object in last_locked_year is dropped"
    printf '  write exit %s, last_locked_year %s\n' "$write_status" "$locked_year"
fi

# ───────────────────────────────────────────────────────────────
# 6. CHECK MODE
# ───────────────────────────────────────────────────────────────

group "check mode"

SOURCE_DATE_EPOCH=$EPOCH_A run_builder --config "$CONFIG" --dashboard "$DASHBOARD" --out "$CLEAN"

SOURCE_DATE_EPOCH=$EPOCH_A check_case "clean file" 0 "session-context: ok" "$CLEAN"

check_case "file missing" 1 "missing file" "$TMP_ROOT/absent.json"

drop_field "$CLEAN" "$TMP_ROOT/no-field.json" phase_18_status
SOURCE_DATE_EPOCH=$EPOCH_A check_case "field missing" 1 "missing field: phase_18_status" "$TMP_ROOT/no-field.json"

add_field "$CLEAN" "$TMP_ROOT/extra-field.json" monitoring_active
SOURCE_DATE_EPOCH=$EPOCH_A check_case "extra field monitoring_active" 1 "unexpected field: monitoring_active" "$TMP_ROOT/extra-field.json"

set_field "$CLEAN" "$TMP_ROOT/bad-status.json" phase_22_status '"DONE"'
SOURCE_DATE_EPOCH=$EPOCH_A check_case "unknown status" 1 "invalid status: phase_22_status" "$TMP_ROOT/bad-status.json"

set_field "$CLEAN" "$TMP_ROOT/path-value.json" last_locked_year '"2024/2025"'
SOURCE_DATE_EPOCH=$EPOCH_A check_case "path-like value" 1 "path-like value: last_locked_year" "$TMP_ROOT/path-value.json"

# WHY: the amount fixture is built at runtime so this tracked file holds no
# amount-shaped literal.
amount_json=$(printf '"%d.%03d,%02d"' 1 234 56)
set_field "$CLEAN" "$TMP_ROOT/amount-value.json" configured_start_date "$amount_json"
SOURCE_DATE_EPOCH=$EPOCH_A check_case "amount-like value" 1 "amount-like value: configured_start_date" "$TMP_ROOT/amount-value.json"

set_field "$CLEAN" "$TMP_ROOT/name-value.json" last_locked_year '"Book Year"'
SOURCE_DATE_EPOCH=$EPOCH_A check_case "name-like value" 1 "name-like value: last_locked_year" "$TMP_ROOT/name-value.json"

set_field "$CLEAN" "$TMP_ROOT/container-value.json" last_locked_year '{"year": 2024}'
SOURCE_DATE_EPOCH=$EPOCH_A check_case "--check rejects a nested object" 1 "invalid container value: last_locked_year" "$TMP_ROOT/container-value.json"

set_field "$CLEAN" "$TMP_ROOT/end-date-value.json" monitoring_end_date '"2026-02-30"'
SOURCE_DATE_EPOCH=$EPOCH_A check_case "--check rejects a non-date in monitoring_end_date" 1 "invalid date: monitoring_end_date" "$TMP_ROOT/end-date-value.json"

# WHY: two days on from the pinned write stamp is twice the default window.
SOURCE_DATE_EPOCH=$((EPOCH_A + 172800)) check_case "stale generated_at" 1 "stale generated_at" "$CLEAN"

# ───────────────────────────────────────────────────────────────
# 7. ROUTE STATE
# ───────────────────────────────────────────────────────────────

group "route state"

for key in $(route_case_list); do
    route_case "$key" "$EPOCH_A"
done

# ───────────────────────────────────────────────────────────────
# 8. ROUTE STATE STABILITY
# ───────────────────────────────────────────────────────────────

group "route state stability"

states_a=$(route_state_list "$EPOCH_A")
states_b=$(route_state_list "$EPOCH_B")
expected_states=$(printf '%s\n' pre_cutover monitoring_active monitoring_lapsed_phase22_open monitoring_active migration_complete gate_window_conflict gate_window_conflict)
if [[ "$states_a" = "$expected_states" ]] && [[ "$states_b" = "$expected_states" ]] && [[ "$states_a" = "$states_b" ]]; then
    pass "year stable"
else
    fail "year stable"
    printf '  first epoch: %s\n' "$(printf '%s' "$states_a" | tr '\n' ' ')"
    printf '  second epoch: %s\n' "$(printf '%s' "$states_b" | tr '\n' ' ')"
    show_output
fi

# ───────────────────────────────────────────────────────────────
# 9. DOCUMENTATION
# ───────────────────────────────────────────────────────────────

group "documentation"

hits=$(grep -E '\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b' "$AGENTS_MD" "$SKILL_MD" "$ROUTER_MD")
if [[ -z "$hits" ]]; then
    pass "no ISO date in AGENTS.md, SKILL.md or ROUTER.md"
else
    fail "no ISO date in AGENTS.md, SKILL.md or ROUTER.md"
    printf '%s\n' "$hits" | sed 's/^/  /'
fi

# ───────────────────────────────────────────────────────────────
# 10. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
