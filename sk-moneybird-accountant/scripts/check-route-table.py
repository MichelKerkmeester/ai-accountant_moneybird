#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE CHECKER
# ───────────────────────────────────────────────────────────────
"""Check the task-type route table in the skill's router.

Reads the ROUTER.md beside the skill's SKILL.md and verifies the route-table
block between its markers. The check validates the header, the row types, the
Dutch and English cells, the budget cells, the tool routes, the read-set
grammar, the read-set paths and their guard, the glossary read rule with a
glossary file for every topic, the route margin, the read budget ladder
against the signal sources file and the file line of token-baseline.py, the
T7, T8 and T9 row rules the resolver depends on, the abstain wording, the
pointer to the signal sources file, the source lines of that file and the
documented-gap ledger of that file. Each read item carries a `!` or
`?` mark, an optional `@section-id` anchor and the `{year}` token, and the map
tokens `{phase-file}` and `{topic-figures}` expand over the phase table of the
migration index and the topic figures files. It also compares the generated
router block between the router markers with the table row by row, including
the required and conditional reads, the section targets, the phase map, the
topic map and the table's multi-word signals and curated advisor signals with
graph-metadata.json, and the write mode regenerates both surfaces. It checks
the hub as well: the root SKILL.md, mode-registry.json and hub-router.json
exist, every registry packet has a SKILL.md whose name is its packetSkillName,
the packetKind of its role and an active ROUTER.md that points back to it and
ends with its machine router section, stage one names one default packet and
no packet SKILL.md embeds a router again. The hub's packet links are read from
the root SKILL.md and from the root ROUTER.md it links, when one exists. The script uses the Python standard library only and makes no network
call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --write

Options:
    --write  Regenerate the router block in ROUTER.md and append the table's
             multi-word signals to graph-metadata.json. Without it the script
             runs the check.

Output:
    One line per problem, or "route-table: ok" when the file passes. The write
    mode prints one line per generated surface. Exit 0 on success, 1 when the
    file has problems and 2 when a write is refused.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, NoReturn, Optional, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

CHECKER = "sk-moneybird-accountant/scripts/check-route-table.py"
SKILL_FOLDER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(SKILL_FOLDER)
ROUTER_MD = os.path.join(SKILL_FOLDER, "ROUTER.md")
# WHY: the hub owns stage one in these files and each packet owns stage two in its own ROUTER.md.
HUB_FILES = ("SKILL.md", "mode-registry.json", "hub-router.json")
# WHY: a packet SKILL.md that carries one of these again has a second router beside ROUTER.md.
EMBEDDED_ROUTER_MARKS = (
    "<!-- route-table:start -->",
    "<!-- router-block:start -->",
    "INTENT_MODEL",
    "INTENT_SIGNALS",
    "RESOURCE_MAP",
)
# WHY: a router emptied to its frontmatter still passes the header check, so
# its body must keep the routing section, an intent model and a resource map.
# The routing section is the older "## 2. SMART ROUTING" or, in the skilled
# router shape, a "## 3. MACHINE ROUTER" that is the router's last H2, so the
# generated block and the tables it is checked against stay in that section.
ROUTER_SECTION = "## 2. SMART ROUTING"
MACHINE_ROUTER_SECTION = "## 3. MACHINE ROUTER"
# WHY: a packet SKILL.md reaches its router only through a relative link.
PACKET_POINTERS = ("](ROUTER.md)", "](./ROUTER.md)")
ROUTER_INTENT_MARKS = ("INTENT_MODEL", "INTENT_SIGNALS")
ROUTER_STATE_LINE = "router_state: active"
SKILL_POINTER_LINE = "skill_pointer: SKILL.md"

GRAPH_METADATA = os.path.join(SKILL_FOLDER, "graph-metadata.json")

START_MARKER = "<!-- route-table:start -->"
END_MARKER = "<!-- route-table:end -->"
ROUTER_START = "<!-- router-block:start -->"
ROUTER_END = "<!-- router-block:end -->"
EXPECTED_HEADER = "| Type | Name | Dutch signals | English signals | Tool route | Read set | Budget | On tie |"

# WHY: the label belongs to the generated region, so a hand edit inside the
# markers fails the check and the write restores it.
ROUTER_NOTE = (
    "This block is generated from the Task-Type Table by `check-route-table.py --write`. "
    "Edit the table and rerun the mode."
)
FALLBACK_TIERS = (
    "Tier A: Refuse with the out-of-scope boundary, load nothing",
    "Tier B: Ask one question, print the candidate route per answer",
    "Tier C: Name the missing tax year, resolve it before loading",
)
HELPER_LINES = (
    'CONTEXT = read_session_context("session-context.json")',
    "",
    "def discover_markdown_resources():",
    '    return {p.relative_to(SKILL_ROOT).as_posix() for base in RESOURCE_BASES if base.exists() for p in base.rglob("*.md") if p.is_file()}',
    "",
    "def _guard_in_skill(relative_path):",
    "    resolved = (SKILL_ROOT / relative_path).resolve()",
    "    resolved.relative_to(SKILL_ROOT)",
    '    if resolved.suffix.lower() != ".md":',
    '        raise ValueError("local markdown only")',
    "    return resolved.relative_to(SKILL_ROOT).as_posix()",
    "",
    "def load_if_available(relative_path, inventory, loaded, missing):",
    "    guarded = _guard_in_skill(relative_path)",
    "    if guarded in inventory and guarded not in loaded:",
    "        load(guarded)",
    "        loaded.append(guarded)",
    "    elif guarded not in inventory:",
    "        missing.append(guarded)",
)

# WHY: these advisor signals are curated by hand and no table cell produces
# them, so the check requires their presence and the write never drops one.
CURATED_ADVISOR_SIGNALS = (
    "help me migrate my jortt bookkeeping into moneybird",
    "review my monthly moneybird bookkeeping",
    "check the vat for this quarter",
    "what is the current dutch zzp mileage rate",
    "how should i book this business expense in moneybird",
    "help me prepare a year-end bookkeeping review",
    "explain the jortt to moneybird mapping",
    "help me review a dutch sole trader yearly close",
)

ROW_TYPES = tuple("T%d" % number for number in range(1, 13))
ROUTE_CELLS = ("`none`", "`cli-jortt`", "`cli-moneybird`", "`cli-jortt + cli-moneybird`", "`additive`")

# WHY: the routing prose must keep naming the abstain outcome.
REQUIRED_TOKENS = ("abstain",)
# WHY: the router and the signal sources file both state the route margin,
# and the resolver reads only the router copy.
MARGIN_RE = re.compile(r"`ROUTE_MARGIN = ([0-9.]+)`")
# WHY: the signal sources file names a term as a weak signal that never
# decides a row, as in "`btw` alone is a weak signal", so no row may list it.
WEAK_SIGNAL_RE = re.compile(r"^`([^`]+)` alone is a weak signal", re.M)

# WHY: the routing section must point readers at the signal sources file.
SIGNAL_HEAD = "Signal sources"
SIGNALS_REF = "references/routing-signals.md"
SIGNALS_MD = os.path.join(SKILL_FOLDER, "references", "routing-signals.md")
SOURCES_HEAD = "SIGNAL SOURCES"
VOCABULARY_PREFIX = "- Skill vocabulary"
YEAR_TOKEN = "{year}"
PHASE_PLACEHOLDER = "{phase-file}"
TOPIC_PLACEHOLDER = "{topic-figures}"
TOPIC_ANCHOR = "2-key-figures"
MIGRATION_INDEX = os.path.join(SKILL_FOLDER, "references", "migration", "README.md")
TAX_RULES_BASE = os.path.join(SKILL_FOLDER, "references", "tax-rules")
GLOSSARY_BASE = os.path.join(SKILL_FOLDER, "references", "glossary")
GLOSSARY_ROUTER_PATH = "references/glossary/README.md"
# WHY: the resolver maps a read outside a topic folder to one of these two files.
GLOSSARY_SHARED_FILES = ("bookkeeping.md", "general.md")
GAPS_HEADING = "Documented gaps"
GAPS_COLUMNS = ("Topic", "Owner", "Coverage", "Operator action")
COVERAGE_VALUES = ("covered", "partial", "gap")

ROW_RE = re.compile(r"^\|\s*(T\d+)\s*\|")
BACKTICK_RE = re.compile(r"`([^`]*)`")
BARE_PATH_RE = re.compile(r"(?<![\w/.~-])((?://|/|~/|\.\./)?(?:[\w.-]+/)*[\w.-]+\.(?:md|mdx|markdown|rst|adoc|html?|json|ya?ml|py|txt|csv))\b", re.IGNORECASE)
YEAR_RE = re.compile(r"^\d{4}$")
SECTION_RE = re.compile(
    r"^(INTENT_SIGNALS|REQUIRED_READS|CONDITIONAL_READS|SECTION_TARGETS|PHASE_FILES|TOPIC_FILES|RESOURCE_MAP|LOADING_LEVELS) = \{$"
)
ENTRY_RE = re.compile(r'^    "(T\d+|tok:T\d+)": .*,$')
HEADING_TEXT_RE = re.compile(r"^#{1,6}\s+(.*)$")
ANCHOR_ID_RE = re.compile(r'<a\s+id="([^"]+)"')
SLUG_STRIP_RE = re.compile(r"[^\w\s-]", re.UNICODE)
SLUG_SPACE_RE = re.compile(r"\s")
PHASE_ROW_RE = re.compile(r"^\|\s*(\d+)\s*\|[^|]*\|\s*\[[^\]]+\]\(\./([^)]+)\)\s*\|")
SEPARATOR_RE = re.compile(r"^:?-{3,}:?$")

# WHY: the read budget ladder names the three units every budget key is built
# from, and token-baseline.py holds the full file unit as its file line, so the
# ladder sentence, the signal sources file and that line must agree.
LADDER_RE = re.compile(
    r"Read budget ladder in o200k_base tokens: year README ([0-9,]+), one section ([0-9,]+), full file ([0-9,]+)\."
)
LADDER_SOURCE_RES = (
    re.compile(r"A README or index file: ([0-9,]+) tokens"),
    re.compile(r"One section: ([0-9,]+) tokens"),
    re.compile(r"One full reference file: ([0-9,]+) tokens"),
)
FILE_LIMIT_RE = re.compile(r"^FILE_TOKEN_LIMIT = ([0-9]+)$", re.MULTILINE)
# WHY: three rows carry a rule the resolver depends on, so the table may not
# drop it: T7 only appends, T9 loses to every typed row and T8 calls no tool.
ROW_RULES = (
    ("T7", "on_tie", "never wins alone"),
    ("T9", "on_tie", "Loses to every typed row"),
    ("T8", "tool_route", "`none`"),
)
PACKET_KINDS = ("workflow", "tool")
FRONTMATTER_NAME_RE = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)

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


def is_empty(cell: str) -> bool:
    """Tell whether a table cell counts as empty.

    Args:
        cell: Raw cell text.

    Returns:
        True when the cell holds nothing outside whitespace and backticks.
    """
    return cell.strip().strip("`").strip() == ""


def split_cells(line: str) -> List[str]:
    """Split a markdown table line into stripped cells.

    Args:
        line: One table line with leading and trailing pipes.

    Returns:
        The cell texts without their surrounding whitespace.
    """
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def cell_signals(cell: str) -> List[str]:
    """Read the signal list of one signal cell.

    A cell may backtick every signal or hold a plain comma list.

    Args:
        cell: Raw Dutch or English signal cell text.

    Returns:
        The signal texts in cell order.
    """
    spans = [span.strip() for span in BACKTICK_RE.findall(cell)]
    if not spans:
        spans = [part.strip() for part in cell.split(",")]
    return [span for span in spans if span]


def split_anchor(item: str) -> Tuple[str, str]:
    """Split one read item into its path and its optional anchor.

    Args:
        item: Read item text after its mark, such as a path with an
            `@section-id` suffix.

    Returns:
        The path and the anchor, with an empty anchor when the item names
        none.
    """
    path, sep, anchor = item.partition("@")
    return path, anchor if sep else ""


def read_set_items(cell: str) -> List[Tuple[str, str]]:
    """Read the marked items of one read-set cell.

    Args:
        cell: Raw read-set cell text.

    Returns:
        One (mark, item) pair per backticked item, with the mark `!` or `?`
        and the item text after the mark. A `-` cell and unmarked spans
        produce no pair.
    """
    items: List[Tuple[str, str]] = []
    for span in BACKTICK_RE.findall(cell):
        span = span.strip()
        if not span or span == "-" or span[0] not in "!?":
            continue
        item = span[1:].strip()
        if item:
            items.append((span[0], item))
    return items


def marked_items(cell: str, mark: str) -> List[str]:
    """Read the items of one read-set cell that carry one mark.

    Args:
        cell: Raw read-set cell text.
        mark: The mark to select, `!` or `?`.

    Returns:
        The item texts in cell order, without their mark.
    """
    return [item for item_mark, item in read_set_items(cell) if item_mark == mark]


def cell_paths(cell: str) -> List[str]:
    """Read the path list of one read-set cell.

    Args:
        cell: Raw read-set cell text.

    Returns:
        The unique item paths in cell order, with the marks and the anchors
        stripped and the year and map tokens kept. An empty list covers the
        `-` cell.
    """
    paths: List[str] = []
    for _, item in read_set_items(cell):
        path = split_anchor(item)[0]
        if path and path not in paths:
            paths.append(path)
    return paths


def cell_section_targets(cell: str) -> List[Tuple[str, str]]:
    """Read the anchored items of one read-set cell.

    Args:
        cell: Raw read-set cell text.

    Returns:
        One (path, anchor) pair per unique anchor, in cell order. A
        `{topic-figures}` item carries the anchor every topic map value
        names, keyed by the token, so a reader sees the section without the
        map being expanded here.
    """
    targets: List[Tuple[str, str]] = []
    for _, item in read_set_items(cell):
        path, anchor = split_anchor(item)
        if not anchor and path == TOPIC_PLACEHOLDER:
            anchor = TOPIC_ANCHOR
        if anchor and (path, anchor) not in targets:
            targets.append((path, anchor))
    return targets


def json_dict(items: List[Tuple[str, str]]) -> str:
    """Format one list of string pairs as a Python dictionary literal.

    Args:
        items: Key and value pairs to format.

    Returns:
        One braced literal with a comma between the entries.
    """
    return "{" + ", ".join("%s: %s" % (json.dumps(key), json.dumps(value)) for key, value in items) + "}"


def json_list(items: List[str]) -> str:
    """Format one list of strings as a Python literal.

    Args:
        items: Strings to format.

    Returns:
        One bracketed literal with a comma between the items.
    """
    return "[" + ", ".join(json.dumps(item) for item in items) + "]"


def read_metadata(path: str) -> Optional[Dict[str, Any]]:
    """Read the graph metadata file.

    Args:
        path: Path of the JSON file.

    Returns:
        The parsed object, or None when the file is missing or malformed.
    """
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def signal_list(data: Optional[Dict[str, Any]]) -> Optional[List[str]]:
    """Read the intent signal list of the metadata object.

    Args:
        data: Parsed metadata object, or None.

    Returns:
        The signal list, or None when the field is missing or malformed.
    """
    if data is None:
        return None
    signals = data.get("intent_signals")
    if not isinstance(signals, list) or any(not isinstance(signal, str) for signal in signals):
        return None
    return signals


def write_text(path: str, content: str) -> bool:
    """Write one text file.

    Args:
        path: File to write.
        content: Full new content.

    Returns:
        True when the file was written.
    """
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
    except OSError as exc:
        print("error: cannot write %s: %s" % (path, exc), file=sys.stderr)
        return False
    return True


def year_folders() -> List[str]:
    """List the four-digit year folders under references/tax-rules.

    Returns:
        Sorted folder names such as 2020, for a read path written as
        references/tax-rules/{year}.
    """
    if not os.path.isdir(TAX_RULES_BASE):
        return []
    return sorted(
        name
        for name in os.listdir(TAX_RULES_BASE)
        if YEAR_RE.fullmatch(name) and os.path.isdir(os.path.join(TAX_RULES_BASE, name))
    )


def phase_files() -> Dict[str, str]:
    """Read the migration phase number to phase file map.

    Returns:
        The phase numbers in numeric order, mapped to their
        `references/migration/<file>` path, parsed from the phase table rows
        of the migration index.
    """
    files: Dict[str, str] = {}
    if not os.path.isfile(MIGRATION_INDEX):
        return files
    try:
        with open(MIGRATION_INDEX, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return files
    for line in lines:
        match = PHASE_ROW_RE.match(line.strip())
        if not match:
            continue
        files[match.group(1)] = "references/migration/%s" % match.group(2)
    return dict(sorted(files.items(), key=lambda pair: int(pair[0])))


def topic_files() -> Dict[str, str]:
    """Read the topic slug to figures file map.

    Returns:
        The topic slugs in name order, mapped to
        `references/tax-rules/{year}/<topic>/figures.md@2-key-figures`, one
        entry per topic folder holding a figures file under any year folder.
    """
    topics: Dict[str, str] = {}
    for year in year_folders():
        year_path = os.path.join(TAX_RULES_BASE, year)
        for name in sorted(os.listdir(year_path)):
            if name in topics or not os.path.isfile(os.path.join(year_path, name, "figures.md")):
                continue
            topics[name] = "references/tax-rules/%s/%s/figures.md@%s" % (YEAR_TOKEN, name, TOPIC_ANCHOR)
    return topics


def expand_read_item(item: str) -> List[str]:
    """Expand the map tokens and the year token of one read item.

    Args:
        item: Read item text after its mark, with the anchor still attached.

    Returns:
        The expansion in map and year order, or the item itself when it
        carries no token.
    """
    items = [item]
    if PHASE_PLACEHOLDER in item:
        items = [part.replace(PHASE_PLACEHOLDER, value) for part in items for value in phase_files().values()]
    if TOPIC_PLACEHOLDER in item:
        items = [part.replace(TOPIC_PLACEHOLDER, value) for part in items for value in topic_files().values()]
    expanded: List[str] = []
    for part in items:
        if YEAR_TOKEN in part:
            expanded.extend(part.replace(YEAR_TOKEN, year) for year in year_folders())
        else:
            expanded.append(part)
    return expanded


def github_slug(heading: str) -> str:
    """Turn a heading into the GitHub anchor slug.

    Args:
        heading: Heading text without the leading hashes.

    Returns:
        Lowercase text with punctuation dropped and each space turned into
        its own hyphen.
    """
    lowered = heading.strip().lower()
    stripped = SLUG_STRIP_RE.sub("", lowered)
    return SLUG_SPACE_RE.sub("-", stripped)


def file_has_anchor(path: str, anchor: str) -> bool:
    """Tell whether one markdown file offers an anchor.

    Args:
        path: Absolute path of the markdown file.
        anchor: Anchor slug to find.

    Returns:
        True when an explicit anchor id or a heading slug matches.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return False
    for line in lines:
        if anchor in ANCHOR_ID_RE.findall(line):
            return True
        match = HEADING_TEXT_RE.match(line)
        if match and github_slug(match.group(1)) == anchor:
            return True
    return False

# ───────────────────────────────────────────────────────────────
# 4. TABLE CHECK
# ───────────────────────────────────────────────────────────────

def check_read_path(
    row_type: str,
    mark: str,
    item: str,
    relative_path: str,
    anchor: str,
    problems: List[str],
    missing: List[str],
) -> None:
    """Check one expanded read-set path against the skill folder.

    The path must stay under the skill folder, name a markdown file and
    exist there. A missing path fails for a required item and is recorded
    for a conditional item. An anchor an existing file does not offer
    fails.

    Args:
        row_type: Row type of the cell, used in problem lines.
        mark: The item mark, `!` or `?`.
        item: The item text as written, used in problem lines.
        relative_path: Expanded read-set path in skill-relative form.
        anchor: Anchor slug named by the item, or an empty string.
        problems: Problem list to append to.
        missing: Missing conditional read list to append to.
    """
    root = os.path.realpath(SKILL_FOLDER)
    resolved = os.path.realpath(os.path.join(root, relative_path))
    if resolved != root and not resolved.startswith(root + os.sep):
        problems.append("row %s read path escapes the skill folder: %s" % (row_type, relative_path))
        return
    # WHY: a markdown-named symlink can point at a non-markdown file, so the resolved target is checked too.
    if not relative_path.lower().endswith(".md") or not resolved.lower().endswith(".md"):
        problems.append("row %s read path is not markdown: %s" % (row_type, relative_path))
        return
    if not os.path.isfile(resolved):
        if mark == "?":
            missing.append("missing: %s %s" % (row_type, relative_path))
        else:
            problems.append(
                "row %s read path missing: %s (item %s%s)" % (row_type, relative_path, mark, item)
            )
        return
    if anchor and not file_has_anchor(resolved, anchor):
        problems.append("row %s read anchor not found: %s@%s" % (row_type, relative_path, anchor))


def check_read_set(
    row_type: str, cell: str, problems: List[str], missing: List[str]
) -> None:
    """Check every marked item of one read-set cell.

    Each item is checked against the grammar, expanded over the map and year
    tokens, guarded and resolved under the skill folder. A `?` item whose
    expansion is absent lands in the missing list instead of the problems.

    Args:
        row_type: Row type of the cell, used in problem lines.
        cell: Raw read-set cell text.
        problems: Problem list to append to.
        missing: Missing conditional read list to append to.
    """
    # WHY: only backticked paths reach the generated read set, so a bare path would be dropped without a word.
    for bare in BARE_PATH_RE.findall(BACKTICK_RE.sub(" ", cell)):
        problems.append("row %s read path is not backticked: %s" % (row_type, bare))
    for span in BACKTICK_RE.findall(cell):
        span = span.strip()
        if not span or span == "-":
            continue
        if span[0] not in "!?":
            problems.append("row %s read item is not marked with ! or ?: %s" % (row_type, span))
            continue
        mark = span[0]
        item = span[1:].strip()
        if not item:
            problems.append("row %s read item is marked but names no path" % row_type)
            continue
        if "@" in item and not split_anchor(item)[1]:
            problems.append("row %s read item has an empty anchor: %s" % (row_type, item))
            continue
        for expanded in expand_read_item(item):
            path, anchor = split_anchor(expanded)
            check_read_path(row_type, mark, item, path, anchor, problems, missing)


def check_row(line: str, row_type: str, problems: List[str], missing: List[str]) -> None:
    """Check the cells of one route table row.

    Args:
        line: The stripped table row line.
        row_type: Row type named by the first cell.
        problems: Problem list to append to.
        missing: Missing conditional read list to append to.
    """
    cells = split_cells(line)
    if len(cells) != 8:
        problems.append("row %s has %d cells, expected 8" % (row_type, len(cells)))
        return
    if is_empty(cells[2]):
        problems.append("row %s has an empty Dutch cell" % row_type)
    if is_empty(cells[3]):
        problems.append("row %s has an empty English cell" % row_type)
    if cells[4] not in ROUTE_CELLS:
        problems.append(
            "row %s tool route is %r, expected one of %s" % (row_type, cells[4], ", ".join(ROUTE_CELLS))
        )
    if cells[6] != "`tok:%s`" % row_type:
        problems.append("row %s budget cell is %r, expected `tok:%s`" % (row_type, cells[6], row_type))
    check_read_set(row_type, cells[5], problems, missing)


def table_bounds(lines: List[str], problems: List[str]) -> Optional[Tuple[int, int]]:
    """Find the route table body between its markers.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.

    Returns:
        The first and last index of the table body, or None on a missing
        marker.
    """
    try:
        start = lines.index(START_MARKER)
    except ValueError:
        problems.append("route-table start marker missing")
        return None
    try:
        end = lines.index(END_MARKER, start + 1)
    except ValueError:
        problems.append("route-table end marker missing")
        return None
    return start + 1, end


def table_rows(lines: List[str]) -> List[Dict[str, str]]:
    """Collect one record per route table row, in table order.

    Args:
        lines: All lines of the markdown file.

    Returns:
        One dict per row with its type and its eight cells, or an empty list
        when the table markers are missing.
    """
    bounds = table_bounds(lines, [])
    if bounds is None:
        return []
    start, end = bounds
    rows: List[Dict[str, str]] = []
    for line in lines[start:end]:
        stripped = line.strip()
        match = ROW_RE.match(stripped)
        if not match:
            continue
        cells = split_cells(stripped)
        if len(cells) != 8:
            continue
        rows.append(
            {
                "type": cells[0],
                "name": cells[1],
                "dutch": cells[2],
                "english": cells[3],
                "tool_route": cells[4],
                "read_set": cells[5],
                "budget": cells[6],
                "on_tie": cells[7],
            }
        )
    return rows


def check_table(lines: List[str], problems: List[str], missing: List[str]) -> None:
    """Check the markers, the header and every row of the route table.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
        missing: Missing conditional read list to append to.
    """
    bounds = table_bounds(lines, problems)
    if bounds is None:
        return
    start, end = bounds
    body = lines[start:end]
    header = ""
    for line in body:
        if line.strip():
            header = line.strip()
            break
    if header != EXPECTED_HEADER:
        problems.append("route table header must be exactly: %s" % EXPECTED_HEADER)
    seen: List[str] = []
    for line in body:
        stripped = line.strip()
        match = ROW_RE.match(stripped)
        if not match:
            continue
        row_type = match.group(1)
        if row_type in seen:
            problems.append("duplicate row %s" % row_type)
            continue
        seen.append(row_type)
        check_row(stripped, row_type, problems, missing)
    for row_type in ROW_TYPES:
        if row_type not in seen:
            problems.append("missing row %s" % row_type)
    for row_type in seen:
        if row_type not in ROW_TYPES:
            problems.append("unexpected row %s" % row_type)

# ───────────────────────────────────────────────────────────────
# 5. ROUTER BLOCK
# ───────────────────────────────────────────────────────────────

def check_maps(problems: List[str]) -> None:
    """Check that the two generated maps have source rows.

    Args:
        problems: Problem list to append to.
    """
    if not phase_files():
        problems.append("migration index holds no phase table rows: %s" % MIGRATION_INDEX)
    if not topic_files():
        problems.append("no topic figures file found under %s" % TAX_RULES_BASE)


def check_glossary(text: str, problems: List[str]) -> None:
    """Check that the glossary read rule can reach a file for every read.

    Args:
        text: Full markdown text of ROUTER.md.
        problems: Problem list to append to.
    """
    if GLOSSARY_ROUTER_PATH not in text:
        problems.append("the glossary read rule is missing: %s" % GLOSSARY_ROUTER_PATH)
    router = os.path.join(GLOSSARY_BASE, "README.md")
    if not os.path.isfile(router):
        problems.append("missing glossary router: %s" % GLOSSARY_ROUTER_PATH)
        return
    with open(router, encoding="utf-8") as handle:
        router_text = handle.read()
    topics = set(topic_files())
    for year in year_folders():
        year_path = os.path.join(TAX_RULES_BASE, year)
        topics.update(
            name
            for name in os.listdir(year_path)
            if os.path.isdir(os.path.join(year_path, name))
        )
    wanted = sorted({"%s.md" % topic for topic in topics} | set(GLOSSARY_SHARED_FILES))
    for name in wanted:
        if not os.path.isfile(os.path.join(GLOSSARY_BASE, name)):
            problems.append("missing glossary file: references/glossary/%s" % name)
    for name in sorted(os.listdir(GLOSSARY_BASE)):
        if name.endswith(".md") and name != "README.md" and "(%s)" % name not in router_text:
            problems.append("glossary router does not link: references/glossary/%s" % name)


def read_json_file(path: str) -> Optional[Any]:
    """Read one JSON file.

    Args:
        path: File path.

    Returns:
        The parsed value, or None when the file is missing or malformed.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def read_file_text(path: str) -> str:
    """Read one text file.

    Args:
        path: File path.

    Returns:
        The file text, or an empty string when the file cannot be read.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def router_header(path: str) -> List[str]:
    """Read the frontmatter lines of one router file.

    Args:
        path: Router file path.

    Returns:
        The lines between the opening and the closing `---`, or an empty
        list when the file is missing or has no frontmatter.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return []
    if not lines or lines[0] != "---" or "---" not in lines[1:]:
        return []
    return lines[1:lines.index("---", 1)]


def h2_headings(text: str) -> List[Tuple[int, str]]:
    """List the H2 headings of a markdown text that sit outside a fence.

    Args:
        text: Markdown text.

    Returns:
        (line index, heading line) pairs in document order.
    """
    headings: List[Tuple[int, str]] = []
    fence = ""
    for index, line in enumerate(text.splitlines()):
        stripped = line.strip()
        if stripped.startswith(("```", "~~~")):
            marker = stripped[:3]
            fence = "" if fence == marker else (fence or marker)
        elif not fence and line.startswith("## "):
            headings.append((index, line.rstrip()))
    return headings


def router_section_problem(packet: str, router_text: str) -> Optional[str]:
    """Name what is wrong with the routing section of one packet router.

    Args:
        packet: Packet folder name.
        router_text: Text of the packet's ROUTER.md.

    Returns:
        A problem line, or None when the router keeps its routing section.
    """
    headings = h2_headings(router_text)
    if any(heading == MACHINE_ROUTER_SECTION for _index, heading in headings):
        if headings[-1][1] != MACHINE_ROUTER_SECTION:
            return "%s/ROUTER.md: %s is not its last H2" % (packet, MACHINE_ROUTER_SECTION)
        lines = router_text.splitlines()
        if ROUTER_START in lines and lines.index(ROUTER_START) < headings[-1][0]:
            return "%s/ROUTER.md: the generated router block sits outside %s" % (packet, MACHINE_ROUTER_SECTION)
        return None
    if ROUTER_SECTION in router_text:
        return None
    return "%s/ROUTER.md lacks its routing section, intent model or resource map" % packet


def check_hub(problems: List[str]) -> None:
    """Check the hub files, the registry, stage one and each packet router.

    Every folder at the repository root that holds a SKILL.md must be a
    registry packet, the hub SKILL.md must link each packet router, and each
    router must keep its routing section, an intent model and a resource map.

    Args:
        problems: Problem list to append to.
    """
    for name in HUB_FILES:
        if not os.path.isfile(os.path.join(REPO_ROOT, name)):
            problems.append("missing hub file: %s" % name)
    registry = read_json_file(os.path.join(REPO_ROOT, "mode-registry.json"))
    modes = registry.get("modes") if isinstance(registry, dict) else None
    if not isinstance(modes, list) or not modes:
        problems.append("mode-registry.json has no modes list")
        return
    defaults = [mode.get("workflowMode") for mode in modes if isinstance(mode, dict) and mode.get("default") is True]
    if len(defaults) != 1:
        problems.append("mode-registry.json needs exactly one default mode, found %d" % len(defaults))
    names = []
    hub_text = read_file_text(os.path.join(REPO_ROOT, "SKILL.md"))
    # WHY: the hub may move its routing prose into a root ROUTER.md that its
    # SKILL.md links, so the packet router links are read from both files.
    hub_router_path = os.path.join(REPO_ROOT, "ROUTER.md")
    hub_router_text = read_file_text(hub_router_path)
    hub_text += "\n" + hub_router_text
    if os.path.isfile(hub_router_path):
        hub_header = router_header(hub_router_path)
        for line in (ROUTER_STATE_LINE, SKILL_POINTER_LINE):
            if line not in hub_header:
                problems.append("ROUTER.md frontmatter lacks: %s" % line)
        headings = h2_headings(hub_router_text)
        if not headings or headings[-1][1] != MACHINE_ROUTER_SECTION:
            problems.append("ROUTER.md: %s is not its last H2" % MACHINE_ROUTER_SECTION)
        if not any(pointer in read_file_text(os.path.join(REPO_ROOT, "SKILL.md")) for pointer in PACKET_POINTERS):
            problems.append("hub SKILL.md does not point to its router: ROUTER.md")
    packets = set()
    for mode in modes:
        if not isinstance(mode, dict):
            problems.append("mode-registry.json holds a mode that is not an object")
            continue
        name, packet = mode.get("workflowMode"), str(mode.get("packet"))
        names.append(name)
        packets.add(packet)
        skill = os.path.join(REPO_ROOT, packet, "SKILL.md")
        if not os.path.isfile(skill):
            problems.append("registry packet has no SKILL.md: %s" % packet)
            continue
        kind = mode.get("packetKind")
        expected_kind = PACKET_KINDS[0] if mode.get("default") is True else PACKET_KINDS[1]
        if kind != expected_kind:
            problems.append("registry packetKind of %s is %s, expected %s" % (packet, kind, expected_kind))
        declared = FRONTMATTER_NAME_RE.search(read_file_text(skill))
        if not declared or mode.get("packetSkillName") != declared.group(1).strip("\"'"):
            problems.append("registry packetSkillName of %s does not match its SKILL.md name" % packet)
        if mode.get("router") != "%s/ROUTER.md" % packet:
            problems.append("registry router is not %s/ROUTER.md: %s" % (packet, mode.get("router")))
        header = router_header(os.path.join(REPO_ROOT, packet, "ROUTER.md"))
        if not header:
            problems.append("packet has no router: %s/ROUTER.md" % packet)
        for line in (ROUTER_STATE_LINE, SKILL_POINTER_LINE):
            if header and line not in header:
                problems.append("%s/ROUTER.md frontmatter lacks: %s" % (packet, line))
        router_text = read_file_text(os.path.join(REPO_ROOT, packet, "ROUTER.md"))
        if header and (
            "RESOURCE_MAP" not in router_text
            or not any(mark in router_text for mark in ROUTER_INTENT_MARKS)
        ):
            problems.append("%s/ROUTER.md lacks its routing section, intent model or resource map" % packet)
        elif header:
            section_problem = router_section_problem(packet, router_text)
            if section_problem:
                problems.append(section_problem)
        if "(%s/ROUTER.md)" % packet not in hub_text:
            problems.append("hub SKILL.md does not link the packet router: %s/ROUTER.md" % packet)
        # WHY: the hub ROUTER.md names the registry modes in its machine block,
        # so a mode the registry gains or renames must show up there too.
        if hub_router_text and (
            '"workflowMode": "%s"' % name not in hub_router_text
            or '"router": "%s/ROUTER.md"' % packet not in hub_router_text
        ):
            problems.append("ROUTER.md machine block does not name the registry mode %s and its router" % name)
        with open(skill, encoding="utf-8") as handle:
            packet_text = handle.read()
        for mark in EMBEDDED_ROUTER_MARKS:
            if mark in packet_text:
                problems.append("packet SKILL.md embeds a router: %s/SKILL.md holds %s" % (packet, mark))
        if not any(pointer in packet_text for pointer in PACKET_POINTERS):
            problems.append("packet SKILL.md does not point to its router: %s/SKILL.md" % packet)
    for entry in sorted(os.listdir(REPO_ROOT)):
        if entry.startswith(".") or entry in packets:
            continue
        if os.path.isfile(os.path.join(REPO_ROOT, entry, "SKILL.md")):
            problems.append("packet folder is not in mode-registry.json: %s" % entry)
    stage_one = read_json_file(os.path.join(REPO_ROOT, "hub-router.json"))
    policy = stage_one.get("routerPolicy") if isinstance(stage_one, dict) else None
    signals = stage_one.get("signals") if isinstance(stage_one, dict) else None
    if not isinstance(policy, dict) or not isinstance(signals, dict):
        problems.append("hub-router.json needs a routerPolicy and a signals object")
        return
    if defaults and policy.get("defaultMode") != defaults[0]:
        problems.append("hub-router.json defaultMode %s is not the registry default %s" % (policy.get("defaultMode"), defaults[0]))
    if sorted(signals) != sorted(str(name) for name in names):
        problems.append("hub-router.json signals do not name the registry modes")
    for name, values in sorted(signals.items()):
        if not isinstance(values, list) or not all(isinstance(value, str) and value.strip() for value in values):
            problems.append("hub-router.json signals for %s are not a list of phrases" % name)
        elif not values and name not in defaults:
            problems.append("hub-router.json signals for %s are empty and it is not the default" % name)


def router_block(rows: List[Dict[str, str]]) -> List[str]:
    """Format the generated router block from the table rows.

    Args:
        rows: Table rows in table order.

    Returns:
        The block lines, markers included.
    """
    lines = [ROUTER_START, ROUTER_NOTE, "", "```python", "from pathlib import Path", ""]
    lines.append("SKILL_ROOT = Path(__file__).resolve().parent")
    lines.append('RESOURCE_BASES = (SKILL_ROOT / "references",)')
    lines.append("INTENT_SIGNALS = {")
    for row in rows:
        lines.append(
            '    "%s": [%s, %s],'
            % (row["type"], json_list(cell_signals(row["dutch"])), json_list(cell_signals(row["english"])))
        )
    lines.append("}")
    lines.append("REQUIRED_READS = {")
    for row in rows:
        lines.append('    "%s": %s,' % (row["type"], json_list(marked_items(row["read_set"], "!"))))
    lines.append("}")
    lines.append("CONDITIONAL_READS = {")
    for row in rows:
        lines.append('    "%s": %s,' % (row["type"], json_list(marked_items(row["read_set"], "?"))))
    lines.append("}")
    lines.append("SECTION_TARGETS = {")
    for row in rows:
        lines.append('    "%s": %s,' % (row["type"], json_dict(cell_section_targets(row["read_set"]))))
    lines.append("}")
    lines.append("PHASE_FILES = {")
    for number, path in phase_files().items():
        lines.append("    %s: %s," % (json.dumps(number), json.dumps(path)))
    lines.append("}")
    lines.append("TOPIC_FILES = {")
    for topic, path in topic_files().items():
        lines.append("    %s: %s," % (json.dumps(topic), json.dumps(path)))
    lines.append("}")
    lines.append("RESOURCE_MAP = {")
    for row in rows:
        lines.append('    "%s": %s,' % (row["type"], json_list(cell_paths(row["read_set"]))))
    lines.append("}")
    lines.append("LOADING_LEVELS = {")
    for row in rows:
        lines.append('    "tok:%s": %s,' % (row["type"], json_list(cell_paths(row["read_set"]))))
    lines.append("}")
    lines.append("UNKNOWN_FALLBACK_CHECKLIST = [")
    for tier in FALLBACK_TIERS:
        lines.append("    %s," % json.dumps(tier))
    lines.append("]")
    lines.append("")
    lines.extend(HELPER_LINES)
    lines.append("")
    lines.append("```")
    lines.append(ROUTER_END)
    return lines


def block_entries(lines: List[str]) -> Dict[str, str]:
    """Map every row entry of a router block to its source line.

    Args:
        lines: The block lines.

    Returns:
        One entry per section and row key, such as INTENT_SIGNALS/T1.
    """
    section = ""
    entries: Dict[str, str] = {}
    for line in lines:
        match = SECTION_RE.match(line)
        if match:
            section = match.group(1)
            continue
        if line in ("}", "]"):
            section = ""
            continue
        entry = ENTRY_RE.match(line)
        if entry and section:
            entries["%s/%s" % (section, entry.group(1))] = line
    return entries


def check_router_block(lines: List[str], rows: List[Dict[str, str]], problems: List[str]) -> None:
    """Compare the generated router block with the table.

    A differing row entry names its row. Any other difference fails as a
    whole block difference.

    Args:
        lines: All lines of the markdown file.
        rows: Table rows in table order.
        problems: Problem list to append to.
    """
    has_start = ROUTER_START in lines
    has_end = ROUTER_END in lines
    if not has_start:
        problems.append("router block start marker missing")
    if not has_end:
        problems.append("router block end marker missing")
    if not (has_start and has_end) or not rows:
        return
    start = lines.index(ROUTER_START)
    end = lines.index(ROUTER_END, start + 1)
    actual = lines[start:end + 1]
    expected = router_block(rows)
    if actual == expected:
        return
    expected_entries = block_entries(expected)
    actual_entries = block_entries(actual)
    named = False
    for key, line in expected_entries.items():
        if actual_entries.get(key) != line:
            problems.append("row %s: block entry differs from the table" % key.split("/")[1])
            named = True
    if not named:
        problems.append("router block differs from the table")


def multi_word_signals(rows: List[Dict[str, str]]) -> List[str]:
    """Read every multi-word signal of the table, in table order.

    Args:
        rows: Table rows in table order.

    Returns:
        One entry per unique signal that holds two or more words.
    """
    signals: List[str] = []
    for row in rows:
        for cell in (row["dutch"], row["english"]):
            for signal in cell_signals(cell):
                if len(signal.split()) < 2 or signal in signals:
                    continue
                signals.append(signal)
    return signals


def check_intent_signals(rows: List[Dict[str, str]], path: str, problems: List[str]) -> None:
    """Compare the table signals and the curated signals with the metadata list.

    Args:
        rows: Table rows in table order.
        path: Path of the graph metadata file.
        problems: Problem list to append to.
    """
    signals = multi_word_signals(rows)
    known = signal_list(read_metadata(path))
    if known is None:
        problems.append("graph metadata file is missing or malformed: %s" % path)
        return
    for signal in signals:
        if signal not in known:
            problems.append("intent signal missing from intent_signals: %s" % signal)
    for signal in CURATED_ADVISOR_SIGNALS:
        if signal not in known:
            problems.append("curated advisor signal missing from intent_signals: %s" % signal)


def write_router_block(
    lines: List[str], rows: List[Dict[str, str]], problems: List[str]
) -> Optional[List[str]]:
    """Replace the router block with the generated block.

    Args:
        lines: All lines of the markdown file.
        rows: Table rows in table order.
        problems: Problem list to append to.

    Returns:
        The new lines, or None when a marker is missing.
    """
    block = router_block(rows)
    has_start = ROUTER_START in lines
    has_end = ROUTER_END in lines
    if not has_start:
        problems.append("router block start marker missing")
    if not has_end:
        problems.append("router block end marker missing")
    if not (has_start and has_end):
        return None
    start = lines.index(ROUTER_START)
    end = lines.index(ROUTER_END, start + 1)
    if lines[start:end + 1] == block:
        return lines
    return lines[:start] + block + lines[end + 1:]


def write_intent_signals(data: Dict[str, Any], signals: List[str]) -> Tuple[List[str], bool]:
    """Append the missing table signals to the metadata list.

    Args:
        data: Parsed metadata object.
        signals: Multi-word table signals in table order.

    Returns:
        The added signals and whether the list changed.
    """
    known = signal_list(data)
    if known is None:
        return [], False
    added: List[str] = []
    for signal in signals:
        if signal not in known:
            known.append(signal)
            added.append(signal)
    data["intent_signals"] = known
    return added, bool(added)


# ───────────────────────────────────────────────────────────────
# 6. PROSE CHECKS
# ───────────────────────────────────────────────────────────────

def check_row_rules(rows: List[Dict[str, str]], problems: List[str]) -> None:
    """Check the row rules the resolver depends on.

    Args:
        rows: Table rows in table order.
        problems: Problem list to append to.
    """
    by_type = {row["type"]: row for row in rows}
    for row_type, field, phrase in ROW_RULES:
        row = by_type.get(row_type)
        if row is None:
            continue
        if field == "tool_route" and row[field].strip() != phrase:
            problems.append("%s tool route must be %s" % (row_type, phrase))
        elif field != "tool_route" and phrase not in row[field]:
            problems.append("%s on tie cell lacks: %s" % (row_type, phrase))


def ladder_number(value: str) -> int:
    """Read one ladder number written with thousands commas.

    Args:
        value: Number text such as `15,000`.

    Returns:
        The integer value.
    """
    return int(value.replace(",", ""))


def check_ladder(text: str, signals_path: str, problems: List[str]) -> None:
    """Check the read budget ladder against its sources and the file line.

    Args:
        text: Full markdown text of the router.
        signals_path: Path of the signal sources file.
        problems: Problem list to append to.
    """
    match = LADDER_RE.search(text)
    if not match:
        problems.append("router lacks the read budget ladder sentence")
        return
    ladder = [ladder_number(value) for value in match.groups()]
    signals_text = read_file_text(signals_path)
    for value, pattern in zip(ladder, LADDER_SOURCE_RES):
        source = pattern.search(signals_text)
        if not source or ladder_number(source.group(1)) != value:
            problems.append("ladder value %d differs from the signal sources file: %s" % (value, pattern.pattern))
    baseline_text = read_file_text(os.path.join(os.path.dirname(os.path.abspath(__file__)), "token-baseline.py"))
    limit = FILE_LIMIT_RE.search(baseline_text)
    if not limit or int(limit.group(1)) != ladder[2]:
        problems.append("ladder full file %d differs from FILE_TOKEN_LIMIT in token-baseline.py" % ladder[2])


def check_margin(text: str, signals_path: str, problems: List[str]) -> None:
    """Check that the router and the signal sources file state one route margin.

    Args:
        text: Full markdown text of the router.
        signals_path: Path of the signal sources file.
        problems: Problem list to append to.
    """
    router = MARGIN_RE.search(text)
    if not router:
        problems.append("router lacks the ROUTE_MARGIN line")
        return
    source = MARGIN_RE.search(read_file_text(signals_path))
    if not source or source.group(1) != router.group(1):
        problems.append("route margin %s differs from the signal sources file" % router.group(1))


def check_weak_signals(rows: List[Dict[str, str]], signals_path: str, problems: List[str]) -> None:
    """Check that no row lists a term the signal sources file calls weak.

    Args:
        rows: Table rows in table order.
        signals_path: Path of the signal sources file.
        problems: Problem list to append to.
    """
    weak = {term.lower() for term in WEAK_SIGNAL_RE.findall(read_file_text(signals_path))}
    for row in rows:
        for cell in (row["dutch"], row["english"]):
            for signal in cell_signals(cell):
                if signal.lower() in weak:
                    problems.append("%s lists the weak signal %s" % (row["type"], signal))


def check_required_tokens(text: str, problems: List[str]) -> None:
    """Check that the routing constants and outcomes are named in the file.

    Args:
        text: Full markdown text.
        problems: Problem list to append to.
    """
    for token in REQUIRED_TOKENS:
        if token not in text:
            problems.append("missing required token: %s" % token)


def check_signals_pointer(lines: List[str], problems: List[str]) -> None:
    """Check that the routing section points at the signal sources file.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
    """
    for line in lines:
        if SIGNAL_HEAD in line and SIGNALS_REF in line:
            return
    problems.append("missing pointer line naming %s" % SIGNALS_REF)


def check_signal_sources(path: str, problems: List[str]) -> None:
    """Check the source lines of the signal sources file.

    The file must exist and its signal sources section must hold at least
    one list bullet. The skill vocabulary bullet is exempt. Every other
    bullet must carry a link to the tax authority site.

    Args:
        path: Path of the signal sources file.
        problems: Problem list to append to.
    """
    if not os.path.isfile(path):
        problems.append("signal sources file not found: %s" % path)
        return
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as exc:
        problems.append("cannot read %s: %s" % (path, exc))
        return
    section = -1
    for index, line in enumerate(lines):
        if line.lstrip().startswith("#") and SOURCES_HEAD in line:
            section = index
            break
    if section < 0:
        problems.append("%s has no %s section" % (path, SOURCES_HEAD))
        return
    bullets = 0
    for index, line in enumerate(lines[section + 1:], section + 2):
        stripped = line.strip()
        if stripped.startswith("#"):
            break
        if not stripped.startswith("- "):
            continue
        bullets += 1
        if stripped.startswith(VOCABULARY_PREFIX):
            continue
        if "belastingdienst.nl" not in stripped:
            problems.append("%s line %d: signal source without a belastingdienst.nl link" % (path, index))
    if bullets == 0:
        problems.append("%s holds no signal source lines" % path)


def check_gap_ledger(path: str, problems: List[str]) -> None:
    """Check the documented-gap table of the signal sources file.

    The table lives under the Documented gaps heading. Every row must carry
    a topic, an owner, a coverage value from the allowed set and an operator
    action, and no topic may repeat. A file without the heading declares no
    gap and passes.

    Args:
        path: Path of the signal sources file.
        problems: Problem list to append to.
    """
    if not os.path.isfile(path):
        return
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return
    heading = -1
    for index, line in enumerate(lines):
        # WHY: reference H2 headings print in capitals, so the match ignores case.
        if line.lstrip().startswith("#") and GAPS_HEADING.lower() in line.lower():
            heading = index
            break
    if heading < 0:
        return
    header = -1
    for index in range(heading + 1, len(lines)):
        if split_cells(lines[index]) == list(GAPS_COLUMNS):
            header = index
            break
    if header < 0:
        problems.append("%s has a %s heading without its table header" % (path, GAPS_HEADING))
        return
    seen: List[str] = []
    for index in range(header + 1, len(lines)):
        stripped = lines[index].strip()
        if not stripped.startswith("|"):
            break
        cells = split_cells(stripped)
        if all(SEPARATOR_RE.match(cell) for cell in cells):
            continue
        if len(cells) != len(GAPS_COLUMNS):
            problems.append(
                "%s line %d: gap row has %d cells, expected %d"
                % (path, index + 1, len(cells), len(GAPS_COLUMNS))
            )
            continue
        topic = cells[0].strip("`").strip()
        owner = cells[1].strip("`").strip()
        coverage = cells[2].strip("`").strip()
        action = cells[3].strip("`").strip()
        if not topic:
            problems.append("%s line %d: gap row has an empty topic" % (path, index + 1))
        if not owner:
            problems.append("%s line %d: gap row %s has an empty owner" % (path, index + 1, topic or "?"))
        if coverage not in COVERAGE_VALUES:
            problems.append(
                "%s line %d: gap row %s coverage is %r, expected one of %s"
                % (path, index + 1, topic or "?", coverage, ", ".join(COVERAGE_VALUES))
            )
        if not action:
            problems.append("%s line %d: gap row %s has an empty operator action" % (path, index + 1, topic or "?"))
        if topic in seen:
            problems.append("%s line %d: gap row %s repeats its topic" % (path, index + 1, topic))
        seen.append(topic)

# ───────────────────────────────────────────────────────────────
# 7. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def run_write(text: str, lines: List[str], rows: List[Dict[str, str]]) -> int:
    """Regenerate the router block and the intent signals.

    A malformed table or metadata file stops the run before either file is
    touched. The block is written before the signal list, so a refused write
    leaves both files as they were.

    Args:
        text: Current ROUTER.md text.
        lines: Current ROUTER.md lines.
        rows: Table rows in table order.

    Returns:
        Zero on success, 2 when the write was refused.
    """
    problems: List[str] = []
    missing: List[str] = []
    check_table(lines, problems, missing)
    check_maps(problems)
    if problems:
        for problem in problems:
            print(problem)
        return 2
    for line in missing:
        print(line)
    data = read_metadata(GRAPH_METADATA)
    if data is None:
        print("graph metadata file is missing or malformed: %s" % GRAPH_METADATA)
        return 2
    if signal_list(data) is None:
        print("graph metadata intent_signals must be a list of strings: %s" % GRAPH_METADATA)
        return 2
    new_lines = write_router_block(lines, rows, problems)
    if new_lines is None:
        for problem in problems:
            print(problem)
        return 2
    added, changed = write_intent_signals(data, multi_word_signals(rows))
    newline = "\n" if text.endswith("\n") else ""
    if new_lines != lines:
        if not write_text(ROUTER_MD, "\n".join(new_lines) + newline):
            return 2
        print("router block: written (%s)" % os.path.basename(ROUTER_MD))
    else:
        print("router block: unchanged (%s)" % os.path.basename(ROUTER_MD))
    if changed:
        if not write_text(GRAPH_METADATA, json.dumps(data, indent=2) + "\n"):
            return 2
        print("intent signals: added %d (%s)" % (len(added), os.path.basename(GRAPH_METADATA)))
    else:
        print("intent signals: unchanged (%s)" % os.path.basename(GRAPH_METADATA))
    return 0


def main(argv: List[str]) -> int:
    """Parse arguments and run the route table check.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the file passes, one when it has problems.
    """
    parser = argparse.ArgumentParser(
        prog=CHECKER,
        description="Check the task-type route table in the skill's router.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="regenerate the router block and the intent signals",
    )
    args = parser.parse_args(argv)
    if not os.path.isfile(ROUTER_MD):
        fail("router markdown not found: %s" % ROUTER_MD)
    try:
        with open(ROUTER_MD, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (ROUTER_MD, exc))
    lines = text.splitlines()
    rows = table_rows(lines)
    if args.write:
        return run_write(text, lines, rows)
    problems: List[str] = []
    missing: List[str] = []
    check_table(lines, problems, missing)
    check_maps(problems)
    check_glossary(text, problems)
    check_hub(problems)
    check_required_tokens(text, problems)
    check_margin(text, SIGNALS_MD, problems)
    check_weak_signals(rows, SIGNALS_MD, problems)
    check_row_rules(rows, problems)
    check_ladder(text, SIGNALS_MD, problems)
    check_signals_pointer(lines, problems)
    check_signal_sources(SIGNALS_MD, problems)
    check_gap_ledger(SIGNALS_MD, problems)
    check_router_block(lines, rows, problems)
    check_intent_signals(rows, GRAPH_METADATA, problems)
    for line in missing:
        print(line)
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("route-table: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
