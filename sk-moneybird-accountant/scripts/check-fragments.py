#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: FRAGMENT AND LINK CHECKER
# ───────────────────────────────────────────────────────────────
"""Check every relative markdown link and section id in the skill family.

Scans the repository AGENTS.md, README.md and the markdown of the three skill
folders for relative links, resolves each path and each fragment, and reports
every miss. A link label that reads like a path is checked too: it must
resolve beside its page or end the target path, so a categoryless label
cannot silently name a file another folder holds. A fragment matches an
explicit anchor line or a heading slug drawn the GitHub way, and a slug that
resolves only through a duplicate suffix is rejected. Every year topic file
must hold its section ids in order: eight in a flat topic file, and the
subset that a topic split part carries. External URLs, images and links
inside fenced code blocks are skipped, and the script makes no network call.
Output is sorted and byte-stable.

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
from typing import Dict, Iterator, List, NoReturn, Optional, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/check-fragments.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# WHY: an allowlist of scan roots keeps the private folders out by construction.
SCAN_ROOTS = ("AGENTS.md", "README.md", "SKILL.md", "sk-moneybird-accountant", "cli-jortt", "cli-moneybird")
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

# WHY: a year folder holds three files beside its topic files, the year README,
# the year changelog and the year change note. None of the three carries the
# eight section ids.
YEAR_NON_TOPIC_NAMES = frozenset(("README.md", "changelog.md", "changes.md"))

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

# WHY: a topic split keeps the eight topic sections in four part files, so
# each part is held only to the sections it carries.
SPLIT_TOPIC_SECTIONS = {
    "figures.md": ("1-overview", "2-key-figures"),
    "rules.md": ("3-how-it-works",),
    "examples.md": ("4-worked-examples",),
    "notes.md": (
        "5-changes",
        "6-in-the-books",
        "7-open-points",
        "8-related-resources",
    ),
}

Problem = Tuple[str, int, str, str]

# WHY: a section that opens with a positional reference hands back text whose
# referent sits elsewhere, so the count is reported beside the link findings.
# The lint counts against a threshold and rewrites nothing, because a
# mechanical rewrite can drop the referent the sentence needs.
POSITIONAL_WINDOW = 220
POSITIONAL_THRESHOLD_PERCENT = 15
POSITIONAL_MARKERS = (
    "below",
    "above",
    "following",
    "this section",
    "this file",
    "this page",
    "as follows",
    "hieronder",
    "hierboven",
    "onderstaand",
    "onderstaande",
    "bovenstaand",
    "bovenstaande",
    "volgende",
    "deze sectie",
    "dit bestand",
    "deze pagina",
    "verderop",
)
H2_RE = re.compile(r"^##\s+\S")

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


def find_links(path: str) -> Iterator[Tuple[int, str, str]]:
    """Yield the relative links one source file holds.

    Args:
        path: Absolute path of the markdown file.

    Yields:
        Triples of line number, link label and raw link target. Inline links
        and reference definitions are both included. External URLs and images
        are left out. A reference definition names its target without a
        label, so its empty label checks nothing.
    """
    for number, line in visible_lines(path):
        for match in LINK_RE.finditer(line):
            # WHY: a target right after a bang is an image, not a link.
            if match.start() > 0 and line[match.start() - 1] == IMAGE_PREFIX:
                continue
            target = match.group(2).strip()
            if is_relative(target):
                yield number, match.group(1).strip(), target
        definition = REFERENCE_RE.match(line)
        if definition:
            target = (definition.group(1) or definition.group(2)).strip()
            if is_relative(target):
                yield number, "", target


def label_problem(path: str, label: str, target: str) -> Optional[str]:
    """Return the reason a path-shaped link label does not name its link target.

    A label that reads like a relative path can drift from the target while
    the target still resolves, so the two are compared. A descriptive label
    carries no path and is skipped. A path label passes when it resolves
    beside the page, as a relative label may, or when it ends the target path,
    which binds a categoryless label to the file the link opens.

    Args:
        path: Absolute path of the source file.
        label: Link text.
        target: Raw link target.

    Returns:
        The reason string, or None when the label passes or is descriptive.
    """
    if "/" not in label or not label.endswith(".md"):
        return None
    if any(char.isspace() for char in label) or SCHEME_RE.match(label):
        return None
    if os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), label))):
        return None
    target_path, _, _ = target.partition("#")
    if target_path:
        resolved = os.path.normpath(os.path.join(os.path.dirname(path), target_path))
    else:
        resolved = path
    if resolved.endswith("/" + label):
        return None
    return "label-mismatch"


def check_links(path: str) -> Tuple[int, int, List[Tuple[int, str, str]]]:
    """Check every relative link in one source file.

    Args:
        path: Absolute path of the source file.

    Returns:
        Link count, fragment-link count and the problems found, each as a
        line number, a link marker and a reason. The marker is the link label
        for a label problem and the raw target otherwise.
    """
    links = 0
    fragments = 0
    problems: List[Tuple[int, str, str]] = []
    for number, label, target in find_links(path):
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
        label_reason = label_problem(path, label, target)
        if label_reason is not None:
            problems.append((number, label, label_reason))
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
        True for a markdown topic file below references, at any folder depth.
        A flat topic file sits directly in a year folder. A split topic file
        sits in a topic folder directly under a year folder and is one of
        figures.md, rules.md, examples.md and notes.md. The year README, the
        year changelog and the year change note are never topic files.
    """
    parts = relative_path.split("/")
    if len(parts) < 3 or "references" not in parts[:-2]:
        return False
    if parts[-1] in YEAR_NON_TOPIC_NAMES:
        return False
    if YEAR_DIR_RE.match(parts[-2]) is not None:
        return True
    # WHY: a topic split keeps one topic as a folder of four part files
    # directly under the year folder, so the part carries the section ids.
    return (
        len(parts) >= 4
        and YEAR_DIR_RE.match(parts[-3]) is not None
        and parts[-1] in SPLIT_TOPIC_SECTIONS
    )


def expected_section_ids(relative_path: str) -> Tuple[str, ...]:
    """Return the section ids one year topic file must carry.

    Args:
        relative_path: Path relative to the repository root.

    Returns:
        All eight ids for a flat topic file or for a file that is not one of
        the four split parts, and the subset of a split part otherwise:
        figures.md holds sections 1 and 2, rules.md section 3, examples.md
        section 4 and notes.md sections 5 to 8.
    """
    parts = relative_path.split("/")
    if len(parts) >= 4 and YEAR_DIR_RE.match(parts[-3]) is not None:
        return SPLIT_TOPIC_SECTIONS.get(parts[-1], SECTION_IDS)
    return SECTION_IDS


def check_section_ids(
    path: str, expected: Tuple[str, ...]
) -> List[Tuple[int, str, str]]:
    """Check the section ids of one year topic file.

    Args:
        path: Absolute path of the topic file.
        expected: The section ids the file must carry, in order.

    Returns:
        The problems found, each as a line number, the id and a reason.
        An empty list means the expected ids are present and in order.
    """
    found: List[Tuple[int, str]] = []
    headings: Dict[int, int] = {}
    for number, line in visible_lines(path):
        match = NUMBERED_H2_RE.match(line)
        if match:
            headings[int(match.group(1))] = number
        found.extend((number, value) for value in ANCHOR_RE.findall(line))
    values = [value for _, value in found]
    if values == list(expected):
        return []
    counts: Dict[str, int] = {}
    for value in values:
        counts[value] = counts.get(value, 0) + 1
    problems: List[Tuple[int, str, str]] = []
    for wanted in expected:
        if counts.get(wanted, 0) == 0:
            # WHY: the id starts with its section number, so a missing id is
            # reported at the heading of that section.
            section = int(wanted.split("-", 1)[0])
            problems.append((headings.get(section, 1), wanted, "missing-id"))
    for number, value in found:
        if value not in expected:
            problems.append((number, value, "unexpected-id"))
        elif counts[value] > 1:
            problems.append((number, value, "duplicate-id"))
    if problems:
        return problems
    for index, value in enumerate(values):
        if value != expected[index]:
            return [(found[index][0], value, "out-of-order")]
    return []


# ───────────────────────────────────────────────────────────────
# 6. POSITIONAL OPENING LINT
# ───────────────────────────────────────────────────────────────

def positional_openings(path: str) -> Tuple[int, int]:
    """Count the sections of one file that open with a positional reference.

    A section starts on its H2 heading line. Its opening is the text up to
    the window limit, with the heading, the anchor lines and the blank lines
    left out. A marker matches on a word boundary, without case.

    Args:
        path: Absolute path of the markdown file.

    Returns:
        A pair of the sections that open with a positional reference and the
        sections counted.
    """
    sections = 0
    positional = 0
    opening: Optional[str] = None
    for _, line in visible_lines(path):
        if H2_RE.match(line):
            if opening is not None:
                sections += 1
                if opening_matches(opening):
                    positional += 1
            opening = ""
            continue
        if opening is None:
            continue
        stripped = line.strip()
        if not stripped or stripped.startswith("<a ") or stripped.startswith("<!--"):
            continue
        if len(opening) < POSITIONAL_WINDOW:
            opening += " " + stripped
    if opening is not None:
        sections += 1
        if opening_matches(opening):
            positional += 1
    return positional, sections


def opening_matches(opening: str) -> bool:
    """Tell whether one section opening carries a positional reference.

    Args:
        opening: Text of the section opening, markers included.

    Returns:
        True when one marker occurs on a word boundary.
    """
    lowered = opening.lower()
    for marker in POSITIONAL_MARKERS:
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


def positional_report(root: str) -> Tuple[int, int]:
    """Count the positional openings of the whole corpus.

    Args:
        root: Repository root.

    Returns:
        A pair of the sections that open with a positional reference and the
        sections counted.
    """
    positional = 0
    sections = 0
    for path in markdown_files(root):
        file_positional, file_sections = positional_openings(path)
        positional += file_positional
        sections += file_sections
    return positional, sections


# ───────────────────────────────────────────────────────────────
# 7. REPORT
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
                for number, marker, reason in check_section_ids(
                    path, expected_section_ids(source)
                )
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
    positional, sections = positional_report(root)
    percent = (100 * positional / sections) if sections else 0
    print(
        "check-fragments: positional openings %d of %d sections (threshold %d%%, measured %.1f%%)"
        % (positional, sections, POSITIONAL_THRESHOLD_PERCENT, percent)
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
