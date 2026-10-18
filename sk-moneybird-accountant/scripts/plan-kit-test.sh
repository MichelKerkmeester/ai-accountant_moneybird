#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: PLAN KIT TEST
# ───────────────────────────────────────────────────────────────
# Tests generate-plan-kit.py and init-workspace.sh end to end.
# Usage: plan-kit-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the kit is only trustworthy when the generated files match the references
# and init-workspace never overwrites existing finance data. This suite proves both.
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
    printf 'error: usage: plan-kit-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

GENERATOR="$SKILL_SRC/scripts/generate-plan-kit.py"
if [[ ! -f "$GENERATOR" ]]; then
    printf 'error: missing scripts/generate-plan-kit.py in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_SRC/scripts/init-workspace.sh" ]]; then
    printf 'error: missing scripts/init-workspace.sh in the skill folder\n' >&2
    exit 2
fi
if [[ ! -d "$SKILL_SRC/references/migration" ]]; then
    printf 'error: missing references/migration in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT, GIT ISOLATION AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/plan-kit-test.XXXXXX") || exit 2
mkdir -p "$TMP_ROOT/gitenv"
# WHY: isolate git config so a developer global ignore cannot change the verdicts.
export HOME="$TMP_ROOT/gitenv"
export XDG_CONFIG_HOME="$TMP_ROOT/gitenv/.config"
export GIT_CONFIG_NOSYSTEM=1

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

# Print the last stored value of a key from captured command output
# Args:
#   $1 - File holding the captured output
#   $2 - Summary key such as files_copied
# Returns:
#   0, printing the value or an empty line
summary_value() {
    tr ' ' '\n' < "$1" | sed -n "s/^$2=//p" | tail -n 1
}

# Print the octal permission mode of a path, using GNU stat or BSD stat
# Args:
#   $1 - Path to inspect
# Returns:
#   0 when a stat call succeeds, printing the mode
file_mode() {
    if stat -c '%a' "$1" >/dev/null 2>&1; then
        stat -c '%a' "$1"
    else
        stat -f '%Lp' "$1"
    fi
}

# Count folder entries whose names match a grep pattern
# Args:
#   $1 - Folder to list
#   $2 - Pattern applied to the entry names
# Returns:
#   0, printing the number of matching entries
count_named() {
    (
        cd "$1" 2>/dev/null || exit 1
        for entry in *; do
            [[ -e "$entry" || -L "$entry" ]] && printf '%s\n' "$entry"
        done | grep -c "$2"
    ) 2>/dev/null || true
}

# Count regular files below a folder
# Args:
#   $1 - Folder to walk
# Returns:
#   0 when the walk succeeds, printing the count
count_files() {
    find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Build a throwaway git repository that holds a copy of the skill
# Args:
#   $1 - Repository root to create
#   $2 - "yes" writes a .gitignore that ignores the workspace and the spec names
# Returns:
#   0 when the fixture is ready, 1 when a copy or git init fails
make_fake_repo() {
    local root="$1"
    local ignored="$2"
    mkdir -p "$root/sk-moneybird-accountant" || return 1
    local part
    for part in scripts assets references; do
        if [[ -e "$SKILL_SRC/$part" ]]; then
            cp -R "$SKILL_SRC/$part" "$root/sk-moneybird-accountant/" || return 1
        fi
    done
    if [[ "$ignored" = yes ]]; then
        printf '/migration-workspace/\n/specs/*\n!/specs/000-migration-template/\n' >"$root/.gitignore" || return 1
    fi
    (
        cd "$root" || exit 1
        git init -q .
    ) || return 1
    return 0
}

# Run the plan kit generator inside a fixture repository
# Args:
#   $1 - Repository root that holds the copied skill
#   $2 - Tag for the captured output file under the temp root
# Returns:
#   The generator exit status
generate_repo() {
    local root="$1"
    local tag="$2"
    python3 -I "$root/sk-moneybird-accountant/scripts/generate-plan-kit.py" >"$TMP_ROOT/generate-$tag.txt" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 5. GENERATED COPY CHECKS
# ───────────────────────────────────────────────────────────────

group "Generated copy"

REPO_A="$TMP_ROOT/repo-a"
SKILL_A="$REPO_A/sk-moneybird-accountant"
GEN_A="$SKILL_A/scripts/generate-plan-kit.py"
INIT_A="$SKILL_A/scripts/init-workspace.sh"
ASSETS_A="$SKILL_A/assets/migration"
SPECS_A="$REPO_A/specs/000-migration-template"
SPEC_COPY="$REPO_A/specs/001-migration"
WS_A="$REPO_A/migration-workspace"

if make_fake_repo "$REPO_A" yes; then
    pass "fake repository is created"
else
    fail "fake repository is created"
fi

if generate_repo "$REPO_A" a; then
    pass "generating the kit in the copy succeeds"
else
    fail "generating the kit in the copy succeeds"
    sed -n '1,3p' "$TMP_ROOT/generate-a.txt"
fi

if python3 -I "$GEN_A" --check >"$TMP_ROOT/check-copy.txt" 2>&1; then
    pass "--check passes on the generated copy"
else
    fail "--check passes on the generated copy"
    sed -n '1,3p' "$TMP_ROOT/check-copy.txt"
fi

stamped_missing=0
for stamped in "$ASSETS_A/workspace-folders.txt" "$ASSETS_A/phase-dashboard.template.md" \
    "$ASSETS_A/migration-config.template.json" "$SPECS_A"/001-phase-*/spec.md; do
    stamped_path=$(grep -m1 -o 'Generated by [^ ]*' "$stamped" | cut -d' ' -f3)
    if [[ -z "$stamped_path" ]] || [[ ! -f "$REPO_A/$stamped_path" ]]; then
        stamped_missing=$((stamped_missing + 1))
    fi
done
assert "every generated notice names a generator path that exists from the repository root" test "$stamped_missing" -eq 0

DRIFT_DOC=""
for candidate in "$SPECS_A"/001-phase-*/spec.md; do
    if [[ -f "$candidate" ]]; then
        DRIFT_DOC="$candidate"
        break
    fi
done
if [[ -n "${DRIFT_DOC:-}" ]] && [[ -f "$DRIFT_DOC" ]]; then
    printf 'injected drift\n' >>"$DRIFT_DOC"
    python3 -I "$GEN_A" --check >"$TMP_ROOT/check-drift.txt" 2>&1
    drift_status=$?
    drift_folder=$(basename "$(dirname "$DRIFT_DOC")")
    if [[ "$drift_status" -eq 1 ]] && grep -q "$drift_folder" "$TMP_ROOT/check-drift.txt"; then
        pass "--check fails and names the edited child doc"
    else
        fail "--check fails and names the edited child doc"
        sed -n '1,3p' "$TMP_ROOT/check-drift.txt"
    fi
else
    fail "--check fails and names the edited child doc (no child doc found to edit)"
fi

if python3 -I "$GEN_A" >/dev/null 2>&1 && python3 -I "$GEN_A" --check >/dev/null 2>&1; then
    pass "regenerating the kit repairs the drift"
else
    fail "regenerating the kit repairs the drift"
fi

# WHY: a stray .md file and a stray non-doc file must each be named, since a
# check that reused the markdown-only finder would miss the second.
printf 'stray\n' >"$SPECS_A/stray-note.md"
first_child=$(find "$SPECS_A" -mindepth 1 -maxdepth 1 -type d -name '001-phase-*' | head -1)
printf 'a,b\n' >"$first_child/export.csv"
python3 -I "$GEN_A" --check >"$TMP_ROOT/check-stray.txt" 2>&1
stray_status=$?
if [[ "$stray_status" -eq 1 ]] && grep -q 'stray-note.md' "$TMP_ROOT/check-stray.txt" \
    && grep -q 'export.csv' "$TMP_ROOT/check-stray.txt"; then
    pass "--check fails and names a stray .md file and a stray non-doc file in the packet"
else
    fail "--check fails and names a stray .md file and a stray non-doc file in the packet"
    sed -n '1,3p' "$TMP_ROOT/check-stray.txt"
fi
rm -f "$SPECS_A/stray-note.md" "$first_child/export.csv"

if python3 -I "$GEN_A" --check >/dev/null 2>&1; then
    pass "--check passes again after the stray files are removed"
else
    fail "--check passes again after the stray files are removed"
fi

printf 'finder\n' >"$first_child/.DS_Store"
if python3 -I "$GEN_A" --check >"$TMP_ROOT/check-ds-store.txt" 2>&1; then
    pass "--check ignores a .DS_Store file in a phase packet"
else
    fail "--check ignores a .DS_Store file in a phase packet"
    sed -n '1,3p' "$TMP_ROOT/check-ds-store.txt"
fi
rm -f "$first_child/.DS_Store"

assert "the packet holds 23 child folders" test "$(count_named "$SPECS_A" '^[0-9][0-9][0-9]-phase-')" -eq 23

# ───────────────────────────────────────────────────────────────
# 6. PACKET STRUCTURE, PLACEHOLDERS AND LINK CHECKS
# ───────────────────────────────────────────────────────────────

if python3 -I - "$SPECS_A" "$SKILL_A/references/migration" <<'PY' >"$TMP_ROOT/packet.txt" 2>&1
import os
import re
import sys

packet = sys.argv[1]
refs = sys.argv[2]

errors = []

name_re = re.compile(r"^([0-9]{3})-phase-([0-9]+)-([a-z0-9]+(?:-[a-z0-9]+)*)$")
child_docs = [
    "spec.md",
    "plan.md",
    "tasks.md",
    "acceptance-criteria.md",
    "decision-record.md",
    "implementation-summary.md",
    "goal.md",
]


def slugify(title):
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


children = sorted(
    name
    for name in os.listdir(packet)
    if name_re.match(name) and os.path.isdir(os.path.join(packet, name))
)

if len(children) != 23:
    errors.append("expected 23 child folders, found %d" % len(children))

phases = []
for name in children:
    match = name_re.match(name)
    number = int(match.group(1))
    phase = int(match.group(2))
    if number != phase + 1:
        errors.append("child folder %s does not match phase number plus one" % name)
    phases.append(phase)
    child_dir = os.path.join(packet, name)
    for doc in child_docs:
        if not os.path.isfile(os.path.join(child_dir, doc)):
            errors.append("missing %s/%s" % (name, doc))
    goal_path = os.path.join(child_dir, "goal.md")
    if os.path.isfile(goal_path):
        with open(goal_path, encoding="utf-8") as handle:
            criteria = [line for line in handle if line.startswith("- [ ]")]
        if len(criteria) < 3 or len(criteria) > 7:
            errors.append("%s/goal.md holds %d checklist criteria lines" % (name, len(criteria)))

if phases != list(range(23)):
    errors.append("child phase numbers are not 0 to 22: %s" % ", ".join(str(item) for item in phases))

for doc in ("spec.md", "goal.md"):
    if not os.path.isfile(os.path.join(packet, doc)):
        errors.append("missing parent %s" % doc)

map_rows = []
spec_path = os.path.join(packet, "spec.md")
if os.path.isfile(spec_path):
    with open(spec_path, encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped.startswith("|"):
                continue
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if len(cells) < 4 or not cells[0].isdigit():
                continue
            map_rows.append(cells)

if len(map_rows) != 23:
    errors.append("parent spec.md holds %d phase map rows" % len(map_rows))

map_folders = set()
map_titles = []
for cells in map_rows:
    link = re.search(r"\]\(\./([^)/]+)/spec\.md\)", cells[1])
    if not link:
        errors.append("phase map row without a child packet link: %s" % " | ".join(cells))
        continue
    folder = link.group(1)
    map_folders.add(folder)
    title = cells[2]
    prefix = re.match(r"^Phase\s+([0-9]+)\s*[:\-]\s*(.+)$", title)
    if prefix:
        title = prefix.group(2).strip()
    map_titles.append(title)
    if folder not in children:
        errors.append("phase map points at unknown folder %s" % folder)
        continue
    match = name_re.match(folder)
    if slugify(title) != match.group(3):
        errors.append("phase title '%s' does not slug to folder %s" % (title, folder))
    row_phase = int(match.group(2))
    if int(cells[0]) not in (row_phase, row_phase + 1):
        errors.append("phase map row number %s does not match phase %d" % (cells[0], row_phase))

if len(map_folders) != len(map_rows):
    errors.append("phase map rows repeat child folders")
if sorted(map_folders) != children:
    errors.append("phase map rows and child folders are not the same packets")

parts = []
for root, dirs, files in os.walk(refs):
    for name in sorted(files):
        if name.endswith(".md"):
            with open(os.path.join(root, name), encoding="utf-8", errors="replace") as handle:
                parts.append(handle.read())
reference_text = re.sub(r"\s+", " ", " ".join(parts).lower())

for title in map_titles:
    probe = re.sub(r"\s+", " ", title).strip().lower()
    if probe and probe not in reference_text:
        errors.append("phase title not found in the references: %s" % title)

if errors:
    for item in errors:
        print(item)
    sys.exit(1)
print("packet structure matches the contract with %d child folders" % len(children))
sys.exit(0)
PY
then
    pass "the packet holds 23 exact child packets with every doc and goal criteria"
else
    fail "the packet holds 23 exact child packets with every doc and goal criteria"
    sed -n '1,5p' "$TMP_ROOT/packet.txt"
fi

if grep -rqF '{{' "$SPECS_A" >/dev/null 2>&1; then
    fail "no rendered file contains {{"
    grep -rlF '{{' "$SPECS_A" 2>/dev/null | sed -n '1,3p'
else
    pass "no rendered file contains {{"
fi

if python3 -I - "$SPECS_A" <<'PY' >"$TMP_ROOT/links.txt" 2>&1
import os
import re
import sys

root = sys.argv[1]
pattern = re.compile(r"\]\(\.\./\.\./\.\./sk-moneybird-accountant/references/migration/([^)#]+)")
checked = 0
unresolved = []
children_with_links = set()
children = [
    name
    for name in sorted(os.listdir(root))
    if re.match(r"^[0-9]{3}-phase-", name) and os.path.isdir(os.path.join(root, name))
]
for name in children:
    child_dir = os.path.join(root, name)
    for fname in sorted(os.listdir(child_dir)):
        if not fname.endswith(".md"):
            continue
        path = os.path.join(child_dir, fname)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for target in pattern.findall(text):
            checked += 1
            children_with_links.add(name)
            candidate = os.path.normpath(
                os.path.join(
                    child_dir,
                    "..",
                    "..",
                    "..",
                    "sk-moneybird-accountant",
                    "references",
                    "migration",
                    target,
                )
            )
            if not os.path.isfile(candidate):
                unresolved.append("%s/%s -> %s" % (name, fname, target))

if not checked:
    print("no rewritten reference links found in the child docs")
    sys.exit(1)
missing = [name for name in children if name not in children_with_links]
if missing:
    print("child folders without a rewritten reference link: %s" % ", ".join(missing))
if unresolved:
    for item in sorted(set(unresolved)):
        print("unresolved: %s" % item)
if missing or unresolved:
    sys.exit(1)
sys.exit(0)
PY
then
    pass "every child doc links to an existing reference file through the rewritten path"
else
    fail "every child doc links to an existing reference file through the rewritten path"
    sed -n '1,5p' "$TMP_ROOT/links.txt"
fi

# ───────────────────────────────────────────────────────────────
# 7. CONFIG TEMPLATE CHECK
# ───────────────────────────────────────────────────────────────

group "Config template"

if python3 -I - "$SKILL_A/references/migration/overview-and-setup.md" "$ASSETS_A/migration-config.template.json" <<'PY' >"$TMP_ROOT/config-check.txt" 2>&1
import json
import re
import sys

reference_path = sys.argv[1]
template_path = sys.argv[2]

rows = []
inside = False
with open(reference_path, "r", encoding="utf-8") as handle:
    for line in handle:
        stripped = line.strip()
        if stripped == "## Required `MIGRATION_CONFIG` fields":
            inside = True
            continue
        if inside and stripped.startswith("## "):
            break
        if not inside or not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if cells and cells[0] == "Field":
            continue
        if cells and all(cell and set(cell) <= set("-: ") for cell in cells):
            continue
        rows.append(cells)

expected = []
for cells in rows:
    match = re.search(r"`([^`]+)`", cells[0])
    if not match:
        print("reference row without a backticked field name: %s" % cells[0])
        sys.exit(1)
    expected.append(match.group(1))

with open(template_path, "r", encoding="utf-8") as handle:
    template = json.load(handle)

if not template.get("_generated"):
    print("missing _generated notice")
    sys.exit(1)

fields = template.get("fields", [])
if len(fields) != len(expected):
    print("field count differs: reference %d, template %d" % (len(expected), len(fields)))
    sys.exit(1)

if [entry.get("field") for entry in fields] != expected:
    print("field names or order differ from the reference table")
    sys.exit(1)

bad = []
for entry in fields:
    for key in ("value", "evidence", "approved_by", "approved_on"):
        if entry.get(key) != "PENDING":
            bad.append("%s.%s" % (entry.get("field", "?"), key))
if bad:
    print("values that are not PENDING: %s" % ", ".join(bad))
    sys.exit(1)

sys.exit(0)
PY
then
    pass "config template matches the reference table and every value is PENDING"
else
    fail "config template matches the reference table and every value is PENDING"
    sed -n '1,3p' "$TMP_ROOT/config-check.txt"
fi

# ───────────────────────────────────────────────────────────────
# 8. WORKSPACE CREATION CHECKS
# ───────────────────────────────────────────────────────────────

group "Workspace creation"

if [[ -e "$WS_A" ]] || [[ -L "$WS_A" ]]; then
    fail "no workspace exists before init"
else
    pass "no workspace exists before init"
fi

if [[ -e "$SPEC_COPY" ]] || [[ -L "$SPEC_COPY" ]]; then
    fail "no spec copy exists before init"
else
    pass "no spec copy exists before init"
fi

if "$INIT_A" --dry-run >"$TMP_ROOT/init-dry.txt" 2>&1; then
    pass "init-workspace --dry-run exits 0"
else
    fail "init-workspace --dry-run exits 0"
    sed -n '1,3p' "$TMP_ROOT/init-dry.txt"
fi

if [[ -e "$WS_A" ]] || [[ -L "$WS_A" ]]; then
    fail "init-workspace --dry-run creates no workspace"
else
    pass "init-workspace --dry-run creates no workspace"
fi

if [[ -e "$SPEC_COPY" ]] || [[ -L "$SPEC_COPY" ]]; then
    fail "init-workspace --dry-run creates no spec copy"
else
    pass "init-workspace --dry-run creates no spec copy"
fi

if "$INIT_A" >"$TMP_ROOT/init-run1.txt" 2>&1; then
    pass "init-workspace exits 0"
else
    fail "init-workspace exits 0"
    sed -n '1,3p' "$TMP_ROOT/init-run1.txt"
fi

copied_one=$(summary_value "$TMP_ROOT/init-run1.txt" files_copied)
copied_one=${copied_one:-0}
if [[ "$copied_one" -ge 4 ]]; then
    pass "init-workspace copies the dashboard, the config and the journal files"
else
    fail "init-workspace copies the dashboard, the config and the journal files (copied $copied_one)"
fi

assert "the phase dashboard is copied" test -f "$WS_A/Plans/phase-dashboard.md"

plans_entries=$(find "$WS_A/Plans" -mindepth 1 -maxdepth 1 ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
assert "Plans/ holds only the dashboard" test "$plans_entries" -eq 1

assert "the config template is copied to MIGRATION_CONFIG.json" test -f "$WS_A/MIGRATION_CONFIG.json"
assert "the run journal template is copied" test -f "$WS_A/RunJournal/run-journal-event.template.json"
assert "the empty run journal is created" test -f "$WS_A/RunJournal/run-journal.jsonl"
assert "the run journal is empty" test ! -s "$WS_A/RunJournal/run-journal.jsonl"

missing_folders=0
while IFS= read -r folder || [[ -n "$folder" ]]; do
    case "$folder" in
        "" | "#"*)
            continue
            ;;
    esac
    if [[ ! -d "$WS_A/$folder" ]]; then
        missing_folders=$((missing_folders + 1))
    fi
done < "$ASSETS_A/workspace-folders.txt"
assert "every folder in workspace-folders.txt exists" test "$missing_folders" -eq 0

ws_mode=$(file_mode "$WS_A")
assert "the workspace folder has mode 700" test "$ws_mode" = "700"

(
    cd "$WS_A" || exit 1
    find . -type f
) >"$TMP_ROOT/ws-files.txt" 2>/dev/null
bad_modes=0
while IFS= read -r entry || [[ -n "$entry" ]]; do
    if [[ -z "$entry" ]]; then
        continue
    fi
    if [[ "$(file_mode "$WS_A/$entry")" != "600" ]]; then
        bad_modes=$((bad_modes + 1))
    fi
done <"$TMP_ROOT/ws-files.txt"
assert "every copied workspace file has mode 600" test "$bad_modes" -eq 0

# ───────────────────────────────────────────────────────────────
# 9. SPEC PACKET COPY CHECKS
# ───────────────────────────────────────────────────────────────

group "Spec packet copy"

scratch_count=$(find "$SPEC_COPY" -type d -name scratch | wc -l | tr -d ' ')
assert "the copy holds one scratch folder per packet (24)" test "$scratch_count" -eq 24
# shellcheck disable=SC2016  # $1 expands inside the sh -c child, not here
assert "the copy drops the generated notice" sh -c '! grep -rq "Generated by sk-moneybird-accountant/scripts/generate-plan-kit.py" "$1"' _ "$SPEC_COPY"

spec_copied_one=$(summary_value "$TMP_ROOT/init-run1.txt" spec_files_copied)
spec_copied_one=${spec_copied_one:-0}
template_files=$(count_files "$SPECS_A")
if [[ "$spec_copied_one" -eq "$template_files" ]]; then
    pass "init-workspace copies every spec packet file ($spec_copied_one)"
else
    fail "init-workspace copies every spec packet file (copied $spec_copied_one of $template_files)"
fi

if python3 -I - "$SPECS_A" "$SPEC_COPY" "001-migration" <<'PY' >"$TMP_ROOT/spec-copy.txt" 2>&1
import os
import sys

template = sys.argv[1]
copy_dir = sys.argv[2]
name = sys.argv[3]

errors = []
count = 0
for root, dirs, files in os.walk(template):
    for fname in sorted(files):
        src = os.path.join(root, fname)
        rel = os.path.relpath(src, template)
        dst = os.path.join(copy_dir, rel)
        count += 1
        if not os.path.isfile(dst):
            errors.append("missing copy of %s" % rel)
            continue
        with open(src, "rb") as handle:
            expected = handle.read()
        if rel.endswith(".md") or rel.endswith(".json"):
            expected = expected.replace(b"000-migration-template", name.encode("utf-8"))
            expected = b"".join(
                line for line in expected.splitlines(True)
                if not line.startswith(b"<!-- Generated by sk-moneybird-accountant/scripts/generate-plan-kit.py "))
        with open(dst, "rb") as handle:
            actual = handle.read()
        if actual != expected:
            errors.append("copy differs from the template: %s" % rel)

for root, dirs, files in os.walk(copy_dir):
    for fname in sorted(files):
        if not fname.endswith(".md") and not fname.endswith(".json"):
            continue
        path = os.path.join(root, fname)
        with open(path, "rb") as handle:
            if b"000-migration-template" in handle.read():
                errors.append("stale template name in %s" % os.path.relpath(path, copy_dir))

if not count:
    errors.append("template holds no files")

if errors:
    for item in errors:
        print(item)
    sys.exit(1)
print("copied packet matches the template with the name replaced, %d files" % count)
sys.exit(0)
PY
then
    pass "the copied packet matches the template with the name replaced"
else
    fail "the copied packet matches the template with the name replaced"
    sed -n '1,5p' "$TMP_ROOT/spec-copy.txt"
fi

if python3 -I - "$SPEC_COPY" <<'PY' >"$TMP_ROOT/copy-links.txt" 2>&1
import os
import re
import sys

root = sys.argv[1]
pattern = re.compile(r"\]\(\.\./\.\./\.\./sk-moneybird-accountant/references/migration/([^)#]+)")
checked = 0
unresolved = []
children = [
    name
    for name in sorted(os.listdir(root))
    if re.match(r"^[0-9]{3}-phase-", name) and os.path.isdir(os.path.join(root, name))
]
for name in children:
    child_dir = os.path.join(root, name)
    for fname in sorted(os.listdir(child_dir)):
        if not fname.endswith(".md"):
            continue
        path = os.path.join(child_dir, fname)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        for target in pattern.findall(text):
            checked += 1
            candidate = os.path.normpath(
                os.path.join(
                    child_dir,
                    "..",
                    "..",
                    "..",
                    "sk-moneybird-accountant",
                    "references",
                    "migration",
                    target,
                )
            )
            if not os.path.isfile(candidate):
                unresolved.append("%s/%s -> %s" % (name, fname, target))

if not checked:
    print("no rewritten reference links found in the copied child docs")
    sys.exit(1)
if unresolved:
    for item in sorted(set(unresolved)):
        print("unresolved: %s" % item)
    sys.exit(1)
sys.exit(0)
PY
then
    pass "the copied child docs still resolve their reference links"
else
    fail "the copied child docs still resolve their reference links"
    sed -n '1,5p' "$TMP_ROOT/copy-links.txt"
fi

if "$INIT_A" --spec-name 002-my-books >"$TMP_ROOT/init-run3.txt" 2>&1; then
    pass "init-workspace --spec-name 002-my-books exits 0"
else
    fail "init-workspace --spec-name 002-my-books exits 0"
    sed -n '1,3p' "$TMP_ROOT/init-run3.txt"
fi

assert "specs/002-my-books is created" test -f "$REPO_A/specs/002-my-books/spec.md"

spec_three=$(summary_value "$TMP_ROOT/init-run3.txt" spec_files_copied)
spec_three=${spec_three:-0}
assert "the 002-my-books run copies every packet file" test "$spec_three" -eq "$spec_copied_one"

stale_two=$(find "$REPO_A/specs/002-my-books" -type f \( -name '*.md' -o -name '*.json' \) -exec grep -lF '000-migration-template' {} + 2>/dev/null | wc -l | tr -d ' ')
assert "specs/002-my-books holds no 000-migration-template text" test "$stale_two" -eq 0

# ───────────────────────────────────────────────────────────────
# 10. REPEAT RUN AND EXISTING FILE CHECKS
# ───────────────────────────────────────────────────────────────

group "Repeat runs"

if "$INIT_A" >"$TMP_ROOT/init-run2.txt" 2>&1; then
    pass "a second init-workspace run exits 0"
else
    fail "a second init-workspace run exits 0"
fi

copied_two=$(summary_value "$TMP_ROOT/init-run2.txt" files_copied)
copied_two=${copied_two:-0}
assert "a second run copies 0 workspace files" test "$copied_two" -eq 0

skipped_two=$(summary_value "$TMP_ROOT/init-run2.txt" files_skipped)
skipped_two=${skipped_two:-0}
assert "a second run skips every workspace file" test "$skipped_two" -eq "$copied_one"

spec_copied_two=$(summary_value "$TMP_ROOT/init-run2.txt" spec_files_copied)
spec_copied_two=${spec_copied_two:-0}
assert "a second run copies 0 spec files" test "$spec_copied_two" -eq 0

spec_skipped_two=$(summary_value "$TMP_ROOT/init-run2.txt" spec_files_skipped)
spec_skipped_two=${spec_skipped_two:-0}
assert "a second run skips every spec file" test "$spec_skipped_two" -eq "$spec_copied_one"

group "Existing files"

REPO_D="$TMP_ROOT/repo-d"
if make_fake_repo "$REPO_D" yes; then
    pass "repository for the existing files check is created"
else
    fail "repository for the existing files check is created"
fi
generate_repo "$REPO_D" d
WS_D="$REPO_D/migration-workspace"
mkdir -p "$WS_D"
printf '{"custom": "keep me"}\n' >"$WS_D/MIGRATION_CONFIG.json"
cp "$WS_D/MIGRATION_CONFIG.json" "$TMP_ROOT/custom-config.json"
mkdir -p "$REPO_D/specs/001-migration"
printf 'custom spec\n' >"$REPO_D/specs/001-migration/spec.md"
cp "$REPO_D/specs/001-migration/spec.md" "$TMP_ROOT/custom-spec.md"

if "$REPO_D/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-run-d.txt" 2>&1; then
    pass "init-workspace runs with an existing workspace folder"
else
    fail "init-workspace runs with an existing workspace folder"
fi

assert "a pre-existing MIGRATION_CONFIG.json is left byte-identical" cmp -s "$WS_D/MIGRATION_CONFIG.json" "$TMP_ROOT/custom-config.json"
assert "a pre-existing spec.md is left byte-identical" cmp -s "$REPO_D/specs/001-migration/spec.md" "$TMP_ROOT/custom-spec.md"

spec_skipped_d=$(summary_value "$TMP_ROOT/init-run-d.txt" spec_files_skipped)
spec_skipped_d=${spec_skipped_d:-0}
assert "the pre-existing spec.md is counted as skipped" test "$spec_skipped_d" -eq 1

# ───────────────────────────────────────────────────────────────
# 11. REFUSAL CHECKS
# ───────────────────────────────────────────────────────────────

group "Refusals"

REPO_B="$TMP_ROOT/repo-b"
if make_fake_repo "$REPO_B" yes; then
    pass "repository for the symlink refusal is created"
else
    fail "repository for the symlink refusal is created"
fi
generate_repo "$REPO_B" b
mkdir -p "$TMP_ROOT/symlink-target"
ln -s "$TMP_ROOT/symlink-target" "$REPO_B/migration-workspace"
"$REPO_B/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-symlink.txt" 2>&1
symlink_status=$?
if [[ "$symlink_status" -eq 1 ]]; then
    pass "a symlinked workspace is refused with exit 1"
else
    fail "a symlinked workspace is refused with exit 1 (exit $symlink_status)"
fi
if grep -qi symlink "$TMP_ROOT/init-symlink.txt"; then
    pass "the symlink refusal is explained in one line"
else
    fail "the symlink refusal is explained in one line"
fi
assert "the symlink is left in place" test -L "$REPO_B/migration-workspace"
assert "nothing is written through the symlink" test ! -e "$TMP_ROOT/symlink-target/MIGRATION_CONFIG.json"
assert "no spec copy is written when the workspace is a symlink" test ! -e "$REPO_B/specs/001-migration"

REPO_C="$TMP_ROOT/repo-c"
if make_fake_repo "$REPO_C" no; then
    pass "repository for the ignored refusal is created"
else
    fail "repository for the ignored refusal is created"
fi
printf '/specs/*\n!/specs/000-migration-template/\n' >"$REPO_C/.gitignore"
generate_repo "$REPO_C" c
"$REPO_C/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-not-ignored.txt" 2>&1
not_ignored_status=$?
if [[ "$not_ignored_status" -eq 1 ]]; then
    pass "a workspace that is not git-ignored is refused with exit 1"
else
    fail "a workspace that is not git-ignored is refused with exit 1 (exit $not_ignored_status)"
fi
if grep -qi ignored "$TMP_ROOT/init-not-ignored.txt"; then
    pass "the not-ignored refusal names the ignored rule"
else
    fail "the not-ignored refusal names the ignored rule"
fi
assert "nothing is created when the workspace is not ignored" test ! -e "$REPO_C/migration-workspace"
assert "no spec copy is written when the workspace is not ignored" test ! -e "$REPO_C/specs/001-migration"

REPO_E="$TMP_ROOT/repo-e"
if make_fake_repo "$REPO_E" no; then
    pass "repository for the spec ignore refusal is created"
else
    fail "repository for the spec ignore refusal is created"
fi
printf '/migration-workspace/\n' >"$REPO_E/.gitignore"
generate_repo "$REPO_E" e
"$REPO_E/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-spec-not-ignored.txt" 2>&1
spec_not_ignored_status=$?
if [[ "$spec_not_ignored_status" -eq 1 ]]; then
    pass "a spec target that is not git-ignored is refused with exit 1"
else
    fail "a spec target that is not git-ignored is refused with exit 1 (exit $spec_not_ignored_status)"
fi
if grep -qi ignored "$TMP_ROOT/init-spec-not-ignored.txt"; then
    pass "the spec refusal names the ignored rule"
else
    fail "the spec refusal names the ignored rule"
fi
assert "nothing is written when the spec target is not ignored" test ! -e "$REPO_E/specs/001-migration"
assert "no workspace is written when the spec target is not ignored" test ! -e "$REPO_E/migration-workspace"

REPO_F="$TMP_ROOT/repo-f"
if make_fake_repo "$REPO_F" yes; then
    pass "repository for the spec symlink refusal is created"
else
    fail "repository for the spec symlink refusal is created"
fi
generate_repo "$REPO_F" f
mkdir -p "$TMP_ROOT/spec-link-target"
ln -s "$TMP_ROOT/spec-link-target" "$REPO_F/specs/001-migration"
"$REPO_F/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-spec-symlink.txt" 2>&1
spec_symlink_status=$?
if [[ "$spec_symlink_status" -eq 1 ]]; then
    pass "a symlinked spec target is refused with exit 1"
else
    fail "a symlinked spec target is refused with exit 1 (exit $spec_symlink_status)"
fi
if grep -qi symlink "$TMP_ROOT/init-spec-symlink.txt"; then
    pass "the spec symlink refusal is explained in one line"
else
    fail "the spec symlink refusal is explained in one line"
fi
assert "the spec symlink is left in place" test -L "$REPO_F/specs/001-migration"
assert "nothing is written through the spec symlink" test ! -e "$TMP_ROOT/spec-link-target/spec.md"
assert "no workspace is written when the spec target is a symlink" test ! -e "$REPO_F/migration-workspace"

REPO_H="$TMP_ROOT/repo-h"
if make_fake_repo "$REPO_H" yes; then
    pass "repository for the name refusals is created"
else
    fail "repository for the name refusals is created"
fi
generate_repo "$REPO_H" h
INIT_H="$REPO_H/sk-moneybird-accountant/scripts/init-workspace.sh"

bad_names_wrong=0
for bad in 1-migration 001-Migration 001_migration 001-migration/../x 000-migration-template; do
    case "$bad" in
        000-migration-template)
            reason='must not be 000-migration-template'
            ;;
        *)
            reason='must match'
            ;;
    esac
    "$INIT_H" --spec-name "$bad" >"$TMP_ROOT/init-bad-name.txt" 2>&1
    bad_name_status=$?
    if [[ "$bad_name_status" -ne 1 ]] || ! grep -qF -- "$reason" "$TMP_ROOT/init-bad-name.txt"; then
        printf 'refusal of %s: got exit %s, wanted exit 1 with "%s" in the output\n' "$bad" "$bad_name_status" "$reason"
        bad_names_wrong=$((bad_names_wrong + 1))
    fi
done
assert "invalid and reserved --spec-name values are refused with exit 1 and the reason" test "$bad_names_wrong" -eq 0
assert "a refused name creates no target folder" test ! -e "$REPO_H/specs/1-migration"
assert "a refused name creates no default spec copy" test ! -e "$REPO_H/specs/001-migration"

"$INIT_H" --spec-name >"$TMP_ROOT/init-no-value.txt" 2>&1
no_value_status=$?
if [[ "$no_value_status" -eq 1 ]] && grep -qF -- '--spec-name needs a value' "$TMP_ROOT/init-no-value.txt"; then
    pass "--spec-name without a value is refused with exit 1 and the reason"
else
    fail "--spec-name without a value is refused with exit 1 and the reason (exit $no_value_status)"
    sed -n '1,3p' "$TMP_ROOT/init-no-value.txt"
fi

"$INIT_H" --bogus >"$TMP_ROOT/init-bogus.txt" 2>&1
bogus_status=$?
if [[ "$bogus_status" -eq 1 ]] && grep -qF -- 'unknown argument --bogus' "$TMP_ROOT/init-bogus.txt"; then
    pass "an unknown argument is refused with exit 1 and named"
else
    fail "an unknown argument is refused with exit 1 and named (exit $bogus_status)"
    sed -n '1,3p' "$TMP_ROOT/init-bogus.txt"
fi

# WHY: each missing-kit refusal tells the Operator to run the generator, so the
# path it names must be a file that exists from the repository root.
REPO_G="$TMP_ROOT/repo-g"
hints_wrong=0
for gone in sk-moneybird-accountant/assets/migration \
    sk-moneybird-accountant/assets/migration/workspace-folders.txt \
    sk-moneybird-accountant/assets/migration/migration-config.template.json \
    specs/000-migration-template; do
    rm -rf "$REPO_G"
    make_fake_repo "$REPO_G" yes
    generate_repo "$REPO_G" g
    rm -rf "${REPO_G:?}/$gone"
    "$REPO_G/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-missing-kit.txt" 2>&1
    missing_kit_status=$?
    hint=$(sed -n 's/.*run \(.*generate-plan-kit\.py\) first.*/\1/p' "$TMP_ROOT/init-missing-kit.txt")
    if [[ "$missing_kit_status" -ne 1 ]] || [[ -z "$hint" ]] || [[ ! -f "$REPO_G/$hint" ]]; then
        printf 'missing %s: got exit %s and hint "%s"\n' "$gone" "$missing_kit_status" "$hint"
        hints_wrong=$((hints_wrong + 1))
    fi
done
assert "each missing-kit refusal exits 1 and names a generator that exists" test "$hints_wrong" -eq 0

# ───────────────────────────────────────────────────────────────
# 12. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
