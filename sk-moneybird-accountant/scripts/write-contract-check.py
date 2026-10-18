#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: WRITE CONTRACT DRIFT CHECK
# ───────────────────────────────────────────────────────────────
"""Check the write contract restatements against the canonical contract.

Reads the canonical write contract in the migration shared mechanisms file and
parses its gate token sentence, its exit code sentence and its canonical
read-back sentence. Then it checks AGENTS.md, the accountant ROUTER.md and the
CLI SKILL.md each on its own, and the pointer lines of the accountant
SKILL.md, for drift: a missing pointer, a gate token or one of the two named
contract rules missing from the paragraphs that point at the contract, a
`--production` there without its production batch condition, a flag named on
a pointer line that the canonical set lacks, an exit code that is missing from
the CLI skill or unknown to the canonical set and a second differing
read-back definition. The
guard's own exit codes are read from the guard script and must stay a subset
of the canonical set, so the check keeps passing while a guard change is in
flight. The script reads the repository above it, uses the Python standard
library only and makes no network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/write-contract-check.py

Output:
    "write-contract: ok" on stdout when the tree matches, one line per problem
    otherwise. Exit 0 when the tree matches, 1 on drift and 2 on a missing
    file or a usage error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import List, NoReturn, Optional, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/write-contract-check.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

CANONICAL_REL = "sk-moneybird-accountant/references/migration/shared-mechanisms.md"

# WHY: the three restatements of the write contract. The paragraphs of each
# file that point at the contract must carry the full set of gate tokens and
# both rules, so a token that leaves the contract paragraph is caught even
# when another file or another line of the same file still names it.
RESTATEMENTS = (
    "AGENTS.md",
    "sk-moneybird-accountant/ROUTER.md",
    "cli-moneybird/SKILL.md",
)

# WHY: the accountant SKILL.md only points at the contract, so it is checked for
# a resolving pointer, its pointer line flags, its exit codes and its read-back
# line, but not for the full token set.
POINTER_FILES = ("sk-moneybird-accountant/SKILL.md",)

# WHY: this file owns the exit ladder, so it must carry the full canonical set.
LADDER_REL = "cli-moneybird/SKILL.md"

# WHY: the two skill files carry the read-back passage that points at the
# canonical sentence.
READBACK_FILES = ("sk-moneybird-accountant/SKILL.md", "cli-moneybird/SKILL.md")

GUARD_REL = "cli-moneybird/cli/moneybird-cli/moneybird-guard"

# WHY: the evidence rule and the idempotency rule are the two named rules of
# the canonical contract, so every restatement names them.
ELEMENT_WORDS = ("evidence", "idempotency")

POINTER_RE = re.compile(r"shared-mechanisms\.md#([a-z0-9][a-z0-9-]*)")
GATE_SENTENCE_RE = re.compile(r"The gate tokens are ([^.]*)\.")
EXIT_SENTENCE_RE = re.compile(r"exits with ([^.]*)\.")
READBACK_SENTENCE_RE = re.compile(r"Read-back means [^.]*\.")
BACKTICK_RE = re.compile(r"`([^`]+)`")
FLAG_RE = re.compile(r"`(--[a-z][a-z0-9-]*)`")
EXIT_MENTION_RE = re.compile(r"\bexit(?:s|ed|ing)?(?:\s+(?:with|code|status))*\s+([0-9]+)")
# WHY: the canonical contract allows `--production` only for an approved
# production batch, so a restatement that lists it without that condition
# tells an agent to set it on a pilot write.
PRODUCTION_FLAG = "--production"
PRODUCTION_CONDITION_RE = re.compile(r"`?--production`?\s+only for an approved production batch")
# WHY: the flag counts with or without backticks, so dropping the ticks does
# not hide an unconditional `--production` from the check.
PRODUCTION_MENTION_RE = re.compile(r"(?<![\w-])--production(?![\w-])")
DIE_RE = re.compile(r"\bdie\s+([0-9]+)")
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*$")
NUMBER_RE = re.compile(r"[0-9]+")
# WHY: a read-back sentence that defines the term differently from the
# canonical sentence is drift, while a line that only mentions read-back or
# points at the contract is not.
READBACK_DEF_RE = re.compile(
    r"read[- ]back\s+(is|are|was|were|means|meant|comes from|requires|must|refers to|consists of|happens|takes place|defined as)\b",
    re.IGNORECASE,
)

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
    """Read one repository file.

    Args:
        root: Repository root.
        relative: Path relative to the root.

    Returns:
        The file text.

    Raises:
        SystemExit: If the file cannot be read.
    """
    path = os.path.join(root, relative)
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative, exc))


def github_slug(heading: str) -> str:
    """Turn a heading into the GitHub anchor slug.

    Args:
        heading: Heading text without the leading hashes.

    Returns:
        Lowercase text with punctuation dropped and each space turned into
        its own hyphen.
    """
    lowered = heading.strip().lower()
    stripped = re.sub(r"[^\w\s\-]", "", lowered, flags=re.UNICODE)
    return re.sub(r"\s", "-", stripped)


def heading_slugs(text: str) -> Set[str]:
    """Collect the heading anchors of the canonical file.

    Args:
        text: Full markdown text.

    Returns:
        The set of heading slugs a pointer may resolve to.
    """
    slugs: Set[str] = set()
    for line in text.splitlines():
        match = HEADING_RE.match(line)
        if match:
            slug = github_slug(match.group(1))
            if slug:
                slugs.add(slug)
    return slugs


def canonical_parts(text: str) -> Tuple[Optional[Set[str]], Optional[Set[int]], Optional[str]]:
    """Parse the canonical gate tokens, exit codes and read-back sentence.

    Args:
        text: Full text of the canonical write contract.

    Returns:
        The gate token set, the exit code set and the canonical read-back
        sentence. A part is None when the canonical contract does not name it.
    """
    gate_flags: Optional[Set[str]] = None
    match = GATE_SENTENCE_RE.search(text)
    if match:
        gate_flags = {span.strip() for span in BACKTICK_RE.findall(match.group(1))}
    exits: Optional[Set[int]] = None
    match = EXIT_SENTENCE_RE.search(text)
    if match:
        exits = {int(value) for value in NUMBER_RE.findall(match.group(1))}
    sentence: Optional[str] = None
    match = READBACK_SENTENCE_RE.search(text)
    if match:
        sentence = match.group(0)
    return gate_flags, exits, sentence


def canonical_flags(gate_flags: Set[str]) -> Set[str]:
    """List the canonical gate tokens that are CLI flags.

    Args:
        gate_flags: Canonical gate token set.

    Returns:
        The tokens that start with two hyphens and carry no value.
    """
    return {flag for flag in gate_flags if re.fullmatch(r"--[a-z][a-z0-9-]*", flag)}

# ───────────────────────────────────────────────────────────────
# 4. RESTATEMENT CHECKS
# ───────────────────────────────────────────────────────────────

def check_pointer(relative: str, text: str, anchors: Set[str], problems: List[str]) -> List[int]:
    """Check the pointer to the canonical contract in one restatement.

    Args:
        relative: Path of the restatement, used in problem lines.
        text: Full text of the restatement.
        anchors: Heading anchors the canonical file offers.
        problems: Problem list to append to.

    Returns:
        The line numbers that carry a pointer.
    """
    lines = text.splitlines()
    found = False
    pointer_lines: List[int] = []
    for number, line in enumerate(lines, 1):
        for anchor in POINTER_RE.findall(line):
            found = True
            if anchor not in anchors:
                problems.append("%s:%d: pointer anchor does not resolve: %s" % (relative, number, anchor))
            else:
                pointer_lines.append(number)
    if not found:
        problems.append("%s: pointer missing" % relative)
    return pointer_lines


def contract_paragraphs(text: str, pointer_lines: List[int]) -> str:
    """Join the paragraphs of one file that point at the contract.

    A paragraph is a run of non-blank lines, so a bullet list counts as one.

    Args:
        text: Full text of the file.
        pointer_lines: Line numbers that carry a pointer.

    Returns:
        The text of every paragraph that holds a pointer line, in file order.
    """
    lines = text.splitlines()
    chosen: List[int] = []
    for number in pointer_lines:
        start = number - 1
        while start > 0 and lines[start - 1].strip():
            start -= 1
        end = number - 1
        while end + 1 < len(lines) and lines[end + 1].strip():
            end += 1
        for index in range(start, end + 1):
            if index not in chosen:
                chosen.append(index)
    return "\n".join(lines[index] for index in sorted(chosen))


def check_gate_flags(relative: str, text: str, gate_flags: Set[str], pointer_lines: List[int], problems: List[str]) -> None:
    """Check the gate tokens of one restatement.

    Every canonical token must appear in the paragraphs that point at the
    contract, `--production` there must carry its production batch condition,
    and a flag named on a pointer line must belong to the canonical set.

    Args:
        relative: Path of the restatement, used in problem lines.
        text: Full text of the restatement.
        gate_flags: Canonical gate token set.
        pointer_lines: Line numbers that carry a pointer.
        problems: Problem list to append to.
    """
    paragraphs = contract_paragraphs(text, pointer_lines)
    for flag in sorted(gate_flags):
        if flag not in paragraphs:
            problems.append("%s: gate token missing from the contract paragraph: %s" % (relative, flag))
    named = len(PRODUCTION_MENTION_RE.findall(paragraphs))
    if named and len(PRODUCTION_CONDITION_RE.findall(paragraphs)) < named:
        problems.append("%s: %s named without its production batch condition" % (relative, PRODUCTION_FLAG))
    check_pointer_flags(relative, text, gate_flags, pointer_lines, problems)


def check_pointer_flags(relative: str, text: str, gate_flags: Set[str], pointer_lines: List[int], problems: List[str]) -> None:
    """Check that every flag on a pointer line belongs to the canonical set.

    Args:
        relative: Path of one file, used in problem lines.
        text: Full text of that file.
        gate_flags: Canonical gate token set.
        pointer_lines: Line numbers of that file that carry a pointer.
        problems: Problem list to append to.
    """
    flags = canonical_flags(gate_flags)
    lines = text.splitlines()
    for number in pointer_lines:
        for flag in FLAG_RE.findall(lines[number - 1]):
            if flag not in flags:
                problems.append("%s:%d: gate token not in the canonical set: %s" % (relative, number, flag))


def check_elements(relative: str, text: str, pointer_lines: List[int], problems: List[str]) -> None:
    """Check that the contract paragraphs of one restatement name the two rules.

    Args:
        relative: Path of the restatement, used in problem lines.
        text: Full text of the restatement.
        pointer_lines: Line numbers that carry a pointer.
        problems: Problem list to append to.
    """
    paragraphs = contract_paragraphs(text, pointer_lines)
    for word in ELEMENT_WORDS:
        if word not in paragraphs:
            problems.append("%s: contract rule missing from the contract paragraph: %s" % (relative, word))


def check_exits(relative: str, text: str, exits: Set[int], problems: List[str]) -> None:
    """Check the exit codes one restatement names.

    A mention outside the canonical set is drift. The ladder file must name
    every canonical exit.

    Args:
        relative: Path of the restatement, used in problem lines.
        text: Full text of the restatement.
        exits: Canonical exit code set.
        problems: Problem list to append to.
    """
    mentioned = {int(value) for value in EXIT_MENTION_RE.findall(text)}
    for value in sorted(mentioned - exits):
        problems.append("%s: exit code not in the canonical set: %d" % (relative, value))
    if relative == LADDER_REL:
        for value in sorted(exits - mentioned):
            problems.append("%s: exit code missing: %d" % (relative, value))


def check_readback(relative: str, text: str, sentence: str, problems: List[str]) -> None:
    """Check the read-back sentence of one restatement.

    A line that defines read-back differently from the canonical sentence is
    drift. The two skill files must carry a read-back line with a pointer.

    Args:
        relative: Path of the restatement, used in problem lines.
        text: Full text of the restatement.
        sentence: The canonical read-back sentence.
        problems: Problem list to append to.
    """
    pointer_line = False
    for number, line in enumerate(text.splitlines(), 1):
        if "read-back" in line and POINTER_RE.search(line):
            pointer_line = True
        if READBACK_DEF_RE.search(line) and sentence not in line:
            problems.append("%s:%d: read-back definition differs from the canonical sentence" % (relative, number))
    if relative in READBACK_FILES and not pointer_line:
        problems.append("%s: read-back pointer missing" % relative)

# ───────────────────────────────────────────────────────────────
# 5. CANONICAL AND GUARD CHECKS
# ───────────────────────────────────────────────────────────────

def check_canonical(text: str, sentence: Optional[str], problems: List[str]) -> None:
    """Check the canonical contract against itself.

    Args:
        text: Full text of the canonical write contract.
        sentence: The canonical read-back sentence, when one was parsed.
        problems: Problem list to append to.
    """
    if sentence is None:
        problems.append("%s: the canonical read-back sentence is missing" % CANONICAL_REL)
        return
    count = text.count(sentence)
    if count != 1:
        problems.append("%s: the canonical read-back sentence appears %d times" % (CANONICAL_REL, count))


def check_guard(root: str, exits: Set[int], problems: List[str]) -> None:
    """Check the guard exit codes against the canonical set.

    The guard may lag the documented set while a change is in flight, so its
    codes must stay a subset of the canonical set and no more.

    Args:
        root: Repository root.
        exits: Canonical exit code set.
        problems: Problem list to append to.
    """
    text = read_text(root, GUARD_REL)
    codes = {int(value) for value in DIE_RE.findall(text)}
    if not codes:
        problems.append("%s: no guard exit code found" % GUARD_REL)
    for value in sorted(codes - exits):
        problems.append("%s: guard exit code not in the canonical set: %d" % (GUARD_REL, value))

# ───────────────────────────────────────────────────────────────
# 6. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the drift check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the tree matches, one on drift.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check the write contract restatements against the canonical contract.",
    )
    parser.parse_args(argv)
    root = REPO_ROOT

    canonical = read_text(root, CANONICAL_REL)
    gate_flags, exits, sentence = canonical_parts(canonical)
    problems: List[str] = []
    if gate_flags is None:
        problems.append("%s: the canonical contract does not name the gate tokens" % CANONICAL_REL)
        gate_flags = set()
    if exits is None:
        problems.append("%s: the canonical contract does not name the exit codes" % CANONICAL_REL)
        exits = set()
    anchors = heading_slugs(canonical)

    for relative in RESTATEMENTS + POINTER_FILES:
        text = read_text(root, relative)
        pointer_lines = check_pointer(relative, text, anchors, problems)
        if relative in RESTATEMENTS:
            check_gate_flags(relative, text, gate_flags, pointer_lines, problems)
            check_elements(relative, text, pointer_lines, problems)
        else:
            check_pointer_flags(relative, text, gate_flags, pointer_lines, problems)
        check_exits(relative, text, exits, problems)
        check_readback(relative, text, sentence or "", problems)

    check_canonical(canonical, sentence, problems)
    check_guard(root, exits, problems)

    if problems:
        for problem in sorted(set(problems)):
            print("write-contract: %s" % problem)
        return 1
    print("write-contract: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
