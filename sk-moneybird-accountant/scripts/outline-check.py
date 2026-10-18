#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: OUTLINE CHECKER
# ───────────────────────────────────────────────────────────────
"""Check the carry-forward rule over the year and general topic files.

A condition names its alternative or its default. A decision step is a step
that asks a question or opens with a decision verb, and it must name the
branch that applies when its condition fails. The check requires a branch
and never judges the branch: it looks for one of the documented branch
markers and says nothing about whether the branch is the right one. The rule
itself is stated in references/tax-rules/year-rollover.md, the authoring
note for the next year's files, and this is the packet's one outline checker.

The check reads the year topic files below references/tax-rules/, flat or
split, and the general topic files beside them. It skips fenced code blocks,
makes no network call and its output is sorted and byte-stable.

Usage:
    python3 -I sk-moneybird-accountant/scripts/outline-check.py
    python3 -I sk-moneybird-accountant/scripts/outline-check.py --check
    python3 -I sk-moneybird-accountant/scripts/outline-check.py --root DIR

Options:
    --check     Run the check. This is the default mode.
    --root DIR  Read another copy of the repository. Defaults to the root
                above this script.

Output:
    One "outline" line per decision step without an alternative branch, then
    the count line "outline-check: N decision steps, M without an
    alternative branch". Exit 0 when no decision step misses its branch, 1
    when one does and 2 on a read error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import Iterator, List, NoReturn, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/outline-check.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TAX_RULES = os.path.join("sk-moneybird-accountant", "references", "tax-rules")
YEAR_RE = re.compile(r"^20\d\d$")
TOPIC_PARTS = ("figures.md", "rules.md", "examples.md", "notes.md")

# WHY: a year folder holds three files beside its topic files, the year
# README, the year changelog and the year change note. None of the three is
# a topic file, so none carries a decision step the rule applies to.
YEAR_NON_TOPIC_NAMES = frozenset(("README.md", "changelog.md", "changes.md"))

FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
STEP_RE = re.compile(r"^(?:\d+\.|-)\s+(.*)$")
HEADING_RE = re.compile(r"^#{1,6}\s")

# WHY: the decision shapes are the two a step takes in this corpus, the
# question from the period-closing outline and the step that opens with a
# decision verb. Both are absent from the tree today, so the check is a
# guard for new content rather than a rewrite of old content.
DECISION_LEADS = (
    "decide",
    "choose",
    "determine",
    "check whether",
    "beslis",
    "kies",
    "bepaal",
)

# WHY: the branch markers are the alternative and default vocabulary that the
# decision sections use. The check requires one of them and never reads the
# branch, so a short pointer to the default is enough.
BRANCH_MARKERS = (
    "otherwise",
    "anders",
    "if not",
    "if no",
    "when not",
    "by default",
    "default",
    "in principle",
    "in principe",
    "standaard",
)

LINK_RE = re.compile(r"\[([^\]]*)\]\([^)]*\)")
BARE_URL_RE = re.compile(r"https?://\S+")
SPACE_RE = re.compile(r"\s+")
STEP_CUT = 90

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


def relative(root: str, path: str) -> str:
    """Render a path relative to the repository root.

    Args:
        root: Repository root.
        path: Absolute path to render.

    Returns:
        The relative path with forward slashes, so output is byte-stable.
    """
    return os.path.relpath(path, root).replace(os.sep, "/")


def read_lines(path: str) -> List[str]:
    """Read a text file as lines without their terminator.

    Args:
        path: Absolute path of the file.

    Returns:
        The lines of the file.

    Raises:
        SystemExit: If the file cannot be read.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read().splitlines()
    except OSError as exc:
        fail("cannot read %s: %s" % (path, exc))


def visible_lines(path: str) -> Iterator[Tuple[int, str]]:
    """Walk a file and leave out the lines inside fenced code blocks.

    Args:
        path: Absolute path of the markdown file.

    Yields:
        Pairs of line number and line text outside a fence. A fence closes
        only on a line whose marker uses the same character and a run at
        least as long as the opener.
    """
    # WHY: the open marker keeps its character and run length, so a shorter
    # inner fence stays content instead of closing the block.
    fence = None
    for number, line in enumerate(read_lines(path), 1):
        match = FENCE_RE.match(line)
        if match:
            marker = match.group(1)
            if fence is None:
                fence = (marker[0], len(marker))
            elif marker[0] == fence[0] and len(marker) >= fence[1]:
                fence = None
            continue
        if fence is None:
            yield number, line


def target_files(root: str) -> List[str]:
    """List the year and general topic files under references/tax-rules.

    Args:
        root: Repository root.

    Returns:
        Sorted absolute paths. A year topic file is a flat markdown file
        directly in a year folder or one of the four parts of a topic folder
        directly under a year folder. The general topic files sit under
        general/. The year README, the year changelog, the year change note
        and the cross-year files at the tax-rules level are left out.
    """
    base = os.path.join(root, TAX_RULES)
    if not os.path.isdir(base):
        fail("missing folder %s" % TAX_RULES)
    found: List[str] = []
    for directory, subdirectories, names in os.walk(base):
        subdirectories.sort()
        parts = os.path.relpath(directory, base).split(os.sep)
        in_year = any(YEAR_RE.match(part) for part in parts)
        in_general = parts and parts[0] == "general"
        if not in_year and not in_general:
            continue
        for name in sorted(names):
            if not name.endswith(".md"):
                continue
            if name in YEAR_NON_TOPIC_NAMES:
                continue
            # WHY: a split topic keeps one topic as a folder of four parts
            # directly under the year folder, so only those four count. A
            # flat topic file sits directly in the year folder.
            if in_year and not (
                len(parts) == 1 or (len(parts) == 2 and name in TOPIC_PARTS)
            ):
                continue
            found.append(os.path.join(directory, name))
    return sorted(found)


def strip_links(text: str) -> str:
    """Reduce one step text to its prose.

    Args:
        text: Raw step text.

    Returns:
        The text with every markdown link reduced to its label, every bare
        URL removed and every run of whitespace collapsed.
    """
    text = LINK_RE.sub(r"\1", text)
    text = BARE_URL_RE.sub(" ", text)
    return SPACE_RE.sub(" ", text).strip()


def steps(path: str) -> Iterator[Tuple[int, str]]:
    """Yield the steps of one file with their first line number.

    A step is a numbered list item or a bullet. Its text carries the
    continuation lines that follow it, so a wrapped step is read whole. The
    walk stops at a blank line, a heading or the next step.

    Args:
        path: Absolute path of the markdown file.

    Yields:
        Pairs of line number and step text.
    """
    current: Tuple[int, str] = (0, "")
    for number, line in visible_lines(path):
        match = STEP_RE.match(line)
        if match:
            if current[0]:
                yield current
            current = (number, match.group(1).strip())
            continue
        if not current[0]:
            continue
        stripped = line.strip()
        if not stripped or HEADING_RE.match(line):
            yield current
            current = (0, "")
            continue
        current = (current[0], current[1] + " " + stripped)
    if current[0]:
        yield current


def is_decision_step(text: str) -> bool:
    """Tell whether one step is a decision step.

    Args:
        text: Step text with its links already reduced to labels.

    Returns:
        True when the step asks a question or opens with a decision verb.
    """
    if "?" in text:
        return True
    lowered = text.lower()
    for lead in DECISION_LEADS:
        if lowered == lead or lowered.startswith(lead + " "):
            return True
    return False


def has_branch(text: str) -> bool:
    """Tell whether one step names an alternative or default branch.

    Args:
        text: Step text with its links already reduced to labels.

    Returns:
        True when one branch marker occurs on a word boundary.
    """
    lowered = text.lower()
    for marker in BRANCH_MARKERS:
        start = 0
        while True:
            index = lowered.find(marker, start)
            if index == -1:
                break
            before = lowered[index - 1] if index > 0 else " "
            after_index = index + len(marker)
            after = lowered[after_index] if after_index < len(lowered) else " "
            if not before.isalnum() and not after.isalnum():
                return True
            start = index + 1
    return False


# ───────────────────────────────────────────────────────────────
# 4. CHECK
# ───────────────────────────────────────────────────────────────

def check(root: str) -> Tuple[int, List[Tuple[str, int, str]]]:
    """Check every decision step of the year and general topic files.

    Args:
        root: Repository root.

    Returns:
        The number of decision steps found and the problems, each as a
        source path, a line number and a step snippet. A decision step with
        no branch marker in its text is a problem.
    """
    decisions = 0
    problems: List[Tuple[str, int, str]] = []
    for path in target_files(root):
        source = relative(root, path)
        for number, raw in steps(path):
            text = strip_links(raw)
            if not is_decision_step(text):
                continue
            decisions += 1
            if not has_branch(text):
                problems.append((source, number, text[:STEP_CUT]))
    return decisions, problems


# ───────────────────────────────────────────────────────────────
# 5. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when no decision step misses its branch, one otherwise.

    Raises:
        SystemExit: If the root is not a directory.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Check the carry-forward rule over the year and general topic files.",
    )
    parser.add_argument("--check", action="store_true", help="run the check, the default mode")
    parser.add_argument(
        "--root",
        default=REPO_ROOT,
        metavar="DIR",
        help="read another copy of the repository instead of the one above this script",
    )
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        fail("not a directory: %s" % args.root)
    decisions, problems = check(root)
    for source, number, snippet in sorted(problems):
        print("outline %s:%d no-alternative-branch %s" % (source, number, snippet))
    print(
        "outline-check: %d decision steps, %d without an alternative branch"
        % (decisions, len(problems))
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
