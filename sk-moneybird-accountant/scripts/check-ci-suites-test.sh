#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: CI SUITE REGISTRATION TEST
# ───────────────────────────────────────────────────────────────
# Tests check-ci-suites.py on fixture repositories built in the test. The
# fixtures hold suite files, a workflow with run lines in three shapes and
# mutants that remove a run line, add a suite with no run line and name a
# path in a step name only.
# Usage: check-ci-suites-test.sh [repository root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing checker files
#
# WHY: the check earns trust only when it fails on a suite that no run line
# names while it passes a block scalar, a chained command and the CLI
# runners, so this suite builds each case instead of reading the real
# workflow. The real workflow is a gate file, so the suite never needs it.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND CHECKER VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: check-ci-suites-test.sh [repository root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

CHECKER="$REPO_SRC/sk-moneybird-accountant/scripts/check-ci-suites.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-ci-suites.py in the repository\n' >&2
    exit 2
fi
PARSER="$REPO_SRC/sk-moneybird-accountant/scripts/check-regression-trailer.py"
if [[ ! -f "$PARSER" ]]; then
    printf 'error: missing scripts/check-regression-trailer.py in the repository\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/check-ci-suites-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

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

# Run the checker against one fixture repository and capture its output
# Args:
#   $1 - Repository root
# Returns:
#   The checker exit status, with output in $TMP_ROOT/out.txt
run_checker() {
    python3 -I "$CHECKER" --root "$1" >"$TMP_ROOT/out.txt" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 5. FIXTURE BUILDER
# ───────────────────────────────────────────────────────────────

FIX="$TMP_ROOT/fixture"

# Create one empty suite file under a fixture repository
# Args:
#   $1 - Repository root
#   $2 - Repo-relative suite path
# Returns:
#   0 when the file is written, 1 when a write fails
write_suite() {
    local path="$1/$2"
    mkdir -p "$(dirname "$path")" || return 1
    printf '#!/usr/bin/env bash\n# Fixture suite.\nexit 0\n' >"$path"
}

# Build the fixture repository with five suites and a workflow that runs them
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local root="$1"
    rm -rf "$root"
    write_suite "$root" "sk-moneybird-accountant/scripts/alpha-test.sh" || return 1
    write_suite "$root" "sk-moneybird-accountant/scripts/route-replay/replay-test.sh" || return 1
    write_suite "$root" "cli-moneybird/cli/moneybird-cli/tests/run-tests.sh" || return 1
    write_suite "$root" "cli-jortt/cli/jortt-cli/tests/run-tests.sh" || return 1
    write_suite "$root" "cli-moneybird/scripts/exit-code-parity-test.sh" || return 1
    mkdir -p "$root/.github/workflows" || return 1
    cat >"$root/.github/workflows/skill-health.yml" <<'YAML' || return 1
name: fixture-health

on: [push]

jobs:
  offline:
    runs-on: ubuntu-latest
    steps:
      - name: Alpha suite
        run: bash sk-moneybird-accountant/scripts/alpha-test.sh
      - name: Replay suite
        run: |
          python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve
          bash sk-moneybird-accountant/scripts/route-replay/replay-test.sh
      - name: CLI suites
        run: |
          bash cli-moneybird/cli/moneybird-cli/tests/run-tests.sh
          bash cli-jortt/cli/jortt-cli/tests/run-tests.sh
      - name: Exit code parity
        run: bash cli-moneybird/scripts/exit-code-parity.sh && bash cli-moneybird/scripts/exit-code-parity-test.sh
YAML
}

# ───────────────────────────────────────────────────────────────
# 6. FIXTURE CASES
# ───────────────────────────────────────────────────────────────

group "fixture suites"
if make_fixture "$FIX"; then
    pass "the fixture repository builds"
else
    fail "the fixture repository builds"
fi

run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]] && grep -q '^check-ci-suites: ok, 5 suites registered' "$TMP_ROOT/out.txt"; then
    pass "every fixture suite with a run line passes"
else
    fail "every fixture suite with a run line passes"
fi

if write_suite "$FIX" "sk-moneybird-accountant/scripts/beta-test.sh"; then
    run_checker "$FIX"
    status=$?
    if [[ "$status" -eq 1 ]] && grep -q '^missing-run sk-moneybird-accountant/scripts/beta-test.sh' "$TMP_ROOT/out.txt"; then
        pass "a suite with no run line fails and is named"
    else
        fail "a suite with no run line fails and is named"
    fi
else
    fail "a suite with no run line fails and is named"
fi

if make_fixture "$FIX" \
    && sed -i.bak '/alpha-test.sh/d' "$FIX/.github/workflows/skill-health.yml"; then
    run_checker "$FIX"
    status=$?
    if [[ "$status" -eq 1 ]] && grep -q '^missing-run sk-moneybird-accountant/scripts/alpha-test.sh' "$TMP_ROOT/out.txt"; then
        pass "a removed run line fails and names its suite"
    else
        fail "a removed run line fails and names its suite"
    fi
else
    fail "a removed run line fails and names its suite"
fi

if make_fixture "$FIX" \
    && write_suite "$FIX" "sk-moneybird-accountant/scripts/gamma-test.sh" \
    && sed -i.bak 's/^      - name: Alpha suite$/      - name: gamma-test.sh/' "$FIX/.github/workflows/skill-health.yml"; then
    run_checker "$FIX"
    status=$?
    if [[ "$status" -eq 1 ]] && grep -q '^missing-run sk-moneybird-accountant/scripts/gamma-test.sh' "$TMP_ROOT/out.txt"; then
        pass "a path in a step name alone does not register a suite"
    else
        fail "a path in a step name alone does not register a suite"
    fi
else
    fail "a path in a step name alone does not register a suite"
fi

if make_fixture "$FIX" \
    && write_suite "$FIX" "sk-moneybird-accountant/scripts/delta-test.sh" \
    && printf '      - name: Delta suite\n        run: bash sk-moneybird-accountant/scripts/delta-test.sh\n' >>"$FIX/.github/workflows/skill-health.yml"; then
    run_checker "$FIX"
    status=$?
    if [[ "$status" -eq 0 ]]; then
        pass "a suite added with its own run line passes"
    else
        fail "a suite added with its own run line passes"
    fi
else
    fail "a suite added with its own run line passes"
fi

# ───────────────────────────────────────────────────────────────
# 7. REFUSALS
# ───────────────────────────────────────────────────────────────

group "refusals"
if make_fixture "$FIX" && rm -f "$FIX/.github/workflows/skill-health.yml"; then
    run_checker "$FIX"
    status=$?
    if [[ "$status" -eq 2 ]] && grep -q 'missing .github/workflows/skill-health.yml' "$TMP_ROOT/out.txt"; then
        pass "a missing workflow exits 2 and names the file"
    else
        fail "a missing workflow exits 2 and names the file"
    fi
else
    fail "a missing workflow exits 2 and names the file"
fi

if python3 -I "$CHECKER" --root "$TMP_ROOT/no-such-root" >"$TMP_ROOT/out.txt" 2>&1; then
    fail "a missing root is refused"
else
    pass "a missing root is refused"
fi

# ───────────────────────────────────────────────────────────────
# 8. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
