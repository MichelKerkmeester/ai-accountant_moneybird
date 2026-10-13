#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: EVAL GRADER
# ───────────────────────────────────────────────────────────────
"""Grade captured eval answers against the assertion blocks in evals.json.

Reads a captured run folder with one answer per case for the with-skill arm
and the baseline arm, checks every case's required tokens and forbidden
patterns, and writes grading.json and benchmark.json. No model judges an
answer: the assertion blocks are the whole grading contract.

A captured run folder holds:
    metadata.json            model_id, captured_on and an optional skill_hash
    with-skill/<case id>.md  one answer per case from the current skill
    baseline/<case id>.md    one answer per case from the baseline snapshot

The captured_on value is an ISO calendar date. A required token written as
{year} resolves to the year of that date, so a case never pins the capture
year in the suite file. A required entry may also be a list of alternative
phrasings, and the entry passes when any one of them appears.

The skill hash is the sha256 of SKILL.md plus every reference path the cases
route to. A run may record its own skill_hash in metadata.json, for example
when the baseline snapshot ships one, and that value is then used as given.

The refusal false-positive rate is the share of cases that should answer and
whose with-skill answer still stops with the route class BLOCKED. Refusal
markers match case-sensitively, because the route class is the uppercase
token and the lowercase word in prose names no route. An
assertion that passes in both arms does not discriminate, so it is flagged
always-pass in both reports.

Usage:
    python3 -I sk-moneybird-accountant/scripts/run-evals.py --grade DIR
    python3 -I sk-moneybird-accountant/scripts/run-evals.py --grade DIR --skill DIR --out DIR

Options:
    --grade DIR  Captured run folder to grade.
    --skill DIR  Skill copy to hash. Defaults to the skill above this script.
    --out DIR    Folder for grading.json and benchmark.json. Defaults to the
                 captured run folder.

Output:
    grading.json and benchmark.json, plus a summary on stdout. Exit 0 when
    every with-skill case passes, 1 when a case fails and 2 on a usage or
    data error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
from typing import Any, Dict, List, NoReturn, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GRADER = "sk-moneybird-accountant/scripts/run-evals.py"
SKILL_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVALS_PATH = os.path.join(SKILL_ROOT, "evals", "evals.json")

SKILL_FILE = "SKILL.md"
WITH_SKILL_ARM = "with-skill"
BASELINE_ARM = "baseline"
METADATA_NAME = "metadata.json"
GRADING_NAME = "grading.json"
BENCHMARK_NAME = "benchmark.json"
ANSWER_EXTENSIONS = (".md", ".txt")

# WHY: the suite contract promises at least 10 cases, so a shorter suite is a
# data error rather than a clean run.
MIN_CASES = 10

HEX_RE = re.compile(r"^[0-9a-f]{64}$")
DATE_FIELD = "captured_on"
YEAR_TOKEN = "{year}"

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
    print("error: %s" % message, file=sys.stderr)
    sys.exit(2)


def load_json(path: str, label: str) -> Any:
    """Read one JSON file.

    Args:
        path: File to read.
        label: Name used in the error message.

    Returns:
        The parsed JSON value.

    Raises:
        SystemExit: If the file cannot be read or parsed.
    """
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read %s: %s" % (label, exc))


def write_json(path: str, data: Any) -> None:
    """Write one report file with sorted keys and a trailing newline.

    Args:
        path: File to write.
        data: JSON value to store.

    Raises:
        SystemExit: If the file cannot be written.
    """
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
    except OSError as exc:
        fail("cannot write %s: %s" % (path, exc))

# ───────────────────────────────────────────────────────────────
# 4. SUITE AND CAPTURE LOADING
# ───────────────────────────────────────────────────────────────

def check_case(case: Any) -> None:
    """Validate one eval case before it is graded.

    Args:
        case: Parsed case object.

    Raises:
        SystemExit: If a required key or a non-empty assertion block is absent.
    """
    if not isinstance(case, dict):
        fail("a case is not a JSON object")
    for key in ("id", "prompt", "expect_refusal", "expected_route", "assertions"):
        if key not in case:
            fail("a case is missing %s" % key)
    assertions = case["assertions"]
    if not isinstance(assertions, dict):
        fail("case %s has no assertion block" % case["id"])
    for kind in ("required", "forbidden"):
        values = assertions.get(kind)
        if not isinstance(values, list) or not values:
            fail("case %s has no %s assertions" % (case["id"], kind))
        for value in values:
            # WHY: only a required entry may list alternative phrasings.
            if kind == "required" and isinstance(value, list):
                if not value or not all(isinstance(item, str) and item for item in value):
                    fail("case %s has an empty required alternative" % case["id"])
                continue
            if not isinstance(value, str) or not value:
                fail("case %s has an empty %s assertion" % (case["id"], kind))
    route = case["expected_route"]
    if not isinstance(route, dict) or not isinstance(route.get("references"), list):
        fail("case %s has no routed reference list" % case["id"])
    if not isinstance(case["expect_refusal"], bool):
        fail("case %s has no expect_refusal flag" % case["id"])


def load_suite() -> Dict[str, Any]:
    """Read and validate the eval suite beside this script.

    Returns:
        The parsed suite.

    Raises:
        SystemExit: If the suite is missing, malformed or too short.
    """
    data = load_json(EVALS_PATH, "the eval suite")
    if not isinstance(data, dict):
        fail("the eval suite is not a JSON object")
    markers = data.get("refusal_markers")
    if not isinstance(markers, list) or not markers:
        fail("the eval suite holds no refusal markers")
    cases = data.get("cases")
    if not isinstance(cases, list) or len(cases) < MIN_CASES:
        fail("the eval suite holds fewer than %d cases" % MIN_CASES)
    seen = set()
    for case in cases:
        check_case(case)
        if case["id"] in seen:
            fail("duplicate case id %s" % case["id"])
        seen.add(case["id"])
    return data


def read_metadata(run_dir: str) -> Dict[str, Any]:
    """Read the captured run metadata.

    Args:
        run_dir: Captured run folder.

    Returns:
        The metadata object.

    Raises:
        SystemExit: If the file, the model_id or the captured_on date is
            missing, if the date is not an ISO calendar date, or when a
            recorded skill_hash is not a sha256 hex digest.
    """
    path = os.path.join(run_dir, METADATA_NAME)
    if not os.path.isfile(path):
        fail("missing %s in the captured run" % METADATA_NAME)
    data = load_json(path, "the captured run metadata")
    model_id = data.get("model_id")
    if not isinstance(model_id, str) or not model_id:
        fail("the captured run metadata holds no model_id")
    captured = data.get(DATE_FIELD)
    if not isinstance(captured, str) or not captured:
        fail("the captured run metadata holds no %s date" % DATE_FIELD)
    try:
        datetime.date.fromisoformat(captured)
    except ValueError:
        fail("the captured run metadata holds an invalid %s date: %s" % (DATE_FIELD, captured))
    recorded = data.get("skill_hash")
    if recorded is not None and not (isinstance(recorded, str) and HEX_RE.match(recorded)):
        fail("the recorded skill_hash is not a sha256 hex digest")
    return data


def find_answer(run_dir: str, arm: str, case_id: str) -> str:
    """Read one captured answer.

    Args:
        run_dir: Captured run folder.
        arm: Arm folder name, with-skill or baseline.
        case_id: Case id, also the answer file stem.

    Returns:
        The answer text.

    Raises:
        SystemExit: If no answer file exists for the case and arm.
    """
    for extension in ANSWER_EXTENSIONS:
        path = os.path.join(run_dir, arm, case_id + extension)
        if os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    return handle.read()
            except OSError as exc:
                fail("cannot read %s: %s" % (path, exc))
    fail("missing %s answer for case %s" % (arm, case_id))


def compile_patterns(
    values: List[str],
    label: str,
    flags: int = re.IGNORECASE,
) -> List[Tuple[str, "re.Pattern"]]:
    """Compile forbidden patterns or refusal markers.

    Args:
        values: Pattern strings from the suite.
        label: Name used in the error message.
        flags: Regular expression flags, case-insensitive by default.

    Returns:
        Pairs of the source text and its compiled pattern.

    Raises:
        SystemExit: If a pattern does not compile.
    """
    compiled = []
    for value in values:
        try:
            compiled.append((value, re.compile(value, flags)))
        except re.error as exc:
            fail("bad pattern in %s: %s (%s)" % (label, value, exc))
    return compiled

# ───────────────────────────────────────────────────────────────
# 5. GRADING
# ───────────────────────────────────────────────────────────────

def grade_answer(
    text: str,
    required: List[Any],
    forbidden: List[Tuple[str, "re.Pattern"]],
) -> List[Dict[str, Any]]:
    """Check one answer against one case's assertion block.

    Args:
        text: Captured answer text.
        required: Required tokens, matched as case-insensitive substrings. A
            list entry passes when any of its alternatives matches.
        forbidden: Compiled forbidden patterns, searched case-insensitively.

    Returns:
        One row per assertion with kind, value and status.
    """
    rows = []
    lowered = text.lower()
    for value in required:
        options = value if isinstance(value, list) else [value]
        status = "pass" if any(option.lower() in lowered for option in options) else "fail"
        rows.append({"kind": "required", "value": value, "status": status})
    for value, pattern in forbidden:
        status = "fail" if pattern.search(text) else "pass"
        rows.append({"kind": "forbidden", "value": value, "status": status})
    return rows


def is_refused(text: str, markers: List[Tuple[str, "re.Pattern"]]) -> bool:
    """Tell whether an answer stops with the BLOCKED route class.

    Args:
        text: Captured answer text.
        markers: Compiled refusal markers.

    Returns:
        True when any marker matches.
    """
    return any(pattern.search(text) for _, pattern in markers)


def routed_references(suite: Dict[str, Any]) -> List[str]:
    """Collect every reference path the cases route to.

    Args:
        suite: Parsed suite.

    Returns:
        Sorted unique relative paths.
    """
    found = set()
    for case in suite["cases"]:
        for relative in case["expected_route"]["references"]:
            found.add(relative.lstrip("./"))
    return sorted(found)


def skill_hash(skill_dir: str, references: List[str]) -> Tuple[str, List[str]]:
    """Hash SKILL.md plus every routed reference.

    Args:
        skill_dir: Skill copy to hash.
        references: Relative reference paths.

    Returns:
        The sha256 hex digest and the paths absent from the copy.

    Raises:
        SystemExit: If the copy holds no SKILL.md.
    """
    if not os.path.isfile(os.path.join(skill_dir, SKILL_FILE)):
        fail("no %s under %s" % (SKILL_FILE, skill_dir))
    digest = hashlib.sha256()
    missing = []
    for relative in [SKILL_FILE] + references:
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        try:
            with open(os.path.join(skill_dir, relative), "rb") as handle:
                digest.update(handle.read())
        except OSError:
            missing.append(relative)
            digest.update(b"missing")
        digest.update(b"\0")
    return digest.hexdigest(), missing

# ───────────────────────────────────────────────────────────────
# 6. REPORTS
# ───────────────────────────────────────────────────────────────

def grade_run(suite: Dict[str, Any], run_dir: str, skill_dir: str, out_dir: str) -> int:
    """Grade every case and write both reports.

    Args:
        suite: Parsed suite.
        run_dir: Captured run folder.
        skill_dir: Skill copy to hash.
        out_dir: Folder for the two report files.

    Returns:
        Zero when every with-skill case passes, one otherwise.
    """
    metadata = read_metadata(run_dir)
    captured = metadata[DATE_FIELD]
    year = captured[:4]
    references = routed_references(suite)
    recorded = metadata.get("skill_hash")
    if recorded:
        digest = recorded
        missing: List[str] = []
        source = "recorded"
    else:
        digest, missing = skill_hash(skill_dir, references)
        source = "computed"
    markers = compile_patterns(suite["refusal_markers"], "refusal markers", flags=0)

    cases_out = []
    benchmark_cases = []
    always_pass = []
    benign = 0
    refused_benign = 0
    with_skill_passed = 0
    baseline_passed = 0

    for case in suite["cases"]:
        required = [
            [option.replace(YEAR_TOKEN, year) for option in value]
            if isinstance(value, list)
            else value.replace(YEAR_TOKEN, year)
            for value in case["assertions"]["required"]
        ]
        forbidden = compile_patterns(case["assertions"]["forbidden"], "case %s" % case["id"])
        with_text = find_answer(run_dir, WITH_SKILL_ARM, case["id"])
        base_text = find_answer(run_dir, BASELINE_ARM, case["id"])
        with_rows = grade_answer(with_text, required, forbidden)
        base_rows = grade_answer(base_text, required, forbidden)

        # WHY: an assertion that passes in both arms does not measure the
        # skill, so it carries the always-pass flag in both arm rows.
        for with_row, base_row in zip(with_rows, base_rows):
            both = with_row["status"] == "pass" and base_row["status"] == "pass"
            with_row["always_pass"] = both
            base_row["always_pass"] = both
            if both:
                always_pass.append({
                    "case": case["id"],
                    "kind": with_row["kind"],
                    "value": with_row["value"],
                })

        with_verdict = "pass" if all(row["status"] == "pass" for row in with_rows) else "fail"
        base_verdict = "pass" if all(row["status"] == "pass" for row in base_rows) else "fail"
        with_refused = is_refused(with_text, markers)
        base_refused = is_refused(base_text, markers)
        false_positive = bool(not case["expect_refusal"] and with_refused)
        if not case["expect_refusal"]:
            benign += 1
            if with_refused:
                refused_benign += 1
        if with_verdict == "pass":
            with_skill_passed += 1
        if base_verdict == "pass":
            baseline_passed += 1

        cases_out.append({
            "id": case["id"],
            "title": case.get("title", ""),
            "expect_refusal": case["expect_refusal"],
            "with_skill": {
                "verdict": with_verdict,
                "refused": with_refused,
                "assertions": with_rows,
            },
            "baseline": {
                "verdict": base_verdict,
                "refused": base_refused,
                "assertions": base_rows,
            },
            "false_positive": false_positive,
            "regression": base_verdict == "pass" and with_verdict == "fail",
        })
        benchmark_cases.append({
            "id": case["id"],
            "with_skill": with_verdict,
            "baseline": base_verdict,
            "expect_refusal": case["expect_refusal"],
            "refused": with_refused,
            "false_positive": false_positive,
            "regression": base_verdict == "pass" and with_verdict == "fail",
        })

    total = len(suite["cases"])
    false_positive_rate = (refused_benign / benign) if benign else 0.0

    grading = {
        "suite": suite.get("suite"),
        "skill_hash": digest,
        "skill_source": source,
        "model_id": metadata["model_id"],
        "captured_on": captured,
        "baseline_kind": suite.get("baseline", {}).get("kind"),
        "missing_references": missing,
        "cases": cases_out,
        "summary": {
            "cases": total,
            "with_skill_passed": with_skill_passed,
            "baseline_passed": baseline_passed,
            "always_pass_assertions": len(always_pass),
        },
    }
    benchmark = {
        "suite": suite.get("suite"),
        "skill_hash": digest,
        "skill_source": source,
        "model_id": metadata["model_id"],
        "captured_on": captured,
        "baseline_kind": suite.get("baseline", {}).get("kind"),
        "pass_rate": round(with_skill_passed / total, 4),
        "baseline_pass_rate": round(baseline_passed / total, 4),
        "refusal_false_positive_rate": round(false_positive_rate, 4),
        "benign_cases": benign,
        "refused_benign_cases": refused_benign,
        "always_pass": always_pass,
        "cases": benchmark_cases,
    }

    grading_path = os.path.join(out_dir, GRADING_NAME)
    benchmark_path = os.path.join(out_dir, BENCHMARK_NAME)
    write_json(grading_path, grading)
    write_json(benchmark_path, benchmark)

    print("run-evals: %d cases, %d with-skill passed, %d baseline passed"
          % (total, with_skill_passed, baseline_passed))
    print("run-evals: pass rate %.4f, baseline pass rate %.4f"
          % (with_skill_passed / total, baseline_passed / total))
    print("run-evals: refusal false positives %d of %d benign cases"
          % (refused_benign, benign))
    print("run-evals: always-pass assertions: %d" % len(always_pass))
    print("run-evals: skill hash %s (%s)" % (digest, source))
    print("run-evals: wrote %s and %s" % (grading_path, benchmark_path))
    return 0 if with_skill_passed == total else 1

# ───────────────────────────────────────────────────────────────
# 7. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and grade one captured run.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        The grader exit code.
    """
    parser = argparse.ArgumentParser(
        prog=GRADER,
        description="Grade captured eval answers against the assertion blocks in evals.json.",
    )
    parser.add_argument("--grade", metavar="DIR", required=True,
                        help="captured run folder to grade")
    parser.add_argument("--skill", metavar="DIR",
                        help="skill copy to hash, defaults to the skill above this script")
    parser.add_argument("--out", metavar="DIR",
                        help="folder for the two report files, defaults to the captured run folder")
    args = parser.parse_args(argv)

    run_dir = os.path.abspath(args.grade)
    if not os.path.isdir(run_dir):
        fail("captured run folder not found: %s" % args.grade)
    skill_dir = os.path.abspath(args.skill) if args.skill else SKILL_ROOT
    if not os.path.isdir(skill_dir):
        fail("skill folder not found: %s" % args.skill)
    out_dir = os.path.abspath(args.out) if args.out else run_dir
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create the output folder: %s" % exc)

    suite = load_suite()
    return grade_run(suite, run_dir, skill_dir, out_dir)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
