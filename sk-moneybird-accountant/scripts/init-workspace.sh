#!/usr/bin/env bash
# WHY: the workspace holds real finance data, so it lives outside git and every
# template is copied in once and never overwritten.
set -u
umask 077

DRY_RUN=no
case "${1:-}" in
    "")
        ;;
    --dry-run)
        DRY_RUN=yes
        ;;
    -h|--help)
        cat <<'USAGE'
usage: init-workspace.sh [--dry-run]

Create migration-workspace/ at the repository root and copy the generated
templates from assets/migration/ into it. Existing files are never overwritten.
USAGE
        exit 0
        ;;
    *)
        printf 'error: unknown argument %s\n' "$1" >&2
        exit 1
        ;;
esac

if [ "$#" -gt 1 ]; then
    printf 'error: too many arguments\n' >&2
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
SKILL_DIR=$(dirname "$SCRIPT_DIR")
REPO_ROOT=$(dirname "$SKILL_DIR")
SKILL_NAME=$(basename "$SKILL_DIR")

ASSETS="$SKILL_DIR/assets/migration"
FOLDER_LIST="$ASSETS/workspace-folders.txt"
WORKSPACE="$REPO_ROOT/migration-workspace"
WORKSPACE_REL="migration-workspace"

created_folders=0
copied_files=0
skipped_files=0

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

ensure_folder() {
    folder_rel="$1"
    target="$REPO_ROOT/$folder_rel"
    if [ -d "$target" ]; then
        if [ "$DRY_RUN" = yes ]; then
            printf 'dry-run: would skip existing folder %s\n' "$folder_rel"
        fi
        return 0
    fi
    if [ "$DRY_RUN" = yes ]; then
        printf 'dry-run: would create folder %s\n' "$folder_rel"
        created_folders=$((created_folders + 1))
        return 0
    fi
    mkdir -p "$target" || fail "cannot create folder $folder_rel"
    chmod 700 "$target" || fail "cannot set mode 700 on $folder_rel"
    printf 'created folder %s\n' "$folder_rel"
    created_folders=$((created_folders + 1))
}

copy_file() {
    src_rel="$1"
    dst_rel="$2"
    src="$SKILL_DIR/$src_rel"
    dst="$REPO_ROOT/$dst_rel"
    if [ ! -f "$src" ]; then
        fail "missing $SKILL_NAME/$src_rel, run scripts/generate-plan-kit.py first"
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        skipped_files=$((skipped_files + 1))
        if [ "$DRY_RUN" = yes ]; then
            printf 'dry-run: would skip existing %s\n' "$dst_rel"
        fi
        return 0
    fi
    if [ "$DRY_RUN" = yes ]; then
        printf 'dry-run: would copy %s to %s\n' "$src_rel" "$dst_rel"
        copied_files=$((copied_files + 1))
        return 0
    fi
    cp "$src" "$dst" || fail "cannot copy $src_rel to $dst_rel"
    chmod 600 "$dst" || fail "cannot set mode 600 on $dst_rel"
    printf 'copied %s\n' "$dst_rel"
    copied_files=$((copied_files + 1))
}

create_empty_file() {
    rel="$1"
    target="$REPO_ROOT/$rel"
    if [ -e "$target" ] || [ -L "$target" ]; then
        skipped_files=$((skipped_files + 1))
        if [ "$DRY_RUN" = yes ]; then
            printf 'dry-run: would skip existing %s\n' "$rel"
        fi
        return 0
    fi
    if [ "$DRY_RUN" = yes ]; then
        printf 'dry-run: would create empty file %s\n' "$rel"
        copied_files=$((copied_files + 1))
        return 0
    fi
    : > "$target" || fail "cannot create $rel"
    chmod 600 "$target" || fail "cannot set mode 600 on $rel"
    printf 'created empty %s\n' "$rel"
    copied_files=$((copied_files + 1))
}

if [ ! -d "$ASSETS" ]; then
    fail "missing $SKILL_NAME/assets/migration, run scripts/generate-plan-kit.py first"
fi
if [ ! -f "$FOLDER_LIST" ]; then
    fail "missing $SKILL_NAME/assets/migration/workspace-folders.txt, run scripts/generate-plan-kit.py first"
fi

plan_count=0
for plan in "$ASSETS/phases"/phase-[0-9][0-9]-plan.md; do
    if [ -f "$plan" ]; then
        plan_count=$((plan_count + 1))
    fi
done
if [ "$plan_count" -ne 23 ]; then
    fail "assets/migration/phases holds $plan_count phase plans, expected 23, run scripts/generate-plan-kit.py first"
fi

# WHY: a symlinked workspace could redirect writes outside the ignored folder.
if [ -L "$WORKSPACE" ]; then
    fail "$WORKSPACE_REL is a symlink, refusing to run"
fi
if [ -e "$WORKSPACE" ] && [ ! -d "$WORKSPACE" ]; then
    fail "$WORKSPACE_REL exists and is not a folder"
fi

# WHY: the workspace must never be committed, so refuse unless git ignores it.
if ! command -v git >/dev/null 2>&1; then
    fail "git is not available, cannot confirm that $WORKSPACE_REL is ignored"
fi
ignored=no
for probe in "$WORKSPACE_REL" "$WORKSPACE_REL/" "$WORKSPACE_REL/.gitkeep"; do
    if (cd "$REPO_ROOT" && git check-ignore -q "$probe" >/dev/null 2>&1); then
        ignored=yes
        break
    fi
done
if [ "$ignored" != yes ]; then
    fail "$WORKSPACE_REL is not git-ignored, refusing to run"
fi

ensure_folder "$WORKSPACE_REL"

while IFS= read -r folder || [ -n "$folder" ]; do
    case "$folder" in
        "" | "#"*)
            continue
            ;;
        /* | *..*)
            fail "unsafe folder entry in workspace-folders.txt"
            ;;
    esac
    ensure_folder "$WORKSPACE_REL/$folder"
done < "$FOLDER_LIST"

copy_file "assets/migration/migration-config.template.json" "$WORKSPACE_REL/MIGRATION_CONFIG.json"
copy_file "assets/migration/phase-dashboard.template.md" "$WORKSPACE_REL/Plans/phase-dashboard.md"

for plan in "$ASSETS/phases"/phase-[0-9][0-9]-plan.md; do
    plan_name=$(basename "$plan")
    copy_file "assets/migration/phases/$plan_name" "$WORKSPACE_REL/Plans/$plan_name"
done

copy_file "assets/migration/run-journal-event.template.json" "$WORKSPACE_REL/RunJournal/run-journal-event.template.json"
create_empty_file "$WORKSPACE_REL/RunJournal/run-journal.jsonl"

printf 'summary folders_created=%d files_copied=%d files_skipped=%d\n' \
    "$created_folders" "$copied_files" "$skipped_files"
