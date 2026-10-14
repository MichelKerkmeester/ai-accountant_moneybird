#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: OUTLINE CHECK TEST
# ───────────────────────────────────────────────────────────────
# Tests outline-check.py against a fixture repository, the real corpus
# and a seeded decision step in a copy of the real tree.
# Usage: outline-check-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the carry-forward rule earns trust only when the checker accepts the
# real tree and rejects every decision step that names no branch. This suite
# proves both, on a fixture of its own and on the corpus the checker guards.
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
    printf 'error: usage: outline-check-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

CHECKER="$SKILL_SRC/scripts/outline-check.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/outline-check.py in the skill folder\n' >&2
    exit 2
fi

REPO_ROOT=$(dirname "$SKILL_SRC")

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/outline-check-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture or tree copy survives the run
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

# Run a command as a check and record whether it passes
# Args:
#   $1 - Check description
#   $2... - Command and arguments to run
assert() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

# Run the checker against one repository and capture its output
# Args:
#   $1 - Repository root
# Returns:
#   The checker exit status, with output in $TMP_ROOT/out.txt
run_checker() {
    python3 -I "$CHECKER" --root "$1" >"$TMP_ROOT/out.txt" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 5. FIXTURE BUILDERS AND FIXTURE HELPERS
# ───────────────────────────────────────────────────────────────

FIX="$TMP_ROOT/fixture"
FIX_RULES="$FIX/sk-moneybird-accountant/references/tax-rules"

# Write one markdown file below the fixture tax-rules tree
# Args:
#   $1 - Path below the fixture tax-rules root
#   $2 - File content
# Returns:
#   0 when the file is written, 1 when a write fails
write_fixture_file() {
    local path="$FIX_RULES/$1"
    mkdir -p "$(dirname "$path")" || return 1
    printf '%s' "$2" >"$path" || return 1
}

# Write the fixture topic files the checks read and the two files they skip
# Args:
#   $1 - Repository root
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local root="$1"
    FIX="$root"
    FIX_RULES="$FIX/sk-moneybird-accountant/references/tax-rules"
    write_fixture_file "2026/vat/notes.md" '# Notes 2026

## 6. IN THE BOOKS

<a id="6-in-the-books"></a>

- Keep the records that support the return.
' || return 1
    write_fixture_file "2026/box-3/rules.md" '# Rules 2026

## 3. HOW IT WORKS

The band method applies to the year.
' || return 1
    write_fixture_file "2026/income-tax.md" '# Income tax 2026

## 3. HOW IT WORKS

The brackets apply to the year.
' || return 1
    write_fixture_file "2026/README.md" '# Tax year 2026

## 1. OVERVIEW

The year overview.
' || return 1
    write_fixture_file "general/vat.md" '# VAT

The general VAT rules.
' || return 1
    write_fixture_file "README.md" '# Tax rules

The cross-year index.
' || return 1
    return 0
}

# Append one step to one fixture file and run the checker
# Args:
#   $1 - Check description
#   $2 - Path below the fixture tax-rules root
#   $3 - Step line to append
#   $4 - "reject" when the checker must fail and name the step, "pass" when
#        the checker must accept the tree
# Returns:
#   0, printing one report line
check_step() {
    local description="$1"
    local path="$2"
    local step="$3"
    local expected="$4"
    # WHY: every case starts from the pristine fixture, so a rejected step
    # left by an earlier case never leaks into the next one.
    rm -rf "$FIX_RULES"
    cp -R "$TMP_ROOT/fixture-pristine/sk-moneybird-accountant/references/tax-rules" "$FIX_RULES"
    printf '\n%s\n' "$step" >>"$FIX_RULES/$path"
    run_checker "$FIX"
    local status=$?
    if [[ "$expected" = "pass" ]]; then
        if [[ "$status" -eq 0 ]]; then
            pass "$description"
        else
            fail "$description"
        fi
    elif [[ "$status" -eq 1 ]] && grep -qF "no-alternative-branch" "$TMP_ROOT/out.txt" \
        && grep -qF "$path:" "$TMP_ROOT/out.txt"; then
        pass "$description"
    else
        fail "$description"
        cat "$TMP_ROOT/out.txt"
    fi
}

# ───────────────────────────────────────────────────────────────
# 6. DECISION STEPS ON THE FIXTURE
# ───────────────────────────────────────────────────────────────

group "decision steps on the fixture"
if make_fixture "$TMP_ROOT/fixture"; then
    pass "fixture repository builds"
else
    fail "fixture repository builds"
fi
if cp -R "$FIX" "$TMP_ROOT/fixture-pristine"; then
    pass "a pristine copy of the fixture builds"
else
    fail "a pristine copy of the fixture builds"
fi

run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'outline-check: 0 decision steps, 0 without an alternative branch' "$TMP_ROOT/out.txt"; then
    pass "the fixture corpus is clean"
else
    fail "the fixture corpus is clean"
    cat "$TMP_ROOT/out.txt"
fi

check_step "a question step with no branch is rejected" \
    "2026/vat/notes.md" "- Does the cost straddle the period boundary?" reject
check_step "a question step with an if-not branch passes" \
    "2026/vat/notes.md" "- Does the cost straddle the period boundary? If not, book it as an ordinary cost." pass
check_step "a question step with an otherwise branch passes" \
    "2026/vat/notes.md" "- Is the asset still in use at year end? Otherwise take the full deduction." pass
check_step "a question step with a Dutch branch marker passes" \
    "2026/vat/notes.md" "- Is the invoice in the period? Anders schuift de kost door naar het volgende jaar." pass
check_step "a decision lead step with no branch is rejected" \
    "2026/vat/notes.md" "- Decide whether the cost is a business cost." reject
check_step "a decision lead step with a default branch passes" \
    "2026/vat/notes.md" "- Decide whether the cost is a business cost. By default it stays private." pass
check_step "a numbered decision step with no branch is rejected" \
    "2026/box-3/rules.md" "2. Does the asset count as overige bezittingen?" reject
check_step "a step with no question and no lead is not a decision step" \
    "2026/box-3/rules.md" "- Keep the peildatum value in the records." pass
check_step "a decision step in a second part is read" \
    "2026/box-3/rules.md" "- Is the asset still in use at year end?" reject
check_step "a decision step in a flat year topic file is read" \
    "2026/income-tax.md" "- Is the taxpayer an ondernemer for the year?" reject
check_step "a decision step in a general topic file is read" \
    "general/vat.md" "- Is the supply exempt from VAT?" reject
check_step "a decision step in a year README is not read" \
    "2026/README.md" "- Is the year settled?" pass
check_step "a decision step in the tax-rules index is not read" \
    "README.md" "- Is the year in range?" pass
check_step "a question inside a link target is not a decision step" \
    "2026/vat/notes.md" "- Read [the page](https://example.invalid/help?q=vat) for the rate." pass
check_step "a question inside a fenced block is not a decision step" \
    "2026/vat/notes.md" '```text
- Does the cost straddle the period boundary?
```' pass

# ───────────────────────────────────────────────────────────────
# 7. REFUSED ROOTS
# ───────────────────────────────────────────────────────────────

group "refused roots"
run_checker "$TMP_ROOT/absent"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a repository without the tax-rules tree is refused"
else
    fail "a repository without the tax-rules tree is refused"
fi

EMPTY="$TMP_ROOT/empty"
mkdir -p "$EMPTY/sk-moneybird-accountant/references"
run_checker "$EMPTY"
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "an empty references folder is refused"
else
    fail "an empty references folder is refused"
fi

# ───────────────────────────────────────────────────────────────
# 8. REAL CORPUS
# ───────────────────────────────────────────────────────────────

group "real corpus"
assert "the real corpus is clean" python3 -I "$CHECKER" --root "$REPO_ROOT" --check

# ───────────────────────────────────────────────────────────────
# 9. SEEDED DECISION STEP IN A COPY OF THE REAL TREE
# ───────────────────────────────────────────────────────────────

group "seeded decision step in a copy"
COPY="$TMP_ROOT/real-copy"
mkdir -p "$COPY/sk-moneybird-accountant" || true
# WHY: the checker reads the tax-rules tree only, so the copy carries that
# tree and nothing else of the repository.
cp -R "$SKILL_SRC/references" "$COPY/sk-moneybird-accountant/references" || true
SEEDED="$COPY/sk-moneybird-accountant/references/tax-rules/2025/vat/notes.md"
if [[ -f "$SEEDED" ]]; then
    pass "a temp copy of the real tax-rules tree builds"
else
    fail "a temp copy of the real tax-rules tree builds"
fi

printf '\n- Does the cost straddle the period boundary?\n' >>"$SEEDED"
run_checker "$COPY"
status=$?
if [[ "$status" -eq 1 ]] && grep -qF '2025/vat/notes.md' "$TMP_ROOT/out.txt" \
    && grep -qF 'no-alternative-branch' "$TMP_ROOT/out.txt" \
    && grep -qF 'Does the cost straddle the period boundary?' "$TMP_ROOT/out.txt"; then
    pass "a seeded decision step in a copy fails the check and names the step"
else
    fail "a seeded decision step in a copy fails the check and names the step"
    cat "$TMP_ROOT/out.txt"
fi

run_checker "$REPO_ROOT"
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "the real tree stays clean after the seeded copy case"
else
    fail "the real tree stays clean after the seeded copy case"
fi

# ───────────────────────────────────────────────────────────────
# 10. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
