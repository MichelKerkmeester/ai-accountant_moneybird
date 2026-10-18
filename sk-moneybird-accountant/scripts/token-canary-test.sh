#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: TOKEN CANARY TEST
# ───────────────────────────────────────────────────────────────
# Tests token-baseline.py against a swapped encoding file, a router grown past
# the request line and a baseline gone stale. The suite imports the baseline
# script and calls its pin helpers, so no hash is repeated here.
# Usage: token-canary-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, a missing skill file, a missing encoding cache or a
#       fixture that cannot be built
#
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT, SKILL AND CACHE VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: token-canary-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

BASELINE_PY="$SKILL_SRC/scripts/token-baseline.py"
if [[ ! -f "$BASELINE_PY" ]]; then
    printf 'error: missing scripts/token-baseline.py in the skill folder\n' >&2
    exit 2
fi

BASELINE_JSON="$SKILL_SRC/benchmark/token-baseline.json"
if [[ ! -f "$BASELINE_JSON" ]]; then
    printf 'error: missing benchmark/token-baseline.json in the skill folder\n' >&2
    exit 2
fi

# The canary never defaults the cache to a path and never downloads an
# encoding. The variable must point at a folder that already holds the two
# pinned data files, which the pin step below proves before any count runs.
CACHE_DIR="${TIKTOKEN_CACHE_DIR:-}"
if [[ -z "$CACHE_DIR" ]]; then
    printf 'error: TIKTOKEN_CACHE_DIR is not set, the canary never downloads an encoding\n' >&2
    exit 2
fi
if [[ ! -d "$CACHE_DIR" ]]; then
    printf 'error: TIKTOKEN_CACHE_DIR is not a folder: %s\n' "$CACHE_DIR" >&2
    exit 2
fi
CACHE_DIR=$(cd "$CACHE_DIR" && pwd -P) || exit 2
export TIKTOKEN_CACHE_DIR="$CACHE_DIR"

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/token-canary-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture or copy survives the run
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

# Run a driver mode and capture its output
# Args:
#   $1 - Driver mode
#   $2... - Driver arguments
# Returns:
#   The driver exit status, with output in $TMP_ROOT/out.txt
run_driver() {
    local mode="$1"
    shift
    python3 -I "$DRIVER" "$mode" "$@" >"$TMP_ROOT/out.txt" 2>&1
}

# Print the captured driver output with a two space indent
show_output() {
    sed 's/^/  /' "$TMP_ROOT/out.txt"
}

# Copy the skill folder and the hub SKILL.md into a throwaway repository root
# WHY: the baseline counts the hub SKILL.md that every route reads, so each copy carries it.
# Args:
#   $1 - Repository root to create
# Returns:
#   0 when the copy is complete, 1 otherwise
copy_repo() {
    mkdir -p "$1/sk-moneybird-accountant" \
        && cp -R "$SKILL_SRC/." "$1/sk-moneybird-accountant/" \
        && cp "$(dirname "$SKILL_SRC")/SKILL.md" "$1/SKILL.md"
}

# ───────────────────────────────────────────────────────────────
# 5. CACHE DRIVER
# ───────────────────────────────────────────────────────────────

DRIVER="$TMP_ROOT/cache-driver.py"
cat >"$DRIVER" <<'PY'
#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: CACHE DRIVER
# ───────────────────────────────────────────────────────────────
"""Reach into one token baseline module for the canary suite.

The driver imports the named token-baseline.py and calls its pin helpers, so
the canary never derives a cache file name or a hash of its own. One mode
checks the cached encoding files against the module pin, and the other swaps
two cached encoding files so the baseline must refuse them. No step
downloads an encoding.

Usage:
    cache-driver.py pin <module>
    cache-driver.py swap-cache <module> <source cache> <target cache>

Options:
    None.

Output:
    The cache folder and the cache file of each encoding, or one line for the
    swap.

Exit Codes:
    0 - The requested step passed
    2 - Bad usage, a missing encoding cache or a pin mismatch
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import importlib.util
import os
import shutil
import sys
from types import ModuleType
from typing import List, NoReturn

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

PROGRAM = "cache-driver"

# ───────────────────────────────────────────────────────────────
# 3. HELPERS
# ───────────────────────────────────────────────────────────────

def fail(message: str) -> NoReturn:
    """Print an error and stop with exit code 2.

    Args:
        message: Error text for stderr.

    Raises:
        SystemExit: Always, with code 2.
    """
    print("%s: %s" % (PROGRAM, message), file=sys.stderr)
    sys.exit(2)


def load_module(path: str) -> ModuleType:
    """Import the token baseline module at one path.

    Args:
        path: Path of a token-baseline.py.

    Returns:
        The imported module.

    Raises:
        SystemExit: When the file cannot be imported.
    """
    spec = importlib.util.spec_from_file_location("token_baseline_canary", path)
    if spec is None or spec.loader is None:
        fail("cannot import %s" % path)
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:
        fail("cannot load %s: %s" % (path, exc))
    return module

# ───────────────────────────────────────────────────────────────
# 4. MODES
# ───────────────────────────────────────────────────────────────

def mode_pin(module: ModuleType) -> int:
    """Check both cached encoding files against the module pin.

    Args:
        module: The imported token baseline module.

    Returns:
        Zero when both files match the pin.
    """
    module.check_cache(module.cache_dir())
    print("cache directory: %s" % module.cache_dir())
    for entry in module.ENCODINGS:
        print("encoding file: %s %s" % (entry["name"], module.cache_file_name(entry["url"])))
    return 0


def mode_swap_cache(module: ModuleType, source: str, target: str) -> int:
    """Copy the cache and put the lead encoding data under the second name.

    Args:
        module: The imported token baseline module.
        source: Cache folder that holds the pinned files.
        target: Cache folder to fill with the swapped files.

    Returns:
        Zero when the target folder holds both files.

    Raises:
        SystemExit: When a copy fails.
    """
    names = {
        entry["name"]: module.cache_file_name(entry["url"]) for entry in module.ENCODINGS
    }
    try:
        os.makedirs(target, exist_ok=True)
        for file_name in names.values():
            shutil.copyfile(os.path.join(source, file_name), os.path.join(target, file_name))
        shutil.copyfile(
            os.path.join(source, names[module.LEAD_ENCODING]),
            os.path.join(target, names[module.SECOND_ENCODING]),
        )
    except OSError as exc:
        fail("cannot build the swapped cache: %s" % exc)
    print("mutant: %s holds the lead encoding data under the second name" % target)
    return 0

# ───────────────────────────────────────────────────────────────
# 5. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Run the mode named by the first argument.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code of the requested step.

    Raises:
        SystemExit: On bad usage or a setup failure.
    """
    if len(argv) < 2 or argv[0] not in ("pin", "swap-cache"):
        fail("usage: %s <mode> <module> [args]" % PROGRAM)
    module = load_module(argv[1])
    if argv[0] == "swap-cache":
        if len(argv) != 4:
            fail("usage: swap-cache <module> <source cache> <target cache>")
        return mode_swap_cache(module, argv[2], argv[3])
    return mode_pin(module)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
PY

if [[ ! -s "$DRIVER" ]]; then
    printf 'error: cannot write the cache driver\n' >&2
    exit 2
fi

# The pin step runs before any count, so a missing or changed cache file stops
# the run with exit code 2 instead of a download
if ! python3 -I "$DRIVER" pin "$BASELINE_PY" >"$TMP_ROOT/pin.txt" 2>&1; then
    printf 'error: the encoding cache does not match the baseline pin\n' >&2
    sed 's/^/  /' "$TMP_ROOT/pin.txt" >&2
    exit 2
fi
printf 'cache: pin ok\n'
sed 's/^/  /' "$TMP_ROOT/pin.txt"

# ───────────────────────────────────────────────────────────────
# 6. CHECKS
# ───────────────────────────────────────────────────────────────

group "swapped-encoding mutant"
MUTANT_CACHE="$TMP_ROOT/cache-swapped"
if ! run_driver swap-cache "$BASELINE_PY" "$CACHE_DIR" "$MUTANT_CACHE"; then
    show_output
    abort_setup "the swapped cache cannot be built"
fi
TIKTOKEN_CACHE_DIR="$MUTANT_CACHE" python3 -I "$BASELINE_PY" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
show_output
if [[ "$status" -eq 2 ]] && grep -q 'pin mismatch cl100k_base' "$TMP_ROOT/out.txt"; then
    pass "the baseline refuses a swapped encoding file"
else
    fail "the baseline refuses a swapped encoding file"
fi

group "request line"
# WHY: every accountant request reads the hub, the router and the skill file
# first, so their sum has its own line and a grown router must fail by name.
REQUEST_REPO="$TMP_ROOT/request-repo"
copy_repo "$REQUEST_REPO" || abort_setup "the request line fixture cannot be copied"
python3 -I -c 'import sys; open(sys.argv[1], "a", encoding="utf-8").write("\n" + "Padding sentence for the request line. " * 600 + "\n")' \
    "$REQUEST_REPO/sk-moneybird-accountant/ROUTER.md" \
    || abort_setup "the request line fixture cannot be padded"
TIKTOKEN_CACHE_DIR="$CACHE_DIR" python3 -I "$REQUEST_REPO/sk-moneybird-accountant/scripts/token-baseline.py" >/dev/null 2>&1 \
    || abort_setup "the request line fixture baseline cannot be written"
TIKTOKEN_CACHE_DIR="$CACHE_DIR" python3 -I "$REQUEST_REPO/sk-moneybird-accountant/scripts/token-baseline.py" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
show_output
if [[ "$status" -eq 1 ]] && grep -q 'over request line SKILL.md + sk-moneybird-accountant/ROUTER.md + sk-moneybird-accountant/SKILL.md' "$TMP_ROOT/out.txt"; then
    pass "a router past the request line fails the check by name"
else
    fail "a router past the request line fails the check by name"
fi

group "stale baseline"
# WHY: the check compares the stored baseline row by row, so a reference edit
# made after the write must fail and name the file.
DRIFT_REPO="$TMP_ROOT/drift-repo"
copy_repo "$DRIFT_REPO" || abort_setup "the stale baseline fixture cannot be copied"
TIKTOKEN_CACHE_DIR="$CACHE_DIR" python3 -I "$DRIFT_REPO/sk-moneybird-accountant/scripts/token-baseline.py" >/dev/null 2>&1 \
    || abort_setup "the stale baseline fixture baseline cannot be written"
printf '\nA sentence added after the baseline was written.\n' \
    >>"$DRIFT_REPO/sk-moneybird-accountant/references/README.md" \
    || abort_setup "the stale baseline fixture cannot be edited"
TIKTOKEN_CACHE_DIR="$CACHE_DIR" python3 -I "$DRIFT_REPO/sk-moneybird-accountant/scripts/token-baseline.py" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
show_output
if [[ "$status" -eq 1 ]] && grep -q 'drift: files: changed sk-moneybird-accountant/references/README.md' "$TMP_ROOT/out.txt"; then
    pass "an edit after the baseline write fails the check and names the file"
else
    fail "an edit after the baseline write fails the check and names the file"
fi

# ───────────────────────────────────────────────────────────────
# 7. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
