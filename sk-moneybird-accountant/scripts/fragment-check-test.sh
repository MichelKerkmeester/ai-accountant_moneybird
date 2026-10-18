#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: FRAGMENT CHECK TEST
# ───────────────────────────────────────────────────────────────
# Tests check-fragments.py against a fixture repository in the real layout
# and a renamed heading in a copy of the real tree. Each tree holds its own
# copy of the checker, which reads the root above its own folder.
# Usage: fragment-check-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, missing skill files or a fixture that cannot be built
#
# WHY: a fragment checker earns trust only when it accepts every address that
# resolves and rejects every address that drifted. This suite proves both on a
# fixture of its own and on a copy of the corpus the checker guards.
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

# Stop the run when a fixture cannot be built, because every case after it would test nothing
# Args:
#   $1 - Description of the fixture step that failed
abort_setup() {
    printf 'error: %s\n' "$1" >&2
    exit 2
}

# Print a section heading before the next block of checks
# Args:
#   $1 - Group title
group() {
    printf '\n== %s\n' "$1"
}

# Run the checker copy that sits inside one repository root and capture its output
# Args:
#   $1 - Repository root
# Returns:
#   The checker exit status, with output in $TMP_ROOT/out.txt
run_checker() {
    python3 -I "$1/sk-moneybird-accountant/scripts/check-fragments.py" >"$TMP_ROOT/out.txt" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 5. FIXTURE BUILDERS AND FIXTURE HELPERS
# ───────────────────────────────────────────────────────────────

FIX="$TMP_ROOT/fixture"
FIX_REFERENCES="$FIX/sk-moneybird-accountant/references"
FIX_TOPIC="$FIX_REFERENCES/tax-rules/2026/vat"

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

# Write the four parts of a year topic with every required section id
# Args:
#   $1 - Repository root
# Returns:
#   0 when the parts are written, 1 when a write fails
write_topic() {
    local dir="$1/sk-moneybird-accountant/references/tax-rules/2026/vat"
    mkdir -p "$dir" || return 1
    cat >"$dir/figures.md" <<'MARKDOWN' || return 1
# Figures 2026

## 1. OVERVIEW

<a id="1-overview"></a>

## 2. KEY FIGURES

<a id="2-key-figures"></a>
MARKDOWN
    cat >"$dir/rules.md" <<'MARKDOWN' || return 1
# Rules 2026

## 3. HOW IT WORKS

<a id="3-how-it-works"></a>
MARKDOWN
    cat >"$dir/examples.md" <<'MARKDOWN' || return 1
# Examples 2026

## 4. WORKED EXAMPLES

<a id="4-worked-examples"></a>
MARKDOWN
    cat >"$dir/notes.md" <<'MARKDOWN' || return 1
# Notes 2026

## 5. CHANGES

<a id="5-changes"></a>

## 6. IN THE BOOKS

<a id="6-in-the-books"></a>

## 7. OPEN POINTS

<a id="7-open-points"></a>

## 8. RELATED RESOURCES

<a id="8-related-resources"></a>
MARKDOWN
    return 0
}

# Write the year changelog and the year change note, which carry no section ids
# Args:
#   $1 - Repository root
# Returns:
#   0 when both files are written, 1 when a write fails
write_year_notes() {
    local dir="$1/sk-moneybird-accountant/references/tax-rules/2026"
    mkdir -p "$dir" || return 1
    cat >"$dir/changelog.md" <<'MARKDOWN' || return 1
# Corrections 2026

| Date | File | Row | Old status | New status | Source |
|---|---|---|---|---|---|
| 2026-10-12 | vat/figures.md | Overview | as first researched | Corrected | https://example.invalid/source |
MARKDOWN
    cat >"$dir/changes.md" <<'MARKDOWN' || return 1
# Changes 2026

## 1. Unique to 2026

- Fixture change. [vat/notes.md](vat/notes.md#5-changes)

## 2. All changes by topic
MARKDOWN
}

# Build the fixture repository with a target file, a year topic, the year notes and one good link
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/scripts" "$root/sk-moneybird-accountant/references" || return 1
    cp "$CHECKER" "$root/sk-moneybird-accountant/scripts/check-fragments.py" || return 1
    write_targets "$root" || return 1
    write_topic "$root" || return 1
    write_year_notes "$root" || return 1
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
    printf '# Source\n\n[case](%s)\n' "$1" >"$FIX_REFERENCES/source.md" || return 1
}

# Write the fixture source file with one link label and one raw link target
# Args:
#   $1 - Link label
#   $2 - Raw link target
# Returns:
#   0 when the file is written, 1 when a write fails
write_label_source() {
    printf '# Source\n\n[%s](%s)\n' "$1" "$2" >"$FIX_REFERENCES/source.md" || return 1
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
    sed -i.bak "$1" "$FIX_REFERENCES/targets.md" || return 1
}

# Run one fixture link case and record whether it resolves or misses
# Args:
#   $1 - Check description
#   $2 - Raw link target
#   $3 - Expected reason, or "ok" when the link must resolve
# Returns:
#   0, printing one report line
check_link() {
    local description="$1"
    local target="$2"
    local expected="$3"
    write_source "$target"
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
make_fixture "$FIX" || abort_setup "the fixture repository cannot be built"
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

write_fence_source "$FIX"
run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a shorter inner fence does not close a longer fence"
else
    fail "a shorter inner fence does not close a longer fence"
fi

# WHY: a categoryless label can name a folder the target never reaches, so the
# label is compared with the path the link opens.
write_label_source 'missing/label.md' 'targets.md#good-heading'
run_checker "$FIX"
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'missing/label.md label-mismatch' "$TMP_ROOT/out.txt"; then
    pass "a path-shaped label that names no file fails the check"
else
    fail "a path-shaped label that names no file fails the check"
fi

write_label_source './targets.md' 'targets.md#good-heading'
run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a relative path label that resolves beside the page passes"
else
    fail "a relative path label that resolves beside the page passes"
fi

write_label_source 'the target page' 'targets.md#good-heading'
run_checker "$FIX"
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a descriptive label passes"
else
    fail "a descriptive label passes"
fi

# ───────────────────────────────────────────────────────────────
# 7. YEAR TOPIC IDS AND LINKS INTO THE TOPIC FOLDER
# ───────────────────────────────────────────────────────────────

group "year topic ids"
write_topic "$FIX"
sed -i.bak '/<a id="2-key-figures"><\/a>/d' "$FIX_TOPIC/figures.md"
write_source 'targets.md#good-heading'
run_checker "$FIX"
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'vat/figures.md:7 2-key-figures missing-id' "$TMP_ROOT/out.txt"; then
    pass "a topic part that misses one id is rejected"
else
    fail "a topic part that misses one id is rejected"
fi

# The run above still holds the broken part, so the year files beside the
# topic folder must stay out of its output.
if [[ "$status" -eq 1 ]] && ! grep -qE 'changelog\.md|changes\.md' "$TMP_ROOT/out.txt"; then
    pass "the year changelog and change note are not held to the topic ids"
else
    fail "the year changelog and change note are not held to the topic ids"
fi

write_topic "$FIX"
sed -i.bak \
    -e 's/id="1-overview"/id="SWAP-A"/' \
    -e 's/id="2-key-figures"/id="SWAP-B"/' \
    -e 's/id="SWAP-A"/id="2-key-figures"/' \
    -e 's/id="SWAP-B"/id="1-overview"/' "$FIX_TOPIC/figures.md"
run_checker "$FIX"
status=$?
if [[ "$status" -eq 1 ]] && grep -qF 'out-of-order' "$TMP_ROOT/out.txt"; then
    pass "a topic part whose ids are out of order is rejected"
else
    fail "a topic part whose ids are out of order is rejected"
fi

write_topic "$FIX"
check_link "a link into a nested topic part resolves" 'tax-rules/2026/vat/notes.md#5-changes' ok
check_link "a nested link with a renamed anchor is rejected" 'tax-rules/2026/vat/notes.md#5-changes-old' missing-fragment
check_link "a missing nested file is rejected" 'tax-rules/2026/missing.md#anywhere' missing-path

# ───────────────────────────────────────────────────────────────
# 8. RENAMED HEADING IN A COPY OF THE REAL TREE
# ───────────────────────────────────────────────────────────────

group "renamed heading in a copy"
COPY="$TMP_ROOT/real-copy"
MUTATED="$COPY/sk-moneybird-accountant/references/migration/shared-mechanisms.md"
copy_tree "$REPO_ROOT" "$COPY" || abort_setup "the copy of the real tree cannot be built"

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
# 9. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
