#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: FRAGMENT AND LINK CHECKER
# ───────────────────────────────────────────────────────────────
"""Check every relative markdown link and section id in the skill family.

Scans the repository AGENTS.md, README.md and the markdown of the three skill
folders for relative links, resolves each path and each fragment, and reports
every miss. A fragment matches an explicit anchor line or a heading slug drawn
the GitHub way, and a slug that resolves only through a duplicate suffix is
rejected. Every year topic file must hold the eight section ids in order.
External URLs, images and links inside fenced code blocks are skipped, and the
script makes no network call. Output is sorted and byte-stable.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-fragments.py
    python3 -I sk-moneybird-accountant/scripts/check-fragments.py --root DIR

Options:
    --root DIR  Read another copy of the repository. Defaults to the root
                above this script.

Output:
    One line per problem on stdout, then a summary line. Exit code 1 when a
    problem remains and 0 when the corpus is clean.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import Dict, Iterator, List, NoReturn, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/check-fragments.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# WHY: an allowlist of scan roots keeps the private folders out by construction.
SCAN_ROOTS = ("AGENTS.md", "README.md", "sk-moneybird-accountant", "cli-jortt", "cli-moneybird")
SKIP_DIRS = frozenset(("specs", ".git", "personal database", "migration-workspace"))

# WHY: the link pattern keeps a nested image as link text, so a badge whose
# text holds an image still counts as the link around it.
LINK_RE = re.compile(r"\[((?:[^\[\]]|\[[^\]\[]*\])*)\]\(([^)]*)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
ANCHOR_RE = re.compile(r'<a\s+id="([^"]+)"')
FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
# WHY: a reference definition holds a path without parentheses, so it needs
# its own pattern to reach the same path and fragment checks.
REFERENCE_RE = re.compile(r"^\s{0,3}\[[^\]]+\]:\s*(?:<([^>]+)>|(\S+))")
NUMBERED_H2_RE = re.compile(r"^##\s+(\d+)\b")
SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.\-]*:")
YEAR_DIR_RE = re.compile(r"^20\d\d$")
IMAGE_PREFIX = "!"

SECTION_IDS = (
    "1-overview",
    "2-key-figures",
    "3-how-it-works",
    "4-worked-examples",
    "5-changes",
    "6-in-the-books",
    "7-open-points",
    "8-related-resources",
)

Problem = Tuple[str, int, str, str]

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


def markdown_files(root: str) -> List[str]:
    """List the markdown files under the scan roots.

    Args:
        root: Repository root.

    Returns:
        Sorted absolute paths, with skipped folders left unread.
    """
    found: List[str] = []
    for entry in SCAN_ROOTS:
        path = os.path.join(root, entry)
        if os.path.isfile(path):
            found.append(path)
            continue
        if not os.path.isdir(path):
            continue
        for directory, subdirectories, names in os.walk(path):
            subdirectories[:] = [name for name in subdirectories if name not in SKIP_DIRS]
            for name in names:
                if name.endswith(".md"):
                    found.append(os.path.join(directory, name))
    return sorted(found)


def github_slug(heading: str) -> str:
    """Turn a heading into the GitHub anchor slug.

    Args:
        heading: Heading text without the leading hashes.

    Returns:
        Lowercase text with punctuation dropped, each space turned into its
        own hyphen and hyphens kept as written.
    """
    lowered = heading.strip().lower()
    stripped = re.sub(r"[^\w\s\-]", "", lowered, flags=re.UNICODE)
    # WHY: GitHub replaces each space on its own, so a dropped slash leaves
    # the two spaces around it as two hyphens.
    return re.sub(r"\s", "-", stripped)


def anchors(path: str) -> Tuple[Set[str], Set[str], Set[str]]:
    """Collect the anchors a target file offers.

    Args:
        path: Absolute path of the target file.

    Returns:
        Explicit anchor ids, plain heading slugs and duplicate-suffixed
        slugs. A slug carries a suffix when an earlier heading took it.
    """
    counts: Dict[str, int] = {}
    assigned: Set[str] = set()
    explicit: Set[str] = set()
    plain: Set[str] = set()
    suffixed: Set[str] = set()
    for _, line in visible_lines(path):
        explicit.update(ANCHOR_RE.findall(line))
        match = HEADING_RE.match(line)
        if not match:
            continue
        base = github_slug(match.group(2))
        if not base:
            continue
        # WHY: GitHub gives the second heading with a slug the same name
        # plus a counter, so the anchor is tracked as a suffixed one.
        taken = counts.get(base, 0)
        counts[base] = taken + 1
        if taken == 0 and base not in assigned:
            candidate = base
        else:
            step = taken if taken else 1
            while "%s-%d" % (base, step) in assigned:
                step += 1
            candidate = "%s-%d" % (base, step)
        assigned.add(candidate)
        if candidate == base:
            plain.add(base)
        else:
            suffixed.add(candidate)
    return explicit, plain, suffixed


# ───────────────────────────────────────────────────────────────
# 4. LINKS AND FRAGMENTS
# ───────────────────────────────────────────────────────────────

def is_relative(target: str) -> bool:
    """Tell whether a link target points inside the repository.

    Args:
        target: Raw link target with surrounding spaces removed.

    Returns:
        True when the target is a relative path or a bare fragment.
    """
    return bool(target) and not SCHEME_RE.match(target) and not target.startswith("//")


def find_links(path: str) -> Iterator[Tuple[int, str]]:
    """Yield the relative links one source file holds.

    Args:
        path: Absolute path of the markdown file.

    Yields:
        Pairs of line number and raw link target. Inline links and reference
        definitions are both included. External URLs and images are left
        out.
    """
    for number, line in visible_lines(path):
        for match in LINK_RE.finditer(line):
            # WHY: a target right after a bang is an image, not a link.
            if match.start() > 0 and line[match.start() - 1] == IMAGE_PREFIX:
                continue
            target = match.group(2).strip()
            if is_relative(target):
                yield number, target
        definition = REFERENCE_RE.match(line)
        if definition:
            target = (definition.group(1) or definition.group(2)).strip()
            if is_relative(target):
                yield number, target


def check_links(path: str) -> Tuple[int, int, List[Tuple[int, str, str]]]:
    """Check every relative link in one source file.

    Args:
        path: Absolute path of the source file.

    Returns:
        Link count, fragment-link count and the problems found, each as a
        line number, the raw target and a reason.
    """
    links = 0
    fragments = 0
    problems: List[Tuple[int, str, str]] = []
    for number, target in find_links(path):
        links += 1
        target_path, _, fragment = target.partition("#")
        if fragment:
            fragments += 1
        if target_path:
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target_path))
        else:
            # WHY: an anchor-only link points into the file that holds it.
            resolved = path
        if not os.path.exists(resolved):
            problems.append((number, target, "missing-path"))
            continue
        if not fragment:
            continue
        if not os.path.isfile(resolved):
            problems.append((number, target, "missing-fragment"))
            continue
        explicit, plain, suffixed = anchors(resolved)
        if fragment in explicit or fragment in plain:
            continue
        reason = "duplicate-suffix" if fragment in suffixed else "missing-fragment"
        problems.append((number, target, reason))
    return links, fragments, problems


# ───────────────────────────────────────────────────────────────
# 5. SECTION IDS
# ───────────────────────────────────────────────────────────────

def is_year_topic(relative_path: str) -> bool:
    """Tell whether a path is a year topic file.

    Args:
        relative_path: Path relative to the repository root.

    Returns:
        True for a markdown file directly in a year folder under references,
        other than the year README.
    """
    parts = relative_path.split("/")
    return (
        len(parts) >= 3
        and parts[-3] == "references"
        and YEAR_DIR_RE.match(parts[-2]) is not None
        and parts[-1] != "README.md"
    )


def check_section_ids(path: str) -> List[Tuple[int, str, str]]:
    """Check the eight section ids of one year topic file.

    Args:
        path: Absolute path of the topic file.

    Returns:
        The problems found, each as a line number, the id and a reason.
        An empty list means the eight ids are present and in order.
    """
    found: List[Tuple[int, str]] = []
    headings: Dict[int, int] = {}
    for number, line in visible_lines(path):
        match = NUMBERED_H2_RE.match(line)
        if match:
            headings[int(match.group(1))] = number
        found.extend((number, value) for value in ANCHOR_RE.findall(line))
    values = [value for _, value in found]
    if values == list(SECTION_IDS):
        return []
    counts: Dict[str, int] = {}
    for value in values:
        counts[value] = counts.get(value, 0) + 1
    problems: List[Tuple[int, str, str]] = []
    for position, wanted in enumerate(SECTION_IDS, 1):
        if counts.get(wanted, 0) == 0:
            problems.append((headings.get(position, 1), wanted, "missing-id"))
    for number, value in found:
        if value not in SECTION_IDS:
            problems.append((number, value, "unexpected-id"))
        elif counts[value] > 1:
            problems.append((number, value, "duplicate-id"))
    if problems:
        return problems
    for index, value in enumerate(values):
        if value != SECTION_IDS[index]:
            return [(found[index][0], value, "out-of-order")]
    return []


# ───────────────────────────────────────────────────────────────
# 6. REPORT
# ───────────────────────────────────────────────────────────────

def check(root: str) -> Tuple[int, int, List[Problem]]:
    """Check every markdown file under the scan roots.

    Args:
        root: Repository root.

    Returns:
        Link count, fragment-link count and every problem found, each as a
        source path, a line number, a link or id and a reason.
    """
    links = 0
    fragments = 0
    problems: List[Problem] = []
    for path in markdown_files(root):
        source = relative(root, path)
        file_links, file_fragments, file_problems = check_links(path)
        links += file_links
        fragments += file_fragments
        problems.extend(
            (source, number, marker, reason) for number, marker, reason in file_problems
        )
        if is_year_topic(source):
            problems.extend(
                (source, number, marker, reason)
                for number, marker, reason in check_section_ids(path)
            )
    return links, fragments, problems


# ───────────────────────────────────────────────────────────────
# 7. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when no problem remains, one otherwise.

    Raises:
        SystemExit: If the root is not a directory.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Check every relative markdown link and section id in the skill family.",
    )
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
    links, fragments, problems = check(root)
    for source, number, marker, reason in sorted(problems):
        print("fragment %s:%d %s %s" % (source, number, marker, reason))
    summary = "check-fragments: %d links, %d fragment links, %d problems" % (
        links,
        fragments,
        len(problems),
    )
    print(summary)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
