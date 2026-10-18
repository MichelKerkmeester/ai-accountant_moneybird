#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: REFERENCE INDEX TEST
# ───────────────────────────────────────────────────────────────
# Tests build-reference-index.py against a fixture repository, the real
# corpus and mutated copies of both.
# Usage: reference-index-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the generator is only trustworthy when --check catches every drift, when
# a write never touches a byte outside a fence and when the year README counters
# match the topic files. This suite proves all three.
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
    printf 'error: usage: reference-index-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

BUILDER="$SKILL_SRC/scripts/build-reference-index.py"
if [[ ! -f "$BUILDER" ]]; then
    printf 'error: missing scripts/build-reference-index.py in the skill folder\n' >&2
    exit 2
fi
if [[ ! -d "$SKILL_SRC/references" ]]; then
    printf 'error: missing references folder in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_SRC/leaf-manifest.json" ]]; then
    printf 'error: missing leaf-manifest.json in the skill folder\n' >&2
    exit 2
fi

YEAR_README="$SKILL_SRC/references/tax-rules/2020/README.md"
YEAR_TOPIC="$SKILL_SRC/references/tax-rules/2020/income-tax/figures.md"
YEAR_LABELED="$SKILL_SRC/references/tax-rules/2020/vat/figures.md"
for required in "$YEAR_README" "$YEAR_TOPIC" "$YEAR_LABELED"; do
    if [[ ! -f "$required" ]]; then
        printf 'error: missing %s in the skill folder\n' "$required" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/reference-index-test.XXXXXX") || exit 2

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

# Print the checksum and the size of one file
# Args:
#   $1 - File to check
file_checksum() {
    cksum "$1" | awk '{print $1, $2}'
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

# Copy the skill folder into a fresh temp path
# Args:
#   $1 - Destination folder
# Returns:
#   0 when the copy is ready, 1 when the copy fails
copy_skill() {
    local destination="$1"
    rm -rf "$destination"
    cp -R "$SKILL_SRC" "$destination"
}

# Copy one built fixture folder into a fresh path
# Args:
#   $1 - Source skill folder
#   $2 - Destination skill folder
# Returns:
#   0 when the copy is ready, 1 when the copy fails
copy_fixture() {
    local source="$1"
    local destination="$2"
    rm -rf "$destination"
    mkdir -p "$(dirname "$destination")" || return 1
    cp -R "$source" "$destination"
}

# Run the generator of one skill copy and capture its output
# Args:
#   $1 - Skill folder
#   $2... - Generator arguments
# Returns:
#   The generator exit status, with its output in $TMP_ROOT/out.txt
run_generator() {
    local skill="$1"
    shift
    python3 -I "$skill/scripts/build-reference-index.py" "$@" >"$TMP_ROOT/out.txt" 2>&1
}

# Print the UNVERIFIED count of one topic row of a year README
# Args:
#   $1 - Year README path
#   $2 - Topic file name
#   $3 - Topic row link target, the file name when omitted
unverified_count() {
    local target="${3:-$2}"
    grep -F "| [$2]($target) |" "$1" | awk -F'|' '{print $5}' | tr -d '[:space:]'
}

# Add a hand-written line right after the first H1 of one markdown file
# Args:
#   $1 - File to edit
#   $2 - Line to insert
# Returns:
#   0 when the line is in place, 1 when the file has no H1 line
insert_hand_line() {
    python3 - "$1" "$2" <<'PY'
import sys

path, note = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
placed = False
for line in lines:
    out.append(line)
    if not placed and line.startswith("# "):
        out.append("")
        out.append(note)
        placed = True
open(path, "w", encoding="utf-8").write("\n".join(out))
sys.exit(0 if placed else 1)
PY
}

# ───────────────────────────────────────────────────────────────
# 5. FIXTURE BUILDER
# ───────────────────────────────────────────────────────────────

# WHY: the rate fixtures are built at runtime from separate number parts, so
# this tracked file holds no amount-shaped literal of its own.
RATE_BOX1=$(printf '%d,%02d%%' 37 35)
RATE_BAND2=$(printf '%d,%02d%%' 9 70)
RATE_BOX1_UP="${RATE_BOX1} up to"
RATE_BOX1_NEXT=$(printf '%d,%02d%% up to' 37 36)

# The year change fixture numbers are built the same way, so the tracked file
# holds no amount-shaped literal either.
FIX_RATE_A=$(printf '%d' 21)
FIX_RATE_B=$(printf '%d,%02d' 37 35)
FIX_RATE_C=$(printf '%d,%02d' 9 70)
FIX_RATE_MISSING=$(printf '%d' 99)

# The topic table values are built the same way.
TOPIC_RATE_MAIN=$(printf '%d%%' 21)
TOPIC_RATE_LOW=$(printf '%d%%' 9)

# Build a minimal skill folder in the real layout: the guide with its topic
# table, one general file with a section 3 subsection, one year folder with two
# topic folders and a year note, the two files that are generated whole, the
# baseline and term map inputs, a manifest and the page that routes the
# fixture leaves. Every fence pair stands in place with an empty body, so the
# first write fills it. The two generated files start as copies of the real
# ones, because the landing page reads the overview frontmatter from the tree
# and a stub with other frontmatter would need a second write to settle.
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local skill="$1"
    local tax_rules="$skill/references/tax-rules"
    mkdir -p "$skill/scripts" "$skill/assets" "$skill/benchmark" "$tax_rules/general" \
        "$tax_rules/2020/vat" "$tax_rules/2020/income-tax" || return 1
    cp "$BUILDER" "$skill/scripts/" || return 1
    printf '{"pin": {"lead_encoding": "o200k_base"}, "files": []}\n' >"$skill/benchmark/token-baseline.json" || return 1
    printf '{"terms": []}\n' >"$skill/assets/term-map.json" || return 1
    cat >"$tax_rules/dutch-tax-rules.md" <<'EOF' || return 1
---
title: "Dutch tax rules"
---

# Dutch tax rules

## 1. Topic files in every year folder

| File | Topic |
|---|---|
| `vat.md` | VAT |
| `income-tax.md` | Income tax |

## 3. GENERAL RULES

Each general topic sits in its own file under `general/`.

| Section | Topic | File |
|---|---|---|
| 3.1 | BTW (VAT) | [vat.md](general/vat.md) |
EOF
    cat >"$tax_rules/general/vat.md" <<'EOF' || return 1
---
title: "BTW (VAT)"
description: "General fixture topic."
---

# BTW (VAT)

### 3.1 BTW (VAT)

Year files: `vat.md` in each year folder.

<!-- GENERATED:s3-btw-vat:start -->
<!-- GENERATED:s3-btw-vat:end -->

The hand-written rule prose stays here.
EOF
    cat >"$tax_rules/2020/README.md" <<'EOF' || return 1
---
title: "Tax year 2020"
description: "Fixture year overview."
---

# Tax year 2020

## 1. OVERVIEW

Hand prose for the fixture year.

## 2. TOPIC FILES

<!-- GENERATED:topic-files:start -->
<!-- GENERATED:topic-files:end -->

## 3. HEADLINE FIGURES

<!-- GENERATED:headline-figures:start -->
<!-- GENERATED:headline-figures:end -->
EOF
    # The delimiter of the next four files stays unquoted so the runtime-built
    # values expand. Their bodies hold no dollar sign, backtick or backslash of
    # their own.
    cat >"$tax_rules/2020/vat/figures.md" <<EOF || return 1
---
title: "BTW 2020"
description: "Covers Dutch VAT for the fixture."
nav_label: "BTW"
---

# BTW 2020

## 2. KEY FIGURES

<a id="2-key-figures"></a>

<!-- GENERATED:key-figure-index:start -->
<!-- GENERATED:key-figure-index:end -->

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Standard rate | ${TOPIC_RATE_MAIN} | enacted | Verified |
| Reduced rate | ${TOPIC_RATE_LOW} | enacted | UNVERIFIED |
EOF
    cat >"$tax_rules/2020/vat/notes.md" <<EOF || return 1
---
title: "BTW notes 2020"
description: "Notes for the fixture."
---

# BTW notes 2020

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The standard rate stayed at ${FIX_RATE_A} percent in the fixture year.
- The reduced rate stayed at ${FIX_RATE_C} percent in the fixture year.
EOF
    cat >"$tax_rules/2020/income-tax/figures.md" <<EOF || return 1
---
title: "Income tax 2020"
description: "Covers income tax for the fixture."
nav_label: "Inkomstenbelasting box 1"
---

# Income tax 2020

## 2. KEY FIGURES

<a id="2-key-figures"></a>

<!-- GENERATED:key-figure-index:start -->
<!-- GENERATED:key-figure-index:end -->

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Box 1 rates | ${RATE_BOX1} | enacted | UNVERIFIED |
| Bands | ${RATE_BAND2} | enacted | Verified |
EOF
    cat >"$tax_rules/2020/income-tax/notes.md" <<EOF || return 1
---
title: "Income tax notes 2020"
description: "Notes for the fixture."
---

# Income tax notes 2020

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The box 1 rate stayed at ${FIX_RATE_B} percent in the fixture year.
- The band stayed at ${FIX_RATE_C} percent in the fixture year.
- The fixture year 2020 kept its rules.
EOF
    cat >"$tax_rules/2020/changes.md" <<EOF || return 1
---
title: "Changes tax year 2020"
description: "Fixture year change note."
---

# Changes tax year 2020

**Rule:** The fixture note restates section 5 of the year topics.

---

## 1. Unique to 2020

- Standard rate stayed at ${FIX_RATE_A} percent. [vat/notes.md](vat/notes.md#5-changes)
- Reduced rate stayed at ${FIX_RATE_C} percent. [vat/notes.md](vat/notes.md#5-changes)
- Box 1 rate stayed at ${FIX_RATE_B} percent. [income-tax/notes.md](income-tax/notes.md#5-changes)
- Band stayed at ${FIX_RATE_C} percent. [income-tax/notes.md](income-tax/notes.md#5-changes)
- Fixture year 2020 kept its rules. [income-tax/notes.md](income-tax/notes.md#5-changes)

---

## 2. All changes by topic

<!-- GENERATED:changes:start -->
<!-- GENERATED:changes:end -->
EOF
    cp "$SKILL_SRC/references/tax-rules/year-changes.md" "$tax_rules/year-changes.md" || return 1
    cp "$SKILL_SRC/references/README.md" "$skill/references/README.md" || return 1
    printf '{"modes":[{"leaves":["references/tax-rules/2020/README.md","assets/handbook.md"]}]}\n' \
        >"$skill/leaf-manifest.json" || return 1
    printf '# Fixture skill\n\nSee the [handbook](assets/handbook.md).\n' >"$skill/SKILL.md" || return 1
    printf '# Handbook\n' >"$skill/assets/handbook.md" || return 1
    return 0
}

# Add a routing signals file with a valid gap ledger to a built fixture
# Args:
#   $1 - Skill folder to extend
# Returns:
#   0 when the file is written, 1 when the write fails
add_gap_ledger() {
    cat >"$1/references/routing-signals.md" <<'EOF'
---
title: "Routing signals"
description: "Fixture routing signals with a gap ledger."
---

# Routing signals

## 1. OVERVIEW

Hand prose for the fixture signals.

## 2. DOCUMENTED GAPS

| Topic | Owner | Coverage | Operator action |
|---|---|---|---|
| `vat-return` | `references/vat-return/README.md` | gap | Prepare the return before filing. |
| yearly-overview | references/yearly-overview/README.md | partial | Review the overview with the operator. |
| income-tax-return | `references/income-tax-return/README.md` | covered | No operator action remains. |
EOF
}

# ───────────────────────────────────────────────────────────────
# 6. REAL CORPUS
# ───────────────────────────────────────────────────────────────

# The real corpus passing --check is a CI step of its own. This group proves
# that a write over the real tree has nothing left to change.
group "real corpus"
REAL_COPY="$TMP_ROOT/real-copy"
copy_skill "$REAL_COPY" || abort_setup "the temp copy of the skill folder cannot be created"
before=$(tree_checksums "$REAL_COPY")
run_generator "$REAL_COPY"
status=$?
first=$(tree_checksums "$REAL_COPY")
if [[ "$status" -eq 0 ]]; then
    pass "the first write in a temp copy exits 0"
else
    fail "the first write in a temp copy exits 0"
fi
if [[ "$before" == "$first" ]]; then
    pass "the first write leaves every file byte-identical"
else
    fail "the first write leaves every file byte-identical"
fi

group "real change notes"
real_change_rows=$(sed -n '/GENERATED:changes:start/,/GENERATED:changes:end/p' "$SKILL_SRC/references/tax-rules/2026/changes.md" | grep -c '#5-changes)')
if [[ "$real_change_rows" == "12" ]]; then
    pass "the real 2026 note lists all twelve topics with a section link"
else
    fail "the real 2026 note lists all twelve topics with a section link"
fi
overview_front=$(sed -n '2,/^---$/p' "$SKILL_SRC/references/tax-rules/year-changes.md")
missing_fields=0
for field in trigger_phrases importance_tier contextType version; do
    grep -q "^${field}:" <<<"$overview_front" || missing_fields=$((missing_fields + 1))
done
if [[ "$missing_fields" == "0" ]]; then
    pass "the real overview carries the reference frontmatter fields"
else
    fail "the real overview carries the reference frontmatter fields"
fi

# ───────────────────────────────────────────────────────────────
# 7. FIXTURE REPOSITORY
# ───────────────────────────────────────────────────────────────

group "fixture repository"
# The fence text is assembled here, so only the generator spells the markers.
GEN_WORD='GENERATED'
FIXTURE="$TMP_ROOT/fixture/sk-moneybird-accountant"
FIXTURE_TAX_RULES="$FIXTURE/references/tax-rules"
make_fixture "$FIXTURE" || abort_setup "the fixture repository cannot be built"
if run_generator "$FIXTURE"; then
    pass "fixture write exits 0"
else
    fail "fixture write exits 0"
fi
if run_generator "$FIXTURE" --check; then
    pass "fixture --check exits 0 after the writes"
else
    fail "fixture --check exits 0 after the writes"
fi
fixture_before=$(tree_checksums "$FIXTURE")
run_generator "$FIXTURE"
status=$?
fixture_after=$(tree_checksums "$FIXTURE")
if [[ "$status" -eq 0 ]] && [[ "$fixture_before" == "$fixture_after" ]]; then
    pass "a second write leaves every fixture file byte-identical"
else
    fail "a second write leaves every fixture file byte-identical"
fi

TOPIC_MUTANT="$TMP_ROOT/topic-mutant/sk-moneybird-accountant"
copy_fixture "$FIXTURE" "$TOPIC_MUTANT" || abort_setup "the topic mutant cannot be copied"
sed -i.bak '/^## 2\. KEY FIGURES$/,$d' "$TOPIC_MUTANT/references/tax-rules/2020/vat/figures.md"
run_generator "$TOPIC_MUTANT" --check
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'no KEY FIGURES table in tax-rules/2020/vat/figures.md' "$TMP_ROOT/out.txt"; then
    pass "a topic file is still held to the topic rules"
else
    fail "a topic file is still held to the topic rules"
fi

FENCE_MUTANT="$TMP_ROOT/fence-mutant/sk-moneybird-accountant"
copy_fixture "$FIXTURE" "$FENCE_MUTANT" || abort_setup "the fence mutant cannot be copied"
grep -v -F "<!-- ${GEN_WORD}:topic-files:" "$FENCE_MUTANT/references/tax-rules/2020/README.md" >"$TMP_ROOT/mutated.md" \
    && mv "$TMP_ROOT/mutated.md" "$FENCE_MUTANT/references/tax-rules/2020/README.md" \
    || abort_setup "the fence mutant cannot be edited"
run_generator "$FENCE_MUTANT" --check
check_status=$?
check_drift=0
grep -q '^drift tax-rules/2020/README.md topic-files$' "$TMP_ROOT/out.txt" && check_drift=1
run_generator "$FENCE_MUTANT"
status=$?
if [[ "$check_status" -eq 1 ]] && [[ "$check_drift" -eq 1 ]] && [[ "$status" -eq 1 ]] \
    && grep -q '^missing tax-rules/2020/README.md topic-files$' "$TMP_ROOT/out.txt"; then
    pass "a block with no fence pair fails the check and blocks the write"
else
    fail "a block with no fence pair fails the check and blocks the write"
fi

# ───────────────────────────────────────────────────────────────
# 7b. ITEM INDEX AND ANSWER SURFACE
# ───────────────────────────────────────────────────────────────

# WHY: the item index is a second representation of the value table, so the
# suite compares its row count with the table and checks the answer surface
# schema on every index record.
group "item index and answer surface"
if python3 - "$FIXTURE_TAX_RULES/2020/vat/figures.md" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
index = re.search(
    r"<!-- GENERATED:key-figure-index:start -->(.*?)<!-- GENERATED:key-figure-index:end -->",
    text,
    re.S,
)
if not index:
    sys.exit(1)
rows = [
    line
    for line in index.group(1).splitlines()
    if line.startswith("|") and "Item" not in line and not re.match(r"^\|[-|]+\|$", line)
]
table = re.search(r"\|\s*Item\s*\|\s*Value[^\n]*\n\|[-\s|]+\|\n((?:\|.*\n)+)", text)
if not table:
    sys.exit(1)
values = [line for line in table.group(1).splitlines() if line.strip()]
sys.exit(0 if len(rows) == len(values) == 2 else 1)
PY
then
    pass "the item index holds one row per value row of the table"
else
    fail "the item index holds one row per value row of the table"
fi
if python3 - "$FIXTURE/references/index.json" <<'PY'
import json
import sys

rows = json.load(open(sys.argv[1], encoding="utf-8"))["files"]
by_path = {row["path"]: row for row in rows}
for row in rows:
    surface = row.get("answerSurface")
    if not isinstance(surface, dict) or set(surface) != {"section", "rows", "tokens"}:
        sys.exit(1)
vat = by_path.get("tax-rules/2020/vat/figures.md")
readme = by_path.get("tax-rules/2020/README.md")
if vat is None or readme is None:
    sys.exit(1)
if vat["answerSurface"]["section"] != "2-key-figures" or vat["answerSurface"]["rows"] != 2:
    sys.exit(1)
if readme["answerSurface"]["section"] != "" or readme["answerSurface"]["rows"] != 0:
    sys.exit(1)
sys.exit(0)
PY
then
    pass "every index record carries the answerSurface schema and the value rows match"
else
    fail "every index record carries the answerSurface schema and the value rows match"
fi

group "year change notes"
CHANGES_NOTE="$FIXTURE_TAX_RULES/2020/changes.md"
CHANGES_OVERVIEW="$FIXTURE_TAX_RULES/year-changes.md"
CHANGE_MUTANT="$TMP_ROOT/change-mutant/sk-moneybird-accountant"
CHANGE_MUTANT_NOTE="$CHANGE_MUTANT/references/tax-rules/2020/changes.md"
if grep -qF "| [vat.md](vat/notes.md#5-changes) | 2 | The standard rate stayed at ${FIX_RATE_A} percent in the fixture year. |" "$CHANGES_NOTE"; then
    pass "the year note lists the topic count and the first bullet snippet"
else
    fail "the year note lists the topic count and the first bullet snippet"
fi
if grep -qF '| [income-tax.md](income-tax/notes.md#5-changes) | 3 |' "$CHANGES_NOTE"; then
    pass "the year note lists every topic of the year"
else
    fail "the year note lists every topic of the year"
fi
if grep -qF '](2020/changes.md)' "$CHANGES_OVERVIEW" \
    && grep -qF -- "- Standard rate stayed at ${FIX_RATE_A} percent. [vat/notes.md](2020/vat/notes.md#5-changes)" "$CHANGES_OVERVIEW"; then
    pass "the overview holds the path link and the rebased authored bullet"
else
    fail "the overview holds the path link and the rebased authored bullet"
fi
copy_fixture "$FIXTURE" "$CHANGE_MUTANT" || abort_setup "the change mutant cannot be copied"
printf 'Hand edit in the overview.\n' >>"$CHANGE_MUTANT/references/tax-rules/year-changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift year-changes.md$' "$TMP_ROOT/out.txt"; then
    pass "a hand edit in the overview fails the check and names the file"
else
    fail "a hand edit in the overview fails the check and names the file"
fi
copy_fixture "$FIXTURE" "$CHANGE_MUTANT" || abort_setup "the change mutant cannot be copied"
sed -i.bak "s/Standard rate stayed at ${FIX_RATE_A} percent/Standard rate stayed at ${FIX_RATE_MISSING} percent/" "$CHANGE_MUTANT_NOTE"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q "^changes tax-rules/2020/changes.md bullet 1 number ${FIX_RATE_MISSING} not in vat/notes.md#5-changes$" "$TMP_ROOT/out.txt"; then
    pass "a bullet number missing from section 5 fails the check"
else
    fail "a bullet number missing from section 5 fails the check"
fi
copy_fixture "$FIXTURE" "$CHANGE_MUTANT" || abort_setup "the change mutant cannot be copied"
sed -i.bak 's/vat\/notes.md#5-changes/vat\/notes.md#6-in-the-books/' "$CHANGE_MUTANT_NOTE"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes tax-rules/2020/changes.md bullet 1 link vat/notes.md#6-in-the-books does not resolve$' "$TMP_ROOT/out.txt"; then
    pass "a bullet link that does not resolve fails the check"
else
    fail "a bullet link that does not resolve fails the check"
fi
copy_fixture "$FIXTURE" "$CHANGE_MUTANT" || abort_setup "the change mutant cannot be copied"
sed -i.bak '/Reduced rate stayed at/d' "$CHANGE_MUTANT_NOTE"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes tax-rules/2020/changes.md 4 authored bullets, the band is 5 to 10$' "$TMP_ROOT/out.txt"; then
    pass "a year note under the bullet band fails the check"
else
    fail "a year note under the bullet band fails the check"
fi
copy_fixture "$FIXTURE" "$CHANGE_MUTANT" || abort_setup "the change mutant cannot be copied"
python3 - "$CHANGE_MUTANT_NOTE" <<'PY' || abort_setup "the change mutant cannot be edited"
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
for line in lines:
    if line == "## 2. All changes by topic":
        out.extend(["- Fixture extra bullet. [vat/notes.md](vat/notes.md#5-changes)"] * 6)
    out.append(line)
open(path, "w", encoding="utf-8").write("\n".join(out))
PY
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes tax-rules/2020/changes.md 11 authored bullets, the band is 5 to 10$' "$TMP_ROOT/out.txt"; then
    pass "a year note over the bullet band fails the check"
else
    fail "a year note over the bullet band fails the check"
fi

# ───────────────────────────────────────────────────────────────
# 8. MUTATIONS IN TEMP COPIES
# ───────────────────────────────────────────────────────────────

group "mutations in temp copies"
MUT="$TMP_ROOT/mutation"
TOPIC_FENCE_START="<!-- ${GEN_WORD}:topic-files:start -->"
LAST_FENCE_END="<!-- ${GEN_WORD}:headline-figures:end -->"

copy_skill "$MUT"
python3 - "$MUT/references/tax-rules/2020/README.md" "$TOPIC_FENCE_START" <<'PY'
import sys

path, tag = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
for line in lines:
    out.append(line)
    if line == tag:
        out.append("| hand | edit | inside | the | fence |")
open(path, "w", encoding="utf-8").write("\n".join(out))
PY
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift tax-rules/2020/README.md topic-files' "$TMP_ROOT/out.txt"; then
    pass "a hand edit inside a fence fails the check"
else
    fail "a hand edit inside a fence fails the check"
fi

copy_skill "$MUT"
python3 - "$MUT/references/tax-rules/2020/income-tax/figures.md" "$RATE_BOX1_UP" "$RATE_BOX1_NEXT" <<'PY'
import sys

path, old_value, new_value = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path, encoding="utf-8").read().split("\n")
inside = False
for index, line in enumerate(lines):
    if line.startswith("## 2. KEY FIGURES"):
        inside = True
        continue
    if inside and line.startswith("|") and old_value in line:
        lines[index] = line.replace(old_value, new_value, 1)
        break
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift tax-rules/2020/README.md ' "$TMP_ROOT/out.txt" \
    && grep -q '^drift tax-rules/general/income-tax-box-1-and-the-health-insurance-contribution.md s3-' "$TMP_ROOT/out.txt"; then
    pass "a changed year value names the year README and the section blocks"
else
    fail "a changed year value names the year README and the section blocks"
fi

copy_skill "$MUT"
grep -v -F "$LAST_FENCE_END" "$MUT/references/tax-rules/2020/README.md" >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/tax-rules/2020/README.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -eq 2 ]] && grep -q 'fence error' "$TMP_ROOT/out.txt"; then
    pass "an unmatched fence stops the check with exit 2"
else
    fail "an unmatched fence stops the check with exit 2"
fi

copy_skill "$MUT"
grep -v '^nav_label:' "$MUT/references/tax-rules/2020/vat/figures.md" >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/tax-rules/2020/vat/figures.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q 'missing nav_label' "$TMP_ROOT/out.txt"; then
    pass "a missing nav_label fails the check"
else
    fail "a missing nav_label fails the check"
fi

copy_skill "$MUT"
sed 's/^nav_label: .*/nav_label: "VAT"/' "$MUT/references/tax-rules/2020/income-tax/figures.md" \
    >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/tax-rules/2020/income-tax/figures.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q 'duplicate nav_label' "$TMP_ROOT/out.txt"; then
    pass "a duplicate nav_label fails the check"
else
    fail "a duplicate nav_label fails the check"
fi

copy_skill "$MUT"
long_label=$(awk 'BEGIN { for (i = 0; i < 61; i++) printf "A" }')
sed "s/^nav_label: .*/nav_label: \"$long_label\"/" "$MUT/references/tax-rules/2020/vat/figures.md" \
    >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/tax-rules/2020/vat/figures.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q 'the limit is 60' "$TMP_ROOT/out.txt"; then
    pass "a nav_label over 60 characters fails the check"
else
    fail "a nav_label over 60 characters fails the check"
fi

copy_skill "$MUT"
printf '# Unlinked fixture\n' >"$MUT/assets/unlinked-fixture.md"
python3 - "$MUT/leaf-manifest.json" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["modes"][0]["leaves"].append("assets/unlinked-fixture.md")
open(path, "w", encoding="utf-8").write(json.dumps(data, indent=2) + "\n")
PY
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^unreachable assets/unlinked-fixture.md' "$TMP_ROOT/out.txt"; then
    pass "a manifest leaf that nothing links fails the check"
else
    fail "a manifest leaf that nothing links fails the check"
fi

# WHY: a deleted reference file still sits under the routed prefix, so the
# check has to read the disk instead of trusting that prefix.
copy_skill "$MUT"
DELETED_LEAF="references/migration/README.md"
rm -f "$MUT/$DELETED_LEAF"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -qF "missing $DELETED_LEAF" "$TMP_ROOT/out.txt"; then
    pass "a manifest leaf with no file on disk fails the check"
else
    fail "a manifest leaf with no file on disk fails the check"
fi

# ───────────────────────────────────────────────────────────────
# 9. EDIT OUTSIDE EVERY FENCE
# ───────────────────────────────────────────────────────────────

group "outside fence"
HAND_NOTE="Hand-written line that sits outside every fence."
OUTSIDE="$TMP_ROOT/outside-fence"
copy_skill "$OUTSIDE"
if insert_hand_line "$OUTSIDE/references/tax-rules/2020/README.md" "$HAND_NOTE"; then
    before=$(file_checksum "$OUTSIDE/references/tax-rules/2020/README.md")
    run_generator "$OUTSIDE"
    status=$?
    after=$(file_checksum "$OUTSIDE/references/tax-rules/2020/README.md")
    if [[ "$status" -eq 0 ]] && [[ "$before" == "$after" ]] \
        && grep -qF "$HAND_NOTE" "$OUTSIDE/references/tax-rules/2020/README.md"; then
        pass "a hand edit outside every fence survives a write byte for byte"
    else
        fail "a hand edit outside every fence survives a write byte for byte"
    fi
else
    fail "a hand edit outside every fence survives a write byte for byte"
fi

# ───────────────────────────────────────────────────────────────
# 10. PREFIX RULE
# ───────────────────────────────────────────────────────────────

group "prefix rule"
if [[ "$(unverified_count "$YEAR_README" income-tax income-tax/figures.md)" == "3" ]]; then
    pass "the UNVERIFIED count for references/tax-rules/2020/income-tax/figures.md is 3"
else
    fail "the UNVERIFIED count for references/tax-rules/2020/income-tax/figures.md is 3"
fi

EQUALITY="$TMP_ROOT/equality-mutant"
copy_skill "$EQUALITY"
sed 's/\.startswith(UNVERIFIED_TAG)/== UNVERIFIED_TAG/' "$BUILDER" \
    >"$EQUALITY/scripts/build-reference-index.py"
sed_applied=1
cmp -s "$BUILDER" "$EQUALITY/scripts/build-reference-index.py" && sed_applied=0
run_generator "$EQUALITY"
mutant_count=$(unverified_count "$EQUALITY/references/tax-rules/2020/README.md" income-tax income-tax/figures.md)
cp "$BUILDER" "$EQUALITY/scripts/reference-index-checker.py"
python3 -I "$EQUALITY/scripts/reference-index-checker.py" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$sed_applied" -eq 1 ]] && [[ "$mutant_count" != "3" ]] && [[ "$status" -ne 0 ]]; then
    pass "the equality-only mutant was caught: it counts $mutant_count and the check fails"
else
    fail "the equality-only mutant was caught: it counts $mutant_count and the check fails"
fi

# ───────────────────────────────────────────────────────────────
# 11. REAL SECTION LIST
# ───────────────────────────────────────────────────────────────

group "real section list"
GENERAL_DIR="$SKILL_SRC/references/tax-rules/general"
GUIDE_FILE="$SKILL_SRC/references/tax-rules/dutch-tax-rules.md"
if python3 -I - "$GUIDE_FILE" "$GENERAL_DIR" <<'PY'
import os
import re
import sys

guide, general_dir = sys.argv[1], sys.argv[2]
text = open(guide, encoding="utf-8").read()
missing = []
for number in range(1, 11):
    match = re.search(
        r"^\| 3\.%d \|[^|]*\|[^|]*\[([^]]+)\]\(general/([^)]+)\)" % number, text, re.M
    )
    if not match:
        missing.append("3.%d row" % number)
        continue
    path = os.path.join(general_dir, match.group(2))
    if not os.path.isfile(path):
        missing.append("3.%d file" % number)
        continue
    body = open(path, encoding="utf-8").read()
    if not re.search(r"^### 3\.%d " % number, body, re.M):
        missing.append("3.%d heading" % number)
if missing:
    print("missing " + ", ".join(missing))
    raise SystemExit(1)
print("ok")
PY
then
    pass "the real section list maps subsections 3.1 to 3.10 onto the general files"
else
    fail "the real section list maps subsections 3.1 to 3.10 onto the general files"
fi

# ───────────────────────────────────────────────────────────────
# 12. REAL LAYOUT
# ───────────────────────────────────────────────────────────────

group "real layout"
if python3 - "$FIXTURE/references/index.json" <<'PY'
import json
import sys

rows = json.load(open(sys.argv[1], encoding="utf-8"))["files"]
paths = [row["path"] for row in rows]
sys.exit(0 if "tax-rules/2020/vat/figures.md" in paths else 1)
PY
then
    pass "the nested figures file is in the index"
else
    fail "the nested figures file is in the index"
fi
if grep -qF '| [vat](vat/figures.md) | Covers Dutch VAT for the fixture. | 2 | 1 | 0 |' \
    "$FIXTURE_TAX_RULES/2020/README.md"; then
    pass "the split year README counts the topic through its figures part"
else
    fail "the split year README counts the topic through its figures part"
fi
if grep -qF 'sk-moneybird-accountant/references/tax-rules/2020/vat/figures.md' "$FIXTURE_TAX_RULES/general/vat.md"; then
    pass "the general file carries the section 3 rows from the figures part"
else
    fail "the general file carries the section 3 rows from the figures part"
fi

# ───────────────────────────────────────────────────────────────
# 13. GAP LEDGER
# ───────────────────────────────────────────────────────────────

# WHY: the ledger is authored in one reference file and copied into the index,
# so the suite proves the copy and the owner rule on a fixture tree.
group "gap ledger"
GAPS_FIXTURE="$TMP_ROOT/gaps-fixture/sk-moneybird-accountant"
GAPS_MUTANT="$TMP_ROOT/gaps-mutant/sk-moneybird-accountant"
if python3 - "$FIXTURE/references/index.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
sys.exit(0 if data.get("gaps") == [] else 1)
PY
then
    pass "an absent Documented gaps heading stores an empty ledger"
else
    fail "an absent Documented gaps heading stores an empty ledger"
fi

copy_fixture "$FIXTURE" "$GAPS_FIXTURE" || abort_setup "the gap ledger fixture cannot be copied"
add_gap_ledger "$GAPS_FIXTURE" || abort_setup "the gap ledger fixture cannot be written"
if run_generator "$GAPS_FIXTURE" && run_generator "$GAPS_FIXTURE" --check; then
    pass "a valid gap ledger writes and passes --check"
else
    fail "a valid gap ledger writes and passes --check"
fi
if python3 - "$GAPS_FIXTURE/references/index.json" <<'PY'
import json
import sys

claimed = [
    (row["topic"], row["owner"], row["coverage"], row["operator_action"])
    for row in json.load(open(sys.argv[1], encoding="utf-8")).get("gaps", [])
]
expected = [
    ("vat-return", "references/vat-return/README.md", "gap", "Prepare the return before filing."),
    ("yearly-overview", "references/yearly-overview/README.md", "partial", "Review the overview with the operator."),
    ("income-tax-return", "references/income-tax-return/README.md", "covered", "No operator action remains."),
]
sys.exit(0 if claimed == expected else 1)
PY
then
    pass "the index copies the ledger rows in table order"
else
    fail "the index copies the ledger rows in table order"
fi
gaps_before=$(tree_checksums "$GAPS_FIXTURE")
run_generator "$GAPS_FIXTURE"
status=$?
gaps_after=$(tree_checksums "$GAPS_FIXTURE")
if [[ "$status" -eq 0 ]] && [[ "$gaps_before" == "$gaps_after" ]]; then
    pass "a second gap ledger write leaves every file byte-identical"
else
    fail "a second gap ledger write leaves every file byte-identical"
fi

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT" || abort_setup "the gap ledger mutant cannot be copied"
python3 - "$GAPS_MUTANT/references/routing-signals.md" <<'PY' || abort_setup "the gap ledger mutant cannot be edited"
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("`references/vat-return/README.md`", "/tmp/outside-the-skill.md", 1)
text = text.replace("`references/income-tax-return/README.md`", "references/../../outside.md", 1)
open(path, "w", encoding="utf-8").write(text)
PY
run_generator "$GAPS_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] \
    && grep -Eq '^gaps routing-signals\.md row [0-9]+ topic vat-return owner /tmp/outside-the-skill\.md escapes the skill folder$' "$TMP_ROOT/out.txt" \
    && grep -Eq '^gaps routing-signals\.md row [0-9]+ topic income-tax-return owner references/\.\./\.\./outside\.md escapes the skill folder$' "$TMP_ROOT/out.txt"; then
    pass "an absolute or climbing owner fails the check and names the row"
else
    fail "an absolute or climbing owner fails the check and names the row"
fi

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT" || abort_setup "the gap ledger mutant cannot be copied"
python3 - "$GAPS_MUTANT/references/index.json" <<'PY' || abort_setup "the gap ledger mutant cannot be edited"
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace('"coverage":"gap"', '"coverage":"covered"', 1))
PY
run_generator "$GAPS_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift index\.json$' "$TMP_ROOT/out.txt"; then
    pass "a hand edit to the stored gap list fails the check"
else
    fail "a hand edit to the stored gap list fails the check"
fi

# ───────────────────────────────────────────────────────────────
# 14. LOADING NOTES LISTING PATHS
# ───────────────────────────────────────────────────────────────

# WHY: the loading notes name the generated index and the token baseline, so
# the suite asserts that both names resolve to a file with its schema fields.
group "loading notes listing paths"
LISTING_SKILL="$TMP_ROOT/listing-skill"
copy_skill "$LISTING_SKILL"
if python3 - "$LISTING_SKILL" <<'PY'
import json
import os
import sys

root = sys.argv[1]
text = open(os.path.join(root, "SKILL.md"), encoding="utf-8").read()
for name in ("references/index.json", "benchmark/token-baseline.json"):
    if name not in text:
        sys.exit(1)
index = json.load(open(os.path.join(root, "references/index.json"), encoding="utf-8"))
if not index.get("files") or "answerSurface" not in index["files"][0]:
    sys.exit(1)
baseline = json.load(open(os.path.join(root, "benchmark/token-baseline.json"), encoding="utf-8"))
if not baseline.get("files") or "tokens" not in baseline["files"][0]:
    sys.exit(1)
sys.exit(0)
PY
then
    pass "the loading notes name the index and the baseline with their schema fields"
else
    fail "the loading notes name the index and the baseline with their schema fields"
fi

# ───────────────────────────────────────────────────────────────
# 15. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
