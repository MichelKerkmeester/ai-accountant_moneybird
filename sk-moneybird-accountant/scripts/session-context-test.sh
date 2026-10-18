#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SESSION CONTEXT TEST
# ───────────────────────────────────────────────────────────────
# Tests build-session-context.py against temp fixture trees for the clock, the
# interactive flag, the config projection and the dashboard table.
# Usage: session-context-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the generated context decides the mode and the year, so a wrong clock or
# a leaked field must fail loudly. This suite proves each one does.
# WHY: the builder reads its config and dashboard from fixed paths under the
# repo root, so every case copies the script into its own fixture tree.
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

# The phase table every fixture dashboard holds unless a case brings its own
PHASE_TABLE='| Phase | Status |
|---|---|
| 12 | GATE PASSED |
| 17 | GATE PASSED |
| 18 | IN PROGRESS |
| 22 | NOT STARTED |'

# Write a fixture tree with the script at its real relative path, the config
# and the dashboard at the fixed paths the script reads
# Args:
#   $1 - Fixture root to create
#   $2 - Migration config JSON text
#   $3 - Dashboard markdown text, defaults to the shared phase table
# Returns:
#   0 when the tree is written, 1 when a write fails
make_fixture() {
    local root="$1" config="$2" dashboard="${3:-$PHASE_TABLE}"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/migration-workspace/Plans" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '%s\n' "$dashboard" >"$root/migration-workspace/Plans/phase-dashboard.md" || return 1
    printf '%s\n' "$config" >"$root/migration-workspace/MIGRATION_CONFIG.json" || return 1
    return 0
}

# Run the builder copy of a fixture tree and capture its combined output
# Args:
#   $1 - Fixture root
run_builder() {
    python3 -I "$1/sk-moneybird-accountant/scripts/build-session-context.py" >"$TMP_ROOT/out.txt" 2>&1
}

# Run the builder copy with stdout and stderr kept apart
# Args:
#   $1 - Fixture root
run_builder_split() {
    python3 -I "$1/sk-moneybird-accountant/scripts/build-session-context.py" >"$TMP_ROOT/out.txt" 2>"$TMP_ROOT/err.txt"
}

# Run the builder copy with a pseudo terminal on stdin
# Args:
#   $1 - Fixture root
# Returns:
#   The builder exit status
run_builder_on_terminal() {
    python3 -I - "$1/sk-moneybird-accountant/scripts/build-session-context.py" >"$TMP_ROOT/out.txt" 2>&1 <<'PY'
import os
import pty
import subprocess
import sys

master, slave = pty.openpty()
try:
    status = subprocess.run([sys.executable, "-I", sys.argv[1]], stdin=slave).returncode
finally:
    os.close(master)
    os.close(slave)
sys.exit(status)
PY
}

# ───────────────────────────────────────────────────────────────
# 5. CLOCK, INTERACTIVE AND WRITE MODE
# ───────────────────────────────────────────────────────────────

BASE_DIR="$TMP_ROOT/base"
CONTEXT="$BASE_DIR/session-context.json"

# WHY: the pinned stamp is computed from a date so this tracked file holds no
# long digit run.
EPOCH_A=$(epoch_from_date 2026-01-01)
if [[ -z "$EPOCH_A" ]]; then
    printf 'error: cannot compute the pinned epoch\n' >&2
    exit 2
fi
EPOCH_TEXT_A=$(utc_from_epoch "$EPOCH_A")

# WHY: the config template stores each field as a row in a fields list, and a
# cell nobody filled in yet holds PENDING.
BASE_CONFIG='{"config_version": 1, "status": "DRAFT", "fields": [{"field": "configured_start_date", "value": "2019-01-01"}, {"field": "last_locked_year", "value": 2024}, {"field": "monitoring.start_date", "value": "2026-01-05"}, {"field": "monitoring.end_date", "value": "2026-02-05"}]}'
make_fixture "$BASE_DIR" "$BASE_CONFIG" || exit 2

group "clock and interactive"

SOURCE_DATE_EPOCH=$EPOCH_A run_builder "$BASE_DIR"
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

run_builder "$BASE_DIR"
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" clock_source)" = "runtime" ]]; then
    pass "clock runtime"
else
    fail "clock runtime"
    printf '  exit %s, clock_source %s\n' "$status" "$(context_field "$CONTEXT" clock_source)"
fi

SOURCE_DATE_EPOCH=abc run_builder_split "$BASE_DIR"
status=$?
if [[ "$status" -eq 3 ]] && grep -Fq 'clock_missing' "$TMP_ROOT/err.txt" && [[ ! -s "$TMP_ROOT/out.txt" ]]; then
    pass "clock missing"
else
    fail "clock missing"
    printf '  exit %s, stderr: %s\n' "$status" "$(tr '\n' ' ' <"$TMP_ROOT/err.txt")"
fi

CI=1 run_builder "$BASE_DIR"
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" interactive)" = "false" ]]; then
    pass "interactive false under CI"
else
    fail "interactive false under CI"
    printf '  exit %s, interactive %s\n' "$status" "$(context_field "$CONTEXT" interactive)"
fi

CI= run_builder "$BASE_DIR" <&-
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" interactive)" = "false" ]]; then
    pass "interactive false with stdin closed"
else
    fail "interactive false with stdin closed"
    printf '  exit %s, interactive %s\n' "$status" "$(context_field "$CONTEXT" interactive)"
fi

run_builder_on_terminal "$BASE_DIR"
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(context_field "$CONTEXT" interactive)" = "true" ]]; then
    pass "interactive true on a terminal"
else
    fail "interactive true on a terminal"
    printf '  exit %s, interactive %s\n' "$status" "$(context_field "$CONTEXT" interactive)"
fi

group "config projection"

# WHY: a config date field holding a path must be dropped rather than copied.
PATHDATE_DIR="$TMP_ROOT/path-date"
make_fixture "$PATHDATE_DIR" \
    '{"fields": [{"field": "configured_start_date", "value": "migration-workspace/2026"}, {"field": "last_locked_year", "value": 2024}, {"field": "monitoring.start_date", "value": "2026-01-05"}, {"field": "monitoring.end_date", "value": "2026-02-05"}]}' \
    || exit 2
SOURCE_DATE_EPOCH=$EPOCH_A run_builder "$PATHDATE_DIR"
write_status=$?
path_date=$(context_field "$PATHDATE_DIR/session-context.json" configured_start_date)
if [[ "$write_status" -eq 0 ]] && [[ "$path_date" = "null" ]]; then
    pass "date field holding a path is dropped"
else
    fail "date field holding a path is dropped"
    printf '  write exit %s, configured_start_date %s\n' "$write_status" "$path_date"
fi

# WHY: a config year field holding an object must be dropped as well.
NESTED_DIR="$TMP_ROOT/nested-year"
make_fixture "$NESTED_DIR" \
    '{"fields": [{"field": "configured_start_date", "value": "2019-01-01"}, {"field": "last_locked_year", "value": {"year": 2024}}, {"field": "monitoring.start_date", "value": "2026-01-05"}, {"field": "monitoring.end_date", "value": "2026-02-05"}]}' \
    || exit 2
SOURCE_DATE_EPOCH=$EPOCH_A run_builder "$NESTED_DIR"
write_status=$?
locked_year=$(context_field "$NESTED_DIR/session-context.json" last_locked_year)
if [[ "$write_status" -eq 0 ]] && [[ "$locked_year" = "null" ]]; then
    pass "nested object in last_locked_year is dropped"
else
    fail "nested object in last_locked_year is dropped"
    printf '  write exit %s, last_locked_year %s\n' "$write_status" "$locked_year"
fi

# WHY: a filled fields row must reach the projection and a placeholder must
# read as null.
TEMPLATE_DIR="$TMP_ROOT/template-shape"
make_fixture "$TEMPLATE_DIR" \
    '{"config_version": 1, "status": "DRAFT", "fields": [{"field": "configured_start_date", "value": "2019-01-01"}, {"field": "last_locked_year", "value": 2024}, {"field": "monitoring.start_date", "value": "2026-01-05"}, {"field": "monitoring.end_date", "value": "PENDING"}]}' \
    || exit 2
TEMPLATE_OUT="$TEMPLATE_DIR/session-context.json"
SOURCE_DATE_EPOCH=$EPOCH_A run_builder "$TEMPLATE_DIR"
write_status=$?
if [[ "$write_status" -eq 0 ]] \
    && [[ "$(context_field "$TEMPLATE_OUT" configured_start_date)" = "2019-01-01" ]] \
    && [[ "$(context_field "$TEMPLATE_OUT" last_locked_year)" = "2024" ]] \
    && [[ "$(context_field "$TEMPLATE_OUT" monitoring_start_date)" = "2026-01-05" ]] \
    && [[ "$(context_field "$TEMPLATE_OUT" monitoring_end_date)" = "null" ]]; then
    pass "template fields rows reach the projection and PENDING reads as null"
else
    fail "template fields rows reach the projection and PENDING reads as null"
    printf '  write exit %s, configured_start_date %s, last_locked_year %s, monitoring_start_date %s, monitoring_end_date %s\n' \
        "$write_status" "$(context_field "$TEMPLATE_OUT" configured_start_date)" \
        "$(context_field "$TEMPLATE_OUT" last_locked_year)" "$(context_field "$TEMPLATE_OUT" monitoring_start_date)" \
        "$(context_field "$TEMPLATE_OUT" monitoring_end_date)"
fi

# WHY: init-workspace.sh copies the generated markdown dashboard, so the builder
# must read its phase table, where a status cell is written with a space.
MARKDOWN_DIR="$TMP_ROOT/markdown-dashboard"
make_fixture "$MARKDOWN_DIR" "$BASE_CONFIG" || exit 2
python3 -I - "$SKILL_SRC/assets/migration/phase-dashboard.template.md" "$MARKDOWN_DIR/migration-workspace/Plans/phase-dashboard.md" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
text = re.sub(r"^(\| 12 \|[^|]*\|) NOT STARTED \|", r"\1 GATE PASSED |", text, count=1, flags=re.M)
text = re.sub(r"^(\| 18 \|[^|]*\|) NOT STARTED \|", r"\1 IN PROGRESS |", text, count=1, flags=re.M)
open(sys.argv[2], "w", encoding="utf-8").write(text)
PY
MARKDOWN_OUT="$MARKDOWN_DIR/session-context.json"
SOURCE_DATE_EPOCH=$EPOCH_A run_builder "$MARKDOWN_DIR"
write_status=$?
if [[ "$write_status" -eq 0 ]] \
    && [[ "$(context_field "$MARKDOWN_OUT" phase_18_status)" = "IN_PROGRESS" ]] \
    && [[ "$(context_field "$MARKDOWN_OUT" phase_22_status)" = "NOT_STARTED" ]] \
    && [[ "$(context_field "$MARKDOWN_OUT" last_passed_gate)" = "12" ]]; then
    pass "the markdown dashboard table reaches the projection"
else
    fail "the markdown dashboard table reaches the projection"
    printf '  write exit %s, phase_18_status %s, phase_22_status %s, last_passed_gate %s\n' \
        "$write_status" "$(context_field "$MARKDOWN_OUT" phase_18_status)" \
        "$(context_field "$MARKDOWN_OUT" phase_22_status)" "$(context_field "$MARKDOWN_OUT" last_passed_gate)"
fi

# ───────────────────────────────────────────────────────────────
# 6. DOCUMENTATION
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
# 7. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
