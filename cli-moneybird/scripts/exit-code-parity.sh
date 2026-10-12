#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: EXIT CODE PARITY
# ───────────────────────────────────────────────────────────────
# Checks the guard die exit codes against the documentation surfaces.
# Usage: exit-code-parity.sh [--root DIR]
# Exit Codes:
#   0 - Every guard code, and only guard codes, appear on every surface
#   1 - A surface misses a guard code or names a code the guard never emits
#   2 - Invalid arguments or missing input files
#
# WHY: the guard is the source of truth for its own exit codes, so a surface that
# drifts from it sends an agent down the wrong recovery path. This check compares
# the guard with the exit table, the troubleshooting rows, the TROUBLESHOOT
# keywords and the section 3 gate ladder in one offline pass.
# WHY: the code comparison goes both ways and uses the numbers each surface names,
# so a wide code such as 100 is caught just like a narrow one.
# WHY: the script reads files only. It never calls the CLI and never opens a credential file.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 2
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd -P) || exit 2

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND ROOT VALIDATION
# ───────────────────────────────────────────────────────────────

ROOT_ARG=""
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "--root" ]]; then
        if [[ "$#" -lt 2 ]]; then
            printf 'error: usage: exit-code-parity.sh [--root DIR]\n' >&2
            exit 2
        fi
        ROOT_ARG="$2"
        shift 2
    else
        printf 'error: usage: exit-code-parity.sh [--root DIR]\n' >&2
        exit 2
    fi
done

ROOT="${ROOT_ARG:-$DEFAULT_ROOT}"
if ! ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P); then
    printf 'error: root folder not found\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 3. INPUT FILES
# ───────────────────────────────────────────────────────────────

GUARD=""
for candidate in \
    "$ROOT/cli-moneybird/cli/moneybird-cli/bin/moneybird-guard" \
    "$ROOT/cli-moneybird/cli/moneybird-cli/moneybird-guard"; do
    if [[ -f "$candidate" ]]; then
        GUARD="$candidate"
        break
    fi
done
if [[ -z "$GUARD" ]]; then
    printf 'error: missing moneybird-guard under %s\n' "$ROOT" >&2
    exit 2
fi

CLI_DOC="$ROOT/cli-moneybird/references/cli.md"
TROUBLESHOOTING_DOC="$ROOT/cli-moneybird/references/troubleshooting.md"
SKILL_DOC="$ROOT/cli-moneybird/SKILL.md"

missing_input=0
for path in "$CLI_DOC" "$TROUBLESHOOTING_DOC" "$SKILL_DOC"; do
    if [[ ! -f "$path" ]]; then
        printf 'error: missing %s\n' "$path" >&2
        missing_input=1
    fi
done
if [[ "$missing_input" -ne 0 ]]; then
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 4. GUARD EXIT CODES
# ───────────────────────────────────────────────────────────────

# Collect the die codes from 2 upward, so the payload-mismatch exit 9 counts as a guard code
GUARD_CODES_RAW=$(grep -v '^[[:space:]]*#' "$GUARD" |
    grep -oE '(^|[^[:alnum:]_])die[[:space:]]+[0-9]+' |
    awk '{print $NF}' |
    awk '$1 >= 2' |
    sort -n -u |
    tr '\n' ' ')
if [[ -z "${GUARD_CODES_RAW//[[:space:]]/}" ]]; then
    printf 'error: no guard exit codes 2 and up found in %s\n' "$GUARD" >&2
    exit 2
fi
read -r -a GUARD_CODES <<< "$GUARD_CODES_RAW"

# ───────────────────────────────────────────────────────────────
# 5. SURFACE EXTRACTION
# ───────────────────────────────────────────────────────────────

# Table rows in cli.md whose first cell is the exit number
TABLE_CODES=$(awk -F'|' 'substr($0, 1, 1) == "|" {
    cell = $2
    gsub(/^[[:space:]]+/, "", cell)
    gsub(/[[:space:]]+$/, "", cell)
    if (cell ~ /^[0-9]+$/) print cell
}' "$CLI_DOC" |
    sort -n -u |
    tr '\n' ' ')

# Troubleshooting lines that name an exit code
ROW_CODES=$(grep -oE 'exit[[:space:]]+[0-9]+' "$TROUBLESHOOTING_DOC" |
    awk '{print $NF}' |
    sort -n -u |
    tr '\n' ' ')

# The TROUBLESHOOT line that lists the keywords
KEYWORD_LINE=$(awk '/TROUBLESHOOT/ && /keywords/ { print; exit }' "$SKILL_DOC")
if [[ -z "$KEYWORD_LINE" ]]; then
    printf 'error: no TROUBLESHOOT keyword line found in %s\n' "$SKILL_DOC" >&2
    exit 2
fi

# The exit codes in the TROUBLESHOOT keyword list
KEYWORD_CODES=$(printf '%s\n' "$KEYWORD_LINE" | grep -oE 'exit[[:space:]]+[0-9]+' |
    awk '{print $NF}' |
    sort -n -u |
    tr '\n' ' ')

# Section 3, which holds the gate ladder
SECTION3=$(awk '
    /^## 3\./ { inside = 1
                next }
    inside && /^## / { exit }
    inside { print }
' "$SKILL_DOC")
if [[ -z "$SECTION3" ]]; then
    printf 'error: no section 3 found in %s\n' "$SKILL_DOC" >&2
    exit 2
fi

# The gate ladder lists the gates in order and writes each code as an exit N
LADDER_CODES=$(printf '%s\n' "$SECTION3" | awk '
    /STEP 3: Gates/ { inside = 1 }
    inside && /STEP 4:/ { exit }
    inside { print }
' | grep -oE 'exit[[:space:]]+[0-9]+' |
    awk '{print $NF}' |
    sort -n -u |
    tr '\n' ' ')

# ───────────────────────────────────────────────────────────────
# 6. PARITY CHECKS AND REPORT
# ───────────────────────────────────────────────────────────────

has_code() {
    local code="$1"
    local present="$2"
    [[ " $present " == *" $code "* ]]
}

# Print one line when a surface yields no codes at all
# Args:
#   $1 - Surface name used in the report line
#   $2 - Space-separated exit codes found on the surface
# Returns:
#   0 when the surface names at least one code, 1 otherwise
report_empty_surface() {
    local surface="$1"
    local present="$2"
    if [[ -z "${present//[[:space:]]/}" ]]; then
        printf 'exit-code-parity: no exit codes found in %s\n' "$surface"
        return 1
    fi
    return 0
}

# Print one line for every guard code the surface list does not cover
# Args:
#   $1 - Surface name used in the report line
#   $2 - Space-separated exit codes found on the surface
report_missing_codes() {
    local surface="$1"
    local present="$2"
    local found_gap=0
    local code
    for code in "${GUARD_CODES[@]}"; do
        if ! has_code "$code" "$present"; then
            printf 'exit-code-parity: missing exit %s in %s\n' "$code" "$surface"
            found_gap=1
        fi
    done
    if [[ "$found_gap" -ne 0 ]]; then
        return 1
    fi
    return 0
}

# Print one line for every code the guard never emits that the surface does name
# The candidate codes come from the surface itself, so a code of any width counts
# Args:
#   $1 - Surface name used in the report line
#   $2 - Space-separated exit codes found on the surface
# Returns:
#   0 when the surface names no such code, 1 otherwise
report_extra_codes() {
    local surface="$1"
    local present="$2"
    local found_gap=0
    local code
    local -a present_codes=()
    read -r -a present_codes <<< "$present"
    for code in "${present_codes[@]}"; do
        # Exit 0 and 1 are generic shell results, so they never count as extras
        if [[ "$code" == "0" ]] || [[ "$code" == "1" ]]; then
            continue
        fi
        if ! has_code "$code" "${GUARD_CODES[*]}"; then
            printf 'exit-code-parity: extra exit %s in %s\n' "$code" "$surface"
            found_gap=1
        fi
    done
    if [[ "$found_gap" -ne 0 ]]; then
        return 1
    fi
    return 0
}

# Run the empty, missing and extra checks for one surface
# Args:
#   $1 - Surface name used in the report line
#   $2 - Space-separated exit codes found on the surface
check_surface() {
    local surface="$1"
    local present="$2"
    if ! report_empty_surface "$surface" "$present"; then
        failed=1
        return
    fi
    if ! report_missing_codes "$surface" "$present"; then
        failed=1
    fi
    if ! report_extra_codes "$surface" "$present"; then
        failed=1
    fi
}

failed=0

check_surface "cli-moneybird/references/cli.md exit table" "$TABLE_CODES"
check_surface "cli-moneybird/references/troubleshooting.md exit rows" "$ROW_CODES"
check_surface "cli-moneybird/SKILL.md TROUBLESHOOT keywords" "$KEYWORD_CODES"
check_surface "gate ladder" "$LADDER_CODES"

if [[ "$KEYWORD_LINE" != *"--print-body"* ]]; then
    printf 'exit-code-parity: missing --print-body in cli-moneybird/SKILL.md TROUBLESHOOT keywords\n'
    failed=1
fi

if [[ "$SECTION3" != *"references/cli.md"* ]]; then
    printf 'exit-code-parity: missing references/cli.md pointer in cli-moneybird/SKILL.md section 3\n'
    failed=1
fi

if [[ "$failed" -ne 0 ]]; then
    exit 1
fi

printf 'exit-code-parity: ok (codes: %s)\n' "${GUARD_CODES[*]}"
exit 0
