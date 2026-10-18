#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: HARDENING MATRIX CHECK
# ───────────────────────────────────────────────────────────────
"""Check the hardening matrix for complete rows and covered tests.

Reads sk-moneybird-accountant/hardening-matrix.md and parses the table between
its markers. Every row must name a failure mode, a priority, a control, a test,
an owner and a status. A P0 row must name an existing test path in the form
"path :: case name". A P1 or P2 row may write "-" for no test, and any row
that names a test needs the path to exist and the case name to occur in that
file as a quoted test name, so a deleted test file or a renamed case fails the
check instead of leaving a silent gap. A test path must stay inside the
repository: a path that resolves outside the root, as an absolute path, a
parent segment or a link can, fails the check on any row. The script reads the
repository above it, uses the Python standard library only and makes no
network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-hardening-matrix.py

Output:
    One line per problem, or "hardening-matrix: ok" with the row counts when
    the matrix passes. Exit 0 when the matrix passes, 1 on a finding and 2 on
    a missing file or a usage error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import Dict, List, NoReturn

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/check-hardening-matrix.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MATRIX_REL = "sk-moneybird-accountant/hardening-matrix.md"

MARKER_START = "<!-- hardening-matrix:start -->"
MARKER_END = "<!-- hardening-matrix:end -->"

EXPECTED_HEADER = ("#", "Failure mode", "Priority", "Control", "Test", "Owner", "Status")
PRIORITIES = ("P0", "P1", "P2")
STATUS_VALUES = ("Covered", "Partial", "Pending", "Deferred")

# The test cell holds a repo-relative path, this separator, then a case name.
TEST_SEPARATOR = " :: "
NO_TEST = "-"

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


def read_text(root: str, relative: str) -> str:
    """Read one repository file as text.

    Args:
        root: Repository root.
        relative: Path relative to the root.

    Returns:
        The file text.

    Raises:
        SystemExit: If the file cannot be read.
    """
    path = os.path.join(root, relative)
    if not os.path.isfile(path):
        fail("missing file: %s" % relative)
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative, exc))


def split_cells(line: str) -> List[str]:
    """Split one markdown table line into its cells.

    Args:
        line: A line that starts and ends with a pipe.

    Returns:
        The cell texts without the outer pipes.
    """
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def stays_inside(root: str, path: str) -> bool:
    """Tell whether a matrix test path stays inside the repository.

    Args:
        root: Repository root.
        path: Test path as the matrix cell wrote it.

    Returns:
        False for a path whose resolved target lies outside the resolved
        root. An absolute path, a parent segment and a link all resolve there.
    """
    resolved = os.path.realpath(os.path.join(root, path))
    return resolved.startswith(os.path.realpath(root) + os.sep)


COMMENT_LINE_RE = re.compile(r"^\s*#")


def code_lines(text: str) -> str:
    """Drop the whole-line comments from a test file.

    Args:
        text: Test file text.

    Returns:
        The text without the lines that start with a comment mark.
    """
    return "\n".join(line for line in text.splitlines() if not COMMENT_LINE_RE.match(line))


def declares_case(text: str, case: str) -> bool:
    """Tell whether a test file declares a case by name.

    Args:
        text: Test file text.
        case: Case name from the matrix cell.

    Returns:
        True when the case sits right after an opening quote and is followed
        by the same closing quote or by a space inside a longer quoted name.
        The suites and the eval file name a case as a quoted string. A quoted
        mention on a comment line and a name inside another word do not
        count.
    """
    pattern = r"""(["'])""" + re.escape(case) + r"""(?:\1|(?=[ \t]))"""
    return re.search(pattern, code_lines(text)) is not None


# ───────────────────────────────────────────────────────────────
# 4. PARSE
# ───────────────────────────────────────────────────────────────

def parse_rows(text: str, problems: List[str]) -> List[Dict[str, str]]:
    """Parse the matrix table between its markers.

    Args:
        text: The full matrix document.
        problems: List that collects problem lines.

    Returns:
        One dict per data row with the header names as keys.
    """
    lines = text.splitlines()
    start = None
    end = None
    for index, line in enumerate(lines):
        if line.strip() == MARKER_START and start is None:
            start = index
        elif line.strip() == MARKER_END and start is not None:
            end = index
            break
    if start is None:
        problems.append("start marker missing: %s" % MARKER_START)
        return []
    if end is None:
        problems.append("end marker missing: %s" % MARKER_END)
        return []

    rows = [line for line in lines[start + 1:end] if line.strip().startswith("|")]
    if len(rows) < 3:
        problems.append("the table holds fewer than one header and one data row")
        return []

    header = split_cells(rows[0])
    if tuple(header) != EXPECTED_HEADER:
        problems.append("header is %r, expected %r" % (tuple(header), EXPECTED_HEADER))
        return []

    data: List[Dict[str, str]] = []
    for line in rows[2:]:
        cells = split_cells(line)
        if len(cells) != len(EXPECTED_HEADER):
            problems.append("row %r holds %d cells, expected %d" % (cells[0] if cells else line, len(cells), len(EXPECTED_HEADER)))
            continue
        data.append(dict(zip(EXPECTED_HEADER, cells)))
    if not data:
        problems.append("the table holds no data rows")
    return data

# ───────────────────────────────────────────────────────────────
# 5. CHECK
# ───────────────────────────────────────────────────────────────

def check_row(row: Dict[str, str], root: str, problems: List[str]) -> None:
    """Check one matrix row and its test path.

    Args:
        row: One parsed row.
        root: Repository root for the test path lookup.
        problems: List that collects failing problem lines.
    """
    label = row["#"] or "(row without an id)"
    if not row["#"]:
        problems.append("a row has no id")
    if row["Priority"] not in PRIORITIES:
        problems.append("row %s: priority %r is not one of %s" % (label, row["Priority"], ", ".join(PRIORITIES)))
    if not row["Failure mode"]:
        problems.append("row %s: failure mode is empty" % label)
    if not row["Control"]:
        problems.append("row %s: control is empty" % label)
    if not row["Owner"]:
        problems.append("row %s: owner is empty" % label)
    if row["Status"] not in STATUS_VALUES:
        problems.append("row %s: status %r is not one of %s" % (label, row["Status"], ", ".join(STATUS_VALUES)))

    cell = row["Test"].strip()
    # WHY: the document wraps a test cell in backticks, so the check accepts both forms.
    if len(cell) >= 2 and cell.startswith("`") and cell.endswith("`"):
        cell = cell[1:-1].strip()
    path = ""
    case = ""
    if cell == NO_TEST:
        if row["Priority"] == "P0":
            problems.append("row %s: a P0 row needs a test path, not %r" % (label, NO_TEST))
        return
    if TEST_SEPARATOR not in cell:
        problems.append("row %s: test cell %r is not 'path :: case name'" % (label, cell))
        return
    path, case = cell.split(TEST_SEPARATOR, 1)
    path = path.strip()
    case = case.strip()
    if not path or not case:
        problems.append("row %s: test cell %r needs both a path and a case name" % (label, cell))
        return
    if not stays_inside(root, path):
        problems.append("row %s: test path must stay inside the repository: %s" % (label, path))
        return
    file_path = os.path.join(root, path)
    if not os.path.isfile(file_path):
        problems.append("row %s: test path missing: %s" % (label, path))
        return
    try:
        with open(file_path, "r", encoding="utf-8") as handle:
            file_text = handle.read()
    except OSError as exc:
        problems.append("row %s: cannot read test file %s: %s" % (label, path, exc))
        return
    if not declares_case(file_text, case):
        problems.append("row %s: test case not found in %s: %s" % (label, path, case))


def check_matrix(root: str) -> int:
    """Check the matrix at the given root.

    Args:
        root: Repository root.

    Returns:
        Zero when the matrix passes, one on a finding.
    """
    text = read_text(root, MATRIX_REL)
    problems: List[str] = []
    rows = parse_rows(text, problems)
    for row in rows:
        check_row(row, root, problems)

    if problems:
        for problem in problems:
            print("hardening-matrix: %s" % problem)
        return 1
    p0_count = sum(1 for row in rows if row["Priority"] == "P0")
    print("hardening-matrix: ok (%d rows, %d P0 rows)" % (len(rows), p0_count))
    return 0

# ───────────────────────────────────────────────────────────────
# 6. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the matrix passes, one on a finding.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check the hardening matrix for complete rows and covered P0 tests.",
    )
    parser.parse_args(argv)
    return check_matrix(REPO_ROOT)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
