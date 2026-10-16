#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ENGLISH FIRST CHECKER
# ───────────────────────────────────────────────────────────────
"""Check that the skill family writes English first and labels every term.

Reads both glossary files and the exceptions file, masks the places where
Dutch is the data, then reports every Dutch glossary term that stands
alone, every first use that drops its Dutch label, every label repeated as
its own text, every reversed pair and every bracketed label that no
glossary row names. An exceptions row that suppresses nothing is stale and
is reported too. The scan stays offline and its output is sorted and
byte-stable.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-english-first.py
    python3 -I sk-moneybird-accountant/scripts/check-english-first.py --root DIR
    python3 -I sk-moneybird-accountant/scripts/check-english-first.py --summary

Options:
    --root DIR   Read another copy of the repository. Defaults to the root
                 above this script.
    --rule NAME  Report only this rule, repeatable. One of residual,
                 first-use, doubled, reversed and unglossed. A stale
                 exception is reported only when residual or first-use is
                 selected.
    --summary    Print one count per rule and per area instead of the lines.

Output:
    One line per problem as path, line, rule and term, then a count line.
    The lines are sorted and byte-stable. Exit code 1 when a problem
    remains, 0 when the corpus is clean and 2 on a usage error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import re
import sys
from typing import Callable, Dict, List, NamedTuple, NoReturn, Pattern, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/check-english-first.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

GLOSSARY_MAIN = "sk-moneybird-accountant/references/glossary.md"
GLOSSARY_SINGLE = "sk-moneybird-accountant/references/glossary-additional-terms.md"
EXCEPTIONS_FILE = "sk-moneybird-accountant/assets/english-first-exceptions.json"
ROUTING_SIGNALS = "sk-moneybird-accountant/references/routing-signals.md"

# WHY: an allowlist of scan roots keeps private folders out by construction.
SCAN_ROOTS = ("AGENTS.md", "README.md", "sk-moneybird-accountant", "cli-moneybird", "cli-jortt")
SKIP_DIRS = frozenset(
    (
        "specs",
        "changelog",
        "benchmark",
        "evals",
        "route-replay",
        "scratch",
        "node_modules",
        "personal database",
        "migration-workspace",
    )
)

SOURCE_HEADERS = frozenset(("source", "sources", "bron", "title"))
# WHY: a playbook prompt is sent verbatim to the router, so its Dutch is test data (E1), never prose to label.
PROMPT_HEADERS = frozenset(("exact prompt",))
PROMPT_LINE_RE = re.compile(r"^(\s*(?:[-*]\s+)?(?:Prompt|Real user request):)(.*)$")
RULES = ("residual", "first-use", "doubled", "reversed", "unglossed")
STALE_RULE = "stale-exception"
SUPPRESSION_CHECKS = ("residual", "first-use")
OFFICIAL_NOTE = "official name"
PLAIN_NOTE = "plain"
ABBREVIATION_NOTE = "abbreviation"

AREA_GENERAL = "tax-rules general and root"
AREA_OUTSIDE = "outside tax-rules"
TAX_RULES_PREFIX = "sk-moneybird-accountant/references/tax-rules/"
DUTCH_TAX_RULES_ROOT = "sk-moneybird-accountant/references/dutch-tax-rules.md"
YEAR_DIR_RE = re.compile(r"^\d{4}$")

GLOSSARY_HEADER_RE = re.compile(r"^\|\s*English\s*\|\s*Dutch\s*\|\s*Note\s*\|\s*$", re.IGNORECASE)
DELIMITER_RE = re.compile(r"^\s*\|?[\s:|\-]*-[\s:|\-]*\|?\s*$")
# WHY: the label convention restarts at each H1 or H2 section, so deeper headings stay inside it.
SECTION_RE = re.compile(r"^#{1,2}\s")
FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
GENERATED_START_RE = re.compile(r"<!--\s*GENERATED:[^>]*:start\s*-->")
GENERATED_END_RE = re.compile(r"<!--\s*GENERATED:[^>]*:end\s*-->")
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
MD_LINK_RE = re.compile(r"\[[^\]\n]*\]\([^)\n]*\)")
URL_RE = re.compile(r"https?://[^\s\)\]\>]+")
# WHY: a bare host name such as wetten.overheid.nl is an address, not prose.
HOST_RE = re.compile(r"\b(?:[\w-]+\.)+(?:nl|eu|com|org|net|io)\b(?:/[^\s\)\]]*)?", re.IGNORECASE)
STRAIGHT_QUOTE_RE = re.compile(r'"[^"\n]*"')
CURLY_QUOTE_RE = re.compile(r"\u201c[^\u201d\n]*\u201d")
ART_RE = re.compile(r"\b(?:art\.|artikel)(?=\s|\d|$)", re.IGNORECASE)
PUBLICATION_RE = re.compile(
    r"\b(?:Kamerstukken|Kamerstuk|Stcrt|Stb|Staatsblad|Staatscourant)\b\.?"
)
BWBR_RE = re.compile(r"\bBWBR\d+", re.IGNORECASE)
ONDERDEEL_RE = re.compile(r"\bonderde(?:el|len)\s+[a-z0-9]{1,3}\b", re.IGNORECASE)
# WHY: a source table number and a dated act or decree identify a source, so they are citation data.
TABEL_RE = re.compile(r"\bTabel\s+[IVX\d]+\b")
DATED_ACT_RE = re.compile(
    r"\b(?:Besluit|Wet|Regeling) van \d{1,2} (?:januari|februari|maart|april|mei|juni|juli|augustus|september|oktober|november|december) \d{4}\b"
)
# WHY: a bracket holding a common English word is an English aside, not a Dutch label.
ENGLISH_FUNCTION_WORDS = frozenset(
    ("a", "an", "and", "or", "the", "of", "for", "on", "by", "to", "under", "against", "same", "page", "url", "category")
)
ECLI_RE = re.compile(r"\bECLI:[A-Za-z0-9:.\-]+")
# WHY: a return box keeps its Dutch name with its code, so it is data.
RUBRIEK_RE = re.compile(r"\brubriek(?:en)?\s+\d+[a-z]?\b", re.IGNORECASE)
PARENS_RE = re.compile(r"\([^()\n]*\)")
SPAN_RE = re.compile(r"\(([^()\n]*)\)")
# WHY: punctuation is its own piece, so "deductible. Costs" never reads as the term "deductible costs".
PIECE_RE = re.compile(r"[\w\-]+|[.,;:!?|]", re.UNICODE)

Row = Tuple[str, str, str]
Piece = Tuple[int, int, str]
Problem = Tuple[str, int, str, str]
TermEntry = Tuple[Tuple[str, ...], int]


class ExceptionRow(NamedTuple):
    """One row of the exceptions file after validation."""

    file: str
    term: str
    check: str
    rule: str
    reason: str


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


def blank(chars: List[str], start: int, end: int) -> None:
    """Replace one span of a mutable line with spaces.

    Args:
        chars: Mutable characters of the line.
        start: First index to blank.
        end: Index just after the last character to blank.
    """
    # WHY: a newline keeps its place so line numbers stay stable.
    for index in range(max(0, start), min(len(chars), end)):
        if chars[index] != "\n":
            chars[index] = " "


def spaces(match: "re.Match[str]") -> str:
    """Return one space per character of a regex match.

    Args:
        match: The match to blank out.

    Returns:
        A run of spaces as long as the match, so offsets stay put.
    """
    return " " * len(match.group())


def is_delimiter(line: str) -> bool:
    """Tell whether a line is a Markdown table delimiter row.

    Args:
        line: Raw line text.

    Returns:
        True when the line holds only pipes, colons, dashes and spaces and
        at least one dash.
    """
    return bool(DELIMITER_RE.match(line))


# ───────────────────────────────────────────────────────────────
# 4. MASKING
# ───────────────────────────────────────────────────────────────

def mask_frontmatter(lines: List[str]) -> List[str]:
    """Blank the YAML frontmatter at the top of a file.

    Args:
        lines: Lines of the markdown file.

    Returns:
        The lines with the frontmatter replaced by spaces.
    """
    if not lines or lines[0].strip() != "---":
        return lines
    masked: List[str] = []
    closed = False
    for index, line in enumerate(lines):
        if index == 0:
            masked.append(" " * len(line))
            continue
        if not closed:
            masked.append(" " * len(line))
            if line.strip() in ("---", "..."):
                closed = True
            continue
        masked.append(line)
    return masked


def mask_code_fences(lines: List[str]) -> List[str]:
    """Blank every fenced code block.

    Args:
        lines: Lines of the markdown file.

    Returns:
        The lines with each fence and its content replaced by spaces. A
        fence closes only on a run of the same character at least as long
        as its opener.
    """
    masked: List[str] = []
    fence: Tuple[str, int] = ("", 0)
    open_fence = False
    for line in lines:
        match = FENCE_RE.match(line)
        if match:
            marker = match.group(1)
            if not open_fence:
                fence = (marker[0], len(marker))
                open_fence = True
            elif marker[0] == fence[0] and len(marker) >= fence[1]:
                open_fence = False
            masked.append(" " * len(line))
            continue
        if open_fence:
            masked.append(" " * len(line))
        else:
            masked.append(line)
    return masked


def mask_inline_code(line: str) -> str:
    """Blank every inline code span on a line.

    Args:
        line: Masked line text.

    Returns:
        The line with each backtick span replaced by spaces. A span opens
        on a run of backticks and closes on the next run of at least the
        same length.
    """
    chars = list(line)
    index = 0
    while index < len(chars):
        if chars[index] != "`":
            index += 1
            continue
        end = index
        while end < len(chars) and chars[end] == "`":
            end += 1
        marker = line[index:end]
        close = line.find(marker, end)
        if close == -1:
            blank(chars, index, len(chars))
            break
        blank(chars, index, close + len(marker))
        index = close + len(marker)
    return "".join(chars)


def mask_generated_blocks(lines: List[str]) -> List[str]:
    """Blank every block between a generated start and end marker.

    Args:
        lines: Lines of the markdown file.

    Returns:
        The lines with the marker pair and the block between them replaced
        by spaces. An unmatched start marker blanks to the end of the file.
    """
    text = "\n".join(lines)
    chars = list(text)
    position = 0
    while True:
        start = GENERATED_START_RE.search(text, position)
        if start is None:
            break
        end = GENERATED_END_RE.search(text, start.end())
        stop = end.end() if end is not None else len(text)
        blank(chars, start.start(), stop)
        position = stop
    return "".join(chars).split("\n")


def mask_html_comments(lines: List[str]) -> List[str]:
    """Blank every HTML comment.

    Args:
        lines: Lines of the markdown file.

    Returns:
        The lines with each comment, across lines, replaced by spaces.
    """
    text = "\n".join(lines)
    chars = list(text)
    for match in COMMENT_RE.finditer(text):
        blank(chars, match.start(), match.end())
    return "".join(chars).split("\n")


def mask_links(line: str) -> str:
    """Blank Markdown link labels, link targets, bare URLs and host names.

    Args:
        line: Masked line text.

    Returns:
        The line with each label, target and URL replaced by spaces. A
        label holds a source title and a target holds an address, so
        neither is prose the rules read.
    """
    line = MD_LINK_RE.sub(spaces, line)
    line = URL_RE.sub(spaces, line)
    return HOST_RE.sub(spaces, line)


def mask_quotes(line: str) -> str:
    """Blank straight and curly double quoted text.

    Args:
        line: Masked line text.

    Returns:
        The line with each quoted span on the line replaced by spaces,
        because a quote holds official text.
    """
    line = STRAIGHT_QUOTE_RE.sub(spaces, line)
    return CURLY_QUOTE_RE.sub(spaces, line)


def publication_end(line: str, start: int) -> int:
    """Find the end of a publication citation run.

    Args:
        line: Raw line text.
        start: Index just after the publication keyword.

    Returns:
        The index after the last character of the run. Numbers, roman
        numerals, separators, spaces and the nr marker continue the run. A
        word after a space ends it.
    """
    index = start
    while index < len(line):
        char = line[index]
        if char in " \t":
            end = index
            while end < len(line) and line[end] in " \t":
                end += 1
            if end >= len(line):
                return end
            rest = line[end:]
            roman = re.match(r"[IVX]+\b", rest)
            if not (roman or re.match(r"\d", rest) or re.match(r"nr\.", rest, re.IGNORECASE)):
                return index
            index = end
            continue
        if char.isdigit() or char in "/-.,:":
            index += 1
            continue
        roman = re.match(r"[IVX]+\b", line[index:])
        if roman:
            index += roman.end()
            continue
        marker = re.match(r"nr\.", line[index:], re.IGNORECASE)
        if marker:
            index += marker.end()
            continue
        break
    return index


def mask_citations(line: str) -> str:
    """Blank legal citation runs.

    Args:
        line: Masked line text.

    Returns:
        The line with each article citation, each publication citation,
        each BWBR id, each ECLI id and each onderdeel letter replaced by
        spaces.
    """
    chars = list(line)
    for match in ART_RE.finditer(line):
        stop = match.end()
        while stop < len(line):
            char = line[stop]
            if char in ",)]":
                break
            if char == "." and (stop + 1 == len(line) or line[stop + 1].isspace()):
                break
            stop += 1
        blank(chars, match.start(), stop)
    # WHY: a publication name without a number is a title in prose, so only a numbered citation is data.
    for match in PUBLICATION_RE.finditer(line):
        end = publication_end(line, match.end())
        if re.search(r"\d", line[match.end():end]):
            blank(chars, match.start(), end)
    for match in BWBR_RE.finditer(line):
        blank(chars, match.start(), match.end())
    for match in ONDERDEEL_RE.finditer(line):
        blank(chars, match.start(), match.end())
    for match in ECLI_RE.finditer(line):
        blank(chars, match.start(), match.end())
    return "".join(chars)


def cell_ranges(line: str) -> List[Tuple[int, int]]:
    """Map each table cell of a line to its character range.

    Args:
        line: Raw table line.

    Returns:
        One pair of start and end index per split part, in order.
    """
    ranges: List[Tuple[int, int]] = []
    start = 0
    for part in line.split("|"):
        ranges.append((start, start + len(part)))
        start += len(part) + 1
    return ranges


def mask_cells(line: str, columns: Set[int]) -> str:
    """Blank the cells of one table row that sit under named headers.

    Args:
        line: Raw table body row.
        columns: Zero based cell indexes to blank.

    Returns:
        The row with each selected cell replaced by spaces.
    """
    if not columns:
        return line
    chars = list(line)
    for column, (start, end) in enumerate(cell_ranges(line)):
        if column in columns:
            blank(chars, start, end)
    return "".join(chars)


def mask_table_cells(lines: List[str]) -> List[str]:
    """Blank every body cell under a Source, Sources, Bron, Title or Exact Prompt header.

    Args:
        lines: Lines of the markdown file.

    Returns:
        The lines with the named source, title and prompt columns replaced
        by spaces until the table ends.
    """
    masked: List[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if (
            "|" in line
            and index + 1 < len(lines)
            and is_delimiter(lines[index + 1])
        ):
            header = line.split("|")
            columns = {
                position
                for position, cell in enumerate(header)
                if cell.strip().lower() in SOURCE_HEADERS | PROMPT_HEADERS
            }
            masked.append(line)
            masked.append(lines[index + 1])
            index += 2
            while (
                index < len(lines)
                and "|" in lines[index]
                and not is_delimiter(lines[index])
            ):
                masked.append(mask_cells(lines[index], columns))
                index += 1
            continue
        masked.append(line)
        index += 1
    return masked


def mask_prompt_line(line: str) -> str:
    """Blank the text of a playbook Prompt or Real user request line.

    Args:
        line: One markdown line.

    Returns:
        The line with everything after the label replaced by spaces, or
        the line unchanged when it is no prompt line.
    """
    match = PROMPT_LINE_RE.match(line)
    if not match:
        return line
    return match.group(1) + " " * len(match.group(2))


def masked_lines(path: str) -> List[str]:
    """Read a markdown file and blank every region the rules ignore.

    Args:
        path: Absolute path of the markdown file.

    Returns:
        The lines with masked characters replaced by spaces, so line
        numbers and columns stay put.
    """
    lines = read_lines(path)
    lines = mask_frontmatter(lines)
    lines = mask_code_fences(lines)
    lines = mask_generated_blocks(lines)
    lines = mask_html_comments(lines)
    lines = [mask_prompt_line(line) for line in lines]
    lines = [mask_inline_code(line) for line in lines]
    lines = [mask_links(line) for line in lines]
    lines = [mask_quotes(line) for line in lines]
    lines = [mask_citations(line) for line in lines]
    return mask_table_cells(lines)


def mask_data_codes(line: str) -> str:
    """Blank rubriek codes, source table numbers and dated acts.

    Args:
        line: Masked line text.

    Returns:
        The line with each rubriek code, each "Tabel" number and each
        dated act or decree replaced by spaces. Only the residual rule
        applies it, so a label such as "(Tabel I)" or "(rubriek 1d)" still
        counts for the other rules.
    """
    for pattern in (RUBRIEK_RE, TABEL_RE, DATED_ACT_RE):
        line = pattern.sub(spaces, line)
    return line


def mask_parentheses(line: str) -> str:
    """Blank every parenthesised span on a line.

    Args:
        line: Masked line text.

    Returns:
        The line with each bracketed span replaced by spaces, so a Dutch
        label inside brackets is not read as a leftover term.
    """
    return PARENS_RE.sub(spaces, line)


# ───────────────────────────────────────────────────────────────
# 5. GLOSSARY AND EXCEPTIONS
# ───────────────────────────────────────────────────────────────

def read_glossary_rows(root: str) -> List[Row]:
    """Read every body row of every glossary table.

    Args:
        root: Repository root.

    Returns:
        One row of English, Dutch and note per glossary term, in file
        order and without duplicates.

    Raises:
        SystemExit: If the main glossary file is missing.
    """
    rows: List[Row] = []
    for relative_path in (GLOSSARY_MAIN, GLOSSARY_SINGLE):
        path = os.path.join(root, relative_path)
        if not os.path.isfile(path):
            if relative_path == GLOSSARY_MAIN:
                fail("missing glossary: %s" % relative_path)
            continue
        in_table = False
        for line in read_lines(path):
            if GLOSSARY_HEADER_RE.match(line):
                in_table = True
                continue
            if not in_table:
                continue
            if is_delimiter(line):
                continue
            if not line.lstrip().startswith("|"):
                in_table = False
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) >= 3 and cells[0] and cells[1]:
                rows.append((cells[0], cells[1], cells[2]))
    unique: Dict[Row, None] = {}
    for row in rows:
        unique[row] = None
    return list(unique)


def load_exceptions(root: str) -> List[ExceptionRow]:
    """Read and validate the exceptions file.

    Args:
        root: Repository root.

    Returns:
        One validated row per exception. A missing file means no
        exceptions.

    Raises:
        SystemExit: If the file is malformed or a row carries a bad rule
        or check value.
    """
    path = os.path.join(root, EXCEPTIONS_FILE)
    if not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read %s: %s" % (EXCEPTIONS_FILE, exc))
    if not isinstance(data, dict):
        fail("malformed exceptions file: %s" % EXCEPTIONS_FILE)
    entries = data.get("exceptions")
    if not isinstance(entries, list):
        fail("malformed exceptions file: %s" % EXCEPTIONS_FILE)
    loaded: List[ExceptionRow] = []
    for entry in entries:
        if not isinstance(entry, dict):
            fail("malformed exceptions row in %s" % EXCEPTIONS_FILE)
        file = entry.get("file")
        term = entry.get("term")
        check = entry.get("check")
        rule = entry.get("rule")
        reason = entry.get("reason")
        if (
            not isinstance(file, str)
            or not file
            or not isinstance(term, str)
            or not term
            or not isinstance(reason, str)
        ):
            fail("malformed exceptions row in %s" % EXCEPTIONS_FILE)
        if check not in SUPPRESSION_CHECKS:
            fail("bad exceptions check %r in %s" % (check, EXCEPTIONS_FILE))
        if rule not in ("E1", "E2", "E3"):
            fail("bad exceptions rule %r in %s" % (rule, EXCEPTIONS_FILE))
        # WHY: a stored path is matched against a relative path that always
        # uses forward slashes.
        normalized = os.path.normpath(file.replace("\\", "/")).replace(os.sep, "/")
        loaded.append(ExceptionRow(normalized, term.lower(), check, rule, reason))
    return loaded


# ───────────────────────────────────────────────────────────────
# 6. CORPUS
# ───────────────────────────────────────────────────────────────

def corpus_files(root: str) -> List[str]:
    """List the markdown files the checker reads.

    Args:
        root: Repository root.

    Returns:
        Sorted absolute paths. Hidden folders, the named skip folders,
        both glossary files and the routing signal list are left out.
    """
    skipped = {
        os.path.normpath(os.path.join(root, name))
        for name in (GLOSSARY_MAIN, GLOSSARY_SINGLE, ROUTING_SIGNALS)
    }
    found: List[str] = []
    for entry in SCAN_ROOTS:
        path = os.path.join(root, entry)
        if os.path.isfile(path):
            found.append(path)
            continue
        if not os.path.isdir(path):
            continue
        for directory, subdirectories, names in os.walk(path):
            subdirectories[:] = [
                name
                for name in subdirectories
                if name not in SKIP_DIRS and not name.startswith(".")
            ]
            for name in names:
                if not name.endswith(".md"):
                    continue
                full = os.path.normpath(os.path.join(directory, name))
                if full not in skipped:
                    found.append(full)
    return sorted(found)


def area_of(relative_path: str) -> str:
    """Name the report area of one file.

    Args:
        relative_path: Path relative to the repository root.

    Returns:
        The year folder name for a tax year file, the general area name
        for the rest of the tax rules and the outside area name for every
        other file.
    """
    if relative_path == DUTCH_TAX_RULES_ROOT:
        return AREA_GENERAL
    if relative_path.startswith(TAX_RULES_PREFIX):
        head = relative_path[len(TAX_RULES_PREFIX):].split("/", 1)[0]
        if YEAR_DIR_RE.match(head):
            return "tax-rules %s" % head
        return AREA_GENERAL
    return AREA_OUTSIDE


# ───────────────────────────────────────────────────────────────
# 7. RULES
# ───────────────────────────────────────────────────────────────

def split_pieces(text: str) -> List[Piece]:
    """Split a line into word pieces with their character offsets.

    Args:
        text: Masked line text.

    Returns:
        Pairs of start and end offset plus the lowercased piece. A hyphen
        counts as a word character, so a term boundary is exact. Each
        punctuation mark is a piece of its own, so a term never spans one.
    """
    return [(match.start(), match.end(), match.group().lower()) for match in PIECE_RE.finditer(text)]


def term_pieces(term: str) -> Tuple[str, ...]:
    """Split a glossary term into its lowercased word pieces.

    Args:
        term: Glossary term.

    Returns:
        The piece sequence of the term.
    """
    return tuple(match.group().lower() for match in PIECE_RE.finditer(term))


def term_index(
    positions: List[int], rows: List[Row], pick: Callable[[Row], str]
) -> Dict[str, List[TermEntry]]:
    """Index a set of glossary terms by their first piece.

    Args:
        positions: Row positions to index.
        rows: All glossary rows.
        pick: Function that returns the term of a row.

    Returns:
        A map from first piece to the remaining pieces and the row
        position, so a line is scanned once for every term.
    """
    index: Dict[str, List[TermEntry]] = {}
    for position in positions:
        pieces = term_pieces(pick(rows[position]))
        if not pieces:
            continue
        index.setdefault(pieces[0], []).append((pieces[1:], position))
    return index


def find_matches(
    pieces: List[Piece], index: Dict[str, List[TermEntry]]
) -> List[Tuple[int, int, int]]:
    """Find every glossary term match in a split line.

    Args:
        pieces: Pieces of the masked line.
        index: Term index to match against.

    Returns:
        One triple of row position, start offset and end offset per match,
        in reading order.
    """
    found: List[Tuple[int, int, int]] = []
    count = len(pieces)
    for position in range(count):
        entries = index.get(pieces[position][2])
        if not entries:
            continue
        for rest, row_position in entries:
            if not rest:
                found.append((row_position, pieces[position][0], pieces[position][1]))
                continue
            end = position + len(rest)
            if end >= count:
                continue
            if all(pieces[position + offset + 1][2] == rest[offset] for offset in range(len(rest))):
                found.append((row_position, pieces[position][0], pieces[end][1]))
    return found


def outermost(
    matches: List[Tuple[int, int, int]], containers: List[Tuple[int, int, int]]
) -> List[Tuple[int, int, int]]:
    """Drop every match that sits inside a longer glossary match on the same line.

    Args:
        matches: Row position, start and end offset per match.
        containers: Every glossary match on the line, plain rows included.

    Returns:
        The matches no longer match contains, in reading order. "Income
        tax" inside "corporate income tax" names a different term, so the
        inner name needs no label of its own.
    """
    kept: List[Tuple[int, int, int]] = []
    for match in matches:
        _, start, end = match
        inside = any(
            other[1] <= start and end <= other[2] and (other[2] - other[1]) > (end - start)
            for other in containers
        )
        if not inside:
            kept.append(match)
    return kept


def split_sections(masked: List[str]) -> List[List[Tuple[int, str]]]:
    """Split a file into sections at its H1 and H2 headings.

    Args:
        masked: Masked lines of the file.

    Returns:
        One section per heading, as line number and line pairs. The
        heading line belongs to the section it opens. Text before the
        first heading forms a section of its own.
    """
    sections: List[List[Tuple[int, str]]] = []
    current: List[Tuple[int, str]] = []
    for index, line in enumerate(masked):
        if SECTION_RE.match(line):
            if current:
                sections.append(current)
                current = []
        current.append((index + 1, line))
    if current:
        sections.append(current)
    return sections


def is_label_span(text: str) -> bool:
    """Tell whether a text can stand as a repeated label.

    Args:
        text: Candidate span text.

    Returns:
        True when the text holds letters, digits, spaces, apostrophes or
        hyphens only and carries at least one letter.
    """
    if not text or not any(char.isalpha() for char in text):
        return False
    return all(char.isalnum() or char in " '-" for char in text)


def doubled_spans(line: str) -> List[str]:
    """Find every span repeated as its own bracketed label.

    Args:
        line: Masked line text.

    Returns:
        The repeated span as written before the bracket. The bracket must
        hold the same label text without case, and the span must start on
        a word boundary.
    """
    spans: List[str] = []
    index = 0
    while True:
        opened = line.find("(", index)
        if opened == -1:
            break
        closed = line.find(")", opened + 1)
        if closed == -1:
            break
        inner = line[opened + 1:closed].strip()
        if inner and is_label_span(inner):
            before = line[:opened].rstrip()
            if len(before) >= len(inner) and before.lower().endswith(inner.lower()):
                start = len(before) - len(inner)
                first = before[start:]
                boundary = start == 0 or not (before[start - 1].isalnum() or before[start - 1] in "_-")
                if boundary and is_label_span(first):
                    spans.append(first)
        index = closed + 1
    return spans


def unglossed_spans(
    line: str, dutch_words: Set[str], english_words: Set[str], dutch_terms: Set[str]
) -> List[str]:
    """Find every bracketed span that looks like an unnamed Dutch label.

    Args:
        line: Masked line text.
        dutch_words: Lowercased words of every glossary Dutch term.
        english_words: Lowercased words of every glossary English term.
        dutch_terms: Lowercased Dutch terms of both glossaries.

    Returns:
        The lowercased span of each bracket that holds one to six letter
        words, contains a Dutch glossary word, is not itself a Dutch term
        and is not made only of English glossary words.
    """
    spans: List[str] = []
    for match in SPAN_RE.finditer(line):
        content = match.group(1).strip()
        if not content:
            continue
        if not all(char.isalpha() or char in " '-" for char in content):
            continue
        words = content.split()
        if not 1 <= len(words) <= 6:
            continue
        lowered = content.lower()
        if lowered in dutch_terms:
            continue
        if not any(word.lower() in dutch_words for word in words):
            continue
        if all(word.lower() in english_words for word in words):
            continue
        if any(word.lower() in ENGLISH_FUNCTION_WORDS for word in words):
            continue
        spans.append(lowered)
    return spans


def check_file(
    relative_path: str,
    path: str,
    rows: List[Row],
    dutch_index: Dict[str, List[TermEntry]],
    first_index: Dict[str, List[TermEntry]],
    english_index: Dict[str, List[TermEntry]],
    tails: List[Pattern[str]],
    dutch_words: Set[str],
    english_words: Set[str],
    dutch_terms: Set[str],
    selected: Set[str],
) -> List[Problem]:
    """Check one markdown file against the selected rules.

    Args:
        relative_path: Path relative to the repository root.
        path: Absolute path of the markdown file.
        rows: Glossary rows.
        dutch_index: Dutch term index.
        first_index: First use term index.
        english_index: Index of every English glossary name.
        tails: Compiled reversed pair pattern per glossary row.
        dutch_words: Lowercased words of every glossary Dutch term.
        english_words: Lowercased words of every glossary English term.
        dutch_terms: Lowercased Dutch terms of both glossaries.
        selected: Rule names to run.

    Returns:
        The problems found, each as path, line number, rule and term.
    """
    problems: List[Problem] = []
    masked = masked_lines(path)

    if "residual" in selected:
        for number, line in enumerate(masked, 1):
            residual = mask_parentheses(mask_data_codes(line))
            # WHY: "opgaaf" inside the form name "Opgaaf startende onderneming" is part of that name.
            dutch_matches = find_matches(split_pieces(residual), dutch_index)
            for row_position, _, _ in outermost(dutch_matches, dutch_matches):
                english, dutch, note = rows[row_position]
                # WHY: an official name or an abbreviation such as BV may stand alone after its first use.
                if note.strip().lower() in (OFFICIAL_NOTE, ABBREVIATION_NOTE):
                    continue
                if dutch.lower() == english.lower():
                    continue
                problems.append((relative_path, number, "residual", dutch))

    if "first-use" in selected:
        # WHY: an official name is labelled once per file, a term once per section.
        name_seen: Set[int] = set()
        name_dutch_seen: Set[str] = set()
        for section in split_sections(masked):
            seen: Set[int] = set()
            dutch_seen: Set[str] = set()
            for number, line in section:
                pieces = split_pieces(line)
                # WHY: two Dutch spellings of one English name both satisfy its label.
                for row_position, _, _ in find_matches(pieces, dutch_index):
                    dutch_seen.add(rows[row_position][0].lower())
                    name_dutch_seen.add(rows[row_position][0].lower())
                containers = find_matches(pieces, english_index)
                for row_position, _, _ in outermost(find_matches(pieces, first_index), containers):
                    official = rows[row_position][2].strip().lower() == OFFICIAL_NOTE
                    first_seen, labels = (name_seen, name_dutch_seen) if official else (seen, dutch_seen)
                    if row_position in first_seen:
                        continue
                    first_seen.add(row_position)
                    if rows[row_position][0].lower() not in labels:
                        problems.append((relative_path, number, "first-use", rows[row_position][1]))

    if "doubled" in selected:
        for number, line in enumerate(masked, 1):
            for span in doubled_spans(line):
                problems.append((relative_path, number, "doubled", span))

    if "reversed" in selected:
        for number, line in enumerate(masked, 1):
            for row_position, _, end in find_matches(split_pieces(line), dutch_index):
                if tails[row_position].match(line[end:]):
                    problems.append((relative_path, number, "reversed", rows[row_position][1]))

    if "unglossed" in selected:
        for number, line in enumerate(masked, 1):
            for span in unglossed_spans(line, dutch_words, english_words, dutch_terms):
                problems.append((relative_path, number, "unglossed", span))

    return problems


def check_corpus(root: str, selected: Set[str]) -> List[Problem]:
    """Check every file in the corpus against the selected rules.

    Args:
        root: Repository root.
        selected: Rule names to run.

    Returns:
        Every remaining problem, sorted and without duplicates.
    """
    rows = read_glossary_rows(root)
    exceptions = load_exceptions(root)

    positions = list(range(len(rows)))
    dutch_index = term_index(positions, rows, lambda row: row[1])
    # WHY: a plain everyday word gains nothing from a Dutch label, and a
    # one-word English name is too common a word to demand one everywhere.
    first_positions = [
        position
        for position, (english, _, note) in enumerate(rows)
        if note.split(",")[0].strip().lower() not in (PLAIN_NOTE, ABBREVIATION_NOTE)
        and (" " in english or note.strip().lower() == OFFICIAL_NOTE)
    ]
    first_index = term_index(first_positions, rows, lambda row: row[0])
    english_index = term_index(positions, rows, lambda row: row[0])
    tails = [
        re.compile(r"^\s*\(\s*" + re.escape(english.lower()) + r"\s*\)", re.IGNORECASE)
        for english, _, _ in rows
    ]
    # WHY: an abbreviation such as KOR also reads as English inside a bracket, so it marks no Dutch label.
    dutch_words = {
        word.lower()
        for _, dutch, note in rows
        if note.strip().lower() != ABBREVIATION_NOTE
        for word in dutch.split()
    }
    english_words = {word.lower() for english, _, _ in rows for word in english.split()}
    dutch_terms = {dutch.lower() for _, dutch, _ in rows}

    findings: List[Problem] = []
    for path in corpus_files(root):
        findings.extend(
            check_file(
                relative(root, path),
                path,
                rows,
                dutch_index,
                first_index,
                english_index,
                tails,
                dutch_words,
                english_words,
                dutch_terms,
                selected,
            )
        )

    suppression = {rule for rule in SUPPRESSION_CHECKS if rule in selected}
    exception_keys = {
        (row.file, row.term, row.check) for row in exceptions if row.check in suppression
    }
    used: Set[Tuple[str, str, str]] = set()
    problems: List[Problem] = []
    for relative_path, number, rule, term in findings:
        key = (relative_path, term.lower(), rule)
        if rule in suppression and key in exception_keys:
            used.add(key)
            continue
        problems.append((relative_path, number, rule, term))

    if suppression:
        for row in exceptions:
            if row.check not in suppression:
                continue
            if (row.file, row.term, row.check) not in used:
                problems.append((row.file, 0, STALE_RULE, row.term))

    return sorted(set(problems))


# ───────────────────────────────────────────────────────────────
# 8. REPORT
# ───────────────────────────────────────────────────────────────

def print_lines(problems: List[Problem]) -> None:
    """Print one sorted line per problem.

    Args:
        problems: Every remaining problem.
    """
    for relative_path, number, rule, term in problems:
        print("%s:%d: %s: %s" % (relative_path, number, rule, term))


def print_summary(problems: List[Problem], rule_order: List[str]) -> None:
    """Print one count per rule and one count per area.

    Args:
        problems: Every remaining problem.
        rule_order: Rule names to count, in report order.
    """
    counts = {rule: 0 for rule in rule_order}
    areas: Dict[str, int] = {}
    for relative_path, _, rule, _ in problems:
        if rule in counts:
            counts[rule] += 1
        area = area_of(relative_path)
        areas[area] = areas.get(area, 0) + 1
    for rule in rule_order:
        print("%s: %d" % (rule, counts[rule]))
    for area in sorted(areas):
        print("%s: %d" % (area, areas[area]))


# ───────────────────────────────────────────────────────────────
# 9. ENTRY POINT
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
        description="Check that the skill family writes English first and labels every term.",
    )
    parser.add_argument(
        "--root",
        default=REPO_ROOT,
        metavar="DIR",
        help="read another copy of the repository instead of the one above this script",
    )
    parser.add_argument(
        "--rule",
        action="append",
        choices=list(RULES),
        metavar="NAME",
        help="report only this rule, repeatable",
    )
    parser.add_argument(
        "--summary",
        action="store_true",
        help="print one count per rule and per area instead of the lines",
    )
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        fail("not a directory: %s" % args.root)
    selected = set(args.rule) if args.rule else set(RULES)
    problems = check_corpus(root, selected)
    if args.summary:
        rule_order = [rule for rule in RULES if rule in selected]
        if any(rule in selected for rule in SUPPRESSION_CHECKS):
            rule_order.append(STALE_RULE)
        print_summary(problems, rule_order)
    else:
        print_lines(problems)
    print("%d problems" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
