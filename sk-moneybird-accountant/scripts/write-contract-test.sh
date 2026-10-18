#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: WRITE CONTRACT TEST
# ───────────────────────────────────────────────────────────────
# Tests write-contract-check.py on the real tree, on a clean copy and on twelve
# seeded divergences: a safety line without --confirm-write, a missing pointer,
# a forbidden flag on the accountant SKILL.md pointer line, a gate token and an
# evidence rule that leave the accountant ROUTER.md while its SKILL.md still
# names them, a missing idempotency rule, a missing exit 9, a second differing
# read-back sentence, a --production without its batch condition, the same
# flag without its backticks, an evidence rule gone from the AGENTS.md contract
# paragraph and an unknown exit named in another wording. Every seeded
# divergence must fail the check and name its file.
# Usage: write-contract-test.sh [repo root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing contract files
#
# WHY: the drift check is only trustworthy when it fails on the divergences
# the contract review found, so this suite seeds each one on a throwaway copy.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND CONTRACT VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: write-contract-test.sh [repo root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

CHECKER="$REPO_SRC/sk-moneybird-accountant/scripts/write-contract-check.py"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/write-contract-check.py in the repository\n' >&2
    exit 2
fi

CONTRACT_FILES=(
    "AGENTS.md"
    "sk-moneybird-accountant/SKILL.md"
    "sk-moneybird-accountant/ROUTER.md"
    "sk-moneybird-accountant/references/migration/shared-mechanisms.md"
    "cli-moneybird/SKILL.md"
    "cli-moneybird/cli/moneybird-cli/moneybird-guard"
)
for relative in "${CONTRACT_FILES[@]}"; do
    if [[ ! -f "$REPO_SRC/$relative" ]]; then
        printf 'error: missing %s in the repository\n' "$relative" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/write-contract-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 4. TEST HELPERS AND COPY BUILDERS
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

# Build a copy of the five contract files under a fresh root
# Args:
#   $1 - Target root to create
# Returns:
#   0 when every file is copied, 1 otherwise
make_copy() {
    local root="$1"
    local relative
    for relative in "${CONTRACT_FILES[@]}"; do
        mkdir -p "$root/$(dirname "$relative")" || return 1
        cp "$REPO_SRC/$relative" "$root/$relative" || return 1
    done
    return 0
}

# Run the drift check against a copy and capture its output
# Args:
#   $1 - Repository root to check
#   $2 - Tag for the captured output file under the temp root
# Returns:
#   The checker exit status
run_checker() {
    python3 -I "$CHECKER" --root "$1" >"$TMP_ROOT/check-$2.txt" 2>&1
}

# Replace every occurrence of a text in one file
# Args:
#   $1 - File to edit
#   $2 - Text to remove
#   $3 - Text to insert
replace_all() {
    python3 -I - "$1" "$2" "$3" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace(sys.argv[2], sys.argv[3]), encoding="utf-8")
PY
}

# Seed one divergence in a fresh copy and require the checker to fail
# Args:
#   $1 - Check description
#   $2 - File relative to the copy root
#   $3 - Text to remove
#   $4 - Text to insert
#   $5 - Tag for the copy and the captured output
seed_failure() {
    local description="$1"
    local relative="$2"
    local old_text="$3"
    local new_text="$4"
    local tag="$5"
    local root="$TMP_ROOT/seed-$tag"
    if ! make_copy "$root"; then
        fail "$description (the copy could not be built)"
        return
    fi
    replace_all "$root/$relative" "$old_text" "$new_text"
    run_checker "$root" "$tag"
    local status=$?
    if [[ "$status" -eq 0 ]]; then
        fail "$description"
        sed -n '1,3p' "$TMP_ROOT/check-$tag.txt"
        return
    fi
    if ! grep -qF "$relative" "$TMP_ROOT/check-$tag.txt"; then
        fail "$description (the report does not name $relative)"
        sed -n '1,3p' "$TMP_ROOT/check-$tag.txt"
        return
    fi
    pass "$description"
}

# ───────────────────────────────────────────────────────────────
# 5. REAL TREE AND CLEAN COPY CHECKS
# ───────────────────────────────────────────────────────────────

group "Real tree"

if run_checker "$REPO_SRC" real && grep -qF 'write-contract: ok' "$TMP_ROOT/check-real.txt"; then
    pass "the drift check passes on the real tree"
else
    fail "the drift check passes on the real tree"
    sed -n '1,3p' "$TMP_ROOT/check-real.txt"
fi

group "Clean copy"

CLEAN_ROOT="$TMP_ROOT/clean"
if make_copy "$CLEAN_ROOT"; then
    pass "the clean copy is created"
else
    fail "the clean copy is created"
fi

if run_checker "$CLEAN_ROOT" clean && grep -qF 'write-contract: ok' "$TMP_ROOT/check-clean.txt"; then
    pass "the drift check passes on the clean copy"
else
    fail "the drift check passes on the clean copy"
    sed -n '1,3p' "$TMP_ROOT/check-clean.txt"
fi

# ───────────────────────────────────────────────────────────────
# 6. SEEDED DIVERGENCE CHECKS
# ───────────────────────────────────────────────────────────────

group "Seeded divergences"

seed_failure "a safety line without --confirm-write fails" \
    "AGENTS.md" '--confirm-write' '' confirm

seed_failure "a missing pointer fails" \
    "sk-moneybird-accountant/ROUTER.md" 'shared-mechanisms.md#route-contract' 'shared-mechanisms.md' pointer

seed_failure "a forbidden flag on the accountant SKILL.md pointer line fails" \
    "sk-moneybird-accountant/SKILL.md" 'for every non-GET batch. See the' 'for every non-GET batch, even with `--force-write`. See the' forceflag

seed_failure "a gate token gone from ROUTER.md fails while SKILL.md still names it" \
    "sk-moneybird-accountant/ROUTER.md" '`MONEYBIRD_GUARD_READ_ONLY=1`' '`MONEYBIRD_GUARD=1`' routertoken

seed_failure "an evidence rule gone from ROUTER.md fails while SKILL.md still names evidence" \
    "sk-moneybird-accountant/ROUTER.md" 'the evidence rule, ' '' routerevidence

seed_failure "a missing idempotency rule fails" \
    "cli-moneybird/SKILL.md" 'idempotency' 'consistency' idempotency

seed_failure "a missing exit 9 fails" \
    "cli-moneybird/SKILL.md" 'exit 9' 'exit 8' exit9

seed_failure "a second differing read-back sentence fails" \
    "cli-moneybird/SKILL.md" 'Read-back follows the canonical read-back sentence in the write contract' 'Read-back is a direct GET after the write' readback

seed_failure "a production flag without its batch condition fails" \
    "sk-moneybird-accountant/ROUTER.md" 'and `--approval`, with `--production` only for an approved production batch.' ', `--approval` and `--production`.' production

seed_failure "a production flag without backticks or its batch condition fails" \
    "sk-moneybird-accountant/ROUTER.md" 'and `--approval`, with `--production` only for an approved production batch.' ', `--approval` and --production.' productionbare

seed_failure "an evidence rule gone from the AGENTS.md contract paragraph fails while other lines name evidence" \
    "AGENTS.md" 'The gate tokens, the evidence rule, ' 'The gate tokens, ' agentsevidence

seed_failure "an exit named in another wording outside the canonical set fails" \
    "cli-moneybird/SKILL.md" 'Read-back follows the canonical read-back sentence in the write contract' 'Read-back follows the canonical read-back sentence in the write contract, and a refused write exits with status 99' exitwording

python3 -I "$CHECKER" --root "$TMP_ROOT/no-such-root" >"$TMP_ROOT/check-noroot.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]] && grep -qF 'error:' "$TMP_ROOT/check-noroot.txt"; then
    pass "a missing root is refused with exit 2"
else
    fail "a missing root is refused with exit 2"
fi

# ───────────────────────────────────────────────────────────────
# 7. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
