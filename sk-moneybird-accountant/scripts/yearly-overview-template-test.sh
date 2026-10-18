#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: YEARLY OVERVIEW TEMPLATE TEST
# ───────────────────────────────────────────────────────────────
# Tests yearly-overview-template-fill.py on the real template and on five
# mutants: a broken repeat marker, a remote asset, a missing prepared-not-filed
# line, an undeclared token and a declared token the body never uses. Every
# mutant must fail and name its cause.
# Usage: yearly-overview-template-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the template is the printable pack layout, so a broken token, a remote
# asset or a lost prepared-not-filed line must fail before a copy is rendered.
# The check proves structure only and never a total.
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
    printf 'error: usage: yearly-overview-template-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

FILLER="$SKILL_SRC/scripts/yearly-overview-template-fill.py"
TEMPLATE="$SKILL_SRC/assets/yearly-overview/yearly-overview-template.html"
if [[ ! -f "$FILLER" ]]; then
    printf 'error: missing scripts/yearly-overview-template-fill.py in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$TEMPLATE" ]]; then
    printf 'error: missing assets/yearly-overview/yearly-overview-template.html in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/yearly-overview-template-test.XXXXXX") || exit 2

# Remove the temp root on exit so no filled copy survives the run
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

# ───────────────────────────────────────────────────────────────
# 5. MUTANT BUILDERS
# ───────────────────────────────────────────────────────────────

# Write the five mutant templates under the temp root. Each mutation touches
# the body only, after the header comment, so the closed token list and the
# repeat markers stay as the header declares them.
python3 -I - "$TEMPLATE" "$TMP_ROOT" <<'PY'
import sys

template, root = sys.argv[1], sys.argv[2]
with open(template, "r", encoding="utf-8") as handle:
    text = handle.read()
start = text.index("<!--")
end = text.index("-->", start) + 3
head, body = text[:end], text[end:]


def write(name, body_text):
    """Write one mutant beside the real template."""
    with open("%s/%s" % (root, name), "w", encoding="utf-8") as handle:
        handle.write(head + body_text)


write("broken-repeat.html", body.replace("<!-- /repeat:exceptions -->", "<!-- /repeat:exception -->"))
write(
    "remote.html",
    body.replace("<head>", '<head>\n<link href="https://example.invalid/style.css" rel="stylesheet">'),
)
write("no-stop.html", body.replace("Prepared, not filed", "Prepared and ready"))
write("undeclared.html", body.replace("{auditfile_version}", "{auditfile_revision}"))
write("unused.html", body.replace("{period_start}", ""))
PY

# ───────────────────────────────────────────────────────────────
# 6. REAL TEMPLATE CHECKS
# ───────────────────────────────────────────────────────────────

group "Real template"

if python3 -I "$FILLER" --template "$TEMPLATE" >"$TMP_ROOT/fill.txt" 2>&1; then
    pass "a synthetic fill of the real template passes every check"
else
    fail "a synthetic fill of the real template passes every check"
    sed -n '1,5p' "$TMP_ROOT/fill.txt"
fi

# ───────────────────────────────────────────────────────────────
# 7. MUTANT CHECKS
# ───────────────────────────────────────────────────────────────

group "Mutants"

check_mutant() {
    local name="$1"
    local expected="$2"
    local out="$TMP_ROOT/mutant-$name.txt"
    local status
    python3 -I "$FILLER" --template "$TMP_ROOT/$name.html" >"$out" 2>&1
    status=$?
    if [[ "$status" -ne 1 ]]; then
        fail "the $name mutant exits 1 (exit $status)"
        return
    fi
    if grep -qF "$expected" "$out"; then
        pass "the $name mutant fails and names its cause"
    else
        fail "the $name mutant fails and names its cause"
        sed -n '1,3p' "$out"
    fi
}

check_mutant "broken-repeat" "repeat marker /repeat:exception"
check_mutant "remote" "remote URL"
check_mutant "no-stop" "prepared-not-filed line is missing: Prepared, not filed"
check_mutant "undeclared" "not in the closed token list"
check_mutant "unused" "the body never uses it"

# ───────────────────────────────────────────────────────────────
# 8. USAGE ERRORS
# ───────────────────────────────────────────────────────────────

group "Usage errors"

python3 -I "$FILLER" --template "$TMP_ROOT/absent.html" >"$TMP_ROOT/usage-absent.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'error: missing template: ' "$TMP_ROOT/usage-absent.txt"; then
    pass "a missing template is refused with exit 2 and names the file"
else
    fail "a missing template is refused with exit 2 and names the file (exit $status)"
fi

# ───────────────────────────────────────────────────────────────
# 9. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
