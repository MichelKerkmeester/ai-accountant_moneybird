#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE TABLE CHECKER
# ───────────────────────────────────────────────────────────────
"""Check the task-type route table in the skill markdown.

Reads SKILL.md and verifies the route-table block between its markers. The
check validates the header, the row types, the Dutch and English cells, the
budget cells, the tool routes, the read-set paths and their guard, the
routing constants, the warning band, the abstain wording, the margin override
bullets, the pointer to the signal sources file, the source lines of that
file and the frozen calibration record in assets/route-calibration.json. It
also compares the generated router block between the router markers with the
table row by row and the table's multi-word signals and curated advisor
signals with graph-metadata.json, and the write mode regenerates both
surfaces. The script uses the Python standard
library only and makes no network call.

Usage:
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --check
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --write
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --signals /tmp/routing-signals.md
    python3 -I sk-moneybird-accountant/scripts/check-route-table.py --calibration /tmp/route-calibration.json

Options:
    --check          Run the check. This is the default mode.
    --write          Regenerate the router block in SKILL.md and append the
                     table's multi-word signals to graph-metadata.json.
    --skill-md P     Read this markdown file instead of the skill's own SKILL.md.
                     Read-set paths still resolve against the skill folder.
    --graph-metadata P  Read the intent signals from this file instead of the
                     skill's graph-metadata.json.
    --signals P      Read the signal sources from this file instead of the
                     skill's references/routing-signals.md.
    --calibration P  Read the frozen constants from this file instead of the
                     skill's assets/route-calibration.json.

Output:
    One line per problem, or "route-table: ok" when the file passes. The
    write mode prints one line per generated surface. Exit 0 on success, 1
    when the file has problems and 2 when a write is refused.
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
SKILL_MD = os.path.join(SKILL_FOLDER, "SKILL.md")

GRAPH_METADATA = os.path.join(SKILL_FOLDER, "graph-metadata.json")

START_MARKER = "<!-- route-table:start -->"
END_MARKER = "<!-- route-table:end -->"
ROUTER_START = "<!-- router-block:start -->"
ROUTER_END = "<!-- router-block:end -->"
ROUTER_HEADING = "### Smart Router Pseudocode"
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

# WHY: the table must carry every row type exactly once.
ROW_TYPES = tuple("T%d" % number for number in range(1, 10))
ROUTE_CELLS = ("`none`", "`cli-jortt`", "`cli-moneybird`", "`cli-jortt + cli-moneybird`", "`additive`")

# WHY: the routing prose must keep naming both calibration constants, the
# warning band and the abstain outcome.
REQUIRED_TOKENS = ("ROUTE_MARGIN", "FALLBACK_FLOOR", "0.08", "abstain")

# WHY: only these row types may carry their own margin override bullet.
OVERRIDE_TYPES = ("T2", "T6")
OVERRIDE_PREFIX = "- Margin override"

# WHY: the routing section must point readers at the signal sources file.
SIGNAL_HEAD = "Signal sources"
SIGNALS_REF = "references/routing-signals.md"
SIGNALS_MD = os.path.join(SKILL_FOLDER, "references", "routing-signals.md")
CALIBRATION_PATH = os.path.join(SKILL_FOLDER, "assets", "route-calibration.json")
SOURCES_HEAD = "SIGNAL SOURCES"
VOCABULARY_PREFIX = "- Skill vocabulary"
TIE_HEADING = "Ties and Abstain"
YEAR_TOKEN = "YYYY"
FALSE_ABSTAIN_MAX = 0.05
PENDING_MARKER = "calibration: pending"
CONSTANT_NUMBER_RE = re.compile(r"([0-9]+(?:\.[0-9]+)?)")

ROW_RE = re.compile(r"^\|\s*(T\d+)\s*\|")
OVERRIDE_BULLET_RE = re.compile(r"^\s*(T\d+):\s*(.*)$")
BACKTICK_RE = re.compile(r"`([^`]*)`")
NUMBER_RE = re.compile(r"\d+(?:\.\d+)?")
YEAR_RE = re.compile(r"^\d{4}$")
SECTION_RE = re.compile(r"^(INTENT_SIGNALS|RESOURCE_MAP|LOADING_LEVELS) = \{$")
ENTRY_RE = re.compile(r'^    "(T\d+|tok:T\d+)": .*,$')
HEADING_RE = re.compile(r"^#{1,6} ")

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


def cell_paths(cell: str) -> List[str]:
    """Read the path list of one read-set cell.

    Args:
        cell: Raw read-set cell text.

    Returns:
        The unique backticked paths in cell order, with an empty list for
        the `-` cell.
    """
    paths: List[str] = []
    for span in BACKTICK_RE.findall(cell):
        span = span.strip()
        if not span or span == "-" or span in paths:
            continue
        paths.append(span)
    return paths


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
    """List the four-digit year folders under references.

    Returns:
        Sorted folder names such as 2020 and 2021.
    """
    base = os.path.join(SKILL_FOLDER, "references")
    if not os.path.isdir(base):
        return []
    return sorted(
        name
        for name in os.listdir(base)
        if YEAR_RE.fullmatch(name) and os.path.isdir(os.path.join(base, name))
    )

# ───────────────────────────────────────────────────────────────
# 4. TABLE CHECK
# ───────────────────────────────────────────────────────────────

def check_read_path(row_type: str, relative_path: str, problems: List[str]) -> None:
    """Check one expanded read-set path against the skill folder.

    The path must stay under the skill folder, name a markdown file and
    exist there.

    Args:
        row_type: Row type of the cell, used in problem lines.
        relative_path: Expanded read-set path in skill-relative form.
        problems: Problem list to append to.
    """
    root = os.path.realpath(SKILL_FOLDER)
    resolved = os.path.realpath(os.path.join(root, relative_path))
    if resolved != root and not resolved.startswith(root + os.sep):
        problems.append("row %s read path escapes the skill folder: %s" % (row_type, relative_path))
        return
    if not relative_path.lower().endswith(".md"):
        problems.append("row %s read path is not markdown: %s" % (row_type, relative_path))
        return
    if not os.path.isfile(resolved):
        problems.append("row %s read path missing: %s" % (row_type, relative_path))


def check_read_set(row_type: str, cell: str, problems: List[str]) -> None:
    """Check every backticked path in one read-set cell.

    A year token expands over every year folder present, and each expanded
    path must pass the guard and exist under the skill folder.

    Args:
        row_type: Row type of the cell, used in problem lines.
        cell: Raw read-set cell text.
        problems: Problem list to append to.
    """
    years = year_folders()
    for span in BACKTICK_RE.findall(cell):
        if span == "-":
            continue
        if YEAR_TOKEN in span:
            for year in years:
                check_read_path(row_type, span.replace(YEAR_TOKEN, year), problems)
            continue
        check_read_path(row_type, span, problems)


def check_row(line: str, row_type: str, problems: List[str]) -> None:
    """Check the cells of one route table row.

    Args:
        line: The stripped table row line.
        row_type: Row type named by the first cell.
        problems: Problem list to append to.
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
    check_read_set(row_type, cells[5], problems)


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


def check_table(lines: List[str], problems: List[str]) -> None:
    """Check the markers, the header and every row of the route table.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
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
        check_row(stripped, row_type, problems)
    for row_type in ROW_TYPES:
        if row_type not in seen:
            problems.append("missing row %s" % row_type)
    for row_type in seen:
        if row_type not in ROW_TYPES:
            problems.append("unexpected row %s" % row_type)

# ───────────────────────────────────────────────────────────────
# 5. ROUTER BLOCK
# ───────────────────────────────────────────────────────────────

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
    """Replace the router block, or the sketch, with the generated block.

    Args:
        lines: All lines of the markdown file.
        rows: Table rows in table order.
        problems: Problem list to append to.

    Returns:
        The new lines, or None when no region can be written.
    """
    block = router_block(rows)
    has_start = ROUTER_START in lines
    has_end = ROUTER_END in lines
    if has_start != has_end:
        problems.append("router block markers must appear as a pair")
        return None
    if has_start:
        start = lines.index(ROUTER_START)
        end = lines.index(ROUTER_END, start + 1)
        if lines[start:end + 1] == block:
            return lines
        return lines[:start] + block + lines[end + 1:]
    heading = next((index for index, line in enumerate(lines) if line.strip() == ROUTER_HEADING), -1)
    if heading < 0:
        problems.append("router block markers and the Smart Router Pseudocode heading are both missing")
        return None
    after = heading + 1
    while after < len(lines) and not HEADING_RE.match(lines[after]):
        after += 1
    return lines[:heading + 1] + [""] + block + [""] + lines[after:]


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

def check_required_tokens(text: str, problems: List[str]) -> None:
    """Check that the routing constants and outcomes are named in the file.

    Args:
        text: Full markdown text.
        problems: Problem list to append to.
    """
    for token in REQUIRED_TOKENS:
        if token not in text:
            problems.append("missing required token: %s" % token)


def check_overrides(lines: List[str], problems: List[str]) -> None:
    """Check the margin override bullets under the tie heading.

    The overrides are list bullets after the heading, one per override type.
    The heading must exist, each override type must have exactly one bullet,
    no other type may carry a bullet and the value must be the default word
    or a number.

    Args:
        lines: All lines of the markdown file.
        problems: Problem list to append to.
    """
    heading = -1
    for index, line in enumerate(lines):
        if line.lstrip().startswith("#") and TIE_HEADING in line:
            heading = index
            break
    if heading < 0:
        problems.append("heading missing: %s" % TIE_HEADING)
        return
    found: List[str] = []
    for index, line in enumerate(lines[heading + 1:], heading + 2):
        stripped = line.strip()
        if not stripped.startswith(OVERRIDE_PREFIX):
            continue
        body = stripped[len(OVERRIDE_PREFIX):].strip()
        match = OVERRIDE_BULLET_RE.match(body)
        if not match:
            problems.append("line %d: margin override bullet without a type and value" % index)
            continue
        row_type = match.group(1)
        if row_type not in OVERRIDE_TYPES:
            problems.append("line %d: margin override bullet names %s, expected T2 or T6" % (index, row_type))
            continue
        found.append(row_type)
        value = match.group(2).strip().strip("`").strip()
        if value != "default" and not NUMBER_RE.fullmatch(value):
            problems.append(
                "line %d: margin override for %s is %r, expected `default` or a number" % (index, row_type, value)
            )
    for row_type in OVERRIDE_TYPES:
        if row_type not in found:
            problems.append("margin override bullet missing for %s" % row_type)


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


def constant_number(text: str, name: str) -> Optional[float]:
    """Read the number stated after one routing constant.

    Args:
        text: SKILL.md text.
        name: Constant name such as ROUTE_MARGIN.

    Returns:
        The number on the constant line, or None when the line states none.
    """
    match = re.search(re.escape(name) + r"[^\n]*?([0-9]+(?:\.[0-9]+)?)", text)
    if not match:
        return None
    return float(match.group(1))


def is_number(value: Any) -> bool:
    """Tell whether one JSON value is a real number.

    Args:
        value: Value from the calibration record.

    Returns:
        True for an int or float that is not a bool.
    """
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_rate(value: Any, label: str, problems: List[str]) -> Optional[float]:
    """Check one rate value and return it as a float.

    Args:
        value: Value from the calibration record.
        label: Field name used in a problem line.
        problems: Problem list to append to.

    Returns:
        The rate as a float, or None when it is not a valid rate.
    """
    if not is_number(value) or value < 0 or value > 1:
        problems.append("calibration %s must be a number from 0 to 1" % label)
        return None
    return float(value)


def check_rate_block(block: Any, label: str, problems: List[str]) -> None:
    """Check the two rates of one calibration split block.

    Args:
        block: JSON object with route_accuracy and false_abstain_rate.
        label: Split name used in a problem line.
        problems: Problem list to append to.
    """
    if not isinstance(block, dict):
        problems.append("calibration %s must be an object" % label)
        return
    check_rate(block.get("route_accuracy"), "%s route_accuracy" % label, problems)
    rate = check_rate(block.get("false_abstain_rate"), "%s false_abstain_rate" % label, problems)
    if rate is not None and rate > FALSE_ABSTAIN_MAX:
        problems.append(
            "calibration %s false_abstain_rate %.3f is above the %.2f cap" % (label, rate, FALSE_ABSTAIN_MAX)
        )
    rows = block.get("rows")
    matches = block.get("route_matches")
    if rows is not None and (not is_number(rows) or rows <= 0):
        problems.append("calibration %s rows must be a positive number" % label)
    if matches is not None and (not is_number(matches) or matches < 0):
        problems.append("calibration %s route_matches must not be negative" % label)
    accuracy = block.get("route_accuracy")
    if is_number(rows) and is_number(matches) and is_number(accuracy) and rows > 0:
        if abs(float(matches) / float(rows) - float(accuracy)) > 0.001:
            problems.append("calibration %s route_accuracy does not match its counts" % label)


def check_candidate_block(candidate: Dict[str, Any], floor: Any, problems: List[str]) -> None:
    """Check the counts and rates of one swept floor candidate.

    Args:
        candidate: One sweep candidate object.
        floor: Floor value of the candidate, used in problem lines.
        problems: Problem list to append to.
    """
    rows = candidate.get("rows")
    matches = candidate.get("route_matches")
    abstains = candidate.get("false_abstains")
    if not is_number(rows) or rows <= 0:
        problems.append("calibration sweep floor %s rows must be a positive number" % floor)
    if not is_number(matches) or matches < 0:
        problems.append("calibration sweep floor %s route_matches must not be negative" % floor)
    if not is_number(abstains) or abstains < 0:
        problems.append("calibration sweep floor %s false_abstains must not be negative" % floor)
    accuracy = check_rate(candidate.get("route_accuracy"), "sweep floor %s route_accuracy" % floor, problems)
    rate = check_rate(candidate.get("false_abstain_rate"), "sweep floor %s false_abstain_rate" % floor, problems)
    if is_number(rows) and is_number(matches) and is_number(accuracy) and rows > 0:
        if abs(float(matches) / float(rows) - float(accuracy)) > 0.001:
            problems.append("calibration sweep floor %s route_accuracy does not match its counts" % floor)
    if is_number(rows) and is_number(abstains) and is_number(rate) and rows > 0:
        if abs(float(abstains) / float(rows) - float(rate)) > 0.001:
            problems.append("calibration sweep floor %s false_abstain_rate does not match its counts" % floor)


def check_sweep(data: Dict[str, Any], problems: List[str]) -> None:
    """Check the sweep table and its link to the frozen block.

    The record must hold one candidate per swept floor, each with the
    calibration counts and the two rates. The frozen fallback floor must
    name one candidate and the frozen calibration block must repeat that
    candidate's counts.

    Args:
        data: The calibration record.
        problems: Problem list to append to.
    """
    sweep = data.get("sweep")
    if not isinstance(sweep, dict):
        problems.append("calibration sweep must be an object")
        return
    rule = sweep.get("selection_rule")
    if not isinstance(rule, str) or not rule.strip():
        problems.append("calibration sweep selection_rule must be a non-empty string")
    step = sweep.get("step")
    if step is not None and (not is_number(step) or step <= 0):
        problems.append("calibration sweep step must be a positive number")
    candidates = sweep.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        problems.append("calibration sweep must hold a non-empty candidate list")
        return
    seen: List[float] = []
    chosen_block: Optional[Dict[str, Any]] = None
    chosen = data.get("fallback_floor")
    for candidate in candidates:
        if not isinstance(candidate, dict):
            problems.append("calibration sweep candidate must be an object")
            continue
        floor = candidate.get("floor")
        if not is_number(floor) or float(floor) < 0:
            problems.append("calibration sweep candidate floor must be a number that is not negative")
            continue
        if float(floor) in seen:
            problems.append("calibration sweep holds duplicate floor %s" % floor)
        seen.append(float(floor))
        check_candidate_block(candidate, floor, problems)
        if is_number(chosen) and abs(float(chosen) - float(floor)) <= 0.000001:
            chosen_block = candidate
    if not seen:
        problems.append("calibration sweep holds no usable candidate")
        return
    if not is_number(chosen):
        return
    if chosen_block is None:
        problems.append("calibration fallback_floor %s is not a swept candidate" % chosen)
        return
    frozen = data.get("calibration")
    if isinstance(frozen, dict):
        for key in ("rows", "route_matches", "route_accuracy", "false_abstains", "false_abstain_rate"):
            if frozen.get(key) != chosen_block.get(key):
                problems.append("calibration %s differs from the swept floor %s" % (key, chosen))


def check_calibration(path: str, skill_text: str, problems: List[str]) -> None:
    """Check the frozen constants against the table that states them.

    The effective table value is the number the table states, or zero while
    the fallback floor is marked pending, because the scorer treats a
    pending floor as no floor. The checker fails when the record and the
    effective table state differ, when a rate is outside its range, when a
    false-abstain rate is above the cap and when the record is missing or
    malformed.

    Args:
        path: Path of the calibration record.
        skill_text: SKILL.md text that states the constants.
        problems: Problem list to append to.
    """
    if not os.path.isfile(path):
        problems.append("calibration file not found: %s" % path)
        return
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        problems.append("cannot read %s: %s" % (path, exc))
        return
    if not isinstance(data, dict):
        problems.append("calibration file must hold one object")
        return
    split_id = data.get("split_id")
    if not isinstance(split_id, str) or not split_id.strip():
        problems.append("calibration split_id must be a non-empty string")
    table_margin = constant_number(skill_text, "ROUTE_MARGIN")
    record_margin = data.get("route_margin")
    if not is_number(record_margin):
        problems.append("calibration route_margin must be a number")
    elif table_margin is not None and abs(float(record_margin) - table_margin) > 0.000001:
        problems.append(
            "calibration route_margin %s differs from the table %s" % (record_margin, table_margin)
        )
    record_floor = data.get("fallback_floor")
    if not is_number(record_floor) or float(record_floor) < 0:
        problems.append("calibration fallback_floor must be a number that is not negative")
    else:
        table_floor = constant_number(skill_text, "FALLBACK_FLOOR")
        if table_floor is None:
            if PENDING_MARKER not in skill_text:
                problems.append("calibration fallback_floor is neither stated in the table nor marked pending")
            elif abs(float(record_floor)) > 0.000001:
                problems.append(
                    "calibration fallback_floor %s differs from the pending table value 0.0" % record_floor
                )
        elif abs(float(record_floor) - table_floor) > 0.000001:
            problems.append(
                "calibration fallback_floor %s differs from the table %s" % (record_floor, table_floor)
            )
    check_rate_block(data.get("held_out"), "held_out", problems)
    check_rate_block(data.get("calibration"), "frozen", problems)
    check_sweep(data, problems)

# ───────────────────────────────────────────────────────────────
# 7. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def run_write(args: Any, text: str, lines: List[str], rows: List[Dict[str, str]]) -> int:
    """Regenerate the router block and the intent signals.

    A malformed table or metadata file stops the run before either file is
    touched. The block is written before the signal list, so a refused write
    leaves both files as they were.

    Args:
        args: Parsed arguments.
        text: Current SKILL.md text.
        lines: Current SKILL.md lines.
        rows: Table rows in table order.

    Returns:
        Zero on success, 2 when the write was refused.
    """
    problems: List[str] = []
    check_table(lines, problems)
    if problems:
        for problem in problems:
            print(problem)
        return 2
    data = read_metadata(args.graph_metadata)
    if data is None:
        print("graph metadata file is missing or malformed: %s" % args.graph_metadata)
        return 2
    if signal_list(data) is None:
        print("graph metadata intent_signals must be a list of strings: %s" % args.graph_metadata)
        return 2
    new_lines = write_router_block(lines, rows, problems)
    if new_lines is None:
        for problem in problems:
            print(problem)
        return 2
    added, changed = write_intent_signals(data, multi_word_signals(rows))
    newline = "\n" if text.endswith("\n") else ""
    if new_lines != lines:
        if not write_text(args.skill_md, "\n".join(new_lines) + newline):
            return 2
        print("router block: written (%s)" % os.path.basename(args.skill_md))
    else:
        print("router block: unchanged (%s)" % os.path.basename(args.skill_md))
    if changed:
        if not write_text(args.graph_metadata, json.dumps(data, indent=2) + "\n"):
            return 2
        print("intent signals: added %d (%s)" % (len(added), os.path.basename(args.graph_metadata)))
    else:
        print("intent signals: unchanged (%s)" % os.path.basename(args.graph_metadata))
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
        description="Check the task-type route table in the skill markdown.",
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true", help="run the check, the default mode")
    group.add_argument(
        "--write",
        action="store_true",
        help="regenerate the router block and the intent signals",
    )
    parser.add_argument(
        "--skill-md",
        metavar="PATH",
        default=SKILL_MD,
        help="read this markdown file instead of the skill's own SKILL.md",
    )
    parser.add_argument(
        "--graph-metadata",
        metavar="PATH",
        default=GRAPH_METADATA,
        help="read the intent signals from this file instead of the skill's graph-metadata.json",
    )
    parser.add_argument(
        "--signals",
        metavar="PATH",
        default=SIGNALS_MD,
        help="read the signal sources from this file instead of the skill's references/routing-signals.md",
    )
    parser.add_argument(
        "--calibration",
        metavar="PATH",
        default=CALIBRATION_PATH,
        help="read the frozen constants from this file instead of the skill's assets/route-calibration.json",
    )
    args = parser.parse_args(argv)
    if not os.path.isfile(args.skill_md):
        fail("skill markdown not found: %s" % args.skill_md)
    try:
        with open(args.skill_md, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (args.skill_md, exc))
    lines = text.splitlines()
    rows = table_rows(lines)
    if args.write:
        return run_write(args, text, lines, rows)
    problems: List[str] = []
    check_table(lines, problems)
    check_required_tokens(text, problems)
    check_overrides(lines, problems)
    check_signals_pointer(lines, problems)
    check_signal_sources(args.signals, problems)
    check_calibration(args.calibration, text, problems)
    check_router_block(lines, rows, problems)
    check_intent_signals(rows, args.graph_metadata, problems)
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("route-table: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
