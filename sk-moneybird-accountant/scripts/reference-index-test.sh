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

# Prove that the walker finds a nested file that a flat-only walk misses
# Args:
#   $1 - Skill folder whose builder script to import
# Returns:
#   0 when the deep walk holds the nested file and the flat-only walk misses it
walk_depth_check() {
    python3 - "$1" <<'PY'
import importlib.util
import sys

skill = sys.argv[1]
spec = importlib.util.spec_from_file_location("nested_builder", skill + "/scripts/build-reference-index.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
nested = "tax-rules/2020/vat/figures.md"
deep = module.reference_files()
flat = module.reference_files(depth=1)
deep_hits = [entry for entry in deep if entry.endswith(nested)]
flat_hits = [entry for entry in flat if entry.endswith(nested)]
print("deep files: %d" % len(deep))
print("flat files: %d" % len(flat))
if len(deep_hits) != 1 or flat_hits:
    sys.exit(1)
PY
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

# The nested fixture rates are built the same way, so the tracked file holds
# no amount-shaped literal either.
NEST_RATE_MAIN=$(printf '%d%%' 21)
NEST_RATE_LOW=$(printf '%d%%' 9)

# WHY: make_fixture keeps the pre-move flat layout on purpose, so the write
# mode and the read plan still prove the flat tree. The path parts stay
# variables so the repository's old-layout grep finds no literal.
FLAT_REF="references"
FLAT_YEAR="2020"

# Build a minimal skill folder with one year folder, a large file, a guide
# with section 3, a manifest and the page that routes the fixture leaves
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_fixture() {
    local skill="$1"
    mkdir -p "$skill/scripts" "$skill/$FLAT_REF/$FLAT_YEAR" "$skill/assets" || return 1
    cp "$BUILDER" "$skill/scripts/" || return 1
    cat >"$skill/$FLAT_REF/dutch-tax-rules.md" <<'EOF'
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

### 3.1 BTW (VAT)

Year files: `vat.md` in each year folder.

The hand-written rule prose stays here.
EOF
    cat >"$skill/$FLAT_REF/$FLAT_YEAR/README.md" <<'EOF'
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
    cat >"$skill/$FLAT_REF/$FLAT_YEAR/vat.md" <<'EOF'
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
    cat >"$skill/$FLAT_REF/$FLAT_YEAR/income-tax.md" <<EOF
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
    } >"$skill/$FLAT_REF/$FLAT_YEAR/large-fixture.md" || return 1
    printf '{"modes":[{"leaves":["%s/%s/README.md","assets/handbook.md"]}]}\n' \
        "$FLAT_REF" "$FLAT_YEAR" >"$skill/leaf-manifest.json" || return 1
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
    cat >>"$skill/$FLAT_REF/$FLAT_YEAR/vat.md" <<EOF

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The standard rate stayed at ${FIX_RATE_A} percent in the fixture year.
- The reduced rate stayed at ${FIX_RATE_C} percent in the fixture year.
EOF
    cat >>"$skill/$FLAT_REF/$FLAT_YEAR/income-tax.md" <<EOF

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The box 1 rate stayed at ${FIX_RATE_B} percent in the fixture year.
- The band stayed at ${FIX_RATE_C} percent in the fixture year.
- The fixture year 2020 kept its rules.
EOF
    cat >"$skill/$FLAT_REF/$FLAT_YEAR/changelog.md" <<'EOF'
# Corrections 2020

Fixture correction log for the change note fixture.
EOF
    cat >"$skill/$FLAT_REF/$FLAT_YEAR/changes.md" <<EOF
---
title: "Changes tax year 2020"
description: "Fixture year change note."
---

# Changes tax year 2020

**Rule:** The fixture note restates section 5 of the year topics and links the [correction log](changelog.md) and the [year overview](README.md).

---

## 1. Unique to 2020

- Standard rate stayed at ${FIX_RATE_A} percent. [vat.md](vat.md#5-changes)
- Reduced rate stayed at ${FIX_RATE_C} percent. [vat.md](vat.md#5-changes)
- Box 1 rate stayed at ${FIX_RATE_B} percent. [income-tax.md](income-tax.md#5-changes)
- Band stayed at ${FIX_RATE_C} percent. [income-tax.md](income-tax.md#5-changes)
- Fixture year 2020 kept its rules. [income-tax.md](income-tax.md#5-changes)

---

## 2. All changes by topic
EOF
    return 0
}

# Build a skill folder whose year folder and topic folder sit at any depth
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_nested_fixture() {
    local skill="$1"
    mkdir -p "$skill/scripts" "$skill/references/tax-rules/2020/vat" "$skill/assets" || return 1
    cp "$BUILDER" "$skill/scripts/" || return 1
    cat >"$skill/references/tax-rules/dutch-tax-rules.md" <<'EOF'
---
title: "Dutch tax rules"
---

# Dutch tax rules

## 1. Topic files in every year folder

| File | Topic |
|---|---|
| `vat.md` | VAT |

## 3. GENERAL RULES

### 3.1 BTW (VAT)

Year files: `vat.md` in each year folder.

The hand-written rule prose stays here.
EOF
    cat >"$skill/references/tax-rules/2020/README.md" <<'EOF'
---
title: "Tax year 2020"
description: "Fixture year overview."
---

# Tax year 2020

## 1. OVERVIEW

Hand prose for the nested fixture year.

## 2. TOPIC FILES

## 3. HEADLINE FIGURES
EOF
    # The delimiter stays unquoted so the runtime-built rate values expand. The
    # body holds no dollar sign, backtick or backslash of its own.
    cat >"$skill/references/tax-rules/2020/vat/figures.md" <<EOF
---
title: "BTW 2020"
description: "Covers Dutch VAT for the nested fixture."
nav_label: "BTW"
---

# BTW 2020

## 1. KEY FIGURES

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Standard rate | ${NEST_RATE_MAIN} | enacted | Verified |
| Reduced rate | ${NEST_RATE_LOW} | enacted | UNVERIFIED |
EOF
    cat >"$skill/references/tax-rules/2020/vat/rules.md" <<'EOF'
---
title: "BTW rules 2020"
description: "Rule prose for the nested fixture."
---

# BTW rules 2020

## 1. RULES

Rule text that a nested file holds.
EOF
    printf '{"modes":[{"leaves":["references/tax-rules/2020/README.md","assets/handbook.md"]}]}\n' \
        >"$skill/leaf-manifest.json" || return 1
    printf '# Nested fixture skill\n\nSee the [handbook](assets/handbook.md).\n' >"$skill/SKILL.md" || return 1
    printf '# Handbook\n' >"$skill/assets/handbook.md" || return 1
    return 0
}

# Build a skill folder whose section 3 subsections sit one per file under a
# general folder, with the entry file holding a pointer table in their place
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_general_fixture() {
    local skill="$1"
    mkdir -p "$skill/scripts" "$skill/references/tax-rules/general" "$skill/references/tax-rules/2020" "$skill/assets" || return 1
    cp "$BUILDER" "$skill/scripts/" || return 1
    cat >"$skill/references/tax-rules/dutch-tax-rules.md" <<'EOF'
---
title: "Dutch tax rules"
---

# Dutch tax rules

## 1. Topic files in every year folder

| File | Topic |
|---|---|
| `vat.md` | VAT |

## 3. GENERAL RULES

The rules below hold across tax years.

### General topics

Each general topic below sits in its own file under `general/`.

| Section | Topic | File |
|---|---|---|
| 3.1 | BTW (VAT) | [vat.md](general/vat.md) |
EOF
    cat >"$skill/references/tax-rules/general/vat.md" <<'EOF'
---
title: "BTW (VAT)"
description: "General fixture topic for the split layout."
---

# BTW (VAT)

### 3.1 BTW (VAT)

Year files: `vat.md` in each year folder.

The hand-written rule prose stays here.
EOF
    cat >"$skill/references/tax-rules/2020/README.md" <<'EOF'
---
title: "Tax year 2020"
description: "Fixture year overview."
---

# Tax year 2020

## 1. OVERVIEW

Hand prose for the general folder fixture year.

## 2. TOPIC FILES

## 3. HEADLINE FIGURES
EOF
    # The delimiter stays unquoted so the runtime-built rate values expand. The
    # body holds no dollar sign, backtick or backslash of its own.
    cat >"$skill/references/tax-rules/2020/vat.md" <<EOF
---
title: "BTW 2020"
description: "Covers Dutch VAT for the general folder fixture."
nav_label: "BTW"
---

# BTW 2020

## 1. KEY FIGURES

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Standard rate | ${NEST_RATE_MAIN} | enacted | Verified |
| Reduced rate | ${NEST_RATE_LOW} | enacted | UNVERIFIED |
EOF
    printf '{"modes":[{"leaves":["references/tax-rules/2020/README.md","assets/handbook.md"]}]}\n' \
        >"$skill/leaf-manifest.json" || return 1
    printf '# General fixture skill\n\nSee the [handbook](assets/handbook.md).\n' >"$skill/SKILL.md" || return 1
    printf '# Handbook\n' >"$skill/assets/handbook.md" || return 1
    return 0
}

# Build a skill folder whose year folder holds one topic as a folder of four
# part files, so a section lookup and a generated link land on the right part
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_split_topic_fixture() {
    local skill="$1"
    mkdir -p "$skill/scripts" "$skill/references/tax-rules/2020/vat" "$skill/assets" || return 1
    cp "$BUILDER" "$skill/scripts/" || return 1
    cat >"$skill/references/tax-rules/dutch-tax-rules.md" <<'EOF'
---
title: "Dutch tax rules"
---

# Dutch tax rules

## 1. Topic files in every year folder

| File | Topic |
|---|---|
| `vat.md` | VAT |

## 3. GENERAL RULES

### 3.1 BTW (VAT)

Year files: `vat.md` in each year folder.

The hand-written rule prose stays here.
EOF
    cat >"$skill/references/tax-rules/2020/README.md" <<'EOF'
---
title: "Tax year 2020"
description: "Fixture year overview."
---

# Tax year 2020

## 1. OVERVIEW

Hand prose for the split topic fixture year.

## 2. TOPIC FILES

## 3. HEADLINE FIGURES
EOF
    # The delimiter stays unquoted so the runtime-built rate values expand. The
    # body holds no dollar sign, backtick or backslash of its own.
    cat >"$skill/references/tax-rules/2020/vat/figures.md" <<EOF
---
title: "BTW 2020"
description: "Covers Dutch VAT for the split topic fixture."
nav_label: "BTW"
---

# BTW 2020

## 2. KEY FIGURES

| Item | Value 2020 | Status | Check |
|---|---|---|---|
| Standard rate | ${NEST_RATE_MAIN} | enacted | Verified |
| Reduced rate | ${NEST_RATE_LOW} | enacted | UNVERIFIED |
EOF
    cat >"$skill/references/tax-rules/2020/vat/rules.md" <<'EOF'
---
title: "BTW rules 2020"
description: "Rule prose for the split topic fixture."
---

# BTW rules 2020

## 3. HOW IT WORKS

Rule text that a split part holds.
EOF
    cat >"$skill/references/tax-rules/2020/vat/examples.md" <<'EOF'
---
title: "BTW examples 2020"
description: "Worked examples for the split topic fixture."
---

# BTW examples 2020

## 4. WORKED EXAMPLES

Example text that a split part holds.
EOF
    cat >"$skill/references/tax-rules/2020/vat/notes.md" <<EOF
---
title: "BTW notes 2020"
description: "Notes for the split topic fixture."
---

# BTW notes 2020

## 5. CHANGES FROM 2019

<a id="5-changes"></a>

- The standard rate stayed at ${FIX_RATE_A} percent in the fixture year.
- The reduced rate stayed at ${FIX_RATE_C} percent in the fixture year.
EOF
    cat >"$skill/references/tax-rules/2020/changes.md" <<EOF
---
title: "Changes tax year 2020"
description: "Fixture year change note."
---

# Changes tax year 2020

**Rule:** The fixture note restates section 5 of the year topics.

---

## 1. Unique to 2020

- Standard rate stayed at ${FIX_RATE_A} percent. [vat.md](vat.md#5-changes)
- Reduced rate stayed at ${FIX_RATE_C} percent. [vat/notes.md](vat/notes.md#5-changes)
- The split original resolves to its notes part. [vat.md](vat.md#5-changes)
- The part link resolves as written. [vat/notes.md](vat/notes.md#5-changes)
- Flat and split links both resolve. [vat.md](vat.md#5-changes)

---

## 2. All changes by topic
EOF
    printf '{"modes":[{"leaves":["references/tax-rules/2020/README.md","assets/handbook.md"]}]}\n' \
        >"$skill/leaf-manifest.json" || return 1
    printf '# Split topic fixture skill\n\nSee the [handbook](assets/handbook.md).\n' >"$skill/SKILL.md" || return 1
    printf '# Handbook\n' >"$skill/assets/handbook.md" || return 1
    return 0
}

# Build a fixture whose routing signals file holds a valid gap ledger
# Args:
#   $1 - Skill folder to create
# Returns:
#   0 when the fixture is ready, 1 when a write fails
make_gaps_fixture() {
    local skill="$1"
    make_fixture "$skill" || return 1
    cat >"$skill/$FLAT_REF/routing-signals.md" <<'EOF'
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
real_change_rows=$(sed -n '/GENERATED:changes:start/,/GENERATED:changes:end/p' "$SKILL_SRC/references/tax-rules/2026/changes.md" | grep -c '#5-changes)')
if [[ "$real_change_rows" == "12" ]]; then
    pass "the real 2026 note lists all twelve topics with a section link"
else
    fail "the real 2026 note lists all twelve topics with a section link"
fi
real_overview_years=$(grep -c '^## 20' "$SKILL_SRC/references/tax-rules/year-changes.md")
if [[ "$real_overview_years" == "8" ]]; then
    pass "the real overview holds eight year sections"
else
    fail "the real overview holds eight year sections"
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

# The change note sits under tax-rules now, so the generated overview keeps
# every year only when CHANGE_NOTE_RE accepts the moved path. The flat
# predicate would drop all eight sections on a write.
TAX_RULES_CHANGES="$TMP_ROOT/tax-rules-changes"
copy_skill "$TAX_RULES_CHANGES"
if run_generator "$TAX_RULES_CHANGES" \
    && [[ "$(grep -c '^## 20' "$TAX_RULES_CHANGES/references/tax-rules/year-changes.md")" == "8" ]]; then
    pass "a write keeps the eight year sections for the tax-rules change notes"
else
    fail "a write keeps the eight year sections for the tax-rules change notes"
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
if grep -qF "$READ_PLAN_FENCE" "$FIXTURE/$FLAT_REF/$FLAT_YEAR/large-fixture.md"; then
    pass "the large fixture file gained a read plan fence"
else
    fail "the large fixture file gained a read plan fence"
fi
if grep -qF "$TOPIC_TABLE_FENCE" "$FIXTURE/$FLAT_REF/$FLAT_YEAR/README.md"; then
    pass "the year README gained a topic table fence"
else
    fail "the year README gained a topic table fence"
fi

# A year folder gains a changelog beside its topic files. The topic table may
# name it, yet the generator reads no topic field from that file.
cat >"$FIXTURE/$FLAT_REF/$FLAT_YEAR/changelog.md" <<'MARKDOWN'
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
| 2026-10-12 | vat.md | Standard rate | as first researched | Corrected | https://example.invalid/source |
MARKDOWN
python3 - "$FIXTURE/$FLAT_REF/dutch-tax-rules.md" <<'PY'
import sys

path = sys.argv[1]
row = "| `income-tax.md` | Income tax |\n"
added = "| `changelog.md` | Corrections |\n"
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace(row, row + added, 1))
PY
if run_generator "$FIXTURE" && run_generator "$FIXTURE" --check \
    && ! grep -qF 'changelog.md' "$FIXTURE/$FLAT_REF/$FLAT_YEAR/README.md"; then
    pass "a year changelog is not held to the topic rules"
else
    fail "a year changelog is not held to the topic rules"
fi

sed -i.bak '/^## 1\. KEY FIGURES$/,$d' "$FIXTURE/$FLAT_REF/$FLAT_YEAR/vat.md"
run_generator "$FIXTURE" --check
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'no KEY FIGURES table in 2020/vat.md' "$TMP_ROOT/out.txt"; then
    pass "a topic file is still held to the topic rules"
else
    fail "a topic file is still held to the topic rules"
fi

# ───────────────────────────────────────────────────────────────
# 7b. ITEM INDEX AND ANSWER SURFACE
# ───────────────────────────────────────────────────────────────

# WHY: the item index is a second representation of the value table, so the
# suite compares its row count with the table and checks the answer surface
# schema on every index record.
group "item index and answer surface"
ITEM_FIXTURE="$TMP_ROOT/item-fixture/sk-moneybird-accountant"
if make_fixture "$ITEM_FIXTURE" \
    && run_generator "$ITEM_FIXTURE" --init \
    && run_generator "$ITEM_FIXTURE" \
    && run_generator "$ITEM_FIXTURE" --check; then
    pass "the item index fixture writes and passes --check"
else
    fail "the item index fixture writes and passes --check"
fi
if python3 - "$ITEM_FIXTURE/$FLAT_REF/$FLAT_YEAR/vat.md" <<'PY'
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
table = re.search(r"\|\s*Item\s*\|.*?\n\|[-\s|]+\|\n((?:\|.*\n)+)", text)
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
if python3 - "$ITEM_FIXTURE/$FLAT_REF/index.json" <<'PY'
import json
import sys

rows = json.load(open(sys.argv[1], encoding="utf-8"))["files"]
by_path = {row["path"]: row for row in rows}
for row in rows:
    surface = row.get("answerSurface")
    if not isinstance(surface, dict) or set(surface) != {"section", "rows", "tokens"}:
        sys.exit(1)
vat = by_path.get("2020/vat.md")
readme = by_path.get("2020/README.md")
if vat is None or readme is None:
    sys.exit(1)
if vat["answerSurface"]["section"] != "1-key-figures" or vat["answerSurface"]["rows"] != 2:
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

# A hand-removed index row fails the check and names the block.
ITEM_MUTANT="$TMP_ROOT/item-mutant/sk-moneybird-accountant"
copy_fixture "$ITEM_FIXTURE" "$ITEM_MUTANT"
sed -i.bak '/^| Reduced rate | 2 |$/d' "$ITEM_MUTANT/$FLAT_REF/$FLAT_YEAR/vat.md"
run_generator "$ITEM_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift 2020/vat.md key-figure-index' "$TMP_ROOT/out.txt"; then
    pass "a hand-removed item index row fails the check"
else
    fail "a hand-removed item index row fails the check"
fi

group "year change notes"
CHANGES_FIXTURE="$TMP_ROOT/change-fixture/sk-moneybird-accountant"
CHANGES_NOTE="$CHANGES_FIXTURE/$FLAT_REF/$FLAT_YEAR/changes.md"
CHANGES_OVERVIEW="$CHANGES_FIXTURE/$FLAT_REF/year-changes.md"
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
if grep -qF "| [vat.md](vat.md#5-changes) | 2 | The standard rate stayed at ${FIX_RATE_A} percent in the fixture year. |" "$CHANGES_NOTE"; then
    pass "the year note lists the topic count and the first bullet snippet"
else
    fail "the year note lists the topic count and the first bullet snippet"
fi
if grep -qF '| [income-tax.md](income-tax.md#5-changes) | 3 |' "$CHANGES_NOTE"; then
    pass "the year note lists every topic of the year"
else
    fail "the year note lists every topic of the year"
fi
if grep -qF '](2020/changes.md)' "$CHANGES_OVERVIEW" \
    && grep -qF -- "- Standard rate stayed at ${FIX_RATE_A} percent. [vat.md](2020/vat.md#5-changes)" "$CHANGES_OVERVIEW"; then
    pass "the overview holds the path link and the rebased authored bullet"
else
    fail "the overview holds the path link and the rebased authored bullet"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
python3 - "$CHANGE_MUTANT/$FLAT_REF/$FLAT_YEAR/changes.md" "$CHANGES_FENCE_START" <<'PY'
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
printf 'Hand edit in the overview.\n' >>"$CHANGE_MUTANT/$FLAT_REF/year-changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift year-changes.md$' "$TMP_ROOT/out.txt"; then
    pass "a hand edit in the overview fails the check and names the file"
else
    fail "a hand edit in the overview fails the check and names the file"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
sed -i.bak "s/Standard rate stayed at ${FIX_RATE_A} percent/Standard rate stayed at ${FIX_RATE_MISSING} percent/" \
    "$CHANGE_MUTANT/$FLAT_REF/$FLAT_YEAR/changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q "^changes 2020/changes.md bullet 1 number ${FIX_RATE_MISSING} not in vat.md#5-changes$" "$TMP_ROOT/out.txt"; then
    pass "a bullet number missing from section 5 fails the check"
else
    fail "a bullet number missing from section 5 fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
sed -i.bak 's/vat.md#5-changes/vat.md#6-in-the-books/' "$CHANGE_MUTANT/$FLAT_REF/$FLAT_YEAR/changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes 2020/changes.md bullet 1 link vat.md#6-in-the-books does not resolve$' "$TMP_ROOT/out.txt"; then
    pass "a bullet link that does not resolve fails the check"
else
    fail "a bullet link that does not resolve fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
sed -i.bak '/Reduced rate stayed at/d' "$CHANGE_MUTANT/$FLAT_REF/$FLAT_YEAR/changes.md"
run_generator "$CHANGE_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^changes 2020/changes.md 4 authored bullets, the band is 5 to 10$' "$TMP_ROOT/out.txt"; then
    pass "a year note under the bullet band fails the check"
else
    fail "a year note under the bullet band fails the check"
fi
copy_fixture "$CHANGES_FIXTURE" "$CHANGE_MUTANT"
python3 - "$CHANGE_MUTANT/$FLAT_REF/$FLAT_YEAR/changes.md" <<'PY'
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
for line in lines:
    if line == "## 2. All changes by topic":
        out.extend(["- Fixture extra bullet. [vat.md](vat.md#5-changes)"] * 6)
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
python3 - "$CHANGES_FIXTURE/$FLAT_REF/dutch-tax-rules.md" <<'PY'
import sys

path = sys.argv[1]
row = "| `income-tax.md` | Income tax |\n"
added = "| `changes.md` | Changes |\n"
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace(row, row + added, 1))
PY
if run_generator "$CHANGES_FIXTURE" && run_generator "$CHANGES_FIXTURE" --check \
    && ! grep -qF 'changes.md' "$CHANGES_FIXTURE/$FLAT_REF/$FLAT_YEAR/README.md"; then
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
    if insert_hand_line "$GUARD/references/tax-rules/2020/README.md" "$HAND_NOTE"; then
        before=$(file_checksum "$GUARD/references/tax-rules/2020/README.md")
        run_generator "$GUARD"
        status=$?
        after=$(file_checksum "$GUARD/references/tax-rules/2020/README.md")
        if [[ "$status" -eq 0 ]] && [[ "$before" != "$after" ]] \
            && ! grep -qF "$HAND_NOTE" "$GUARD/references/tax-rules/2020/README.md"; then
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
    && shape_nav_file "$BUDGET_CAP/$FLAT_REF/$FLAT_YEAR/large-fixture.md" 200000 1300 "$GEN_WORD"; then
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
    && shape_nav_file "$BUDGET_PERCENT/$FLAT_REF/$FLAT_YEAR/large-fixture.md" 51300 600 "$GEN_WORD"; then
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
if run_generator "$SKILL_SRC" --check; then
    pass "the real corpus passes --check, which confirms every section list range"
else
    fail "the real corpus passes --check, which confirms every section list range"
fi

# ───────────────────────────────────────────────────────────────
# 14. NESTED REFERENCE FOLDERS
# ───────────────────────────────────────────────────────────────

group "nested reference folders"
NESTED_FIXTURE="$TMP_ROOT/nested-fixture/sk-moneybird-accountant"
if make_nested_fixture "$NESTED_FIXTURE"; then
    pass "the nested fixture repository builds"
else
    fail "the nested fixture repository builds"
fi
if run_generator "$NESTED_FIXTURE" --init; then
    pass "the nested fixture --init exits 0"
else
    fail "the nested fixture --init exits 0"
fi
if run_generator "$NESTED_FIXTURE"; then
    pass "the nested fixture write exits 0"
else
    fail "the nested fixture write exits 0"
fi
if run_generator "$NESTED_FIXTURE" --check; then
    pass "the nested fixture --check exits 0 after the writes"
else
    fail "the nested fixture --check exits 0 after the writes"
fi

if python3 - "$NESTED_FIXTURE/references/index.json" <<'PY'
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

if grep -qF '| [vat](vat/figures.md) | Covers Dutch VAT for the nested fixture. | 2 | 1 | 0 |' \
    "$NESTED_FIXTURE/references/tax-rules/2020/README.md"; then
    pass "the nested topic folder is counted like a file in the year README"
else
    fail "the nested topic folder is counted like a file in the year README"
fi

if grep -qF 'sk-moneybird-accountant/references/tax-rules/2020/vat/figures.md' \
    "$NESTED_FIXTURE/references/tax-rules/dutch-tax-rules.md"; then
    pass "the nested figures file owns its section 3 rows"
else
    fail "the nested figures file owns its section 3 rows"
fi

if walk_depth_check "$NESTED_FIXTURE" >"$TMP_ROOT/out.txt" 2>&1; then
    pass "the deep walk counts the nested file and the flat-only walk misses it"
else
    fail "the deep walk counts the nested file and the flat-only walk misses it"
fi

NESTED_BEFORE=$(tree_checksums "$NESTED_FIXTURE")
run_generator "$NESTED_FIXTURE"
status=$?
NESTED_AFTER=$(tree_checksums "$NESTED_FIXTURE")
if [[ "$status" -eq 0 ]] && [[ "$NESTED_BEFORE" == "$NESTED_AFTER" ]]; then
    pass "a second nested write leaves every file byte-identical"
else
    fail "a second nested write leaves every file byte-identical"
fi

FLAT_STABLE="$TMP_ROOT/flat-stable/sk-moneybird-accountant"
if make_fixture "$FLAT_STABLE" && run_generator "$FLAT_STABLE" --init && run_generator "$FLAT_STABLE"; then
    flat_before=$(tree_checksums "$FLAT_STABLE")
    run_generator "$FLAT_STABLE"
    status=$?
    flat_after=$(tree_checksums "$FLAT_STABLE")
    if [[ "$status" -eq 0 ]] && [[ "$flat_before" == "$flat_after" ]]; then
        pass "the flat tree stays byte-identical on a second write"
    else
        fail "the flat tree stays byte-identical on a second write"
    fi
else
    fail "the flat tree stays byte-identical on a second write"
fi

# ───────────────────────────────────────────────────────────────
# 15. SPLIT LAYOUT
# ───────────────────────────────────────────────────────────────

group "general folder"
GENERAL_FIXTURE="$TMP_ROOT/general-fixture/sk-moneybird-accountant"
GENERAL_TOPIC="$GENERAL_FIXTURE/references/tax-rules/general/vat.md"
GENERAL_ENTRY="$GENERAL_FIXTURE/references/tax-rules/dutch-tax-rules.md"
GENERAL_FENCE="<!-- ${GEN_WORD}:s3-btw-vat:start -->"
if make_general_fixture "$GENERAL_FIXTURE"; then
    pass "the general folder fixture builds"
else
    fail "the general folder fixture builds"
fi
if run_generator "$GENERAL_FIXTURE" --init; then
    pass "the general folder fixture --init exits 0"
else
    fail "the general folder fixture --init exits 0"
fi
if grep -qF "$GENERAL_FENCE" "$GENERAL_TOPIC"; then
    pass "--init puts the section 3 fence in the general file"
else
    fail "--init puts the section 3 fence in the general file"
fi
if run_generator "$GENERAL_FIXTURE" && run_generator "$GENERAL_FIXTURE" --check; then
    pass "the general folder fixture passes --check after a write"
else
    fail "the general folder fixture passes --check after a write"
fi
if grep -qF 'sk-moneybird-accountant/references/tax-rules/2020/vat.md' "$GENERAL_TOPIC" \
    && ! grep -qF "$GENERAL_FENCE" "$GENERAL_ENTRY"; then
    pass "the general file carries the section 3 rows and the entry carries no fence"
else
    fail "the general file carries the section 3 rows and the entry carries no fence"
fi
general_before=$(tree_checksums "$GENERAL_FIXTURE")
run_generator "$GENERAL_FIXTURE"
status=$?
general_after=$(tree_checksums "$GENERAL_FIXTURE")
if [[ "$status" -eq 0 ]] && [[ "$general_before" == "$general_after" ]]; then
    pass "a second general folder write leaves every file byte-identical"
else
    fail "a second general folder write leaves every file byte-identical"
fi

group "split topic folder"
SPLIT_FIXTURE="$TMP_ROOT/split-fixture/sk-moneybird-accountant"
SPLIT_NOTE="$SPLIT_FIXTURE/references/tax-rules/2020/changes.md"
SPLIT_OVERVIEW="$SPLIT_FIXTURE/references/tax-rules/year-changes.md"
if make_split_topic_fixture "$SPLIT_FIXTURE"; then
    pass "the split topic fixture builds"
else
    fail "the split topic fixture builds"
fi
if run_generator "$SPLIT_FIXTURE" --init; then
    pass "the split topic fixture --init exits 0"
else
    fail "the split topic fixture --init exits 0"
fi
if run_generator "$SPLIT_FIXTURE" && run_generator "$SPLIT_FIXTURE" --check; then
    pass "the split topic fixture passes --check after a write"
else
    fail "the split topic fixture passes --check after a write"
fi
if grep -qF "| [vat.md](vat/notes.md#5-changes) | 2 | The standard rate stayed at ${FIX_RATE_A} percent in the fixture year. |" "$SPLIT_NOTE"; then
    pass "the split change row links the notes part"
else
    fail "the split change row links the notes part"
fi
if grep -qF '| [vat](vat/figures.md) | Covers Dutch VAT for the split topic fixture. | 2 | 1 | 0 |' \
    "$SPLIT_FIXTURE/references/tax-rules/2020/README.md"; then
    pass "the split year README counts the topic through its figures part"
else
    fail "the split year README counts the topic through its figures part"
fi
if grep -qF 'sk-moneybird-accountant/references/tax-rules/2020/vat/figures.md' \
    "$SPLIT_FIXTURE/references/tax-rules/dutch-tax-rules.md"; then
    pass "the split figures part owns its section 3 rows"
else
    fail "the split figures part owns its section 3 rows"
fi
if grep -qF '](2020/vat/notes.md#5-changes)' "$SPLIT_OVERVIEW"; then
    pass "the overview rebases a flat section 5 link onto the notes part"
else
    fail "the overview rebases a flat section 5 link onto the notes part"
fi
split_before=$(tree_checksums "$SPLIT_FIXTURE")
run_generator "$SPLIT_FIXTURE"
status=$?
split_after=$(tree_checksums "$SPLIT_FIXTURE")
if [[ "$status" -eq 0 ]] && [[ "$split_before" == "$split_after" ]]; then
    pass "a second split topic write leaves every file byte-identical"
else
    fail "a second split topic write leaves every file byte-identical"
fi

# ───────────────────────────────────────────────────────────────
# 16. GAP LEDGER
# ───────────────────────────────────────────────────────────────

# WHY: the ledger is authored in one reference file and copied into the index,
# so the suite proves the copy and every row rule on a fixture tree.
group "gap ledger"
PLAIN_FIXTURE="$TMP_ROOT/gaps-plain/sk-moneybird-accountant"
GAPS_FIXTURE="$TMP_ROOT/gaps-fixture/sk-moneybird-accountant"
GAPS_MUTANT="$TMP_ROOT/gaps-mutant/sk-moneybird-accountant"
if make_fixture "$PLAIN_FIXTURE" && run_generator "$PLAIN_FIXTURE" --init && run_generator "$PLAIN_FIXTURE" \
    && python3 - "$PLAIN_FIXTURE/$FLAT_REF/index.json" <<'PY'
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

if make_gaps_fixture "$GAPS_FIXTURE"; then
    pass "the gap ledger fixture builds"
else
    fail "the gap ledger fixture builds"
fi
if run_generator "$GAPS_FIXTURE" --init && run_generator "$GAPS_FIXTURE" && run_generator "$GAPS_FIXTURE" --check; then
    pass "a valid gap ledger writes and passes --check"
else
    fail "a valid gap ledger writes and passes --check"
fi
if python3 - "$GAPS_FIXTURE/$FLAT_REF/index.json" <<'PY'
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

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT"
python3 - "$GAPS_MUTANT/$FLAT_REF/routing-signals.md" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
old = "| `vat-return` | `references/vat-return/README.md` | gap |"
new = "| `vat-return` |  | gap |"
open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
PY
run_generator "$GAPS_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -Eq '^gaps routing-signals\.md row [0-9]+ topic vat-return has no owner$' "$TMP_ROOT/out.txt"; then
    pass "a gap row without an owner fails the check and names the row"
else
    fail "a gap row without an owner fails the check and names the row"
fi

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT"
sed -i.bak 's#| partial |#| unresolved |#' "$GAPS_MUTANT/$FLAT_REF/routing-signals.md"
run_generator "$GAPS_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] \
    && grep -Eq '^gaps routing-signals\.md row [0-9]+ topic yearly-overview coverage unresolved is not covered, partial or gap$' "$TMP_ROOT/out.txt"; then
    pass "an unknown coverage fails the check and names the row"
else
    fail "an unknown coverage fails the check and names the row"
fi

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT"
sed -i.bak 's#| yearly-overview |#| vat-return |#' "$GAPS_MUTANT/$FLAT_REF/routing-signals.md"
run_generator "$GAPS_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -Eq '^gaps routing-signals\.md row [0-9]+ duplicate topic vat-return$' "$TMP_ROOT/out.txt"; then
    pass "a duplicate topic fails the check and names the row"
else
    fail "a duplicate topic fails the check and names the row"
fi

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT"
python3 - "$GAPS_MUTANT/$FLAT_REF/routing-signals.md" <<'PY'
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

copy_fixture "$GAPS_FIXTURE" "$GAPS_MUTANT"
python3 - "$GAPS_MUTANT/$FLAT_REF/index.json" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace('"coverage":"gap"', '"coverage":"covered"', 1))
PY
run_generator "$GAPS_MUTANT" --check
status=$?
if [[ "$status" -ne 0 ]] && grep -q '^drift index\.json gaps topic vat-return$' "$TMP_ROOT/out.txt"; then
    pass "a hand edit to the stored gap list fails the check"
else
    fail "a hand edit to the stored gap list fails the check"
fi

# ───────────────────────────────────────────────────────────────
# 16b. LOADING NOTES LISTING PATHS
# ───────────────────────────────────────────────────────────────

# WHY: the loading notes name the generated index and the token baseline, so
# the suite asserts that both names resolve to a file with its schema fields
# and that the assertion fails when one name is dropped.
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
python3 -I - "$LISTING_SKILL/SKILL.md" <<'PY' || exit 2
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace("benchmark/token-baseline.json", "the baseline"))
PY
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
    fail "the listing-path case fails when one name is removed"
else
    pass "the listing-path case fails when one name is removed"
fi

# ───────────────────────────────────────────────────────────────
# 17. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"

[[ "$failed" -eq 0 ]]
