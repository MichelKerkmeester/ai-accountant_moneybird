#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE CHECKER
# ───────────────────────────────────────────────────────────────
"""Check the task-type route table in the skill markdown.

Reads SKILL.md and verifies the route-table block between its markers. The
check validates the header, the row types, the Dutch and English cells, the
budget cells, the tool routes, the read-set paths, the routing constants,
the warning band, the abstain wording, the margin override bullets, the
pointer to the signal sources file and the source lines of that file. The
script uses the Python standard library only and makes no network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --signals /tmp/routing-signals.md

Options:
    --check       Run the check. This is the default and only mode.
    --skill-md P  Read this markdown file instead of the skill's own SKILL.md.
                  Read-set paths still resolve against the skill folder.
    --signals P   Read the signal sources from this file instead of the
                  skill's references/routing-signals.md.

Output:
    One line per problem, or "route-table: ok" when the file passes. Exit 0
    when the file passes, 1 when it has problems and 2 on a usage error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import List, NoReturn

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
SOURCES_HEAD = "SIGNAL SOURCES"
VOCABULARY_PREFIX = "- Skill vocabulary"
TIE_HEADING = "Ties and Abstain"
YEAR_TOKEN = "YYYY"

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
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("route-table: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
