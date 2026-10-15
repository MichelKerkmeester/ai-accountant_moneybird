#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: YEARLY OVERVIEW TEMPLATE FILL
# ───────────────────────────────────────────────────────────────
"""Fill the yearly overview template from its own token list and check the result.

The template header declares a closed token list, the repeat markers and the
escaping rule. This checker reads that list, strips the header comment,
expands every repeat block and substitutes one synthetic value per token. It
then asserts that no brace token survives, that no remote asset remains, that
the synthetic values are HTML-escaped and that the prepared-not-filed line
stays in both languages. The check proves structure only and never a total.

Every value is synthetic. A filled copy for an Operator is finance data and
stays outside the tracked tree.

Usage:
    python3 -I sk-moneybird-accountant/scripts/yearly-overview-template-fill.py
    python3 -I sk-moneybird-accountant/scripts/yearly-overview-template-fill.py --template PATH --out PATH

Options:
    --template PATH  Template to read. Defaults to the asset beside this script.
    --out PATH       Write the filled copy here. Optional.
    --items N        Copies per repeat block. Defaults to 2.

Output:
    One problem line per failed assertion, or a single ok line when every
    assertion holds, plus the filled copy when --out is given. Exit 0 when the
    fill passes, 1 on a template problem and 2 on a usage or read error.
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
DEFAULT_ITEMS = 2

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


def synthetic_value(token: str) -> str:
    """Build the synthetic value for one token.

    Args:
        token: Token name without braces.

    Returns:
        A value that carries characters the escaping rule must encode.
    """
    return "S&<%s>" % token


def escape_html(value: str) -> str:
    """Encode the three HTML special characters in one value.

    Args:
        value: Raw value text.

    Returns:
        The value with ampersand, less-than and greater-than encoded.
    """
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


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


def expand_repeats(body: str, items: int, problems: List[str]) -> Tuple[str, List[Tuple[str, str]]]:
    """Expand every repeat block to the given number of exemplar copies.

    Args:
        body: Template body without the header comment.
        items: Copies per repeat block, at least one.
        problems: Problem list to append to.

    Returns:
        The expanded body and one (block name, exemplar) pair per block. The
        body is returned unchanged when a marker is unmatched.
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

    parts = []
    cursor = 0
    for match in REPEAT_RE.finditer(body):
        if match.group(1):
            continue
        closing = REPEAT_RE.search(body, match.end())
        # WHY: the scan above proved the pairs, so the next closing marker
        # after this opening marker belongs to it.
        while closing is not None and closing.group(2) != match.group(2):
            closing = REPEAT_RE.search(body, closing.end())
        if closing is None:
            problems.append("repeat marker repeat:%s has no closing marker" % match.group(2))
            return body, blocks
        parts.append(body[cursor:match.start()])
        parts.append(body[match.end():closing.start()] * items)
        cursor = closing.end()
    parts.append(body[cursor:])
    expanded = "".join(parts)
    if REPEAT_RE.search(expanded):
        problems.append("a repeat marker survives the expansion")
    if not blocks:
        problems.append("the template declares no repeat block")
    return expanded, blocks


def check_expansion_counts(
    original: str,
    expanded: str,
    blocks: List[Tuple[str, str]],
    items: int,
    problems: List[str],
) -> None:
    """Check that each repeat block holds the expected number of copies.

    Args:
        original: Body before the expansion.
        expanded: Body after the expansion.
        blocks: One (block name, exemplar) pair per block.
        items: Expected copies per block.
        problems: Problem list to append to.
    """
    for name, exemplar in blocks:
        own = [token for token in FIELD_RE.findall(exemplar) if original.count("{%s}" % token) == 1]
        if not own:
            problems.append("repeat block %s holds no token of its own" % name)
            continue
        count = expanded.count("{%s}" % own[0])
        if count != items:
            problems.append(
                "repeat block %s holds %d copies of its exemplar row, expected %d" % (name, count, items)
            )


def check_filled(
    filled: str,
    declared: List[str],
    problems: List[str],
) -> None:
    """Check the filled copy for fields, assets, escaping and the stop line.

    Args:
        filled: Filled template text.
        declared: Declared token names.
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
    for token in sorted(set(declared)):
        raw = synthetic_value(token)
        if raw in filled:
            problems.append("the value for {%s} was not HTML-escaped" % token)
        if escape_html(raw) not in filled:
            problems.append("the value for {%s} is missing after the fill" % token)


def fill_template(text: str, items: int, problems: List[str]) -> str:
    """Fill one template text and collect every problem.

    Args:
        text: Raw template text.
        items: Copies per repeat block.
        problems: Problem list to append to.

    Returns:
        The filled template, or an empty string when a problem stops the fill.
    """
    body, header = split_header(text, problems)
    declared = declared_tokens(header, problems)
    if problems:
        return ""
    declared_set = set(declared)
    used = FIELD_RE.findall(body)
    for token in sorted(set(used) - declared_set):
        problems.append("brace token {%s} is not in the closed token list" % token)
    for token in sorted(declared_set - set(used)):
        problems.append("the closed token list names {%s} but the body never uses it" % token)
    if problems:
        return ""

    expanded, blocks = expand_repeats(body, items, problems)
    if problems:
        return ""
    check_expansion_counts(body, expanded, blocks, items, problems)
    if problems:
        return ""

    filled = FIELD_RE.sub(lambda match: escape_html(synthetic_value(match.group(1))), expanded)
    check_filled(filled, declared, problems)
    if problems:
        return ""
    return filled

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
        description="Fill the yearly overview template and check its structure.",
    )
    parser.add_argument("--template", default=DEFAULT_TEMPLATE, metavar="PATH", help="template to read")
    parser.add_argument("--out", default="", metavar="PATH", help="write the filled copy here")
    parser.add_argument(
        "--items",
        type=int,
        default=DEFAULT_ITEMS,
        metavar="N",
        help="copies per repeat block, default 2",
    )
    args = parser.parse_args(argv)
    if args.items < 1:
        fail("--items must be at least 1")
    if not os.path.isfile(args.template):
        fail("missing template: %s" % args.template)
    try:
        with open(args.template, "r", encoding="utf-8") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (args.template, exc))

    problems: List[str] = []
    filled = fill_template(text, args.items, problems)
    if problems:
        for problem in problems:
            print("yearly-overview-template: %s" % problem)
        return 1
    if args.out:
        try:
            with open(args.out, "w", encoding="utf-8") as handle:
                handle.write(filled)
        except OSError as exc:
            fail("cannot write %s: %s" % (args.out, exc))
    print("yearly-overview-template: ok (%d copies per repeat block)" % args.items)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
