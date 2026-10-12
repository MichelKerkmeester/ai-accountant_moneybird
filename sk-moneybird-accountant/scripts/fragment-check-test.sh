#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: FRAGMENT CHECK TEST
# ───────────────────────────────────────────────────────────────
# Tests check-fragments.py against a fixture repository, the real
# corpus and a renamed heading in a copy of the real tree.
# Usage: fragment-check-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: a fragment checker earns trust only when it accepts every address that
# resolves and rejects every address that drifted. This suite proves both on a
# fixture of its own and on the corpus the checker guards.
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
    printf 'error: usage: fragment-check-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

CHECKER="$SKILL_SRC/scripts/check-fragments.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-fragments.py in the skill folder\n' >&2
    exit 2
fi

REPO_ROOT=$(dirname "$SKILL_SRC")

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fragment-check-test.XXXXXX") || exit 2

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

# Write the target file that the fixture links point at
# Args:
#   $1 - Repository root
# Returns:
#   0 when the file is written, 1 when a write fails
write_targets() {
    local file="$1/sk-moneybird-accountant/references/targets.md"
    cat >"$file" <<'MARKDOWN' || return 1
# Targets

<a id="3-how-it-works"></a>

## Good Heading

First heading with this text.

## Good Heading

Second heading with the same text, so its slug takes a counter.

## Another Heading

Heading that the rename case points at.

## Pass / Fail

Heading whose slash is dropped before each space becomes a hyphen.
MARKDOWN
}

# Write the year topic file with the eight section ids in order
# Args:
#   $1 - Repository root
# Returns:
#   0 when the file is written, 1 when a write fails
write_topic() {
    local file="$1/sk-moneybird-accountant/references/2026/topic.md"
    cat >"$file" <<'MARKDOWN' || return 1
# Topic 2026

## 1. OVERVIEW

<a id="1-overview"></a>

## 2. KEY FIGURES

<a id="2-key-figures"></a>

## 3. HOW IT WORKS

<a id="3-how-it-works"></a>

## 4. WORKED EXAMPLES

<a id="4-worked-examples"></a>

## 5. CHANGES

<a id="5-changes"></a>

## 6. IN THE BOOKS

<a id="6-in-the-books"></a>

## 7. OPEN POINTS

<a id="7-open-points"></a>

## 8. RELATED RESOURCES

<a id="8-related-resources"></a>
MARKDOWN
}

# Build the fixture repository with a target file, a topic file and one good link
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/references/2026" || return 1
    write_targets "$root" || return 1
    write_topic "$root" || return 1
    printf '# Source\n\n[case](targets.md#good-heading)\n' \
        >"$root/sk-moneybird-accountant/references/source.md" || return 1
    return 0
}

# Point the fixture source file at one raw link target
# Args:
#   $1 - Raw link target
# Returns:
#   0 when the file is written, 1 when a write fails
write_source() {
    printf '# Source\n\n[case](%s)\n' "$1" \
        >"$FIX/sk-moneybird-accountant/references/source.md" || return 1
}

# Point the fixture source file at one raw link target through a reference definition
# Args:
#   $1 - Raw link target
# Returns:
#   0 when the file is written, 1 when a write fails
write_reference_source() {
    printf '# Source\n\n[case][r1]\n\n[r1]: %s\n' "$1" \
        >"$FIX/sk-moneybird-accountant/references/source.md" || return 1
}

# Write the fixture source file with long fences around shorter inner fences
# Args:
#   $1 - Repository root
# Returns:
#   0 when the file is written, 1 when a write fails
write_fence_source() {
    cat >"$1/sk-moneybird-accountant/references/source.md" <<'MARKDOWN' || return 1
# Source

[visible](targets.md#good-heading)

````text
```
[hidden-backtick](missing.md#nowhere)
```
````

~~~~text
~~~
[hidden-tilde](missing.md#nowhere)
~~~
~~~~

[visible-again](targets.md#good-heading)
MARKDOWN
}

# Rename one id or heading in the fixture target file
# Args:
#   $1 - Sed expression applied to the target file
# Returns:
#   0 when the file is rewritten, 1 when the edit fails
rename_target() {
    sed -i.bak "$1" "$FIX/sk-moneybird-accountant/references/targets.md" || return 1
}

# Run one fixture link case and record whether it resolves or misses
# Args:
#   $1 - Check description
#   $2 - Raw link target
#   $3 - Expected reason, or "ok" when the link must resolve
#   $4 - Source writer helper, defaults to write_source
# Returns:
#   0, printing one report line
check_link() {
    local description="$1"
    local target="$2"
    local expected="$3"
    local writer="${4:-write_source}"
    "$writer" "$target"
    run_checker "$FIX"
    local status=$?
    if [[ "$expected" = "ok" ]]; then
        if [[ "$status" -eq 0 ]]; then
            pass "$description"
        else
            fail "$description"
        fi
        return 0
    fi
    if [[ "$status" -eq 1 ]] && grep -qF "$target $expected" "$TMP_ROOT/out.txt"; then
        pass "$description"
    else
        fail "$description"
    fi
}

# Copy the entries the checker reads into a throwaway tree
# Args:
#   $1 - Source repository root
#   $2 - Target repository root
# Returns:
#   0 when the copy is ready, 1 when a copy fails
copy_tree() {
    local source="$1"
    local target="$2"
    local entry
    mkdir -p "$target" || return 1
    for entry in AGENTS.md README.md sk-moneybird-accountant cli-jortt cli-moneybird
    do
        if [[ -e "$source/$entry" ]]; then
            cp -R "$source/$entry" "$target/" || return 1
        fi
    done
    return 0
}

# ───────────────────────────────────────────────────────────────
# 6. FIXTURE LINKS
# ───────────────────────────────────────────────────────────────

group "fixture links"
if make_fixture "$FIX"; then
    pass "fixture repository builds"
else
    fail "fixture repository builds"
fi
run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "the fixture corpus is clean"
else
    fail "the fixture corpus is clean"
fi

check_link "a heading slug link resolves" 'targets.md#good-heading' ok
check_link "an anchor id link resolves" 'targets.md#3-how-it-works' ok

rename_target 's/id="3-how-it-works"/id="3-how-it-works-old"/'
check_link "a renamed id is rejected" 'targets.md#3-how-it-works' missing-fragment

write_targets "$FIX"
check_link "the heading before its rename resolves" 'targets.md#another-heading' ok

rename_target 's/^## Another Heading$/## Renamed Heading/'
check_link "a renamed heading is rejected" 'targets.md#another-heading' missing-fragment

write_targets "$FIX"
check_link "a missing file is rejected" 'missing.md#anywhere' missing-path
check_link "a duplicate-suffix slug is rejected" 'targets.md#good-heading-1' duplicate-suffix

check_link "a slash heading keeps both hyphens" 'targets.md#pass--fail' ok
check_link "a collapsed slash heading is rejected" 'targets.md#pass-fail' missing-fragment
check_link "a reference definition resolves" 'targets.md#another-heading' ok write_reference_source
check_link "a broken reference definition is rejected" 'targets.md#gone-heading' missing-fragment write_reference_source

write_fence_source "$FIX"
run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a shorter inner fence does not close a longer fence"
else
    fail "a shorter inner fence does not close a longer fence"
fi

# ───────────────────────────────────────────────────────────────
# 7. YEAR TOPIC IDS
# ───────────────────────────────────────────────────────────────

group "year topic ids"
TOPIC="$FIX/sk-moneybird-accountant/references/2026/topic.md"

write_topic "$FIX"
sed -i.bak '/<a id="2-key-figures"><\/a>/d' "$TOPIC"
write_source 'targets.md#good-heading'
run_checker "$FIX"
status=$?
if [[ "$status" -eq 1 ]] && grep -qF '2-key-figures missing-id' "$TMP_ROOT/out.txt"; then
    pass "a topic file that misses one id is rejected"
else
    fail "a topic file that misses one id is rejected"
fi

write_topic "$FIX"
sed -i.bak \
    -e 's/id="1-overview"/id="SWAP-A"/' \
    -e 's/id="2-key-figures"/id="SWAP-B"/' \
    -e 's/id="SWAP-A"/id="2-key-figures"/' \
    -e 's/id="SWAP-B"/id="1-overview"/' "$TOPIC"
write_source 'targets.md#good-heading'
run_checker "$FIX"
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'out-of-order' "$TMP_ROOT/out.txt"; then
    pass "a topic file whose ids are out of order is rejected"
else
    fail "a topic file whose ids are out of order is rejected"
fi

# ───────────────────────────────────────────────────────────────
# 8. REAL CORPUS
# ───────────────────────────────────────────────────────────────

group "real corpus"
assert "the real corpus is clean" python3 -I "$CHECKER" --root "$REPO_ROOT"

# ───────────────────────────────────────────────────────────────
# 9. RENAMED HEADING IN A COPY OF THE REAL TREE
# ───────────────────────────────────────────────────────────────

group "renamed heading in a copy"
COPY="$TMP_ROOT/real-copy"
MUTATED="$COPY/sk-moneybird-accountant/references/migration/shared-mechanisms.md"
if copy_tree "$REPO_ROOT" "$COPY"; then
    pass "a temp copy of the real tree builds"
else
    fail "a temp copy of the real tree builds"
fi

run_checker "$COPY"
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/copy-before.txt"

sed -i.bak 's/^## Route contract$/## Route contract revised/' "$MUTATED"
run_checker "$COPY"
status=$?
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/copy-after.txt"

comm -13 <(grep '^fragment ' "$TMP_ROOT/copy-before.txt" | sort) \
    <(grep '^fragment ' "$TMP_ROOT/copy-after.txt" | sort) >"$TMP_ROOT/copy-new.txt"

if [[ "$status" -eq 1 ]] && grep -qF '#route-contract missing-fragment' "$TMP_ROOT/copy-new.txt"; then
    pass "a renamed heading in a copy fails the check"
else
    fail "a renamed heading in a copy fails the check"
fi

# ───────────────────────────────────────────────────────────────
# 10. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
