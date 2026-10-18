#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: RECORD DUTY HOIST
# ───────────────────────────────────────────────────────────────
"""Match the year-independent record duties and report whether a hoist has landed.

The section 6 IN THE BOOKS bullets of the year topic files can repeat one
duty in up to eight year folders, and a duty that holds in every year belongs
once in the general rules. This script performs the mechanical match and
reports the result. It rewrites no section: a bullet that only one or two
years carry is reported as unmatched and nothing moves.

The match compares two normalised forms of a bullet: the text with every
number and every link target removed. A bullet that normalises to the same
text in three or more year folders is year-independent. The owner section is
the RECORD AND INVOICE DUTIES section of
references/tax-rules/general/record-and-invoice-duties.md. A hoist has landed
when the count over the year topic files prints 0 and the owner section is
present, because a count of 0 beside a missing owner would also read as a
landed hoist.

Usage:
    python3 -I sk-moneybird-accountant/scripts/hoist-record-duties.py
    python3 -I sk-moneybird-accountant/scripts/hoist-record-duties.py --check

Options:
    --check     Print the count of year-independent duties that still sit in
                the year topic files and exit 1 when it is not zero or when
                the owner section is absent.

Output:
    One "match" line per matched duty with its year count, one "unmatched"
    line per bullet that only one or two years carry, then the count line.
    Exit 0 when the count is zero and the owner section is present, 1 when a
    duty still sits in the year files or the owner section is absent, and 2
    on a read error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import Dict, List, NoReturn, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/hoist-record-duties.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TAX_RULES_ROOT = os.path.join(REPO_ROOT, "sk-moneybird-accountant", "references", "tax-rules")
OWNER_PATH = os.path.join(
    REPO_ROOT, "sk-moneybird-accountant", "references", "tax-rules", "general", "record-and-invoice-duties.md"
)
# WHY: the owner file also carries a title and a routing list, so only its own
# numbered section proves that the hoisted duties have a home.
OWNER_HEADING_RE = re.compile(r"^## \d+\. RECORD AND INVOICE DUTIES[ \t]*$", re.M)
YEAR_RE = re.compile(r"^20\d\d$")
# WHY: a split part renumbers its headings from 1, so the topic-wide section
# number survives only in the explicit anchor under the heading. A flat topic
# file keeps the old "## 6." heading, which the second branch still reads.
SECTION_SIX_RE = re.compile(
    r"^## (?:\d+\.[^\n]*\n\s*<a id=\"6-in-the-books\"></a>|6\.[^\n]*\n)(.*?)(?=^## |\Z)", re.S | re.M
)
BULLET_PREFIX = "- "
NUMBER_RE = re.compile(r"\d+(?:[.,]\d+)*")
LINK_RE = re.compile(r"\[([^\]]*)\]\([^)]*\)")
SPACE_RE = re.compile(r"\s+")
YEAR_INDEPENDENT_MIN = 3

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
    print("%s: %s" % (os.path.basename(GENERATOR), message), file=sys.stderr)
    sys.exit(2)


def normalise(bullet: str) -> str:
    """Normalise one record-duty bullet for the mechanical match.

    Args:
        bullet: Bullet text without its marker.

    Returns:
        The text with every link reduced to its label, every number replaced
        by a placeholder and every run of whitespace collapsed.
    """
    text = LINK_RE.sub(r"\1", bullet)
    text = NUMBER_RE.sub("N", text)
    return SPACE_RE.sub(" ", text).strip().lower()

# ───────────────────────────────────────────────────────────────
# 4. MATCH
# ───────────────────────────────────────────────────────────────

def record_duties() -> List[Tuple[str, str, str]]:
    """Read every section 6 bullet of the year topic files.

    Returns:
        One (year, path, bullet) row per bullet, in path order.
    """
    rows: List[Tuple[str, str, str]] = []
    if not os.path.isdir(TAX_RULES_ROOT):
        fail("missing folder %s" % os.path.relpath(TAX_RULES_ROOT, REPO_ROOT))
    for directory, _, names in os.walk(TAX_RULES_ROOT):
        for name in sorted(names):
            if not name.endswith(".md"):
                continue
            path = os.path.join(directory, name)
            relative = os.path.relpath(path, REPO_ROOT)
            parts = relative.split(os.sep)
            year = next((part for part in parts if YEAR_RE.match(part)), None)
            if year is None or name in ("README.md", "changelog.md", "changes.md"):
                continue
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
            except OSError as exc:
                fail("cannot read %s: %s" % (relative, exc))
            match = SECTION_SIX_RE.search(text)
            if not match:
                continue
            for line in match.group(1).splitlines():
                if line.startswith(BULLET_PREFIX):
                    rows.append((year, relative, line[len(BULLET_PREFIX):].strip()))
    return rows


def matches(rows: List[Tuple[str, str, str]]) -> Dict[str, List[Tuple[str, str]]]:
    """Group the bullets by their normalised text.

    Args:
        rows: Result of record_duties().

    Returns:
        One entry per normalised bullet, with its year and path rows.
    """
    grouped: Dict[str, List[Tuple[str, str]]] = {}
    for year, path, bullet in rows:
        key = normalise(bullet)
        if not key:
            continue
        grouped.setdefault(key, []).append((year, path))
    return grouped


def owner_section_present() -> bool:
    """Tell whether the owner file holds the record duties section.

    Returns:
        True when the owner file exists and carries a numbered RECORD AND
        INVOICE DUTIES section heading.
    """
    if not os.path.isfile(OWNER_PATH):
        return False
    try:
        with open(OWNER_PATH, "r", encoding="utf-8", errors="replace") as handle:
            return OWNER_HEADING_RE.search(handle.read()) is not None
    except OSError as exc:
        fail("cannot read %s: %s" % (os.path.relpath(OWNER_PATH, REPO_ROOT), exc))

# ───────────────────────────────────────────────────────────────
# 5. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Run the report or check mode.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when no year-independent duty sits in the year files and the
        owner section is present, one otherwise.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Match the year-independent record duties and report what a hoist would move.",
    )
    parser.add_argument("--check", action="store_true", help="print the count and fail when it is not zero")
    args = parser.parse_args(argv)
    rows = record_duties()
    grouped = matches(rows)
    independent = {
        key: value
        for key, value in grouped.items()
        if len({year for year, _ in value}) >= YEAR_INDEPENDENT_MIN
    }
    if not args.check:
        for key in sorted(independent):
            years = sorted({year for year, _ in independent[key]})
            print("match %s years %s" % (key[:90], ",".join(years)))
        for key in sorted(grouped):
            if key not in independent:
                print("unmatched %s" % key[:90])
    owner = owner_section_present()
    print(
        "record duties: %d bullets, %d unique, %d year-independent, owner section %s"
        % (len(rows), len(grouped), len(independent), "present" if owner else "absent")
    )
    return 1 if independent or not owner else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
