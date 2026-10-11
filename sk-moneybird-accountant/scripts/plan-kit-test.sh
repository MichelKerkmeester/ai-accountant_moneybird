#!/usr/bin/env bash
# WHY: the kit is only trustworthy when the generated files match the references
# and init-workspace never overwrites existing finance data. This suite proves both.
set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")

if [ "$#" -gt 1 ]; then
    printf 'error: usage: plan-kit-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

GENERATOR="$SKILL_SRC/scripts/generate-plan-kit.py"
if [ ! -f "$GENERATOR" ]; then
    printf 'error: missing scripts/generate-plan-kit.py in the skill folder\n' >&2
    exit 2
fi
if [ ! -f "$SKILL_SRC/scripts/init-workspace.sh" ]; then
    printf 'error: missing scripts/init-workspace.sh in the skill folder\n' >&2
    exit 2
fi
if [ ! -d "$SKILL_SRC/references/migration" ]; then
    printf 'error: missing references/migration in the skill folder\n' >&2
    exit 2
fi

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/plan-kit-test.XXXXXX") || exit 2
mkdir -p "$TMP_ROOT/gitenv"
# WHY: isolate git config so a developer global ignore cannot change the verdicts.
export HOME="$TMP_ROOT/gitenv"
export XDG_CONFIG_HOME="$TMP_ROOT/gitenv/.config"
export GIT_CONFIG_NOSYSTEM=1

cleanup() {
    if [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

passed=0
failed=0

pass() {
    passed=$((passed + 1))
    printf 'PASS %s\n' "$1"
}

fail() {
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
}

group() {
    printf '\n== %s\n' "$1"
}

assert() {
    description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

summary_value() {
    tr ' ' '\n' < "$1" | sed -n "s/^$2=//p" | tail -n 1
}

file_mode() {
    if stat -c '%a' "$1" >/dev/null 2>&1; then
        stat -c '%a' "$1"
    else
        stat -f '%Lp' "$1"
    fi
}

count_named() {
    (
        cd "$1" 2>/dev/null || exit 1
        ls | grep -c "$2"
    ) 2>/dev/null || true
}

make_fake_repo() {
    root="$1"
    ignored="$2"
    mkdir -p "$root/sk-moneybird-accountant" || return 1
    for part in scripts assets references; do
        if [ -e "$SKILL_SRC/$part" ]; then
            cp -R "$SKILL_SRC/$part" "$root/sk-moneybird-accountant/" || return 1
        fi
    done
    if [ "$ignored" = yes ]; then
        printf '/migration-workspace/\n' > "$root/.gitignore" || return 1
    fi
    (
        cd "$root" || exit 1
        git init -q .
    ) || return 1
    return 0
}

group "Real skill folder"

if python3 -I "$GENERATOR" --check >"$TMP_ROOT/check-real.txt" 2>&1; then
    pass "generate-plan-kit.py --check passes on the real skill folder"
else
    fail "generate-plan-kit.py --check passes on the real skill folder"
    sed -n '1,3p' "$TMP_ROOT/check-real.txt"
fi

group "Generated copy"

REPO_A="$TMP_ROOT/repo-a"
if make_fake_repo "$REPO_A" yes; then
    pass "fake repository is created"
else
    fail "fake repository is created"
fi

GEN_A="$REPO_A/sk-moneybird-accountant/scripts/generate-plan-kit.py"
INIT_A="$REPO_A/sk-moneybird-accountant/scripts/init-workspace.sh"
ASSETS_A="$REPO_A/sk-moneybird-accountant/assets/migration"
PHASES_A="$ASSETS_A/phases"
WS_A="$REPO_A/migration-workspace"

if python3 -I "$GEN_A" >"$TMP_ROOT/generate-copy.txt" 2>&1; then
    pass "generating the assets in the copy succeeds"
else
    fail "generating the assets in the copy succeeds"
fi

if python3 -I "$GEN_A" --check >"$TMP_ROOT/check-copy.txt" 2>&1; then
    pass "--check passes on the generated copy"
else
    fail "--check passes on the generated copy"
fi

printf 'injected drift\n' >> "$PHASES_A/phase-05-plan.md"
python3 -I "$GEN_A" --check >"$TMP_ROOT/check-drift.txt" 2>&1
drift_status=$?
if [ "$drift_status" -eq 1 ] && grep -q 'phase-05-plan.md' "$TMP_ROOT/check-drift.txt"; then
    pass "--check fails and names the edited phase plan"
else
    fail "--check fails and names the edited phase plan"
fi

if python3 -I "$GEN_A" >/dev/null 2>&1 && python3 -I "$GEN_A" --check >/dev/null 2>&1; then
    pass "regenerating the assets repairs the drift"
else
    fail "regenerating the assets repairs the drift"
fi

plan_count=$(count_named "$PHASES_A" '^phase-[0-9][0-9]-plan\.md$')
plan_count=${plan_count:-0}
if [ "$plan_count" -eq 23 ]; then
    pass "23 phase plan files exist"
else
    fail "23 phase plan files exist (found $plan_count)"
fi

if [ -f "$PHASES_A/phase-00-plan.md" ] && [ -f "$PHASES_A/phase-22-plan.md" ]; then
    pass "phase-00 and phase-22 plans are present"
else
    fail "phase-00 and phase-22 plans are present"
fi

missing_sections=0
for plan in "$PHASES_A"/phase-*-plan.md; do
    if [ ! -f "$plan" ]; then
        continue
    fi
    for heading in "## Status" "## Goal" "## Nested sub-goals" "## Entry criteria" "## Inputs" "## Owner-tagged actions" "## Tool route" "## Outputs and evidence artifacts" "## Numeric exit gate" "## Stop conditions" "## Rollback or compensation" "## Resume rule" "## Run record"; do
        if ! grep -qxF "$heading" "$plan"; then
            missing_sections=$((missing_sections + 1))
        fi
    done
done
if [ "$missing_sections" -eq 0 ]; then
    pass "every phase plan holds the 11 contract sections, Status and Run record"
else
    fail "every phase plan holds the 11 contract sections, Status and Run record (missing $missing_sections)"
fi

group "Config template"

if python3 -I - "$REPO_A/sk-moneybird-accountant/references/migration/overview-and-setup.md" "$ASSETS_A/migration-config.template.json" <<'PY' >"$TMP_ROOT/config-check.txt" 2>&1
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

group "Workspace creation"

if [ -e "$WS_A" ] || [ -L "$WS_A" ]; then
    fail "no workspace exists before init"
else
    pass "no workspace exists before init"
fi

if "$INIT_A" --dry-run >"$TMP_ROOT/init-dry.txt" 2>&1; then
    pass "init-workspace --dry-run exits 0"
else
    fail "init-workspace --dry-run exits 0"
    sed -n '1,3p' "$TMP_ROOT/init-dry.txt"
fi

if [ -e "$WS_A" ] || [ -L "$WS_A" ]; then
    fail "init-workspace --dry-run creates nothing"
else
    pass "init-workspace --dry-run creates nothing"
fi

if "$INIT_A" >"$TMP_ROOT/init-run1.txt" 2>&1; then
    pass "init-workspace exits 0"
else
    fail "init-workspace exits 0"
    sed -n '1,3p' "$TMP_ROOT/init-run1.txt"
fi

copied_one=$(summary_value "$TMP_ROOT/init-run1.txt" files_copied)
copied_one=${copied_one:-0}
if [ "$copied_one" -ge 25 ]; then
    pass "init-workspace copies the plans, the dashboard, the config and the journal files"
else
    fail "init-workspace copies the plans, the dashboard, the config and the journal files (copied $copied_one)"
fi

ws_plans=$(count_named "$WS_A/Plans" '^phase-[0-9][0-9]-plan\.md$')
ws_plans=${ws_plans:-0}
assert "23 phase plans are copied into Plans/" test "$ws_plans" -eq 23
assert "the phase dashboard is copied" test -f "$WS_A/Plans/phase-dashboard.md"
assert "the config template is copied to MIGRATION_CONFIG.json" test -f "$WS_A/MIGRATION_CONFIG.json"
assert "the run journal template is copied" test -f "$WS_A/RunJournal/run-journal-event.template.json"
assert "the empty run journal is created" test -f "$WS_A/RunJournal/run-journal.jsonl"
assert "the run journal is empty" test ! -s "$WS_A/RunJournal/run-journal.jsonl"

missing_folders=0
while IFS= read -r folder || [ -n "$folder" ]; do
    case "$folder" in
        "" | "#"*)
            continue
            ;;
    esac
    if [ ! -d "$WS_A/$folder" ]; then
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
while IFS= read -r entry || [ -n "$entry" ]; do
    if [ -z "$entry" ]; then
        continue
    fi
    if [ "$(file_mode "$WS_A/$entry")" != "600" ]; then
        bad_modes=$((bad_modes + 1))
    fi
done <"$TMP_ROOT/ws-files.txt"
assert "every copied workspace file has mode 600" test "$bad_modes" -eq 0

if "$INIT_A" >"$TMP_ROOT/init-run2.txt" 2>&1; then
    pass "a second init-workspace run exits 0"
else
    fail "a second init-workspace run exits 0"
fi

copied_two=$(summary_value "$TMP_ROOT/init-run2.txt" files_copied)
copied_two=${copied_two:-0}
if [ "$copied_two" -eq 0 ]; then
    pass "a second run copies 0 files"
else
    fail "a second run copies 0 files (copied $copied_two)"
fi

skipped_two=$(summary_value "$TMP_ROOT/init-run2.txt" files_skipped)
skipped_two=${skipped_two:-0}
if [ "$skipped_two" -eq "$copied_one" ]; then
    pass "a second run skips every file"
else
    fail "a second run skips every file (skipped $skipped_two, first run copied $copied_one)"
fi

group "Existing files"

REPO_D="$TMP_ROOT/repo-d"
if make_fake_repo "$REPO_D" yes; then
    pass "second fake repository is created"
else
    fail "second fake repository is created"
fi
WS_D="$REPO_D/migration-workspace"
mkdir -p "$WS_D"
printf '{"custom": "keep me"}\n' >"$WS_D/MIGRATION_CONFIG.json"
cp "$WS_D/MIGRATION_CONFIG.json" "$TMP_ROOT/custom-config.json"

if "$REPO_D/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-run-d.txt" 2>&1; then
    pass "init-workspace runs with an existing workspace folder"
else
    fail "init-workspace runs with an existing workspace folder"
fi

assert "a pre-existing MIGRATION_CONFIG.json is left byte-identical" cmp -s "$WS_D/MIGRATION_CONFIG.json" "$TMP_ROOT/custom-config.json"

group "Refusals"

REPO_B="$TMP_ROOT/repo-b"
if make_fake_repo "$REPO_B" yes; then
    pass "third fake repository is created"
else
    fail "third fake repository is created"
fi
mkdir -p "$TMP_ROOT/symlink-target"
ln -s "$TMP_ROOT/symlink-target" "$REPO_B/migration-workspace"
"$REPO_B/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-symlink.txt" 2>&1
symlink_status=$?
if [ "$symlink_status" -ne 0 ]; then
    pass "a symlinked workspace is refused"
else
    fail "a symlinked workspace is refused"
fi
if grep -qi symlink "$TMP_ROOT/init-symlink.txt"; then
    pass "the symlink refusal is explained in one line"
else
    fail "the symlink refusal is explained in one line"
fi
assert "the symlink is left in place" test -L "$REPO_B/migration-workspace"
assert "nothing is written through the symlink" test ! -e "$TMP_ROOT/symlink-target/MIGRATION_CONFIG.json"

REPO_C="$TMP_ROOT/repo-c"
if make_fake_repo "$REPO_C" no; then
    pass "fourth fake repository is created"
else
    fail "fourth fake repository is created"
fi
"$REPO_C/sk-moneybird-accountant/scripts/init-workspace.sh" >"$TMP_ROOT/init-not-ignored.txt" 2>&1
not_ignored_status=$?
if [ "$not_ignored_status" -ne 0 ]; then
    pass "a workspace that is not git-ignored is refused"
else
    fail "a workspace that is not git-ignored is refused"
fi
assert "nothing is created when the workspace is not ignored" test ! -e "$REPO_C/migration-workspace"

group "Reference links"

if python3 -I - "$PHASES_A" <<'PY' >"$TMP_ROOT/links.txt" 2>&1
import os
import re
import sys

phases_dir = sys.argv[1]
pattern = re.compile(r"\]\(\.\./\.\./\.\./references/migration/([^)#]+)")
checked = 0
unresolved = []
for name in sorted(os.listdir(phases_dir)):
    if not (name.startswith("phase-") and name.endswith("-plan.md")):
        continue
    with open(os.path.join(phases_dir, name), "r", encoding="utf-8") as handle:
        text = handle.read()
    for target in pattern.findall(text):
        checked += 1
        candidate = os.path.normpath(
            os.path.join(phases_dir, "..", "..", "..", "references", "migration", target)
        )
        if not os.path.isfile(candidate):
            unresolved.append("%s -> %s" % (name, target))

if not checked:
    print("no rewritten reference links found in the generated plans")
    sys.exit(1)
if unresolved:
    for item in sorted(set(unresolved)):
        print("unresolved: %s" % item)
    sys.exit(1)
sys.exit(0)
PY
then
    pass "every link that points into ../../../references/migration/ resolves"
else
    fail "every link that points into ../../../references/migration/ resolves"
    sed -n '1,5p' "$TMP_ROOT/links.txt"
fi

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [ "$failed" -gt 0 ]; then
    exit 1
fi
exit 0
