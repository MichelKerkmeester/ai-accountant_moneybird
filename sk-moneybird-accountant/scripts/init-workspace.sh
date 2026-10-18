#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: INIT WORKSPACE
# ───────────────────────────────────────────────────────────────
# Creates the git-ignored migration workspace and copies the templates into it
# without overwriting any file.
# Usage: init-workspace.sh [--dry-run] [--spec-name <NNN-slug>]
# Exit Codes:
#   0 - Success
#   1 - Validation or safety check failed
#
# WHY: the workspace holds real finance data, so it lives outside git and every
# template is copied in once and never overwritten.
set -euo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SETUP
# ───────────────────────────────────────────────────────────────

umask 077

# ───────────────────────────────────────────────────────────────
# 2. UTILITY FUNCTIONS
# ───────────────────────────────────────────────────────────────

# Print an error message and stop the run
# Args:
#   $1 - Error message to print
# Returns:
#   Never returns, the script exits with code 1
fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

# Print the command line usage text
# Args:
#   None
# Returns:
#   0 after the usage text is written
usage() {
    cat <<'USAGE'
usage: init-workspace.sh [--dry-run] [--spec-name <NNN-slug>]

Create migration-workspace/ at the repository root and copy the generated
templates from assets/migration/ into it. Copy the spec packet template from
specs/000-migration-template/ to specs/<NNN-slug>/. Existing files are never
overwritten.
USAGE
}

# ───────────────────────────────────────────────────────────────
# 3. ARGUMENT PARSING
# ───────────────────────────────────────────────────────────────

DRY_RUN=no
SPEC_NAME=001-migration

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=yes
            shift
            ;;
        --spec-name)
            if [[ "$#" -lt 2 ]]; then
                fail "--spec-name needs a value"
            fi
            SPEC_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'error: unknown argument %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

case "$SPEC_NAME" in
    000-migration-template)
        fail "--spec-name must not be 000-migration-template, that name belongs to the template packet"
        ;;
esac

if ! printf '%s\n' "$SPEC_NAME" | grep -Eq '^[0-9]{3}-[a-z0-9][a-z0-9-]*$'; then
    fail "--spec-name must match ^[0-9]{3}-[a-z0-9][a-z0-9-]*$"
fi

# ───────────────────────────────────────────────────────────────
# 4. CONFIGURATION
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
SKILL_DIR=$(dirname "$SCRIPT_DIR")
REPO_ROOT=$(dirname "$SKILL_DIR")
SKILL_NAME=$(basename "$SKILL_DIR")

ASSETS="$SKILL_DIR/assets/migration"
FOLDER_LIST="$ASSETS/workspace-folders.txt"
WORKSPACE="$REPO_ROOT/migration-workspace"
WORKSPACE_REL="migration-workspace"
SPEC_TEMPLATE="$REPO_ROOT/specs/000-migration-template"
SPEC_TEMPLATE_REL="specs/000-migration-template"
SPEC_DIR="$REPO_ROOT/specs/$SPEC_NAME"
SPEC_DIR_REL="specs/$SPEC_NAME"

created_folders=0
copied_files=0
skipped_files=0
spec_files_copied=0
spec_files_skipped=0

# ───────────────────────────────────────────────────────────────
# 5. FILESYSTEM HELPERS
# ───────────────────────────────────────────────────────────────

# Create a workspace folder with owner-only permissions
# Args:
#   $1 - Folder path relative to the repository root
# Returns:
#   0 when the folder already exists or is created
ensure_folder() {
    local folder_rel="$1"
    local target="$REPO_ROOT/$folder_rel"
    if [[ -d "$target" ]]; then
        if [[ "$DRY_RUN" = yes ]]; then
            printf 'dry-run: would skip existing folder %s\n' "$folder_rel"
        fi
        return 0
    fi
    if [[ "$DRY_RUN" = yes ]]; then
        printf 'dry-run: would create folder %s\n' "$folder_rel"
        created_folders=$((created_folders + 1))
        return 0
    fi
    mkdir -p "$target" || fail "cannot create folder $folder_rel"
    chmod 700 "$target" || fail "cannot set mode 700 on $folder_rel"
    printf 'created folder %s\n' "$folder_rel"
    created_folders=$((created_folders + 1))
}

# Copy one generated template into the workspace without overwriting
# Args:
#   $1 - Source path relative to the skill directory
#   $2 - Destination path relative to the repository root
# Returns:
#   0 when the file is copied or already present
copy_file() {
    local src_rel="$1"
    local dst_rel="$2"
    local src="$SKILL_DIR/$src_rel"
    local dst="$REPO_ROOT/$dst_rel"
    if [[ ! -f "$src" ]]; then
        fail "missing $SKILL_NAME/$src_rel, run $SKILL_NAME/scripts/generate-plan-kit.py first"
    fi
    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
        skipped_files=$((skipped_files + 1))
        if [[ "$DRY_RUN" = yes ]]; then
            printf 'dry-run: would skip existing %s\n' "$dst_rel"
        fi
        return 0
    fi
    if [[ "$DRY_RUN" = yes ]]; then
        printf 'dry-run: would copy %s to %s\n' "$src_rel" "$dst_rel"
        copied_files=$((copied_files + 1))
        return 0
    fi
    cp "$src" "$dst" || fail "cannot copy $src_rel to $dst_rel"
    chmod 600 "$dst" || fail "cannot set mode 600 on $dst_rel"
    printf 'copied %s\n' "$dst_rel"
    copied_files=$((copied_files + 1))
}

# Create an empty placeholder file when it is not present
# Args:
#   $1 - File path relative to the repository root
# Returns:
#   0 when the file is created or already present
create_empty_file() {
    local rel="$1"
    local target="$REPO_ROOT/$rel"
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        skipped_files=$((skipped_files + 1))
        if [[ "$DRY_RUN" = yes ]]; then
            printf 'dry-run: would skip existing %s\n' "$rel"
        fi
        return 0
    fi
    if [[ "$DRY_RUN" = yes ]]; then
        printf 'dry-run: would create empty file %s\n' "$rel"
        copied_files=$((copied_files + 1))
        return 0
    fi
    : > "$target" || fail "cannot create $rel"
    chmod 600 "$target" || fail "cannot set mode 600 on $rel"
    printf 'created empty %s\n' "$rel"
    copied_files=$((copied_files + 1))
}

# Report whether git ignores a path
# Args:
#   $1 - Path relative to the repository root
# Returns:
#   0 when git ignores the path, 1 when it does not
is_ignored() {
    local check_rel="$1"
    local probe
    for probe in "$check_rel" "$check_rel/" "$check_rel/.gitkeep"; do
        if (cd "$REPO_ROOT" && git check-ignore -q "$probe" >/dev/null 2>&1); then
            return 0
        fi
    done
    return 1
}

# ───────────────────────────────────────────────────────────────
# 6. PREFLIGHT VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ ! -d "$ASSETS" ]]; then
    fail "missing $SKILL_NAME/assets/migration, run $SKILL_NAME/scripts/generate-plan-kit.py first"
fi
if [[ ! -f "$FOLDER_LIST" ]]; then
    fail "missing $SKILL_NAME/assets/migration/workspace-folders.txt, run $SKILL_NAME/scripts/generate-plan-kit.py first"
fi

# WHY: a symlinked workspace could redirect writes outside the ignored folder.
if [[ -L "$WORKSPACE" ]]; then
    fail "$WORKSPACE_REL is a symlink, refusing to run"
fi
if [[ -e "$WORKSPACE" ]] && [[ ! -d "$WORKSPACE" ]]; then
    fail "$WORKSPACE_REL exists and is not a folder"
fi

# WHY: a symlinked spec folder could redirect writes outside the ignored folder.
if [[ -L "$SPEC_DIR" ]]; then
    fail "$SPEC_DIR_REL is a symlink, refusing to run"
fi
if [[ -e "$SPEC_DIR" ]] && [[ ! -d "$SPEC_DIR" ]]; then
    fail "$SPEC_DIR_REL exists and is not a folder"
fi

# WHY: the workspace and the spec packet must never be committed, so refuse
# unless git ignores both targets.
if ! command -v git >/dev/null 2>&1; then
    fail "git is not available, cannot confirm that $WORKSPACE_REL and $SPEC_DIR_REL are ignored"
fi
if ! is_ignored "$WORKSPACE_REL"; then
    fail "$WORKSPACE_REL is not git-ignored, refusing to run"
fi
if ! is_ignored "$SPEC_DIR_REL"; then
    fail "$SPEC_DIR_REL is not git-ignored, refusing to run"
fi

if [[ ! -d "$SPEC_TEMPLATE" ]]; then
    fail "missing $SPEC_TEMPLATE_REL, run $SKILL_NAME/scripts/generate-plan-kit.py first"
fi

# ───────────────────────────────────────────────────────────────
# 7. WORKSPACE CREATION
# ───────────────────────────────────────────────────────────────

ensure_folder "$WORKSPACE_REL"

while IFS= read -r folder || [[ -n "$folder" ]]; do
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
copy_file "assets/migration/run-journal-event.template.json" "$WORKSPACE_REL/RunJournal/run-journal-event.template.json"
create_empty_file "$WORKSPACE_REL/RunJournal/run-journal.jsonl"

# ───────────────────────────────────────────────────────────────
# 8. SPEC FOLDER CREATION
# ───────────────────────────────────────────────────────────────

if [[ ! -d "$SPEC_DIR" ]]; then
    if [[ "$DRY_RUN" = yes ]]; then
        printf 'dry-run: would create folder %s\n' "$SPEC_DIR_REL"
        created_folders=$((created_folders + 1))
    else
        mkdir "$SPEC_DIR" || fail "cannot create folder $SPEC_DIR_REL"
        chmod 700 "$SPEC_DIR" || fail "cannot set mode 700 on $SPEC_DIR_REL"
        printf 'created folder %s\n' "$SPEC_DIR_REL"
        created_folders=$((created_folders + 1))
    fi
fi

# ───────────────────────────────────────────────────────────────
# 9. SPEC PACKET COPY
# ───────────────────────────────────────────────────────────────

# WHY: the packet is copied once and the template name inside every doc must
# point at the new folder, without ever touching an existing file.
while IFS= read -r src_path || [[ -n "$src_path" ]]; do
    if [[ "$src_path" = "$SPEC_TEMPLATE" ]]; then
        continue
    fi
    rel="${src_path#"$SPEC_TEMPLATE"/}"
    src_rel="$SPEC_TEMPLATE_REL/$rel"
    dst_rel="$SPEC_DIR_REL/$rel"
    dst_path="$SPEC_DIR/$rel"
    if [[ -d "$src_path" ]]; then
        if [[ -L "$dst_path" ]]; then
            fail "$dst_rel is a symlink, refusing to run"
        fi
        if [[ -e "$dst_path" ]] && [[ ! -d "$dst_path" ]]; then
            fail "$dst_rel exists and is not a folder"
        fi
        if [[ -d "$dst_path" ]]; then
            continue
        fi
        if [[ "$DRY_RUN" = yes ]]; then
            printf 'dry-run: would create folder %s\n' "$dst_rel"
            created_folders=$((created_folders + 1))
            continue
        fi
        mkdir "$dst_path" || fail "cannot create folder $dst_rel"
        chmod 700 "$dst_path" || fail "cannot set mode 700 on $dst_rel"
        printf 'created folder %s\n' "$dst_rel"
        created_folders=$((created_folders + 1))
        continue
    fi
    if [[ -e "$dst_path" ]] || [[ -L "$dst_path" ]]; then
        spec_files_skipped=$((spec_files_skipped + 1))
        if [[ "$DRY_RUN" = yes ]]; then
            printf 'dry-run: would skip existing %s\n' "$dst_rel"
        fi
        continue
    fi
    if [[ "$DRY_RUN" = yes ]]; then
        printf 'dry-run: would copy %s to %s\n' "$src_rel" "$dst_rel"
        spec_files_copied=$((spec_files_copied + 1))
        continue
    fi
    case "$rel" in
        *.md|*.json)
            # WHY: the generated notice is true for the template only. The
            # working copy belongs to the Operator and is edited by hand.
            sed -e "s|000-migration-template|$SPEC_NAME|g" \
                -e '/^<!-- Generated by sk-moneybird-accountant\/scripts\/generate-plan-kit.py /d' \
                "$src_path" >"$dst_path" \
                || fail "cannot copy $src_rel to $dst_rel"
            ;;
        *)
            cp "$src_path" "$dst_path" || fail "cannot copy $src_rel to $dst_rel"
            ;;
    esac
    chmod 600 "$dst_path" || fail "cannot set mode 600 on $dst_rel"
    printf 'copied %s\n' "$dst_rel"
    spec_files_copied=$((spec_files_copied + 1))
done < <(find "$SPEC_TEMPLATE" \( -type d -o -type f \) -print | sort)

# ───────────────────────────────────────────────────────────────
# 10. SCRATCH FOLDERS
# ───────────────────────────────────────────────────────────────

# WHY: the template tracks no empty folders, and every spec-kit packet keeps a
# scratch/ folder for working notes.
while IFS= read -r spec_doc || [[ -n "$spec_doc" ]]; do
    packet_rel="${spec_doc#"$SPEC_TEMPLATE"}"
    packet_rel="${packet_rel%spec.md}"
    scratch_rel="$SPEC_DIR_REL${packet_rel}scratch"
    scratch_path="$SPEC_DIR${packet_rel}scratch"
    if [[ -L "$scratch_path" ]]; then
        fail "$scratch_rel is a symlink, refusing to run"
    fi
    if [[ -d "$scratch_path" ]]; then
        continue
    fi
    if [[ -e "$scratch_path" ]]; then
        fail "$scratch_rel exists and is not a folder"
    fi
    if [[ "$DRY_RUN" = yes ]]; then
        printf 'dry-run: would create folder %s\n' "$scratch_rel"
        created_folders=$((created_folders + 1))
        continue
    fi
    mkdir "$scratch_path" || fail "cannot create folder $scratch_rel"
    chmod 700 "$scratch_path" || fail "cannot set mode 700 on $scratch_rel"
    printf 'created folder %s\n' "$scratch_rel"
    created_folders=$((created_folders + 1))
done < <(find "$SPEC_TEMPLATE" -type f -name spec.md -print | sort)

# ───────────────────────────────────────────────────────────────
# 11. SUMMARY
# ───────────────────────────────────────────────────────────────

printf 'summary folders_created=%d files_copied=%d files_skipped=%d spec_files_copied=%d spec_files_skipped=%d\n' \
    "$created_folders" "$copied_files" "$skipped_files" "$spec_files_copied" "$spec_files_skipped"
