#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: REFERENCE INDEX BUILDER
# ───────────────────────────────────────────────────────────────
"""Build or check the reference index and the generated blocks.

Scans the markdown and the JSON under sk-moneybird-accountant/references/ and
writes two kinds of output from the same run, references/index.json, a
structure-only map of every markdown file and its H2 sections, and the bodies
of the generated blocks that sit between the fence markers inside the
reference files. The script uses the Python standard library only and makes no
network call. Output is byte-stable: sorted paths, sorted keys, LF line
endings, no timestamp and no random part. Paths in the output and in the
messages are relative to the references root.

The two year README blocks read the topic files of one year folder. Their row
order and their text come from the corpus at run time: the topic order from
the topic table in references/dutch-tax-rules.md, the covers and the topic
labels from the topic-file frontmatter, and the counts and the headline rows
from the KEY FIGURES table of every topic file.

A markdown file over 51,200 bytes gets a read plan between its H1 and the
rest of the file. The plan splits the file at its H2 and H3 lines, names the
next read offset and keeps every part at or under the byte limit. A single
section over the limit has no heading inside it and becomes one oversized
part. The plan states its own size and sits in the first part, so the writer
plans that part against the byte limit minus the longest plan seen so far,
then rebuilds the plan on the file that holds it until two rounds agree. A
plan is measured on the file as a write would leave it, so every other block
body of that file is in place before the parts are sized.

The reference guide gets a second generated block, a compact list of its H2
sections and its 3.n subsections with the line range of each on the final
file. The list sits right after the read plan, so the two bodies shift the
same lines and are rebuilt together until neither changes. A guide over the
byte limit gets the list. A nav or a list body over the block budget fails
--check. The budget of one file is the smaller of a fixed byte count and one
percent of its file size.

Section 3 of the reference guide holds the rules that span tax years, and it
restates figures that the year files own. One generated block sits in every
subsection of that section, right after the line that names the year files of
the subsection. Its table repeats the first two KEY FIGURES rows of every
named file for every year folder that holds the file, and the owner cell
names the year file that owns the value. The rule prose around the block
stays hand-written.

A generated block is fenced by two marker lines that each stand alone:

    <!-- GENERATED:<block-id>:start -->
    <!-- GENERATED:<block-id>:end -->

The generator replaces only the bytes between a matched pair and never
touches a byte outside one. A missing pair is added by --init at the anchor
that the block registered, and only body bytes move, so hand prose survives a
regeneration byte for byte. An unmatched marker, a nested start, a duplicate
block id, a malformed marker or a marker inside a code block stops the run
with exit code 2 and names the file, the line and the reason.

A block generator registers a builder keyed by its block id, and an optional
anchor that tells --init where the empty pair belongs. A block without a
registered builder is left as it is.

Every year folder gets a change note at references/<year>/changes.md. Its first
section is authored, and its second section is a generated table with one row
per topic file: the section 5 bullet count, the first bullet cut to a snippet
and the link to the section 5 anchor. The note sits between one fence pair with
the id changes. references/year-changes.md is generated whole, one H2 per year,
newest first, with the path link to the year note and the authored bullets of
that note, so the index reads the generated form. --check also checks the
authored bullets. A number in a bullet must occur as the same number in the
linked section 5. The last link of a bullet must resolve to an existing file
and its section 5 anchor. A year note must hold five to ten authored bullets.

A manifest at the skill root lists the leaves that a reader must be able to
reach. The reachability check reads it under --check and under --reachability
alone. A leaf under the routed reference folders is reachable through the
task-type table in SKILL.md. Every other leaf is reachable when its path or a
relative link to it appears in SKILL.md, in the reference index or in a
README.md or a folder index page. A folder index page counts only once
SKILL.md links it, so the feature catalog and the playbook route no leaf
while SKILL.md leaves their roots out.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --check
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --init
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --overlap
    python3 -I sk-moneybird-accountant/scripts/build-reference-index.py --reachability

Options:
    --check         Compute every output in memory and report each block or
                    index that differs, without writing. Exits 1 on drift, on
                    a block over its byte budget or on an unreachable
                    manifest leaf.
    --init          Insert the fence pair of every registered block that a
                    file misses, at its anchor. A pair may frame bytes that
                    are already in the file, so a table that is already
                    correct keeps its bytes. Idempotent, and it writes no
                    index.
    --overlap       Report the headline values that section 3 of the guide
                    restates in its prose, and how many of them no generated
                    row owns. Reads only and exits 0.
    --reachability  Report every manifest leaf that no routed folder and no
                    reachable page reaches. Reads only and exits 1 on a gap.

Output:
    references/index.json and the fence bodies, one "drift" line per stale
    block and one "budget" line per block over its cap in check mode, the
    overlap summary line in overlap mode, or the reachability summary and one
    line per unreachable leaf. Exit 0 when everything matches, 1 on drift, a
    block over its cap or an unreachable leaf, and 2 on a usage error, a read
    error, a fence error or a write error.
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
from typing import Any, Callable, Dict, List, NoReturn, Optional, Set, Tuple, Union

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

# Fallback id for a whole-file difference that no single block explains. It
# never fires while every write goes through the fence replacement.
FILE_DRIFT_ID = "generated-content"

# The two year README blocks describe the topic files of one year folder. The
# canonical topic order lives in the topic table of the reference guide, so no
# order list is kept here. A year folder keeps its topic files directly, at any
# depth below the references root, so the year folder is one path part and the
# topic file names stay the part that carries the topic.
YEAR_README_RE = re.compile(r"^(?:.*/)?(\d{4})/README\.md$")
YEAR_PART_RE = re.compile(r"^\d{4}$")
TOPIC_ORDER_FILE = "dutch-tax-rules.md"
TOPIC_ORDER_HEADING = "Topic files in every year folder"
TOPIC_NAME_PATTERN = r"[A-Za-z0-9._-]+\.md"
TOPIC_FILES_HEADING = "TOPIC FILES"
HEADLINE_FIGURES_HEADING = "HEADLINE FIGURES"
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
SECTION_THREE_NUMBER = 3
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
OWNER_LINK_RE = re.compile(r"\]\(([^)]+)\)")

# A markdown file over this byte count gets a read plan after its H1. No part
# of the plan may pass the limit, and the plan splits only on H2 or H3 lines
# so one read stops at a heading and not inside a section.
NAV_BLOCK_ID = "nav"
NAV_LIMIT = 51200
NAV_HEADING_LEVELS = (2, 3)
# WHY: every round can only move the first boundary back, at most once per
# heading, so the round cap is a guard and never the stop of a real plan.
NAV_MAX_ROUNDS = 4096

# The guide gets a list of its sections with the line range of each on the
# final file. It sits right after the read plan, so a plan of another length
# moves the ranges and the list bytes move the part sizes. Both bodies are
# rebuilt together until they settle on the same file.
TOC_BLOCK_ID = "toc"
TOC_SECTIONS_HEADING = "Sections and line ranges"
TOC_ENTRY_PREFIX = "- "
TOC_SECTION_PREFIX = "3."
NAVIGATION_BLOCK_IDS = (NAV_BLOCK_ID, TOC_BLOCK_ID)

# A nav or a section list body over its budget fails --check. The budget of
# one file is the smaller of a fixed byte count and one percent of its size.
BUDGET_BYTE_LIMIT = 1200
BUDGET_PERCENT = 1

# The reachability check reads the leaf manifest at the skill root and the
# pages that route a reader to a leaf. A leaf under the routed reference
# folders is reachable by definition, every other leaf needs its path or a
# relative link to it in a page that SKILL.md itself reaches.
MANIFEST_NAME = "leaf-manifest.json"
MANIFEST_PATH = os.path.join(SKILL_ROOT, MANIFEST_NAME)
SKILL_PAGE = "SKILL.md"
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
CHANGE_NOTE_RE = re.compile(r"^(\d{4})/" + re.escape(CHANGE_NOTE_NAME) + r"$")
CHANGES_BLOCK_ID = "changes"
CHANGES_UNIQUE_PREFIX = "Unique to "
CHANGES_BY_TOPIC_HEADING = "All changes by topic"
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

# An anchor returns the character offset where --init inserts the empty fence
# pair of one file, or None when the file needs no pair. The offset must sit
# at the start of a line. An anchor may return a (start, end) pair instead,
# which plants the start marker at the first offset and the end marker at the
# second, so the two markers frame the bytes that already sit between them.
BlockAnchor = Callable[[Dict[str, Any]], Optional[Union[int, Tuple[int, int]]]]

BLOCK_BUILDERS: Dict[str, BlockBuilder] = {}
BLOCK_ANCHORS: Dict[str, BlockAnchor] = {}


def register_builder(block_id: str, builder: BlockBuilder, anchor: Optional[BlockAnchor] = None) -> None:
    """Register one block builder under its fence id.

    Args:
        block_id: Fence id of the block.
        builder: Function that returns the body of the block per relative
            path, with the fences left out.
        anchor: Offset locator that --init uses for a missing pair. It returns
            one offset or a start and end offset pair.

    Raises:
        SystemExit: If the id does not match the fence id pattern.
    """
    if not BLOCK_ID_RE.match(block_id):
        fail("invalid block id: %s" % block_id)
    BLOCK_BUILDERS[block_id] = builder
    if anchor is not None:
        BLOCK_ANCHORS[block_id] = anchor


def register_block(block_id: str, anchor: Optional[BlockAnchor] = None) -> Callable[[BlockBuilder], BlockBuilder]:
    """Register one generated block under its fence id.

    A block generator decorates its builder with this function and passes its
    id, so the marker text stays in this file alone. The anchor is optional.
    A block without one cannot be added by --init.

    Args:
        block_id: Fence id of the block.
        anchor: Offset locator that --init uses for a missing pair. It returns
            one offset or a start and end offset pair.

    Returns:
        Decorator that registers the builder function.
    """

    def decorate(builder: BlockBuilder) -> BlockBuilder:
        register_builder(block_id, builder, anchor)
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


def reference_files(depth: Optional[int] = None) -> List[str]:
    """List the markdown and the JSON files under the references root.

    Args:
        depth: Maximum folder depth below the references root, or None for
            every depth. A file directly in the references root sits at
            depth 0. The generated index is never an input.

    Returns:
        Sorted absolute paths.
    """
    found = []
    base = os.path.abspath(REFERENCES_ROOT)
    for directory, _, names in os.walk(base):
        relative = os.path.relpath(directory, base)
        level = 0 if relative == "." else relative.count(os.sep) + 1
        if depth is not None and level > depth:
            continue
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


def fence_line(block_id: str, kind: str) -> str:
    """Build one fence marker line from the marker parts and a block id.

    Args:
        block_id: Fence id of the block.
        kind: "start" or "end".

    Returns:
        The marker line without a line ending.
    """
    suffix = FENCE_START_SUFFIX if kind == "start" else FENCE_END_SUFFIX
    return FENCE_PREFIX + block_id + suffix


def init_text(block_id: str) -> str:
    """Build the text --init inserts for one empty block.

    The text holds the two marker lines and at most one blank line around
    them, so a hand edit elsewhere in the file keeps its spacing.

    Args:
        block_id: Fence id of the block.

    Returns:
        The inserted text, which starts and ends with a line ending.
    """
    lines = ["", fence_line(block_id, "start"), fence_line(block_id, "end"), ""]
    return "".join(line + "\n" for line in lines)


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
        A row with the path, the H1 title, the byte count, the line count and
        the H2 sections. It holds structure only, never a figure.
    """
    title, sections = scan_sections(text)
    return {
        "path": path,
        "title": title,
        "bytes": len(text.encode("utf-8")),
        "lines": len(line_spans(text)),
        "sections": sections,
    }


def build_index_text(entries: List[Dict[str, Any]]) -> str:
    """Render the index JSON with one file row per line.

    Args:
        entries: Rows from index_entry(), in path order.

    Returns:
        Index text with sorted keys, LF line endings and a trailing newline.
    """
    rows = [json.dumps(entry, ensure_ascii=False, sort_keys=True, separators=(",", ":")) for entry in entries]
    head = '{"files":['
    tail = '],"generator":%s}' % json.dumps(GENERATOR)
    if not rows:
        return head + tail + "\n"
    return head + "\n" + ",\n".join(rows) + "\n" + tail + "\n"


def read_index() -> Optional[str]:
    """Read the current index text.

    Returns:
        The index text, or None when the index does not exist yet.
    """
    if not os.path.isfile(INDEX_PATH):
        return None
    return read_text(INDEX_PATH)


def read_year_changes() -> Optional[str]:
    """Read the current year change overview text.

    Returns:
        The overview text, or None when the file does not exist yet.
    """
    path = os.path.join(REFERENCES_ROOT, YEAR_CHANGES_NAME)
    if not os.path.isfile(path):
        return None
    return read_text(path)


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
    spans: List[Tuple[int, str, int, int]], heading: str
) -> Optional[List[Tuple[int, str, int, int]]]:
    """Return the line spans of the first table under a heading.

    The table runs from its header line to its last row line. The next
    heading, a blank line or any other line ends the search, so a later table
    in the same section is not picked up.

    Args:
        spans: Result of line_spans().
        heading: Keyword that names the heading that owns the table.

    Returns:
        The spans of the header line, the separator line and the row lines, in
        file order, or None when the file has no such heading or no table
        under it.
    """
    start = heading_index(spans, heading)
    if start is None:
        return None
    table: List[Tuple[int, str, int, int]] = []
    for span in spans[start + 1:]:
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
    table = table_spans(line_spans(file["text"]), KEY_FIGURES_HEADING)
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

    The flat shape keeps the topic as a file directly in the year folder. The
    nested shape keeps the topic as a folder that holds its four files, and
    the figures file carries the KEY FIGURES table. Both shapes are searched
    at any depth below the references root. The flat file wins when the tree
    holds both.

    Args:
        files: File records keyed by relative path.
        year: Four digit year folder.
        name: Canonical topic file name, for example btw.md.

    Returns:
        The path of the carrier file relative to the references root, or None
        when the year folder holds no topic with that name.
    """
    topic = name[: -len(MARKDOWN_SUFFIX)] if name.endswith(MARKDOWN_SUFFIX) else name
    flat = None
    nested = None
    for path in sorted(files):
        parts = path.split("/")
        if year not in parts[:-1]:
            continue
        index = parts.index(year)
        after = parts[index + 1:]
        if after == [name] and flat is None:
            flat = path
        elif after == [topic, "figures.md"] and nested is None:
            nested = path
        if flat is not None and nested is not None:
            break
    return flat if flat is not None else nested


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
    guide = files.get(TOPIC_ORDER_FILE)
    if guide is None:
        fail("missing %s, the topic order comes from it" % TOPIC_ORDER_FILE)
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
        key=lambda path: (year_of(path) or "", path),
    )
    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for readme in readmes:
        year = year_of(readme)
        if year is None:
            continue
        labels: Dict[str, str] = {}
        records: List[Dict[str, Any]] = []
        for name in topics:
            path = year_topic_path(files, year, name)
            if path is None:
                fail("missing %s, every year folder holds each topic file" % ("%s/%s" % (year, name)))
            if not is_year_topic(path):
                continue
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
            flat = os.path.basename(path) == name
            records.append(
                {
                    "name": name if flat else name[: -len(MARKDOWN_SUFFIX)],
                    "link": name
                    if flat
                    else os.path.relpath(path, os.path.dirname(readme)).replace(os.sep, "/"),
                    "path": path,
                    "description": values.get("description", ""),
                    "nav_label": label,
                    "figures": key_figures(file),
                }
            )
        grouped[readme] = records
    return grouped


def readme_table_anchor(heading: str) -> BlockAnchor:
    """Build the anchor of one year README table block.

    Args:
        heading: Keyword that names the heading that owns the table.

    Returns:
        An anchor that frames the table of a year README: the offset of its
        header line start and the offset of its last row end. A file whose
        table is missing gets the offset after the heading, so --init can
        still plant a pair, and a file that is no year README gets None.
    """

    def anchor(file: Dict[str, Any]) -> Optional[Union[int, Tuple[int, int]]]:
        if not YEAR_README_RE.match(file["path"]):
            return None
        spans = line_spans(file["text"])
        table = table_spans(spans, heading)
        if table is not None:
            return table[0][2], table[-1][3]
        start = heading_index(spans, heading)
        if start is None:
            return None
        return spans[start][3]

    return anchor


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
    return "| [%s](%s) | %s | %d | %d | %d |" % (
        record["name"],
        record["link"],
        record["description"],
        len(rows),
        unverified,
        not_enacted,
    )


@register_block("topic-files", anchor=readme_table_anchor(TOPIC_FILES_HEADING))
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
        rows = [topic_files_row(record) for record in grouped[readme]]
        bodies[readme] = table_text(TOPIC_FILES_HEADER, rows)
    return bodies


@register_block("headline-figures", anchor=readme_table_anchor(HEADLINE_FIGURES_HEADING))
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
        for record in grouped[readme]:
            value_column, figures = headline_figures(record)
            if not value_header:
                value_header = value_column
            for figure in figures:
                rows.append(
                    "| %s | %s | %s | %s | %s |"
                    % (
                        record["nav_label"],
                        figure["item"],
                        figure["value"],
                        figure["status"],
                        figure["check"],
                    )
                )
        bodies[readme] = table_text(
            "| Topic | Item | %s | Status | Check |" % value_header, rows
        )
    return bodies


# ───────────────────────────────────────────────────────────────
# 9. CHANGE NOTES
# ───────────────────────────────────────────────────────────────

def section_lines(
    text: str, level: int = 2, number: Optional[int] = None, keyword: str = ""
) -> List[str]:
    """Return the lines of the first heading section that matches.

    The section starts on its heading line and ends on the line before the
    next heading of the same level or a higher level, so the blank and
    separator lines around it stay inside it. A heading inside frontmatter or
    inside a code block is no heading.

    Args:
        text: File text.
        level: Heading level to match.
        number: Heading number to match, or None to match any number.
        keyword: Text that the heading must hold, or an empty string.

    Returns:
        The section lines without their line endings, empty when no heading
        matches.
    """
    spans = line_spans(text)
    headings = markdown_headings(text)
    for position, heading in enumerate(headings):
        if heading["level"] != level:
            continue
        if number is not None and heading_parts(heading["text"])[0] != number:
            continue
        if keyword and keyword not in heading["text"]:
            continue
        stop = len(spans)
        for following in headings[position + 1:]:
            if following["level"] <= level:
                stop = following["line"] - 1
                break
        return [span[1] for span in spans[heading["line"] - 1:stop]]
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
    return bullet_lines(section_lines(text, 2, number=CHANGE_SECTION_NUMBER))


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


def changes_row(name: str, bullets: List[str]) -> str:
    """Render one change row of a year note.

    Args:
        name: Topic file name.
        bullets: Section 5 bullets of the topic file.

    Returns:
        The row line, without a line ending. The first cell links to the
        section 5 anchor of the topic file.
    """
    snippet = change_snippet(bullets[0]) if bullets else ""
    return "| [%s](%s#%s) | %d | %s |" % (name, name, CHANGE_FRAGMENT, len(bullets), snippet)


def changes_anchor(file: Dict[str, Any]) -> Optional[int]:
    """Return where --init plants the empty change block pair.

    Args:
        file: File record from load_files().

    Returns:
        The offset just after the "All changes by topic" heading line, or None
        for every file but a year change note that holds that heading.
    """
    if CHANGE_NOTE_RE.match(file["path"]) is None:
        return None
    spans = line_spans(file["text"])
    index = heading_index(spans, CHANGES_BY_TOPIC_HEADING)
    if index is None:
        return None
    return spans[index][3]


@register_block(CHANGES_BLOCK_ID, anchor=changes_anchor)
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
        rows: List[str] = []
        for name in topics:
            topic_path = "%s/%s" % (year, name)
            if not is_year_topic(topic_path):
                continue
            topic = by_path.get(topic_path)
            if topic is None:
                fail("missing %s, every year folder holds each topic file" % topic_path)
            rows.append(changes_row(name, topic_change_bullets(topic["text"])))
        bodies[path] = table_text(CHANGES_TABLE_HEADER, rows, CHANGES_TABLE_SEPARATOR)
    return bodies


def authored_bullets(text: str) -> List[str]:
    """Read the authored bullets of a year change note.

    Args:
        text: File text of a year change note.

    Returns:
        The bullet texts of the "Unique to <year>" section, in file order.
    """
    return bullet_lines(section_lines(text, 2, keyword=CHANGES_UNIQUE_PREFIX))


def last_link_target(text: str) -> str:
    """Return the target of the last markdown link on a line.

    Args:
        text: One bullet line.

    Returns:
        The target, empty when the line holds no link.
    """
    targets = LINK_TARGET_RE.findall(text)
    return targets[-1] if targets else ""


def overview_bullet(year: str, bullet: str) -> str:
    """Return one authored bullet with its topic link aimed at the year folder.

    A bullet in a year note links to its topic file as a sibling. The overview
    sits at the references root, so the same link needs the year folder in
    front. Every other part of the bullet stays as it is.

    Args:
        year: Year folder of the note.
        bullet: Authored bullet of the note.

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
    resolved = os.path.normpath(os.path.join(year, path)).replace(os.sep, "/")
    return bullet[:match.start()] + "](%s#%s)" % (resolved, fragment) + bullet[match.end():]


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

    One H2 per year, newest first, with a path link to the year note and the
    authored bullets of that note. The file is generated whole, so it carries
    its own frontmatter and H1.

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
    ]
    for year in year_note_years(files):
        note = by_path["%s/%s" % (year, CHANGE_NOTE_NAME)]
        bullets = authored_bullets(note["text"])
        lines.append("## %s" % year)
        lines.append("")
        lines.append("Path: [%s/%s](%s/%s)" % (year, CHANGE_NOTE_NAME, year, CHANGE_NOTE_NAME))
        lines.append("")
        for bullet in bullets:
            lines.append("- %s" % overview_bullet(year, bullet))
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
                resolved = os.path.normpath(os.path.join(year, path_part)).replace(os.sep, "/")
            topic = by_path.get(resolved) if resolved.startswith(year + "/") else None
            if (
                not target
                or separator != "#"
                or fragment != CHANGE_FRAGMENT
                or topic is None
                or '<a id="%s"></a>' % CHANGE_FRAGMENT not in topic["text"]
            ):
                problems.append(
                    "changes %s bullet %d link %s does not resolve"
                    % (path, position, target or "none")
                )
                continue
            section = "\n".join(section_lines(topic["text"], 2, number=CHANGE_SECTION_NUMBER))
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

def guide_file(files: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Return the record of the reference guide, the file with section 3.

    Args:
        files: Result of load_files().

    Returns:
        The file record of the guide.

    Raises:
        SystemExit: If the guide is not in the scan.
    """
    for file in files:
        if file["path"] == TOPIC_ORDER_FILE:
            return file
    fail("missing %s, section 3 lives in it" % TOPIC_ORDER_FILE)


def section_three_specs(guide: Dict[str, Any]) -> Dict[str, Any]:
    """Map the subsections of section 3 and the year files they name.

    A subsection names its year files on a line that starts with the year
    files marker. The block of a subsection sits right after that line, so the
    end offset of the line is its anchor.

    Args:
        guide: File record of the reference guide.

    Returns:
        The offset span of section 3 and one record per subsection, with the
        block id, the heading title, the named file names and the anchor
        offset.

    Raises:
        SystemExit: If section 3 is missing, a subsection holds no year files
            line, a year files line names no file, or two subsections share a
            block id.
    """
    spans = line_spans(guide["text"])
    headings: List[Dict[str, Any]] = []
    in_code = False
    frontmatter_stop = frontmatter_end(spans)
    for index, (_, content, start, _) in enumerate(spans):
        if index < frontmatter_stop:
            continue
        stripped = content.strip()
        if stripped.startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = HEADING_RE.match(content)
        if not match:
            continue
        level = len(match.group(1))
        if level in (2, 3):
            headings.append({"index": index, "level": level, "text": match.group(2).strip(), "start": start})
    section: Dict[str, Any] = {}
    for position, heading in enumerate(headings):
        if heading["level"] != 2:
            continue
        number, _ = heading_parts(heading["text"])
        if number != SECTION_THREE_NUMBER:
            continue
        after = headings[position + 1:]
        stop = next((index for index, item in enumerate(after) if item["level"] == 2), len(after))
        section = {
            "start": heading["start"],
            "end": after[stop]["start"] if stop < len(after) else len(guide["text"]),
            "headings": after[:stop],
        }
        break
    if not section:
        fail("no section %d heading in %s" % (SECTION_THREE_NUMBER, guide["path"]))
    section_stop = next((index for index, span in enumerate(spans) if span[2] >= section["end"]), len(spans))
    subsections = [item for item in section["headings"] if item["level"] == 3]
    specs: List[Dict[str, Any]] = []
    seen: Set[str] = set()
    for position, heading in enumerate(subsections):
        match = SECTION_THREE_HEADING_RE.match(heading["text"])
        if not match:
            continue
        last = subsections[position + 1]["index"] if position + 1 < len(subsections) else section_stop
        line = next(
            (span for span in spans[heading["index"] + 1:last] if span[1].startswith(YEAR_FILES_MARKER)), None
        )
        if line is None:
            fail("no %s line in %s of %s" % (YEAR_FILES_MARKER, heading["text"], guide["path"]))
        names = YEAR_FILES_NAME_RE.findall(line[1])
        if not names:
            fail("no year file name on line %d of %s" % (line[0], guide["path"]))
        block_id = SECTION_BLOCK_PREFIX + slugify(match.group(1))
        if block_id in seen:
            fail("duplicate block id %s in %s" % (block_id, guide["path"]))
        seen.add(block_id)
        specs.append({"id": block_id, "title": match.group(1), "files": names, "anchor": line[3]})
    if not specs:
        fail("no subsection with a %s line in %s" % (YEAR_FILES_MARKER, guide["path"]))
    return {"start": section["start"], "end": section["end"], "subsections": specs}


def section_three_row(year: str, path: str, figure: Dict[str, str]) -> str:
    """Render one value row of a section 3 block.

    Args:
        year: Year folder of the owning file.
        path: Path of the owning file relative to the references root.
        figure: Headline figure from headline_figures().

    Returns:
        The row line. The owner cell names the year file by its path from the
        repository root and links to the file itself.
    """
    return "| %s | %s | %s | %s | %s | [%s](%s) |" % (
        year,
        figure["item"],
        figure["value"],
        figure["status"],
        figure["check"],
        OWNER_PREFIX + path,
        path,
    )


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
        The block body keyed by the guide path, empty when no named file is in
        the tree.
    """
    years = sorted({year for year in (year_of(path) for path in by_path) if year is not None})
    rows: List[str] = []
    for name in spec["files"]:
        for year in years:
            path = year_topic_path(by_path, year, name)
            if path is None or not is_year_topic(path):
                continue
            file = by_path.get(path)
            if file is None:
                continue
            _, figures = headline_figures({"path": path, "figures": key_figures(file)})
            for figure in figures:
                rows.append(section_three_row(year, path, figure))
    if not rows:
        return {}
    table = table_text(SECTION_THREE_HEADER, rows, SECTION_THREE_SEPARATOR)
    return {TOPIC_ORDER_FILE: SECTION_THREE_SENTENCE + "\n\n" + table}


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


def section_three_anchor(spec: Dict[str, Any]) -> BlockAnchor:
    """Build the anchor of one subsection block.

    Args:
        spec: Subsection record from section_three_specs().

    Returns:
        An anchor that returns the offset just after the year files line of
        the subsection, and None for every file but the guide.
    """

    def anchor(file: Dict[str, Any]) -> Optional[int]:
        if file["path"] != TOPIC_ORDER_FILE:
            return None
        return spec["anchor"]

    return anchor


def register_section_three_blocks(section: Dict[str, Any]) -> None:
    """Register one generated block per subsection of section 3.

    Args:
        section: Result of section_three_specs().
    """
    for spec in section["subsections"]:
        register_builder(spec["id"], section_three_builder(spec), section_three_anchor(spec))


# ───────────────────────────────────────────────────────────────
# 11. NAVIGATION BLOCKS
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


def nav_h1_offset(text: str) -> Optional[int]:
    """Return the offset just after the first H1 line.

    Args:
        text: File text.

    Returns:
        The offset, or None when the file has no H1 line.
    """
    spans = line_spans(text)
    for _, content, _, end in spans[frontmatter_end(spans):]:
        match = HEADING_RE.match(content)
        if match and len(match.group(1)) == 1:
            return end
    return None


def block_of(file: Dict[str, Any], block_id: str) -> Optional[Dict[str, Any]]:
    """Return the parsed fence block of one id in a file record.

    Args:
        file: File record from load_files().
        block_id: Fence id of the block.

    Returns:
        The block record, or None when the file holds no such pair.
    """
    return next((item for item in file["blocks"] if item["id"] == block_id), None)


def find_block_body(text: str, block_id: str) -> Optional[Tuple[int, int]]:
    """Return the body offsets of one fence pair inside a text.

    Args:
        text: File text.
        block_id: Fence id of the block.

    Returns:
        The start and end offset of the bytes between the markers, or None
        when the text holds no pair with that id.
    """
    body_start: Optional[int] = None
    for _, content, start, end in line_spans(text):
        if body_start is None:
            match = FENCE_START_RE.match(content)
            if match and match.group(1) == block_id:
                body_start = end
            continue
        match = FENCE_END_RE.match(content)
        if match and match.group(1) == block_id:
            return body_start, start
    return None


def nav_end_offset(text: str) -> Optional[int]:
    """Return the offset just after the nav end marker line.

    Args:
        text: File text.

    Returns:
        The offset, or None when the text holds no nav end marker line.
    """
    for _, content, _, end in line_spans(text):
        match = FENCE_END_RE.match(content)
        if match and match.group(1) == NAV_BLOCK_ID:
            return end
    return None


def nav_target(file: Dict[str, Any]) -> bool:
    """Tell whether one file needs a read plan.

    Args:
        file: File record from load_files().

    Returns:
        True for a markdown file over the byte limit that has an H1 line.
    """
    if not file["path"].endswith(MARKDOWN_SUFFIX):
        return False
    if len(file["text"].encode("utf-8")) <= NAV_LIMIT:
        return False
    return nav_h1_offset(file["text"]) is not None


def nav_anchor(file: Dict[str, Any]) -> Optional[int]:
    """Return where --init plants the empty read plan pair.

    Args:
        file: File record from load_files().

    Returns:
        The offset just after the H1 line of a file over the byte limit, or
        None for any other file.
    """
    if not nav_target(file):
        return None
    return nav_h1_offset(file["text"])


def nav_parts(text: str, first_limit: int = NAV_LIMIT) -> List[Tuple[int, int, int, int, bool]]:
    """Split one file into the parts of its read plan.

    Part boundaries sit on H2 and H3 lines, so a read stops at a heading
    instead of inside a section. A part takes as many whole sections as fit
    under the byte limit. A single section over the limit has no heading
    inside it and becomes one oversized part.

    Args:
        text: File text with its read plan in place.
        first_limit: Byte limit of the first part. The first part holds the
            plan itself, so the caller lowers this limit while it reserves
            room for a plan that outgrows the current one.

    Returns:
        One record per part with the first line number, the last line
        number, the start offset, the end offset and the oversized flag.
    """
    spans = line_spans(text)
    boundaries = [1]
    for heading in markdown_headings(text):
        if heading["level"] in NAV_HEADING_LEVELS and heading["line"] > 1:
            boundaries.append(heading["line"])
    segments = []
    for index, first in enumerate(boundaries):
        last = boundaries[index + 1] - 1 if index + 1 < len(boundaries) else len(spans)
        segments.append((first, last, spans[first - 1][2], spans[last - 1][3]))
    parts: List[Tuple[int, int, int, int, bool]] = []
    current: Optional[List[int]] = None
    for first, last, start, end in segments:
        limit = first_limit if not parts else NAV_LIMIT
        if current is None:
            current = [first, last, start, end]
        elif slice_bytes(text, current[2], end) <= limit:
            current[1] = last
            current[3] = end
            continue
        else:
            parts.append((current[0], current[1], current[2], current[3], False))
            current = [first, last, start, end]
        if slice_bytes(text, current[2], current[3]) > NAV_LIMIT:
            parts.append((current[0], current[1], current[2], current[3], True))
            current = None
    if current is not None:
        parts.append((current[0], current[1], current[2], current[3], False))
    return parts


def nav_plan(text: str, first_limit: int = NAV_LIMIT) -> str:
    """Render the read plan of one file.

    Args:
        text: File text with its read plan in place.
        first_limit: Byte limit of the first part, passed to nav_parts().

    Returns:
        The plan text, one header line and one line per part.
    """
    parts = nav_parts(text, first_limit)
    headings = markdown_headings(text)
    lines = []
    for number, (first, last, start, end, oversized) in enumerate(parts, 1):
        heading = "none"
        for item in headings:
            if first <= item["line"] <= last:
                heading = "#" * item["level"] + " " + item["text"]
                break
        line = 'Part %d: lines %d-%d, %d bytes, first heading "%s"' % (
            number,
            first,
            last,
            slice_bytes(text, start, end),
            heading,
        )
        if oversized:
            line += ", oversized"
        lines.append(line)
    if len(parts) > 1:
        head = "Read plan: %d parts. Next read offset: line %d." % (len(parts), parts[1][0])
    else:
        head = "Read plan: 1 part."
    return head + "\n" + "\n".join(lines) + "\n"


def nav_final_text(file: Dict[str, Any], block: Optional[Dict[str, Any]], body: str) -> str:
    """Return one file text with a read plan body in place.

    Args:
        file: File record from load_files().
        block: Existing read plan block of the file, or None.
        body: Plan text that sits between the two markers.

    Returns:
        The expected file text.

    Raises:
        SystemExit: If the file has no H1 line to anchor the pair on.
    """
    if block is not None:
        return file["text"][:block["body_start"]] + body + file["text"][block["body_end"]:]
    offset = nav_h1_offset(file["text"])
    if offset is None:
        fail("no H1 line in %s" % file["path"])
    insertion = (
        "\n"
        + fence_line(NAV_BLOCK_ID, "start")
        + "\n"
        + body
        + fence_line(NAV_BLOCK_ID, "end")
        + "\n\n"
    )
    return file["text"][:offset] + insertion + file["text"][offset:]


def nav_source_text(file: Dict[str, Any], bodies: Dict[str, Dict[str, str]]) -> str:
    """Return one file text with every block body but the read plan applied.

    A read plan is measured on the file as a write would leave it, so a block
    that shares the file is spliced in first. The plan itself is measured
    around the result, which is why it stays out here.

    Args:
        file: File record from load_files().
        bodies: Bodies of every other block, keyed by block id and then by
            relative path.

    Returns:
        The expected file text without a read plan body.
    """
    text = file["text"]
    replacements = []
    for block in file["blocks"]:
        if block["id"] == NAV_BLOCK_ID:
            continue
        produced = bodies.get(block["id"], {}).get(file["path"])
        if produced is None:
            continue
        replacements.append((block["body_start"], block["body_end"], body_text(produced)))
    # WHY: the latest replacement goes first, so every earlier offset stays valid.
    for start, end, body in sorted(replacements, reverse=True):
        text = text[:start] + body + text[end:]
    return text


def toc_entries(text: str) -> List[Dict[str, Any]]:
    """List the guide sections and subsections with their line ranges.

    A range starts on its heading line and ends on the line before the next
    heading of the same level or higher, so a range covers every line of its
    section.

    Args:
        text: File text.

    Returns:
        One record per H2 heading and per H3 heading whose text starts with
        the section number, in file order, with the heading text, the first
        line and the last line.
    """
    headings = markdown_headings(text)
    total = len(line_spans(text))
    entries: List[Dict[str, Any]] = []
    for index, heading in enumerate(headings):
        if heading["level"] != 2 and not (
            heading["level"] == 3 and heading["text"].startswith(TOC_SECTION_PREFIX)
        ):
            continue
        last = total
        for following in headings[index + 1:]:
            if following["level"] <= heading["level"]:
                last = following["line"] - 1
                break
        entries.append({"text": heading["text"], "first": heading["line"], "last": last})
    return entries


def toc_plan(text: str) -> str:
    """Render the section list of the reference guide.

    Args:
        text: File text with the read plan and the list in place.

    Returns:
        The list text, one header line and one line per entry.
    """
    lines = [TOC_SECTIONS_HEADING]
    for entry in toc_entries(text):
        lines.append(
            "%s%s: lines %d-%d" % (TOC_ENTRY_PREFIX, entry["text"], entry["first"], entry["last"])
        )
    return "".join(line + "\n" for line in lines)


def toc_anchor(file: Dict[str, Any]) -> Optional[int]:
    """Return where --init plants the empty section list pair.

    The pair sits right after the read plan pair, or right after the H1 when
    the file holds no read plan pair. Only a guide over the byte limit gets
    one, because a smaller file would not fit the block budget.

    Args:
        file: File record from load_files().

    Returns:
        The offset, or None for every file but a large reference guide.
    """
    if file["path"] != TOPIC_ORDER_FILE or not nav_target(file):
        return None
    offset = nav_end_offset(file["text"])
    if offset is None:
        offset = nav_h1_offset(file["text"])
    return offset


def toc_final_text(file: Dict[str, Any], body: str) -> str:
    """Return one guide text with a section list body in place.

    Args:
        file: File record whose text already holds the read plan.
        body: List text that sits between the two markers.

    Returns:
        The expected file text, unchanged when the text holds neither a list
        pair nor a line to anchor one on.
    """
    found = find_block_body(file["text"], TOC_BLOCK_ID)
    if found is not None:
        return file["text"][:found[0]] + body + file["text"][found[1]:]
    offset = nav_end_offset(file["text"])
    if offset is None:
        offset = nav_h1_offset(file["text"])
    if offset is None:
        return file["text"]
    insertion = (
        "\n"
        + fence_line(TOC_BLOCK_ID, "start")
        + "\n"
        + body
        + fence_line(TOC_BLOCK_ID, "end")
        + "\n\n"
    )
    return file["text"][:offset] + insertion + file["text"][offset:]


def navigation_text(
    file: Dict[str, Any],
    others: Dict[str, Dict[str, str]],
    nav_body: str,
    toc_body: str,
) -> str:
    """Return one guide text with the read plan and the section list in place.

    Every other block body of the file is applied first, so the line ranges
    and the part sizes are measured on the file a write would leave.

    Args:
        file: File record from load_files().
        others: Bodies of every other block, keyed by block id and then by
            path.
        nav_body: Read plan text that sits between the nav markers.
        toc_body: List text that sits between the list markers.

    Returns:
        The expected file text.
    """
    source = {"path": file["path"], "text": nav_source_text(file, others)}
    nav_pair = block_of(file, NAV_BLOCK_ID)
    if nav_pair is None and not nav_target(file):
        text = source["text"]
    else:
        text = nav_final_text(source, nav_pair, nav_body)
    return toc_final_text({"path": file["path"], "text": text}, toc_body)


def navigation_pair(file: Dict[str, Any], others: Dict[str, Dict[str, str]]) -> Tuple[str, str]:
    """Return the read plan and the section list of the guide, converged.

    The list sits right after the read plan, so a plan of another length
    moves every line range in the list, and the list bytes move the part
    sizes of the plan. Both bodies are rebuilt on the file that holds them
    until a round leaves both unchanged, which is the same reserve rule that
    the read plan uses alone.

    Args:
        file: File record of the reference guide.
        others: Bodies of every other block, keyed by block id and then by
            path.

    Returns:
        The read plan text and the section list text.

    Raises:
        SystemExit: If the two bodies do not settle after the round limit.
    """
    nav_pair = block_of(file, NAV_BLOCK_ID)
    nav_body = nav_pair["body"] if nav_pair is not None else ""
    toc_pair = block_of(file, TOC_BLOCK_ID)
    toc_body = toc_pair["body"] if toc_pair is not None else ""
    reserve = len(nav_body.encode("utf-8"))
    for _ in range(NAV_MAX_ROUNDS):
        text = navigation_text(file, others, nav_body, toc_body)
        plan = nav_body
        if nav_target(file):
            # WHY: the plan counts toward the first part. The limit lowers by
            # the longest plan seen so far and then adds the current body
            # back, so the part content around the plan stays under the cap
            # once the new plan is in place. The reserve only grows, so the
            # first boundary can only move back and the plan settles.
            plan = nav_plan(text, NAV_LIMIT - reserve + len(nav_body.encode("utf-8")))
        listing = toc_plan(text)
        if plan == nav_body and listing == toc_body:
            return plan, listing
        nav_body = plan
        toc_body = listing
        reserve = max(reserve, len(nav_body.encode("utf-8")))
    fail("read plan and section list in %s do not settle" % file["path"])


def other_block_bodies(files: List[Dict[str, Any]]) -> Dict[str, Dict[str, str]]:
    """Run every block builder but the nav and the section list.

    Args:
        files: Result of load_files().

    Returns:
        Bodies keyed by block id and then by relative path.
    """
    blocks: Dict[str, Dict[str, str]] = {}
    for block_id in sorted(BLOCK_BUILDERS):
        if block_id in NAVIGATION_BLOCK_IDS:
            continue
        for path, body in BLOCK_BUILDERS[block_id](files).items():
            blocks.setdefault(block_id, {})[path] = body
    return blocks


@register_block(NAV_BLOCK_ID, anchor=nav_anchor)
def nav_block(files: List[Dict[str, Any]]) -> Dict[str, str]:
    """Build the read plan body of every file over the byte limit.

    The plan states its own size and sits in the first part, so the first
    part is planned against the byte limit minus the longest plan seen so
    far. That reserve keeps the first part under the limit while the plan
    grows. The plan is rebuilt on the file that holds it until two rounds
    agree, which makes every part size and line number exact on the final
    file. Every other block body of the same file is spliced in before the
    parts are measured, so a block written in the same pass cannot leave the
    plan stale. A file that has no pair yet is measured with an empty pair in
    place, so the body is ready for the run after --init. The guide holds the
    section list too, so its two bodies converge together.

    Args:
        files: Result of load_files().

    Returns:
        The plan text keyed by the file path.

    Raises:
        SystemExit: If a plan does not settle after the round limit.
    """
    blocks = other_block_bodies(files)
    bodies: Dict[str, str] = {}
    for file in files:
        if not nav_target(file):
            continue
        if file["path"] == TOPIC_ORDER_FILE:
            bodies[file["path"]] = navigation_pair(file, blocks)[0]
            continue
        block = block_of(file, NAV_BLOCK_ID)
        source = {"path": file["path"], "text": nav_source_text(file, blocks)}
        body = block["body"] if block is not None else ""
        reserve = len(body.encode("utf-8"))
        for _ in range(NAV_MAX_ROUNDS):
            text = nav_final_text(source, block, body)
            # WHY: the plan counts toward the first part. The limit lowers by
            # the longest plan seen so far and then adds the current body
            # back, so the part content around the plan stays under the cap
            # once the new plan is in place. The reserve only grows, so the
            # first boundary can only move back and the plan settles.
            first_limit = NAV_LIMIT - reserve + len(body.encode("utf-8"))
            plan = nav_plan(text, first_limit)
            if plan == body:
                break
            body = plan
            reserve = max(reserve, len(body.encode("utf-8")))
        else:
            fail("read plan in %s does not settle" % file["path"])
        bodies[file["path"]] = body
    return bodies


@register_block(TOC_BLOCK_ID, anchor=toc_anchor)
def toc_block(files: List[Dict[str, Any]]) -> Dict[str, str]:
    """Build the section list body of the reference guide.

    Args:
        files: Result of load_files().

    Returns:
        The list text keyed by the guide path, empty for every other file.
    """
    blocks = other_block_bodies(files)
    bodies: Dict[str, str] = {}
    for file in files:
        if file["path"] != TOPIC_ORDER_FILE or not nav_target(file):
            continue
        bodies[file["path"]] = navigation_pair(file, blocks)[1]
    return bodies


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
        by block id and then by path, which is what --init has to add.
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
    rendered[YEAR_CHANGES_NAME] = year_changes_text(files)
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
    # WHY: the overview is generated whole, so it gains its index row even when
    # the tree does not hold the file yet.
    if YEAR_CHANGES_NAME not in {file["path"] for file in files}:
        entries.append(index_entry(YEAR_CHANGES_NAME, rendered[YEAR_CHANGES_NAME]))
        entries.sort(key=lambda entry: entry["path"])
    return build_index_text(entries)


# ───────────────────────────────────────────────────────────────
# 13. CHECK AND WRITE
# ───────────────────────────────────────────────────────────────

def budget_problems(files: List[Dict[str, Any]]) -> List[str]:
    """List the nav and section list blocks that exceed their byte budget.

    The budget of one file is the smaller of a fixed byte count and one
    percent of the file size, so a small file allows a shorter block than a
    large one.

    Args:
        files: Result of load_files().

    Returns:
        One line per oversized block, with its path, its block id, its body
        bytes and its budget.
    """
    problems: List[str] = []
    for file in files:
        size = len(file["text"].encode("utf-8"))
        budget = min(BUDGET_BYTE_LIMIT, size * BUDGET_PERCENT // 100)
        for block in file["blocks"]:
            if block["id"] not in NAVIGATION_BLOCK_IDS:
                continue
            body = len(block["body"].encode("utf-8"))
            if body > budget:
                problems.append("budget %s %s %d over %d" % (file["path"], block["id"], body, budget))
    return problems


def check_all(files: List[Dict[str, Any]], bodies: Dict[str, Dict[str, str]], rendered: Dict[str, str]) -> int:
    """Report every block, index or budget that differs from its generated form.

    Args:
        files: Result of load_files().
        bodies: Result of block_bodies().
        rendered: Result of render_files().

    Returns:
        Zero when nothing differs, one otherwise.
    """
    problems = budget_problems(files)
    problems += ["drift %s %s" % pair for pair in missing_fences(files, bodies)]
    for file in files:
        # WHY: the overview is generated whole and reported on its own line, so
        # the block loop leaves it out.
        if file["path"] == YEAR_CHANGES_NAME:
            continue
        reported = False
        for block in file["blocks"]:
            produced = bodies.get(block["id"], {}).get(file["path"])
            if produced is None:
                continue
            if body_text(produced) != block["body"]:
                problems.append("drift %s %s" % (file["path"], block["id"]))
                reported = True
        if not reported and rendered[file["path"]] != file["text"]:
            problems.append("drift %s %s" % (file["path"], FILE_DRIFT_ID))
    problems += change_note_problems(files)
    if read_year_changes() != rendered[YEAR_CHANGES_NAME]:
        problems.append("drift %s" % YEAR_CHANGES_NAME)
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
        print("reference-index: run --init before a write")
        return 1
    written = []
    seen = set()
    for file in files:
        seen.add(file["path"])
        if rendered[file["path"]] != file["text"]:
            write_text(file["absolute"], rendered[file["path"]])
            written.append(file["path"])
    if YEAR_CHANGES_NAME not in seen:
        write_text(os.path.join(REFERENCES_ROOT, YEAR_CHANGES_NAME), rendered[YEAR_CHANGES_NAME])
        written.append(YEAR_CHANGES_NAME)
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


def checked_anchor(block_id: str, offset: int, file: Dict[str, Any]) -> int:
    """Check one anchor offset and return it.

    Args:
        block_id: Fence id of the block.
        offset: Offset the anchor returned.
        file: File record the anchor ran on.

    Returns:
        The offset.

    Raises:
        SystemExit: If the offset sits outside the file or inside a line.
    """
    if offset < 0 or offset > len(file["text"]) or (offset > 0 and file["text"][offset - 1] != "\n"):
        fail("anchor of %s is not at the start of a line in %s" % (block_id, file["path"]))
    return offset


def init_fences(files: List[Dict[str, Any]]) -> int:
    """Insert the fence pair of every anchored block that a file misses.

    A pair that frames bytes already in the file keeps those bytes, so a table
    that is already correct is not moved or rewritten. Every other pair goes
    in empty, with a blank line around it.

    Args:
        files: Result of load_files().

    Returns:
        Zero on success.

    Raises:
        SystemExit: If an anchor sits outside its file or inside a line, or a
            start offset sits after its end offset.
    """
    inserted = 0
    touched = 0
    for file in files:
        if not file["path"].endswith(MARKDOWN_SUFFIX):
            continue
        present = {block["id"] for block in file["blocks"]}
        insertions: List[Tuple[int, int, str]] = []
        for block_id in sorted(BLOCK_ANCHORS):
            if block_id in present:
                continue
            place = BLOCK_ANCHORS[block_id](file)
            if place is None:
                continue
            if isinstance(place, tuple):
                start, end = place
                checked_anchor(block_id, start, file)
                checked_anchor(block_id, end, file)
                if end < start:
                    fail("anchor of %s runs backwards in %s" % (block_id, file["path"]))
                insertions.append((start, len(insertions), fence_line(block_id, "start") + "\n"))
                insertions.append((end, len(insertions), fence_line(block_id, "end") + "\n"))
            else:
                checked_anchor(block_id, place, file)
                insertions.append((place, len(insertions), init_text(block_id)))
            inserted += 1
        if not insertions:
            continue
        text = file["text"]
        # WHY: the latest insertion goes first, so every earlier offset stays valid.
        for offset, _, addition in sorted(insertions, key=lambda item: (item[0], item[1]), reverse=True):
            text = text[:offset] + addition + text[offset:]
        write_text(file["absolute"], text)
        touched += 1
    if inserted:
        print("reference-index: inserted %d fence pairs in %d files" % (inserted, touched))
    else:
        print("reference-index: no fence pair inserted")
    return 0


# ───────────────────────────────────────────────────────────────
# 14. OVERLAP REPORT
# ───────────────────────────────────────────────────────────────

def owner_rows(blocks: List[Dict[str, Any]], block_id: str) -> Set[Tuple[str, str, str]]:
    """Read the owner rows of one generated block of the guide.

    Args:
        blocks: Fence blocks of the guide.
        block_id: Fence id of the block.

    Returns:
        One (path, year, item) triple per six cell row that holds an owner
        link, so a caller can tell whether a value row exists.
    """
    block = next((item for item in blocks if item["id"] == block_id), None)
    rows: Set[Tuple[str, str, str]] = set()
    if block is None:
        return rows
    for line in block["body"].splitlines():
        if not line.startswith("|"):
            continue
        cells = markdown_cells(line)
        if len(cells) != 6:
            continue
        match = OWNER_LINK_RE.search(cells[5])
        if match:
            rows.add((match.group(1), cells[0], cells[1]))
    return rows


def overlap_report(files: List[Dict[str, Any]], guide: Dict[str, Any], section: Dict[str, Any]) -> int:
    """Report the headline values that section 3 restates in its prose.

    A headline value is one of the first two KEY FIGURES rows of one topic
    file in one year folder, so it is one of the rows that the year README
    HEADLINE FIGURES table shows. It counts as restated when its value text
    appears literally on a prose line of section 3, outside every generated
    block. A restated value is owned when the subsection that names its topic
    file holds a generated row for the same year and item. The report writes
    nothing and exits 0 either way.

    Args:
        files: Result of load_files().
        guide: File record of the reference guide.
        section: Result of section_three_specs().

    Returns:
        Zero.
    """
    by_path = {file["path"]: file for file in files}
    fenced: Set[int] = set()
    for block in guide["blocks"]:
        fenced.update(range(block["start_line"], block["end_line"] + 1))
    prose = [
        content
        for number, content, start, _ in line_spans(guide["text"])
        if section["start"] <= start < section["end"] and number not in fenced
    ]
    owner_of: Dict[str, str] = {}
    owned: Dict[str, Set[Tuple[str, str, str]]] = {}
    for spec in section["subsections"]:
        owned[spec["id"]] = owner_rows(guide["blocks"], spec["id"])
        for name in spec["files"]:
            owner_of.setdefault(name, spec["id"])
    years = sorted({year for year in (year_of(path) for path in by_path) if year is not None})
    total = 0
    restated = 0
    unowned = 0
    for name in canonical_topics(by_path):
        for year in years:
            path = year_topic_path(by_path, year, name)
            if path is None or not is_year_topic(path):
                continue
            file = by_path.get(path)
            if file is None:
                continue
            _, figures = headline_figures({"path": path, "figures": key_figures(file)})
            for figure in figures:
                total += 1
                if not figure["value"] or not any(figure["value"] in line for line in prose):
                    continue
                restated += 1
                block_id = owner_of.get(name, "")
                if (path, year, figure["item"]) not in owned.get(block_id, set()):
                    unowned += 1
                    print("overlap unowned %s %s %s" % (year, path, figure["item"]))
    print("overlap: restated %d of %d, unowned %d" % (restated, total, unowned))
    return 0


# ───────────────────────────────────────────────────────────────
# 15. REACHABILITY CHECK
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

    The sources are SKILL.md, the reference index, every README.md and every
    folder index page inside the skill. A caller decides whether a folder
    index page counts.

    Returns:
        File text keyed by path relative to the skill root.
    """
    sources: Dict[str, str] = {}
    for relative in (SKILL_PAGE, "references/" + INDEX_NAME):
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


def unreachable_leaves(leaves: List[str], sources: Dict[str, str]) -> List[str]:
    """Return the leaves that no routed folder and no reachable page reaches.

    A leaf under the routed reference folders is reachable through the
    task-type table. Any other leaf is reachable when a reachable page names
    it or links to it. A folder index page counts as a page only once
    SKILL.md links it, so the catalog and the playbook route nothing while
    SKILL.md leaves their roots out.

    Args:
        leaves: Leaf paths from the manifest.
        sources: Result of reachability_sources().

    Returns:
        The sorted paths of the leaves that stay unreachable.
    """
    active = {path: text for path, text in sources.items() if not is_folder_index(path)}
    skill_text = sources.get(SKILL_PAGE, "")
    for path in sorted(sources):
        if is_folder_index(path) and source_mentions(SKILL_PAGE, skill_text, path):
            active[path] = sources[path]
    pending = {leaf for leaf in leaves if not leaf.startswith(ROUTED_PREFIX)}
    for leaf in sorted(pending):
        if any(source_mentions(path, text, leaf) for path, text in active.items()):
            pending.discard(leaf)
    return sorted(pending)


def reachability_report() -> int:
    """Report the manifest leaves that no route and no link reaches.

    Returns:
        Zero when every leaf is reachable, one otherwise.
    """
    leaves = manifest_leaves()
    gaps = unreachable_leaves(leaves, reachability_sources())
    print("reachability: %d of %d leaves reachable" % (len(leaves) - len(gaps), len(leaves)))
    for leaf in gaps:
        print("unreachable %s" % leaf)
    return 1 if gaps else 0


# ───────────────────────────────────────────────────────────────
# 16. ENTRY POINT
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
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="compute every output and report drift without writing")
    modes.add_argument("--init", action="store_true", help="insert the empty fence pair of every missing block")
    modes.add_argument("--overlap", action="store_true", help="report the headline values that section 3 restates")
    modes.add_argument(
        "--reachability",
        action="store_true",
        help="report the manifest leaves that no route and no link reaches",
    )
    args = parser.parse_args(argv)
    if args.reachability:
        return reachability_report()
    if not os.path.isdir(REFERENCES_ROOT):
        fail("references folder not found: %s" % REFERENCES_ROOT)
    files = load_files()
    guide = guide_file(files)
    section = section_three_specs(guide)
    register_section_three_blocks(section)
    if args.init:
        return init_fences(files)
    if args.overlap:
        return overlap_report(files, guide, section)
    bodies = block_bodies(files)
    rendered = render_files(files, bodies)
    if args.check:
        drift_status = check_all(files, bodies, rendered)
        reachability_status = reachability_report()
        return 1 if drift_status or reachability_status else 0
    return write_all(files, bodies, rendered)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
