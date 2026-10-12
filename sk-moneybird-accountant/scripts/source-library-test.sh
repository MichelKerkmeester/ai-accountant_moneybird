#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SOURCE LIBRARY TEST
# ───────────────────────────────────────────────────────────────
# Tests build-source-library.py against a fixture repository and the real one.
# Usage: source-library-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the index is only trustworthy when --check catches every drift and a
# rewrite never drops a recorded access result. This suite proves both.
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
    printf 'error: usage: source-library-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

BUILDER="$SKILL_SRC/scripts/build-source-library.py"
if [[ ! -f "$BUILDER" ]]; then
    printf 'error: missing scripts/build-source-library.py in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/source-library-test.XXXXXX") || exit 2

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

# Build a fixture repository with the builder and a few cited sources
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fake_repo() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/assets" \
        "$root/sk-moneybird-accountant/references" "$root/cli-jortt" "$root/cli-moneybird" || return 1
    cp "$BUILDER" "$root/sk-moneybird-accountant/scripts/" || return 1
    printf '# Bootstrap\n\nSee https://www.belastingdienst.nl/a and ![b](https://img.shields.io/x).\n' \
        >"$root/AGENTS.md" || return 1
    printf '# Rules\n\nThe [VAT page](https://www.belastingdienst.nl/b). Token: https://app.jortt.nl/oauth.\n' \
        >"$root/sk-moneybird-accountant/references/rules.md" || return 1
    printf '# Guide\n\nhttps://example.org/only-in-guide\n' \
        >"$root/sk-moneybird-accountant/references/source-library.md" || return 1
    return 0
}

# Run the builder inside a fixture repository
# Args:
#   $1 - Repository root
#   $2... - Extra builder arguments
# Returns:
#   The builder exit status, with output in $TMP_ROOT/out.txt
run_builder() {
    local root="$1"
    shift
    python3 -I "$root/sk-moneybird-accountant/scripts/build-source-library.py" "$@" >"$TMP_ROOT/out.txt" 2>&1
}

# Print one field of one indexed source
# Args:
#   $1 - Repository root
#   $2 - Source URL
#   $3 - Field name
# Returns:
#   0, printing the value or an empty line
index_field() {
    python3 -I -c '
import json, sys
rows = {r["url"]: r for r in json.load(open(sys.argv[1]))["sources"]}
print(rows.get(sys.argv[2], {}).get(sys.argv[3], ""))
' "$1/sk-moneybird-accountant/assets/source-library.json" "$2" "$3" 2>/dev/null
}

# ───────────────────────────────────────────────────────────────
# 5. CHECKS
# ───────────────────────────────────────────────────────────────

REPO="$TMP_ROOT/repo"
INDEX="$REPO/sk-moneybird-accountant/assets/source-library.json"

group "write"
if make_fake_repo "$REPO"; then
    pass "fixture repository builds"
else
    fail "fixture repository builds"
fi
assert "write exits 0" run_builder "$REPO"
assert "index is valid JSON" python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$INDEX"
assert "cited page is indexed" grep -q 'belastingdienst.nl/a"' "$INDEX"
assert "badge is not indexed" bash -c "! grep -q img.shields.io '$INDEX'"
assert "guide links are not scanned" bash -c "! grep -q only-in-guide '$INDEX'"
if [[ "$(index_field "$REPO" https://www.belastingdienst.nl/b title)" = "VAT page" ]]; then
    pass "link text becomes the title"
else
    fail "link text becomes the title"
fi
if [[ "$(index_field "$REPO" https://app.jortt.nl/oauth access)" = "endpoint" ]]; then
    pass "OAuth address is an endpoint"
else
    fail "OAuth address is an endpoint"
fi
if [[ "$(index_field "$REPO" https://www.belastingdienst.nl/a access)" = "unchecked" ]]; then
    pass "new source starts unchecked"
else
    fail "new source starts unchecked"
fi

group "check"
assert "check passes after a write" run_builder "$REPO" --check
printf '\nNew: https://wetten.overheid.nl/BWBR0000001\n' >>"$REPO/sk-moneybird-accountant/references/rules.md"
run_builder "$REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^missing: https://wetten.overheid.nl/BWBR0000001' "$TMP_ROOT/out.txt"; then
    pass "check reports a newly cited source"
else
    fail "check reports a newly cited source"
fi
run_builder "$REPO" >/dev/null
printf '# Bootstrap\n' >"$REPO/AGENTS.md"
run_builder "$REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q '^uncited: https://www.belastingdienst.nl/a' "$TMP_ROOT/out.txt"; then
    pass "check reports a source no file cites"
else
    fail "check reports a source no file cites"
fi
run_builder "$REPO" >/dev/null

group "access results"
python3 -I -c '
import json, sys
path = sys.argv[1]
data = json.load(open(path))
for row in data["sources"]:
    if row["url"] == "https://www.belastingdienst.nl/b":
        row.update(access="ok", http_status=200, checked_on="2026-01-01")
open(path, "w").write(json.dumps(data))
' "$INDEX"
assert "rewrite after a recorded check exits 0" run_builder "$REPO"
if [[ "$(index_field "$REPO" https://www.belastingdienst.nl/b access)" = "ok" ]] \
    && [[ "$(index_field "$REPO" https://www.belastingdienst.nl/b checked_on)" = "2026-01-01" ]]; then
    pass "rewrite keeps the recorded access result"
else
    fail "rewrite keeps the recorded access result"
fi
sed -i.bak 's/"access":"ok"/"access":"fine"/' "$INDEX"
run_builder "$REPO" --check
status=$?
if [[ "$status" -eq 1 ]] && grep -q "^unknown access 'fine'" "$TMP_ROOT/out.txt"; then
    pass "check rejects an unknown access value"
else
    fail "check rejects an unknown access value"
fi

group "real skill"
assert "the skill's own index matches its sources" python3 -I "$BUILDER" --check

# ───────────────────────────────────────────────────────────────
# 6. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
