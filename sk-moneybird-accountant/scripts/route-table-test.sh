#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE TEST
# ───────────────────────────────────────────────────────────────
# Tests check-route-table.py against the real SKILL.md and mutated copies.
# Usage: route-table-test.sh
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the checker is only trustworthy when it accepts the real files and
# rejects every drift this suite introduces. This suite proves both.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
SKILL_DIR=$(dirname "$SCRIPT_DIR")
CHECKER="$SCRIPT_DIR/check-route-table.py"
SKILL_MD="$SKILL_DIR/SKILL.md"
SIGNALS_MD="$SKILL_DIR/references/routing-signals.md"

if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-route-table.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_MD" ]]; then
    printf 'error: missing SKILL.md in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$SIGNALS_MD" ]]; then
    printf 'error: missing references/routing-signals.md in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/route-table-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 3. TEST HELPERS
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

# Run the checker against a mutated SKILL.md copy expected to fail with exit 1
# Args:
#   $1 - Check name
#   $2 - Markdown copy to check
mutant() {
    local name="$1"
    local file="$2"
    python3 -I "$CHECKER" --skill-md "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

# Run the checker against a mutated signals file expected to fail with exit 1
# Args:
#   $1 - Check name
#   $2 - Signals file copy to check
signals_mutant() {
    local name="$1"
    local file="$2"
    python3 -I "$CHECKER" --signals "$file" >"$TMP_ROOT/out.txt" 2>&1
    status=$?
    if [[ "$status" -eq 1 ]]; then
        pass "$name"
    else
        fail "$name"
    fi
}

# ───────────────────────────────────────────────────────────────
# 4. REAL SKILL MARKDOWN
# ───────────────────────────────────────────────────────────────

python3 -I "$CHECKER" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "real SKILL.md and routing-signals.md pass"
else
    fail "real SKILL.md and routing-signals.md pass"
    cat "$TMP_ROOT/out.txt"
fi

# ───────────────────────────────────────────────────────────────
# 5. MUTANTS
# ───────────────────────────────────────────────────────────────

copy() {
    cp "$SKILL_MD" "$TMP_ROOT/SKILL.md"
    printf '%s\n' "$TMP_ROOT/SKILL.md"
}

# Blank the budget cell of the T1 row
sed 's/| `tok:T1` | Beats T2/|  | Beats T2/' "$(copy)" >"$TMP_ROOT/m-budget.md"
mutant "budget cell blanked" "$TMP_ROOT/m-budget.md"

# Empty the Dutch cell of the T2 row
sed 's/`migratie`, `overzetten`, `historische administratie` \| mapping/ \| mapping/' "$(copy)" >"$TMP_ROOT/m-dutch.md"
mutant "Dutch cell emptied" "$TMP_ROOT/m-dutch.md"

# Delete the T9 row
sed '/^| T9 | onboarding |/d' "$(copy)" >"$TMP_ROOT/m-row.md"
mutant "T9 row deleted" "$TMP_ROOT/m-row.md"

# Point a read path at a file that does not exist
sed 's|references/purchase-invoices\.md|references/purchase-invoices-missing.md|' "$(copy)" >"$TMP_ROOT/m-path.md"
mutant "read path missing" "$TMP_ROOT/m-path.md"

# Remove the ROUTE_MARGIN line
sed '/ROUTE_MARGIN/d' "$(copy)" >"$TMP_ROOT/m-margin.md"
mutant "ROUTE_MARGIN line removed" "$TMP_ROOT/m-margin.md"

# Route the T2 row to a tool skill the table does not define
sed 's/| mapping, category, which account, trap | `none` |/| mapping, category, which account, trap | `cli-notion` |/' "$(copy)" >"$TMP_ROOT/m-route.md"
mutant "T2 tool route unknown" "$TMP_ROOT/m-route.md"

# Delete the T6 margin override bullet
sed '/^- Margin override T6:/d' "$(copy)" >"$TMP_ROOT/m-override-gone.md"
mutant "T6 override bullet deleted" "$TMP_ROOT/m-override-gone.md"

# Give the T6 override bullet a value that is neither default nor a number
sed 's/^- Margin override T6: `default`$/- Margin override T6: `abc`/' "$(copy)" >"$TMP_ROOT/m-override-value.md"
mutant "T6 override set to abc" "$TMP_ROOT/m-override-value.md"

# Give the T2 margin override bullet a type the table does not allow
sed 's/^- Margin override T2: `default`$/- Margin override T7: `default`/' "$(copy)" >"$TMP_ROOT/m-override-type.md"
mutant "override bullet names T7" "$TMP_ROOT/m-override-type.md"

# Remove the Ties and Abstain heading
sed '/^### Ties and Abstain$/d' "$(copy)" >"$TMP_ROOT/m-tie-heading.md"
mutant "Ties and Abstain heading removed" "$TMP_ROOT/m-tie-heading.md"

# Drop the pointer line that names the signal sources file
sed '/Signal sources and their Belastingdienst pages: `references\/routing-signals\.md`\./d' "$(copy)" >"$TMP_ROOT/m-pointer.md"
mutant "signal sources pointer removed" "$TMP_ROOT/m-pointer.md"

# ───────────────────────────────────────────────────────────────
# 6. SIGNALS FILE MUTANTS
# ───────────────────────────────────────────────────────────────

# Copy the signals file to a temp path so the original stays untouched
cp "$SIGNALS_MD" "$TMP_ROOT/routing-signals.md"

# Remove every source line from the signals file
sed '/^- /d' "$TMP_ROOT/routing-signals.md" >"$TMP_ROOT/m-signals-lines.md"
signals_mutant "signal source lines removed" "$TMP_ROOT/m-signals-lines.md"

# Drop the belastingdienst link from the administration terms source line
sed 's|: https://www\.belastingdienst\.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/|: missing|' "$TMP_ROOT/routing-signals.md" >"$TMP_ROOT/m-signals-link.md"
signals_mutant "belastingdienst link removed" "$TMP_ROOT/m-signals-link.md"

# Delete the whole signals file by pointing the checker at an absent path
signals_mutant "signals file deleted" "$TMP_ROOT/no-such-routing-signals.md"

# ───────────────────────────────────────────────────────────────
# 7. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
