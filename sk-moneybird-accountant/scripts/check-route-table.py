#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE CHECKER
# ───────────────────────────────────────────────────────────────
"""Check the task-type route table in the skill markdown.

Reads SKILL.md and verifies the route-table block between its markers. The
check validates the header, the row types, the Dutch and English cells, the
budget cells, the tool routes, the read-set paths, the routing constants,
the warning band, the abstain wording, the margin override bullets, the
pointer to the signal sources file, the source lines of that file and the
frozen calibration record in assets/route-calibration.json. The script uses
the Python standard library only and makes no network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --signals /tmp/routing-signals.md
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --calibration /tmp/route-calibration.json

Options:
    --check          Run the check. This is the default and only mode.
    --skill-md P     Read this markdown file instead of the skill's own SKILL.md.
                     Read-set paths still resolve against the skill folder.
    --signals P      Read the signal sources from this file instead of the
                     skill's references/routing-signals.md.
    --calibration P  Read the frozen constants from this file instead of the
                     skill's assets/route-calibration.json.

Output:
    One line per problem, or "route-table: ok" when the file passes. Exit 0
    when the file passes, 1 when it has problems and 2 on a usage error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, NoReturn, Optional

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/check-route-table.py"
SKILL_FOLDER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL_MD = os.path.join(SKILL_FOLDER, "SKILL.md")

START_MARKER = "<!-- route-table:start -->"
END_MARKER = "<!-- route-table:end -->"
EXPECTED_HEADER = "| Type | Name | Dutch signals | English signals | Tool route | Read set | Budget | On tie |"

# WHY: the table must carry every row type exactly once.
ROW_TYPES = tuple("T%d" % number for number in range(1, 10))
ROUTE_CELLS = ("`none`", "`cli-jortt`", "`cli-moneybird`", "`cli-jortt + cli-moneybird`", "`additive`")

# WHY: the routing prose must keep naming both calibration constants, the
# warning band and the abstain outcome.
REQUIRED_TOKENS = ("ROUTE_MARGIN", "FALLBACK_FLOOR", "0.08", "abstain")

# WHY: only these row types may carry their own margin override bullet.
OVERRIDE_TYPES = ("T2", "T6")
OVERRIDE_PREFIX = "- Margin override"

# WHY: the routing section must point readers at the signal sources file.
SIGNAL_HEAD = "Signal sources"
SIGNALS_REF = "references/routing-signals.md"
SIGNALS_MD = os.path.join(SKILL_FOLDER, "references", "routing-signals.md")
CALIBRATION_PATH = os.path.join(SKILL_FOLDER, "assets", "route-calibration.json")
SOURCES_HEAD = "SIGNAL SOURCES"
VOCABULARY_PREFIX = "- Skill vocabulary"
TIE_HEADING = "Ties and Abstain"
YEAR_TOKEN = "YYYY"
FALSE_ABSTAIN_MAX = 0.05
PENDING_MARKER = "calibration: pending"
CONSTANT_NUMBER_RE = re.compile(r"([0-9]+(?:\.[0-9]+)?)")

ROW_RE = re.compile(r"^\|\s*(T\d+)\s*\|")
OVERRIDE_BULLET_RE = re.compile(r"^\s*(T\d+):\s*(.*)$")
BACKTICK_RE = re.compile(r"`([^`]*)`")
NUMBER_RE = re.compile(r"\d+(?:\.\d+)?")
YEAR_RE = re.compile(r"^\d{4}$")

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


def is_empty(cell: str) -> bool:
    """Tell whether a table cell counts as empty.

    Args:
        cell: Raw cell text.

    Returns:
        True when the cell holds nothing outside whitespace and backticks.
    """
    return cell.strip().strip("`").strip() == ""


def split_cells(line: str) -> List[str]:
    """Split a markdown table line into stripped cells.

    Args:
        line: One table line with leading and trailing pipes.

    Returns:
        The cell texts without their surrounding whitespace.
    """
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def year_folders() -> List[str]:
    """List the four-digit year folders under references.

    Returns:
        Sorted folder names such as 2020 and 2021.
    """
    base = os.path.join(SKILL_FOLDER, "references")
    if not os.path.isdir(base):
        return []
    return sorted(
        name
        for name in os.listdir(base)
        if YEAR_RE.fullmatch(name) and os.path.isdir(os.path.join(base, name))
    )

# ───────────────────────────────────────────────────────────────
# 4. TABLE CHECK
# ───────────────────────────────────────────────────────────────

def check_read_set(row_type: str, cell: str, problems: List[str]) -> None:
    """Check every backticked path in one read-set cell.

    A year token expands over every year folder present, and each expanded
    path must exist under the skill folder.

    Args:
        row_type: Row type of the cell, used in problem lines.
        cell: Raw read-set cell text.
        problems: Problem list to append to.
    """
    years = year_folders()
    for span in BACKTICK_RE.findall(cell):
        if span == "-":
            continue
        if YEAR_TOKEN in span:
            for year in years:
                concrete = span.replace(YEAR_TOKEN, year)
                if not os.path.isfile(os.path.join(SKILL_FOLDER, concrete)):
                    problems.append("row %s read path missing: %s" % (row_type, concrete))
            continue
        if not os.path.isfile(os.path.join(SKILL_FOLDER, span)):
            problems.append("row %s read path missing: %s" % (row_type, span))


def check_row(line: str, row_type: str, problems: List[str]) -> None:
    """Check the cells of one route table row.

    Args:
        line: The stripped table row line.
        row_type: Row type named by the first cell.
        problems: Problem list to append to.
    """
    cells = split_cells(line)
    if len(cells) != 8:
        problems.append("row %s has %d cells, expected 8" % (row_type, len(cells)))
        return
    if is_empty(cells[2]):
        problems.append("row %s has an empty Dutch cell" % row_type)
    if is_empty(cells[3]):
        problems.append("row %s has an empty English cell" % row_type)
    if cells[4] not in ROUTE_CELLS:
        problems.append(
            "row %s tool route is %r, expected one of %s" % (row_type, cells[4], ", ".join(ROUTE_CELLS))
        )
    if cells[6] != "`tok:%s`" % row_type:
        problems.append("row %s budget cell is %r, expected `tok:%s`" % (row_type, cells[6], row_type))
    check_read_set(row_type, cells[5], problems)


def check_table(lines: List[str], problems: List[str]) -> None:
    """Check the markers, the header and every row of the route table.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
    """
    try:
        start = lines.index(START_MARKER)
    except ValueError:
        problems.append("route-table start marker missing")
        return
    try:
        end = lines.index(END_MARKER, start + 1)
    except ValueError:
        problems.append("route-table end marker missing")
        return
    body = lines[start + 1:end]
    header = ""
    for line in body:
        if line.strip():
            header = line.strip()
            break
    if header != EXPECTED_HEADER:
        problems.append("route table header must be exactly: %s" % EXPECTED_HEADER)
    seen: List[str] = []
    for line in body:
        stripped = line.strip()
        match = ROW_RE.match(stripped)
        if not match:
            continue
        row_type = match.group(1)
        if row_type in seen:
            problems.append("duplicate row %s" % row_type)
            continue
        seen.append(row_type)
        check_row(stripped, row_type, problems)
    for row_type in ROW_TYPES:
        if row_type not in seen:
            problems.append("missing row %s" % row_type)
    for row_type in seen:
        if row_type not in ROW_TYPES:
            problems.append("unexpected row %s" % row_type)

# ───────────────────────────────────────────────────────────────
# 5. PROSE CHECKS
# ───────────────────────────────────────────────────────────────

def check_required_tokens(text: str, problems: List[str]) -> None:
    """Check that the routing constants and outcomes are named in the file.

    Args:
        text: Full markdown text.
        problems: Problem list to append to.
    """
    for token in REQUIRED_TOKENS:
        if token not in text:
            problems.append("missing required token: %s" % token)


def check_overrides(lines: List[str], problems: List[str]) -> None:
    """Check the margin override bullets under the tie heading.

    The overrides are list bullets after the heading, one per override type.
    The heading must exist, each override type must have exactly one bullet,
    no other type may carry a bullet and the value must be the default word
    or a number.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
    """
    heading = -1
    for index, line in enumerate(lines):
        if line.lstrip().startswith("#") and TIE_HEADING in line:
            heading = index
            break
    if heading < 0:
        problems.append("heading missing: %s" % TIE_HEADING)
        return
    found: List[str] = []
    for index, line in enumerate(lines[heading + 1:], heading + 2):
        stripped = line.strip()
        if not stripped.startswith(OVERRIDE_PREFIX):
            continue
        body = stripped[len(OVERRIDE_PREFIX):].strip()
        match = OVERRIDE_BULLET_RE.match(body)
        if not match:
            problems.append("line %d: margin override bullet without a type and value" % index)
            continue
        row_type = match.group(1)
        if row_type not in OVERRIDE_TYPES:
            problems.append("line %d: margin override bullet names %s, expected T2 or T6" % (index, row_type))
            continue
        found.append(row_type)
        value = match.group(2).strip().strip("`").strip()
        if value != "default" and not NUMBER_RE.fullmatch(value):
            problems.append(
                "line %d: margin override for %s is %r, expected `default` or a number" % (index, row_type, value)
            )
    for row_type in OVERRIDE_TYPES:
        if row_type not in found:
            problems.append("margin override bullet missing for %s" % row_type)


def check_signals_pointer(lines: List[str], problems: List[str]) -> None:
    """Check that the routing section points at the signal sources file.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
    """
    for line in lines:
        if SIGNAL_HEAD in line and SIGNALS_REF in line:
            return
    problems.append("missing pointer line naming %s" % SIGNALS_REF)


def check_signal_sources(path: str, problems: List[str]) -> None:
    """Check the source lines of the signal sources file.

    The file must exist and its signal sources section must hold at least
    one list bullet. The skill vocabulary bullet is exempt. Every other
    bullet must carry a link to the tax authority site.

    Args:
        path: Path of the signal sources file.
        problems: Problem list to append to.
    """
    if not os.path.isfile(path):
        problems.append("signal sources file not found: %s" % path)
        return
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as exc:
        problems.append("cannot read %s: %s" % (path, exc))
        return
    section = -1
    for index, line in enumerate(lines):
        if line.lstrip().startswith("#") and SOURCES_HEAD in line:
            section = index
            break
    if section < 0:
        problems.append("%s has no %s section" % (path, SOURCES_HEAD))
        return
    bullets = 0
    for index, line in enumerate(lines[section + 1:], section + 2):
        stripped = line.strip()
        if stripped.startswith("#"):
            break
        if not stripped.startswith("- "):
            continue
        bullets += 1
        if stripped.startswith(VOCABULARY_PREFIX):
            continue
        if "belastingdienst.nl" not in stripped:
            problems.append("%s line %d: signal source without a belastingdienst.nl link" % (path, index))
    if bullets == 0:
        problems.append("%s holds no signal source lines" % path)


def constant_number(text: str, name: str) -> Optional[float]:
    """Read the number stated after one routing constant.

    Args:
        text: SKILL.md text.
        name: Constant name such as ROUTE_MARGIN.

    Returns:
        The number on the constant line, or None when the line states none.
    """
    match = re.search(re.escape(name) + r"[^\n]*?([0-9]+(?:\.[0-9]+)?)", text)
    if not match:
        return None
    return float(match.group(1))


def is_number(value: Any) -> bool:
    """Tell whether one JSON value is a real number.

    Args:
        value: Value from the calibration record.

    Returns:
        True for an int or float that is not a bool.
    """
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_rate(value: Any, label: str, problems: List[str]) -> Optional[float]:
    """Check one rate value and return it as a float.

    Args:
        value: Value from the calibration record.
        label: Field name used in a problem line.
        problems: Problem list to append to.

    Returns:
        The rate as a float, or None when it is not a valid rate.
    """
    if not is_number(value) or value < 0 or value > 1:
        problems.append("calibration %s must be a number from 0 to 1" % label)
        return None
    return float(value)


def check_rate_block(block: Any, label: str, problems: List[str]) -> None:
    """Check the two rates of one calibration split block.

    Args:
        block: JSON object with route_accuracy and false_abstain_rate.
        label: Split name used in a problem line.
        problems: Problem list to append to.
    """
    if not isinstance(block, dict):
        problems.append("calibration %s must be an object" % label)
        return
    check_rate(block.get("route_accuracy"), "%s route_accuracy" % label, problems)
    rate = check_rate(block.get("false_abstain_rate"), "%s false_abstain_rate" % label, problems)
    if rate is not None and rate > FALSE_ABSTAIN_MAX:
        problems.append(
            "calibration %s false_abstain_rate %.3f is above the %.2f cap" % (label, rate, FALSE_ABSTAIN_MAX)
        )
    rows = block.get("rows")
    matches = block.get("route_matches")
    if rows is not None and (not is_number(rows) or rows <= 0):
        problems.append("calibration %s rows must be a positive number" % label)
    if matches is not None and (not is_number(matches) or matches < 0):
        problems.append("calibration %s route_matches must not be negative" % label)
    accuracy = block.get("route_accuracy")
    if is_number(rows) and is_number(matches) and is_number(accuracy) and rows > 0:
        if abs(float(matches) / float(rows) - float(accuracy)) > 0.001:
            problems.append("calibration %s route_accuracy does not match its counts" % label)


def check_candidate_block(candidate: Dict[str, Any], floor: Any, problems: List[str]) -> None:
    """Check the counts and rates of one swept floor candidate.

    Args:
        candidate: One sweep candidate object.
        floor: Floor value of the candidate, used in problem lines.
        problems: Problem list to append to.
    """
    rows = candidate.get("rows")
    matches = candidate.get("route_matches")
    abstains = candidate.get("false_abstains")
    if not is_number(rows) or rows <= 0:
        problems.append("calibration sweep floor %s rows must be a positive number" % floor)
    if not is_number(matches) or matches < 0:
        problems.append("calibration sweep floor %s route_matches must not be negative" % floor)
    if not is_number(abstains) or abstains < 0:
        problems.append("calibration sweep floor %s false_abstains must not be negative" % floor)
    accuracy = check_rate(candidate.get("route_accuracy"), "sweep floor %s route_accuracy" % floor, problems)
    rate = check_rate(candidate.get("false_abstain_rate"), "sweep floor %s false_abstain_rate" % floor, problems)
    if is_number(rows) and is_number(matches) and is_number(accuracy) and rows > 0:
        if abs(float(matches) / float(rows) - float(accuracy)) > 0.001:
            problems.append("calibration sweep floor %s route_accuracy does not match its counts" % floor)
    if is_number(rows) and is_number(abstains) and is_number(rate) and rows > 0:
        if abs(float(abstains) / float(rows) - float(rate)) > 0.001:
            problems.append("calibration sweep floor %s false_abstain_rate does not match its counts" % floor)


def check_sweep(data: Dict[str, Any], problems: List[str]) -> None:
    """Check the sweep table and its link to the frozen block.

    The record must hold one candidate per swept floor, each with the
    calibration counts and the two rates. The frozen fallback floor must
    name one candidate and the frozen calibration block must repeat that
    candidate's counts.

    Args:
        data: The calibration record.
        problems: Problem list to append to.
    """
    sweep = data.get("sweep")
    if not isinstance(sweep, dict):
        problems.append("calibration sweep must be an object")
        return
    rule = sweep.get("selection_rule")
    if not isinstance(rule, str) or not rule.strip():
        problems.append("calibration sweep selection_rule must be a non-empty string")
    step = sweep.get("step")
    if step is not None and (not is_number(step) or step <= 0):
        problems.append("calibration sweep step must be a positive number")
    candidates = sweep.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        problems.append("calibration sweep must hold a non-empty candidate list")
        return
    seen: List[float] = []
    chosen_block: Optional[Dict[str, Any]] = None
    chosen = data.get("fallback_floor")
    for candidate in candidates:
        if not isinstance(candidate, dict):
            problems.append("calibration sweep candidate must be an object")
            continue
        floor = candidate.get("floor")
        if not is_number(floor) or float(floor) < 0:
            problems.append("calibration sweep candidate floor must be a number that is not negative")
            continue
        if float(floor) in seen:
            problems.append("calibration sweep holds duplicate floor %s" % floor)
        seen.append(float(floor))
        check_candidate_block(candidate, floor, problems)
        if is_number(chosen) and abs(float(chosen) - float(floor)) <= 0.000001:
            chosen_block = candidate
    if not seen:
        problems.append("calibration sweep holds no usable candidate")
        return
    if not is_number(chosen):
        return
    if chosen_block is None:
        problems.append("calibration fallback_floor %s is not a swept candidate" % chosen)
        return
    frozen = data.get("calibration")
    if isinstance(frozen, dict):
        for key in ("rows", "route_matches", "route_accuracy", "false_abstains", "false_abstain_rate"):
            if frozen.get(key) != chosen_block.get(key):
                problems.append("calibration %s differs from the swept floor %s" % (key, chosen))


def check_calibration(path: str, skill_text: str, problems: List[str]) -> None:
    """Check the frozen constants against the table that states them.

    The effective table value is the number the table states, or zero while
    the fallback floor is marked pending, because the scorer treats a
    pending floor as no floor. The checker fails when the record and the
    effective table state differ, when a rate is outside its range, when a
    false-abstain rate is above the cap and when the record is missing or
    malformed.

    Args:
        path: Path of the calibration record.
        skill_text: SKILL.md text that states the constants.
        problems: Problem list to append to.
    """
    if not os.path.isfile(path):
        problems.append("calibration file not found: %s" % path)
        return
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        problems.append("cannot read %s: %s" % (path, exc))
        return
    if not isinstance(data, dict):
        problems.append("calibration file must hold one object")
        return
    split_id = data.get("split_id")
    if not isinstance(split_id, str) or not split_id.strip():
        problems.append("calibration split_id must be a non-empty string")
    table_margin = constant_number(skill_text, "ROUTE_MARGIN")
    record_margin = data.get("route_margin")
    if not is_number(record_margin):
        problems.append("calibration route_margin must be a number")
    elif table_margin is not None and abs(float(record_margin) - table_margin) > 0.000001:
        problems.append(
            "calibration route_margin %s differs from the table %s" % (record_margin, table_margin)
        )
    record_floor = data.get("fallback_floor")
    if not is_number(record_floor) or float(record_floor) < 0:
        problems.append("calibration fallback_floor must be a number that is not negative")
    else:
        table_floor = constant_number(skill_text, "FALLBACK_FLOOR")
        if table_floor is None:
            if PENDING_MARKER not in skill_text:
                problems.append("calibration fallback_floor is neither stated in the table nor marked pending")
            elif abs(float(record_floor)) > 0.000001:
                problems.append(
                    "calibration fallback_floor %s differs from the pending table value 0.0" % record_floor
                )
        elif abs(float(record_floor) - table_floor) > 0.000001:
            problems.append(
                "calibration fallback_floor %s differs from the table %s" % (record_floor, table_floor)
            )
    check_rate_block(data.get("held_out"), "held_out", problems)
    check_rate_block(data.get("calibration"), "frozen", problems)
    check_sweep(data, problems)

# ───────────────────────────────────────────────────────────────
# 6. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the route table check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the file passes, one when it has problems.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check the task-type route table in the skill markdown.",
    )
    parser.add_argument("--check", action="store_true", help="run the check, the default and only mode")
    parser.add_argument(
        "--skill-md",
        metavar="PATH",
        default=SKILL_MD,
        help="read this markdown file instead of the skill's own SKILL.md",
    )
    parser.add_argument(
        "--signals",
        metavar="PATH",
        default=SIGNALS_MD,
        help="read the signal sources from this file instead of the skill's references/routing-signals.md",
    )
    parser.add_argument(
        "--calibration",
        metavar="PATH",
        default=CALIBRATION_PATH,
        help="read the frozen constants from this file instead of the skill's assets/route-calibration.json",
    )
    args = parser.parse_args(argv)
    if not os.path.isfile(args.skill_md):
        fail("skill markdown not found: %s" % args.skill_md)
    try:
        with open(args.skill_md, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (args.skill_md, exc))
    lines = text.splitlines()
    problems: List[str] = []
    check_table(lines, problems)
    check_required_tokens(text, problems)
    check_overrides(lines, problems)
    check_signals_pointer(lines, problems)
    check_signal_sources(args.signals, problems)
    check_calibration(args.calibration, text, problems)
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("route-table: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
