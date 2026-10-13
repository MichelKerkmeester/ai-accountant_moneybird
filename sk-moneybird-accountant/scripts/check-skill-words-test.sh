#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SKILL WORD CHECK TEST
# ───────────────────────────────────────────────────────────────
# Tests check-skill-words.py on the real tree, on three generated fixture
# trees either side of the two thresholds and on a missing or unreadable
# file. The 2,999-word fixture must pass without a warning, the 3,001-word
# fixture must warn and exit 0 and the 4,001-word fixture must exit 1 and
# name its path. The real-tree counts must match `wc -w`.
# Usage: check-skill-words-test.sh [repo root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing checker files
#
# WHY: the checker is only trustworthy when it accepts the real tree, warns
# in the middle band and fails above the hard ceiling, so this suite proves
# each band on a generated fixture in a throwaway root.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND CONTRACT VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: check-skill-words-test.sh [repo root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

CHECKER="$REPO_SRC/sk-moneybird-accountant/scripts/check-skill-words.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-skill-words.py in the repository\n' >&2
    exit 2
fi

SKILL_FILES=(
    "sk-moneybird-accountant/SKILL.md"
    "cli-moneybird/SKILL.md"
    "cli-jortt/SKILL.md"
)
for relative in "${SKILL_FILES[@]}"; do
    if [[ ! -f "$REPO_SRC/$relative" ]]; then
        printf 'error: missing %s in the repository\n' "$relative" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/check-skill-words-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        chmod -R u+rwX "$TMP_ROOT" 2>/dev/null
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

# Write a file that holds exactly one word per line
# Args:
#   $1 - File to write
#   $2 - Word count
# Returns:
#   0 when the file is written, 1 otherwise
write_words() {
    python3 -I - "$1" "$2" <<'PY'
import sys

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write("\n".join(["word"] * int(sys.argv[2])) + "\n")
PY
}

# Build a fixture repository root with the three skill family files
# Args:
#   $1 - Fixture root to create
#   $2 - Relative path of the file that carries the band count
#   $3 - Word count for that file
# Returns:
#   0 when every file is written, 1 otherwise
make_fixture() {
    local root="$1"
    local band_file="$2"
    local count="$3"
    local relative
    for relative in "${SKILL_FILES[@]}"; do
        mkdir -p "$root/$(dirname "$relative")" || return 1
        if [[ "$relative" == "$band_file" ]]; then
            write_words "$root/$relative" "$count" || return 1
        else
            write_words "$root/$relative" 10 || return 1
        fi
    done
    return 0
}

# Run the word check against a fixture root and capture both streams
# Args:
#   $1 - Repository root to check
#   $2 - Tag for the captured output files
# Returns:
#   The checker exit status
run_checker() {
    python3 -I "$CHECKER" --root "$1" >"$TMP_ROOT/out-$2.txt" 2>"$TMP_ROOT/err-$2.txt"
}

# Return the count one fixture root reports for one file
# Args:
#   $1 - Tag of the captured output file
#   $2 - File relative to the fixture root
# Returns:
#   The reported word count, or an empty string when the line is absent
reported_count() {
    awk -v path="$2" '$1 == "check-skill-words:" && $2 == path {print $3}' "$TMP_ROOT/out-$1.txt"
}

# ───────────────────────────────────────────────────────────────
# 5. REAL TREE CHECKS
# ───────────────────────────────────────────────────────────────

group "Real tree"

run_checker "$REPO_SRC" real
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "the word check exits 0 on the real tree"
else
    fail "the word check exits 0 on the real tree"
    cat "$TMP_ROOT/out-real.txt"
    cat "$TMP_ROOT/err-real.txt" >&2
fi

lines=$(wc -l <"$TMP_ROOT/out-real.txt" | tr -d '[:space:]')
if [[ "$lines" == "3" ]] && [[ "$(grep -c '^check-skill-words: ' "$TMP_ROOT/out-real.txt")" == "3" ]]; then
    pass "the real tree prints one line per SKILL.md"
else
    fail "the real tree prints one line per SKILL.md"
    cat "$TMP_ROOT/out-real.txt"
fi

counts_match=1
for relative in "${SKILL_FILES[@]}"; do
    reported=$(reported_count real "$relative")
    expected=$(LC_ALL=C wc -w <"$REPO_SRC/$relative" | tr -d '[:space:]')
    if [[ -z "$reported" ]] || [[ "$reported" != "$expected" ]]; then
        counts_match=0
        printf 'count mismatch: %s reports %s, wc -w says %s\n' "$relative" "$reported" "$expected"
    fi
done
if [[ "$counts_match" -eq 1 ]]; then
    pass "the real-tree counts match wc -w"
else
    fail "the real-tree counts match wc -w"
fi

if grep -qE '^check-skill-words: (sk-moneybird-accountant/SKILL\.md|cli-moneybird/SKILL\.md|cli-jortt/SKILL\.md) [0-9]+ words, (ok|warn above 3,000|fail above 4,000)$' "$TMP_ROOT/out-real.txt"; then
    pass "every real-tree line carries a count and a verdict"
else
    fail "every real-tree line carries a count and a verdict"
    cat "$TMP_ROOT/out-real.txt"
fi

# The same run must print the same lines
python3 -I "$CHECKER" --root "$REPO_SRC" >"$TMP_ROOT/out-real-again.txt" 2>&1
if cmp -s "$TMP_ROOT/out-real.txt" "$TMP_ROOT/out-real-again.txt"; then
    pass "a second real-tree run prints the same lines"
else
    fail "a second real-tree run prints the same lines"
fi

# ───────────────────────────────────────────────────────────────
# 6. WORD BAND FIXTURES
# ───────────────────────────────────────────────────────────────

group "Word bands"

BAND_FILE="sk-moneybird-accountant/SKILL.md"

for band in 2999 3001 4001; do
    if make_fixture "$TMP_ROOT/band-$band" "$BAND_FILE" "$band"; then
        pass "the $band-word fixture is created"
    else
        fail "the $band-word fixture is created"
    fi
    fixture_words=$(LC_ALL=C wc -w <"$TMP_ROOT/band-$band/$BAND_FILE" | tr -d '[:space:]')
    if [[ "$fixture_words" == "$band" ]]; then
        pass "the $band-word fixture holds $band words"
    else
        fail "the $band-word fixture holds $band words (it holds $fixture_words)"
    fi
done

run_checker "$TMP_ROOT/band-2999" band-2999
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(reported_count band-2999 "$BAND_FILE")" == "2999" ]] \
    && ! grep -qE 'warn above 3,000|fail above 4,000' "$TMP_ROOT/out-band-2999.txt"; then
    pass "the 2,999-word fixture stays silent and exits 0"
else
    fail "the 2,999-word fixture stays silent and exits 0"
    cat "$TMP_ROOT/out-band-2999.txt"
    cat "$TMP_ROOT/err-band-2999.txt" >&2
fi

run_checker "$TMP_ROOT/band-3001" band-3001
status=$?
if [[ "$status" -eq 0 ]] && [[ "$(reported_count band-3001 "$BAND_FILE")" == "3001" ]] \
    && grep -qF "check-skill-words: $BAND_FILE 3001 words, warn above 3,000" "$TMP_ROOT/out-band-3001.txt"; then
    pass "the 3,001-word fixture warns and exits 0"
else
    fail "the 3,001-word fixture warns and exits 0"
    cat "$TMP_ROOT/out-band-3001.txt"
    cat "$TMP_ROOT/err-band-3001.txt" >&2
fi

run_checker "$TMP_ROOT/band-4001" band-4001
status=$?
if [[ "$status" -eq 1 ]] && [[ "$(reported_count band-4001 "$BAND_FILE")" == "4001" ]] \
    && grep -qF "check-skill-words: $BAND_FILE 4001 words, fail above 4,000" "$TMP_ROOT/out-band-4001.txt"; then
    pass "the 4,001-word fixture exits 1 and names its path"
else
    fail "the 4,001-word fixture exits 1 and names its path"
    cat "$TMP_ROOT/out-band-4001.txt"
    cat "$TMP_ROOT/err-band-4001.txt" >&2
fi

# A hidden folder holds a tool checkout, not the skill family, so its files
# stay out of the walk and out of the budget
mkdir -p "$TMP_ROOT/band-2999/.skilled/skills"
if write_words "$TMP_ROOT/band-2999/.skilled/skills/SKILL.md" 4100; then
    pass "the hidden-folder fixture is created"
else
    fail "the hidden-folder fixture is created"
fi

run_checker "$TMP_ROOT/band-2999" hidden
status=$?
if [[ "$status" -eq 0 ]] && ! grep -qF '.skilled' "$TMP_ROOT/out-hidden.txt"; then
    pass "a hidden folder stays outside the walk"
else
    fail "a hidden folder stays outside the walk"
    cat "$TMP_ROOT/out-hidden.txt"
fi

# A spec packet keeps backup copies of retired skills, so its files stay out
# of the walk and out of the budget
mkdir -p "$TMP_ROOT/band-2999/specs/001-packet/scratch/backup"
if write_words "$TMP_ROOT/band-2999/specs/001-packet/scratch/backup/SKILL.md" 4100; then
    pass "the spec-packet fixture is created"
else
    fail "the spec-packet fixture is created"
fi

run_checker "$TMP_ROOT/band-2999" specs
status=$?
if [[ "$status" -eq 0 ]] && ! grep -qF 'specs/' "$TMP_ROOT/out-specs.txt"; then
    pass "a spec packet stays outside the walk"
else
    fail "a spec packet stays outside the walk"
    cat "$TMP_ROOT/out-specs.txt"
fi

# ───────────────────────────────────────────────────────────────
# 7. MISSING AND UNREADABLE FILE CHECKS
# ───────────────────────────────────────────────────────────────

group "Missing and unreadable files"

if make_fixture "$TMP_ROOT/missing" "$BAND_FILE" 100 && rm -f "$TMP_ROOT/missing/cli-jortt/SKILL.md"; then
    pass "the missing-file fixture is created"
else
    fail "the missing-file fixture is created"
fi

run_checker "$TMP_ROOT/missing" missing
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'cli-jortt/SKILL.md' "$TMP_ROOT/err-missing.txt"; then
    pass "a missing SKILL.md exits 2 and names its path"
else
    fail "a missing SKILL.md exits 2 and names its path"
    cat "$TMP_ROOT/out-missing.txt"
    cat "$TMP_ROOT/err-missing.txt" >&2
fi

if make_fixture "$TMP_ROOT/unreadable" "$BAND_FILE" 100; then
    pass "the unreadable-file fixture is created"
else
    fail "the unreadable-file fixture is created"
fi

chmod 000 "$TMP_ROOT/unreadable/cli-jortt/SKILL.md"
if [[ -r "$TMP_ROOT/unreadable/cli-jortt/SKILL.md" ]]; then
    # A root account reads a 000 file, so the case cannot run and stays recorded
    pass "the unreadable-file case is skipped (this account reads a 000 file)"
else
    run_checker "$TMP_ROOT/unreadable" unreadable
    status=$?
    if [[ "$status" -eq 2 ]] && grep -qF 'cli-jortt/SKILL.md' "$TMP_ROOT/err-unreadable.txt"; then
        pass "an unreadable SKILL.md exits 2 and names its path"
    else
        fail "an unreadable SKILL.md exits 2 and names its path"
        cat "$TMP_ROOT/out-unreadable.txt"
        cat "$TMP_ROOT/err-unreadable.txt" >&2
    fi
fi
chmod u+rw "$TMP_ROOT/unreadable/cli-jortt/SKILL.md"

run_checker "$TMP_ROOT/no-such-root" no-root
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'no-such-root' "$TMP_ROOT/err-no-root.txt"; then
    pass "a missing root exits 2 and names it"
else
    fail "a missing root exits 2 and names it"
    cat "$TMP_ROOT/err-no-root.txt" >&2
fi

# ───────────────────────────────────────────────────────────────
# 8. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
