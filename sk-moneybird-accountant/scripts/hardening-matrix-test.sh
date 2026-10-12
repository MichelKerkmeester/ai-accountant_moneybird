#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: HARDENING MATRIX TEST
# ───────────────────────────────────────────────────────────────
# Tests check-hardening-matrix.py on the real matrix, on a fixture copy whose
# P0 test paths and case strings are present, on a copy with one P0 test path
# removed, on a copy with one P0 test cell blanked and on a copy with one P0
# case string renamed. Each mutated copy must fail the check and name the row.
# Usage: hardening-matrix-test.sh [repo root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing matrix files
#
# WHY: the coverage check only guards the matrix when it passes a complete
# fixture and fails a fixture with one P0 path missing, so this suite builds
# both from the real matrix.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS AND ARGUMENT VALIDATION
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: hardening-matrix-test.sh [repo root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

CHECKER="$REPO_SRC/sk-moneybird-accountant/scripts/check-hardening-matrix.py"
MATRIX="$REPO_SRC/sk-moneybird-accountant/hardening-matrix.md"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-hardening-matrix.py in the repository\n' >&2
    exit 2
fi
if [[ ! -f "$MATRIX" ]]; then
    printf 'error: missing hardening-matrix.md in the skill folder\n' >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf 'error: python3 is not available\n' >&2
    exit 2
fi

# Keep the run away from agent markers and credentials, the way run-tests.sh does
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX || true
unset MONEYBIRD_HMAC_KEY_FILE MONEYBIRD_PILOT_ADMINISTRATION_ID || true
unset MONEYBIRD_GUARD_READ_ONLY || true

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/hardening-matrix-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 3. TEST HELPERS AND FIXTURE BUILDERS
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

# Run the check against a fixture root and capture its output
# Args:
#   $1 - Repository root to check
#   $2 - Tag for the captured output file under the temp root
# Returns:
#   The checker exit status
run_checker() {
    python3 -I "$CHECKER" --check --root "$1" >"$TMP_ROOT/check-$2.txt" 2>&1
}

# List one tab-separated line per matrix row: priority, test path, test cell
python3 -I - "$MATRIX" > "$TMP_ROOT/rows.tsv" <<'PY'
import sys

text = open(sys.argv[1], encoding="utf-8").read()
for line in text.splitlines():
    line = line.strip()
    if not (line.startswith("|") and line.endswith("|")):
        continue
    cells = [cell.strip() for cell in line.strip("|").split("|")]
    if len(cells) != 7 or cells[2] not in ("P0", "P1", "P2"):
        continue
    cell = cells[4]
    if len(cell) >= 2 and cell.startswith("`") and cell.endswith("`"):
        cell = cell[1:-1].strip()
    if " :: " not in cell:
        continue
    path = cell.split(" :: ", 1)[0].strip()
    print("%s\t%s\t%s" % (cells[2], path, cell))
PY

FIRST_P0_PATH=$(awk -F'\t' '$1 == "P0" { print $2; exit }' "$TMP_ROOT/rows.tsv")
FIRST_P0_CELL=$(awk -F'\t' '$1 == "P0" { print $3; exit }' "$TMP_ROOT/rows.tsv")
if [[ -z "$FIRST_P0_PATH" ]] || [[ -z "$FIRST_P0_CELL" ]]; then
    printf 'error: no P0 row with a test path in the matrix\n' >&2
    exit 2
fi

# Build a fixture root: the matrix plus every named test path that exists
# Args:
#   $1 - Target root to create
# Returns:
#   0 when the copy is complete, 1 otherwise
build_fixture() {
    local root="$1"
    local _priority path _cell
    mkdir -p "$root/sk-moneybird-accountant" || return 1
    cp "$MATRIX" "$root/sk-moneybird-accountant/hardening-matrix.md" || return 1
    while IFS=$'\t' read -r _priority path _cell; do
        [[ -n "$path" ]] || continue
        [[ -f "$REPO_SRC/$path" ]] || continue
        mkdir -p "$root/$(dirname "$path")" || return 1
        cp "$REPO_SRC/$path" "$root/$path" || return 1
    done < "$TMP_ROOT/rows.tsv"
    return 0
}

# ───────────────────────────────────────────────────────────────
# 4. REAL TREE AND FIXTURE COPY CHECKS
# ───────────────────────────────────────────────────────────────

group "Real tree"

if run_checker "$REPO_SRC" real && grep -qF 'hardening-matrix: ok' "$TMP_ROOT/check-real.txt"; then
    pass "the real matrix passes the check"
else
    fail "the real matrix passes the check"
    sed -n '1,5p' "$TMP_ROOT/check-real.txt"
fi

group "Fixture copy"

FIXTURE="$TMP_ROOT/fixture"
if build_fixture "$FIXTURE"; then
    pass "the fixture copy builds"
else
    fail "the fixture copy builds"
fi

if run_checker "$FIXTURE" fixture && grep -qF 'hardening-matrix: ok' "$TMP_ROOT/check-fixture.txt"; then
    pass "the fixture copy passes the check"
else
    fail "the fixture copy passes the check"
    sed -n '1,5p' "$TMP_ROOT/check-fixture.txt"
fi

# ───────────────────────────────────────────────────────────────
# 5. REMOVED TEST PATH
# ───────────────────────────────────────────────────────────────

group "Removed test path"

rm -f "$FIXTURE/$FIRST_P0_PATH"
run_checker "$FIXTURE" removed
status=$?
if [[ "$status" -eq 1 ]] && grep -qF "$FIRST_P0_PATH" "$TMP_ROOT/check-removed.txt"; then
    pass "a removed P0 test path fails the check and names the path"
else
    fail "a removed P0 test path fails the check and names the path (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-removed.txt"
fi

# ───────────────────────────────────────────────────────────────
# 6. BLANKED P0 TEST CELL
# ───────────────────────────────────────────────────────────────

group "Blanked P0 test cell"

BLANK="$TMP_ROOT/fixture-blank"
if build_fixture "$BLANK"; then
    pass "the blank fixture copy builds"
else
    fail "the blank fixture copy builds"
fi

python3 -I - "$BLANK/sk-moneybird-accountant/hardening-matrix.md" "$FIRST_P0_CELL" <<'PY'
import sys

path = sys.argv[1]
cell = "`%s`" % sys.argv[2]
text = open(path, encoding="utf-8").read()
if cell not in text:
    print("error: the fixture matrix does not hold the expected test cell", file=sys.stderr)
    sys.exit(2)
open(path, "w", encoding="utf-8").write(text.replace(cell, "`-`", 1))
PY
blank_status=$?
if [[ "$blank_status" -ne 0 ]]; then
    fail "the P0 test cell is blanked in the fixture copy (exit $blank_status)"
fi

run_checker "$BLANK" blank
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'P0 row needs a test path' "$TMP_ROOT/check-blank.txt"; then
    pass "a blanked P0 test cell fails the check"
else
    fail "a blanked P0 test cell fails the check (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-blank.txt"
fi

# ───────────────────────────────────────────────────────────────
# 7. MISSING CASE STRING
# ───────────────────────────────────────────────────────────────

group "Missing case string"

MISSING_CASE="$TMP_ROOT/fixture-missing-case"
if build_fixture "$MISSING_CASE"; then
    pass "the missing-case fixture copy builds"
else
    fail "the missing-case fixture copy builds"
fi

FIRST_P0_CASE="${FIRST_P0_CELL#* :: }"
python3 -I - "$MISSING_CASE/$FIRST_P0_PATH" "$FIRST_P0_CASE" <<'PY'
import sys

path = sys.argv[1]
case = sys.argv[2]
text = open(path, encoding="utf-8").read()
if case not in text:
    print("error: the fixture copy does not hold the expected case", file=sys.stderr)
    sys.exit(2)
open(path, "w", encoding="utf-8").write(text.replace(case, "case-renamed-in-fixture"))
PY
case_status=$?
if [[ "$case_status" -ne 0 ]]; then
    fail "the case string is renamed in the fixture copy (exit $case_status)"
fi

run_checker "$MISSING_CASE" missing-case
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'test case not found' "$TMP_ROOT/check-missing-case.txt" && grep -qF "$FIRST_P0_CASE" "$TMP_ROOT/check-missing-case.txt"; then
    pass "a renamed case string fails the check and names the case"
else
    fail "a renamed case string fails the check and names the case (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/check-missing-case.txt"
fi

# ───────────────────────────────────────────────────────────────
# 8. USAGE GUARDS
# ───────────────────────────────────────────────────────────────

group "Usage guards"

python3 -I "$CHECKER" --check --root "$TMP_ROOT/no-such-root" >/dev/null 2>&1
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a missing root is refused with exit 2"
else
    fail "a missing root is refused with exit 2 (exit $status)"
fi

# ───────────────────────────────────────────────────────────────
# 9. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
