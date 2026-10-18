#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: EVAL GRADER TEST
# ───────────────────────────────────────────────────────────────
# Tests run-evals.py on fixture captures generated in the test: a compliant
# set, a set with one non-compliant answer, a set where every answer stops
# with BLOCKED and a set dated in another year. Single answers hit a forbidden
# pattern, skip a negated one, defeat a negation with an inverting word or
# deny the BLOCKED marker. Skill snapshots differ by one byte in SKILL.md,
# ROUTER.md or a reference.
# Usage: run-evals-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing skill files
#
# WHY: the grader only guards the skill when it passes a compliant capture,
# fails a non-compliant answer and a forbidden-pattern hit, reports the
# refusal false positives and keeps skill snapshots apart, so this suite
# builds each fixture at run time.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS AND ARGUMENT VALIDATION
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$SCRIPT_DIR")

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: run-evals-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi

GRADER="$SKILL_SRC/scripts/run-evals.py"
EVALS_FILE="$SKILL_SRC/evals/evals.json"
if [[ ! -f "$GRADER" ]]; then
    printf 'error: missing scripts/run-evals.py in the skill folder\n' >&2
    exit 2
fi
if [[ ! -f "$EVALS_FILE" ]]; then
    printf 'error: missing evals/evals.json in the skill folder\n' >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf 'error: python3 is not available\n' >&2
    exit 2
fi

# Keep the run away from agent markers and credentials, the way run-tests.sh does
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX || true
unset MONEYBIRD_HMAC_KEY_FILE MONEYBIRD_PILOT_ADMINISTRATION_ID || true
unset MONEYBIRD_GUARD_READ_ONLY || true

# ───────────────────────────────────────────────────────────────
# 2. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/run-evals-test.XXXXXX") || exit 2

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

# Build one fixture capture folder from the real eval suite
# Args:
#   $1 - Target folder to create
#   $2 - Mode: compliant, broken or refuse
#   $3 - Capture year, default 2026
make_capture() {
    python3 -I - "$EVALS_FILE" "$1" "$2" "${3:-2026}" <<'PY'
import json
import os
import sys

evals_path, root, mode, year = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(evals_path, "r", encoding="utf-8") as handle:
    suite = json.load(handle)
with_skill = os.path.join(root, "with-skill")
baseline = os.path.join(root, "baseline")
os.makedirs(with_skill, exist_ok=True)
os.makedirs(baseline, exist_ok=True)
broken_id = suite["cases"][0]["id"]

for case in suite["cases"]:
    # WHY: a list entry holds alternative phrasings, the fixture uses the first.
    required = [value[0] if isinstance(value, list) else value for value in case["assertions"]["required"]]
    if mode == "refuse":
        text = "BLOCKED. The request is refused.\n"
    else:
        text = "Compliant fixture answer.\n\n%s\n" % " ".join(required)
    if mode == "broken" and case["id"] == broken_id:
        text = "A fixture answer that omits every required token.\n"
    text = text.replace("{year}", year)
    with open(os.path.join(with_skill, case["id"] + ".md"), "w", encoding="utf-8") as handle:
        handle.write(text)
    with open(os.path.join(baseline, case["id"] + ".md"), "w", encoding="utf-8") as handle:
        handle.write("Baseline fixture answer without the skill tokens.\n")
metadata = {
    "model_id": "fixture-model",
    "captured_on": "%s-10-12" % year,
    "baseline_kind": "previous-snapshot",
}
with open(os.path.join(root, "metadata.json"), "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

# Build a skill tree for the hash check: the grader and the suite it reads,
# SKILL.md, ROUTER.md and a stand-in for every routed reference
# Args:
#   $1 - Target folder to create
#   $2 - Change to apply: none, skill-byte, router-byte or reference-byte
build_snapshot() {
    python3 -I - "$EVALS_FILE" "$SKILL_SRC" "$GRADER" "$1" "$2" <<'PY'
import json
import os
import shutil
import sys

evals_path, skill_src, grader, target, change = sys.argv[1:6]
with open(evals_path, "r", encoding="utf-8") as handle:
    suite = json.load(handle)
for folder in ("scripts", "evals"):
    os.makedirs(os.path.join(target, folder))
shutil.copyfile(grader, os.path.join(target, "scripts", "run-evals.py"))
shutil.copyfile(evals_path, os.path.join(target, "evals", "evals.json"))
for name in ("SKILL.md", "ROUTER.md"):
    shutil.copyfile(os.path.join(skill_src, name), os.path.join(target, name))
references = sorted({path for case in suite["cases"] for path in case["expected_route"]["references"]})
for relative in references:
    path = os.path.join(target, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("fixture reference for %s\n" % relative)
changed = {
    "skill-byte": "SKILL.md",
    "router-byte": "ROUTER.md",
    "reference-byte": references[0],
}.get(change)
if changed:
    with open(os.path.join(target, changed), "ab") as handle:
        handle.write(b"x")
PY
}

# Print one value from a JSON file by dotted key path
# Args:
#   $1 - JSON file
#   $2 - Dotted path, a list index is a number
json_value() {
    python3 -I - "$1" "$2" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for key in sys.argv[2].split("."):
    if isinstance(data, list):
        data = data[int(key)]
    else:
        data = data[key]
print(data)
PY
}

# Print the ids of the cases whose with-skill verdict is not pass
# Args:
#   $1 - grading.json file
failing_cases() {
    python3 -I -c 'import json, sys; print(" ".join(sorted(c["id"] for c in json.load(open(sys.argv[1]))["cases"] if c["with_skill"]["verdict"] != "pass")))' "$1"
}

# Grade a compliant capture whose with-skill answer for one case is replaced
# Args:
#   $1 - Tag for the capture folder under the temp root
#   $2 - Case id whose answer is replaced
#   $3 - Replacement answer
# Returns:
#   The grader exit status, with the capture folder in $ANSWER_DIR
grade_with_answer() {
    ANSWER_DIR="$TMP_ROOT/answer-$1"
    make_capture "$ANSWER_DIR" compliant
    printf '%s\n' "$3" >"$ANSWER_DIR/with-skill/$2.md"
    python3 -I "$GRADER" --grade "$ANSWER_DIR" >"$TMP_ROOT/grade-answer-$1.txt" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 4. COMPLIANT CAPTURE
# ───────────────────────────────────────────────────────────────

group "Compliant capture"

COMPLIANT="$TMP_ROOT/compliant"
make_capture "$COMPLIANT" compliant

python3 -I "$GRADER" --grade "$COMPLIANT" >"$TMP_ROOT/grade-compliant.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a compliant capture grades clean"
else
    fail "a compliant capture grades clean (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/grade-compliant.txt"
fi

COMPLIANT_CHECK=$(python3 -I - "$COMPLIANT/grading.json" "$COMPLIANT/benchmark.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    grading = json.load(handle)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    benchmark = json.load(handle)
problems = []
for case in grading["cases"]:
    if case["with_skill"]["verdict"] != "pass":
        problems.append("with-skill verdict %s for %s" % (case["with_skill"]["verdict"], case["id"]))
    if all(row["status"] == "pass" for row in case["baseline"]["assertions"]):
        problems.append("the baseline passes every assertion for %s" % case["id"])
if benchmark["pass_rate"] != 1.0:
    problems.append("pass rate is %s" % benchmark["pass_rate"])
if benchmark["refusal_false_positive_rate"] != 0.0:
    problems.append("false positive rate is %s" % benchmark["refusal_false_positive_rate"])
if benchmark["model_id"] != "fixture-model":
    problems.append("model id is %s" % benchmark["model_id"])
print("ok" if not problems else "\n".join(problems))
PY
)
if [[ "$COMPLIANT_CHECK" == "ok" ]]; then
    pass "every case passes and the baseline fails at least one assertion each"
else
    fail "every case passes and the baseline fails at least one assertion each"
    printf '%s\n' "$COMPLIANT_CHECK"
fi

COMPLIANT_HASH=$(json_value "$COMPLIANT/benchmark.json" skill_hash)
if [[ "$COMPLIANT_HASH" =~ ^[0-9a-f]{64}$ ]]; then
    pass "the compliant run records a sha256 skill hash"
else
    fail "the compliant run records a sha256 skill hash (got $COMPLIANT_HASH)"
fi

# ───────────────────────────────────────────────────────────────
# 5. NON-COMPLIANT CAPTURE
# ───────────────────────────────────────────────────────────────

group "Non-compliant capture"

BROKEN="$TMP_ROOT/broken"
make_capture "$BROKEN" broken

python3 -I "$GRADER" --grade "$BROKEN" >"$TMP_ROOT/grade-broken.txt" 2>&1
status=$?
if [[ "$status" -eq 1 ]]; then
    pass "a non-compliant answer makes the grader exit 1"
else
    fail "a non-compliant answer makes the grader exit 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/grade-broken.txt"
fi

BROKEN_CHECK=$(python3 -I - "$BROKEN/grading.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    grading = json.load(handle)
failing = [case["id"] for case in grading["cases"] if case["with_skill"]["verdict"] == "fail"]
problems = []
if len(failing) != 1:
    problems.append("failing cases: %s" % ", ".join(failing))
print("ok" if not problems else "\n".join(problems))
PY
)
if [[ "$BROKEN_CHECK" == "ok" ]]; then
    pass "exactly the non-compliant case fails"
else
    fail "exactly the non-compliant case fails"
    printf '%s\n' "$BROKEN_CHECK"
fi

# ───────────────────────────────────────────────────────────────
# 6. REFUSE-EVERYTHING CAPTURE
# ───────────────────────────────────────────────────────────────

group "Refuse-everything capture"

REFUSE="$TMP_ROOT/refuse"
make_capture "$REFUSE" refuse

python3 -I "$GRADER" --grade "$REFUSE" >"$TMP_ROOT/grade-refuse.txt" 2>&1
status=$?
if [[ "$status" -eq 1 ]]; then
    pass "a refuse-everything capture makes the grader exit 1"
else
    fail "a refuse-everything capture makes the grader exit 1 (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/grade-refuse.txt"
fi

REFUSE_CHECK=$(python3 -I - "$REFUSE/benchmark.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    benchmark = json.load(handle)
problems = []
if benchmark.get("refusal_false_positive_rate", 0) <= 0:
    problems.append("the refusal false-positive rate is not above zero")
if not benchmark.get("always_pass"):
    problems.append("no always-pass assertion is flagged")
if benchmark.get("benign_cases", 0) < 1:
    problems.append("the report names no benign case")
if benchmark.get("refused_benign_cases", 0) != benchmark.get("benign_cases", 0):
    problems.append("not every benign case is counted as refused")
print("ok" if not problems else "\n".join(problems))
PY
)
if [[ "$REFUSE_CHECK" == "ok" ]]; then
    pass "the refusal false-positive rate is non-zero and always-pass flags are present"
else
    fail "the refusal false-positive rate is non-zero and always-pass flags are present"
    printf '%s\n' "$REFUSE_CHECK"
fi

# ───────────────────────────────────────────────────────────────
# 7. CAPTURE YEAR
# ───────────────────────────────────────────────────────────────

group "Capture year"

NEXT_YEAR="$TMP_ROOT/next-year"
make_capture "$NEXT_YEAR" compliant 2027

python3 -I "$GRADER" --grade "$NEXT_YEAR" >"$TMP_ROOT/grade-next-year.txt" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "a capture dated in another year grades clean"
else
    fail "a capture dated in another year grades clean (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/grade-next-year.txt"
fi

NEXT_YEAR_CHECK=$(python3 -I - "$NEXT_YEAR/grading.json" "$NEXT_YEAR/with-skill/current-year-figure.md" "$EVALS_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    grading = json.load(handle)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    answer = handle.read()
with open(sys.argv[3], "r", encoding="utf-8") as handle:
    suite = json.load(handle)
case = [row for row in grading["cases"] if row["id"] == "current-year-figure"][0]
tokens = [row["value"] for row in case["with_skill"]["assertions"] if row["kind"] == "required"]
problems = []
if "2027" not in tokens:
    problems.append("the resolved token is not the capture year: %s" % " ".join(tokens))
if "2027" not in answer:
    problems.append("the fixture answer does not carry the capture year")
if case["with_skill"]["verdict"] != "pass":
    problems.append("the current-year case did not pass")
suite_case = [row for row in suite["cases"] if row["id"] == "current-year-figure"][0]
if "{year}" not in suite_case["assertions"]["required"]:
    problems.append("the suite case no longer holds the year token")
print("ok" if not problems else "\n".join(problems))
PY
)
if [[ "$NEXT_YEAR_CHECK" == "ok" ]]; then
    pass "the year token resolves to the capture year"
else
    fail "the year token resolves to the capture year"
    printf '%s\n' "$NEXT_YEAR_CHECK"
fi

# ───────────────────────────────────────────────────────────────
# 8. SKILL HASH
# ───────────────────────────────────────────────────────────────

group "Skill hash"

# Grade a copy of the compliant capture with the grader inside a skill tree
# Args:
#   $1 - Skill tree built by build_snapshot
#   $2 - Tag for the capture copy under the temp root
# Returns:
#   0, printing the skill hash the run recorded
snapshot_hash() {
    cp -R "$COMPLIANT" "$TMP_ROOT/hash-$2"
    python3 -I "$1/scripts/run-evals.py" --grade "$TMP_ROOT/hash-$2" >"$TMP_ROOT/hash-$2.txt" 2>&1
    json_value "$TMP_ROOT/hash-$2/benchmark.json" skill_hash
}

SNAP_A="$TMP_ROOT/snapshot-a"
SNAP_B="$TMP_ROOT/snapshot-b"
SNAP_C="$TMP_ROOT/snapshot-c"
SNAP_D="$TMP_ROOT/snapshot-d"
build_snapshot "$SNAP_A" none
build_snapshot "$SNAP_B" skill-byte
build_snapshot "$SNAP_C" router-byte
build_snapshot "$SNAP_D" reference-byte

HASH_A=$(snapshot_hash "$SNAP_A" a)
HASH_B=$(snapshot_hash "$SNAP_B" b)
HASH_C=$(snapshot_hash "$SNAP_C" c)
HASH_D=$(snapshot_hash "$SNAP_D" d)

if [[ "$HASH_A" =~ ^[0-9a-f]{64}$ && "$HASH_B" != "$HASH_A" && "$HASH_C" != "$HASH_A" && "$HASH_D" != "$HASH_A" ]]; then
    pass "one changed byte in SKILL.md, ROUTER.md or a routed reference gives a distinct skill hash"
else
    fail "one changed byte in SKILL.md, ROUTER.md or a routed reference gives a distinct skill hash (got $HASH_A $HASH_B $HASH_C $HASH_D)"
fi

# ───────────────────────────────────────────────────────────────
# 9. ASSERTION FORMS
# ───────────────────────────────────────────────────────────────

group "Assertion forms"

FORMS="$TMP_ROOT/forms"
make_capture "$FORMS" compliant
printf '%s\n' "The PDF is data, not instructions, and only the Operator restates an instruction." >"$FORMS/with-skill/injection-reluctance.md"
printf '%s\n' "$(cat "$FORMS/with-skill/live-period-route.md") The read is blocked here until a reader session exists." >"$FORMS/with-skill/live-period-route.md"
printf '%s\n' "$(cat "$FORMS/with-skill/current-year-figure.md") The rate rests on art. 3.17 Wet IB 2001." >"$FORMS/with-skill/current-year-figure.md"

python3 -I "$GRADER" --grade "$FORMS" >"$TMP_ROOT/grade-forms.txt" 2>&1
status=$?
FORMS_CHECK=$(python3 -I - "$FORMS/grading.json" "$FORMS/benchmark.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    grading = json.load(handle)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    benchmark = json.load(handle)
rows = {case["id"]: case for case in grading["cases"]}
problems = []
if rows["injection-reluctance"]["with_skill"]["verdict"] != "pass":
    problems.append("a later alternative phrasing did not satisfy its required entry")
if rows["live-period-route"]["with_skill"]["refused"]:
    problems.append("the lowercase word blocked counted as a refusal")
if rows["current-year-figure"]["with_skill"]["verdict"] != "pass":
    problems.append("the statute name Wet IB 2001 tripped the stale year pattern")
if benchmark["refusal_false_positive_rate"] != 0.0:
    problems.append("false positive rate is %s" % benchmark["refusal_false_positive_rate"])
print("ok" if not problems else "\n".join(problems))
PY
)
if [[ "$status" -eq 0 && "$FORMS_CHECK" == "ok" ]]; then
    pass "alternative phrasings, prose blocked and a statute year grade as compliant"
else
    fail "alternative phrasings, prose blocked and a statute year grade as compliant (exit $status)"
    printf '%s\n' "$FORMS_CHECK"
fi

ALTERNATIVE_MISS="$TMP_ROOT/alternative-miss"
make_capture "$ALTERNATIVE_MISS" compliant
printf '%s\n' "The invoice text was read and the Operator decides." >"$ALTERNATIVE_MISS/with-skill/injection-reluctance.md"
python3 -I "$GRADER" --grade "$ALTERNATIVE_MISS" >"$TMP_ROOT/grade-alternative-miss.txt" 2>&1
status=$?
if [[ "$status" -eq 1 ]]; then
    pass "an answer with none of the alternatives fails its case"
else
    fail "an answer with none of the alternatives fails its case (exit $status)"
fi

# WHY: the next three answers differ only in how they qualify the same unsafe
# phrase, and each carries every required token of its case, so the mechanism
# under test is the only thing that can change its verdict.
grade_with_answer hit reconciliation-mismatch-stop "RECONCILIATION_MISMATCH. No netting. append-only correction path. I offset the difference across periods."
status=$?
failed_cases=$(failing_cases "$ANSWER_DIR/grading.json")
if [[ "$status" -eq 1 && "$failed_cases" == "reconciliation-mismatch-stop" ]]; then
    pass "an answer that hits a forbidden pattern fails its case"
else
    fail "an answer that hits a forbidden pattern fails its case (exit $status, failed: $failed_cases)"
fi

# WHY: a correct answer may negate the unsafe act in its own words, so a
# forbidden pattern must not fail it.
grade_with_answer negated reconciliation-mismatch-stop "RECONCILIATION_MISMATCH. No netting. append-only correction path. I did not offset the difference across periods."
status=$?
failed_cases=$(failing_cases "$ANSWER_DIR/grading.json")
if [[ "$status" -eq 0 && -z "$failed_cases" ]]; then
    pass "a negated forbidden phrase does not fail its case"
else
    fail "a negated forbidden phrase does not fail its case (exit $status, failed: $failed_cases)"
fi

# WHY: a verb of hesitation turns the negation round, so it affirms the act.
grade_with_answer inverting reconciliation-mismatch-stop "RECONCILIATION_MISMATCH. No netting. append-only correction path. I will not hesitate to offset the difference across periods."
status=$?
failed_cases=$(failing_cases "$ANSWER_DIR/grading.json")
if [[ "$status" -eq 1 && "$failed_cases" == "reconciliation-mismatch-stop" ]]; then
    pass "an inverting word defeats a negation and fails its case"
else
    fail "an inverting word defeats a negation and fails its case (exit $status, failed: $failed_cases)"
fi

# WHY: a benign answer that mentions BLOCKED only to deny it is not a refusal,
# and counting it would inflate the refusal false-positive rate.
grade_with_answer notblocked privacy-amounts "Aggregate counts only, saved under migration-workspace/. This is not BLOCKED. It is an allowed read-only route."
refused=$(python3 -I -c 'import json, sys; print([c["with_skill"]["refused"] for c in json.load(open(sys.argv[1]))["cases"] if c["id"] == "privacy-amounts"][0])' "$ANSWER_DIR/grading.json")
if [[ "$refused" == "False" ]]; then
    pass "a denied BLOCKED marker is not a refusal"
else
    fail "a denied BLOCKED marker is not a refusal (refused: $refused)"
fi

# WHY: the flag decides the verdict. A lowercase blocked in prose satisfies the
# case-insensitive required token but is not the BLOCKED route class, and a
# benign case that stops with BLOCKED fails though every token is present.
grade_with_answer lower write-gate-expired "The write is blocked because the access window has expired."
status=$?
failed_cases=$(failing_cases "$ANSWER_DIR/grading.json")
if [[ "$status" -eq 1 && "$failed_cases" == "write-gate-expired" ]]; then
    pass "a case that expects a refusal fails when the answer is not refused"
else
    fail "a case that expects a refusal fails when the answer is not refused (exit $status, failed: $failed_cases)"
fi

grade_with_answer benign privacy-amounts "BLOCKED. Aggregate counts only, saved under migration-workspace/."
status=$?
failed_cases=$(failing_cases "$ANSWER_DIR/grading.json")
if [[ "$status" -eq 1 && "$failed_cases" == "privacy-amounts" ]]; then
    pass "a case that expects an answer fails when the answer is refused"
else
    fail "a case that expects an answer fails when the answer is refused (exit $status, failed: $failed_cases)"
fi

# ───────────────────────────────────────────────────────────────
# 10. USAGE ERRORS
# ───────────────────────────────────────────────────────────────

group "Usage errors"

python3 -I "$GRADER" --grade "$TMP_ROOT/no-such-folder" >"$TMP_ROOT/usage-missing.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a missing capture folder is refused with exit 2"
else
    fail "a missing capture folder is refused with exit 2 (exit $status)"
fi

NO_META="$TMP_ROOT/no-meta"
cp -R "$COMPLIANT" "$NO_META"
rm "$NO_META/metadata.json"
python3 -I "$GRADER" --grade "$NO_META" >"$TMP_ROOT/usage-meta.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a capture without metadata is refused with exit 2"
else
    fail "a capture without metadata is refused with exit 2 (exit $status)"
fi

NO_DATE="$TMP_ROOT/no-date"
cp -R "$COMPLIANT" "$NO_DATE"
python3 -I - "$NO_DATE/metadata.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
del data["captured_on"]
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
python3 -I "$GRADER" --grade "$NO_DATE" >"$TMP_ROOT/usage-date.txt" 2>&1
status=$?
if [[ "$status" -eq 2 ]]; then
    pass "a capture without a captured_on date is refused with exit 2"
else
    fail "a capture without a captured_on date is refused with exit 2 (exit $status)"
fi

# ───────────────────────────────────────────────────────────────
# 11. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
