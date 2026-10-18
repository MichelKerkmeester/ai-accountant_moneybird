#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: REFERENCE INDEX BUILDER
# ───────────────────────────────────────────────────────────────
"""Build or check the reference index and the generated blocks.

Scans the markdown and the JSON under sk-moneybird-accountant/references/ and
writes two kinds of output from the same run, references/index.json, a
structure-only map of every markdown file and its H2 sections plus the
authored gap ledger, and the bodies of the generated blocks that sit between
the fence markers inside the reference files. The gap ledger is a table under
one heading of references/routing-signals.md, and the index copies its rows in
table order. The script uses the Python standard library only and makes no
network call. Output is byte-stable: sorted paths, sorted keys, LF line
endings, no timestamp and no random part. Paths in the output and in the
messages are relative to the references root.

The two year README blocks read the topic files of one year folder. Their row
order and their text come from the corpus at run time: the topic order from
the topic table in references/tax-rules/dutch-tax-rules.md, the covers and the topic
labels from the topic-file frontmatter, and the counts and the headline rows
from the KEY FIGURES table of every topic file. Each topic is a folder of
four part files, so a lookup for a section reads and links the part that holds
it: sections 1 and 2 in figures.md, section 3 in rules.md, section 4 in
examples.md and sections 5 to 8 in notes.md.

Section 3 of the reference guide holds the rules that span tax years, and it
restates figures that the year files own. The subsections sit in the general
folder, one file per subsection. One generated block sits in every
subsection, right after the line that names the year files of the subsection.
Its table repeats the first two KEY FIGURES rows of every named file for
every year folder that holds the file, and the owner cell names the year file
that owns the value. The rule prose around the block stays hand-written.

A generated block is fenced by two marker lines that each stand alone:

    <!-- GENERATED:<block-id>:start -->
    <!-- GENERATED:<block-id>:end -->

The generator replaces only the bytes between a matched pair and never
touches a byte outside one, so hand prose survives a regeneration byte for
byte. A pair is added by hand. --check reports a registered block that has no
pair as drift, and a write refuses to run until the pair is there. An
unmatched marker, a nested start, a duplicate block id, a malformed marker or
a marker inside a code block stops the run with exit code 2 and names the
file, the line and the reason.

A block generator registers a builder keyed by its block id. A block without
a registered builder is left as it is.

Every year folder gets a change note at references/tax-rules/<year>/changes.md. Its first
section is authored, and its second section is a generated table with one row
per topic file: the section 5 bullet count, the first bullet cut to a snippet
and the link to the section 5 anchor. The note sits between one fence pair with
the id changes. references/tax-rules/year-changes.md is generated whole, one H2 per year,
newest first, with the path link to the year note and the authored bullets of
that note, so the index reads the generated form. --check also checks the
authored bullets. A number in a bullet must occur as the same number in the
linked section 5. The last link of a bullet must resolve to an existing file
and its section 5 anchor. A year note must hold five to ten authored bullets.

A manifest at the skill root lists the leaves that a reader must be able to
reach. The reachability check reads it under --check. A leaf under the routed
reference folders is reachable through the task-type table in ROUTER.md. Every
other leaf is reachable when its path or a relative link to it appears in
SKILL.md, in ROUTER.md, in the reference index or in a README.md or a folder
index page. A folder index page counts only once SKILL.md or ROUTER.md links
it, so the feature catalog and the playbook route no leaf while both pages
leave their roots out. A manifest leaf that names no file on disk fails the
check on its own, because the routed prefix must not turn a deleted reference
file into a pass.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check

Options:
    --check  Compute every output in memory and report each block or index
             that differs, without writing. Exits 1 on drift, on a landing
             block over its byte cap, on a gap ledger owner that leaves the
             skill folder, on an unreachable manifest leaf or on a manifest
             leaf with no file on disk.

Without an option the run writes every changed block, the year change
overview, the landing page and the index.

Output:
    references/index.json and the fence bodies, one "drift" line per stale
    block in check mode, then the reachability summary and one line per
    missing or unreachable leaf. Exit 0 when everything matches, 1 on drift,
    a landing block over its cap, a bad gap ledger owner, a missing leaf or an
    unreachable leaf, and 2 on a usage error, a read error, a fence error or a
    write error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import re
import sys
import tempfile
from typing import Any, Callable, Dict, List, NoReturn, Optional, Set, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/build-reference-index.py"

# WHY: the references root resolves from the script location, so the scan does
# not depend on the current working directory and never leaves the tree.
SKILL_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFERENCES_ROOT = os.path.join(SKILL_ROOT, "references")
INDEX_NAME = "index.json"
INDEX_PATH = os.path.join(REFERENCES_ROOT, INDEX_NAME)

# Only markdown and JSON are inputs. The generated index is written whole, so
# it is an output and not an input.
SCAN_SUFFIXES = (".md", ".json")
MARKDOWN_SUFFIX = ".md"

# The authored gap ledger is a table under one heading of a reference file.
# The index copies it, so one authored row drives the documented-gap answer.
GAPS_SOURCE = "routing-signals.md"
GAPS_HEADING = "Documented gaps"
GAPS_TOPIC_COLUMN = "Topic"
GAPS_OWNER_COLUMN = "Owner"
GAPS_COVERAGE_COLUMN = "Coverage"
GAPS_ACTION_COLUMN = "Operator action"

# WHY: the marker text is built from parts, so a block generator passes only
# its id and never the marker itself. The id keeps to lower case letters,
# digits, dots, hyphens and underscores.
FENCE_PREFIX = "<!-- GENERATED:"
FENCE_START_SUFFIX = ":start -->"
FENCE_END_SUFFIX = ":end -->"
BLOCK_ID_PATTERN = r"[a-z0-9][a-z0-9._-]*"
BLOCK_ID_RE = re.compile("^" + BLOCK_ID_PATTERN + "$")
FENCE_START_RE = re.compile(
    "^" + re.escape(FENCE_PREFIX) + "(" + BLOCK_ID_PATTERN + ")" + re.escape(FENCE_START_SUFFIX) + "$"
)
FENCE_END_RE = re.compile(
    "^" + re.escape(FENCE_PREFIX) + "(" + BLOCK_ID_PATTERN + ")" + re.escape(FENCE_END_SUFFIX) + "$"
)

# A code block hides its content from the heading scan, and a marker inside one
# is an error rather than a block, so the writer never rewrites an example.
CODE_FENCE_PREFIXES = ("```", "~~~")

HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.*?)[ \t]*$")
NUMBERED_RE = re.compile(r"^(\d+)[.)]?[ \t]+(.*)$")
FRONTMATTER_FIELD_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):[ \t]*(.*)$")
SLUG_RE = re.compile(r"[^\w\s-]", re.UNICODE)
SPACE_RE = re.compile(r"\s+")

# The token baseline is read once per run and consulted by the answer surface.
BASELINE: Dict[str, Any] = {}

# The two year README blocks describe the topic files of one year folder. The
# canonical topic order lives in the topic table of the reference guide, so no
# order list is kept here. A year folder keeps one folder per topic, at any
# depth below the references root, so the year folder is one path part.
YEAR_README_RE = re.compile(r"^(?:.*/)?(\d{4})/README\.md$")
YEAR_PART_RE = re.compile(r"^\d{4}$")
# WHY: a year topic is a folder of four part files, each with a fixed section
# range, so a section lookup names the part that holds it.
TOPIC_PART_BY_SECTION = {
    1: "figures.md",
    2: "figures.md",
    3: "rules.md",
    4: "examples.md",
    5: "notes.md",
    6: "notes.md",
    7: "notes.md",
    8: "notes.md",
}
TOPIC_ORDER_FILE = "dutch-tax-rules.md"
GENERAL_DIR_NAME = "general"
TOPIC_ORDER_HEADING = "Topic files in every year folder"
TOPIC_NAME_PATTERN = r"[A-Za-z0-9._-]+\.md"
KEY_FIGURES_HEADING = "KEY FIGURES"
NAV_LABEL_FIELD = "nav_label"
NAV_LABEL_LIMIT = 60
TOPIC_FILES_HEADER = "| File | Covers | Values | UNVERIFIED | Not enacted |"
TABLE_SEPARATOR = "|---|---|---|---|---|"
TABLE_SEPARATOR_RE = re.compile(r"^\|[-:|\s]+\|$")
UNVERIFIED_TAG = "UNVERIFIED"
ENACTED_STATUS = "enacted"

# Section 3 of the reference guide holds rules that span tax years, and each
# subsection names its year files so a reader reaches the owning file. One
# generated block per subsection repeats the headline rows of those files.
SECTION_THREE_HEADING_RE = re.compile(r"^3\.\d+[ \t]+(.+)$")
SECTION_BLOCK_PREFIX = "s3-"
YEAR_FILES_MARKER = "Year files:"
YEAR_FILES_NAME_RE = re.compile(r"`([A-Za-z0-9._-]+\.md)`")
SECTION_THREE_HEADER = "| Year | Item | Value | Status | Check | Owner |"
SECTION_THREE_SEPARATOR = "|---|---|---|---|---|---|"
SECTION_THREE_SENTENCE = (
    "Rows below are generated from the year files named above, which own the values."
)
OWNER_PREFIX = "sk-moneybird-accountant/references/"

# The item index sits inside the section that holds the KEY FIGURES table, one
# row per value, so a reader jumps to a row without reading the whole table.
# The row number counts the value rows alone, so the body never depends on its
# own size and one run settles it.
ITEM_INDEX_BLOCK_ID = "key-figure-index"
ITEM_INDEX_HEADER = "| Item | row |"
ITEM_INDEX_SEPARATOR = "|---|---|"

# The token baseline is the generator's second input. The answerSurface token
# count comes from it, so a value that disagrees with its baseline row fails
# --check.
BASELINE_PATH = os.path.join(SKILL_ROOT, "benchmark", "token-baseline.json")
LEAD_ENCODING_FIELD = "lead_encoding"

# The term map holds one entry per Dutch term that appears in a generated
# table, with the English gloss a reader sees on its first use and the source
# the owning year file cites. A term without a source does not land.
TERM_MAP_PATH = os.path.join(SKILL_ROOT, "assets", "term-map.json")
TERMS: List[Tuple[str, str]] = []

# The references root gets one generated landing page with three per-group
# blocks, so a reader enters the tree at one page instead of a bare listing.
# A block over its byte cap fails --check, which is what keeps the page
# readable in part.
LANDING_NAME = "README.md"
LANDING_PATH = "README.md"
LANDING_BLOCK_LIMIT = 4096
LANDING_TITLE = "Reference library"
LANDING_DESCRIPTION = (
    "Generated index of the reference tree: the tax year folders, the tax-rule top-level "
    "files and the migration files, with the description each file carries."
)
LANDING_INTRO = (
    "Generated landing page for the reference tree. Every row comes from the frontmatter "
    "description of the file it names, so one regeneration picks up a new file or a changed "
    "description. A folder README belongs to the folder that owns it, and the task-type "
    "table in ROUTER.md routes a request to its file."
)
LANDING_OVERVIEW = (
    "The reference library holds the tax year folders, the tax-rule top-level files "
    "and the migration files. Every row names one file and carries the description "
    "that file already publishes."
)

# The reachability check reads the leaf manifest at the skill root and the
# pages that route a reader to a leaf. A leaf under the routed reference
# folders is reachable by definition, every other leaf needs its path or a
# relative link to it in a page that SKILL.md or ROUTER.md itself reaches.
MANIFEST_NAME = "leaf-manifest.json"
MANIFEST_PATH = os.path.join(SKILL_ROOT, MANIFEST_NAME)
SKILL_PAGE = "SKILL.md"
# WHY: the router beside SKILL.md holds the task-type table and its links, so
# it routes a reader to a leaf as SKILL.md does.
ROUTER_PAGE = "ROUTER.md"
ENTRY_PAGES = (SKILL_PAGE, ROUTER_PAGE)
README_NAME = "README.md"
# WHY: a year folder holds three files beside its topic files, the year README,
# the year changelog and the year change note. None of the three carries the
# topic fields, so no topic scan reads one.
CHANGELOG_NAME = "changelog.md"
ROUTED_PREFIX = "references/"
LINK_TARGET_RE = re.compile(r"\]\(([^)\s]+)\)")

# The year change note restates the changes that section 5 of the year topic
# files records, and the overview gathers the eight notes. One generated block
# per note lists every topic, its section 5 bullet count and its first bullet
# cut to a snippet. The overview is generated whole, so it needs no fence.
CHANGE_NOTE_NAME = "changes.md"
YEAR_CHANGES_NAME = "year-changes.md"
# WHY: the note sits in a year folder under the tax-rules folder.
CHANGE_NOTE_RE = re.compile(r"^tax-rules/(\d{4})/" + re.escape(CHANGE_NOTE_NAME) + r"$")
CHANGES_BLOCK_ID = "changes"
CHANGES_UNIQUE_PREFIX = "Unique to "
CHANGES_TABLE_HEADER = "| Topic | Bullets | First change |"
CHANGES_TABLE_SEPARATOR = "|---|---|---|"
CHANGE_SECTION_NUMBER = 5
CHANGE_FRAGMENT = "5-changes"
CHANGE_BULLET_PREFIX = "- "
CHANGE_BULLET_MIN = 5
CHANGE_BULLET_MAX = 10
CHANGE_SNIPPET_LIMIT = 80
NUMBER_RE = re.compile(r"\d+(?:[.,]\d+)*")
# WHY: the topic link at the end of an authored bullet carries a file name and
# a fragment, never a restated fact, so the number scan reads the prose alone.
CHANGE_PROSE_LINK_RE = re.compile(r"\[[^\[\]]*\]\([^)]*\)")

# ───────────────────────────────────────────────────────────────
# 3. BLOCK REGISTRY
# ───────────────────────────────────────────────────────────────

# A builder returns the body of its block per relative path, with the fences
# left out. A path the builder leaves out keeps the body the file has.
BlockBuilder = Callable[[List[Dict[str, Any]]], Dict[str, str]]

BLOCK_BUILDERS: Dict[str, BlockBuilder] = {}


def register_builder(block_id: str, builder: BlockBuilder) -> None:
    """Register one block builder under its fence id.

    Args:
        block_id: Fence id of the block.
        builder: Function that returns the body of the block per relative
            path, with the fences left out.

    Raises:
        SystemExit: If the id does not match the fence id pattern.
    """
    if not BLOCK_ID_RE.match(block_id):
        fail("invalid block id: %s" % block_id)
    BLOCK_BUILDERS[block_id] = builder


def register_block(block_id: str) -> Callable[[BlockBuilder], BlockBuilder]:
    """Register one generated block under its fence id.

    A block generator decorates its builder with this function and passes its
    id, so the marker text stays in this file alone.

    Args:
        block_id: Fence id of the block.

    Returns:
        Decorator that registers the builder function.
    """

    def decorate(builder: BlockBuilder) -> BlockBuilder:
        register_builder(block_id, builder)
        return builder

    return decorate


# ───────────────────────────────────────────────────────────────
# 4. HELPERS
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


def line_spans(text: str) -> List[Tuple[int, str, int, int]]:
    """Split text into lines with their numbers and character offsets.

    A line keeps its ending out of the content, and the offsets cover the
    whole text, so joining the spans again reproduces the input.

    Args:
        text: File text.

    Returns:
        List of (line number, content, start offset, end offset).
    """
    spans: List[Tuple[int, str, int, int]] = []
    start = 0
    number = 0
    length = len(text)
    while start < length:
        newline = text.find("\n", start)
        number += 1
        if newline == -1:
            spans.append((number, text[start:].rstrip("\r"), start, length))
            break
        spans.append((number, text[start:newline].rstrip("\r"), start, newline + 1))
        start = newline + 1
    return spans


def relative_path(path: str) -> str:
    """Return a file path relative to the references root.

    Args:
        path: Absolute or relative path inside the references tree.

    Returns:
        The path with forward slashes, for output and for messages.
    """
    return os.path.relpath(path, REFERENCES_ROOT).replace(os.sep, "/")


def reference_files() -> List[str]:
    """List the markdown and the JSON files under the references root.

    The generated index is never an input.

    Returns:
        Sorted absolute paths.
    """
    found = []
    base = os.path.abspath(REFERENCES_ROOT)
    for directory, _, names in os.walk(base):
        for name in names:
            if not name.endswith(SCAN_SUFFIXES):
                continue
            path = os.path.join(directory, name)
            # WHY: the index is generated whole, so scanning it would make it cite itself.
            if os.path.abspath(path) == os.path.abspath(INDEX_PATH):
                continue
            found.append(path)
    return sorted(found)


def read_text(path: str) -> str:
    """Read one file as UTF-8 text without changing a byte.

    Args:
        path: File to read.

    Returns:
        The decoded file text.

    Raises:
        SystemExit: If the file cannot be read or is not UTF-8.
    """
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (relative_path(path), exc))
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        fail("cannot decode %s as UTF-8: %s" % (relative_path(path), exc))


def file_mode(path: str) -> int:
    """Return the mode a written file keeps.

    Args:
        path: Target file.

    Returns:
        The mode of an existing file, otherwise the mode a new file gets under
        the current umask.
    """
    if os.path.isfile(path):
        return os.stat(path).st_mode & 0o777
    current = os.umask(0)
    os.umask(current)
    return 0o666 & ~current


def write_text(path: str, text: str) -> None:
    """Write one file through a temporary file and a rename.

    Args:
        path: File to write.
        text: New file text.

    Raises:
        SystemExit: If the file cannot be written.
    """
    data = text.encode("utf-8")
    mode = file_mode(path)
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=".reference-index-", dir=os.path.dirname(path))
        os.close(descriptor)
        with open(temporary, "wb") as handle:
            handle.write(data)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
        temporary = None
    except OSError as exc:
        fail("cannot write %s: %s" % (relative_path(path), exc))
    finally:
        # WHY: a half-written temporary file must not survive a failed rename.
        if temporary is not None and os.path.exists(temporary):
            os.unlink(temporary)


# ───────────────────────────────────────────────────────────────
# 5. FENCES
# ───────────────────────────────────────────────────────────────

class FenceError(Exception):
    """One fence problem with the line it sits on and the reason."""

    def __init__(self, line: int, reason: str) -> None:
        super().__init__("line %d: %s" % (line, reason))
        self.line = line
        self.reason = reason


def parse_fences(text: str) -> List[Dict[str, Any]]:
    """Return the fence blocks of one markdown file.

    Args:
        text: File text.

    Returns:
        One record per matched pair, in file order, with the id, the start and
        end line numbers, the body offsets and the body text.

    Raises:
        FenceError: On an unmatched or malformed marker, a nested start, a
            duplicate block id, or a marker inside a code block.
    """
    blocks: List[Dict[str, Any]] = []
    seen: Dict[str, int] = {}
    opened: Optional[Dict[str, Any]] = None
    in_code = False
    for number, content, start, end in line_spans(text):
        stripped = content.strip()
        if stripped.startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            continue
        start_match = FENCE_START_RE.match(content)
        end_match = FENCE_END_RE.match(content)
        if in_code:
            if start_match or end_match or stripped.startswith(FENCE_PREFIX):
                raise FenceError(number, "fence in code block")
            continue
        if start_match:
            block_id = start_match.group(1)
            if opened is not None:
                raise FenceError(number, "nested start")
            if block_id in seen:
                raise FenceError(number, "duplicate block id")
            opened = {"id": block_id, "start_line": number, "body_start": end}
            continue
        if end_match:
            block_id = end_match.group(1)
            if opened is None or opened["id"] != block_id:
                raise FenceError(number, "unmatched end")
            opened["end_line"] = number
            opened["body_end"] = start
            opened["body"] = text[opened["body_start"]:start]
            blocks.append(opened)
            seen[block_id] = opened["start_line"]
            opened = None
            continue
        if stripped.startswith(FENCE_PREFIX):
            raise FenceError(number, "malformed fence")
    if opened is not None:
        raise FenceError(opened["start_line"], "unmatched start")
    return blocks


# ───────────────────────────────────────────────────────────────
# 6. SECTION SCAN
# ───────────────────────────────────────────────────────────────

def slugify(heading: str) -> str:
    """Return the anchor slug of a heading.

    Args:
        heading: Heading text with any inline markdown kept.

    Returns:
        The lower case slug with punctuation dropped and spaces as hyphens.
    """
    text = SLUG_RE.sub("", heading.strip().lower())
    return SPACE_RE.sub("-", text.strip())


def heading_parts(heading: str) -> Tuple[Optional[int], str]:
    """Split a heading into its number and its title.

    Args:
        heading: Heading text.

    Returns:
        The number when the heading starts with one, and the title without it.
    """
    match = NUMBERED_RE.match(heading)
    if not match:
        return None, heading
    return int(match.group(1)), match.group(2).strip()


def frontmatter_end(spans: List[Tuple[int, str, int, int]]) -> int:
    """Return the index of the first line after a leading frontmatter block.

    Args:
        spans: Result of line_spans().

    Returns:
        The index of the first content line, zero when no frontmatter block is
        closed.
    """
    if not spans or spans[0][1].strip() != "---":
        return 0
    for index in range(1, len(spans)):
        if spans[index][1].strip() == "---":
            return index + 1
    return 0


def frontmatter_values(text: str) -> Dict[str, str]:
    """Read the one-line fields of a leading frontmatter block.

    A double-quoted value loses its quotes, so a description reads as the text
    a table cell holds. A list field keeps out of the result.

    Args:
        text: File text.

    Returns:
        Field values by field name, empty without a closed frontmatter block.
    """
    spans = line_spans(text)
    end = frontmatter_end(spans)
    if end == 0:
        return {}
    values: Dict[str, str] = {}
    for span in spans[1:end - 1]:
        match = FRONTMATTER_FIELD_RE.match(span[1])
        if not match:
            continue
        value = match.group(2).strip()
        if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        values[match.group(1)] = value
    return values


def scan_sections(text: str) -> Tuple[str, List[Dict[str, Any]]]:
    """Map the H1 title and the H2 sections of one markdown file.

    A section runs from its heading line to the line before the next H2, so
    the blank and separator lines between two sections belong to the earlier
    one. A heading inside frontmatter or inside a code block is no heading.

    Args:
        text: File text.

    Returns:
        The H1 text, empty when there is none, and the section rows with the
        anchor, the byte count, the line number, the number and the title.
    """
    spans = line_spans(text)
    title = ""
    headings: List[Dict[str, Any]] = []
    in_code = False
    for number, content, start, _ in spans[frontmatter_end(spans):]:
        stripped = content.strip()
        if stripped.startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = HEADING_RE.match(content)
        if not match:
            continue
        heading = match.group(2).strip()
        if len(match.group(1)) == 1 and not title:
            title = heading
        if len(match.group(1)) == 2:
            headings.append({"heading": heading, "line": number, "start": start})
    sections: List[Dict[str, Any]] = []
    used: Dict[str, int] = {}
    for index, item in enumerate(headings):
        end = headings[index + 1]["start"] if index + 1 < len(headings) else len(text)
        number, short = heading_parts(item["heading"])
        base = slugify(item["heading"])
        count = used.get(base, 0)
        used[base] = count + 1
        # WHY: a repeated heading takes a numbered suffix, as a page anchor does.
        anchor = base if count == 0 else "%s-%d" % (base, count)
        sections.append(
            {
                "anchor": anchor,
                "bytes": len(text[item["start"]:end].encode("utf-8")),
                "line": item["line"],
                "n": number,
                "title": short,
            }
        )
    return title, sections


# ───────────────────────────────────────────────────────────────
# 7. INDEX
# ───────────────────────────────────────────────────────────────

def index_entry(path: str, text: str) -> Dict[str, Any]:
    """Build the index row of one markdown file.

    Args:
        path: Path relative to the references root.
        text: File text after every block body is applied.

    Returns:
        A row with the path, the H1 title, the byte count, the line count,
        the H2 sections and the answer surface. It holds structure only,
        never a figure.
    """
    title, sections = scan_sections(text)
    return {
        "path": path,
        "title": title,
        "bytes": len(text.encode("utf-8")),
        "lines": len(line_spans(text)),
        "sections": sections,
        "answerSurface": key_figures_section({"path": path, "text": text}),
    }


def build_index_text(entries: List[Dict[str, Any]], gaps: List[Dict[str, str]]) -> str:
    """Render the index JSON with one file row and one gap row per line.

    Args:
        entries: Rows from index_entry(), in path order.
        gaps: Gap ledger rows from gap_rows(), in table order.

    Returns:
        Index text with sorted keys, LF line endings and a trailing newline.
    """
    rows = [json.dumps(entry, ensure_ascii=False, sort_keys=True, separators=(",", ":")) for entry in entries]
    gap_lines = [json.dumps(gap, ensure_ascii=False, sort_keys=True, separators=(",", ":")) for gap in gaps]
    files_text = '{"files":[' + ("" if not rows else "\n" + ",\n".join(rows) + "\n") + "]"
    gaps_text = ',"gaps":[' + ("" if not gap_lines else "\n" + ",\n".join(gap_lines) + "\n") + "]"
    tail = ',"generator":%s}' % json.dumps(GENERATOR)
    return files_text + gaps_text + tail + "\n"


def read_index() -> Optional[str]:
    """Read the current index text.

    Returns:
        The index text, or None when the index does not exist yet.
    """
    if not os.path.isfile(INDEX_PATH):
        return None
    return read_text(INDEX_PATH)


def gap_source(files: List[Dict[str, Any]]) -> Optional[str]:
    """Return the text of the authored gap ledger file.

    Args:
        files: Result of load_files().

    Returns:
        The file text, or None when the tree holds no ledger file.
    """
    for file in files:
        if file["path"] == GAPS_SOURCE:
            return file["text"]
    return None


def gap_cell(row: List[str], header: List[str], column: str) -> str:
    """Return one gap ledger cell with its markdown code marks stripped.

    Args:
        row: Cell list of one table row.
        header: Cell list of the table header.
        column: Column name to read.

    Returns:
        The cell text without its surrounding spaces and backticks, or an
        empty string when the header or the row stops before it.
    """
    if column not in header:
        return ""
    index = header.index(column)
    if index >= len(row):
        return ""
    return row[index].strip().strip("`").strip()


def gap_table(files: List[Dict[str, Any]]) -> Optional[List[Tuple[int, str]]]:
    """Read the line spans of the authored gap ledger rows.

    Args:
        files: Result of load_files().

    Returns:
        The spans of the header line, the separator line and the row lines,
        in file order, or None when the tree holds no ledger table.
    """
    text = gap_source(files)
    if text is None:
        return None
    return table_spans(line_spans(text), GAPS_HEADING)


def gap_rows(files: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    """Read the authored gap ledger rows.

    Args:
        files: Result of load_files().

    Returns:
        One row per table row, in table order, with the index keys. An absent
        file, heading or table yields an empty list.
    """
    table = gap_table(files)
    if table is None:
        return []
    header = markdown_cells(table[0][1])
    return [
        {
            "topic": gap_cell(row, header, GAPS_TOPIC_COLUMN),
            "owner": gap_cell(row, header, GAPS_OWNER_COLUMN),
            "coverage": gap_cell(row, header, GAPS_COVERAGE_COLUMN),
            "operator_action": gap_cell(row, header, GAPS_ACTION_COLUMN),
        }
        for row in (markdown_cells(span[1]) for span in table[2:])
    ]


def gap_problems(files: List[Dict[str, Any]]) -> List[str]:
    """List the gap ledger rows whose owner leaves the skill folder.

    check-route-table.py checks the other ledger rules, and no other check
    covers an owner that leaves the skill folder.

    Args:
        files: Result of load_files().

    Returns:
        One line per row with an absolute owner or an owner that climbs out of
        the skill folder, naming the source row.
    """
    table = gap_table(files)
    if table is None:
        return []
    header = markdown_cells(table[0][1])
    problems: List[str] = []
    for span in table[2:]:
        row = markdown_cells(span[1])
        owner = gap_cell(row, header, GAPS_OWNER_COLUMN)
        normalized = os.path.normpath(owner)
        if os.path.isabs(owner) or normalized == ".." or normalized.startswith("../"):
            problems.append(
                "gaps %s row %d topic %s owner %s escapes the skill folder"
                % (GAPS_SOURCE, span[0], gap_cell(row, header, GAPS_TOPIC_COLUMN), owner)
            )
    return problems


def year_changes_path(files: List[Dict[str, Any]]) -> str:
    """Return the path of the year change overview.

    The overview sits beside its year folders, at any depth.

    Args:
        files: Result of load_files().

    Returns:
        The overview path relative to the references root.

    Raises:
        SystemExit: If the tree holds no overview.
    """
    for file in files:
        if os.path.basename(file["path"]) == YEAR_CHANGES_NAME:
            return file["path"]
    fail("missing %s, the generated overview lives beside the year folders" % YEAR_CHANGES_NAME)


# ───────────────────────────────────────────────────────────────
# 8. YEAR README BLOCKS
# ───────────────────────────────────────────────────────────────

def markdown_cells(row: str) -> List[str]:
    """Split one markdown table row into its trimmed cells.

    Args:
        row: Table row line, with or without its outer pipes.

    Returns:
        The cell texts in column order.
    """
    return [cell.strip() for cell in row.strip().strip("|").split("|")]


def heading_index(spans: List[Tuple[int, str, int, int]], heading: str) -> Optional[int]:
    """Find the first heading line that holds a keyword.

    Args:
        spans: Result of line_spans().
        heading: Keyword to look for, matched without case.

    Returns:
        The index of the heading line in spans, or None when no heading holds
        it.
    """
    for index, span in enumerate(spans):
        if span[1].startswith("#") and heading.lower() in span[1].lower():
            return index
    return None


def table_spans(
    spans: List[Tuple[int, str, int, int]], heading: str, skip_blocks: Tuple[str, ...] = ()
) -> Optional[List[Tuple[int, str, int, int]]]:
    """Return the line spans of the first table under a heading.

    The table runs from its header line to its last row line. The next
    heading, a blank line or any other line ends the search, so a later table
    in the same section is not picked up. A line inside one of the skipped
    generated blocks is left out, so a block that sits above a table does not
    hide it.

    Args:
        spans: Result of line_spans().
        heading: Keyword that names the heading that owns the table.
        skip_blocks: Fence ids whose body lines the scan steps over.

    Returns:
        The spans of the header line, the separator line and the row lines, in
        file order, or None when the file has no such heading or no table
        under it.
    """
    start = heading_index(spans, heading)
    if start is None:
        return None
    skipped: Set[int] = set()
    opened: Optional[str] = None
    for number, content, _, _ in spans:
        match = FENCE_START_RE.match(content)
        if match:
            if match.group(1) in skip_blocks:
                opened = match.group(1)
                skipped.add(number)
            continue
        match = FENCE_END_RE.match(content)
        if match and opened == match.group(1):
            skipped.add(number)
            opened = None
            continue
        if opened is not None:
            skipped.add(number)
    table: List[Tuple[int, str, int, int]] = []
    for span in spans[start + 1:]:
        if span[0] in skipped:
            continue
        if span[1].startswith("#"):
            break
        if not span[1].startswith("|"):
            if table:
                break
            continue
        table.append(span)
    if len(table) < 2:
        return None
    return table


def key_figures(file: Dict[str, Any]) -> Dict[str, Any]:
    """Read the KEY FIGURES table of one topic file.

    Args:
        file: File record from load_files().

    Returns:
        The header cells and the data rows.

    Raises:
        SystemExit: If the file has no KEY FIGURES table, or the table has no
            separator line, Status column or Check column.
    """
    table = table_spans(
        line_spans(file["text"]), KEY_FIGURES_HEADING, skip_blocks=(ITEM_INDEX_BLOCK_ID,)
    )
    if table is None:
        fail("no %s table in %s" % (KEY_FIGURES_HEADING, file["path"]))
    if not TABLE_SEPARATOR_RE.match(table[1][1].strip()):
        fail("%s table in %s has no separator line" % (KEY_FIGURES_HEADING, file["path"]))
    header = markdown_cells(table[0][1])
    for column in ("Status", "Check"):
        if column not in header:
            fail("%s table in %s has no %s column" % (KEY_FIGURES_HEADING, file["path"], column))
    return {"header": header, "rows": [markdown_cells(span[1]) for span in table[2:]]}


def figure_cell(record: Dict[str, Any], row: List[str], column: str) -> str:
    """Return one cell of a KEY FIGURES row.

    Args:
        record: Topic record from year_topics().
        row: Cell list of one row.
        column: Column name.

    Returns:
        The cell text.

    Raises:
        SystemExit: If the table has no such column or the row stops before it.
    """
    header = record["figures"]["header"]
    if column not in header:
        fail("%s table in %s has no %s column" % (KEY_FIGURES_HEADING, record["path"], column))
    index = header.index(column)
    if index >= len(row):
        fail("%s row in %s stops before its %s cell" % (KEY_FIGURES_HEADING, record["path"], column))
    return row[index]


def headline_figures(record: Dict[str, Any]) -> Tuple[str, List[Dict[str, str]]]:
    """Read the first two KEY FIGURES rows of one topic file.

    These two rows are the ones the year README HEADLINE FIGURES table shows,
    so the year README and the section 3 blocks read the same figures.

    Args:
        record: Topic record with a KEY FIGURES table.

    Returns:
        The name of the Value column and the two rows, each with its named
        cells.

    Raises:
        SystemExit: If the table has no Value column or holds fewer than two
            rows.
    """
    header = record["figures"]["header"]
    value_column = next((cell for cell in header if cell.startswith("Value")), "")
    if not value_column:
        fail("%s table in %s has no Value column" % (KEY_FIGURES_HEADING, record["path"]))
    figures = record["figures"]["rows"]
    if len(figures) < 2:
        fail("%s table in %s holds fewer than two rows" % (KEY_FIGURES_HEADING, record["path"]))
    return value_column, [
        {
            "item": figure_cell(record, row, "Item"),
            "value": figure_cell(record, row, value_column),
            "status": figure_cell(record, row, "Status"),
            "check": figure_cell(record, row, "Check"),
        }
        for row in figures[:2]
    ]


def table_text(header: str, rows: List[str], separator: str = TABLE_SEPARATOR) -> str:
    """Render a table body from its header line and its row lines.

    Args:
        header: Header line of the table.
        rows: Data row lines.
        separator: Separator line of the table.

    Returns:
        The table text, with the separator line and a trailing line ending.
    """
    return "".join(line + "\n" for line in [header, separator] + rows)


def year_of(path: str) -> Optional[str]:
    """Return the year folder of a reference path.

    Args:
        path: Path relative to the references root.

    Returns:
        The first four digit path part, at any depth, or None when the path
        holds no year folder.
    """
    for part in path.split("/"):
        if YEAR_PART_RE.match(part):
            return part
    return None


def is_year_topic(path: str) -> bool:
    """Tell whether a reference path is a year topic file.

    Args:
        path: Path relative to the references root.

    Returns:
        True for a markdown file that sits in a year folder at any depth,
        other than the year README, the year changelog and the year change
        note.
    """
    name = os.path.basename(path)
    return (
        year_of(path) is not None
        and name.endswith(MARKDOWN_SUFFIX)
        and name not in (README_NAME, CHANGELOG_NAME, CHANGE_NOTE_NAME)
    )


def year_topic_path(files: Dict[str, Dict[str, Any]], year: str, name: str) -> Optional[str]:
    """Return the file that carries one canonical topic of one year.

    A topic is a folder that holds its four files, and the figures file
    carries the KEY FIGURES table. The folder is searched at any depth below
    the references root.

    Args:
        files: File records keyed by relative path.
        year: Four digit year folder.
        name: Canonical topic file name, for example vat.md.

    Returns:
        The path of the carrier file relative to the references root, or None
        when the year folder holds no topic with that name.
    """
    topic = name[: -len(MARKDOWN_SUFFIX)]
    for path in sorted(files):
        parts = path.split("/")
        if year not in parts[:-1]:
            continue
        if parts[parts.index(year) + 1:] == [topic, "figures.md"]:
            return path
    return None


def topic_section_path(
    files: Dict[str, Dict[str, Any]], topic_path: str, section: int
) -> str:
    """Return the part of one topic that holds a section.

    A topic is a folder of four part files, so a caller reads and links the
    part that carries the section it needs.

    Args:
        files: File records keyed by relative path.
        topic_path: Carrier path from year_topic_path().
        section: Section number.

    Returns:
        The path of the part relative to the references root.

    Raises:
        SystemExit: If the topic folder lacks that part.
    """
    path = os.path.join(os.path.dirname(topic_path), TOPIC_PART_BY_SECTION[section]).replace(os.sep, "/")
    if path not in files:
        fail("missing %s, every year topic folder holds its four part files" % path)
    return path


def is_guide_path(path: str) -> bool:
    """Tell whether a reference path is the reference guide.

    The scan reads the guide by name.

    Args:
        path: Path relative to the references root.

    Returns:
        True for the file that carries the topic order and section 3.
    """
    return os.path.basename(path) == TOPIC_ORDER_FILE


def is_general_path(path: str) -> bool:
    """Tell whether a reference path is a general topic file.

    The subsections of section 3 of the reference guide sit in a general
    folder, one file per subsection.

    Args:
        path: Path relative to the references root.

    Returns:
        True for a markdown file directly inside a general folder.
    """
    parts = path.split("/")
    return len(parts) >= 2 and parts[-2] == GENERAL_DIR_NAME and path.endswith(MARKDOWN_SUFFIX)


def canonical_topics(files: Dict[str, Dict[str, Any]]) -> List[str]:
    """Read the canonical topic file order from the reference guide.

    The order is the row order of the topic table in the guide, so the year
    README tables and this script share one source of truth for it.

    Args:
        files: File records keyed by relative path.

    Returns:
        The topic file names in order.

    Raises:
        SystemExit: If the guide or its topic table is missing or empty.
    """
    path = next((path for path in sorted(files) if is_guide_path(path)), None)
    if path is None:
        fail("missing %s, the topic order comes from it" % TOPIC_ORDER_FILE)
    guide = files[path]
    spans = line_spans(guide["text"])
    start = heading_index(spans, TOPIC_ORDER_HEADING)
    if start is None:
        fail("no %r heading in %s" % (TOPIC_ORDER_HEADING, TOPIC_ORDER_FILE))
    pattern = re.compile(r"^\| `(" + TOPIC_NAME_PATTERN + r")` \|")
    topics: List[str] = []
    for span in spans[start + 1:]:
        if span[1].startswith("#"):
            break
        match = pattern.match(span[1])
        if match:
            topics.append(match.group(1))
    if not topics:
        fail("no topic rows under %r in %s" % (TOPIC_ORDER_HEADING, TOPIC_ORDER_FILE))
    return topics


def year_topics(files: Dict[str, Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """Read the topic-file fields that the year README tables need.

    Args:
        files: File records keyed by relative path.

    Returns:
        One topic record list per year README, keyed by the README path, in
        canonical order. A record carries the topic name, its link, the path,
        the description, the nav label and the KEY FIGURES table.

    Raises:
        SystemExit: If a topic file is missing, or a nav_label is missing,
            duplicated within its year or longer than the limit.
    """
    topics = canonical_topics(files)
    readmes = sorted(
        (path for path in files if YEAR_README_RE.match(path)),
        key=lambda path: (year_of(path), path),
    )
    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for readme in readmes:
        year = year_of(readme)
        labels: Dict[str, str] = {}
        records: List[Dict[str, Any]] = []
        for name in topics:
            path = year_topic_path(files, year, name)
            if path is None:
                fail("missing %s, every year folder holds each topic file" % ("%s/%s" % (year, name)))
            file = files[path]
            values = frontmatter_values(file["text"])
            label = values.get(NAV_LABEL_FIELD, "")
            if not label:
                fail("missing %s in %s" % (NAV_LABEL_FIELD, path))
            if len(label) > NAV_LABEL_LIMIT:
                fail(
                    "%s of %s is %d characters, the limit is %d"
                    % (NAV_LABEL_FIELD, path, len(label), NAV_LABEL_LIMIT)
                )
            if label in labels:
                fail("duplicate %s %s in %s and %s" % (NAV_LABEL_FIELD, label, labels[label], path))
            labels[label] = path
            records.append(
                {
                    "name": name[: -len(MARKDOWN_SUFFIX)],
                    "link": os.path.relpath(path, os.path.dirname(readme)).replace(os.sep, "/"),
                    "path": path,
                    "description": values.get("description", ""),
                    "nav_label": label,
                    "figures": key_figures(file),
                }
            )
        grouped[readme] = records
    return grouped


def topic_files_row(record: Dict[str, Any]) -> str:
    """Render one TOPIC FILES row of a year README.

    Args:
        record: Topic record from year_topics().

    Returns:
        The row line, without a line ending.
    """
    rows = record["figures"]["rows"]
    unverified = sum(
        1 for row in rows if figure_cell(record, row, "Check").startswith(UNVERIFIED_TAG)
    )
    not_enacted = sum(
        1 for row in rows if figure_cell(record, row, "Status") != ENACTED_STATUS
    )
    line = "| [%s](%s) | %s | %d | %d | %d |" % (
        record["name"],
        record["link"],
        record["description"],
        len(rows),
        unverified,
        not_enacted,
    )
    return gloss_cell(line, record["used"])


@register_block("topic-files")
def topic_files_block(files: List[Dict[str, Any]]) -> Dict[str, str]:
    """Build the TOPIC FILES table body of every year README.

    Args:
        files: Result of load_files().

    Returns:
        The table body keyed by the README path, one row per topic file in the
        canonical order.
    """
    grouped = year_topics({file["path"]: file for file in files})
    bodies: Dict[str, str] = {}
    for readme in sorted(grouped):
        for record in grouped[readme]:
            record["used"] = set()
        rows = [topic_files_row(record) for record in grouped[readme]]
        bodies[readme] = table_text(TOPIC_FILES_HEADER, rows)
    return bodies


@register_block("headline-figures")
def headline_figures_block(files: List[Dict[str, Any]]) -> Dict[str, str]:
    """Build the HEADLINE FIGURES table body of every year README.

    The table holds the first two rows of every topic file's KEY FIGURES
    table, in the canonical topic order, with the nav label as the topic.

    Args:
        files: Result of load_files().

    Returns:
        The table body keyed by the README path.
    """
    grouped = year_topics({file["path"]: file for file in files})
    bodies: Dict[str, str] = {}
    for readme in sorted(grouped):
        rows: List[str] = []
        value_header = ""
        used: Set[str] = set()
        for record in grouped[readme]:
            value_column, figures = headline_figures(record)
            if not value_header:
                value_header = value_column
            for figure in figures:
                rows.append(
                    gloss_cell(
                        "| %s | %s | %s | %s | %s |"
                        % (
                            record["nav_label"],
                            figure["item"],
                            figure["value"],
                            figure["status"],
                            figure["check"],
                        ),
                        used,
                    )
                )
        bodies[readme] = table_text(
            "| Topic | Item | %s | Status | Check |" % value_header, rows
        )
    return bodies


# ───────────────────────────────────────────────────────────────
# 8b. ITEM INDEX, BASELINE VALUES AND LANDING PAGE
# ───────────────────────────────────────────────────────────────

def load_baseline() -> Dict[str, Any]:
    """Read the token baseline, the generator's second input.

    Returns:
        The baseline record.

    Raises:
        SystemExit: If the file cannot be read or holds invalid JSON.
    """
    try:
        data = json.loads(read_text(BASELINE_PATH))
    except json.JSONDecodeError as exc:
        fail("cannot parse %s: %s" % (os.path.basename(BASELINE_PATH), exc))
    if not isinstance(data, dict):
        fail("%s holds no JSON object" % os.path.basename(BASELINE_PATH))
    return data


def baseline_reference_path(path: str) -> str:
    """Return the baseline key of one reference path.

    Args:
        path: Path relative to the references root.

    Returns:
        The path relative to the repository root, the key the baseline uses.
    """
    return "sk-moneybird-accountant/references/" + path


def baseline_section_tokens(baseline: Dict[str, Any], path: str, anchor: str) -> int:
    """Read the lead-encoding token count of one section row.

    Args:
        baseline: Result of load_baseline().
        path: Path relative to the references root.
        anchor: Anchor of the section.

    Returns:
        The token count of the matching section row, zero when the baseline
        holds no such row.
    """
    lead = baseline["pin"][LEAD_ENCODING_FIELD]
    wanted = baseline_reference_path(path)
    for row in baseline["files"]:
        if row["path"] != wanted:
            continue
        for section in row["sections"]:
            if section["anchor"] == anchor:
                return section["tokens"][lead]
    return 0


def key_figures_heading_index(file: Dict[str, Any]) -> Optional[int]:
    """Return the span index of the heading that owns the KEY FIGURES table.

    Args:
        file: File record from load_files().

    Returns:
        The index of the heading line in line_spans(), or None when the file
        holds no such heading.
    """
    return heading_index(line_spans(file["text"]), KEY_FIGURES_HEADING)


def item_index_target(file: Dict[str, Any]) -> bool:
    """Tell whether one file needs an item index.

    Args:
        file: File record from load_files().

    Returns:
        True for a year topic file that carries a KEY FIGURES heading.
    """
    if not file["path"].endswith(MARKDOWN_SUFFIX) or not is_year_topic(file["path"]):
        return False
    return key_figures_heading_index(file) is not None


@register_block(ITEM_INDEX_BLOCK_ID)
def item_index_block(files: List[Dict[str, Any]]) -> Dict[str, str]:
    """Build the item index body of every file that holds a value table.

    One row per value row of the KEY FIGURES table, in table order, with the
    item text and the 1-based row number of the value in the table. The row
    number counts the value rows alone, so the body never depends on its own
    size and one write settles it.

    Args:
        files: Result of load_files().

    Returns:
        The table body keyed by the file path.
    """
    bodies: Dict[str, str] = {}
    for file in files:
        if not item_index_target(file):
            continue
        record = {"path": file["path"], "figures": key_figures(file)}
        used: Set[str] = set()
        rows = [
            gloss_cell("| %s | %d |" % (figure_cell(record, row, "Item"), position), used)
            for position, row in enumerate(record["figures"]["rows"], 1)
        ]
        bodies[file["path"]] = table_text(ITEM_INDEX_HEADER, rows, ITEM_INDEX_SEPARATOR)
    return bodies


def load_terms() -> List[Tuple[str, str]]:
    """Read the sourced term map.

    Returns:
        The (term, gloss) pairs, longest term first, so a compound term is
        glossed before the shorter term inside it. An entry without a source
        is left out.

    Raises:
        SystemExit: If the file cannot be read or holds invalid JSON.
    """
    try:
        data = json.loads(read_text(TERM_MAP_PATH))
    except json.JSONDecodeError as exc:
        fail("cannot parse %s: %s" % (os.path.basename(TERM_MAP_PATH), exc))
    if not isinstance(data, dict):
        fail("%s holds no JSON object" % os.path.basename(TERM_MAP_PATH))
    pairs: List[Tuple[str, str]] = []
    for row in data.get("terms", []):
        if not isinstance(row, dict):
            continue
        term = row.get("term")
        gloss = row.get("gloss")
        source = row.get("source")
        if not isinstance(term, str) or not isinstance(gloss, str) or not term:
            continue
        if not isinstance(source, str) or not source:
            continue
        pairs.append((term, gloss))
    return sorted(pairs, key=lambda pair: (-len(pair[0]), pair[0]))


def gloss_cell(text: str, used: Set[str]) -> str:
    """Gloss the first use of every mapped term in one cell.

    Args:
        text: Cell text.
        used: Terms already glossed in the table this cell belongs to,
            updated in place.

    Returns:
        The cell text with " (gloss)" after the first whole-word use of every
        mapped term the table has not glossed yet.
    """
    for term, gloss in TERMS:
        if term in used:
            continue
        match = re.search(r"(?<!\w)" + re.escape(term) + r"(?!\w)", text)
        if match is None:
            continue
        text = text[: match.end()] + " (%s)" % gloss + text[match.end():]
        used.add(term)
    return text


def key_figures_section(file: Dict[str, Any]) -> Dict[str, Any]:
    """Build the answer surface of one rendered file.

    Args:
        file: File record whose text holds every block body.

    Returns:
        A record with the anchor of the section that holds the value table,
        the number of value rows and the lead-encoding token count of the
        section. A file without a value table carries an empty section, zero
        rows and zero tokens.
    """
    index = key_figures_heading_index(file)
    if index is None or not is_year_topic(file["path"]):
        return {"section": "", "rows": 0, "tokens": 0}
    spans = line_spans(file["text"])
    heading = spans[index][1].lstrip("#").strip()
    anchor = slugify(heading)
    record = {"path": file["path"], "figures": key_figures(file)}
    return {
        "section": anchor,
        "rows": len(record["figures"]["rows"]),
        "tokens": baseline_section_tokens(BASELINE, file["path"], anchor),
    }


def group_rows(files: Dict[str, Dict[str, Any]], paths: List[str]) -> List[str]:
    """Render one landing page block from a path list.

    Args:
        files: File records keyed by their relative path.
        paths: Relative paths of the rows, in order.

    Returns:
        One row line per path, with the frontmatter description as the cell.
    """
    rows: List[str] = []
    for path in paths:
        values = frontmatter_values(files[path]["text"])
        label = values.get(NAV_LABEL_FIELD, "") or os.path.basename(path)
        rows.append("| [%s](%s) | %s |" % (label, path, values.get("description", "")))
    return rows


def landing_text(files: List[Dict[str, Any]]) -> str:
    """Render the generated landing page of the references root.

    One overview section and three per-group blocks: the year folders, the
    tax-rule top-level files and the migration files. Every row comes from
    the frontmatter description of the file it names.

    Args:
        files: Result of load_files().

    Returns:
        The complete file text.
    """
    by_path = {file["path"]: file for file in files}
    years = sorted(
        path for path in by_path if YEAR_README_RE.match(path)
    )
    tax_files = sorted(
        path
        for path in by_path
        if "/" in path
        and os.path.dirname(path).split("/")[-1] == "tax-rules"
        and path.endswith(MARKDOWN_SUFFIX)
    )
    migration = sorted(
        path
        for path in by_path
        if os.path.dirname(path).split("/")[-1] == "migration" and path.endswith(MARKDOWN_SUFFIX)
    )
    lines = [
        "---",
        'title: "%s"' % LANDING_TITLE,
        'description: "%s"' % LANDING_DESCRIPTION,
        "trigger_phrases:",
        '  - "reference library"',
        '  - "reference tree index"',
        "importance_tier: important",
        "contextType: reference",
        "version: 1.0.0.0",
        'nav_label: "References"',
        "---",
        "",
        "# %s" % LANDING_TITLE,
        "",
        "**Rule:** %s" % LANDING_INTRO,
        "",
        "---",
        "",
        "## 1. OVERVIEW",
        "",
        LANDING_OVERVIEW,
        "",
    ]
    blocks = (
        ("2. TAX YEAR FOLDERS", years, "the twelve topic files and the headline figures of one tax year"),
        ("3. TAX-RULE FILES", tax_files, "the general rules, the year index, the change overview and the source upkeep files"),
        ("4. MIGRATION FILES", migration, "the phase files, the mapping and the write contract"),
    )
    for heading, paths, note in blocks:
        lines.append("---")
        lines.append("")
        lines.append("## %s" % heading)
        lines.append("")
        lines.append(note)
        lines.append("")
        lines.append("| File | Covers |")
        lines.append("|---|---|")
        lines.extend(group_rows(by_path, paths))
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def landing_blocks(text: str) -> List[Tuple[str, int]]:
    """Measure the three landing page blocks.

    Args:
        text: Landing page text.

    Returns:
        One (heading, byte count) pair per H2 block, in file order.
    """
    spans = line_spans(text)
    headings = [index for index, span in enumerate(spans) if span[1].startswith("## ")]
    blocks: List[Tuple[str, int]] = []
    for position, index in enumerate(headings):
        stop = headings[position + 1] if position + 1 < len(headings) else len(spans)
        blocks.append((spans[index][1][3:], slice_bytes(text, spans[index][2], spans[stop - 1][3])))
    return blocks


def landing_problems(rendered: Dict[str, str]) -> List[str]:
    """List the landing page blocks that exceed their byte cap.

    Args:
        rendered: Result of render_files().

    Returns:
        One line per oversized block.
    """
    problems: List[str] = []
    for heading, size in landing_blocks(rendered[LANDING_PATH]):
        if size > LANDING_BLOCK_LIMIT:
            problems.append(
                "landing block %s %d over %d" % (heading, size, LANDING_BLOCK_LIMIT)
            )
    return problems


# ───────────────────────────────────────────────────────────────
# 9. CHANGE NOTES
# ───────────────────────────────────────────────────────────────

def section_lines(text: str, keyword: str) -> List[str]:
    """Return the lines of the first H2 section whose heading holds a keyword.

    The section starts on its heading line and ends on the line before the
    next H1 or H2, so the blank and separator lines around it stay inside it.
    A heading inside frontmatter or inside a code block is no heading.

    Args:
        text: File text.
        keyword: Text that the heading must hold.

    Returns:
        The section lines without their line endings, empty when no heading
        matches.
    """
    spans = line_spans(text)
    headings = markdown_headings(text)
    for position, heading in enumerate(headings):
        if heading["level"] != 2:
            continue
        # WHY: the year notes print their H2 headings in capitals, so the match
        # ignores case.
        if keyword.lower() not in heading["text"].lower():
            continue
        stop = len(spans)
        for following in headings[position + 1:]:
            if following["level"] <= 2:
                stop = following["line"] - 1
                break
        return [span[1] for span in spans[heading["line"] - 1:stop]]
    return []


def topic_section_lines(text: str, number: int) -> List[str]:
    """Return the lines of one topic section, found by its stable anchor.

    A part renumbers its headings from 1, so the topic-wide section number
    survives only in the explicit anchor id under the heading, such as
    <a id="5-changes">.

    Args:
        text: File text of a year topic part.
        number: Topic-wide section number.

    Returns:
        The section lines without their line endings, empty when no anchor
        matches.
    """
    marker = '<a id="%d-' % number
    spans = line_spans(text)
    headings = [heading for heading in markdown_headings(text) if heading["level"] == 2]
    for position, heading in enumerate(headings):
        stop = headings[position + 1]["line"] - 1 if position + 1 < len(headings) else len(spans)
        lines = [span[1] for span in spans[heading["line"] - 1:stop]]
        if any(line.strip().startswith(marker) for line in lines):
            return lines
    return []


def bullet_lines(lines: List[str]) -> List[str]:
    """Return the text of every markdown bullet line.

    Args:
        lines: Lines of one section.

    Returns:
        The bullet texts without their marker, in file order.
    """
    return [
        line[len(CHANGE_BULLET_PREFIX):].strip()
        for line in lines
        if line.startswith(CHANGE_BULLET_PREFIX)
    ]


def topic_change_bullets(text: str) -> List[str]:
    """Read the section 5 bullets of one topic file.

    Args:
        text: File text of a year topic file.

    Returns:
        The bullet texts in file order, empty when the file holds no section 5
        heading.
    """
    return bullet_lines(topic_section_lines(text, CHANGE_SECTION_NUMBER))


def change_snippet(bullet: str) -> str:
    """Cut the first change bullet to a short table snippet.

    The cut lands on a word boundary, so a snippet never ends in the middle of
    a word. A pipe is escaped, because the snippet sits in a table cell.

    Args:
        bullet: First section 5 bullet of a topic file.

    Returns:
        The snippet, empty when the bullet is empty.
    """
    text = SPACE_RE.sub(" ", bullet).strip()
    if len(text) > CHANGE_SNIPPET_LIMIT:
        cut = text[:CHANGE_SNIPPET_LIMIT]
        space = cut.rfind(" ")
        if space > 0:
            cut = cut[:space]
        text = cut.rstrip(" ,.;:!?") + "..."
    return text.replace("|", "\\|")


def changes_row(name: str, link: str, bullets: List[str], used: Set[str]) -> str:
    """Render one change row of a year note.

    Args:
        name: Topic file name.
        link: Path of the part that holds section 5, relative to the note.
        bullets: Section 5 bullets of the topic file.
        used: Terms already glossed in this table, updated in place.

    Returns:
        The row line, without a line ending. The first cell links to the
        section 5 anchor of the part that holds it.
    """
    snippet = change_snippet(bullets[0]) if bullets else ""
    line = "| [%s](%s#%s) | %d | %s |" % (name, link, CHANGE_FRAGMENT, len(bullets), snippet)
    return gloss_cell(line, used)


@register_block(CHANGES_BLOCK_ID)
def changes_block(files: List[Dict[str, Any]]) -> Dict[str, str]:
    """Build the per-topic change table body of every year note.

    One row per canonical topic file of the year, in the canonical order, with
    the section 5 bullet count, the first bullet cut to a snippet and the link
    to the section 5 anchor. The rows come from the topic files alone, so a
    section 5 edit moves the table in one write run.

    Args:
        files: Result of load_files().

    Returns:
        The table body keyed by the note path. A year without a note keeps
        every existing body.

    Raises:
        SystemExit: If a year note sits in a folder that misses one of the
            canonical topic files.
    """
    by_path = {file["path"]: file for file in files}
    topics = canonical_topics(by_path)
    bodies: Dict[str, str] = {}
    for path in sorted(by_path):
        match = CHANGE_NOTE_RE.match(path)
        if match is None:
            continue
        year = match.group(1)
        note_dir = os.path.dirname(path)
        rows: List[str] = []
        used: Set[str] = set()
        for name in topics:
            topic_path = year_topic_path(by_path, year, name)
            if topic_path is None:
                fail("missing %s, every year folder holds each topic file" % ("%s/%s" % (year, name)))
            holder = topic_section_path(by_path, topic_path, CHANGE_SECTION_NUMBER)
            link = os.path.relpath(holder, note_dir).replace(os.sep, "/") if note_dir else holder
            rows.append(changes_row(name, link, topic_change_bullets(by_path[holder]["text"]), used))
        bodies[path] = table_text(CHANGES_TABLE_HEADER, rows, CHANGES_TABLE_SEPARATOR)
    return bodies


def authored_bullets(text: str) -> List[str]:
    """Read the authored bullets of a year change note.

    Args:
        text: File text of a year change note.

    Returns:
        The bullet texts of the "Unique to <year>" section, in file order.
    """
    return bullet_lines(section_lines(text, CHANGES_UNIQUE_PREFIX))


def last_link_target(text: str) -> str:
    """Return the target of the last markdown link on a line.

    Args:
        text: One bullet line.

    Returns:
        The target, empty when the line holds no link.
    """
    targets = LINK_TARGET_RE.findall(text)
    return targets[-1] if targets else ""


def overview_bullet(year: str, bullet: str, overview_dir: str) -> str:
    """Return one authored bullet with its topic link aimed at the year folder.

    A bullet in a year note links to its topic file as a sibling. The overview
    sits beside the year folders, so the same link needs the year folder in
    front and the target resolves against the overview folder. Every other
    part of the bullet stays as it is.

    Args:
        year: Year folder of the note.
        bullet: Authored bullet of the note.
        overview_dir: Folder of the overview relative to the references root.

    Returns:
        The bullet for the overview.
    """
    targets = list(LINK_TARGET_RE.finditer(bullet))
    if not targets:
        return bullet
    match = targets[-1]
    path, separator, fragment = match.group(1).partition("#")
    if not path or separator != "#" or fragment != CHANGE_FRAGMENT:
        return bullet
    resolved = os.path.normpath(os.path.join(overview_dir, year, path)).replace(os.sep, "/")
    link = os.path.relpath(resolved, overview_dir).replace(os.sep, "/") if overview_dir else resolved
    return bullet[:match.start()] + "](%s#%s)" % (link, fragment) + bullet[match.end():]


def year_note_years(files: List[Dict[str, Any]]) -> List[str]:
    """List the year folders that hold a change note, newest first.

    Args:
        files: Result of load_files().

    Returns:
        The four digit years in descending order.
    """
    years = []
    for file in files:
        match = CHANGE_NOTE_RE.match(file["path"])
        if match is not None:
            years.append(match.group(1))
    return sorted(years, reverse=True)


def year_changes_text(files: List[Dict[str, Any]]) -> str:
    """Render the whole year change overview.

    One overview section and one H2 per year, newest first, with a path link
    to the year note and the authored bullets of that note. The file is
    generated whole, so it carries its own frontmatter and H1.

    Args:
        files: Result of load_files().

    Returns:
        The complete file text.
    """
    by_path = {file["path"]: file for file in files}
    lines = [
        "---",
        'title: "Year changes"',
        'description: "Generated overview of the changes in every tax year, newest first, with the path to each year note."',
        'nav_label: "Year changes"',
        "trigger_phrases:",
        '  - "year changes overview"',
        '  - "what changed per tax year"',
        '  - "changes year by year"',
        "importance_tier: normal",
        "contextType: research",
        "version: 1.0.0.0",
        "---",
        "",
        "# Year changes",
        "",
        "Generated overview of the changes in every tax year. Each section names the year note and repeats its authored bullets. The note owns the wording, so one edit moves both files.",
        "",
        "## 1. OVERVIEW",
        "",
        "This reference gathers the changes in every tax year, newest first, with the path to each year note. Each year section repeats the authored bullets of that note, which owns the wording.",
        "",
        "---",
        "",
    ]
    notes: Dict[str, str] = {}
    for path in sorted(by_path):
        match = CHANGE_NOTE_RE.match(path)
        if match is not None:
            notes[match.group(1)] = path
    overview_dir = os.path.dirname(year_changes_path(files))
    for year in year_note_years(files):
        note = by_path[notes[year]]
        bullets = authored_bullets(note["text"])
        lines.append("## %s" % year)
        lines.append("")
        lines.append("Path: [%s/%s](%s/%s)" % (year, CHANGE_NOTE_NAME, year, CHANGE_NOTE_NAME))
        lines.append("")
        for bullet in bullets:
            lines.append("- %s" % overview_bullet(year, bullet, overview_dir))
        if bullets:
            lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def change_note_problems(files: List[Dict[str, Any]]) -> List[str]:
    """List the failures of the authored change bullets.

    A bullet fails when it holds no link or a link that does not resolve to an
    existing topic file and its section 5 anchor, when one of its numbers does
    not occur as the same number in the linked section 5, or when its year
    note holds fewer than five or more than ten authored bullets. A number
    matches only as a whole token, so a bullet that says 26 does not match
    2026 in the section text.

    Args:
        files: Result of load_files().

    Returns:
        One line per failure, naming the note, the bullet and the reason.
    """
    by_path = {file["path"]: file for file in files}
    problems: List[str] = []
    for path in sorted(by_path):
        match = CHANGE_NOTE_RE.match(path)
        if match is None:
            continue
        year = match.group(1)
        note_dir = os.path.dirname(path)
        bullets = authored_bullets(by_path[path]["text"])
        if not CHANGE_BULLET_MIN <= len(bullets) <= CHANGE_BULLET_MAX:
            problems.append(
                "changes %s %d authored bullets, the band is %d to %d"
                % (path, len(bullets), CHANGE_BULLET_MIN, CHANGE_BULLET_MAX)
            )
        for position, bullet in enumerate(bullets, 1):
            target = last_link_target(bullet)
            path_part, separator, fragment = target.partition("#")
            resolved = ""
            if path_part and separator == "#":
                resolved = os.path.normpath(os.path.join(note_dir, path_part)).replace(os.sep, "/")
            marker = '<a id="%s"></a>' % CHANGE_FRAGMENT
            topic = by_path.get(resolved) if resolved.startswith(note_dir + "/") else None
            if (
                not target
                or separator != "#"
                or fragment != CHANGE_FRAGMENT
                or topic is None
                or marker not in topic["text"]
            ):
                problems.append(
                    "changes %s bullet %d link %s does not resolve"
                    % (path, position, target or "none")
                )
                continue
            section = "\n".join(topic_section_lines(topic["text"], CHANGE_SECTION_NUMBER))
            section_numbers = set(NUMBER_RE.findall(section))
            for number in NUMBER_RE.findall(CHANGE_PROSE_LINK_RE.sub(" ", bullet)):
                if number not in section_numbers:
                    problems.append(
                        "changes %s bullet %d number %s not in %s#%s"
                        % (path, position, number, path_part, CHANGE_FRAGMENT)
                    )
                    break
    return problems


# ───────────────────────────────────────────────────────────────
# 10. SECTION 3 BLOCKS
# ───────────────────────────────────────────────────────────────

def section_three_headings(text: str) -> List[Dict[str, Any]]:
    """Map the H3 headings of one file outside frontmatter and code.

    Args:
        text: File text.

    Returns:
        One record per H3 heading with its span index and its text.
    """
    spans = line_spans(text)
    headings: List[Dict[str, Any]] = []
    in_code = False
    frontmatter_stop = frontmatter_end(spans)
    for index, (_, content, _, _) in enumerate(spans):
        if index < frontmatter_stop:
            continue
        stripped = content.strip()
        if stripped.startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = HEADING_RE.match(content)
        if match and len(match.group(1)) == 3:
            headings.append({"index": index, "text": match.group(2).strip()})
    return headings


def source_section_three_specs(source: Dict[str, Any], seen: Set[str]) -> List[Dict[str, Any]]:
    """Map the section 3 subsections of one general file.

    Every numbered H3 heading of the file counts as a subsection.

    Args:
        source: File record to scan.
        seen: Block ids already recorded, updated in place.

    Returns:
        One record per subsection, with the block id, the named file names and
        the path of the file that holds it.

    Raises:
        SystemExit: If a subsection holds no year files line, a year files
            line names no file, or two subsections share a block id.
    """
    spans = line_spans(source["text"])
    candidates = section_three_headings(source["text"])
    specs: List[Dict[str, Any]] = []
    for position, heading in enumerate(candidates):
        match = SECTION_THREE_HEADING_RE.match(heading["text"])
        if not match:
            continue
        last = candidates[position + 1]["index"] if position + 1 < len(candidates) else len(spans)
        line = next(
            (span for span in spans[heading["index"] + 1:last] if span[1].startswith(YEAR_FILES_MARKER)), None
        )
        if line is None:
            fail("no %s line in %s of %s" % (YEAR_FILES_MARKER, heading["text"], source["path"]))
        names = YEAR_FILES_NAME_RE.findall(line[1])
        if not names:
            fail("no year file name on line %d of %s" % (line[0], source["path"]))
        block_id = SECTION_BLOCK_PREFIX + slugify(match.group(1))
        if block_id in seen:
            fail("duplicate block id %s in %s" % (block_id, source["path"]))
        seen.add(block_id)
        specs.append({"id": block_id, "files": names, "path": source["path"]})
    return specs


def section_three_specs(files: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Map the subsections of section 3 and the year files they name.

    A subsection names its year files on a line that starts with the year
    files marker. The subsections sit in the general folder, one per file, so
    the scan reads those files.

    Args:
        files: Result of load_files().

    Returns:
        One record per subsection, with the block id, the named file names
        and the path of the file that holds it.

    Raises:
        SystemExit: If the general folder holds no subsection, a subsection
            holds no year files line, a year files line names no file, or two
            subsections share a block id.
    """
    general = sorted((file for file in files if is_general_path(file["path"])), key=lambda file: file["path"])
    subsections: List[Dict[str, Any]] = []
    seen: Set[str] = set()
    for source in general:
        subsections.extend(source_section_three_specs(source, seen))
    if not subsections:
        fail("no subsection with a %s line in a %s folder file" % (YEAR_FILES_MARKER, GENERAL_DIR_NAME))
    return {"subsections": subsections}


def section_three_row(
    year: str, path: str, figure: Dict[str, str], link: str, used: Set[str]
) -> str:
    """Render one value row of a section 3 block.

    Args:
        year: Year folder of the owning file.
        path: Path of the owning file relative to the references root.
        figure: Headline figure from headline_figures().
        link: Link target of the owning file, relative to the guide.
        used: Terms already glossed in this table, updated in place.

    Returns:
        The row line. The owner cell names the year file by its path from the
        repository root and links to the file itself.
    """
    line = "| %s | %s | %s | %s | %s | [%s](%s) |" % (
        year,
        figure["item"],
        figure["value"],
        figure["status"],
        figure["check"],
        OWNER_PREFIX + path,
        link,
    )
    return gloss_cell(line, used)


def section_three_bodies(by_path: Dict[str, Dict[str, Any]], spec: Dict[str, Any]) -> Dict[str, str]:
    """Build the value rows of one subsection of section 3.

    The rows come from the named year files, one row per headline figure of
    every file that a year folder holds, keyed by the topic file and the item
    of the value. They are ordered by file, then by year, then by their place
    in the KEY FIGURES table, so a row keeps its place when a year folder
    gains a file.

    Args:
        by_path: File records keyed by relative path.
        spec: Subsection record from section_three_specs().

    Returns:
        The block body keyed by the path of the file that holds the
        subsection, empty when no named file is in the tree.
    """
    years = sorted({year for year in (year_of(path) for path in by_path) if year is not None})
    rows: List[str] = []
    used: Set[str] = set()
    holder = spec["path"]
    holder_dir = os.path.dirname(holder)
    for name in spec["files"]:
        for year in years:
            path = year_topic_path(by_path, year, name)
            if path is None:
                continue
            link = os.path.relpath(path, holder_dir).replace(os.sep, "/") if holder_dir else path
            _, figures = headline_figures({"path": path, "figures": key_figures(by_path[path])})
            for figure in figures:
                rows.append(section_three_row(year, path, figure, link, used))
    if not rows:
        return {}
    table = table_text(SECTION_THREE_HEADER, rows, SECTION_THREE_SEPARATOR)
    return {holder: SECTION_THREE_SENTENCE + "\n\n" + table}


def section_three_builder(spec: Dict[str, Any]) -> BlockBuilder:
    """Build the block builder of one subsection of section 3.

    Args:
        spec: Subsection record from section_three_specs().

    Returns:
        A builder that returns the body of the subsection block.
    """

    def builder(files: List[Dict[str, Any]]) -> Dict[str, str]:
        return section_three_bodies({file["path"]: file for file in files}, spec)

    return builder


def register_section_three_blocks(section: Dict[str, Any]) -> None:
    """Register one generated block per subsection of section 3.

    Args:
        section: Result of section_three_specs().
    """
    for spec in section["subsections"]:
        register_builder(spec["id"], section_three_builder(spec))


# ───────────────────────────────────────────────────────────────
# 11. HEADING AND SLICE HELPERS
# ───────────────────────────────────────────────────────────────

def markdown_headings(text: str) -> List[Dict[str, Any]]:
    """Map every heading outside the frontmatter and the code blocks.

    Args:
        text: File text.

    Returns:
        One record per heading, in file order, with the line number, the
        level, the heading text and the line start offset.
    """
    spans = line_spans(text)
    headings: List[Dict[str, Any]] = []
    in_code = False
    for number, content, start, _ in spans[frontmatter_end(spans):]:
        stripped = content.strip()
        if stripped.startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = HEADING_RE.match(content)
        if not match:
            continue
        headings.append(
            {
                "line": number,
                "level": len(match.group(1)),
                "text": match.group(2).strip(),
                "start": start,
            }
        )
    return headings


def slice_bytes(text: str, start: int, end: int) -> int:
    """Count the UTF-8 bytes of one slice of text.

    Args:
        text: File text.
        start: Start offset.
        end: End offset.

    Returns:
        The byte count of the slice.
    """
    return len(text[start:end].encode("utf-8"))


# ───────────────────────────────────────────────────────────────
# 12. BLOCK BODIES
# ───────────────────────────────────────────────────────────────

def load_files() -> List[Dict[str, Any]]:
    """Read every input file and parse its fences.

    Returns:
        One record per file with the relative path, the absolute path, the
        text, the title, the sections and the fence blocks, in path order.

    Raises:
        SystemExit: If a file cannot be read or decoded, or on a fence error.
    """
    files: List[Dict[str, Any]] = []
    for path in reference_files():
        relative = relative_path(path)
        text = read_text(path)
        title, sections = scan_sections(text)
        blocks: List[Dict[str, Any]] = []
        if path.endswith(MARKDOWN_SUFFIX):
            try:
                blocks = parse_fences(text)
            except FenceError as error:
                print("reference-index: fence error %s:%d %s" % (relative, error.line, error.reason))
                sys.exit(2)
        files.append(
            {
                "path": relative,
                "absolute": path,
                "text": text,
                "title": title,
                "sections": sections,
                "blocks": blocks,
            }
        )
    return files


def block_bodies(files: List[Dict[str, Any]]) -> Dict[str, Dict[str, str]]:
    """Run every registered builder over the scanned files.

    Args:
        files: Result of load_files().

    Returns:
        Bodies keyed by block id and then by relative path.
    """
    bodies: Dict[str, Dict[str, str]] = {}
    for block_id in sorted(BLOCK_BUILDERS):
        produced = BLOCK_BUILDERS[block_id](files)
        for path in produced:
            bodies.setdefault(block_id, {})[path] = produced[path]
    return bodies


def body_text(body: str) -> str:
    """Return a block body as it is written between two markers.

    Args:
        body: Builder output.

    Returns:
        The body, with a trailing newline added when it misses one, so the end
        marker keeps a line of its own.
    """
    if not body or body.endswith("\n"):
        return body
    return body + "\n"


def missing_fences(files: List[Dict[str, Any]], bodies: Dict[str, Dict[str, str]]) -> List[Tuple[str, str]]:
    """List the builder outputs that have no fence to sit in.

    Args:
        files: Result of load_files().
        bodies: Result of block_bodies().

    Returns:
        One (path, block id) pair per builder output without a fence, ordered
        by block id and then by path.
    """
    known = set()
    for file in files:
        for block in file["blocks"]:
            known.add((file["path"], block["id"]))
    return [
        (path, block_id)
        for block_id in sorted(bodies)
        for path in sorted(bodies[block_id])
        if (path, block_id) not in known
    ]


def render_files(files: List[Dict[str, Any]], bodies: Dict[str, Dict[str, str]]) -> Dict[str, str]:
    """Return the expected text of every file after the block bodies.

    Only the bytes between a matched fence pair are replaced. The year change
    overview is generated whole, so its text is set here and the index and
    every drift report read the generated form.

    Args:
        files: Result of load_files().
        bodies: Result of block_bodies().

    Returns:
        Expected text keyed by relative path.
    """
    rendered: Dict[str, str] = {}
    for file in files:
        text = file["text"]
        replacements = []
        for block in file["blocks"]:
            if file["path"] in bodies.get(block["id"], {}):
                replacements.append(
                    (block["body_start"], block["body_end"], body_text(bodies[block["id"]][file["path"]]))
                )
        # WHY: the latest replacement goes first, so every earlier offset stays valid.
        for start, end, body in sorted(replacements, reverse=True):
            text = text[:start] + body + text[end:]
        rendered[file["path"]] = text
    rendered[year_changes_path(files)] = year_changes_text(files)
    rendered[LANDING_PATH] = landing_text(files)
    return rendered


def expected_index(files: List[Dict[str, Any]], rendered: Dict[str, str]) -> str:
    """Render the index from the expected file texts.

    Args:
        files: Result of load_files().
        rendered: Result of render_files().

    Returns:
        The index text a write would produce.
    """
    entries = [
        index_entry(file["path"], rendered[file["path"]])
        for file in files
        if file["path"].endswith(MARKDOWN_SUFFIX)
    ]
    entries.sort(key=lambda entry: entry["path"])
    return build_index_text(entries, gap_rows(files))


# ───────────────────────────────────────────────────────────────
# 13. CHECK AND WRITE
# ───────────────────────────────────────────────────────────────

def check_all(files: List[Dict[str, Any]], bodies: Dict[str, Dict[str, str]], rendered: Dict[str, str]) -> int:
    """Report every block, index or landing page that differs from its generated form.

    Args:
        files: Result of load_files().
        bodies: Result of block_bodies().
        rendered: Result of render_files().

    Returns:
        Zero when nothing differs, one otherwise.
    """
    by_path = {file["path"]: file for file in files}
    overview = year_changes_path(files)
    problems = landing_problems(rendered)
    problems += gap_problems(files)
    problems += ["drift %s %s" % pair for pair in missing_fences(files, bodies)]
    for file in files:
        # WHY: the overview and the landing page are generated whole and
        # reported on their own lines, so the block loop leaves them out.
        if file["path"] in (overview, LANDING_PATH):
            continue
        for block in file["blocks"]:
            produced = bodies.get(block["id"], {}).get(file["path"])
            if produced is None:
                continue
            if body_text(produced) != block["body"]:
                problems.append("drift %s %s" % (file["path"], block["id"]))
    problems += change_note_problems(files)
    if by_path[overview]["text"] != rendered[overview]:
        problems.append("drift %s" % YEAR_CHANGES_NAME)
    if by_path[LANDING_PATH]["text"] != rendered[LANDING_PATH]:
        problems.append("drift %s" % LANDING_NAME)
    if read_index() != expected_index(files, rendered):
        problems.append("drift %s" % INDEX_NAME)
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("reference-index: ok")
    return 0


def write_all(files: List[Dict[str, Any]], bodies: Dict[str, Dict[str, str]], rendered: Dict[str, str]) -> int:
    """Write every changed file, the year change overview and the index.

    Args:
        files: Result of load_files().
        bodies: Result of block_bodies().
        rendered: Result of render_files().

    Returns:
        Zero when the write ran, one when a fence is missing.
    """
    missing = missing_fences(files, bodies)
    if missing:
        for path, block_id in missing:
            print("missing %s %s" % (path, block_id))
        print("reference-index: add the fence pair of each block above by hand before a write")
        return 1
    written = []
    for file in files:
        if rendered[file["path"]] != file["text"]:
            write_text(file["absolute"], rendered[file["path"]])
            written.append(file["path"])
    text = expected_index(files, rendered)
    index_changed = read_index() != text
    if index_changed:
        write_text(INDEX_PATH, text)
    if not written and not index_changed:
        print("reference-index: %d files, no change" % len(files))
        return 0
    for path in written:
        print("reference-index: wrote %s" % path)
    if index_changed:
        print("reference-index: wrote %s" % INDEX_NAME)
    return 0


# ───────────────────────────────────────────────────────────────
# 14. REACHABILITY CHECK
# ───────────────────────────────────────────────────────────────

def is_folder_index(path: str) -> bool:
    """Tell whether a markdown file is the index page of its own folder.

    Args:
        path: Path relative to the skill root.

    Returns:
        True for a file like feature-catalog/feature-catalog.md, False for a
        README.md or any other file.
    """
    name = os.path.basename(path)
    if not name.endswith(MARKDOWN_SUFFIX) or name == README_NAME:
        return False
    return os.path.splitext(name)[0] == os.path.basename(os.path.dirname(path))


def manifest_leaves() -> List[str]:
    """Read the leaf paths from the skill leaf manifest.

    Returns:
        The sorted leaf paths of every mode, relative to the skill root.

    Raises:
        SystemExit: If the manifest is missing or holds invalid JSON.
    """
    if not os.path.isfile(MANIFEST_PATH):
        fail("missing %s, the reachability check reads it" % MANIFEST_NAME)
    try:
        manifest = json.loads(read_text(MANIFEST_PATH))
    except json.JSONDecodeError as exc:
        fail("cannot parse %s: %s" % (MANIFEST_NAME, exc))
    leaves: Set[str] = set()
    for mode in manifest.get("modes", []):
        for leaf in mode.get("leaves", []):
            leaves.add(str(leaf).replace(os.sep, "/"))
    return sorted(leaves)


def reachability_sources() -> Dict[str, str]:
    """Read the pages that can route a reader to a leaf.

    The sources are SKILL.md, ROUTER.md, the reference index, every README.md and every
    folder index page inside the skill. A caller decides whether a folder
    index page counts.

    Returns:
        File text keyed by path relative to the skill root.
    """
    sources: Dict[str, str] = {}
    for relative in ENTRY_PAGES + ("references/" + INDEX_NAME,):
        path = os.path.join(SKILL_ROOT, relative)
        if os.path.isfile(path):
            sources[relative] = read_text(path)
    for directory, _, names in os.walk(SKILL_ROOT):
        for name in names:
            path = os.path.join(directory, name)
            relative = os.path.relpath(path, SKILL_ROOT).replace(os.sep, "/")
            if relative in sources:
                continue
            if name != README_NAME and not is_folder_index(relative):
                continue
            sources[relative] = read_text(path)
    return sources


def source_mentions(source: str, text: str, target: str) -> bool:
    """Tell whether one page names a path or links to it.

    A relative link is resolved against the folder of the page that holds it,
    so a folder index reaches the files next to it.

    Args:
        source: Path of the page relative to the skill root.
        text: Page text.
        target: Path to look for, relative to the skill root.

    Returns:
        True when the page holds the path as text or as a relative link.
    """
    if target in text:
        return True
    base = os.path.dirname(source)
    for link in LINK_TARGET_RE.findall(text):
        clean = link.split("#", 1)[0]
        if not clean or ":" in clean:
            continue
        resolved = os.path.normpath(os.path.join(base, clean)).replace(os.sep, "/")
        if resolved == target:
            return True
    return False


def missing_leaves(leaves: List[str]) -> List[str]:
    """Return the manifest leaves that no file on disk backs.

    The routed prefix exempts a reachable leaf from the walk, so a deleted
    reference file has to fail here instead. A manifest leaf that names no
    file is a stale manifest, not a routing gap.

    Args:
        leaves: Leaf paths from the manifest.

    Returns:
        The sorted paths of the leaves that are absent from the skill folder.
    """
    return sorted(leaf for leaf in leaves if not os.path.isfile(os.path.join(SKILL_ROOT, leaf)))


def unreachable_leaves(leaves: List[str], sources: Dict[str, str]) -> List[str]:
    """Return the leaves that no routed folder and no reachable page reaches.

    A leaf under the routed reference folders is reachable through the
    task-type table. Any other leaf is reachable when a reachable page names
    it or links to it. A folder index page counts as a page only once
    SKILL.md or ROUTER.md links it, so the catalog and the playbook route
    nothing while both pages leave their roots out. A leaf with no file on disk is left to
    missing_leaves(), so the two reports never name the same path.

    Args:
        leaves: Leaf paths from the manifest.
        sources: Result of reachability_sources().

    Returns:
        The sorted paths of the leaves that stay unreachable.
    """
    active = {path: text for path, text in sources.items() if not is_folder_index(path)}
    for path in sorted(sources):
        if is_folder_index(path) and any(
            source_mentions(page, sources.get(page, ""), path) for page in ENTRY_PAGES
        ):
            active[path] = sources[path]
    pending = {
        leaf
        for leaf in leaves
        if not leaf.startswith(ROUTED_PREFIX) and os.path.isfile(os.path.join(SKILL_ROOT, leaf))
    }
    for leaf in sorted(pending):
        if any(source_mentions(path, text, leaf) for path, text in active.items()):
            pending.discard(leaf)
    return sorted(pending)


def reachability_report() -> int:
    """Report the manifest leaves that no route reaches or that no file backs.

    Returns:
        Zero when every leaf exists and is reachable, one otherwise.
    """
    leaves = manifest_leaves()
    missing = missing_leaves(leaves)
    gaps = unreachable_leaves(leaves, reachability_sources())
    print("reachability: %d of %d leaves reachable" % (len(leaves) - len(gaps) - len(missing), len(leaves)))
    for leaf in missing:
        print("missing %s" % leaf)
    for leaf in gaps:
        print("unreachable %s" % leaf)
    return 1 if gaps or missing else 0


# ───────────────────────────────────────────────────────────────
# 15. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the mode that they select.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code reported by the mode that ran.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Build or check the reference index and the generated blocks.",
    )
    parser.add_argument("--check", action="store_true", help="compute every output and report drift without writing")
    args = parser.parse_args(argv)
    if not os.path.isdir(REFERENCES_ROOT):
        fail("references folder not found: %s" % REFERENCES_ROOT)
    # WHY: the baseline and the term map are the generator's other inputs,
    # read once per run.
    global BASELINE, TERMS
    BASELINE = load_baseline()
    TERMS = load_terms()
    files = load_files()
    register_section_three_blocks(section_three_specs(files))
    bodies = block_bodies(files)
    rendered = render_files(files, bodies)
    if args.check:
        drift_status = check_all(files, bodies, rendered)
        reachability_status = reachability_report()
        return 1 if drift_status or reachability_status else 0
    return write_all(files, bodies, rendered)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
