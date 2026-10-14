#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: TOKEN CANARY TEST
# ───────────────────────────────────────────────────────────────
# Tests token-baseline.py against the car question route, two mutants and a
# byte-only fixture. The suite imports the baseline script and calls its
# counting helpers, so no count is repeated here.
# Usage: token-canary-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, a missing skill file or a missing encoding cache
#
# WHY: the car question is the shortest route a reader can walk through the
# reference tree, so it is the first route a whole-file load would inflate.
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

# ───────────────────────────────────────────────────────────────
# 5. ROUTE CANARY DRIVER
# ───────────────────────────────────────────────────────────────

DRIVER="$TMP_ROOT/route-canary.py"
cat >"$DRIVER" <<'PY'
#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE CANARY DRIVER
# ───────────────────────────────────────────────────────────────
"""Measure one token baseline module against the route canary budget.

The driver imports the named token-baseline.py and calls its counting helpers,
so the canary never counts tokens on its own. The proposed car route must stay
at or under 35 percent of the current route and at or under 8000 cl100k_base
tokens. The driver also builds a byte-only fixture, rewrites a module copy so
the proposed route reads the whole topic through its parts, and swaps two
cached encoding files so the baseline must refuse them. No step downloads an
encoding.

Usage:
    route-canary.py pin <module>
    route-canary.py route <module>
    route-canary.py fixture <module>
    route-canary.py whole-file <module>
    route-canary.py swap-cache <module> <source cache> <target cache>

Options:
    None.

Output:
    The measured route numbers, one budget line per breach, the fixture
    numbers and one line for each mutation.

Exit Codes:
    0 - The requested step passed
    1 - A route or fixture stayed outside its budget
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
from typing import Any, Dict, List, NoReturn, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

PROGRAM = "route-canary"
RATIO_PERCENT = 35
CEILING_CL100K = 8000

# The fixture repeats one car cost row. Its token count carries a byte count
# that a bytes/4 budget accepts, while the count itself stands 25 percent over
# a token budget that the same byte count implies.
FIXTURE_UNIT = "| Auto | Kosten |\n|---|---|\n| 0.25 | 12345 |\n"
FIXTURE_REPEATS = 7

Counts = Dict[str, int]
Ratios = Dict[str, float]

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


def open_encoders(module: ModuleType) -> Dict[str, Any]:
    """Check the cache pin and load both encoders from the local cache.

    Args:
        module: The imported token baseline module.

    Returns:
        Mapping of encoding name to an encoder.

    Raises:
        SystemExit: When a cache file is missing or its hash differs.
    """
    module.check_cache(module.cache_dir())
    return module.load_encoders()


def route_rows(module: ModuleType, encoders: Dict[str, Any]) -> Tuple[Counts, Counts, Ratios]:
    """Return the current and proposed token counts and the route ratio.

    Args:
        module: The imported token baseline module.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        The current counts, the proposed counts and the ratio by encoding.
    """
    data = module.build_baseline(encoders)
    units = {row["name"]: row for row in data["units"]}
    current = units[module.CAR_CURRENT_NAME]["tokens"]
    proposed = units[module.CAR_PROPOSED_NAME]["tokens"]
    return current, proposed, data["car_route"]["ratio"]


def budget_problems(current: Counts, proposed: Counts) -> List[str]:
    """Return one line per cl100k_base budget that the proposed route breaks.

    Args:
        current: Token counts of the current route.
        proposed: Token counts of the proposed route.

    Returns:
        The problem lines, empty when the route is inside both budgets.
    """
    problems: List[str] = []
    if proposed["cl100k_base"] * 100 > RATIO_PERCENT * current["cl100k_base"]:
        problems.append(
            "cl100k_base proposed %d is over %d percent of current %d"
            % (proposed["cl100k_base"], RATIO_PERCENT, current["cl100k_base"])
        )
    if proposed["cl100k_base"] > CEILING_CL100K:
        problems.append(
            "cl100k_base proposed %d is over the ceiling %d"
            % (proposed["cl100k_base"], CEILING_CL100K)
        )
    return problems

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


def mode_route(module: ModuleType, encoders: Dict[str, Any]) -> int:
    """Measure the car route and apply the ratio and ceiling budget.

    Args:
        module: The imported token baseline module.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        Zero when the route is inside both budgets, one otherwise.
    """
    current, proposed, ratio = route_rows(module, encoders)
    print("route current: %s" % module.token_text(current))
    print("route proposed: %s" % module.token_text(proposed))
    print("route ratio: %s" % module.ratio_text(ratio))
    print(
        "route budget: at most %d percent of current and at most %d cl100k_base tokens"
        % (RATIO_PERCENT, CEILING_CL100K)
    )
    problems = budget_problems(current, proposed)
    for problem in problems:
        print("budget: %s" % problem)
    if problems:
        print("budget: rejected")
        return 1
    print("budget: accepted")
    return 0


def mode_fixture(module: ModuleType, encoders: Dict[str, Any]) -> int:
    """Check a fixture that passes a byte budget and breaks a token budget.

    The token budget is four fifths of the measured count, so the count is
    exactly 25 percent over it. The byte budget is four bytes per token from
    the same rule the fixture is meant to defeat.

    Args:
        module: The imported token baseline module.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        Zero when the byte budget passes and the token gate rejects, one
        when the fixture does not show that gap.
    """
    text = FIXTURE_UNIT * FIXTURE_REPEATS
    size = module.count_bytes(text)
    counts = module.count_tokens(text, encoders)
    count = counts["cl100k_base"]
    budget = count * 4 // 5
    byte_budget = budget * 4
    byte_ok = size <= byte_budget
    token_ok = count <= budget
    exact = count * 4 == budget * 5
    print("fixture bytes: %d" % size)
    print("fixture tokens: %s" % module.token_text(counts))
    print("byte budget: %d bytes, %s" % (byte_budget, "passes" if byte_ok else "fails"))
    print(
        "token budget: %d cl100k_base tokens, %s"
        % (budget, "within" if token_ok else "over by 25 percent")
    )
    if not exact:
        print("fixture: the count is not exactly 25 percent over the token budget")
        return 1
    if not byte_ok:
        print("fixture: the byte budget fails, so the probe proves nothing")
        return 1
    if token_ok:
        print("fixture: the token budget passes, so the probe proves nothing")
        return 1
    print("fixture: the byte budget passes and the token gate rejects the text")
    return 0


def mode_nested(module: ModuleType, encoders: Dict[str, Any]) -> int:
    """Check that the walk reaches a nested file once and keeps its path.

    The walk is depth-agnostic at the base commit, so this case guards that
    behavior instead of proving a fix.

    Args:
        module: The imported token baseline module.
        encoders: Mapping of encoding name to an encoder.

    Returns:
        Zero when the walk holds the nested file exactly once, its row path
        is the nested path and its two sections are counted, one otherwise.
    """
    wanted = "tax-rules/2020/vat/figures.md"
    paths = [module.relative_path(path) for path in module.markdown_files()]
    hits = [path for path in paths if path.endswith(wanted)]
    row = module.file_row(os.path.join(module.REFERENCES_ROOT, wanted), encoders)
    print("nested files: %d" % len(paths))
    print("nested hits: %d" % len(hits))
    print("nested sections: %d" % len(row["sections"]))
    if len(hits) != 1:
        print("nested: the walk does not hold the file exactly once")
        return 1
    if row["path"] != "sk-moneybird-accountant/references/" + wanted:
        print("nested: the row path is not the nested path")
        return 1
    if len(row["sections"]) != 2:
        print("nested: the nested file does not count its two sections")
        return 1
    print("nested: one entry and two sections from a depth-agnostic walk")
    return 0


def mode_whole_file(path: str) -> int:
    """Point the proposed route of a module copy at the whole topic.

    Args:
        path: Path of a token-baseline.py copy to rewrite.

    Returns:
        Zero when the copy is rewritten.

    Raises:
        SystemExit: When the route lines are missing, so no mutation applies.
    """
    old_reads = '[readme_path, "%s#%s" % (topic_path, CAR_SECTION_ANCHOR)]'
    new_reads = "[readme_path] + topic_paths"
    old_part = "[readme, section_part(topic_path, CAR_SECTION_ANCHOR, rows)]"
    new_part = "[readme] + topic_parts"
    with open(path, "r", encoding="utf-8") as handle:
        text = handle.read()
    if text.count(old_reads) != 1 or text.count(old_part) != 1:
        fail("cannot place the whole-file mutation in %s" % path)
    text = text.replace(old_reads, new_reads).replace(old_part, new_part)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    print("mutant: the proposed route reads the whole topic through its parts")
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
    modes = ("pin", "route", "fixture", "whole-file", "swap-cache", "nested")
    if len(argv) < 2 or argv[0] not in modes:
        fail("usage: %s <mode> <module> [args]" % PROGRAM)
    mode = argv[0]
    module = load_module(argv[1])
    if mode == "whole-file":
        return mode_whole_file(argv[1])
    if mode == "swap-cache":
        if len(argv) != 4:
            fail("usage: swap-cache <module> <source cache> <target cache>")
        return mode_swap_cache(module, argv[2], argv[3])
    if mode == "pin":
        return mode_pin(module)
    encoders = open_encoders(module)
    if mode == "route":
        return mode_route(module, encoders)
    if mode == "nested":
        return mode_nested(module, encoders)
    return mode_fixture(module, encoders)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
PY

if [[ ! -s "$DRIVER" ]]; then
    printf 'error: cannot write the route canary driver\n' >&2
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

group "car question on the key figures route"
run_driver route "$BASELINE_PY"
status=$?
show_output
if [[ "$status" -eq 0 ]]; then
    pass "the year README plus the key figures section stays within budget"
else
    fail "the year README plus the key figures section stays within budget"
fi

group "whole-file mutant"
COPY_REPO="$TMP_ROOT/repo"
mkdir -p "$COPY_REPO/sk-moneybird-accountant"
cp -R "$SKILL_SRC/." "$COPY_REPO/sk-moneybird-accountant/"
COPY_PY="$COPY_REPO/sk-moneybird-accountant/scripts/token-baseline.py"
run_driver whole-file "$COPY_PY"
status=$?
show_output
if [[ "$status" -eq 0 ]]; then
    pass "the throwaway copy points the proposed route at the whole topic"
else
    fail "the throwaway copy points the proposed route at the whole topic"
fi
run_driver route "$COPY_PY"
status=$?
show_output
if [[ "$status" -eq 1 ]] && grep -q 'over 35 percent' "$TMP_ROOT/out.txt"; then
    pass "the whole-file mutant fails on the ratio"
else
    fail "the whole-file mutant fails on the ratio"
fi

group "swapped-encoding mutant"
MUTANT_CACHE="$TMP_ROOT/cache-swapped"
run_driver swap-cache "$BASELINE_PY" "$CACHE_DIR" "$MUTANT_CACHE"
status=$?
show_output
if [[ "$status" -eq 0 ]]; then
    pass "the mutant cache holds the lead data under the second name"
else
    fail "the mutant cache holds the lead data under the second name"
fi
TIKTOKEN_CACHE_DIR="$MUTANT_CACHE" python3 -I "$BASELINE_PY" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
show_output
if [[ "$status" -eq 2 ]] && grep -q 'pin mismatch cl100k_base' "$TMP_ROOT/out.txt"; then
    pass "the baseline refuses a swapped encoding file"
else
    fail "the baseline refuses a swapped encoding file"
fi

group "byte-only fixture"
run_driver fixture "$BASELINE_PY"
status=$?
show_output
if [[ "$status" -eq 0 ]] && grep -q 'token gate rejects' "$TMP_ROOT/out.txt"; then
    pass "a fixture inside the byte budget fails the token budget"
else
    fail "a fixture inside the byte budget fails the token budget"
fi

# WHY: the walk is depth-agnostic at the base commit, so this fixture guards
# that behavior instead of proving a fix.
group "nested reference file"
NESTED_REPO="$TMP_ROOT/nested-repo"
NESTED_SKILL="$NESTED_REPO/sk-moneybird-accountant"
mkdir -p "$NESTED_SKILL/scripts" "$NESTED_SKILL/references/tax-rules/2020/vat"
cp "$BASELINE_PY" "$NESTED_SKILL/scripts/token-baseline.py"
cat >"$NESTED_SKILL/references/tax-rules/2020/vat/figures.md" <<'EOF'
# Nested figures

## 1. KEY FIGURES

| Item | Value | Status | Check |
|---|---|---|---|
| Rate | Fixture value | enacted | Verified |

## 2. NOTES

A nested note that gives the file its second section.
EOF
run_driver nested "$NESTED_SKILL/scripts/token-baseline.py"
status=$?
show_output
if [[ "$status" -eq 0 ]] && grep -q 'nested: one entry and two sections' "$TMP_ROOT/out.txt"; then
    pass "a depth-agnostic walk counts a nested reference file once"
else
    fail "a depth-agnostic walk counts a nested reference file once"
fi

group "real tree"
python3 -I "$BASELINE_PY" --check >"$TMP_ROOT/out.txt" 2>&1
status=$?
show_output
if [[ "$status" -eq 0 ]] && grep -q 'check ok' "$TMP_ROOT/out.txt"; then
    pass "the baseline check passes on the real tree"
else
    fail "the baseline check passes on the real tree"
fi

# ───────────────────────────────────────────────────────────────
# 7. SUMMARY
# ───────────────────────────────────────────────────────────────

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
