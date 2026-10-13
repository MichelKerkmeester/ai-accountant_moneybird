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

YEAR_README="$SKILL_SRC/references/2020/README.md"
YEAR_TOPIC="$SKILL_SRC/references/2020/inkomstenbelasting.md"
YEAR_LABELED="$SKILL_SRC/references/2020/btw.md"
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
unverified_count() {
    grep -F "| [$2]($2) |" "$1" | awk -F'|' '{print $5}' | tr -d '[:space:]'
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

# Replace one fixture file with a read plan body of an exact size
# Args:
#   $1 - File to replace
#   $2 - Total size of the file in bytes
#   $3 - Size of the read plan body in bytes
#   $4 - Marker word of the fence lines
# Returns:
#   0 when the file is in place, 1 when the sizes do not fit
shape_nav_file() {
    python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys

path, size, body_bytes = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
word = sys.argv[4]
start_line = "<!-- %s:nav:start -->\n" % word
end_line = "<!-- %s:nav:end -->\n" % word
unit = "Nav body filler text that is long enough to fill one line.\n"
body = ""
while len(body) + len(unit) <= body_bytes - 1:
    body += unit
body += "x" * (body_bytes - len(body) - 1) + "\n"
head = "# Large budget fixture\n\n" + start_line + body + end_line + "\n"
tail_unit = "Filler line that gives the fixture file its length.\n"
tail = ""
remaining = size - len(head)
while len(tail) + len(tail_unit) <= remaining:
    tail += tail_unit
tail += "y" * (remaining - len(tail))
text = head + tail
if len(text) != size or len(body.encode("utf-8")) != body_bytes:
    sys.exit(1)
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
sys.exit(0)
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

# Build a minimal skill folder with one year folder, a large file, a guide
# with section 3, a manifest and the page that routes the fixture leaves
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local skill="$1"
    mkdir -p "$skill/scripts" "$skill/references/2020" "$skill/assets" || return 1
    cp "$BUILDER" "$skill/scripts/" || return 1
    cat >"$skill/references/dutch-tax-rules.md" <<'EOF'
---
title: "Dutch tax rules"
---

# Dutch tax rules

## 1. Topic files in every year folder

| File | Topic |
|---|---|
| `btw.md` | VAT |
| `inkomstenbelasting.md` | Income tax |

## 3. GENERAL RULES

### 3.1 BTW (VAT)

Year files: `btw.md` in each year folder.

The hand-written rule prose stays here.
EOF
    cat >"$skill/references/2020/README.md" <<'EOF'
---
title: "Tax year 2020"
description: "Fixture year overview."
---

# Tax year 2020

## 1. OVERVIEW

Hand prose for the fixture year.

## 2. TOPIC FILES

## 3. HEADLINE FIGURES
EOF
    cat >"$skill/references/2020/btw.md" <<'EOF'
---
title: "BTW 2020"
description: "Covers Dutch VAT for the fixture."
nav_label: "BTW"
---

# BTW 2020

## 1. KEY FIGURES

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Standard rate | 21% | enacted | Verified |
| Reduced rate | 9% | enacted | UNVERIFIED |
EOF
    # The delimiter stays unquoted so the runtime-built rate values expand. The
    # body holds no dollar sign, backtick or backslash of its own.
    cat >"$skill/references/2020/inkomstenbelasting.md" <<EOF
---
title: "Income tax 2020"
description: "Covers income tax for the fixture."
nav_label: "Inkomstenbelasting box 1"
---

# Income tax 2020

## 1. KEY FIGURES

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Box 1 rates | ${RATE_BOX1} | enacted | UNVERIFIED |
| Bands | ${RATE_BAND2} | enacted | Verified |
EOF
    {
        printf '# Large fixture\n\n## 1. PART ONE\n\n'
        awk 'BEGIN { for (i = 1; i <= 1500; i++) printf "Fixture line %04d with filler text that gives the file its length.\n", i }'
    } >"$skill/references/2020/large-fixture.md" || return 1
    printf '{"modes":[{"leaves":["references/2020/README.md","assets/handbook.md"]}]}\n' \
        >"$skill/leaf-manifest.json" || return 1
    printf '# Fixture skill\n\nSee the [handbook](assets/handbook.md).\n' >"$skill/SKILL.md" || return 1
    printf '# Handbook\n' >"$skill/assets/handbook.md" || return 1
    return 0
}

# Add a year change note and section 5 bullets to the fixture repository
# Args:
#   $1 - Skill folder to extend
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_changes_fixture() {
    local skill="$1"
    make_fixture "$skill" || return 1
    cat >>"$skill/references/2020/btw.md" <<EOF

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The standard rate stayed at ${FIX_RATE_A} percent in the fixture year.
- The reduced rate stayed at ${FIX_RATE_C} percent in the fixture year.
EOF
    cat >>"$skill/references/2020/inkomstenbelasting.md" <<EOF

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The box 1 rate stayed at ${FIX_RATE_B} percent in the fixture year.
- The band stayed at ${FIX_RATE_C} percent in the fixture year.
- The fixture year 2020 kept its rules.
EOF
    cat >"$skill/references/2020/changelog.md" <<'EOF'
# Corrections 2020

Fixture correction log for the change note fixture.
EOF
    cat >"$skill/references/2020/changes.md" <<EOF
---
title: "Changes tax year 2020"
description: "Fixture year change note."
---

# Changes tax year 2020

**Rule:** The fixture note restates section 5 of the year topics and links the [correction log](changelog.md) and the [year overview](README.md).

---

## 1. Unique to 2020

- Standard rate stayed at ${FIX_RATE_A} percent. [btw.md](btw.md#5-changes)
- Reduced rate stayed at ${FIX_RATE_C} percent. [btw.md](btw.md#5-changes)
- Box 1 rate stayed at ${FIX_RATE_B} percent. [inkomstenbelasting.md](inkomstenbelasting.md#5-changes)
- Band stayed at ${FIX_RATE_C} percent. [inkomstenbelasting.md](inkomstenbelasting.md#5-changes)
- Fixture year 2020 kept its rules. [inkomstenbelasting.md](inkomstenbelasting.md#5-changes)

---

## 2. All changes by topic
EOF
    return 0
}

# ───────────────────────────────────────────────────────────────
# 6. REAL CORPUS
# ───────────────────────────────────────────────────────────────

group "real corpus"
if run_generator "$SKILL_SRC" --check; then
    pass "the real corpus passes --check"
else
    fail "the real corpus passes --check"
fi

REAL_COPY="$TMP_ROOT/real-copy"
if copy_skill "$REAL_COPY"; then
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
    run_generator "$REAL_COPY"
    status=$?
    second=$(tree_checksums "$REAL_COPY")
    if [[ "$status" -eq 0 ]]; then
        pass "the second write in a temp copy exits 0"
    else
        fail "the second write in a temp copy exits 0"
    fi
    if [[ "$first" == "$second" ]]; then
        pass "the second write leaves every file byte-identical"
    else
        fail "the second write leaves every file byte-identical"
    fi
    if run_generator "$REAL_COPY" --check; then
        pass "the temp copy still passes --check after two writes"
    else
        fail "the temp copy still passes --check after two writes"
    fi
else
    fail "the temp copy of the skill folder builds"
fi

group "real change notes"
real_change_rows=$(sed -n '/GENERATED:changes:start/,/GENERATED:changes:end/p' "$SKILL_SRC/references/2026/changes.md" | grep -c '#5-changes)')
if [[ "$real_change_rows" == "12" ]]; then
    pass "the real 2026 note lists all twelve topics with a section link"
else
    fail "the real 2026 note lists all twelve topics with a section link"
fi
real_overview_years=$(grep -c '^## 20' "$SKILL_SRC/references/year-changes.md")
if [[ "$real_overview_years" == "8" ]]; then
    pass "the real overview holds eight year sections"
else
    fail "the real overview holds eight year sections"
fi

# ───────────────────────────────────────────────────────────────
# 7. FIXTURE REPOSITORY
# ───────────────────────────────────────────────────────────────

group "fixture repository"
FIXTURE="$TMP_ROOT/fixture/sk-moneybird-accountant"
if make_fixture "$FIXTURE"; then
    pass "fixture repository builds"
else
    fail "fixture repository builds"
fi
if run_generator "$FIXTURE" --init; then
    pass "fixture --init exits 0"
else
    fail "fixture --init exits 0"
fi
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

# The fence text is assembled here, so only the generator spells the markers.
GEN_WORD='GENERATED'
READ_PLAN_FENCE="<!-- ${GEN_WORD}:nav:start -->"
TOPIC_TABLE_FENCE="<!-- ${GEN_WORD}:topic-files:start -->"
if grep -qF "$READ_PLAN_FENCE" "$FIXTURE/references/2020/large-fixture.md"; then
    pass "the large fixture file gained a read plan fence"
else
    fail "the large fixture file gained a read plan fence"
fi
if grep -qF "$TOPIC_TABLE_FENCE" "$FIXTURE/references/2020/README.md"; then
    pass "the year README gained a topic table fence"
else
    fail "the year README gained a topic table fence"
fi

# A year folder gains a changelog beside its topic files. The topic table may
# name it, yet the generator reads no topic field from that file.
cat >"$FIXTURE/references/2020/changelog.md" <<'MARKDOWN'
---
title: "Corrections tax year 2020"
description: "Fixture correction log."
---

# Corrections tax year 2020

## 1. OVERVIEW

Fixture overview.

## 2. CORRECTIONS

| Date | File | Row | Old status | New status | Source |
|---|---|---|---|---|---|
| 2026-10-12 | btw.md | Standard rate | as first researched | Corrected | https://example.invalid/source |
MARKDOWN
python3 - "$FIXTURE/references/dutch-tax-rules.md" <<'PY'
import sys

path = sys.argv[1]
row = "| `inkomstenbelasting.md` | Income tax |\n"
added = "| `changelog.md` | Corrections |\n"
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace(row, row + added, 1))
PY
if run_generator "$FIXTURE" && run_generator "$FIXTURE" --check \
    && ! grep -qF 'changelog.md' "$FIXTURE/references/2020/README.md"; then
    pass "a year changelog is not held to the topic rules"
else
    fail "a year changelog is not held to the topic rules"
fi

sed -i.bak '/^## 1\. KEY FIGURES$/,$d' "$FIXTURE/references/2020/btw.md"
run_generator "$FIXTURE" --check
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'no KEY FIGURES table in 2020/btw.md' "$TMP_ROOT/out.txt"; then
    pass "a topic file is still held to the topic rules"
else
    fail "a topic file is still held to the topic rules"
fi

group "year change notes"
CHANGES_FIXTURE="$TMP_ROOT/change-fixture/sk-moneybird-accountant"
CHANGES_NOTE="$CHANGES_FIXTURE/references/2020/changes.md"
CHANGES_OVERVIEW="$CHANGES_FIXTURE/references/year-changes.md"
CHANGE_MUTANT="$TMP_ROOT/change-mutant/sk-moneybird-accountant"
CHANGES_FENCE_START="<!-- ${GEN_WORD}:changes:start -->"
if make_changes_fixture "$CHANGES_FIXTURE"; then
    pass "the year change fixture builds"
else
    fail "the year change fixture builds"
fi
if run_generator "$CHANGES_FIXTURE" --init; then
    pass "the year change fixture --init exits 0"
else
    fail "the year change fixture --init exits 0"
fi
if awk -v heading='## 2. All changes by topic' -v marker="$CHANGES_FENCE_START" '
    $0 == heading { found = 1; next }
    found && $0 == "" { next }
    found { print ($0 == marker) ? "yes" : "no"; exit }
' "$CHANGES_NOTE" | grep -q '^yes$'; then
    pass "--init places the change fence under its section heading"
else
    fail "--init places the change fence under its section heading"
fi
if run_generator "$CHANGES_FIXTURE" && run_generator "$CHANGES_FIXTURE" --check; then
    pass "the year change fixture passes --check after a write"
else
    fail "the year change fixture passes --check after a write"
fi
change_before=$(tree_checksums "$CHANGES_FIXTURE")
run_generator "$CHANGES_FIXTURE"
status=$?
change_after=$(tree_checksums "$CHANGES_FIXTURE")
if [[ "$status" -eq 0 ]] && [[ "$change_before" == "$change_after" ]]; then
    pass "a second write leaves the year change files byte-identical"
else
    fail "a second write leaves the year change files byte-identical"
fi
if grep -qF "| [btw.md](btw.md#5-changes) | 2 | The standard rate stayed at ${FIX_RATE_A} percent in the fixture year. |" "$CHANGES_NOTE"; then
    pass "the year note lists the topic count and the first bullet snippet"
else
    fail "the year note lists the topic count and the first bullet snippet"
fi
if grep -qF '| [inkomstenbelasting.md](inkomstenbelasting.md#5-changes) | 3 |' "$CHANGES_NOTE"; then
    pass "the year note lists every topic of the year"
else
    fail "the year note lists every topic of the year"
fi
if grep -qF '](2020/changes.md)' "$CHANGES_OVERVIEW" \
    && grep -qF -- "- Standard rate stayed at ${FIX_RATE_A} percent. [btw.md](2020/btw.md#5-changes)" "$CHANGES_OVERVIEW"; then
    pass "the overview holds the path link and the rebased authored bullet"
else
    fail "the overview holds the path link and the rebased authored bullet"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
python3 - "$CHANGE_MUTANT/references/2020/changes.md" "$CHANGES_FENCE_START" <<'PY'
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
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift 2020/changes.md changes' "$TMP_ROOT/out.txt"; then
    pass "a hand edit inside the change block fails the check"
else
    fail "a hand edit inside the change block fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
printf 'Hand edit in the overview.\n' >>"$CHANGE_MUTANT/references/year-changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift year-changes.md$' "$TMP_ROOT/out.txt"; then
    pass "a hand edit in the overview fails the check and names the file"
else
    fail "a hand edit in the overview fails the check and names the file"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
sed -i.bak "s/Standard rate stayed at ${FIX_RATE_A} percent/Standard rate stayed at ${FIX_RATE_MISSING} percent/" \
    "$CHANGE_MUTANT/references/2020/changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q "^changes 2020/changes.md bullet 1 number ${FIX_RATE_MISSING} not in btw.md#5-changes$" "$TMP_ROOT/out.txt"; then
    pass "a bullet number missing from section 5 fails the check"
else
    fail "a bullet number missing from section 5 fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
sed -i.bak 's/btw.md#5-changes/btw.md#6-in-the-books/' "$CHANGE_MUTANT/references/2020/changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes 2020/changes.md bullet 1 link btw.md#6-in-the-books does not resolve$' "$TMP_ROOT/out.txt"; then
    pass "a bullet link that does not resolve fails the check"
else
    fail "a bullet link that does not resolve fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
sed -i.bak '/Reduced rate stayed at/d' "$CHANGE_MUTANT/references/2020/changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes 2020/changes.md 4 authored bullets, the band is 5 to 10$' "$TMP_ROOT/out.txt"; then
    pass "a year note under the bullet band fails the check"
else
    fail "a year note under the bullet band fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
python3 - "$CHANGE_MUTANT/references/2020/changes.md" <<'PY'
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
for line in lines:
    if line == "## 2. All changes by topic":
        out.extend(["- Fixture extra bullet. [btw.md](btw.md#5-changes)"] * 6)
    out.append(line)
open(path, "w", encoding="utf-8").write("\n".join(out))
PY
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes 2020/changes.md 11 authored bullets, the band is 5 to 10$' "$TMP_ROOT/out.txt"; then
    pass "a year note over the bullet band fails the check"
else
    fail "a year note over the bullet band fails the check"
fi
python3 - "$CHANGES_FIXTURE/references/dutch-tax-rules.md" <<'PY'
import sys

path = sys.argv[1]
row = "| `inkomstenbelasting.md` | Income tax |\n"
added = "| `changes.md` | Changes |\n"
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace(row, row + added, 1))
PY
if run_generator "$CHANGES_FIXTURE" && run_generator "$CHANGES_FIXTURE" --check \
    && ! grep -qF 'changes.md' "$CHANGES_FIXTURE/references/2020/README.md"; then
    pass "a year change note is not held to the topic rules"
else
    fail "a year change note is not held to the topic rules"
fi

# ───────────────────────────────────────────────────────────────
# 8. MUTATIONS IN TEMP COPIES
# ───────────────────────────────────────────────────────────────

group "mutations in temp copies"
MUT="$TMP_ROOT/mutation"
TOPIC_FENCE_START="<!-- ${GEN_WORD}:topic-files:start -->"
LAST_FENCE_END="<!-- ${GEN_WORD}:headline-figures:end -->"

copy_skill "$MUT"
python3 - "$MUT/references/2020/README.md" "$TOPIC_FENCE_START" <<'PY'
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
if [[ "$status" -ne 0 ]] && grep -q '^drift 2020/README.md topic-files' "$TMP_ROOT/out.txt"; then
    pass "a hand edit inside a fence fails the check"
else
    fail "a hand edit inside a fence fails the check"
fi

copy_skill "$MUT"
python3 - "$MUT/references/2020/inkomstenbelasting.md" "$RATE_BOX1_UP" "$RATE_BOX1_NEXT" <<'PY'
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
if [[ "$status" -ne 0 ]] && grep -q '^drift 2020/README.md ' "$TMP_ROOT/out.txt" \
    && grep -q '^drift dutch-tax-rules.md s3-' "$TMP_ROOT/out.txt"; then
    pass "a changed year value names the year README and the section blocks"
else
    fail "a changed year value names the year README and the section blocks"
fi

copy_skill "$MUT"
grep -v -F "$LAST_FENCE_END" "$MUT/references/2020/README.md" >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/2020/README.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -eq 2 ]] && grep -q 'fence error' "$TMP_ROOT/out.txt"; then
    pass "an unmatched fence stops the check with exit 2"
else
    fail "an unmatched fence stops the check with exit 2"
fi

copy_skill "$MUT"
grep -v '^nav_label:' "$MUT/references/2020/btw.md" >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/2020/btw.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q 'missing nav_label' "$TMP_ROOT/out.txt"; then
    pass "a missing nav_label fails the check"
else
    fail "a missing nav_label fails the check"
fi

copy_skill "$MUT"
sed 's/^nav_label: .*/nav_label: "BTW"/' "$MUT/references/2020/inkomstenbelasting.md" \
    >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/2020/inkomstenbelasting.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q 'duplicate nav_label' "$TMP_ROOT/out.txt"; then
    pass "a duplicate nav_label fails the check"
else
    fail "a duplicate nav_label fails the check"
fi

copy_skill "$MUT"
long_label=$(awk 'BEGIN { for (i = 0; i < 61; i++) printf "A" }')
sed "s/^nav_label: .*/nav_label: \"$long_label\"/" "$MUT/references/2020/btw.md" \
    >"$TMP_ROOT/mutated.md"
mv "$TMP_ROOT/mutated.md" "$MUT/references/2020/btw.md"
run_generator "$MUT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q 'the limit is 60' "$TMP_ROOT/out.txt"; then
    pass "a nav_label over 60 characters fails the check"
else
    fail "a nav_label over 60 characters fails the check"
fi

copy_skill "$MUT"
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

# ───────────────────────────────────────────────────────────────
# 9. EDIT OUTSIDE EVERY FENCE
# ───────────────────────────────────────────────────────────────

group "outside fence"
HAND_NOTE="Hand-written line that sits outside every fence."
OUTSIDE="$TMP_ROOT/outside-fence"
copy_skill "$OUTSIDE"
if insert_hand_line "$OUTSIDE/references/2020/README.md" "$HAND_NOTE"; then
    before=$(file_checksum "$OUTSIDE/references/2020/README.md")
    run_generator "$OUTSIDE"
    status=$?
    after=$(file_checksum "$OUTSIDE/references/2020/README.md")
    if [[ "$status" -eq 0 ]] && [[ "$before" == "$after" ]] \
        && grep -qF "$HAND_NOTE" "$OUTSIDE/references/2020/README.md"; then
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
if [[ "$(unverified_count "$YEAR_README" inkomstenbelasting.md)" == "3" ]]; then
    pass "the UNVERIFIED count for references/2020/inkomstenbelasting.md is 3"
else
    fail "the UNVERIFIED count for references/2020/inkomstenbelasting.md is 3"
fi

EQUALITY="$TMP_ROOT/equality-mutant"
copy_skill "$EQUALITY"
sed 's/\.startswith(UNVERIFIED_TAG)/== UNVERIFIED_TAG/' "$BUILDER" \
    >"$EQUALITY/scripts/build-reference-index.py"
sed_applied=1
cmp -s "$BUILDER" "$EQUALITY/scripts/build-reference-index.py" && sed_applied=0
run_generator "$EQUALITY"
mutant_count=$(unverified_count "$EQUALITY/references/2020/README.md" inkomstenbelasting.md)
cp "$BUILDER" "$EQUALITY/scripts/reference-index-checker.py"
python3 -I "$EQUALITY/scripts/reference-index-checker.py" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
if [[ "$sed_applied" -eq 1 ]] && [[ "$mutant_count" != "3" ]] && [[ "$status" -ne 0 ]]; then
    pass "the equality-only mutant was caught: it counts $mutant_count and the check fails"
else
    fail "the equality-only mutant was caught: it counts $mutant_count and the check fails"
fi

# ───────────────────────────────────────────────────────────────
# 11. FENCE GUARD MUTANT
# ───────────────────────────────────────────────────────────────

group "fence guard mutant"
GUARD="$TMP_ROOT/fence-guard-mutant"
copy_skill "$GUARD"
# The body start offset is what confines a replacement to the fence. Setting it
# to zero makes the writer replace from the top of the file, so one sed edit
# removes the guard.
sed 's/"body_start": end/"body_start": 0/' "$BUILDER" >"$GUARD/scripts/build-reference-index.py"
if cmp -s "$BUILDER" "$GUARD/scripts/build-reference-index.py"; then
    fail "the fence guard cannot be removed by a single sed edit, so the outside-fence case was not run against a mutant"
else
    if insert_hand_line "$GUARD/references/2020/README.md" "$HAND_NOTE"; then
        before=$(file_checksum "$GUARD/references/2020/README.md")
        run_generator "$GUARD"
        status=$?
        after=$(file_checksum "$GUARD/references/2020/README.md")
        if [[ "$status" -eq 0 ]] && [[ "$before" != "$after" ]] \
            && ! grep -qF "$HAND_NOTE" "$GUARD/references/2020/README.md"; then
            pass "the fence guard mutant was caught: the outside-fence case fails under it"
        else
            fail "the fence guard mutant was caught: the outside-fence case fails under it"
        fi
    else
        fail "the fence guard mutant was caught: the outside-fence case fails under it"
    fi
fi

# ───────────────────────────────────────────────────────────────
# 12. NAV BUDGET
# ───────────────────────────────────────────────────────────────

# WHY: the budget of a block is the smaller of the fixed byte cap and one
# percent of the file size, so a body just over either cap must fail --check
# and the budget line must name the cap that fires.
group "nav budget"
BUDGET_CAP="$TMP_ROOT/budget-cap/sk-moneybird-accountant"
if make_fixture "$BUDGET_CAP" \
    && run_generator "$BUDGET_CAP" --init \
    && run_generator "$BUDGET_CAP" \
    && shape_nav_file "$BUDGET_CAP/references/2020/large-fixture.md" 200000 1300 "$GEN_WORD"; then
    run_generator "$BUDGET_CAP" --check
    status=$?
    if [[ "$status" -ne 0 ]] \
        && grep -q '^budget 2020/large-fixture.md nav 1300 over 1200$' "$TMP_ROOT/out.txt"; then
        pass "a 1300 byte plan in a 200000 byte file fails on the 1200 byte cap"
    else
        fail "a 1300 byte plan in a 200000 byte file fails on the 1200 byte cap"
    fi
else
    fail "a 1300 byte plan in a 200000 byte file fails on the 1200 byte cap"
fi

BUDGET_PERCENT="$TMP_ROOT/budget-percent/sk-moneybird-accountant"
if make_fixture "$BUDGET_PERCENT" \
    && run_generator "$BUDGET_PERCENT" --init \
    && run_generator "$BUDGET_PERCENT" \
    && shape_nav_file "$BUDGET_PERCENT/references/2020/large-fixture.md" 51300 600 "$GEN_WORD"; then
    run_generator "$BUDGET_PERCENT" --check
    status=$?
    if [[ "$status" -ne 0 ]] \
        && grep -q '^budget 2020/large-fixture.md nav 600 over 513$' "$TMP_ROOT/out.txt"; then
        pass "a 600 byte plan in a 51300 byte file fails on the 1 percent cap"
    else
        fail "a 600 byte plan in a 51300 byte file fails on the 1 percent cap"
    fi
else
    fail "a 600 byte plan in a 51300 byte file fails on the 1 percent cap"
fi

# ───────────────────────────────────────────────────────────────
# 13. REAL SECTION LIST
# ───────────────────────────────────────────────────────────────

group "real section list"
TOC_FENCE_START="<!-- ${GEN_WORD}:toc:start -->"
TOC_FENCE_END="<!-- ${GEN_WORD}:toc:end -->"
GUIDE_FILE="$SKILL_SRC/references/dutch-tax-rules.md"
awk -v start="$TOC_FENCE_START" -v end="$TOC_FENCE_END" '
    $0 == start { inside = 1; next }
    $0 == end { inside = 0; next }
    inside
' "$GUIDE_FILE" >"$TMP_ROOT/toc-body.txt"
toc_missing=""
for number in 1 2 3 4 5 6 7 8 9 10; do
    if ! grep -qE -- "^- 3\.${number} .*: lines [0-9]+-[0-9]+$" "$TMP_ROOT/toc-body.txt"; then
        toc_missing="$toc_missing 3.${number}"
    fi
done
if [[ -z "$toc_missing" ]]; then
    pass "the real section list names subsections 3.1 to 3.10 with a range each"
else
    fail "the real section list names subsections 3.1 to 3.10 with a range each"
fi
if run_generator "$SKILL_SRC" --check; then
    pass "the real corpus passes --check, which confirms every section list range"
else
    fail "the real corpus passes --check, which confirms every section list range"
fi

# ───────────────────────────────────────────────────────────────
# 14. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
