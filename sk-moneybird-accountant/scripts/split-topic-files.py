#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: TOPIC FILE SPLITTER
# ───────────────────────────────────────────────────────────────
"""Split every tax-rules topic file into four part files and check the rejoin.

The 96 year topic files at references/tax-rules/{year}/{topic}.md carry the
same eight H2 sections. This script slices each one at its H2 headings into
four part files under references/tax-rules/{year}/{topic}/ and removes the
original with git rm. The slice keeps every knowledge byte. A part body is
the original section bytes with a generated overview section first, its
headings renumbered from 1 in capitals and its relative links rebased, and
every topic-wide anchor stays in place. The manifest records the rejoin of
the four normalized bodies. The body starts on the first H2 line and runs to
the end of the file.

Each part reads as a standalone reference file. figures.md keeps source
sections 1 and 2, which already open with an OVERVIEW. The rules.md,
examples.md and notes.md parts gain a generated `## 1. OVERVIEW` that names
what the part holds and which sibling holds the rest, and every later
numbered H2 is renumbered from 2 in file order. The original anchors stay in
place, so a citation to an anchor such as `3-how-it-works` keeps resolving.

One split also rewrites references/tax-rules/dutch-tax-rules.md. Its H3
subsections 3.1 to 3.10 and its H2 sections 4, 5 and 6 move to
references/tax-rules/general/{slug}.md, where the slug is mechanical: drop
the section number, lower case, every run of non-alphanumerics becomes one
hyphen and the hyphens are trimmed. The entry file keeps the sections around
the moved block and gains a pointer table to the 13 general files. Every
general part gains the same generated overview, a moved H2 section is
renumbered to 2 and a kept H2 section after the moved block is renumbered to
continue the guide sequence. The 13 names are fixed by the privacy gate
allowlist, so a name outside the set stops the run with exit 2.

Every part file is a derived header followed by its body bytes. The header
holds frontmatter, an H1 that names the topic and the part, the rule line
copied verbatim and a pointer block with relative links that names each
sibling by its content. The body starts on the first H2 or H3 heading line
after the frontmatter, which is the line this script and a checker use to find
the bytes that the manifest hashes.
The header leaves the H1 line free for the GENERATED nav and toc fences that
build-reference-index.py inserts after it, so a block write never touches a
body byte.

The run writes references/tax-rules/split-manifest.json with one row per
split file: the source path, the normalized rejoin sha256 and one record per
part with its path, its section numbers, its normalized body sha256 and its
line map. The general split gets one record with the same fields plus the
heading of every part and an entry line map for the lines the entry keeps.
Keys are sorted, the rows are sorted by source and a second --write with no
source change writes no byte. The manifest version is 3: the body hashes
cover a normalized body, and each part also records the sha256 of its derived
header with every GENERATED fence and blank line removed, so a hand edit to
the header fails --check as a body edit does. The general record carries the
same kind of hash for the whole entry file, which keeps its sections around
the moved block and the pointer table.

A part body is not the source bytes verbatim. It opens with the generated
overview where the part needs one, its H2 numbers follow the part sequence
and every relative link is rebased for the part's deeper folder. A link to a
split original is pointed at the part or general file that now holds its
target, and a bare link to a split topic file points at that folder's
figures.md. The guide keeps its entry file, so a bare link to the guide still
resolves.

The manifest records the sha256 of a NORMALIZED body per part and per
rejoined source. The normalization removes the contents of every GENERATED
fence and replaces every link target with its canonical repository path
through the split map. A changed sentence, value, status tag or URL still
changes the hash, while a rebased link and a regenerated fence do not.
--check recomputes the same normalization from the part files.

A pure rename changes link targets and nothing else. The --accept-renames mode
takes a JSON map of old repository paths to new paths and a git revision that
still holds the old files. For every part and for the entry file it reads the
old text from that revision, reads the new text at the mapped path, rewrites
the repository paths in the old normalized body and header through the map and
accepts the part only when both sides match. A link label that resolves to its
own target counts as a path too, because a derived header names each sibling
file in both the label and the target. A part that differs beyond its paths is
refused, nothing is written and the run exits 1.

A reviewed content edit changes the bytes of a part or of the entry file. The
--accept-edits mode takes the same base revision and compares every part with
its text at that revision. A part whose text still matches keeps its stored
hashes byte for byte, so an unchanged part never moves. A part whose text
changed is re-normalized against the current tree, its body and header hashes
are recorded, and the part is printed with the number of changed lines. A row
with a recorded part gets its rejoin hashes recomputed, and the entry hash is
re-recorded when the entry file changed. The manifest is written once, at the
end, so a failed read leaves every byte as it was.

remap_citations() rewrites every path, path:line and path#anchor citation of
a split file in every tracked markdown or JSON file outside specs/ and
outside the moved parts. It points at the part that holds the line or the
heading, keeps the anchor and recomputes the line inside the part. A bare
path points at figures.md. The generated files that their own generators
rewrite are skipped, as are .privacy-gate.json and the manifest itself. A
citation whose line, heading or file cannot be resolved aborts the run with a
non-zero exit before any byte is written.

The manifest also stores the line map: the first and last source line of each
part and the offset that turns a source line number into a part line number.
No mode makes a network call, and no mode reads personal database/,
migration-workspace/, an .env file or .privacy-denylist.

Usage:
    python3 -I sk-moneybird-accountant/scripts/split-topic-files.py --plan
    python3 -I sk-moneybird-accountant/scripts/split-topic-files.py --write
    python3 -I sk-moneybird-accountant/scripts/split-topic-files.py --check
    python3 -I sk-moneybird-accountant/scripts/split-topic-files.py --accept-renames MAP --base REF
    python3 -I sk-moneybird-accountant/scripts/split-topic-files.py --accept-edits --base REF

Options:
    --plan   Print every source file, its parts, the byte sizes and the o200k
             token count per part when the cached encoding is available.
             Writes nothing. This is the default.
    --write  Plan every source, write the part files, remove each original
             with git rm, rewrite the entry file, remap every citation of a
             split source and write the manifest. A citation that cannot be
             mapped leads to exit 1 and no byte is written.
    --check  Recompute every part body and every rejoin from the part files
             alone, compare them with the manifest, refuse a leftover
             original, refuse a folder with fewer than four parts, refuse a
             part over the token line and report the citations that still
             point at a split source. Reads only.
    --accept-renames MAP
             Accept a pure rename and record its new hashes. MAP is a JSON
             object that maps an old repository path to its new path, and a
             key that ends in a slash maps every path under it. Requires
             --base.
    --accept-edits
             Record the new hashes of the parts and of the entry file whose
             text changed since the base revision, keep every unchanged
             part's hashes byte for byte and print each recorded part with
             its changed line count. Requires --base.
    --base REF
             Git revision that still holds the old files. Required with
             --accept-renames and with --accept-edits.

Output:
    --plan prints one "source" line per topic file, one "part" line per part,
    one "general" line per entry file and one "general-part" line per general
    part, each with its bytes and its token count. --write prints one "split"
    line per source, the citation count and the manifest path. --check prints
    one "rejoin ok" line per split source, one problem line per failure, then
    the leftovers, the unmapped citations and the largest part token count.
    --accept-renames prints one "split-accept" line with the renamed and
    unchanged part counts when every part is accepted, or one "refused"
    block per part with the first differing line, and exits 1.
    --accept-edits prints one "split-edit" line per recorded part or entry
    file with its changed line count, then one "split-accept-edits" line with
    the recorded and unchanged part counts.
    Exit 0 when the mode finished, 1 on an unmapped citation, a refused
    rename or a check problem, and 2 on a usage error, a read error, a
    malformed source file, a malformed manifest or a write error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import hashlib
import json
import os
import posixpath
import re
import site
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, NoReturn, Optional, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/split-topic-files.py"

# WHY: the tree resolves from the script location, so a run from another
# folder still writes inside the repository and never leaves it.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SKILL_ROOT = os.path.dirname(SCRIPT_DIR)
REPO_ROOT = os.path.dirname(SKILL_ROOT)
TAX_RULES_ROOT = os.path.join(SKILL_ROOT, "references", "tax-rules")
GENERAL_DIR = os.path.join(TAX_RULES_ROOT, "general")
ENTRY_NAME = "dutch-tax-rules.md"
ENTRY_PATH = os.path.join(TAX_RULES_ROOT, ENTRY_NAME)
MANIFEST_NAME = "split-manifest.json"
MANIFEST_PATH = os.path.join(TAX_RULES_ROOT, MANIFEST_NAME)

# A year folder holds its topic files directly, and the three other markdown
# files of a year are not topics.
YEAR_RE = re.compile(r"^[0-9]{4}$")
NON_TOPIC_NAMES = frozenset(("README.md", "changelog.md", "changes.md"))

# The four parts of one topic, the section numbers each one carries and the
# content name its pointer block shows, so a reader can follow a sibling by
# name instead of a topic-wide section number.
PART_DEFS = (
    {"file": "figures.md", "label": "Figures", "sections": (1, 2), "ranges": "the overview and key figures"},
    {"file": "rules.md", "label": "Rules", "sections": (3,), "ranges": "how it works"},
    {"file": "examples.md", "label": "Examples", "sections": (4,), "ranges": "the worked examples"},
    {"file": "notes.md", "label": "Notes", "sections": (5, 6, 7, 8), "ranges": "changes, records, open points and related resources"},
)

# The generated OVERVIEW paragraph of each year part. It states what the part
# holds and which sibling holds the rest, so a part that starts at section 2
# still tells a reader where the other sections went. The text adds structure
# only and makes no tax claim.
YEAR_OVERVIEW_TEXT = {
    "rules.md": "This part holds the how-it-works rules for the %s topic. "
    "The overview and key figures are in figures.md, the worked examples in examples.md "
    "and the changes, records, open points and related resources in notes.md.",
    "examples.md": "This part holds the worked examples for the %s topic. "
    "The overview and key figures are in figures.md, the how-it-works rules in rules.md "
    "and the changes, records, open points and related resources in notes.md.",
    "notes.md": "This part holds the changes, records, open points and related resources for the %s topic. "
    "The overview and key figures are in figures.md, the how-it-works rules in rules.md "
    "and the worked examples in examples.md.",
}

# The generated OVERVIEW paragraph of one general part. The opening avoids
# the positional markers that check-fragments counts.
GENERAL_OVERVIEW_TEXT = (
    "This part holds the general rules for the %s topic across the tax years. "
    "The other general topics sit in the sibling files under general/ and the year figures sit in the year folders."
)

# WHY: the privacy gate admits exactly these 13 general paths. A slug outside
# the tuple would write a path that the gate rejects, so the run stops with
# exit 2 instead of writing it.
GENERAL_SLUGS = (
    "btw-vat",
    "income-tax-box-1-and-the-zvw-contribution",
    "ondernemersaftrek-and-mkb-winstvrijstelling",
    "investment-deductions-and-depreciation",
    "costs-and-the-car",
    "box-3-savings-and-investments",
    "box-2-and-the-substantial-interest",
    "the-bv-and-vennootschapsbelasting",
    "pension-lijfrente-and-aov",
    "work-relationship-and-procedure",
    "settled-source-conflicts",
    "open-points-and-gaps",
    "record-and-invoice-duties",
)
# A slug comes from a Dutch section heading, but every file name is English,
# so five slugs map to the English name of the file they write
GENERAL_FILE_NAMES = {
    "btw-vat": "vat",
    "income-tax-box-1-and-the-zvw-contribution": "income-tax-box-1-and-the-health-insurance-contribution",
    "ondernemersaftrek-and-mkb-winstvrijstelling": "business-deductions-and-sme-profit-exemption",
    "the-bv-and-vennootschapsbelasting": "the-private-company-and-corporate-tax",
    "pension-lijfrente-and-aov": "pension-annuities-and-disability-insurance",
}
GENERAL_FILES = tuple(GENERAL_FILE_NAMES.get(slug, slug) for slug in GENERAL_SLUGS)
GENERAL_SECTION_NUMBERS = ("3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8", "3.9", "3.10", "4", "5", "6")
GENERAL_ENTRY_ANCHORS = ("4", "5", "6")

# The heading patterns. A topic file is split on its numbered H2 lines, and a
# numbered H3 line only matters inside section 3 of the entry file.
HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.*?)[ \t]*$")
NUMBERED_H2_RE = re.compile(r"^([0-9]+)\.[ \t]+(.*)$")
NUMBERED_H3_RE = re.compile(r"^([0-9]+\.[0-9]+)[ \t]+(.*)$")
# One whole H2 line, so the conform pass can rewrite only its number and its
# case without touching any other byte of the line.
NUMBERED_H2_LINE_RE = re.compile(r"^##[ \t]+([0-9]+)\.[ \t]+(.*?)[ \t]*$")
PLAIN_H2_LINE_RE = re.compile(r"^##[ \t]+(.*?)[ \t]*$")
FRONTMATTER_FIELD_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):[ \t]*(.*)$")
LIST_ITEM_RE = re.compile(r"^[ \t]+-[ \t]+(.*)$")
RULE_PREFIX = "**Rule:**"
CODE_FENCE_PREFIXES = ("```", "~~~")

# The part header fields, in the order the year topic files carry them.
SCALAR_FIELDS = ("title", "description", "nav_label")
RAW_FIELDS = ("importance_tier", "contextType", "version")
NAV_LABEL_LIMIT = 60

# The o200k encoding is a proxy for the executing models, so the token line
# states the encoding it counted. The cache check keeps the run offline.
O200K_NAME = "o200k_base"
O200K_URL = "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken"
CACHE_ENV = "TIKTOKEN_CACHE_DIR"
PART_TOKEN_LIMIT = 15000

# The manifest version names the hash rule: normalized bodies and fence-free headers.
MANIFEST_VERSION = 3

# A generated fence holds machine bytes, so the normalization drops the
# contents between the two marker lines and keeps the marker lines.
GENERATED_START_RE = re.compile(r"^\s*<!-- GENERATED:([a-z0-9][a-z0-9._-]*):start -->\s*$")
GENERATED_END_RE = re.compile(r"^\s*<!-- GENERATED:([a-z0-9][a-z0-9._-]*):end -->\s*$")

# One inline link target, without the wrapping parentheses. A target never
# holds a newline, and a target with a title is left alone.
INLINE_LINK_RE = re.compile(r"\]\(([^)\n]*)\)")

# One whole inline link, so the accept mode can tell whether a link label
# names the same file as the target.
LABEL_LINK_RE = re.compile(r"\[([^\]\n]*)\]\(([^)\n]*)\)")

# One relative inline link that the rebase may rewrite. External URLs, angle
# wrappers and titles are left as they are.
SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.\-]*:")

# A citation token: a markdown path with an optional :line or #anchor
# suffix. The path may be bare or carry any relative prefix, because a year
# README cites vat.md and a JSON file cites references/tax-rules/<year>/btw.md.
# The lookarounds keep a longer path or a word boundary out of the match.
CITATION_RE = re.compile(
    r"(?<![A-Za-z0-9_./-])(?<!\[)"
    r"(?P<path>(?:[A-Za-z0-9._-]+/)*[a-z0-9-]+\.md)"
    r"(?::(?P<line>[0-9]+)|#(?P<anchor>[A-Za-z0-9._-]+))?"
    r"(?![A-Za-z0-9_/-])(?!\])"
)

# WHY: the pattern tells a citation to a tax-rules source from a citation to
# another year file such as changes.md. Only a miss on the first kind is an
# abort.
SPLIT_SOURCE_RE = re.compile(r"(?:^|/)tax-rules/(?:20[0-9]{2}/[a-z0-9-]+\.md|dutch-tax-rules\.md)$")

# The part paths the remap scan leaves to the rebase pass.
YEAR_PART_RE = re.compile(r"(?:^|/)tax-rules/20[0-9]{2}/[a-z0-9-]+/(?:figures|rules|examples|notes)\.md$")
GENERAL_PART_RE = re.compile(r"(?:^|/)tax-rules/general/[a-z0-9-]+\.md$")

# The files their own generators rewrite, plus the gate file and the manifest.
# The remap scan skips them so a regenerated file is never a hand edit.
CITATION_SKIP_FILES = frozenset(
    (
        ".privacy-gate.json",
        "sk-moneybird-accountant/references/index.json",
        "sk-moneybird-accountant/benchmark/token-baseline.json",
        "sk-moneybird-accountant/assets/source-library.json",
        "sk-moneybird-accountant/leaf-manifest.json",
        "sk-moneybird-accountant/references/tax-rules/split-manifest.json",
    )
)
CITATION_SUFFIXES = (".md", ".json")

# The GitHub heading slug rule that check-fragments.py uses, so a citation
# anchor and a heading match on the same text.
SLUG_DROP_RE = re.compile(r"[^\w\s\-]", re.UNICODE)
SLUG_SPACE_RE = re.compile(r"\s")
ANCHOR_ID_RE = re.compile(r'<a\s+id="([^"]+)"')

# The scan roots a citation may resolve against, in order. A path is tried
# relative to the citing file first, then against the repository root, the
# skill root and the references root.
CITATION_BASES = ("", "sk-moneybird-accountant", "sk-moneybird-accountant/references")

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


def repo_rel(path: str) -> str:
    """Render one path relative to the repository root.

    Args:
        path: Absolute path.

    Returns:
        The repository-relative path with forward slashes, so the output and
        the manifest are byte-stable on every host.
    """
    return os.path.relpath(path, REPO_ROOT).replace(os.sep, "/")


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
        fail("cannot read %s: %s" % (repo_rel(path), exc))
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        fail("cannot decode %s as UTF-8: %s" % (repo_rel(path), exc))


def write_text(path: str, text: str) -> None:
    """Write one file through a temporary file and a rename.

    Args:
        path: File to write.
        text: New file text.

    Raises:
        SystemExit: If the file cannot be written.
    """
    data = text.encode("utf-8")
    temporary = None
    try:
        folder = os.path.dirname(path)
        if folder and not os.path.isdir(folder):
            os.makedirs(folder)
        descriptor, temporary = tempfile.mkstemp(prefix=".split-topic-files-", dir=folder)
        os.close(descriptor)
        with open(temporary, "wb") as handle:
            handle.write(data)
        os.replace(temporary, path)
        temporary = None
    except OSError as exc:
        fail("cannot write %s: %s" % (repo_rel(path), exc))
    finally:
        # WHY: a half-written temporary file must not survive a failed rename.
        if temporary is not None and os.path.exists(temporary):
            os.remove(temporary)


def sha256_text(text: str) -> str:
    """Return the sha256 hex of one text in UTF-8 bytes.

    Args:
        text: Text to hash.

    Returns:
        The 64 character hex digest.
    """
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


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
        if newline == -1:
            spans.append((number + 1, text[start:], start, length))
            break
        spans.append((number + 1, text[start:newline], start, newline + 1))
        start = newline + 1
        number += 1
    return spans


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


def scan_headings(text: str) -> List[Dict[str, Any]]:
    """Map every heading outside the frontmatter and the code blocks.

    Args:
        text: File text.

    Returns:
        One record per heading in file order, with the line number, the level,
        the heading text and the line start offset.
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


def body_start(text: str) -> Optional[int]:
    """Return the offset where the body of one part file starts.

    The body starts on the first H2 or H3 heading line after the frontmatter,
    because the derived header holds no heading of those levels. Every byte
    from that line to the end of the file is the body: the overview section
    and the original section bytes under their conformed headings.

    Args:
        text: Part file text.

    Returns:
        The start offset, or None when the file holds no body heading.
    """
    for heading in scan_headings(text):
        if heading["level"] in (2, 3):
            return heading["start"]
    return None


def part_body(text: str) -> Optional[str]:
    """Return the body bytes of one part file.

    Args:
        text: Part file text.

    Returns:
        The body, or None when the file holds no body heading.
    """
    start = body_start(text)
    if start is None:
        return None
    return text[start:]


def unquote(value: str) -> str:
    """Drop the quotes of one double-quoted frontmatter scalar.

    Args:
        value: Raw value with its quotes.

    Returns:
        The value text with its escape characters resolved.
    """
    inner = value[1:-1]
    out: List[str] = []
    index = 0
    while index < len(inner):
        if inner[index] == "\\" and index + 1 < len(inner):
            out.append(inner[index + 1])
            index += 2
            continue
        out.append(inner[index])
        index += 1
    return "".join(out)


def yaml_quote(value: str) -> str:
    """Render one double-quoted frontmatter scalar.

    Args:
        value: Value text.

    Returns:
        The quoted scalar with its backslash and quote escapes.
    """
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"'


def frontmatter_fields(text: str) -> Optional[Dict[str, Any]]:
    """Read the fields of a leading frontmatter block.

    Args:
        text: File text.

    Returns:
        A record with the scalar values, the raw scalar lines and the
        trigger_phrases list, or None when the block is missing or unclosed.
    """
    spans = line_spans(text)
    end = frontmatter_end(spans)
    if end == 0:
        return None
    scalars: Dict[str, str] = {}
    raw: Dict[str, str] = {}
    phrases: List[str] = []
    current = ""
    for _, content, _, _ in spans[1:end - 1]:
        match = FRONTMATTER_FIELD_RE.match(content)
        if match:
            name = match.group(1)
            value = match.group(2).strip()
            raw[name] = value
            current = name
            if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
                value = unquote(value)
            scalars[name] = value
            continue
        item = LIST_ITEM_RE.match(content)
        if item and current == "trigger_phrases":
            value = item.group(1).strip()
            if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
                value = unquote(value)
            phrases.append(value)
    return {"scalars": scalars, "raw": raw, "phrases": phrases}


def find_rule_line(text: str) -> Optional[str]:
    """Return the first rule line of one file.

    Args:
        text: File text.

    Returns:
        The line content without its terminator, or None when the file holds
        no rule line.
    """
    for _, content, _, _ in line_spans(text):
        if content.startswith(RULE_PREFIX):
            return content
    return None


def required_scalars(fields: Dict[str, Any], path: str, with_nav_label: bool = True) -> Dict[str, str]:
    """Return the required frontmatter scalars of one source file.

    Args:
        fields: Result of frontmatter_fields().
        path: Source path for an error message.
        with_nav_label: True to require a nav_label, which the entry file does
            not carry because its part labels come from the heading titles.

    Returns:
        The scalar values keyed by field name.

    Raises:
        SystemExit: If the frontmatter or a required field is missing.
    """
    if fields is None:
        fail("missing frontmatter in %s" % repo_rel(path))
    scalars: Dict[str, str] = fields["scalars"]
    names = SCALAR_FIELDS + RAW_FIELDS if with_nav_label else ("title", "description") + RAW_FIELDS
    for name in names:
        if not scalars.get(name):
            fail("missing %s in %s" % (name, repo_rel(path)))
    return scalars


def general_slug(heading: str) -> str:
    """Turn one general heading into its mechanical file slug.

    The rule drops the section number, lower cases the rest, turns every run
    of non-alphanumerics into one hyphen and trims the hyphens.

    Args:
        heading: Heading text such as "3.1 BTW (VAT)" or "4. SETTLED SOURCE
            CONFLICTS".

    Returns:
        The slug, for example "btw-vat".
    """
    title = re.sub(r"^#+[ \t]+", "", heading)
    title = re.sub(r"^[0-9]+(?:\.[0-9]+)*\.?[ \t]*", "", title)
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower())
    return slug.strip("-")


def posix_relpath(path: str, start: str) -> str:
    """Render one repository path relative to a folder.

    Args:
        path: Target repository path with forward slashes.
        start: Folder repository path with forward slashes.

    Returns:
        The relative path with forward slashes on every host.
    """
    return posixpath.relpath(path, start or ".")


def line_number_at(text: str, offset: int) -> int:
    """Return the one based line number that holds one character offset.

    Args:
        text: File text.
        offset: Character offset into the text.

    Returns:
        The line number.
    """
    return text.count("\n", 0, offset) + 1


def github_slug(heading: str) -> str:
    """Turn a heading into the GitHub anchor slug.

    Args:
        heading: Heading text without the leading hashes.

    Returns:
        Lower case text with punctuation dropped, each space turned into its
        own hyphen and hyphens kept as written.
    """
    lowered = heading.strip().lower()
    stripped = SLUG_DROP_RE.sub("", lowered)
    return SLUG_SPACE_RE.sub("-", stripped)


def heading_slug_candidates(headings: List[str]) -> List[str]:
    """Give every heading its GitHub slug, with the duplicate suffix.

    The rule is the one check-fragments.py uses: the second heading with the
    same base slug gets a counter suffix, so a citation anchor matches the
    heading the reader sees.

    Args:
        headings: Heading texts in file order.

    Returns:
        One slug per heading, in the same order.
    """
    counts: Dict[str, int] = {}
    assigned = set()
    out: List[str] = []
    for heading in headings:
        base = github_slug(heading)
        if not base:
            out.append("")
            continue
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
        out.append(candidate)
    return out


def strip_generated(text: str) -> str:
    """Drop the contents of every GENERATED fence and keep the fence lines.

    Args:
        text: Body text.

    Returns:
        The text with every byte between a start marker and its matching end
        marker removed. An unmatched start marker drops the rest of the text,
        so a hand edit inside a half-open fence still changes the hash.
    """
    spans = line_spans(text)
    pieces: List[str] = []
    block: Optional[str] = None
    for _, content, start, end in spans:
        start_match = GENERATED_START_RE.match(content)
        end_match = GENERATED_END_RE.match(content)
        if block is None:
            if start_match:
                block = start_match.group(1)
            pieces.append(text[start:end])
            continue
        if end_match and end_match.group(1) == block:
            block = None
            pieces.append(text[start:end])
            continue
        if start_match:
            # WHY: a nested start never opens a second block, and its bytes
            # stay out of the normalized hash until the first block closes.
            pieces.append(text[start:end])
            continue
    return "".join(pieces)


def strip_generated_blocks(text: str) -> str:
    """Drop every GENERATED fence, its marker lines included.

    Args:
        text: Header text.

    Returns:
        The text without any fence. The index generator adds a nav fence
        after the H1 only when a file is long enough, so the header hash must
        not depend on whether a fence is present.
    """
    fenced = strip_generated(text)
    return "".join(
        content
        for content in fenced.splitlines(keepends=True)
        if not GENERATED_START_RE.match(content) and not GENERATED_END_RE.match(content)
    )


def header_hash_text(header: str) -> str:
    """Return the header bytes that the header hash covers.

    Args:
        header: The bytes of a part file before its body, or a whole entry
            file.

    Returns:
        The header with every GENERATED fence and every blank line removed.
    """
    lines = strip_generated_blocks(header).splitlines(keepends=True)
    return "".join(line for line in lines if line.strip())


def header_sha256(header: str) -> str:
    """Return the sha256 of one derived header with its fences removed.

    Args:
        header: The bytes of a part file before its body.

    Returns:
        The hex digest. Blank lines are left out too, because the index
        generator surrounds each fence it adds with blank lines and the
        count of those carries no content.
    """
    return sha256_text(header_hash_text(header))


def entry_sha256(text: str) -> str:
    """Return the sha256 of the entry file's kept bytes and pointer table.

    The entry file is not a part, so it carries no body hash. Hashing the
    whole file with the header rule keeps a hand edit to its kept prose or
    its pointer table visible while its regenerated fences stay free.

    Args:
        text: Entry file text.

    Returns:
        The hex digest.
    """
    return header_sha256(text)


def file_header_sha256(text: str) -> Optional[str]:
    """Return the header digest of one part file.

    Args:
        text: Part file text.

    Returns:
        The digest of the bytes before the body, or None when the file holds
        no body heading.
    """
    start = body_start(text)
    if start is None:
        return None
    return header_sha256(text[:start])


def resolve_canonical_path(path_part: str, part_rel: str) -> str:
    """Resolve one link path against the part that holds it.

    Args:
        path_part: Link path without its anchor.
        part_rel: Repository path of the part file that holds the link.

    Returns:
        The repository path, with forward slashes and no dot segments.
    """
    if path_part.startswith("sk-moneybird-accountant/"):
        return posixpath.normpath(path_part)
    return posixpath.normpath(posixpath.join(posixpath.dirname(part_rel), path_part))


def canonical_target(target: str, part_rel: str, source_rel: str, split_map: Dict[str, Any]) -> str:
    """Replace one link target with its canonical repository path.

    Args:
        target: Raw link target.
        part_rel: Repository path of the part file that holds the link.
        source_rel: Repository path of the split source the part came from.
        split_map: Result of build_split_map().

    Returns:
        The canonical target. A split original becomes the part that holds
        its heading, an anchor-only target is resolved through the source
        heading map, and every other relative target becomes its repository
        path. An external URL, a title and an unresolved anchor stay as they
        are.
    """
    stripped = target.strip(" \t")
    if not stripped or SCHEME_RE.match(stripped) or stripped.startswith("//"):
        return target
    if " " in stripped or "\t" in stripped:
        return target
    if stripped.startswith("#"):
        anchors = split_map["sources"].get(source_rel, {}).get("anchors", {})
        part = anchors.get(stripped[1:])
        if part is None:
            return target
        return part + stripped
    path_part, _, fragment = stripped.partition("#")
    resolved = resolve_canonical_path(path_part, part_rel)
    if resolved in split_map["sources"]:
        info = split_map["sources"][resolved]
        if fragment:
            part = info["anchors"].get(fragment)
            if part is None:
                return target
        else:
            part = info["figures"]
        return part + (("#" + fragment) if fragment else "")
    return resolved + (("#" + fragment) if fragment else "")


def canonicalize_targets(text: str, part_rel: str, source_rel: str, split_map: Dict[str, Any]) -> str:
    """Replace every link target in one text with its canonical repository path.

    Args:
        text: Text with inline links.
        part_rel: Repository path of the file that holds the links.
        source_rel: Repository path of the split source the file came from.
        split_map: Result of build_split_map().

    Returns:
        The text with every link target replaced by its canonical repository
        path. Every other byte is kept.
    """

    def replacement(match: re.Match) -> str:
        return "](" + canonical_target(match.group(1), part_rel, source_rel, split_map) + ")"

    return INLINE_LINK_RE.sub(replacement, text)


def normalize_body(text: str, part_rel: str, source_rel: str, split_map: Dict[str, Any]) -> str:
    """Normalize one body for the manifest hash.

    Args:
        text: Body text.
        part_rel: Repository path of the part file that holds the body.
        source_rel: Repository path of the split source the part came from.
        split_map: Result of build_split_map().

    Returns:
        The body with GENERATED fence contents removed and every link target
        replaced by its canonical repository path.
    """
    return canonicalize_targets(strip_generated(text), part_rel, source_rel, split_map)


def rebase_target(target: str, source_rel: str, part_rel: str, split_map: Dict[str, Any]) -> str:
    """Rebase one relative link target for a part at a deeper folder.

    Args:
        target: Raw link target.
        source_rel: Repository path of the split source the part came from.
        part_rel: Repository path of the part file that holds the link.
        split_map: Result of build_split_map().

    Returns:
        The rebased target, or the raw target when it is external, holds a
        title or resolves inside the part already.

    Raises:
        SystemExit: If an anchor matches no heading in a split source.
    """
    stripped = target.strip(" \t")
    if not stripped or SCHEME_RE.match(stripped) or stripped.startswith("//"):
        return target
    if " " in stripped or "\t" in stripped:
        return target
    part_dir = posixpath.dirname(part_rel)
    if stripped.startswith("#"):
        part = split_map["sources"][source_rel]["anchors"].get(stripped[1:])
        if part is None or part == part_rel:
            return target
        return posix_relpath(part, part_dir) + stripped
    path_part, _, fragment = stripped.partition("#")
    resolved = posixpath.normpath(posixpath.join(posixpath.dirname(source_rel), path_part))
    if resolved in split_map["sources"]:
        info = split_map["sources"][resolved]
        if fragment:
            part = info["anchors"].get(fragment)
            if part is None:
                fail("anchor #%s matches no heading in %s" % (fragment, resolved))
        else:
            part = info["figures"]
        new_path = posix_relpath(part, part_dir)
    else:
        new_path = posix_relpath(resolved, part_dir)
    if stripped.startswith("./") and not new_path.startswith(("./", "../")):
        new_path = "./" + new_path
    if fragment:
        new_path += "#" + fragment
    return new_path


def rebase_body(text: str, source_rel: str, part_rel: str, split_map: Dict[str, Any]) -> str:
    """Rebase every relative link in one part body.

    Args:
        text: Body text.
        source_rel: Repository path of the split source the part came from.
        part_rel: Repository path of the part file that holds the body.
        split_map: Result of build_split_map().

    Returns:
        The body with every relative link rebased. Every other byte is kept.
    """

    def replacement(match: re.Match) -> str:
        return "](" + rebase_target(match.group(1), source_rel, part_rel, split_map) + ")"

    return INLINE_LINK_RE.sub(replacement, text)


def build_split_map(entries: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Build the split map that the rebase, the normalization and the remap share.

    Args:
        entries: One record per split source, each with its repository path,
            its kind, its part records and an optional line map.

    Returns:
        A record with the source records keyed by path, the part to source
        map and the part bodies keyed by path.
    """
    sources: Dict[str, Dict[str, Any]] = {}
    parts: Dict[str, str] = {}
    bodies: Dict[str, str] = {}
    for entry in entries:
        source = entry["source"]
        headings: List[str] = []
        heading_parts: List[str] = []
        explicit: List[Tuple[str, str]] = []
        for part in entry["parts"]:
            body = part["body"]
            bodies[part["path"]] = body
            parts[part["path"]] = source
            for heading in scan_headings(body):
                headings.append(heading["text"])
                heading_parts.append(part["path"])
            for anchor in ANCHOR_ID_RE.findall(body):
                explicit.append((anchor, part["path"]))
        anchors: Dict[str, str] = {}
        for slug, part_path in zip(heading_slug_candidates(headings), heading_parts):
            if slug and slug not in anchors:
                anchors[slug] = part_path
        for anchor, part_path in explicit:
            anchors.setdefault(anchor, part_path)
        # WHY: the guide keeps sections 1, 2 and 7 in its entry file, so a
        # citation to a heading there still points at the entry itself.
        kept = entry.get("kept")
        if kept:
            kept_headings = [heading["text"] for heading in scan_headings(kept)]
            for slug in heading_slug_candidates(kept_headings):
                if slug:
                    anchors.setdefault(slug, source)
            for anchor in ANCHOR_ID_RE.findall(kept):
                anchors.setdefault(anchor, source)
        line_map = entry.get("line_map")
        if line_map is None:
            line_map = []
            for part in entry["parts"]:
                if part.get("source_start_line") is None:
                    continue
                line_map.append(
                    {
                        "part": part["path"],
                        "source_start_line": part["source_start_line"],
                        "source_end_line": part["source_end_line"],
                        "line_offset": part["line_offset"],
                    }
                )
        figures = entry.get("figures")
        if figures is None and entry["parts"]:
            figures = entry["parts"][0]["path"]
        sources[source] = {
            "kind": entry.get("kind", "year"),
            "parts": entry["parts"],
            "anchors": anchors,
            "figures": figures,
            "line_map": line_map,
        }
    return {"sources": sources, "parts": parts, "bodies": bodies}


def remap_source_line(split_map: Dict[str, Any], source: str, line: int) -> Optional[Tuple[str, int]]:
    """Map one source line number to its part and its line there.

    Args:
        split_map: Result of build_split_map().
        source: Repository path of a split source.
        line: One based source line number.

    Returns:
        A pair of the part path and the one based line inside it, or None
        when the line falls outside every run.
    """
    for run in split_map["sources"].get(source, {}).get("line_map", []):
        if run["source_start_line"] <= line <= run["source_end_line"]:
            return run["part"], line + run["line_offset"]
    return None


def relative_to(root: str, path: str) -> str:
    """Render one path relative to a root with forward slashes.

    Args:
        root: Root folder.
        path: Absolute or root relative path.

    Returns:
        The relative path with forward slashes.
    """
    return os.path.relpath(path, root).replace(os.sep, "/")


def citation_is_missing_candidate(written: str, citing_rel: str) -> bool:
    """Tell whether an unresolved citation names a tax-rules source.

    Args:
        written: Path as the citing file spells it.
        citing_rel: Repository path of the citing file.

    Returns:
        True when a candidate resolution lands on a tax-rules year topic
        path or on the guide entry. A bare document name such as vat.md in
        the guide body and a YYYY placeholder are documentation, not a
        broken citation, so they stay untouched.
    """
    bases = [posixpath.dirname(citing_rel)] + list(CITATION_BASES)
    for base in bases:
        candidate = posixpath.normpath(posixpath.join(base, written)) if base else posixpath.normpath(written)
        if candidate.startswith("../") or candidate == ".." or posixpath.isabs(candidate):
            continue
        if SPLIT_SOURCE_RE.search(candidate):
            return True
    return False


def candidate_citation_files(repo_root: str) -> List[str]:
    """List the tracked markdown and JSON files the citation scan reads.

    Args:
        repo_root: Repository root.

    Returns:
        Sorted repository relative paths. The git index is the source of
        truth, and a tree without git falls back to a walk that skips the
        private folders. The generated files, the gate file, the manifest,
        the split sources and the moved parts are left out.
    """
    tracked: Optional[List[str]] = None
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode == 0:
            tracked = [name.decode("utf-8") for name in result.stdout.split(b"\0") if name]
    except OSError:
        tracked = None
    if tracked is None:
        tracked = []
        for directory, subdirectories, names in os.walk(repo_root):
            subdirectories[:] = [
                name
                for name in subdirectories
                if name not in ("specs", ".git", "personal database", "migration-workspace")
            ]
            for name in names:
                tracked.append(relative_to(repo_root, os.path.join(directory, name)))
    out: List[str] = []
    for name in sorted(set(tracked)):
        if not name.endswith(CITATION_SUFFIXES):
            continue
        if name.startswith("specs/") or "/specs/" in name:
            continue
        if name in CITATION_SKIP_FILES:
            continue
        if YEAR_PART_RE.search(name) or GENERAL_PART_RE.search(name):
            continue
        out.append(name)
    return out


def resolve_citation(
    written: str, citing_rel: str, repo_root: str, split_map: Dict[str, Any]
) -> Tuple[Optional[str], str]:
    """Resolve one written citation path against the likely bases.

    Args:
        written: Path as the citing file spells it.
        citing_rel: Repository path of the citing file.
        repo_root: Repository root.
        split_map: Result of build_split_map().

    Returns:
        A pair of the repository path and the base that resolved it, both
        None and empty when no base resolves the path.
    """
    bases = [posixpath.dirname(citing_rel)] + list(CITATION_BASES)
    for base in bases:
        candidate = posixpath.normpath(posixpath.join(base, written)) if base else posixpath.normpath(written)
        if candidate.startswith("../") or candidate == ".." or posixpath.isabs(candidate):
            continue
        if candidate in split_map["sources"] or candidate in split_map["parts"]:
            return candidate, base
        if os.path.exists(os.path.join(repo_root, candidate)):
            return candidate, base
    return None, ""


def overview_heading(paragraph: str) -> str:
    """Render the generated OVERVIEW block that opens a part body.

    Args:
        paragraph: The one or two sentence overview text.

    Returns:
        The heading, the paragraph and the separator that the template puts
        between two H2 sections, so the next heading keeps its separator.
    """
    return "## 1. OVERVIEW\n\n%s\n\n---\n\n" % paragraph


def year_overview_paragraph(file_name: str, title: str) -> str:
    """Return the generated overview paragraph of one year part.

    Args:
        file_name: Part file name such as rules.md.
        title: Topic title without the part label.

    Returns:
        The paragraph text.
    """
    return YEAR_OVERVIEW_TEXT[file_name] % title


def general_overview_paragraph(title: str) -> str:
    """Return the generated overview paragraph of one general part.

    Args:
        title: General topic title.

    Returns:
        The paragraph text.
    """
    return GENERAL_OVERVIEW_TEXT % title


def conform_h2_headings(text: str, start_number: int) -> str:
    """Renumber the numbered H2 headings of one body and upper case each H2.

    A numbered H2 becomes the next number in file order from start_number.
    An unnumbered H2 keeps its text and gains upper case. A heading inside a
    code fence is content and stays as it is. Every other byte, the anchor
    lines included, is kept exactly.

    Args:
        text: Body text with H2 headings.
        start_number: Number the first numbered H2 receives.

    Returns:
        The text with its H2 headings conformed.
    """
    out: List[str] = []
    in_code = False
    number = start_number
    for line in text.splitlines(keepends=True):
        content = line.rstrip("\n")
        ending = line[len(content):]
        if content.strip().startswith(CODE_FENCE_PREFIXES):
            in_code = not in_code
            out.append(line)
            continue
        if not in_code:
            match = NUMBERED_H2_LINE_RE.match(content)
            if match:
                out.append("## %d. %s%s" % (number, match.group(2).strip().upper(), ending))
                number += 1
                continue
            match = PLAIN_H2_LINE_RE.match(content)
            if match and match.group(1).strip():
                title = match.group(1).strip()
                if title != title.upper():
                    out.append("## %s%s" % (title.upper(), ending))
                    continue
        out.append(line)
    return "".join(out)


def conform_year_part_body(body: str, index: int, title: str) -> str:
    """Return one year part body in its conformed form.

    figures.md keeps its body, because source sections 1 and 2 already open
    with an OVERVIEW. The other three parts gain the generated overview and
    renumber their numbered H2 headings from 2.

    Args:
        body: Source section bytes of one part.
        index: Zero based part index in PART_DEFS.
        title: Topic title without the part label.

    Returns:
        The conformed body.
    """
    if index == 0:
        return body
    definition = PART_DEFS[index]
    paragraph = year_overview_paragraph(definition["file"], title)
    return overview_heading(paragraph) + conform_h2_headings(body, 2)


def conform_general_part_body(body: str, title: str) -> str:
    """Return one general part body in its conformed form.

    Every general part gains the generated overview. A moved entry H2 is
    renumbered to 2, while an H3 subsection keeps its entry number.

    Args:
        body: Entry section bytes of one general topic.
        title: General topic title.

    Returns:
        The conformed body.
    """
    return overview_heading(general_overview_paragraph(title)) + conform_h2_headings(body, 2)


# ───────────────────────────────────────────────────────────────
# 4. YEAR TOPIC PLAN
# ───────────────────────────────────────────────────────────────

def year_sources() -> List[str]:
    """List the year topic files that still hold their eight sections.

    Returns:
        Sorted absolute paths of the markdown files that sit directly in a
        year folder and are not the year README, changelog or change note.
    """
    found: List[str] = []
    if not os.path.isdir(TAX_RULES_ROOT):
        fail("missing folder %s" % repo_rel(TAX_RULES_ROOT))
    for name in sorted(os.listdir(TAX_RULES_ROOT)):
        year_dir = os.path.join(TAX_RULES_ROOT, name)
        if not YEAR_RE.match(name) or not os.path.isdir(year_dir):
            continue
        for file_name in sorted(os.listdir(year_dir)):
            if not file_name.endswith(".md") or file_name in NON_TOPIC_NAMES:
                continue
            path = os.path.join(year_dir, file_name)
            if os.path.isfile(path):
                found.append(path)
    return found


def numbered_h2(text: str) -> List[Dict[str, Any]]:
    """Map the numbered H2 headings of one topic file.

    Args:
        text: File text.

    Returns:
        One record per H2 heading that starts with a number and a dot, in
        file order, with the number, the heading text, the line number and
        the start offset.
    """
    rows: List[Dict[str, Any]] = []
    for heading in scan_headings(text):
        if heading["level"] != 2:
            continue
        match = NUMBERED_H2_RE.match(heading["text"])
        if not match:
            continue
        rows.append(
            {
                "number": int(match.group(1)),
                "heading": heading["text"],
                "line": heading["line"],
                "start": heading["start"],
            }
        )
    return rows


def year_part_header(fields: Dict[str, Any], rule_line: str, title: str, index: int) -> str:
    """Render the derived header of one year part file.

    Args:
        fields: Result of frontmatter_fields().
        rule_line: The year rule line copied verbatim.
        title: Topic title from the source frontmatter.
        index: Zero based part index in PART_DEFS.

    Returns:
        The header text, ending with one blank line before the body.
    """
    definition = PART_DEFS[index]
    scalars = fields["scalars"]
    label = definition["label"]
    part_title = "%s: %s" % (title, label)
    description = scalars["description"]
    if index > 0:
        description = description + " This file holds the %s part." % label.lower()
    nav_label = scalars["nav_label"]
    if index > 0:
        nav_label = (nav_label + " " + label.lower())[:NAV_LABEL_LIMIT]
    lines = [
        "---",
        "title: %s" % yaml_quote(part_title),
        "description: %s" % yaml_quote(description),
        "nav_label: %s" % yaml_quote(nav_label),
        "trigger_phrases:",
    ]
    for phrase in fields["phrases"]:
        lines.append("  - %s" % yaml_quote(phrase))
    lines.append("  - %s" % yaml_quote("%s %s" % (title, label.lower())))
    for name in RAW_FIELDS:
        lines.append("%s: %s" % (name, fields["raw"][name]))
    lines += [
        "---",
        "",
        "# %s" % part_title,
        "",
        rule_line,
        "",
        "Part %d of 4 of the %s topic." % (index + 1, title),
        "",
    ]
    for other in PART_DEFS:
        if other["file"] == definition["file"]:
            continue
        lines.append("- [%s](%s): %s." % (other["file"], other["file"], other["ranges"]))
    lines += [
        "",
        "Year overview: [README.md](../README.md).",
        "",
    ]
    return "\n".join(lines) + "\n"


def plan_year_source(path: str) -> Dict[str, Any]:
    """Plan the split of one year topic file without writing it.

    Args:
        path: Absolute path of the topic file.

    Returns:
        A record with the source path, the title, the original body, its
        sha256 and one part record per PART_DEFS entry. A part record carries
        its repository-relative path, its section numbers, its conformed
        body, its body sha256, the whole derived file content and the line map
        fields that turn a source line number into a part line number.

    Raises:
        SystemExit: If the file misses its frontmatter, its rule line or any
            of its eight numbered H2 sections.
    """
    text = read_text(path)
    fields = frontmatter_fields(text)
    scalars = required_scalars(fields, path)
    rule_line = find_rule_line(text)
    if rule_line is None:
        fail("missing rule line in %s" % repo_rel(path))
    rows = numbered_h2(text)
    numbers = [row["number"] for row in rows]
    if len(rows) != 8 or numbers != [1, 2, 3, 4, 5, 6, 7, 8]:
        fail("missing the eight numbered H2 sections in %s (found %s)" % (repo_rel(path), numbers))
    total_lines = len(line_spans(text))
    body = text[rows[0]["start"]:]
    parts: List[Dict[str, Any]] = []
    for index, definition in enumerate(PART_DEFS):
        first = definition["sections"][0]
        last = definition["sections"][-1]
        start = rows[first - 1]["start"]
        end = rows[last]["start"] if last < 8 else len(text)
        start_line = rows[first - 1]["line"]
        end_line = rows[last]["line"] - 1 if last < 8 else total_lines
        part_body_text = text[start:end]
        conformed_body = conform_year_part_body(part_body_text, index, scalars["title"])
        inserted_lines = conformed_body.count("\n") - part_body_text.count("\n")
        header = year_part_header(fields, rule_line, scalars["title"], index)
        folder = os.path.splitext(os.path.basename(path))[0]
        part_path = os.path.join(os.path.dirname(path), folder, definition["file"])
        parts.append(
            {
                "path": repo_rel(part_path),
                "sections": definition["sections"],
                "body": conformed_body,
                "body_sha256": sha256_text(conformed_body),
                "content": header + conformed_body,
                "header": header,
                "start_line": start_line,
                "end_line": end_line,
                # WHY: the conformed body opens with the generated overview,
                # so a source line maps that many lines farther down.
                "line_offset": header.count("\n") + 1 - start_line + inserted_lines,
            }
        )
    return {
        "source": repo_rel(path),
        "absolute": path,
        "title": scalars["title"],
        "body": body,
        "body_sha256": sha256_text(body),
        "parts": parts,
    }

# ───────────────────────────────────────────────────────────────
# 5. GENERAL PLAN
# ───────────────────────────────────────────────────────────────

def entry_has_general_headings(text: str) -> bool:
    """Tell whether the entry file still holds the general H3 subsections.

    Args:
        text: Entry file text.

    Returns:
        True when at least one H3 heading starts with "3.".
    """
    for heading in scan_headings(text):
        if heading["level"] == 3 and NUMBERED_H3_RE.match(heading["text"]):
            if heading["text"].startswith("3."):
                return True
    return False


def general_part_header(
    fields: Dict[str, Any],
    rule_line: str,
    regions: List[Dict[str, Any]],
    slugs: Tuple[str, ...],
    index: int,
) -> str:
    """Render the derived header of one general part file.

    Args:
        fields: Result of frontmatter_fields().
        rule_line: The rule line copied verbatim from the entry file.
        regions: One record per general topic, in file order, each with its
            section number and its title.
        slugs: The 13 mechanical slugs in the same order.
        index: Zero based part index.

    Returns:
        The header text, ending with one blank line before the body.
    """
    scalars = fields["scalars"]
    title = regions[index]["title"]
    description = scalars["description"] + " This file holds the general topic %s." % title
    lines = [
        "---",
        "title: %s" % yaml_quote(title),
        "description: %s" % yaml_quote(description),
        "nav_label: %s" % yaml_quote(title[:NAV_LABEL_LIMIT]),
        "trigger_phrases:",
    ]
    for phrase in fields["phrases"]:
        lines.append("  - %s" % yaml_quote(phrase))
    lines.append("  - %s" % yaml_quote(title))
    for name in RAW_FIELDS:
        lines.append("%s: %s" % (name, fields["raw"][name]))
    lines += [
        "---",
        "",
        "# %s" % title,
        "",
        rule_line,
        "",
        "General topic %s of 13 in the Dutch tax rules guide." % regions[index]["section"],
        "",
    ]
    for position, region in enumerate(regions):
        lines.append(
            "- [%s.md](%s.md): %s %s." % (slugs[position], slugs[position], region["section"], region["title"])
        )
    lines += [
        "",
        "Guide: [dutch-tax-rules.md](../dutch-tax-rules.md).",
        "",
    ]
    return "\n".join(lines) + "\n"


def entry_pointer_table(regions: List[Dict[str, Any]], slugs: Tuple[str, ...]) -> str:
    """Render the pointer table that replaces the moved entry sections.

    Args:
        regions: One record per general topic, in file order.
        slugs: The 13 mechanical slugs in the same order.

    Returns:
        The table text with a heading, the rows and a closing separator line.
    """
    lines = [
        "### General topics",
        "",
        "Each general topic below sits in its own file under `general/`.",
        "",
        "| Section | Topic | File |",
        "|---|---|---|",
    ]
    for position, region in enumerate(regions):
        lines.append(
            "| %s | %s | [%s.md](general/%s.md) |"
            % (region["section"], region["title"], slugs[position], slugs[position])
        )
    lines += ["", "---", ""]
    return "\n".join(lines) + "\n"


def plan_general_source(path: str) -> Optional[Dict[str, Any]]:
    """Plan the split of the entry file without writing it.

    Args:
        path: Absolute path of dutch-tax-rules.md.

    Returns:
        A record with the source path, the original moved region, its sha256,
        the 13 part records, the new entry text and the entry line map, or
        None when the entry file already lost its general subsections.

    Raises:
        SystemExit: If the file misses its frontmatter, its rule line, its ten
            general subsections, its three moved H2 sections or the kept H2
            heading after them, or when a computed slug is outside
            GENERAL_SLUGS.
    """
    text = read_text(path)
    fields = frontmatter_fields(text)
    required_scalars(fields, path, with_nav_label=False)
    rule_line = find_rule_line(text)
    if rule_line is None:
        fail("missing rule line in %s" % repo_rel(path))
    headings = scan_headings(text)
    subsections: List[Dict[str, Any]] = []
    for heading in headings:
        if heading["level"] != 3:
            continue
        match = NUMBERED_H3_RE.match(heading["text"])
        if match and heading["text"].startswith("3."):
            subsections.append(
                {
                    "heading": heading["text"],
                    "section": match.group(1),
                    "title": match.group(2).strip(),
                    "line": heading["line"],
                    "start": heading["start"],
                }
            )
    moved_h2: List[Dict[str, Any]] = []
    anchor_seven: Optional[int] = None
    anchor_seven_line: Optional[int] = None
    for heading in headings:
        if heading["level"] != 2:
            continue
        match = NUMBERED_H2_RE.match(heading["text"])
        if not match:
            continue
        number = match.group(1)
        if number in GENERAL_ENTRY_ANCHORS:
            moved_h2.append(
                {
                    "heading": heading["text"],
                    "section": number,
                    "title": match.group(2).strip(),
                    "line": heading["line"],
                    "start": heading["start"],
                }
            )
        elif number == "7" and anchor_seven is None:
            anchor_seven = heading["start"]
            anchor_seven_line = heading["line"]
    if not subsections and not moved_h2:
        return None
    section_numbers = [row["section"] for row in subsections]
    if section_numbers != list(GENERAL_SECTION_NUMBERS[:10]):
        fail("general subsections of %s are %s" % (repo_rel(path), section_numbers))
    if [row["section"] for row in moved_h2] != list(GENERAL_ENTRY_ANCHORS):
        fail("general H2 sections of %s are %s" % (repo_rel(path), [row["section"] for row in moved_h2]))
    if anchor_seven is None or anchor_seven_line is None:
        fail("missing the kept heading after the moved block in %s" % repo_rel(path))
    if moved_h2[0]["start"] < subsections[-1]["start"] or anchor_seven < moved_h2[-1]["start"]:
        fail("general sections out of order in %s" % repo_rel(path))
    moved = subsections + moved_h2
    for index, row in enumerate(moved):
        row["end"] = moved[index + 1]["start"] if index + 1 < len(moved) else anchor_seven
    slugs = tuple(general_slug(row["heading"]) for row in moved)
    if slugs != GENERAL_SLUGS:
        fail("general slugs %s do not match the allowlist" % (slugs,))
    slugs = GENERAL_FILES
    total_lines = len(line_spans(text))
    parts: List[Dict[str, Any]] = []
    for index, row in enumerate(moved):
        part_body_text = text[row["start"]:row["end"]]
        conformed_body = conform_general_part_body(part_body_text, row["title"])
        inserted_lines = conformed_body.count("\n") - part_body_text.count("\n")
        header = general_part_header(fields, rule_line, moved, slugs, index)
        end_line = moved[index + 1]["line"] - 1 if index + 1 < len(moved) else anchor_seven_line - 1
        parts.append(
            {
                "path": repo_rel(os.path.join(GENERAL_DIR, slugs[index] + ".md")),
                "section": row["section"],
                "heading": row["heading"],
                "body": conformed_body,
                "body_sha256": sha256_text(conformed_body),
                "content": header + conformed_body,
                "header": header,
                "start_line": row["line"],
                "end_line": end_line,
                # WHY: the conformed body opens with the generated overview,
                # so an entry line maps that many lines farther down.
                "line_offset": header.count("\n") + 1 - row["line"] + inserted_lines,
            }
        )
    region = text[moved[0]["start"]:anchor_seven]
    pointer_table = entry_pointer_table(moved, slugs)
    # WHY: the moved block takes sections 4, 5 and 6, so the kept headings
    # after it continue the guide sequence from 4.
    kept_after = conform_h2_headings(text[anchor_seven:], int(GENERAL_ENTRY_ANCHORS[0]))
    entry_text = text[: moved[0]["start"]] + pointer_table + kept_after
    # WHY: the moved region is one contiguous run, so the lines the entry
    # keeps before it keep their number and the lines after it shift by the
    # difference between the inserted table and the removed bytes.
    line_map: List[Dict[str, Any]] = []
    if moved[0]["line"] > 1:
        line_map.append(
            {
                "part": repo_rel(path),
                "source_start_line": 1,
                "source_end_line": moved[0]["line"] - 1,
                "line_offset": 0,
            }
        )
    for part in parts:
        line_map.append(
            {
                "part": part["path"],
                "source_start_line": part["start_line"],
                "source_end_line": part["end_line"],
                "line_offset": part["line_offset"],
            }
        )
    if anchor_seven_line <= total_lines:
        line_map.append(
            {
                "part": repo_rel(path),
                "source_start_line": anchor_seven_line,
                "source_end_line": total_lines,
                "line_offset": pointer_table.count("\n") - (anchor_seven_line - moved[0]["line"]),
            }
        )
    return {
        "source": repo_rel(path),
        "absolute": path,
        "body": region,
        "body_sha256": sha256_text(region),
        "parts": parts,
        "entry_text": entry_text,
        "line_map": line_map,
    }

# ───────────────────────────────────────────────────────────────
# 6. MANIFEST
# ───────────────────────────────────────────────────────────────

def year_manifest_row(plan: Dict[str, Any]) -> Dict[str, Any]:
    """Build the manifest row of one year topic split.

    Args:
        plan: Result of plan_year_source(). A part record may carry a
            rebased normalized body under the "normalized" key, which is the
            body the hash covers.

    Returns:
        The row with the source, the normalized rejoin hash and the four part
        records with their line map fields.
    """
    normalized = [part.get("normalized", part["body"]) for part in plan["parts"]]
    rejoin = sha256_text("".join(normalized))
    return {
        "source": plan["source"],
        "body_sha256": rejoin,
        "rejoin_sha256": rejoin,
        "parts": [
            {
                "path": part["path"],
                "sections": list(part["sections"]),
                "body_sha256": sha256_text(part.get("normalized", part["body"])),
                "header_sha256": header_sha256(part["header"]),
                "source_start_line": part["start_line"],
                "source_end_line": part["end_line"],
                "line_offset": part["line_offset"],
            }
            for part in plan["parts"]
        ],
    }


def general_manifest_row(plan: Dict[str, Any]) -> Dict[str, Any]:
    """Build the manifest record of the general split.

    Args:
        plan: Result of plan_general_source(). A part record may carry a
            rebased normalized body under the "normalized" key, which is the
            body the hash covers.

    Returns:
        The record with the entry source, the normalized rejoin hash, the
        entry line map and the 13 part records with their line map fields.
    """
    normalized = [part.get("normalized", part["body"]) for part in plan["parts"]]
    rejoin = sha256_text("".join(normalized))
    return {
        "source": plan["source"],
        "body_sha256": rejoin,
        "rejoin_sha256": rejoin,
        "line_map": plan.get("line_map", []),
        "parts": [
            {
                "path": part["path"],
                "section": part["section"],
                "heading": part["heading"],
                "body_sha256": sha256_text(part.get("normalized", part["body"])),
                "header_sha256": header_sha256(part["header"]),
                "source_start_line": part["start_line"],
                "source_end_line": part["end_line"],
                "line_offset": part["line_offset"],
            }
            for part in plan["parts"]
        ],
    }


def rebuild_general_row() -> Optional[Dict[str, Any]]:
    """Rebuild the general manifest record from the general part files alone.

    The original moved region is gone when this runs, so the rejoin hash is
    the recorded body hash too. The bodies are normalized with the same rule
    the checker uses, and the record carries no line map because the original
    line numbers are gone.

    Returns:
        The record, or None when a general part file is missing.
    """
    paths: List[str] = []
    bodies: List[str] = []
    headers: List[str] = []
    for slug in GENERAL_FILES:
        path = os.path.join(GENERAL_DIR, slug + ".md")
        if not os.path.isfile(path):
            return None
        text = read_text(path)
        body = part_body(text)
        digest = file_header_sha256(text)
        if body is None or digest is None:
            return None
        paths.append(repo_rel(path))
        bodies.append(body)
        headers.append(digest)
    source = repo_rel(ENTRY_PATH)
    split_map = build_split_map(
        [
            {
                "source": source,
                "kind": "general",
                "figures": source,
                "parts": [
                    {"path": paths[index], "body": bodies[index]} for index in range(len(paths))
                ],
            }
        ]
    )
    normalized = [
        normalize_body(bodies[index], paths[index], source, split_map) for index in range(len(paths))
    ]
    rejoin = sha256_text("".join(normalized))
    parts: List[Dict[str, Any]] = []
    for index, slug in enumerate(GENERAL_FILES):
        parts.append(
            {
                "path": paths[index],
                "section": GENERAL_SECTION_NUMBERS[index],
                "heading": GENERAL_SECTION_NUMBERS[index],
                "body_sha256": sha256_text(normalized[index]),
                "header_sha256": headers[index],
            }
        )
    if not os.path.isfile(ENTRY_PATH):
        return None
    return {
        "source": source,
        "body_sha256": rejoin,
        "rejoin_sha256": rejoin,
        "entry_sha256": entry_sha256(read_text(ENTRY_PATH)),
        "parts": parts,
    }


def merge_manifest(
    old: Optional[Dict[str, Any]],
    rows: List[Dict[str, Any]],
    general: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    """Merge newly planned rows into the stored manifest.

    Args:
        old: Stored manifest, or None when the tree holds none.
        rows: New year rows from year_manifest_row().
        general: New general record from general_manifest_row(), or None when
            the entry file carries no general section any more.

    Returns:
        The manifest a write would leave, with its keys in a stable order.
    """
    by_source: Dict[str, Dict[str, Any]] = {}
    if old is not None:
        for row in old["files"]:
            by_source[row["source"]] = row
    for row in rows:
        by_source[row["source"]] = row
    data: Dict[str, Any] = {
        "generated_by": GENERATOR,
        "version": MANIFEST_VERSION,
        "files": [by_source[source] for source in sorted(by_source)],
    }
    if general is not None:
        data["general"] = general
    elif old is not None and isinstance(old.get("general"), dict):
        data["general"] = old["general"]
    else:
        rebuilt = rebuild_general_row()
        if rebuilt is None:
            fail("no general split planned and none in %s" % repo_rel(MANIFEST_PATH))
        data["general"] = rebuilt
    return data


def render_manifest(data: Dict[str, Any]) -> str:
    """Render the manifest with sorted keys and a trailing newline.

    Args:
        data: Manifest record.

    Returns:
        The JSON text.
    """
    return json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def read_manifest(required: bool) -> Optional[Dict[str, Any]]:
    """Read the split manifest.

    Args:
        required: True to stop with exit 2 when the file is missing.

    Returns:
        The manifest record, or None when the file is missing and not
        required.

    Raises:
        SystemExit: If the file is required and missing, holds invalid JSON or
            misses a well-formed row list.
    """
    if not os.path.isfile(MANIFEST_PATH):
        if required:
            fail("missing manifest %s" % repo_rel(MANIFEST_PATH))
        return None
    text = read_text(MANIFEST_PATH)
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        fail("cannot parse %s: %s" % (repo_rel(MANIFEST_PATH), exc))
    if not isinstance(data, dict) or not isinstance(data.get("files"), list):
        fail("malformed manifest %s" % repo_rel(MANIFEST_PATH))
    for row in data["files"]:
        if not isinstance(row, dict) or not isinstance(row.get("source"), str):
            fail("malformed manifest row in %s" % repo_rel(MANIFEST_PATH))
        if not isinstance(row.get("parts"), list):
            fail("malformed part list in %s" % repo_rel(MANIFEST_PATH))
        for name in ("body_sha256", "rejoin_sha256"):
            if not isinstance(row.get(name), str):
                fail("malformed row hash in %s" % repo_rel(MANIFEST_PATH))
        for part in row["parts"]:
            if not isinstance(part, dict) or not isinstance(part.get("path"), str):
                fail("malformed part record in %s" % repo_rel(MANIFEST_PATH))
            if not isinstance(part.get("body_sha256"), str) or not isinstance(part.get("header_sha256"), str):
                fail("malformed part record in %s" % repo_rel(MANIFEST_PATH))
    general = data.get("general")
    if general is not None:
        if not isinstance(general, dict) or not isinstance(general.get("parts"), list):
            fail("malformed general record in %s" % repo_rel(MANIFEST_PATH))
        for name in ("source", "body_sha256", "rejoin_sha256", "entry_sha256"):
            if not isinstance(general.get(name), str):
                fail("malformed general record in %s" % repo_rel(MANIFEST_PATH))
        for part in general["parts"]:
            if not isinstance(part, dict) or not isinstance(part.get("path"), str):
                fail("malformed general part in %s" % repo_rel(MANIFEST_PATH))
            if not isinstance(part.get("body_sha256"), str) or not isinstance(part.get("header_sha256"), str):
                fail("malformed general part in %s" % repo_rel(MANIFEST_PATH))
    return data

# ───────────────────────────────────────────────────────────────
# 7. LINK REBASE, NORMALIZATION AND CITATION REMAP
# ───────────────────────────────────────────────────────────────

def split_map_entries_from_manifest(
    manifest: Dict[str, Any],
    repo_root: str,
    part_bodies: Optional[Dict[str, str]] = None,
    overrides: Optional[Dict[str, str]] = None,
) -> List[Dict[str, Any]]:
    """Build the split map entries from a manifest and the part files.

    Args:
        manifest: Stored or planned manifest.
        repo_root: Repository root.
        part_bodies: Part bodies keyed by path, or None to read them from
            the repository.
        overrides: File text keyed by repository path that replaces the text
            on disk, used for the entry file before a write.

    Returns:
        One entry per split source, with the part records the map builder
        needs. A part file that is missing is left out.
    """

    def read_part(part: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        path = part.get("path")
        if not isinstance(path, str):
            return None
        body = None
        if part_bodies is not None and path in part_bodies:
            body = part_bodies[path]
        else:
            absolute = os.path.join(repo_root, path)
            if os.path.isfile(absolute):
                body = part_body(read_text(absolute))
        if body is None:
            return None
        record: Dict[str, Any] = {"path": path, "body": body}
        for name in ("source_start_line", "source_end_line", "line_offset"):
            if isinstance(part.get(name), int):
                record[name] = part[name]
        return record

    entries: List[Dict[str, Any]] = []
    for row in manifest.get("files", []):
        if not isinstance(row, dict):
            continue
        parts = []
        for part in row.get("parts", []):
            if isinstance(part, dict):
                record = read_part(part)
                if record is not None:
                    parts.append(record)
        entries.append({"source": row["source"], "kind": "year", "parts": parts})
    general = manifest.get("general")
    if isinstance(general, dict):
        parts = []
        for part in general.get("parts", []):
            if isinstance(part, dict):
                record = read_part(part)
                if record is not None:
                    parts.append(record)
        line_map = general.get("line_map")
        entry_kept = None
        if overrides and general["source"] in overrides:
            entry_kept = overrides[general["source"]]
        else:
            entry_absolute = os.path.join(repo_root, general["source"])
            if os.path.isfile(entry_absolute):
                entry_kept = read_text(entry_absolute)
        entries.append(
            {
                "source": general["source"],
                "kind": "general",
                "parts": parts,
                "figures": general["source"],
                "kept": entry_kept,
                "line_map": line_map if isinstance(line_map, list) else None,
            }
        )
    return entries


def remap_citations(
    manifest: Dict[str, Any],
    repo_root: str,
    write: bool = False,
    part_bodies: Optional[Dict[str, str]] = None,
    overrides: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    """Remap every citation of a split file to its part file.

    Args:
        manifest: Manifest a write would leave, or the stored manifest in
            check mode.
        repo_root: Repository root.
        write: True to return the rewritten file text, False to report every
            citation that still points at a split source.
        part_bodies: Part bodies keyed by path for a write that has not
            written the part files yet, or None to read them from the tree.
        overrides: File text keyed by repository path that replaces the text
            on disk. The write mode uses it for the entry file, whose new
            text is planned before the file is written.

    Returns:
        A record with the unmapped citation lines, the rewrites as pairs of
        repository path and new text, the remapped count and the untouched
        count. A citation to a split source whose line, heading or file
        cannot be resolved lands in unmapped and the caller writes nothing.
    """
    entries = split_map_entries_from_manifest(manifest, repo_root, part_bodies, overrides)
    split_map = build_split_map(entries)
    overrides = overrides or {}
    result: Dict[str, Any] = {"unmapped": [], "rewrites": [], "remapped": 0, "untouched": 0}
    for rel in candidate_citation_files(repo_root):
        if rel in split_map["sources"] and rel not in overrides:
            continue
        if rel in overrides:
            text = overrides[rel]
        else:
            path = os.path.join(repo_root, rel)
            if not os.path.isfile(path):
                continue
            text = read_text(path)
        matches = list(CITATION_RE.finditer(text))
        if not matches:
            continue
        pieces: List[str] = []
        cursor = 0
        changed = False
        for match in matches:
            written = match.group("path")
            line = int(match.group("line")) if match.group("line") else None
            anchor = match.group("anchor")
            label = "%s:%d %s" % (rel, line_number_at(text, match.start()), match.group(0))
            resolved, base = resolve_citation(written, rel, repo_root, split_map)
            if resolved is None:
                if citation_is_missing_candidate(written, rel):
                    result["unmapped"].append("%s names a missing file" % label)
                else:
                    result["untouched"] += 1
                continue
            if resolved not in split_map["sources"]:
                result["untouched"] += 1
                continue
            info = split_map["sources"][resolved]
            if not write and info["kind"] == "general" and line is not None:
                # WHY: the guide keeps its entry file and renumbers the lines
                # below the moved block, so a check has to accept a citation
                # to a line the entry still holds. One past the last entry
                # line stays a problem.
                entry_absolute = os.path.join(repo_root, resolved)
                if os.path.isfile(entry_absolute):
                    entry_lines = len(line_spans(read_text(entry_absolute)))
                    if line <= entry_lines:
                        result["untouched"] += 1
                        continue
                    result["unmapped"].append(
                        "%s line %d is past the end of %s" % (label, line, resolved)
                    )
                    continue
            if line is not None:
                mapped = remap_source_line(split_map, resolved, line)
                if mapped is None:
                    result["unmapped"].append(
                        "%s line %d is past the end of %s" % (label, line, resolved)
                    )
                    continue
                target, new_line = mapped
                suffix = ":%d" % new_line
            elif anchor is not None:
                target = info["anchors"].get(anchor)
                if target is None:
                    result["unmapped"].append(
                        "%s anchor #%s matches no heading in %s" % (label, anchor, resolved)
                    )
                    continue
                suffix = "#" + anchor
            else:
                target = info["figures"]
                suffix = ""
            new_written = posix_relpath(target, base)
            if written.startswith("./") and not new_written.startswith(("./", "../")):
                new_written = "./" + new_written
            new_written += suffix
            if new_written == match.group(0):
                result["untouched"] += 1
                continue
            if write:
                pieces.append(text[cursor:match.start()])
                pieces.append(new_written)
                cursor = match.end()
                changed = True
                result["remapped"] += 1
            else:
                result["unmapped"].append(
                    "%s still points at the split source %s" % (label, resolved)
                )
        if write and changed:
            pieces.append(text[cursor:])
            result["rewrites"].append((rel, "".join(pieces)))
    return result

# ───────────────────────────────────────────────────────────────
# 8. TOKENS
# ───────────────────────────────────────────────────────────────

def load_o200k() -> Optional[Any]:
    """Load the cached o200k encoder when it is available.

    The run makes no network call. A cache directory that misses the encoding
    file makes this function return None instead of letting the library try a
    download.

    Returns:
        The encoder, or None when the cache or the library is unavailable.
    """
    cache = os.environ.get(CACHE_ENV, "")
    if not cache or not os.path.isdir(cache):
        return None
    cache_file = os.path.join(cache, hashlib.sha1(O200K_URL.encode()).hexdigest())
    if not os.path.isfile(cache_file):
        return None
    user_site = site.getusersitepackages()
    if user_site and os.path.isdir(user_site) and user_site not in sys.path:
        sys.path.append(user_site)
    try:
        import tiktoken
        return tiktoken.get_encoding(O200K_NAME)
    except Exception:
        return None


def token_count(encoder: Optional[Any], text: str) -> Optional[int]:
    """Count the o200k tokens of one text.

    Args:
        encoder: Result of load_o200k().
        text: Text to count.

    Returns:
        The token count, or None when the encoder is unavailable.
    """
    if encoder is None:
        return None
    return len(encoder.encode(text))


def token_text(encoder: Optional[Any], text: str) -> str:
    """Render the token part of a plan or check line.

    Args:
        encoder: Result of load_o200k().
        text: Text to count.

    Returns:
        " tokens N" when the encoder is available, otherwise an empty string.
    """
    count = token_count(encoder, text)
    if count is None:
        return ""
    return " tokens %d" % count

# ───────────────────────────────────────────────────────────────
# 9. PLAN MODE
# ───────────────────────────────────────────────────────────────

def plan_mode() -> int:
    """Print what a write would do and write nothing.

    Returns:
        Zero on success, 2 through fail() on a malformed source.
    """
    sources = year_sources()
    entry = read_text(ENTRY_PATH) if os.path.isfile(ENTRY_PATH) else ""
    general_planned = entry_has_general_headings(entry)
    if not sources and not general_planned:
        print("plan: nothing to split")
        return 0
    plans = [plan_year_source(path) for path in sources]
    general = plan_general_source(ENTRY_PATH) if general_planned else None
    encoder = load_o200k()
    general_parts = len(general["parts"]) if general is not None else 0
    print(
        "plan: %d topic files, %d parts, %d general parts"
        % (len(plans), sum(len(plan["parts"]) for plan in plans), general_parts)
    )
    for plan in plans:
        body_bytes = len(plan["body"].encode("utf-8"))
        print("source %s body %d bytes" % (plan["source"], body_bytes))
        for part in plan["parts"]:
            sections = ",".join(str(number) for number in part["sections"])
            print(
                "part %s sections %s body %d bytes file %d bytes%s"
                % (
                    part["path"],
                    sections,
                    len(part["body"].encode("utf-8")),
                    len(part["content"].encode("utf-8")),
                    token_text(encoder, part["content"]),
                )
            )
    if general is not None:
        print(
            "general %s region %d bytes parts %d entry file %d bytes%s"
            % (
                general["source"],
                len(general["body"].encode("utf-8")),
                len(general["parts"]),
                len(general["entry_text"].encode("utf-8")),
                token_text(encoder, general["entry_text"]),
            )
        )
        for part in general["parts"]:
            print(
                "general-part %s section %s body %d bytes file %d bytes%s"
                % (
                    part["path"],
                    part["section"],
                    len(part["body"].encode("utf-8")),
                    len(part["content"].encode("utf-8")),
                    token_text(encoder, part["content"]),
                )
            )
    print("plan: nothing written")
    return 0

# ───────────────────────────────────────────────────────────────
# 10. WRITE MODE
# ───────────────────────────────────────────────────────────────

def remove_source(path: str) -> None:
    """Remove one split original with git rm, or with an unlink as fallback.

    Args:
        path: Absolute path of the original.

    Raises:
        SystemExit: If the file survives both removals.
    """
    relative = repo_rel(path)
    result = subprocess.run(
        ["git", "rm", "-q", "--", relative],
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode == 0:
        return
    # WHY: a fixture tree holds no git repository, so the split still removes
    # the file and the suite can run on a plain copy.
    try:
        os.remove(path)
    except OSError as exc:
        fail("cannot remove %s: %s" % (relative, exc))


def assert_unique_parts(plans: List[Dict[str, Any]], general: Optional[Dict[str, Any]]) -> None:
    """Refuse a part path that two sources would write.

    Args:
        plans: Results of plan_year_source().
        general: Result of plan_general_source(), or None.

    Raises:
        SystemExit: If two sources map to the same part path.
    """
    seen: Dict[str, str] = {}
    groups = [(plan["source"], [part["path"] for part in plan["parts"]]) for plan in plans]
    if general is not None:
        groups.append((general["source"], [part["path"] for part in general["parts"]]))
    for source, paths in groups:
        for path in paths:
            if path in seen:
                fail("duplicate part path %s in %s and %s" % (path, seen[path], source))
            seen[path] = source


def write_year_parts(plan: Dict[str, Any]) -> None:
    """Write the four part files of one year topic.

    Args:
        plan: Result of plan_year_source().
    """
    for part in plan["parts"]:
        write_text(os.path.join(REPO_ROOT, part["path"]), part["content"])


def write_general_parts(plan: Dict[str, Any]) -> None:
    """Write the 13 general part files and the rewritten entry file.

    Args:
        plan: Result of plan_general_source().
    """
    for part in plan["parts"]:
        write_text(os.path.join(REPO_ROOT, part["path"]), part["content"])
    write_text(plan["absolute"], plan["entry_text"])


def prepare_plans(plans: List[Dict[str, Any]], general: Optional[Dict[str, Any]]) -> Dict[str, str]:
    """Rebase and normalize every planned part body and return its map.

    Args:
        plans: Results of plan_year_source().
        general: Result of plan_general_source(), or None.

    Returns:
        The part bodies keyed by path, which the remapper reads before the
        part files exist. Every part record gains the rebased body, the
        normalized body, its normalized hash and the final file content.
    """
    entries: List[Dict[str, Any]] = []
    for plan in plans:
        entries.append(
            {
                "source": plan["source"],
                "kind": "year",
                "parts": [
                    {
                        "path": part["path"],
                        "body": part["body"],
                        "source_start_line": part["start_line"],
                        "source_end_line": part["end_line"],
                        "line_offset": part["line_offset"],
                    }
                    for part in plan["parts"]
                ],
            }
        )
    if general is not None:
        entries.append(
            {
                "source": general["source"],
                "kind": "general",
                "figures": general["source"],
                "kept": general["entry_text"],
                "line_map": general["line_map"],
                "parts": [
                    {
                        "path": part["path"],
                        "body": part["body"],
                        "source_start_line": part["start_line"],
                        "source_end_line": part["end_line"],
                        "line_offset": part["line_offset"],
                    }
                    for part in general["parts"]
                ],
            }
        )
    split_map = build_split_map(entries)
    bodies: Dict[str, str] = {}
    for plan in plans:
        for part in plan["parts"]:
            rebased = rebase_body(part["body"], plan["source"], part["path"], split_map)
            part["rebased"] = rebased
            part["normalized"] = normalize_body(rebased, part["path"], plan["source"], split_map)
            part["body_sha256"] = sha256_text(part["normalized"])
            part["content"] = part["header"] + rebased
            bodies[part["path"]] = part["body"]
    if general is not None:
        for part in general["parts"]:
            rebased = rebase_body(part["body"], general["source"], part["path"], split_map)
            part["rebased"] = rebased
            part["normalized"] = normalize_body(rebased, part["path"], general["source"], split_map)
            part["body_sha256"] = sha256_text(part["normalized"])
            part["content"] = part["header"] + rebased
            bodies[part["path"]] = part["body"]
    return bodies


def write_mode() -> int:
    """Split every source, rewrite the entry file and write the manifest.

    Returns:
        Zero on success, 1 when the remapper reports a citation that it
        cannot map, 2 through fail() on a malformed source or a write error.
    """
    old = read_manifest(required=False)
    sources = year_sources()
    general = None
    entry = read_text(ENTRY_PATH) if os.path.isfile(ENTRY_PATH) else ""
    if entry_has_general_headings(entry):
        general = plan_general_source(ENTRY_PATH)
    plans = [plan_year_source(path) for path in sources]
    if not plans and general is None:
        if old is None:
            fail("no source to split and no %s" % repo_rel(MANIFEST_PATH))
        print("nothing to split: %s stands" % repo_rel(MANIFEST_PATH))
        return 0
    assert_unique_parts(plans, general)
    part_bodies = prepare_plans(plans, general)
    rows = [year_manifest_row(plan) for plan in plans]
    general_row = general_manifest_row(general) if general is not None else None
    manifest = merge_manifest(old, rows, general_row)
    overrides: Dict[str, str] = {}
    if general is not None:
        overrides[general["source"]] = general["entry_text"]
    citations = remap_citations(
        manifest, REPO_ROOT, write=True, part_bodies=part_bodies, overrides=overrides
    )
    if citations["unmapped"]:
        for line in citations["unmapped"]:
            print("unmapped citation %s" % line)
        print(
            "citations: 0 remapped, %d untouched, %d unmapped"
            % (citations["untouched"], len(citations["unmapped"]))
        )
        return 1
    for rel, text in citations["rewrites"]:
        if general is not None and rel == general["source"]:
            general["entry_text"] = text
    for plan in plans:
        write_year_parts(plan)
        remove_source(plan["absolute"])
        print("split %s -> 4 parts" % plan["source"])
    if general is not None:
        write_general_parts(general)
        print("split %s -> %d parts and rewrote the entry" % (general["source"], len(general["parts"])))
    for rel, text in citations["rewrites"]:
        if general is not None and rel == general["source"]:
            continue
        write_text(os.path.join(REPO_ROOT, rel), text)
    if general is not None:
        manifest["general"]["entry_sha256"] = entry_sha256(general["entry_text"])
    write_text(MANIFEST_PATH, render_manifest(manifest))
    print("citations: %d remapped, %d untouched" % (citations["remapped"], citations["untouched"]))
    print(
        "manifest %s rows %d general parts %d"
        % (repo_rel(MANIFEST_PATH), len(manifest["files"]), len(manifest["general"]["parts"]))
    )
    return 0

# ───────────────────────────────────────────────────────────────
# 11. CHECK MODE
# ───────────────────────────────────────────────────────────────

def check_year_row(
    row: Dict[str, Any], problems: List[str], split_map: Dict[str, Any]
) -> Tuple[bool, int]:
    """Check one year manifest row against its part files.

    Args:
        row: One manifest row.
        problems: Problem list that the check appends to.
        split_map: Result of build_split_map() for the normalization.

    Returns:
        A pair of the row verdict and the number of leftover originals that
        the row contributed.
    """
    source = row["source"]
    leftovers = 0
    if os.path.exists(os.path.join(REPO_ROOT, source)):
        problems.append("leftover original %s" % source)
        leftovers += 1
    parts = row["parts"]
    bodies: List[str] = []
    row_ok = True
    if len(parts) != 4:
        problems.append("manifest row %s holds %d parts" % (source, len(parts)))
        row_ok = False
    folder = os.path.dirname(parts[0]["path"]) if parts else os.path.dirname(source)
    present = 0
    for part in parts:
        path = os.path.join(REPO_ROOT, part["path"])
        if not os.path.isfile(path):
            problems.append("missing part %s" % part["path"])
            row_ok = False
            continue
        present += 1
        text = read_text(path)
        body = part_body(text)
        if body is None:
            problems.append("drift %s part %s (no body heading)" % (source, part["path"]))
            row_ok = False
            continue
        header = file_header_sha256(text)
        if header != part["header_sha256"]:
            problems.append("drift %s part %s (header hash %s)" % (source, part["path"], header))
            row_ok = False
        normalized = normalize_body(body, part["path"], source, split_map)
        digest = sha256_text(normalized)
        if digest != part["body_sha256"]:
            problems.append("drift %s part %s (body hash %s)" % (source, part["path"], digest))
            row_ok = False
            continue
        bodies.append(normalized)
    if present < 4:
        problems.append("short folder %s holds %d of 4 parts" % (folder, present))
    if row_ok and len(bodies) == len(parts):
        rejoin = sha256_text("".join(bodies))
        if rejoin != row["rejoin_sha256"] or rejoin != row["body_sha256"]:
            problems.append("drift %s rejoin hash %s" % (source, rejoin))
            row_ok = False
    return row_ok, leftovers


def check_general_row(
    general: Dict[str, Any],
    entry_text: str,
    entry_unsplit: bool,
    problems: List[str],
    split_map: Dict[str, Any],
) -> Tuple[bool, int]:
    """Check the general manifest record against its part files.

    Args:
        general: The general record from the manifest.
        entry_text: Current entry file text, empty when the file is missing.
        entry_unsplit: True when the entry file still holds its general H3
            subsections.
        problems: Problem list that the check appends to.
        split_map: Result of build_split_map() for the normalization.

    Returns:
        A pair of the record verdict and the number of leftover originals that
        the record contributed.
    """
    leftovers = 0
    source = general["source"]
    parts = general.get("parts", [])
    bodies: List[str] = []
    row_ok = True
    if len(parts) != 13:
        problems.append("manifest general record holds %d parts" % len(parts))
        row_ok = False
    present = 0
    for part in parts:
        path = os.path.join(REPO_ROOT, part["path"])
        if not os.path.isfile(path):
            problems.append("missing general part %s" % part["path"])
            row_ok = False
            continue
        present += 1
        text = read_text(path)
        body = part_body(text)
        if body is None:
            problems.append("drift %s part %s (no body heading)" % (source, part["path"]))
            row_ok = False
            continue
        header = file_header_sha256(text)
        if header != part["header_sha256"]:
            problems.append("drift %s part %s (header hash %s)" % (source, part["path"], header))
            row_ok = False
        normalized = normalize_body(body, part["path"], source, split_map)
        digest = sha256_text(normalized)
        if digest != part["body_sha256"]:
            problems.append("drift %s part %s (body hash %s)" % (source, part["path"], digest))
            row_ok = False
            continue
        bodies.append(normalized)
    if present < 13:
        problems.append("short folder %s holds %d of 13 parts" % (repo_rel(GENERAL_DIR), present))
    if row_ok and len(bodies) == len(parts):
        rejoin = sha256_text("".join(bodies))
        if rejoin != general["rejoin_sha256"] or rejoin != general["body_sha256"]:
            problems.append("drift %s rejoin hash %s" % (source, rejoin))
            row_ok = False
    if entry_unsplit:
        problems.append("leftover original %s (section 3 still holds its subsections)" % source)
        leftovers += 1
    elif entry_text:
        digest = entry_sha256(entry_text)
        if digest != general["entry_sha256"]:
            problems.append("drift %s entry (entry hash %s)" % (source, digest))
            row_ok = False
        for part in parts:
            slug = os.path.basename(part["path"])[: -len(".md")]
            if "general/%s.md" % slug not in entry_text:
                problems.append("entry pointer missing %s" % part["path"])
                row_ok = False
    return row_ok, leftovers


def check_mode() -> int:
    """Recompute the rejoin from the part files and report every problem.

    Returns:
        Zero when every hash matches, 1 on a drift, a leftover original, a
        short folder, an over-limit part or an unmapped citation, and 2
        through fail() on a missing or malformed manifest.
    """
    sources = year_sources()
    entry_text = read_text(ENTRY_PATH) if os.path.isfile(ENTRY_PATH) else ""
    entry_unsplit = entry_has_general_headings(entry_text)
    manifest = read_manifest(required=False)
    problems: List[str] = []
    if not os.path.isfile(ENTRY_PATH):
        problems.append("missing entry %s" % repo_rel(ENTRY_PATH))
    if manifest is None:
        for path in sources:
            problems.append("unsplit %s" % repo_rel(path))
        if entry_unsplit:
            problems.append("unsplit %s" % repo_rel(ENTRY_PATH))
        if not problems:
            fail("missing manifest %s" % repo_rel(MANIFEST_PATH))
        for line in problems:
            print(line)
        print("missing manifest %s" % repo_rel(MANIFEST_PATH))
        print("leftovers: %d" % len(problems))
        print("unmapped citations: 0")
        print("split-check: %d problems" % len(problems))
        return 1
    leftovers = 0
    known = {row["source"] for row in manifest["files"]}
    for path in sources:
        if repo_rel(path) not in known:
            problems.append("unsplit %s" % repo_rel(path))
            leftovers += 1
    part_bodies: Dict[str, str] = {}
    for row in manifest["files"]:
        for part in row["parts"]:
            path = os.path.join(REPO_ROOT, part["path"])
            if os.path.isfile(path):
                body = part_body(read_text(path))
                if body is not None:
                    part_bodies[part["path"]] = body
    general = manifest.get("general")
    if isinstance(general, dict):
        for part in general["parts"]:
            path = os.path.join(REPO_ROOT, part["path"])
            if os.path.isfile(path):
                body = part_body(read_text(path))
                if body is not None:
                    part_bodies[part["path"]] = body
    split_map = build_split_map(split_map_entries_from_manifest(manifest, REPO_ROOT, part_bodies))
    ok_lines: List[str] = []
    for row in manifest["files"]:
        row_ok, row_leftovers = check_year_row(row, problems, split_map)
        leftovers += row_leftovers
        if row_ok:
            ok_lines.append("rejoin ok %s (%d parts)" % (row["source"], len(row["parts"])))
    general = manifest.get("general")
    if isinstance(general, dict):
        row_ok, row_leftovers = check_general_row(general, entry_text, entry_unsplit, problems, split_map)
        leftovers += row_leftovers
        if row_ok:
            ok_lines.append("rejoin ok %s (%d general parts)" % (general["source"], len(general["parts"])))
    elif entry_unsplit:
        problems.append("unsplit %s" % repo_rel(ENTRY_PATH))
        leftovers += 1
    encoder = load_o200k()
    if encoder is not None:
        largest_path = ""
        largest = 0
        for row in manifest["files"]:
            for part in row["parts"]:
                path = os.path.join(REPO_ROOT, part["path"])
                if not os.path.isfile(path):
                    continue
                count = token_count(encoder, read_text(path))
                if count > largest:
                    largest = count
                    largest_path = part["path"]
                if count > PART_TOKEN_LIMIT:
                    problems.append("over token line %s %d of %d" % (part["path"], count, PART_TOKEN_LIMIT))
        if isinstance(general, dict):
            for part in general["parts"]:
                path = os.path.join(REPO_ROOT, part["path"])
                if not os.path.isfile(path):
                    continue
                count = token_count(encoder, read_text(path))
                if count > largest:
                    largest = count
                    largest_path = part["path"]
                if count > PART_TOKEN_LIMIT:
                    problems.append("over token line %s %d of %d" % (part["path"], count, PART_TOKEN_LIMIT))
        print("tokens: largest %s %d of %d" % (largest_path, largest, PART_TOKEN_LIMIT))
    problems = sorted(problems)
    for line in problems:
        print(line)
    for line in ok_lines:
        print(line)
    citations = remap_citations(manifest, REPO_ROOT, write=False, part_bodies=part_bodies)
    for line in citations["unmapped"]:
        print("unmapped citation %s" % line)
    print("leftovers: %d" % leftovers)
    print("unmapped citations: %d" % len(citations["unmapped"]))
    print("citations: %d remapped, %d untouched" % (citations["remapped"], citations["untouched"]))
    total = len(problems) + len(citations["unmapped"])
    if total:
        print("split-check: %d problems" % total)
        return 1
    print("split-check: ok")
    return 0

# ───────────────────────────────────────────────────────────────
# 12. ACCEPT RENAMES MODE
# ───────────────────────────────────────────────────────────────

def read_rename_map(path: str) -> Dict[str, str]:
    """Read the rename map of one accept run.

    Args:
        path: Map file path.

    Returns:
        The old to new repository path map.

    Raises:
        SystemExit: If the file is missing, holds invalid JSON, is not a JSON
            object or holds a malformed entry.
    """
    if not os.path.isfile(path):
        fail("missing rename map %s" % path)
    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        fail("cannot parse rename map %s: %s" % (path, exc))
    if not isinstance(data, dict):
        fail("rename map %s must hold a JSON object" % path)
    mapping: Dict[str, str] = {}
    for key, value in data.items():
        if not isinstance(key, str) or not isinstance(value, str):
            fail("rename map %s holds a non-string path" % path)
        if not key or not value or key.startswith("/") or value.startswith("/"):
            fail("rename map %s holds a malformed path" % path)
        if key.endswith("/") != value.endswith("/"):
            fail("rename map %s pairs a path with another kind of path" % path)
        mapping[key] = value
    return mapping


BARE_NAME_STOP = frozenset(" \t\n\"'`()[]<>,|")


def map_repo_path(path: str, mapping: Dict[str, str]) -> str:
    """Map one repository path through a rename map.

    An exact key wins. A folder key that ends in a slash maps the part of
    the path below it, and the longest matching folder key wins.

    Args:
        path: Repository path.
        mapping: Result of read_rename_map().

    Returns:
        The mapped path, or the path as written when no key matches.
    """
    if path in mapping:
        return mapping[path]
    folder = ""
    for key in mapping:
        if not key.endswith("/") or not path.startswith(key):
            continue
        if len(key) > len(folder):
            folder = key
    if not folder:
        return path
    return mapping[folder] + path[len(folder):]


def rewrite_repo_paths(text: str, mapping: Dict[str, str]) -> str:
    """Rewrite every repository path in one text through a rename map.

    Exact path keys run first, longest first. A folder key that ends in a
    slash runs after them. An exact key only matches when the next character
    is not a path character, so a longer name that starts with the key is
    left alone.

    Args:
        text: Text that holds repository paths.
        mapping: Result of read_rename_map().

    Returns:
        The text with every matched path replaced.
    """
    out = text
    exact = sorted((key for key in mapping if not key.endswith("/")), key=len, reverse=True)
    for key in exact:
        pattern = re.escape(key) + r"(?![A-Za-z0-9._-])"
        out = re.sub(pattern, lambda match, value=mapping[key]: value, out)
    folder = sorted((key for key in mapping if key.endswith("/")), key=len, reverse=True)
    for key in folder:
        out = out.replace(key, mapping[key])
    return rewrite_bare_names(out, mapping)


def rename_name_pairs(mapping: Dict[str, str]) -> Tuple[Dict[str, str], Dict[str, str]]:
    """Derive the folder and file name renames a rename map implies.

    Each key and value are compared segment by segment. A differing folder
    segment becomes a folder pair and a differing last segment becomes a file
    pair, so prose that names a folder or a file without its full path can be
    mapped the same way the rename rewrote it.

    Args:
        mapping: Result of read_rename_map().

    Returns:
        The folder name pairs and the file name pairs, old to new.
    """
    folders: Dict[str, str] = {}
    files: Dict[str, str] = {}
    for key, value in mapping.items():
        old_parts = key.rstrip("/").split("/")
        new_parts = value.rstrip("/").split("/")
        if len(old_parts) != len(new_parts):
            continue
        last = len(old_parts) - 1
        for index, (old, new) in enumerate(zip(old_parts, new_parts)):
            if old == new:
                continue
            if index == last and not key.endswith("/"):
                files[old] = new
            else:
                folders[old] = new
    return folders, files


def rewrite_bare_names(text: str, mapping: Dict[str, str]) -> str:
    """Rewrite folder and file names that appear without their full path.

    A folder name is rewritten as a path segment before a slash, or as the
    stem of a pre-split file name such as the old year file. A file name is
    rewritten where it stands alone. A token that holds a URL is never
    touched, because source URLs keep their own words.

    Args:
        text: Text whose repository paths were already rewritten.
        mapping: Result of read_rename_map().

    Returns:
        The text with every bare name replaced.
    """
    folders, files = rename_name_pairs(mapping)
    if not folders and not files:
        return text
    names = sorted(folders, key=len, reverse=True)
    alt = "|".join(re.escape(name) for name in names)
    patterns = []
    if alt:
        patterns.append((re.compile(r"(?<![A-Za-z0-9_.-])(" + alt + r")(?=/|\.md\b)"), folders))
    file_alt = "|".join(re.escape(name) for name in sorted(files, key=len, reverse=True))
    if file_alt:
        patterns.append((re.compile(r"(?<![A-Za-z0-9_.-])(" + file_alt + r")(?![A-Za-z0-9_.-])"), files))
    for pattern, pairs in patterns:

        def replace(match: re.Match, pairs: Dict[str, str] = pairs) -> str:
            left = match.start()
            while left > 0 and match.string[left - 1] not in BARE_NAME_STOP:
                left -= 1
            right = match.end()
            while right < len(match.string) and match.string[right] not in BARE_NAME_STOP:
                right += 1
            word = match.string[left:right]
            if "://" in word or "www." in word:
                return match.group(0)
            return pairs[match.group(1)]

        text = pattern.sub(replace, text)
    return text


def canonicalize_link_labels(text: str, part_rel: str) -> str:
    """Replace a link label with its target when the label names that target.

    A derived header names each sibling file in both the label and the target
    of one link. A rename changes both, so the label has to resolve to the
    same repository path as the target before the two sides can compare.

    Args:
        text: Text with every link target already replaced by a repository
            path.
        part_rel: Repository path of the file that holds the text.

    Returns:
        The text with every label that names its own target replaced by that
        target.
    """

    def replacement(match: re.Match) -> str:
        label = match.group(1).strip()
        target = match.group(2)
        if not label or " " in label or "\t" in label or SCHEME_RE.match(label):
            return match.group(0)
        path_part = target.partition("#")[0]
        if not path_part:
            return match.group(0)
        if label == path_part:
            return "[" + target + "](" + target + ")"
        for base in (posixpath.dirname(path_part), posixpath.dirname(part_rel)):
            if posixpath.normpath(posixpath.join(base, label)) == path_part:
                return "[" + target + "](" + target + ")"
        return match.group(0)

    return LABEL_LINK_RE.sub(replacement, text)


def rename_body_identity(
    text: str,
    part_rel: str,
    source_rel: str,
    split_map: Dict[str, Any],
    mapping: Dict[str, str],
) -> str:
    """Return the rename identity of one part body.

    Args:
        text: Body text.
        part_rel: Repository path of the part file in the text's own tree.
        source_rel: Repository path of the split source in the same tree.
        split_map: Result of build_split_map() for the same tree.
        mapping: Result of read_rename_map().

    Returns:
        The normalized body with every label that names its target replaced,
        then with every repository path rewritten through the map.
    """
    normalized = normalize_body(text, part_rel, source_rel, split_map)
    labeled = canonicalize_link_labels(normalized, part_rel)
    return rewrite_repo_paths(labeled, mapping)


def rename_header_identity(
    text: str,
    part_rel: str,
    split_map: Dict[str, Any],
    mapping: Dict[str, str],
) -> str:
    """Return the rename identity of one derived header or the entry file.

    Args:
        text: Header text, or the whole entry file text.
        part_rel: Repository path of the file that holds the text.
        split_map: Result of build_split_map() for the same tree.
        mapping: Result of read_rename_map().

    Returns:
        The bytes the header hash covers, with every target and every label
        that names its target canonicalized, then with every repository path
        rewritten through the map.
    """
    normalized = canonicalize_targets(header_hash_text(text), part_rel, part_rel, split_map)
    labeled = canonicalize_link_labels(normalized, part_rel)
    return rewrite_repo_paths(labeled, mapping)


def git_show_text(ref: str, path: str) -> str:
    """Read one repository path from a git revision.

    Args:
        ref: Git revision.
        path: Repository path.

    Returns:
        The file text.

    Raises:
        SystemExit: If git cannot read the path at the revision or the bytes
            are not UTF-8.
    """
    result = subprocess.run(
        ["git", "show", "%s:%s" % (ref, path)],
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        fail("cannot read %s at %s" % (path, ref))
    try:
        return result.stdout.decode("utf-8")
    except UnicodeDecodeError as exc:
        fail("cannot decode %s at %s as UTF-8: %s" % (path, ref, exc))


def first_differing_line(old: str, new: str) -> Optional[Tuple[int, str, str]]:
    """Find the first line that differs between two texts.

    Args:
        old: Old text.
        new: New text.

    Returns:
        A triple of the one based line number, the old line and the new
        line, or None when the two texts are equal.
    """
    old_lines = old.splitlines()
    new_lines = new.splitlines()
    for index in range(max(len(old_lines), len(new_lines))):
        old_line = old_lines[index] if index < len(old_lines) else ""
        new_line = new_lines[index] if index < len(new_lines) else ""
        if old_line != new_line:
            return index + 1, old_line, new_line
    return None


def refuse_line(new_path: str, section: str, old: str, new: str) -> None:
    """Print one refused part with its first differing line.

    Args:
        new_path: Repository path of the part in the new tree.
        section: "body" or "header".
        old: Old identity text.
        new: New identity text.
    """
    difference = first_differing_line(old, new)
    if difference is None:
        print("refused %s %s" % (new_path, section))
        return
    number, old_line, new_line = difference
    print("refused %s %s line %d" % (new_path, section, number))
    print("  old %s" % old_line)
    print("  new %s" % new_line)


def accept_part(
    old_text: str,
    new_text: str,
    old_path: str,
    new_path: str,
    old_source: str,
    new_source: str,
    old_split_map: Dict[str, Any],
    new_split_map: Dict[str, Any],
    mapping: Dict[str, str],
) -> Tuple[bool, str, str]:
    """Compare one part body and header for a pure rename.

    Args:
        old_text: File text at the old path in the base revision.
        new_text: File text at the new path in the working tree.
        old_path: Repository path of the part in the base revision.
        new_path: Repository path of the part in the working tree.
        old_source: Repository path of the split source in the base revision.
        new_source: Repository path of the split source in the new tree.
        old_split_map: Result of build_split_map() for the base revision.
        new_split_map: Result of build_split_map() for the working tree.
        mapping: Result of read_rename_map().

    Returns:
        A triple of the verdict, the new normalized body and the new header
        digest. The verdict is False and the two hashes are empty when the
        part differs beyond its paths or holds no body heading.
    """
    old_body = part_body(old_text)
    new_body = part_body(new_text)
    old_start = body_start(old_text)
    new_start = body_start(new_text)
    if old_body is None or new_body is None or old_start is None or new_start is None:
        print("refused %s (no body heading)" % new_path)
        return False, "", ""
    old_identity = rename_body_identity(old_body, old_path, old_source, old_split_map, mapping)
    new_identity = rename_body_identity(new_body, new_path, new_source, new_split_map, {})
    verdict = True
    if old_identity != new_identity:
        refuse_line(new_path, "body", old_identity, new_identity)
        verdict = False
    old_header = rename_header_identity(old_text[:old_start], old_path, old_split_map, mapping)
    new_header = rename_header_identity(new_text[:new_start], new_path, new_split_map, {})
    if old_header != new_header:
        refuse_line(new_path, "header", old_header, new_header)
        verdict = False
    normalized = normalize_body(new_body, new_path, new_source, new_split_map)
    return verdict, normalized, header_sha256(new_text[:new_start])


def map_line_map(line_map: List[Any], mapping: Dict[str, str]) -> List[Any]:
    """Map the part path of every line map run through a rename map.

    Args:
        line_map: The line map runs of one manifest row.
        mapping: Result of read_rename_map().

    Returns:
        A copy of the runs with each part path mapped.
    """
    runs: List[Any] = []
    for run in line_map:
        if isinstance(run, dict) and isinstance(run.get("part"), str):
            runs.append(dict(run, part=map_repo_path(run["part"], mapping)))
        else:
            runs.append(run)
    return runs


def changed_line_count(old_text: str, new_text: str) -> int:
    """Count the lines that differ between two texts.

    The count compares the two texts line by line at the same position and
    adds the length difference, so an inserted line counts once and a moved
    block counts its changed positions. It is a review aid, never a diff.

    Args:
        old_text: File text at the base revision.
        new_text: File text in the working tree.

    Returns:
        The number of changed lines.
    """
    old_lines = old_text.split("\n")
    new_lines = new_text.split("\n")
    common = min(len(old_lines), len(new_lines))
    return sum(1 for index in range(common) if old_lines[index] != new_lines[index]) + abs(
        len(old_lines) - len(new_lines)
    )


def accept_edits_mode(base_ref: str) -> int:
    """Record the new hashes of a reviewed content edit.

    A part whose text still matches the base revision keeps its stored hashes
    byte for byte. A part whose text changed is re-normalized against the
    current tree, its new body and header hashes are recorded and the part is
    printed with the number of changed lines. A row with a changed part gets
    its rejoin hashes recomputed, and the general record is handled the same
    way, including its entry hash. The manifest is written once, so a refused
    read leaves every byte as it was.

    Args:
        base_ref: Git revision that still holds the pre-edit files.

    Returns:
        Zero when the manifest was written, and 2 through fail() on a missing
        or malformed manifest, an unreadable base revision or a part file
        without a body heading.
    """
    manifest = read_manifest(required=True)
    old_general = manifest.get("general")
    new_manifest: Dict[str, Any] = {
        "generated_by": manifest.get("generated_by", GENERATOR),
        "version": manifest.get("version", MANIFEST_VERSION),
        "files": [],
    }
    part_bodies: Dict[str, str] = {}
    for row in manifest["files"]:
        for part in row["parts"]:
            path = os.path.join(REPO_ROOT, part["path"])
            if os.path.isfile(path):
                body = part_body(read_text(path))
                if body is not None:
                    part_bodies[part["path"]] = body
    if isinstance(old_general, dict):
        for part in old_general["parts"]:
            path = os.path.join(REPO_ROOT, part["path"])
            if os.path.isfile(path):
                body = part_body(read_text(path))
                if body is not None:
                    part_bodies[part["path"]] = body
    split_map = build_split_map(split_map_entries_from_manifest(manifest, REPO_ROOT, part_bodies))
    recorded = 0
    unchanged = 0
    for row in manifest["files"]:
        new_row = dict(row)
        new_parts: List[Dict[str, Any]] = []
        rejoin_parts: List[str] = []
        row_changed = False
        for part in row["parts"]:
            path = part["path"]
            old_text = git_show_text(base_ref, path)
            absolute = os.path.join(REPO_ROOT, path)
            if not os.path.isfile(absolute):
                fail("missing part %s" % path)
            new_text = read_text(absolute)
            body = part_body(new_text)
            header = file_header_sha256(new_text)
            if body is None or header is None:
                fail("part %s holds no body heading" % path)
            normalized = normalize_body(body, path, row["source"], split_map)
            digest = sha256_text(normalized)
            new_part = dict(part)
            if old_text != new_text or digest != part["body_sha256"] or header != part["header_sha256"]:
                print("split-edit %s %d changed lines" % (path, changed_line_count(old_text, new_text)))
                new_part["body_sha256"] = digest
                new_part["header_sha256"] = header
                recorded += 1
                row_changed = True
            else:
                unchanged += 1
            new_parts.append(new_part)
            rejoin_parts.append(normalized)
        new_row["parts"] = new_parts
        if row_changed:
            rejoin = sha256_text("".join(rejoin_parts))
            new_row["body_sha256"] = rejoin
            new_row["rejoin_sha256"] = rejoin
        new_manifest["files"].append(new_row)
    if isinstance(old_general, dict):
        new_general = dict(old_general)
        new_parts = []
        rejoin_parts = []
        record_changed = False
        for part in old_general["parts"]:
            path = part["path"]
            old_text = git_show_text(base_ref, path)
            absolute = os.path.join(REPO_ROOT, path)
            if not os.path.isfile(absolute):
                fail("missing general part %s" % path)
            new_text = read_text(absolute)
            body = part_body(new_text)
            header = file_header_sha256(new_text)
            if body is None or header is None:
                fail("general part %s holds no body heading" % path)
            normalized = normalize_body(body, path, old_general["source"], split_map)
            digest = sha256_text(normalized)
            new_part = dict(part)
            if old_text != new_text or digest != part["body_sha256"] or header != part["header_sha256"]:
                print("split-edit %s %d changed lines" % (path, changed_line_count(old_text, new_text)))
                new_part["body_sha256"] = digest
                new_part["header_sha256"] = header
                recorded += 1
                record_changed = True
            else:
                unchanged += 1
            new_parts.append(new_part)
            rejoin_parts.append(normalized)
        new_general["parts"] = new_parts
        entry = old_general["source"]
        entry_old = git_show_text(base_ref, entry)
        if not os.path.isfile(os.path.join(REPO_ROOT, entry)):
            fail("missing entry %s" % entry)
        entry_new = read_text(os.path.join(REPO_ROOT, entry))
        if record_changed:
            rejoin = sha256_text("".join(rejoin_parts))
            new_general["body_sha256"] = rejoin
            new_general["rejoin_sha256"] = rejoin
        if entry_old != entry_new or entry_sha256(entry_new) != old_general.get("entry_sha256"):
            print("split-edit %s %d changed lines" % (entry, changed_line_count(entry_old, entry_new)))
            new_general["entry_sha256"] = entry_sha256(entry_new)
            recorded += 1
        new_manifest["general"] = new_general
    write_text(MANIFEST_PATH, render_manifest(new_manifest))
    print("split-accept-edits: %d parts recorded, %d unchanged" % (recorded, unchanged))
    return 0


def accept_renames_mode(map_path: str, base_ref: str) -> int:
    """Record the new hashes of a pure rename.

    Args:
        map_path: Rename map file, a JSON object of old to new repository
            paths.
        base_ref: Git revision that still holds the old files.

    Returns:
        Zero when every part is accepted, 1 when a part is refused, and 2
        through fail() on a malformed map, an unreadable old file, an
        unknown revision or a map key that names nothing in the manifest.
    """
    mapping = read_rename_map(map_path)
    old_manifest = read_manifest(required=True)
    old_general = old_manifest.get("general")
    manifest_paths: List[str] = []
    for row in old_manifest["files"]:
        manifest_paths.append(row["source"])
        for part in row["parts"]:
            manifest_paths.append(part["path"])
    if isinstance(old_general, dict):
        manifest_paths.append(old_general["source"])
        for part in old_general["parts"]:
            manifest_paths.append(part["path"])
    for key in sorted(mapping):
        covered = any(
            path == key or (key.endswith("/") and path.startswith(key))
            for path in manifest_paths
        )
        if not covered:
            fail("rename map key %s names nothing in %s" % (key, repo_rel(MANIFEST_PATH)))
    content_paths: List[str] = []
    new_manifest: Dict[str, Any] = {
        "generated_by": old_manifest.get("generated_by", GENERATOR),
        "version": old_manifest.get("version", MANIFEST_VERSION),
        "files": [],
    }
    for row in old_manifest["files"]:
        new_row = dict(row)
        new_row["source"] = map_repo_path(row["source"], mapping)
        new_row["parts"] = [
            dict(part, path=map_repo_path(part["path"], mapping)) for part in row["parts"]
        ]
        if isinstance(row.get("line_map"), list):
            new_row["line_map"] = map_line_map(row["line_map"], mapping)
        new_manifest["files"].append(new_row)
        for part in row["parts"]:
            content_paths.append(part["path"])
    new_general: Optional[Dict[str, Any]] = None
    if isinstance(old_general, dict):
        new_general = dict(old_general)
        new_general["source"] = map_repo_path(old_general["source"], mapping)
        new_general["parts"] = [
            dict(part, path=map_repo_path(part["path"], mapping)) for part in old_general["parts"]
        ]
        if isinstance(old_general.get("line_map"), list):
            new_general["line_map"] = map_line_map(old_general["line_map"], mapping)
        new_manifest["general"] = new_general
        for part in old_general["parts"]:
            content_paths.append(part["path"])
        content_paths.append(old_general["source"])
    old_texts: Dict[str, str] = {}
    new_texts: Dict[str, str] = {}
    for path in content_paths:
        old_texts[path] = git_show_text(base_ref, path)
        new_path = map_repo_path(path, mapping)
        new_texts[new_path] = read_text(os.path.join(REPO_ROOT, new_path))
    old_bodies: Dict[str, str] = {}
    new_bodies: Dict[str, str] = {}
    for path in content_paths:
        old_body = part_body(old_texts[path])
        if old_body is not None:
            old_bodies[path] = old_body
        new_path = map_repo_path(path, mapping)
        new_body = part_body(new_texts[new_path])
        if new_body is not None:
            new_bodies[new_path] = new_body
    old_overrides: Dict[str, str] = {}
    new_overrides: Dict[str, str] = {}
    if isinstance(old_general, dict) and isinstance(new_general, dict):
        old_overrides[old_general["source"]] = old_texts[old_general["source"]]
        new_overrides[new_general["source"]] = new_texts[new_general["source"]]
    old_entries = split_map_entries_from_manifest(
        old_manifest, REPO_ROOT, part_bodies=old_bodies, overrides=old_overrides
    )
    old_split_map = build_split_map(old_entries)
    new_entries = split_map_entries_from_manifest(
        new_manifest, REPO_ROOT, part_bodies=new_bodies, overrides=new_overrides
    )
    new_split_map = build_split_map(new_entries)
    refused = False
    renamed = 0
    unchanged = 0
    for old_row, new_row in zip(old_manifest["files"], new_manifest["files"]):
        rejoin_parts: List[str] = []
        for old_part, new_part in zip(old_row["parts"], new_row["parts"]):
            old_path = old_part["path"]
            new_path = new_part["path"]
            verdict, normalized, header = accept_part(
                old_texts[old_path],
                new_texts[new_path],
                old_path,
                new_path,
                old_row["source"],
                new_row["source"],
                old_split_map,
                new_split_map,
                mapping,
            )
            if not verdict:
                refused = True
                continue
            new_part["body_sha256"] = sha256_text(normalized)
            new_part["header_sha256"] = header
            rejoin_parts.append(normalized)
            if new_path == old_path:
                unchanged += 1
            else:
                renamed += 1
        if len(rejoin_parts) == len(new_row["parts"]):
            rejoin = sha256_text("".join(rejoin_parts))
            new_row["body_sha256"] = rejoin
            new_row["rejoin_sha256"] = rejoin
    if isinstance(old_general, dict) and isinstance(new_general, dict):
        general_parts: List[str] = []
        for old_part, new_part in zip(old_general["parts"], new_general["parts"]):
            old_path = old_part["path"]
            new_path = new_part["path"]
            verdict, normalized, header = accept_part(
                old_texts[old_path],
                new_texts[new_path],
                old_path,
                new_path,
                old_general["source"],
                new_general["source"],
                old_split_map,
                new_split_map,
                mapping,
            )
            if not verdict:
                refused = True
                continue
            new_part["body_sha256"] = sha256_text(normalized)
            new_part["header_sha256"] = header
            general_parts.append(normalized)
            if new_path == old_path:
                unchanged += 1
            else:
                renamed += 1
        if len(general_parts) == len(new_general["parts"]):
            rejoin = sha256_text("".join(general_parts))
            new_general["body_sha256"] = rejoin
            new_general["rejoin_sha256"] = rejoin
        entry_old = old_general["source"]
        entry_new = new_general["source"]
        old_identity = rename_header_identity(
            old_texts[entry_old], entry_old, old_split_map, mapping
        )
        new_identity = rename_header_identity(
            new_texts[entry_new], entry_new, new_split_map, {}
        )
        if old_identity != new_identity:
            refuse_line(entry_new, "entry", old_identity, new_identity)
            refused = True
        new_general["entry_sha256"] = entry_sha256(new_texts[entry_new])
    if refused:
        return 1
    write_text(MANIFEST_PATH, render_manifest(new_manifest))
    print("split-accept: %d parts renamed, %d unchanged" % (renamed, unchanged))
    return 0

# ───────────────────────────────────────────────────────────────
# 13. MAIN
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
        description="Split the tax-rules topic files into four part files, check the rejoin or accept a pure rename.",
    )
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--plan", action="store_true", help="print the split plan and write nothing")
    modes.add_argument("--write", action="store_true", help="split the sources, remove the originals and write the manifest")
    modes.add_argument("--check", action="store_true", help="recompute the rejoin and report every drift")
    modes.add_argument(
        "--accept-renames",
        metavar="MAP",
        help="accept a pure rename from the map in MAP and record its new hashes",
    )
    modes.add_argument(
        "--accept-edits",
        action="store_true",
        help="record the new hashes of the parts and the entry file that changed since the base revision",
    )
    parser.add_argument(
        "--base",
        metavar="REF",
        help="git revision that still holds the old files, required with --accept-renames and --accept-edits",
    )
    args = parser.parse_args(argv)
    if not os.path.isdir(TAX_RULES_ROOT):
        fail("missing folder %s" % repo_rel(TAX_RULES_ROOT))
    if args.accept_renames is not None:
        if not args.base:
            parser.error("--accept-renames requires --base REF")
        return accept_renames_mode(args.accept_renames, args.base)
    if args.accept_edits:
        if not args.base:
            parser.error("--accept-edits requires --base REF")
        return accept_edits_mode(args.base)
    if args.base:
        parser.error("--base requires --accept-renames MAP or --accept-edits")
    if args.write:
        return write_mode()
    if args.check:
        return check_mode()
    return plan_mode()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
