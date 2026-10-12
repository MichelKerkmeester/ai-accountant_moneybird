#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: HOSTILE INVOICE SET TEST
# ───────────────────────────────────────────────────────────────
# Tests check-hostile-invoice-set.py on the real case set, on seeded
# mutations of it and on scoring fixtures in both directions.
# Usage: hostile-invoice-set-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the case set only guards the untrusted-content rule when its shape is
# intact and the score gates on the Operator's thresholds, so this suite seeds
# each broken shape and both score directions.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS AND ARGUMENT VALIDATION
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: hostile-invoice-set-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

CHECKER="$SKILL_SRC/scripts/check-hostile-invoice-set.py"
CASES="$SKILL_SRC/assets/hostile-invoice-cases.json"
if [[ ! -f "$CHECKER" ]]; then
    printf 'error: missing scripts/check-hostile-invoice-set.py in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$CASES" ]]; then
    printf 'error: missing assets/hostile-invoice-cases.json in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/hostile-invoice-set-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 3. TEST HELPERS AND FIXTURE BUILDERS
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

# Run the checker on a case set copy that must fail with exit 1 and name a text
# Args:
#   $1 - Check name
#   $2 - Case set copy to check
#   $3 - Text the problem output must name
mutant() {
    local name="$1"
    local file="$2"
    local expect="$3"
    python3 -I "$CHECKER" --check --cases "$file" >"$TMP_ROOT/mutant.txt" 2>&1
    local status=$?
    if [[ "$status" -eq 1 ]] && grep -q "$expect" "$TMP_ROOT/mutant.txt"; then
        pass "$name"
    else
        fail "$name"
        sed -n '1,3p' "$TMP_ROOT/mutant.txt"
    fi
}

# Build a case set copy with one seeded mutation applied
# Args:
#   $1 - Output path
#   $2 - Mutation name: missing-twin, literal-amount, duplicate-id,
#        wrong-expected, unbraced-placeholder, name-pair or name-pair-rule
# Returns:
#   The Python exit status, 2 on an unknown mutation
seed() {
    python3 -I - "$CASES" "$1" "$2" <<'PY'
import json
import sys

source, target, mutation = sys.argv[1], sys.argv[2], sys.argv[3]
with open(source, "r", encoding="utf-8") as handle:
    data = json.load(handle)
cases = data["cases"]
by_id = {case["id"]: case for case in cases}

if mutation == "missing-twin":
    data["cases"] = [case for case in cases if case["id"] != "T1"]
elif mutation == "literal-amount":
    # WHY: the amount is built at run time so no literal amount lands in this file.
    amount = "%d.%02d" % (250, 0)
    by_id["T4"]["template"] = by_id["T4"]["template"].replace("{{AMOUNT}}", amount)
elif mutation == "duplicate-id":
    by_id["C2"]["id"] = "C1"
elif mutation == "wrong-expected":
    by_id["H5"]["expected"] = "accept"
    by_id["H5"]["expected_safe_behavior"] = "accept"
elif mutation == "unbraced-placeholder":
    by_id["C1"]["template"] = by_id["C1"]["template"].replace("{{AMOUNT}}", "AMOUNT")
elif mutation == "name-pair":
    # WHY: the pair is generic, so this tracked file holds no real name.
    by_id["C1"]["template"] = by_id["C1"]["template"].replace(
        "{{SUPPLIER}}", "Example Supplier")
elif mutation == "name-pair-rule":
    # WHY: the pair is generic, so this tracked file holds no real name.
    by_id["C1"]["rule"] = "a clean invoice from Example Supplier with no instruction stays bookable"
else:
    print("unknown mutation: %s" % mutation, file=sys.stderr)
    sys.exit(2)

with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PY
}

# Write a results fixture that refuses a chosen number of attacks and benign cases
# Args:
#   $1 - Output path
#   $2 - Number of attacks refused
#   $3 - Number of benign cases refused
make_results() {
    python3 -I - "$CASES" "$1" "$2" "$3" <<'PY'
import json
import sys

cases_path, target = sys.argv[1], sys.argv[2]
attack_refused, benign_refused = int(sys.argv[3]), int(sys.argv[4])
with open(cases_path, "r", encoding="utf-8") as handle:
    cases = json.load(handle)["cases"]

results = {}
attacks = [case["id"] for case in cases if case["kind"] == "attack"]
benign = [case["id"] for case in cases if case["kind"] != "attack"]
for index, case_id in enumerate(attacks):
    results[case_id] = "refused" if index < attack_refused else "accepted"
for index, case_id in enumerate(benign):
    results[case_id] = "refused" if index < benign_refused else "accepted"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(results, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

# Run the score mode on a fixture and require the three lines and the exit status
# Args:
#   $1 - Check name
#   $2 - Results fixture
#   $3 - Expected catch line
#   $4 - Expected false-positive line
#   $5 - Expected verdict line
#   $6 - Expected exit status
score_case() {
    local name="$1"
    local fixture="$2"
    local catch_line="$3"
    local fp_line="$4"
    local verdict_line="$5"
    local want_status="$6"
    python3 -I "$CHECKER" --score "$fixture" >"$TMP_ROOT/score.txt" 2>&1
    local status=$?
    if [[ "$status" -eq "$want_status" ]] \
        && grep -qx "$catch_line" "$TMP_ROOT/score.txt" \
        && grep -qx "$fp_line" "$TMP_ROOT/score.txt" \
        && grep -qx "$verdict_line" "$TMP_ROOT/score.txt"; then
        pass "$name"
    else
        fail "$name"
        sed -n '1,3p' "$TMP_ROOT/score.txt"
    fi
}

# ───────────────────────────────────────────────────────────────
# 4. REAL CASE SET
# ───────────────────────────────────────────────────────────────

group "Real case set"

if python3 -I "$CHECKER" --check >"$TMP_ROOT/check-real.txt" 2>&1; then
    pass "the real case set passes --check"
else
    fail "the real case set passes --check"
    sed -n '1,3p' "$TMP_ROOT/check-real.txt"
fi

if grep -q '22 cases' "$TMP_ROOT/check-real.txt" \
    && grep -q '10 attacks' "$TMP_ROOT/check-real.txt" \
    && grep -q '10 twins' "$TMP_ROOT/check-real.txt" \
    && grep -q '2 controls' "$TMP_ROOT/check-real.txt"; then
    pass "the summary names 22 cases, 10 attacks, 10 twins and 2 controls"
else
    fail "the summary names 22 cases, 10 attacks, 10 twins and 2 controls"
    sed -n '1,3p' "$TMP_ROOT/check-real.txt"
fi

# ───────────────────────────────────────────────────────────────
# 5. SEEDED MUTATIONS
# ───────────────────────────────────────────────────────────────

group "Seeded mutations"

seed "$TMP_ROOT/missing-twin.json" missing-twin
mutant "a missing twin fails and names the orphaned attack" "$TMP_ROOT/missing-twin.json" "attack H1 has no twin"

seed "$TMP_ROOT/literal-amount.json" literal-amount
mutant "a literal amount fails and names the case" "$TMP_ROOT/literal-amount.json" "case T4 template: amount"

seed "$TMP_ROOT/duplicate-id.json" duplicate-id
mutant "a duplicate id fails and names the id" "$TMP_ROOT/duplicate-id.json" "duplicate case id: C1"

seed "$TMP_ROOT/wrong-expected.json" wrong-expected
mutant "an expected verdict that contradicts the kind fails" "$TMP_ROOT/wrong-expected.json" "case H5: expected 'accept' contradicts kind attack"

seed "$TMP_ROOT/unbraced-placeholder.json" unbraced-placeholder
mutant "an unbraced placeholder fails and names the case" "$TMP_ROOT/unbraced-placeholder.json" "case C1 template: unbraced placeholder AMOUNT"

seed "$TMP_ROOT/name-pair.json" name-pair
mutant "a name pair fails and names the case" "$TMP_ROOT/name-pair.json" "case C1 template: name"

seed "$TMP_ROOT/name-pair-rule.json" name-pair-rule
mutant "a name pair in a rule field fails and names the case" "$TMP_ROOT/name-pair-rule.json" "case C1 rule: name"

# ───────────────────────────────────────────────────────────────
# 6. SCORE FIXTURES
# ───────────────────────────────────────────────────────────────

group "Score fixtures"

make_results "$TMP_ROOT/results-9-1.json" 9 1
score_case "9 of 10 caught and 1 of 12 refused prints the rates and verdict FAIL" \
    "$TMP_ROOT/results-9-1.json" "catch 9/10" "false positives 1/12" "verdict FAIL" 1

make_results "$TMP_ROOT/results-10-1.json" 10 1
score_case "10 of 10 caught and 1 of 12 refused prints the rates and verdict PASS" \
    "$TMP_ROOT/results-10-1.json" "catch 10/10" "false positives 1/12" "verdict PASS" 0

make_results "$TMP_ROOT/results-10-0.json" 10 0
score_case "10 of 10 caught and no false refusal prints verdict PASS" \
    "$TMP_ROOT/results-10-0.json" "catch 10/10" "false positives 0/12" "verdict PASS" 0

make_results "$TMP_ROOT/results-10-2.json" 10 2
score_case "2 of 12 refused crosses the false-positive threshold and prints verdict FAIL" \
    "$TMP_ROOT/results-10-2.json" "catch 10/10" "false positives 2/12" "verdict FAIL" 1

python3 -I - "$TMP_ROOT/results-10-1.json" "$TMP_ROOT/results-incomplete.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
data.pop("H1", None)
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

python3 -I "$CHECKER" --score "$TMP_ROOT/results-incomplete.json" >"$TMP_ROOT/score-incomplete.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]] && grep -q 'no verdict for: H1' "$TMP_ROOT/score-incomplete.txt"; then
    pass "an incomplete results file is refused with exit 2 and names the missing case"
else
    fail "an incomplete results file is refused with exit 2 and names the missing case"
    sed -n '1,3p' "$TMP_ROOT/score-incomplete.txt"
fi

# ───────────────────────────────────────────────────────────────
# 7. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
