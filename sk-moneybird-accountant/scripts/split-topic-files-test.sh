#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SPLIT TOPIC FILES TEST
# ───────────────────────────────────────────────────────────────
# Tests split-topic-files.py against a fixture repository that holds two year
# folders, three topic files with the eight numbered H2 sections, a small
# guide whose section 3 and cross-year sections carry the 13 general slugs and
# one citing file with a path, a path:line and a path#anchor citation.
# Usage: split-topic-files-test.sh
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing script files
#
# WHY: the splitter is only trustworthy when it accepts a clean split, rejects
# every drift this suite seeds and remaps each citation form to the right part
# and line. This suite proves both directions.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
# WHY: the token case runs only when the checker can load the cached o200k
# encoding, and it reports a noted pass when the cache is unavailable.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
CHECKER="$SCRIPT_DIR/split-topic-files.py"

if [[ "$#" -gt 0 ]]; then
    printf 'error: usage: split-topic-files-test.sh\n' >&2
    exit 2
fi
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/split-topic-files.py next to this test\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/split-topic-files-test.XXXXXX") || exit 2

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
    printf 'pass: %s\n' "$1"
}

# Record a failing check and print its report line
# Args:
#   $1 - Check description
fail() {
    failed=$((failed + 1))
    printf 'fail: %s\n' "$1"
}

# Record a failing check and show the captured splitter output
# Args:
#   $1 - Check description
case_failed() {
    fail "$1"
    if [[ -f "$TMP_ROOT/out.txt" ]]; then
        cat "$TMP_ROOT/out.txt"
    fi
}

# Print a section heading before the next block of checks
# Args:
#   $1 - Group title
group() {
    printf '\n== %s\n' "$1"
}

# Print one checksum line per file under a folder, in path order
# Args:
#   $1 - Folder to walk
tree_checksums() {
    local root="$1"
    (
        cd "$root" || exit 1
        find . -type f | LC_ALL=C sort | while IFS= read -r file; do
            cksum "$file"
        done
    )
}

# Run the splitter of one fixture repository and capture its output
# Args:
#   $1 - Fixture repository root
#   $2 - Mode flag
# Returns:
#   The splitter exit status, with its output in $TMP_ROOT/out.txt
run_splitter() {
    local root="$1"
    local mode="$2"
    python3 -I "$root/sk-moneybird-accountant/scripts/split-topic-files.py" "$mode" >"$TMP_ROOT/out.txt" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 4. FIXTURE BUILDER
# ───────────────────────────────────────────────────────────────

# Build a fixture repository with two year folders, three topic files, a small
# guide and one citing file. The guide subsections and cross-year headings
# carry the 13 mechanical slugs the splitter allows.
# Args:
#   $1 - Fixture repository root
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local repo_root="$1"
    local skill="$repo_root/sk-moneybird-accountant"
    local year2020="$skill/references/tax-rules/2020"
    local year2021="$skill/references/tax-rules/2021"
    local cited_line

    mkdir -p "$skill/scripts" "$year2020" "$year2021" || return 1
    cp "$CHECKER" "$skill/scripts/split-topic-files.py" || return 1

    cat >"$year2020/btw.md" <<'EOF'
---
title: "BTW 2020"
description: "Covers Dutch VAT for the split suite."
nav_label: "BTW"
importance_tier: "normal"
contextType: "reference"
version: "1.0"
trigger_phrases:
  - "fixture vat"
---

# BTW 2020

**Rule:** The fixture rule line for the split suite.

## 1. KEY FIGURES

<!-- GENERATED:fixture-nav:start -->
Generated navigation body with a [relative link](README.md).
<!-- GENERATED:fixture-nav:end -->

| Item | Value 2020 |
|---|---|
| Standard rate | 21 percent |

## 2. KEY FIGURE NOTES

Fixture key figure notes.

## 3. HOW IT WORKS

Fixture rule text. See the [year overview](README.md) and the [income topic](inkomstenbelasting.md).

The citation target line for the suite.

## 4. WORKED EXAMPLES

Fixture worked example.

## 5. CHANGES

Fixture changes text.

## 6. IN THE BOOKS

Fixture books text.

## 7. OPEN POINTS

Fixture open points text.

## 8. RELATED RESOURCES

Fixture resources text.
EOF

    cat >"$year2020/inkomstenbelasting.md" <<'EOF'
---
title: "Income tax 2020"
description: "Covers Dutch income tax for the split suite."
nav_label: "Income tax"
importance_tier: "normal"
contextType: "reference"
version: "1.0"
trigger_phrases:
  - "fixture income tax"
---

# Income tax 2020

**Rule:** The fixture income rule line.

## 1. KEY FIGURES

Fixture income key figures.

## 2. KEY FIGURE NOTES

Fixture income key notes.

## 3. HOW IT WORKS

Fixture income rules.

## 4. WORKED EXAMPLES

Fixture income example.

## 5. CHANGES

Fixture income changes.

## 6. IN THE BOOKS

Fixture income books.

## 7. OPEN POINTS

Fixture income open points.

## 8. RELATED RESOURCES

Fixture income resources.
EOF

    cat >"$year2020/README.md" <<'EOF'
---
title: "Tax year 2020"
description: "Fixture year overview."
---

# Tax year 2020

Fixture year overview.
EOF

    cat >"$year2021/btw.md" <<'EOF'
---
title: "BTW 2021"
description: "Covers Dutch VAT for the split suite."
nav_label: "BTW"
importance_tier: "normal"
contextType: "reference"
version: "1.0"
trigger_phrases:
  - "fixture vat next year"
---

# BTW 2021

**Rule:** The fixture rule line for the next year.

## 1. KEY FIGURES

Fixture next year key figures.

## 2. KEY FIGURE NOTES

Fixture next year key notes.

## 3. HOW IT WORKS

Fixture next year rules.

## 4. WORKED EXAMPLES

Fixture next year example.

## 5. CHANGES

Fixture next year changes.

## 6. IN THE BOOKS

Fixture next year books.

## 7. OPEN POINTS

Fixture next year open points.

## 8. RELATED RESOURCES

Fixture next year resources.
EOF

    cat >"$year2021/README.md" <<'EOF'
---
title: "Tax year 2021"
description: "Fixture year overview."
---

# Tax year 2021

Fixture year overview.
EOF

    cat >"$skill/references/tax-rules/dutch-tax-rules.md" <<'EOF'
---
title: "Dutch tax rules"
description: "The fixture guide for the split suite."
importance_tier: "normal"
contextType: "reference"
version: "1.0"
trigger_phrases:
  - "fixture guide"
---

# Dutch tax rules

**Rule:** The fixture guide rule line.

## 1. SCOPE

Fixture scope text.

## 2. HOW TO USE

Fixture use text.

## 3. GENERAL RULES

Fixture general lead text.

### 3.1 BTW (VAT)

Fixture general topic 3.1.

### 3.2 INCOME TAX BOX 1 AND THE ZVW CONTRIBUTION

Fixture general topic 3.2.

### 3.3 ONDERNEMERSAFTREK AND MKB-WINSTVRIJSTELLING

Fixture general topic 3.3.

### 3.4 INVESTMENT DEDUCTIONS AND DEPRECIATION

Fixture general topic 3.4.

### 3.5 COSTS AND THE CAR

Fixture general topic 3.5.

### 3.6 BOX 3 SAVINGS AND INVESTMENTS

Fixture general topic 3.6.

### 3.7 BOX 2 AND THE SUBSTANTIAL INTEREST

Fixture general topic 3.7.

### 3.8 THE BV AND VENNOOTSCHAPSBELASTING

Fixture general topic 3.8.

### 3.9 PENSION LIJFRENTE AND AOV

Fixture general topic 3.9.

### 3.10 WORK RELATIONSHIP AND PROCEDURE

Fixture general topic 3.10.

## 4. SETTLED SOURCE CONFLICTS

Fixture settled source conflicts.

## 5. OPEN POINTS AND GAPS

Fixture open points and gaps.

## 6. RECORD AND INVOICE DUTIES

Fixture record and invoice duties.

## 7. WHERE TO START

Fixture start text.

## 8. RELATED

Fixture related text.
EOF

    cited_line=$(grep -n 'The citation target line for the suite.' "$year2020/btw.md" | cut -d: -f1) || return 1
    cat >"$repo_root/citations.md" <<EOF
# Citation fixture

- Bare path: sk-moneybird-accountant/references/tax-rules/2020/btw.md
- Line path: sk-moneybird-accountant/references/tax-rules/2020/btw.md:${cited_line}
- Anchor path: sk-moneybird-accountant/references/tax-rules/2020/btw.md#3-how-it-works
EOF
    return 0
}

# ───────────────────────────────────────────────────────────────
# 5. CLEAN SPLIT
# ───────────────────────────────────────────────────────────────

group "clean split"
FIXTURE="$TMP_ROOT/repo"
if ! make_fixture "$FIXTURE"; then
    printf 'error: cannot build the fixture tree\n' >&2
    exit 2
fi

ORIGINAL_BTW="$TMP_ROOT/original-btw.md"
cp "$FIXTURE/sk-moneybird-accountant/references/tax-rules/2020/btw.md" "$ORIGINAL_BTW" || exit 2

CLEAN="$TMP_ROOT/clean"
cp -R "$FIXTURE" "$CLEAN" || exit 2

run_splitter "$CLEAN" --write
status=$?
if [[ "$status" -eq 0 ]] \
    && [[ -f "$CLEAN/sk-moneybird-accountant/references/tax-rules/split-manifest.json" ]]; then
    run_splitter "$CLEAN" --check
    status=$?
    cp "$TMP_ROOT/out.txt" "$TMP_ROOT/clean-check.txt"
    if [[ "$status" -eq 0 ]] \
        && grep -qF 'split-check: ok' "$TMP_ROOT/clean-check.txt" \
        && grep -qF 'leftovers: 0' "$TMP_ROOT/clean-check.txt" \
        && grep -qF 'unmapped citations: 0' "$TMP_ROOT/clean-check.txt" \
        && [[ "$(grep -c '^rejoin ok ' "$TMP_ROOT/clean-check.txt")" -eq 4 ]]; then
        pass "clean split passes --check"
    else
        case_failed "clean split passes --check"
    fi
else
    case_failed "clean split passes --check"
fi

# ───────────────────────────────────────────────────────────────
# 6. MUTANTS
# ───────────────────────────────────────────────────────────────

group "mutants"

# Case: one hand-edited part byte fails --check and names the part
HAND_EDIT="$TMP_ROOT/hand-edit"
cp -R "$CLEAN" "$HAND_EDIT" || exit 2
printf 'A hand edit that the manifest does not know.\n' \
    >>"$HAND_EDIT/sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md"
run_splitter "$HAND_EDIT" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -qF 'drift sk-moneybird-accountant/references/tax-rules/2020/btw.md part sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md' "$TMP_ROOT/out.txt"; then
    pass "hand-edited part"
else
    case_failed "hand-edited part"
fi

# Case: a hand edit to the derived header fails --check as a body edit does
HEADER_EDIT="$TMP_ROOT/header-edit"
cp -R "$CLEAN" "$HEADER_EDIT" || exit 2
HEADER_PART="$HEADER_EDIT/sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md"
python3 -I - "$HEADER_PART" <<'PY' || exit 2
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
start = text.index("\n# ") + 1
end = text.index("\n", start)
open(path, "w", encoding="utf-8").write(text[:end] + " (edited)" + text[end:])
PY
run_splitter "$HEADER_EDIT" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -qF 'drift sk-moneybird-accountant/references/tax-rules/2020/btw.md part sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md (header hash' "$TMP_ROOT/out.txt"; then
    pass "hand-edited header"
else
    case_failed "hand-edited header"
fi

# Case: a hand edit to the kept entry file fails --check
ENTRY_EDIT="$TMP_ROOT/entry-edit"
cp -R "$CLEAN" "$ENTRY_EDIT" || exit 2
printf 'A hand edit to the entry file.\n' \
    >>"$ENTRY_EDIT/sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md"
run_splitter "$ENTRY_EDIT" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -qF 'drift sk-moneybird-accountant/references/tax-rules/dutch-tax-rules.md entry (entry hash' "$TMP_ROOT/out.txt"; then
    pass "hand-edited entry file"
else
    case_failed "hand-edited entry file"
fi

# Case: a GENERATED fence the index generator adds after the H1 keeps --check green
FENCED="$TMP_ROOT/fenced"
cp -R "$CLEAN" "$FENCED" || exit 2
python3 -I - "$FENCED/sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md" <<'PY' || exit 2
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
start = text.index("\n# ") + 1
end = text.index("\n", start) + 1
fence = "\n<!-- GENERATED:nav:start -->\nRead plan: 1 part.\n<!-- GENERATED:nav:end -->\n"
open(path, "w", encoding="utf-8").write(text[:end] + fence + text[end:])
PY
run_splitter "$FENCED" --check
status=$?
if [[ "$status" -eq 0 ]] && grep -qF 'split-check: ok' "$TMP_ROOT/out.txt"; then
    pass "generated fence in the header does not fail"
else
    case_failed "generated fence in the header does not fail"
fi

# Case: a returned original fails --check and names the leftover
RETURNED="$TMP_ROOT/returned"
cp -R "$CLEAN" "$RETURNED" || exit 2
cp "$ORIGINAL_BTW" "$RETURNED/sk-moneybird-accountant/references/tax-rules/2020/btw.md"
run_splitter "$RETURNED" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -qF 'leftover original sk-moneybird-accountant/references/tax-rules/2020/btw.md' "$TMP_ROOT/out.txt"; then
    pass "returned original"
else
    case_failed "returned original"
fi

# Case: an unmappable citation exits non-zero and writes nothing
UNMAPPABLE="$TMP_ROOT/unmappable"
cp -R "$FIXTURE" "$UNMAPPABLE" || exit 2
printf -- '- Broken line: sk-moneybird-accountant/references/tax-rules/2020/btw.md:9999\n' \
    >>"$UNMAPPABLE/citations.md"
before=$(tree_checksums "$UNMAPPABLE")
run_splitter "$UNMAPPABLE" --write
status=$?
after=$(tree_checksums "$UNMAPPABLE")
if [[ "$status" -ne 0 ]] \
    && grep -qF '9999' "$TMP_ROOT/out.txt" \
    && [[ "$before" == "$after" ]]; then
    pass "unmappable citation"
else
    case_failed "unmappable citation"
fi

# Case: a topic folder that holds fewer than four parts fails --check
SHORT_FOLDER="$TMP_ROOT/short-folder"
cp -R "$CLEAN" "$SHORT_FOLDER" || exit 2
rm "$SHORT_FOLDER/sk-moneybird-accountant/references/tax-rules/2020/inkomstenbelasting/examples.md"
run_splitter "$SHORT_FOLDER" --check
status=$?
if [[ "$status" -eq 1 ]] \
    && grep -qF 'missing part sk-moneybird-accountant/references/tax-rules/2020/inkomstenbelasting/examples.md' "$TMP_ROOT/out.txt" \
    && grep -qF 'short folder sk-moneybird-accountant/references/tax-rules/2020/inkomstenbelasting holds 3 of 4 parts' "$TMP_ROOT/out.txt"; then
    pass "folder with fewer than four parts"
else
    case_failed "folder with fewer than four parts"
fi

# Case: a part pushed over the token line fails --check, when the cached
# encoding is available. The clean check prints the tokens line only when the
# checker loaded the encoder.
if [[ -f "$TMP_ROOT/clean-check.txt" ]] && ! grep -q '^tokens: largest ' "$TMP_ROOT/clean-check.txt"; then
    pass "part pushed over the token line (skipped, tiktoken cache unavailable)"
else
    TOKEN_FIXTURE="$TMP_ROOT/token-fixture"
    cp -R "$FIXTURE" "$TOKEN_FIXTURE" || exit 2
    awk 'BEGIN { for (i = 1; i <= 2200; i++) print "Fixture filler line that gives the topic file its length." }' \
        >>"$TOKEN_FIXTURE/sk-moneybird-accountant/references/tax-rules/2020/inkomstenbelasting.md"
    run_splitter "$TOKEN_FIXTURE" --write
    write_status=$?
    run_splitter "$TOKEN_FIXTURE" --check
    check_status=$?
    if [[ "$write_status" -eq 0 ]] \
        && [[ "$check_status" -eq 1 ]] \
        && grep -qF 'over token line sk-moneybird-accountant/references/tax-rules/2020/inkomstenbelasting/notes.md' "$TMP_ROOT/out.txt"; then
        pass "part pushed over the token line"
    else
        case_failed "part pushed over the token line"
    fi
fi

# ───────────────────────────────────────────────────────────────
# 7. REJOIN, IDEMPOTENCE AND CITATIONS
# ───────────────────────────────────────────────────────────────

group "rejoin, idempotence and citations"

# Case: a rebased relative link does not fail --check
if grep -qF '](../README.md)' "$CLEAN/sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md" \
    && grep -qF '](../inkomstenbelasting/figures.md)' "$CLEAN/sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md"; then
    run_splitter "$CLEAN" --check
    status=$?
    if [[ "$status" -eq 0 ]]; then
        pass "rebased link does not fail"
    else
        case_failed "rebased link does not fail"
    fi
else
    fail "rebased link does not fail"
fi

# Case: a second --write changes no byte
before=$(tree_checksums "$CLEAN")
run_splitter "$CLEAN" --write
status=$?
after=$(tree_checksums "$CLEAN")
if [[ "$status" -eq 0 ]] && [[ "$before" == "$after" ]]; then
    pass "second --write changes no byte"
else
    case_failed "second --write changes no byte"
fi

# Case: the remapped citations land on the right part and line
CITATIONS="$CLEAN/citations.md"
RULES_PART="$CLEAN/sk-moneybird-accountant/references/tax-rules/2020/btw/rules.md"
if grep -qF '2020/btw/figures.md' "$CITATIONS" \
    && grep -qF '2020/btw/rules.md#3-how-it-works' "$CITATIONS" \
    && grep -qF '## 3. HOW IT WORKS' "$RULES_PART" \
    && python3 - "$CITATIONS" "$RULES_PART" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"btw/rules\.md:(?P<line>[0-9]+)", text)
if not match:
    sys.exit(1)
lines = open(sys.argv[2], encoding="utf-8").read().split("\n")
number = int(match.group("line"))
expected = "The citation target line for the suite."
sys.exit(0 if 1 <= number <= len(lines) and lines[number - 1].strip() == expected else 1)
PY
then
    pass "remapped citations land on the right part and line"
else
    fail "remapped citations land on the right part and line"
fi

# ───────────────────────────────────────────────────────────────
# 8. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
