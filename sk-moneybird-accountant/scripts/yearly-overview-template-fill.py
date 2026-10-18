#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: YEARLY OVERVIEW TEMPLATE FILL
# ───────────────────────────────────────────────────────────────
"""Lint the yearly overview template with an in-memory synthetic fill.

The template header declares a closed token list and the repeat markers. This
checker reads that list, strips the header comment, keeps one copy of every
repeat block and substitutes one synthetic value per token. It asserts that the
body uses exactly the declared tokens, that the repeat markers pair up and that
every repeat block holds a token of its own. It then asserts that no brace
token survives the fill, that no remote asset remains and that the
prepared-not-filed line stays in both languages. The check proves structure
only and never a total.

Every value is synthetic and nothing is written. A filled copy for an Operator
is finance data and stays outside the tracked tree.

Usage:
    python3 -I sk-moneybird-accountant/scripts/yearly-overview-template-fill.py
    python3 -I sk-moneybird-accountant/scripts/yearly-overview-template-fill.py --template PATH

Options:
    --template PATH  Template to read. Defaults to the asset beside this script.

Output:
    One problem line per failed assertion, or a single ok line when every
    assertion holds. Exit 0 when the fill passes, 1 on a template problem and
    2 on a usage or read error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import os
import re
import sys
from typing import List, NoReturn, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/yearly-overview-template-fill.py"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TEMPLATE = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "assets", "yearly-overview", "yearly-overview-template.html")
)

HEADER_OPEN = "<!--"
HEADER_CLOSE = "-->"
FIELD_LIST_HEADING = "CLOSED TOKEN LIST."
OMITTED_FIELD_HEADING = "OMITTED FIELD."

# WHY: the placeholder syntax is a lowercase name in braces, so the check
# never confuses a CSS rule or a template comment with a value token.
FIELD_RE = re.compile(r"\{([a-z][a-z0-9_]*)\}")
# WHY: a filled copy is rejected on any brace token shape, not only a declared
# name, so a typo such as a space inside the braces still fails.
ANY_FIELD_RE = re.compile(r"\{[^{}\n]*\}")
REPEAT_RE = re.compile(r"<!--\s*(/?)repeat:([a-z_]+)\s*-->")
STYLE_RE = re.compile(r"<style\b[^>]*>.*?</style>", re.DOTALL | re.IGNORECASE)

REMOTE_RULES: List[Tuple[re.Pattern, str]] = [
    (re.compile(r"https?://", re.IGNORECASE), "a remote URL"),
    (re.compile(r"@import", re.IGNORECASE), "a CSS import"),
    (re.compile(r"\b(?:src|href)\s*=\s*[\"']//", re.IGNORECASE), "a protocol-relative asset"),
]
PREPARED_NOT_FILED = ("Opgesteld, niet ingediend", "Prepared, not filed")

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


def split_header(text: str, problems: List[str]) -> Tuple[str, str]:
    """Split the template into its body and its header comment.

    Args:
        text: Raw template text.
        problems: Problem list to append to.

    Returns:
        The body and the header comment. Both are empty when the header is
        missing or not closed.
    """
    stripped = text.lstrip()
    if HEADER_OPEN not in stripped:
        problems.append("the template holds no header comment")
        return "", ""
    start = text.index(HEADER_OPEN)
    end = text.find(HEADER_CLOSE, start)
    if end < 0:
        problems.append("the header comment is not closed")
        return "", ""
    return text[:start] + text[end + len(HEADER_CLOSE):], text[start:end + len(HEADER_CLOSE)]


def declared_tokens(header: str, problems: List[str]) -> List[str]:
    """Read the closed token list the header declares.

    Args:
        header: Header comment text.
        problems: Problem list to append to.

    Returns:
        The declared token names in order, with repeats kept.
    """
    if FIELD_LIST_HEADING not in header:
        problems.append("the header holds no closed token list")
        return []
    block = header.split(FIELD_LIST_HEADING, 1)[1]
    if OMITTED_FIELD_HEADING in block:
        block = block.split(OMITTED_FIELD_HEADING, 1)[0]
    fields = FIELD_RE.findall(block)
    if not fields:
        problems.append("the closed token list is empty")
    return fields


def pair_repeats(body: str, problems: List[str]) -> Tuple[str, List[Tuple[str, str]]]:
    """Pair the repeat markers and keep one copy of every repeat block.

    Args:
        body: Template body without the header comment.
        problems: Problem list to append to.

    Returns:
        The body without its repeat markers and one (block name, exemplar)
        pair per block. The body is returned unchanged when a marker is
        unmatched.
    """
    blocks: List[Tuple[str, str]] = []
    open_match = None
    for match in REPEAT_RE.finditer(body):
        closing = match.group(1) == "/"
        name = match.group(2)
        if not closing:
            if open_match is not None:
                problems.append(
                    "repeat marker repeat:%s has no closing marker" % open_match.group(2)
                )
            open_match = match
            continue
        if open_match is None:
            problems.append("repeat marker /repeat:%s has no opening marker" % name)
            continue
        if open_match.group(2) != name:
            problems.append(
                "repeat marker /repeat:%s closes repeat block %s" % (name, open_match.group(2))
            )
            open_match = None
            continue
        blocks.append((name, body[open_match.end():match.start()]))
        open_match = None
    if open_match is not None:
        problems.append("repeat marker repeat:%s has no closing marker" % open_match.group(2))
    if problems:
        return body, blocks
    if not blocks:
        problems.append("the template declares no repeat block")
    return REPEAT_RE.sub("", body), blocks


def check_block_tokens(original: str, blocks: List[Tuple[str, str]], problems: List[str]) -> None:
    """Check that each repeat block holds a token that appears nowhere else.

    Args:
        original: Body before the markers are removed.
        blocks: One (block name, exemplar) pair per block.
        problems: Problem list to append to.
    """
    for name, exemplar in blocks:
        own = [token for token in FIELD_RE.findall(exemplar) if original.count("{%s}" % token) == 1]
        if not own:
            problems.append("repeat block %s holds no token of its own" % name)


def check_filled(filled: str, problems: List[str]) -> None:
    """Check the filled copy for brace tokens, remote assets and the stop line.

    Args:
        filled: Filled template text.
        problems: Problem list to append to.
    """
    checkable = STYLE_RE.sub("", filled)
    match = ANY_FIELD_RE.search(checkable)
    if match:
        problems.append("a brace token survives the fill: %s" % match.group(0))
    for pattern, description in REMOTE_RULES:
        match = pattern.search(filled)
        if match:
            problems.append("the filled copy keeps %s: %s" % (description, match.group(0)))
    for phrase in PREPARED_NOT_FILED:
        if phrase not in filled:
            problems.append("the prepared-not-filed line is missing: %s" % phrase)


def fill_template(text: str, problems: List[str]) -> None:
    """Fill one template text in memory and collect every problem.

    Args:
        text: Raw template text.
        problems: Problem list to append to.
    """
    body, header = split_header(text, problems)
    declared = declared_tokens(header, problems)
    if problems:
        return
    declared_set = set(declared)
    used = FIELD_RE.findall(body)
    for token in sorted(set(used) - declared_set):
        problems.append("brace token {%s} is not in the closed token list" % token)
    for token in sorted(declared_set - set(used)):
        problems.append("the closed token list names {%s} but the body never uses it" % token)
    if problems:
        return

    paired, blocks = pair_repeats(body, problems)
    if problems:
        return
    check_block_tokens(body, blocks, problems)
    if problems:
        return

    filled = FIELD_RE.sub(lambda match: "value_" + match.group(1), paired)
    check_filled(filled, problems)

# ───────────────────────────────────────────────────────────────
# 4. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the fill and its checks.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the fill passes, one on a template problem.

    Raises:
        SystemExit: If an argument is invalid or the template cannot be read.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Lint the yearly overview template with a synthetic fill.",
    )
    parser.add_argument("--template", default=DEFAULT_TEMPLATE, metavar="PATH", help="template to read")
    args = parser.parse_args(argv)
    if not os.path.isfile(args.template):
        fail("missing template: %s" % args.template)
    try:
        with open(args.template, "r", encoding="utf-8") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (args.template, exc))

    problems: List[str] = []
    fill_template(text, problems)
    if problems:
        for problem in problems:
            print("yearly-overview-template: %s" % problem)
        return 1
    print("yearly-overview-template: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
