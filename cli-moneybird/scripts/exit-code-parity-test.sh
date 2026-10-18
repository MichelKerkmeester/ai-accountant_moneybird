#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: EXIT CODE PARITY TEST
# ───────────────────────────────────────────────────────────────
# Tests exit-code-parity.sh on a clean copy and on six mutated copies.
# Usage: exit-code-parity-test.sh
# Exit Codes:
#   0 - All cases pass
#   1 - One or more cases fail
#   2 - Invalid arguments or missing input files
#
# WHY: a parity check that cannot fail proves nothing, so each case copies the script
# and the files it reads into a throwaway tree and requires the expected verdict. The
# mutants cover a deleted table row, a deleted gate ladder code, an added table
# row, a missing keyword code, a missing flag keyword and a documentation file
# with no exit rows.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS AND ARGUMENTS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 2
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd -P) || exit 2
PARITY_REL="cli-moneybird/scripts/exit-code-parity.sh"

if [[ "$#" -gt 0 ]]; then
    printf 'error: usage: exit-code-parity-test.sh\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. INPUT FILES
# ───────────────────────────────────────────────────────────────

# The parity check finds its root from its own location, so a fixture copies the
# script beside exactly the files it reads
COPY_FILES=(
    "$PARITY_REL"
    "cli-moneybird/cli/moneybird-cli/moneybird-guard"
    "cli-moneybird/references/cli.md"
    "cli-moneybird/references/troubleshooting.md"
    "cli-moneybird/SKILL.md"
    "cli-moneybird/ROUTER.md"
)

for rel in "${COPY_FILES[@]}"; do
    if [[ ! -f "$ROOT/$rel" ]]; then
        printf 'error: missing %s under %s\n' "$rel" "$ROOT" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/exit-code-parity-test.XXXXXX") || exit 2

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

# Copy the parity script and the files it reads into a throwaway root
# Args:
#   $1 - Fixture root to create
# Returns:
#   0 when every copy succeeds, 1 otherwise
build_fixture() {
    local root="$1"
    local rel
    for rel in "${COPY_FILES[@]}"; do
        mkdir -p "$root/$(dirname "$rel")" || return 1
        cp "$ROOT/$rel" "$root/$rel" || return 1
    done
    return 0
}

# Run the parity check against a fixture root
# Args:
#   $1 - Fixture root
#   $2 - Tag for the captured output file under the temp root
# Returns:
#   The parity check exit status
run_parity() {
    bash "$1/$PARITY_REL" >"$TMP_ROOT/parity-$2.txt" 2>&1
}

# Delete one keyword token from the TROUBLESHOOT line in a copied ROUTER.md
# Args:
#   $1 - Path to the copied ROUTER.md
#   $2 - Token to delete with its quotes and comma, such as "exit 2", 
# Returns:
#   0 when the edited file is written, 1 when the token is not found or awk fails
remove_keyword() {
    local doc="$1"
    local token="$2"
    if awk -v token="$token" '
        /TROUBLESHOOT/ && /keywords/ && index($0, token) { gsub(token, ""); changed = 1 }
        { print }
        END { if (changed != 1) exit 1 }
    ' "$doc" >"$TMP_ROOT/skill-edit.txt"; then
        cp "$TMP_ROOT/skill-edit.txt" "$doc"
        return 0
    fi
    return 1
}

# Delete every line of a copied document that matches an extended regex
# Args:
#   $1 - Path to the copied document
#   $2 - Extended regex for the lines to delete
# Returns:
#   0 when the edited file is written, 1 when no line matched or awk fails
delete_lines() {
    local doc="$1"
    local pattern="$2"
    if awk -v pattern="$pattern" '
        $0 ~ pattern { removed = 1
                       next }
        { print }
        END { if (removed != 1) exit 1 }
    ' "$doc" >"$TMP_ROOT/doc-edit.txt"; then
        cp "$TMP_ROOT/doc-edit.txt" "$doc"
        return 0
    fi
    return 1
}

# Add one row after the first line of a copied document that matches an anchor
# Args:
#   $1 - Path to the copied document
#   $2 - Extended regex for the anchor line
#   $3 - Row text to add below the anchor line
# Returns:
#   0 when the edited file is written, 1 when the anchor is not found or awk fails
add_row_after() {
    local doc="$1"
    local anchor="$2"
    local row="$3"
    if awk -v anchor="$anchor" -v row="$row" '
        { print }
        $0 ~ anchor && !added { print row; added = 1 }
        END { if (added != 1) exit 1 }
    ' "$doc" >"$TMP_ROOT/doc-edit.txt"; then
        cp "$TMP_ROOT/doc-edit.txt" "$doc"
        return 0
    fi
    return 1
}

# ───────────────────────────────────────────────────────────────
# 5. PARITY CASES
# ───────────────────────────────────────────────────────────────

group "Unmodified copy"

FIXTURE_1="$TMP_ROOT/case-1"
if build_fixture "$FIXTURE_1"; then
    run_parity "$FIXTURE_1" 1
    status_1=$?
    if [[ "$status_1" -eq 0 ]]; then
        pass "the unmodified copy passes"
    else
        fail "the unmodified copy passes"
        sed -n '1,5p' "$TMP_ROOT/parity-1.txt"
    fi
else
    fail "the unmodified copy passes (fixture copy failed)"
fi

group "Mutated copies"

FIXTURE_2="$TMP_ROOT/case-2"
if ! build_fixture "$FIXTURE_2"; then
    fail "a deleted table row is caught and names exit 6 (fixture copy failed)"
else
    DOC_2="$FIXTURE_2/cli-moneybird/references/cli.md"
    if grep -v '^| 6 |' "$DOC_2" >"$TMP_ROOT/cli-2.md"; then
        cp "$TMP_ROOT/cli-2.md" "$DOC_2"
        run_parity "$FIXTURE_2" 2
        status_2=$?
        if [[ "$status_2" -ne 0 ]] && grep -q 'missing exit 6' "$TMP_ROOT/parity-2.txt"; then
            pass "a deleted table row is caught and names exit 6"
        else
            fail "a deleted table row is caught and names exit 6"
            sed -n '1,5p' "$TMP_ROOT/parity-2.txt"
        fi
    else
        fail "a deleted table row is caught and names exit 6 (table row not found)"
    fi
fi

FIXTURE_3="$TMP_ROOT/case-3"
if ! build_fixture "$FIXTURE_3"; then
    fail "a removed keyword code is caught and names exit 2 (fixture copy failed)"
else
    DOC_3="$FIXTURE_3/cli-moneybird/ROUTER.md"
    if remove_keyword "$DOC_3" '"exit 2", '; then
        run_parity "$FIXTURE_3" 3
        status_3=$?
        if [[ "$status_3" -ne 0 ]] && grep -q 'missing exit 2 in cli-moneybird/ROUTER.md TROUBLESHOOT keywords' "$TMP_ROOT/parity-3.txt"; then
            pass "a removed keyword code is caught and names exit 2"
        else
            fail "a removed keyword code is caught and names exit 2"
            sed -n '1,5p' "$TMP_ROOT/parity-3.txt"
        fi
    else
        fail "a removed keyword code is caught and names exit 2 (keyword edit failed)"
    fi
fi

FIXTURE_4="$TMP_ROOT/case-4"
if ! build_fixture "$FIXTURE_4"; then
    fail "a removed --print-body keyword is caught (fixture copy failed)"
else
    DOC_4="$FIXTURE_4/cli-moneybird/ROUTER.md"
    if remove_keyword "$DOC_4" '"--print-body", '; then
        run_parity "$FIXTURE_4" 4
        status_4=$?
        if [[ "$status_4" -ne 0 ]] && grep -q 'missing --print-body in cli-moneybird/ROUTER.md TROUBLESHOOT keywords' "$TMP_ROOT/parity-4.txt"; then
            pass "a removed --print-body keyword is caught"
        else
            fail "a removed --print-body keyword is caught"
            sed -n '1,5p' "$TMP_ROOT/parity-4.txt"
        fi
    else
        fail "a removed --print-body keyword is caught (keyword edit failed)"
    fi
fi

FIXTURE_5="$TMP_ROOT/case-5"
if ! build_fixture "$FIXTURE_5"; then
    fail "a removed ladder code is caught and names exit 5 in the gate ladder (fixture copy failed)"
else
    DOC_5="$FIXTURE_5/cli-moneybird/SKILL.md"
    if delete_lines "$DOC_5" 'outside migration-workspace or through a symlink'; then
        run_parity "$FIXTURE_5" 5
        status_5=$?
        if [[ "$status_5" -ne 0 ]] && grep -q 'missing exit 5 in gate ladder' "$TMP_ROOT/parity-5.txt"; then
            pass "a removed ladder code is caught and names exit 5 in the gate ladder"
        else
            fail "a removed ladder code is caught and names exit 5 in the gate ladder"
            sed -n '1,5p' "$TMP_ROOT/parity-5.txt"
        fi
    else
        fail "a removed ladder code is caught and names exit 5 in the gate ladder (ladder line not found)"
    fi
fi

FIXTURE_6="$TMP_ROOT/case-6"
if ! build_fixture "$FIXTURE_6"; then
    fail "an added table row is caught and names extra exit 10 (fixture copy failed)"
else
    DOC_6="$FIXTURE_6/cli-moneybird/references/cli.md"
    if add_row_after "$DOC_6" '^[|] 9 [|]' '| 10 | Placeholder row used only by the parity test fixture |'; then
        run_parity "$FIXTURE_6" 6
        status_6=$?
        if [[ "$status_6" -ne 0 ]] && grep -q 'extra exit 10 in cli-moneybird/references/cli.md exit table' "$TMP_ROOT/parity-6.txt"; then
            pass "an added table row is caught and names extra exit 10"
        else
            fail "an added table row is caught and names extra exit 10"
            sed -n '1,5p' "$TMP_ROOT/parity-6.txt"
        fi
    else
        fail "an added table row is caught and names extra exit 10 (anchor row not found)"
    fi
fi

FIXTURE_7="$TMP_ROOT/case-7"
if ! build_fixture "$FIXTURE_7"; then
    fail "a troubleshooting file with no exit rows is caught (fixture copy failed)"
else
    DOC_7="$FIXTURE_7/cli-moneybird/references/troubleshooting.md"
    if delete_lines "$DOC_7" '^[|] Guard exit [0-9]+ [|]'; then
        run_parity "$FIXTURE_7" 7
        status_7=$?
        if [[ "$status_7" -ne 0 ]] && grep -q 'no exit codes found in cli-moneybird/references/troubleshooting.md exit rows' "$TMP_ROOT/parity-7.txt"; then
            pass "a troubleshooting file with no exit rows is caught"
        else
            fail "a troubleshooting file with no exit rows is caught"
            sed -n '1,5p' "$TMP_ROOT/parity-7.txt"
        fi
    else
        fail "a troubleshooting file with no exit rows is caught (exit rows not found)"
    fi
fi

# ───────────────────────────────────────────────────────────────
# 6. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
