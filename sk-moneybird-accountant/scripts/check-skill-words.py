#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SKILL WORD BUDGET CHECK
# ───────────────────────────────────────────────────────────────
"""Check every SKILL.md and ROUTER.md against the loading word budget.

Walks the repository for SKILL.md and ROUTER.md files and prints one line per file with its
word count and its verdict. A file above 3,000 words warns, a file above
4,000 words fails the run, and a missing or unreadable file stops the run with
exit code 2 and the path named. The hub file and the three packet files are
required: SKILL.md, sk-moneybird-accountant/SKILL.md, cli-moneybird/SKILL.md
and cli-jortt/SKILL.md. A word is a run of characters between two ASCII whitespace
characters (space, tab, newline, carriage return, form feed and vertical tab).
BSD `LC_ALL=C wc -w` counts the same way. GNU wc in the C locale skips a run
that holds no printable ASCII byte, such as a lone euro sign, so it reports
fewer words and is not the reference. The root is the repository that holds
this script. The script uses the Python standard library only and makes no
network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-skill-words.py

Output:
    One line per SKILL.md with its relative path, its word count and its
    verdict: "ok", "warn above 3,000" or "fail above 4,000". Exit 0 when
    every file is at or below the hard ceiling, 1 when a file is above it and
    2 on a missing or unreadable file or a usage error.
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

CHECKER = "sk-moneybird-accountant/scripts/check-skill-words.py"
TAG = "check-skill-words"
SCRIPT_FOLDER = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_FOLDER))

WARN_WORDS = 3000
FAIL_WORDS = 4000

# WHY: a packet's router loads beside its SKILL.md, so it carries the same
# budget, and a router left out of the walk would grow with no ceiling.
COUNTED_NAMES = ("ROUTER.md", "SKILL.md")

# WHY: the check covers the whole skill family, so a file the walk cannot
# reach is a finding rather than a file that passes by absence.
REQUIRED_FILES = (
    "SKILL.md",
    "cli-jortt/ROUTER.md",
    "cli-jortt/SKILL.md",
    "cli-moneybird/ROUTER.md",
    "cli-moneybird/SKILL.md",
    "sk-moneybird-accountant/ROUTER.md",
    "sk-moneybird-accountant/SKILL.md",
)

# WHY: a hidden folder holds the git store or a local tool checkout rather
# than the skill family, and these folders hold no live skill markdown. The
# spec packets keep backup copies of retired skills, and two of these folders
# hold private data this check must not read.
SKIP_FOLDERS = ("migration-workspace", "personal database", "specs")

# WHY: a word is a run of characters between two ASCII whitespace characters,
# the same rule on every platform, so a CI runner and a Mac report one count.
WORD_SEPARATORS = re.compile(r"[ \t\n\r\f\v]+")

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


def count_words(text: str) -> int:
    """Count the words in one file as runs between ASCII whitespace.

    Args:
        text: File text.

    Returns:
        The number of maximal runs of non-whitespace characters.
    """
    return len([word for word in WORD_SEPARATORS.split(text) if word])


def verdict(count: int) -> str:
    """Name the band one word count falls in.

    Args:
        count: Word count.

    Returns:
        "ok", "warn above 3,000" or "fail above 4,000".
    """
    if count > FAIL_WORDS:
        return "fail above {:,}".format(FAIL_WORDS)
    if count > WARN_WORDS:
        return "warn above {:,}".format(WARN_WORDS)
    return "ok"


def skill_files(root: str) -> List[str]:
    """Collect every SKILL.md and ROUTER.md under one repository root.

    Args:
        root: Repository root to walk.

    Returns:
        Repository-relative POSIX paths, sorted. The walk skips a hidden
        folder, the private workspace and the spec packets, and it does not
        follow a symlinked folder.
    """
    found: List[str] = []
    for folder, subfolders, files in os.walk(root):
        subfolders[:] = sorted(
            name
            for name in subfolders
            if name not in SKIP_FOLDERS and not name.startswith(".")
        )
        for name in COUNTED_NAMES:
            if name in files:
                found.append(os.path.relpath(os.path.join(folder, name), root).replace(os.sep, "/"))
    return sorted(found)


def read_text(path: str) -> str:
    """Read one file and name its path when it cannot be read.

    Args:
        path: File to read.

    Returns:
        File text, with undecodable bytes replaced.

    Raises:
        SystemExit: With code 2 when the file cannot be read.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (path, exc))


# ───────────────────────────────────────────────────────────────
# 4. CHECK
# ───────────────────────────────────────────────────────────────

def check_root(root: str) -> int:
    """Check every SKILL.md under one repository root.

    Args:
        root: Repository root to check.

    Returns:
        Zero when every file is at or below the hard ceiling, 1 when a file
        is above it and 2 when a required file is missing or unreadable.
    """
    found = skill_files(root)
    for relative in REQUIRED_FILES:
        if relative not in found or not os.path.isfile(os.path.join(root, relative)):
            fail("missing or unreadable skill file: %s" % os.path.join(root, relative))
    over_budget = False
    for relative in found:
        count = count_words(read_text(os.path.join(root, relative)))
        label = verdict(count)
        if label.startswith("fail"):
            over_budget = True
        print("%s: %s %d words, %s" % (TAG, relative, count, label))
    return 1 if over_budget else 0


# ───────────────────────────────────────────────────────────────
# 5. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the word check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when every file is within budget, one when a file is above the
        hard ceiling.

    Raises:
        SystemExit: If a required file is missing or unreadable.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check every SKILL.md and ROUTER.md against the loading word budget.",
    )
    parser.parse_args(argv)
    return check_root(REPO_ROOT)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
