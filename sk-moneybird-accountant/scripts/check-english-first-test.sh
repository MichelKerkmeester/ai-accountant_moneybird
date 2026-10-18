#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ENGLISH FIRST CHECK TEST
# ───────────────────────────────────────────────────────────────
# Tests check-english-first.py against a fixture repository, a
# summary fixture and the real corpus.
# Usage: check-english-first-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: a rule earns trust only when it reports a bad fixture and accepts the
# fixed one. This suite proves that for every rule, for the masked regions
# and for a second byte-identical run.
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
    printf 'error: usage: check-english-first-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

CHECKER="$SKILL_SRC/scripts/check-english-first.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-english-first.py in the skill folder\n' >&2
    exit 2
fi

REPO_ROOT=$(dirname "$SKILL_SRC")

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/english-first-test.XXXXXX") || exit 2

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

# Run the checker against one repository and capture its output
# Args:
#   $1 - Repository root
#   $2... - Extra checker arguments
# Returns:
#   The checker exit status, with output in $TMP_ROOT/out.txt
run_checker() {
    local root="$1"
    shift
    python3 -I "$CHECKER" --root "$root" "$@" >"$TMP_ROOT/out.txt" 2>&1
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

# ───────────────────────────────────────────────────────────────
# 5. FIXTURE BUILDERS AND FIXTURE HELPERS
# ───────────────────────────────────────────────────────────────

FIX="$TMP_ROOT/fixture"
CASE="$FIX/sk-moneybird-accountant/references/case.md"
EXCEPTIONS="$FIX/sk-moneybird-accountant/assets/english-first-exceptions.json"

# Write the glossary folder under one repository root
# Args:
#   $1 - Repository root
# Returns:
#   0 when the files are written, 1 when a write fails
write_glossaries() {
    local dir="$1/sk-moneybird-accountant/references/glossary"
    mkdir -p "$dir" || return 1
    cat >"$dir/README.md" <<'MARKDOWN' || return 1
# Glossary router

| English | Dutch | Note |
|---|---|---|
| router only | alleen de router |  |
MARKDOWN
    cat >"$dir/general.md" <<'MARKDOWN' || return 1
# Glossary

| English | Dutch | Note |
|---|---|---|
| assessment | aanslag |  |
| additional assessment | navorderingsaanslag |  |
| provisional assessment | voorlopige aanslag |  |
| Dutch Tax and Customs Administration | belastingdienst | official name |
| VAT return box | rubriek |  |
| parts | onderdelen |  |
MARKDOWN
    cat >"$dir/procedure.md" <<'MARKDOWN' || return 1
# Single use terms

| English | Dutch | Note |
|---|---|---|
| carry-forward | voortwenteling |  |
MARKDOWN
    return 0
}

# Write the empty exceptions file beside the fixture
# Returns:
#   0 when the file is written, 1 when a write fails
write_exceptions_empty() {
    mkdir -p "$(dirname "$EXCEPTIONS")" || return 1
    printf '{"exceptions": []}\n' >"$EXCEPTIONS" || return 1
}

# Write one exceptions row for the case file
# Args:
#   $1 - Dutch term
#   $2 - Check name, residual or first-use
# Returns:
#   0 when the file is written, 1 when a write fails
write_case_exception() {
    local term="$1"
    local check="$2"
    mkdir -p "$(dirname "$EXCEPTIONS")" || return 1
    cat >"$EXCEPTIONS" <<JSON || return 1
{"exceptions": [{"file": "sk-moneybird-accountant/references/case.md", "term": "$term", "check": "$check", "rule": "E1", "reason": "fixture"}]}
JSON
}

# Write an exceptions file whose row carries a bad check value
# Returns:
#   0 when the file is written, 1 when a write fails
write_exceptions_malformed() {
    mkdir -p "$(dirname "$EXCEPTIONS")" || return 1
    printf '{"exceptions": [{"file": "sk-moneybird-accountant/references/case.md", "term": "aanslag", "check": "wrong", "rule": "E1", "reason": "fixture"}]}\n' >"$EXCEPTIONS" || return 1
}

# Replace the case file with the markdown on standard input
# Returns:
#   0 when the file is written, 1 when a write fails
write_case() {
    cat >"$CASE" || return 1
}

# Print the line number of the first line that holds one text
# Args:
#   $1 - Text to find in the case file
case_line() {
    grep -nF "$1" "$CASE" | head -1 | cut -d: -f1
}

# Run the checker and require a clean exit
# Args:
#   $1 - Check description
check_clean() {
    local description="$1"
    run_checker "$FIX"
    local status=$?
    if [[ "$status" -eq 0 ]]; then
        pass "$description"
    else
        fail "$description"
    fi
}

# Run the checker and require one report line
# Args:
#   $1 - Check description
#   $2 - Report line to find
check_reported() {
    local description="$1"
    local needle="$2"
    run_checker "$FIX"
    local status=$?
    if [[ "$status" -eq 1 ]] && grep -qF "$needle" "$TMP_ROOT/out.txt"; then
        pass "$description"
    else
        fail "$description"
    fi
}

# Run the checker and require a chosen exit code
# Args:
#   $1 - Check description
#   $2 - Expected exit code
check_exit() {
    local description="$1"
    local expected="$2"
    run_checker "$FIX"
    local status=$?
    if [[ "$status" -eq "$expected" ]]; then
        pass "$description"
    else
        fail "$description"
    fi
}

# Build the fixture repository with both glossaries, an exceptions file and a case file
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local root="$1"
    mkdir -p "$root/sk-moneybird-accountant/references" || return 1
    mkdir -p "$root/sk-moneybird-accountant/assets" || return 1
    write_glossaries "$root" || return 1
    printf '{"exceptions": []}\n' \
        >"$root/sk-moneybird-accountant/assets/english-first-exceptions.json" || return 1
    printf '# Case\n\nA clean line.\n' \
        >"$root/sk-moneybird-accountant/references/case.md" || return 1
    return 0
}

# Build the summary fixture with one year file and one outside file
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_summary_fixture() {
    local root="$1"
    local references="$root/sk-moneybird-accountant/references"
    mkdir -p "$references/tax-rules/2024" || return 1
    write_glossaries "$root" || return 1
    printf '# Topic\n\nThe navorderingsaanslag arrives.\n' \
        >"$references/tax-rules/2024/topic.md" || return 1
    printf '# Outside\n\nThe provisional assessment is due.\n' \
        >"$references/outside.md" || return 1
    return 0
}

# ───────────────────────────────────────────────────────────────
# 6. FIXTURE CORPUS
# ───────────────────────────────────────────────────────────────

group "fixture corpus"
if make_fixture "$FIX"; then
    pass "fixture repository builds"
else
    fail "fixture repository builds"
fi
check_clean "the clean fixture corpus passes"

# ───────────────────────────────────────────────────────────────
# 7. RESIDUAL
# ───────────────────────────────────────────────────────────────

group "residual"
write_case <<'MARKDOWN'
# Case

The voorlopige aanslag arrives.
MARKDOWN
line=$(case_line 'The voorlopige aanslag arrives')
check_reported "a lone Dutch term is a residual" \
    "sk-moneybird-accountant/references/case.md:${line}: residual: voorlopige aanslag"

write_case <<'MARKDOWN'
# Case

The provisional assessment (voorlopige aanslag) arrives.
MARKDOWN
check_clean "a labelled Dutch term is not a residual"

# ───────────────────────────────────────────────────────────────
# 8. FIRST USE
# ───────────────────────────────────────────────────────────────

group "first-use"
write_case <<'MARKDOWN'
# Case

## Section one

The provisional assessment is due.
MARKDOWN
line=$(case_line 'The provisional assessment is due')
check_reported "an unlabelled first use is a first-use problem" \
    "sk-moneybird-accountant/references/case.md:${line}: first-use: voorlopige aanslag"

write_case <<'MARKDOWN'
# Case

## Section one

The provisional assessment (voorlopige aanslag) is due.

## Section two

The provisional assessment is collected.
MARKDOWN
line=$(case_line 'The provisional assessment is collected')
check_reported "a new section restarts the first-use label" \
    "sk-moneybird-accountant/references/case.md:${line}: first-use: voorlopige aanslag"

write_case <<'MARKDOWN'
# Case

## Section one

The provisional assessment (voorlopige aanslag) is due.

## Section two

The provisional assessment (voorlopige aanslag) is collected.
MARKDOWN
check_clean "a label in every section passes first use"

write_case <<'MARKDOWN'
# Case

The Dutch Tax and Customs Administration collects it.
MARKDOWN
line=$(case_line 'The Dutch Tax and Customs Administration collects it')
check_reported "an unlabelled official name is a first-use problem" \
    "sk-moneybird-accountant/references/case.md:${line}: first-use: belastingdienst"

write_case <<'MARKDOWN'
# Case

The Dutch Tax and Customs Administration (Belastingdienst) collects it.
MARKDOWN
check_clean "a labelled official name passes first use"

write_case <<'MARKDOWN'
# Case

The amount is provisional. Assessment notices follow.
MARKDOWN
check_clean "a term never spans a full stop"

write_case <<'MARKDOWN'
# Case

## Section one

The provisional assessment (voorlopige aanslag) is due.

### Detail

The provisional assessment is collected.
MARKDOWN
check_clean "a deeper heading stays inside its H2 section"

write_case <<'MARKDOWN'
# Case

## Section one

The Dutch Tax and Customs Administration (Belastingdienst) collects it.

## Section two

The Dutch Tax and Customs Administration refunds it.
MARKDOWN
check_clean "an official name is labelled once per file"

# ───────────────────────────────────────────────────────────────
# 9. DOUBLED
# ───────────────────────────────────────────────────────────────

group "doubled"
write_case <<'MARKDOWN'
# Case

See rubriek 1d (rubriek 1d).
MARKDOWN
line=$(case_line 'See rubriek 1d')
check_reported "a label repeated as its own text is a doubled problem" \
    "sk-moneybird-accountant/references/case.md:${line}: doubled: rubriek 1d"

write_case <<'MARKDOWN'
# Case

See rubriek 1d.
MARKDOWN
check_clean "a single label is not a doubled problem"

# ───────────────────────────────────────────────────────────────
# 10. REVERSED
# ───────────────────────────────────────────────────────────────

group "reversed"
write_case <<'MARKDOWN'
# Case

The belastingdienst (Dutch Tax and Customs Administration) collects it.
MARKDOWN
line=$(case_line 'The belastingdienst')
check_reported "a Dutch first pair is a reversed problem" \
    "sk-moneybird-accountant/references/case.md:${line}: reversed: belastingdienst"

write_case <<'MARKDOWN'
# Case

The Dutch Tax and Customs Administration (Belastingdienst) collects it.
MARKDOWN
check_clean "an English first pair is not a reversed problem"

# ───────────────────────────────────────────────────────────────
# 11. UNGLOSSED
# ───────────────────────────────────────────────────────────────

group "unglossed"
write_case <<'MARKDOWN'
# Case

The rule applies (voorlopige aanslag deadline).
MARKDOWN
line=$(case_line 'The rule applies')
check_reported "an unnamed Dutch bracket is an unglossed problem" \
    "sk-moneybird-accountant/references/case.md:${line}: unglossed: voorlopige aanslag deadline"

write_case <<'MARKDOWN'
# Case

The rule applies (voorlopige aanslag).
MARKDOWN
check_clean "a named Dutch bracket is not an unglossed problem"

write_case <<'MARKDOWN'
# Case

The rule applies (assessment).
MARKDOWN
check_clean "an English bracket is not an unglossed problem"

# ───────────────────────────────────────────────────────────────
# 12. EXCEPTIONS
# ───────────────────────────────────────────────────────────────

group "exceptions"
write_case <<'MARKDOWN'
# Case

The navorderingsaanslag arrives.
MARKDOWN
write_case_exception navorderingsaanslag residual
check_clean "an exception suppresses a residual"

write_case <<'MARKDOWN'
# Case

The provisional assessment is due.
MARKDOWN
write_case_exception voorlopige\ aanslag first-use
check_clean "an exception suppresses a first use"

write_case <<'MARKDOWN'
# Case

A clean line.
MARKDOWN
write_case_exception navorderingsaanslag residual
check_reported "an exception that suppresses nothing is stale" \
    "sk-moneybird-accountant/references/case.md:0: stale-exception: navorderingsaanslag"

write_exceptions_empty
check_clean "a fixture without stale exceptions passes"

write_exceptions_malformed
check_exit "a bad exceptions check exits 2" 2
write_exceptions_empty

# ───────────────────────────────────────────────────────────────
# 13. MASKING
# ───────────────────────────────────────────────────────────────

group "masking"
write_case <<'MARKDOWN'
# Case

A term in `voorlopige aanslag` stays code.

A URL https://example.test/voorlopige-aanslag stays a URL.

A label [navorderingsaanslag](https://example.test/other) stays a label.

A quote "voorlopige aanslag" stays official text.

A citation art. 3.16 lid 2 voorlopige aanslag stays a citation.

<!-- GENERATED:demo:start -->
voorlopige aanslag
<!-- GENERATED:demo:end -->

| Name | Source |
|---|---|
| row | voorlopige aanslag |
MARKDOWN
check_clean "masked regions hold no problem"

write_case <<'MARKDOWN'
# Case

Report it in rubriek 1d of the VAT return box (rubriek).
MARKDOWN
check_clean "a rubriek code is data, not a residual"

write_case <<'MARKDOWN'
# Case

Article 11 lid 1 onderdelen a to w exempts it.
MARKDOWN
check_clean "a plural onderdelen citation is data, not a residual"

# WHY: a playbook prompt is test data, but the same label in a reference file
# is prose, so the mask applies only inside the playbook folders.
PROMPT_CASE=$(cat <<'MARKDOWN'
# Case

- Prompt: Book the voorlopige aanslag for this year.
- Real user request: Book the voorlopige aanslag for this year.

| Feature ID | Exact Prompt | Notes |
|---|---|---|
| T-1 | Book the voorlopige aanslag for this year. | none |
MARKDOWN
)
PLAYBOOK_CASE="$FIX/sk-moneybird-accountant/manual-testing-playbook/case.md"
mkdir -p "$(dirname "$PLAYBOOK_CASE")"
printf '%s\n' "$PROMPT_CASE" >"$PLAYBOOK_CASE"
check_clean "a playbook prompt is test data, not a residual"
rm -rf "$FIX/sk-moneybird-accountant/manual-testing-playbook"

printf '%s\n' "$PROMPT_CASE" >"$CASE"
run_checker "$FIX"
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -qF 'sk-moneybird-accountant/references/case.md:3: residual: voorlopige aanslag' "$TMP_ROOT/out.txt" \
    && grep -qF 'sk-moneybird-accountant/references/case.md:4: residual: voorlopige aanslag' "$TMP_ROOT/out.txt" \
    && grep -qF 'sk-moneybird-accountant/references/case.md:8: residual: voorlopige aanslag' "$TMP_ROOT/out.txt"; then
    pass "a Prompt label in a reference file is a finding"
else
    fail "a Prompt label in a reference file is a finding"
fi

write_case <<'MARKDOWN'
# Case

Report it in rubriek 1d (rubriek 1d).
MARKDOWN
line=$(case_line 'Report it in rubriek 1d')
check_reported "a doubled rubriek label is still reported" \
    "sk-moneybird-accountant/references/case.md:${line}: doubled: rubriek 1d"

# ───────────────────────────────────────────────────────────────
# 13A. GLOSSARY FOLDER
# ───────────────────────────────────────────────────────────────

group "glossary folder"
write_case <<'MARKDOWN'
# Case

The carry-forward (voortwenteling) applies.
MARKDOWN
check_clean "a term from a second category file labels a first use"

write_case <<'MARKDOWN'
# Case

Ask alleen de router here.
MARKDOWN
check_clean "a table row in the router README is not a glossary term"

GLOSSARY_DIR="$FIX/sk-moneybird-accountant/references/glossary"
printf '| English | Dutch | Note |\n|---|---|---|\n| Additional assessment | Navorderingsaanslag |  |\n' >"$GLOSSARY_DIR/vat.md"
write_case <<'MARKDOWN'
# Case

The additional assessment (navorderingsaanslag) arrives.
MARKDOWN
check_reported "a pair held in two glossary files is a duplicate" \
    "sk-moneybird-accountant/references/glossary/vat.md:3: duplicate: Navorderingsaanslag"
rm -f "$GLOSSARY_DIR/vat.md"
check_clean "the duplicate clears once the second file is gone"

# ───────────────────────────────────────────────────────────────
# 14. DETERMINISM
# ───────────────────────────────────────────────────────────────

group "determinism"
write_case <<'MARKDOWN'
# Case

The voorlopige aanslag arrives.
MARKDOWN
run_checker "$FIX"
cp "$TMP_ROOT/out.txt" "$TMP_ROOT/out-first.txt"
run_checker "$FIX"
if cmp -s "$TMP_ROOT/out-first.txt" "$TMP_ROOT/out.txt"; then
    pass "a second run prints identical bytes"
else
    fail "a second run prints identical bytes"
fi

# ───────────────────────────────────────────────────────────────
# 15. SUMMARY
# ───────────────────────────────────────────────────────────────

group "summary"
SUM="$TMP_ROOT/summary"
make_summary_fixture "$SUM"
cat >"$TMP_ROOT/summary-expected.txt" <<'TEXT'
residual: 1
first-use: 1
doubled: 0
reversed: 0
unglossed: 0
duplicate: 0
stale-exception: 0
outside tax-rules: 1
tax-rules 2024: 1
2 problems
TEXT
if run_checker "$SUM" --summary; then
    fail "the summary counts every rule and area"
elif cmp -s "$TMP_ROOT/summary-expected.txt" "$TMP_ROOT/out.txt"; then
    pass "the summary counts every rule and area"
else
    fail "the summary counts every rule and area"
fi

# ───────────────────────────────────────────────────────────────
# 16. RULE FILTER
# ───────────────────────────────────────────────────────────────

group "rule filter"
write_case <<'MARKDOWN'
# Case

The voorlopige aanslag arrives.
MARKDOWN
write_exceptions_empty
run_checker "$FIX" --rule doubled
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a rule filter that matches nothing passes"
else
    fail "a rule filter that matches nothing passes"
fi
run_checker "$FIX" --rule residual
status=$?
if [[ "$status" -eq 1 ]] && grep -qF "residual: voorlopige aanslag" "$TMP_ROOT/out.txt" \
    && ! grep -qF "first-use" "$TMP_ROOT/out.txt"; then
    pass "a rule filter reports only that rule"
else
    fail "a rule filter reports only that rule"
fi

# ───────────────────────────────────────────────────────────────
# 17. REAL CORPUS
# ───────────────────────────────────────────────────────────────

group "real corpus"
assert "the real corpus is clean" python3 -I "$CHECKER" --root "$REPO_ROOT"

# ───────────────────────────────────────────────────────────────
# 18. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
