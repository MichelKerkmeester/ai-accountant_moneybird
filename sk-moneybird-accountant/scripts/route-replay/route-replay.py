#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE REPLAY
# ───────────────────────────────────────────────────────────────
"""Resolve the routing fixture corpus and score the routes offline.

The resolve mode builds a router snapshot out of the task-type table in
SKILL.md section 2 and the resource map under references/. It hashes the
snapshot, runs a connectivity gate over every routed path, resolves each
corpus prompt with a deterministic signal scorer and scores the row against
the gold mode, task type, path set, facts, file claims and token ceiling.
Output is results.csv and report.md. A file claim names one path and one
text that must appear in the scored revision, so a row can guard content
its read set does not load. No model answers a question, so answer quality
stays unscored. Time, environment and absolute paths never enter an output.

The replay mode runs the guard in test mode against the stub CLI and asserts
the recorded command line and exit code of every refusal row and of every
hostile invoice case. The key file, the run journal and the stub log live in
one run-owned temp root, so no credential or workspace is read.

Token counts use the pinned o200k_base encoding that the token baseline
loads. A missing cache folder or a sha256 pin mismatch stops the run with
exit code 2 instead of starting a download.

Usage:
    TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve
    TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve --out /tmp/route-replay
    python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay
    python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay --rev f5ba1f5 --covers 006/REQ-002

Options:
    --mode       resolve scores pure route resolution. replay runs the guard
                 in test mode against the stub and scores the refusal rows.
    --corpus     Read the fixture corpus from this path. The default is
                 routing-gold.json next to this script.
    --out        Write results.csv and report.md into this folder. The
                 default is benchmark/reports/route-replay under the skill.
    --skill-root Read SKILL.md and references/ from this folder. The default
                 is the skill folder that holds this script. It cannot be
                 combined with --rev.
    --rev SHA    Score a git worktree of that revision instead of the live
                 tree. The worktree is added in a temp folder and removed
                 after the run.
    --covers P/R Only score rows tagged with this phase and requirement.
                 Repeat the option to select more than one tag.
    --guard PATH Replay this guard instead of the one under the repo root.
    --stub PATH  Replay against this stub CLI instead of the one under the
                 repo root.

Output:
    results.csv with the columns scenario_id, lang, split, gold_mode,
    gold_task_type, score, verdict, reason, tokens_loaded, t7 and reads,
    report.md with the scored dimensions, the accuracy lines, the per-type
    precision and recall with denominators, the read counts, the warning
    band sink and the additive T7 assertion, and a one-line summary on
    stdout. A replay run adds command, expected_exit and actual_exit
    columns. Exit 0 when every row passes, 1 on a row or parity finding and
    2 on a usage, corpus, encoding cache or connectivity error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import ast
import csv
import hashlib
import importlib.util
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, NoReturn, Optional, Sequence, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

PROGRAM = "route-replay"
GENERATOR = "sk-moneybird-accountant/scripts/route-replay/route-replay.py"
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_ROOT = os.path.dirname(os.path.dirname(HERE))
CORPUS_NAME = "routing-gold.json"
DEFAULT_OUT = os.path.join(SKILL_ROOT, "benchmark", "reports", "route-replay")
SKILL_MD_NAME = "SKILL.md"
SKILL_FOLDER_NAME = "sk-moneybird-accountant"
SIGNALS_NAME = os.path.join("references", "routing-signals.md")
MIGRATION_INDEX = os.path.join("references", "migration", "README.md")
ROUTER_START = "<!-- router-block:start -->"
ROUTER_END = "<!-- router-block:end -->"
REFERENCE_INDEX = os.path.join("references", "index.json")
BASELINE_HELPER = os.path.join("scripts", "token-baseline.py")
HOSTILE_CASES = os.path.join("assets", "hostile-invoice-cases.json")
GUARD_RELATIVE = os.path.join("cli-moneybird", "cli", "moneybird-cli", "moneybird-guard")
STUB_RELATIVE = os.path.join("cli-moneybird", "cli", "moneybird-cli", "tests", "stub-moneybird-cli")
MISSING_WRITER_MARKER = "__MISSING_WRITER__"

START_MARKER = "<!-- route-table:start -->"
END_MARKER = "<!-- route-table:end -->"
TOC_START = "<!-- GENERATED:toc:start -->"
TOC_END = "<!-- GENERATED:toc:end -->"
ROW_RE = re.compile(r"^\|\s*(T\d+)\s*\|")
PHASE_ROW_RE = re.compile(r"^\|\s*(\d+)\s*\|[^|]*\|\s*\[[^\]]+\]\(\./([^)]+)\)\s*\|")
TOC_LINE_RE = re.compile(r"^-\s+(.+?):\s+lines\s+(\d+)-(\d+)\s*$")
BACKTICK_RE = re.compile(r"`([^`]*)`")
YEAR_TOKEN = "{year}"
PHASE_PLACEHOLDER = "{phase-file}"
TOPIC_PLACEHOLDER = "{topic-figures}"
YEAR_FOLDER_RE = re.compile(r"^\d{4}$")
YEAR_RE = re.compile(r"\b(19|20)\d{2}\b")
PHASE_RE = re.compile(r"(?:fase|phase)\s*(\d+)", re.IGNORECASE)
PASSED_RE = re.compile(r"(passed|gehaald|afgerond|doorlopen)\s+(?:fase|phase)?\s*$", re.IGNORECASE)

# WHY: the contract fixes these three rows as the preparation rows, so the
# filing precedence drops exactly these candidates when a T8 signal matches.
PREPARE_TYPES = ("T10", "T11", "T12")
REPORT_TYPES = tuple("T%d" % number for number in range(1, 13))

RESULT_COLUMNS = (
    "scenario_id",
    "lang",
    "split",
    "gold_mode",
    "gold_task_type",
    "score",
    "verdict",
    "reason",
    "tokens_loaded",
    "t7",
    "reads",
)

REPLAY_COLUMNS = RESULT_COLUMNS + (
    "command",
    "expected_exit",
    "actual_exit",
)

MODE_BY_TYPE = {
    "T1": "MIGRATION",
    "T2": "MIGRATION",
    "T3": "LIVE",
    "T4": "LIVE",
    "T5": "LIVE",
    "T6": "LIVE",
    "T9": "MIGRATION",
    "T10": "LIVE",
    "T11": "LIVE",
    "T12": "LIVE",
}

# WHY: the table names the signal families in prose, so a few fixtures need
# the same family in the other language or in a compound spelling.
EXTRA_SIGNALS = {
    "T1": (
        "write_intent",
        "write intent",
        "run journal",
        "read-back",
        "read back",
        "auditfile",
        "trial",
        "access window",
        "gated write",
        "m12",
        "agent_drafted",
        "proefperiode",
        "schrijfbatch",
        "leescontrole",
    ),
    "T5": (
        "official text",
        "officiële tekst",
        "officiele tekst",
        "source library",
        "law text",
        "wetstekst",
    ),
}

OUT_OF_SCOPE_PATTERNS = (
    r"file (?:my|the|our) [a-z ]*return",
    r"submit (?:my|the|our) [a-z ]*return",
    r"\bfiling\b",
    r"\baangifte\b",
    r"private database",
    r"priv[eé]database",
    r"non-dutch tax",
    r"german income tax",
)
NEGATION_RE = re.compile(r"(?:\bno\b|\bnot\b|\bnever\b|\bgeen\b|\bniet\b|\bzonder\b)\s*$", re.IGNORECASE)

INVOICE_RE = re.compile(r"\b(inkoopfactuur|bonnetje|invoice|receipt|supplier|leverancier)\b", re.IGNORECASE)
GATE_RE = re.compile(r"\b(gate|poort)\b", re.IGNORECASE)
CANCEL_RE = re.compile(r"(?<!\w)(?:cancel|opzeg|opgezeg)", re.IGNORECASE)
JORTT_OP_RE = re.compile(r"\bjortt\b[^.]*\bop\b", re.IGNORECASE)

SOURCE_TERMS = ("official text", "officiële tekst", "officiele tekst", "source library", "law text", "wetstekst")
MONITORING_TERMS = ("monitoring", "post-cutover", "post cutover", "monitoring_active", "monitoring_lapsed_phase22_open")
VAT_TERMS = ("btw", "vat", "quarter", "kwartaal")
ACCESS_TERMS = ("trial", "access window", "proefperiode", "auditfile", "read-only", "read only", "read_only", "lock", "workspace", "setup")

# WHY: the T4 read set carries two conditional references, so the resolver
# keeps the table's mixed-use and asset signal families to decide whether a
# winning T4 request also loads them. route-replay-test.sh fails when a term
# here is missing from the T4 signal cells.
MIXED_USE_TERMS = (
    "privégebruik",
    "zakelijk en privé",
    "deels privé",
    "gemengde kosten",
    "telefoonabonnement",
    "private use",
    "partly private",
    "mixed use",
    "phone subscription",
)
FIXED_ASSET_TERMS = (
    "afschrijven",
    "afschrijving",
    "inventaris",
    "activeren",
    "activeer",
    "depreciation",
    "depreciate",
    "fixed asset",
    "capitalise",
    "capitalize",
)
# These terms name what is booked, not the kind of request, so together they
# add one point to T4 at most. Otherwise a tax figure or rule question that
# names an asset twice outscores T5 or T6 before the tie clauses can apply.
T4_TOPIC_TERMS = MIXED_USE_TERMS + FIXED_ASSET_TERMS

TOPIC_SIGNALS = (
    (("kilometer", "mileage", "auto", "car", "thuiswerk", "home office", "kosten", "costs", "study", "studie"), "kosten-en-auto"),
    (("zelfstandigenaftrek", "ondernemersaftrek", "urencriterium", "mkb", "startersaftrek"), "ondernemersaftrek"),
    (("btw", "vat", "tarief", "rate", "voorbelasting", "kor"), "btw"),
    (("box 3", "box3", "heffingsvrij", "vermogen", "savings"), "box-3"),
    (("box 2", "aanmerkelijk belang", "gebruikelijk loon"), "box-2"),
    (("vennootschapsbelasting", "vpb", "bv "), "bv-en-vennootschapsbelasting"),
    (("pensioen", "lijfrente", "jaarruimte", "aov"), "pensioen-en-aov"),
    (("arbeidsrelatie", "dba", "opdracht", "loondienst"), "arbeidsrelatie"),
    (("investering", "kia", "eia", "mia", "afschrijving"), "investeringen"),
    (("zvw",), "zvw"),
    (("bewaarplicht", "deadline", "aangifte", "bezwaar", "procedure"), "procedure"),
    (("box 1", "inkomstenbelasting", "heffingskorting"), "inkomstenbelasting"),
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
    print("%s: %s" % (PROGRAM, message), file=sys.stderr)
    sys.exit(2)


def read_text(path: str) -> str:
    """Read one file as UTF-8 text.

    Args:
        path: File to read.

    Returns:
        The file text.

    Raises:
        SystemExit: When the file cannot be read.
    """
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (os.path.basename(path), exc))


def join_skill(skill_root: str, relative: str) -> str:
    """Return one path under the skill folder.

    Args:
        skill_root: Absolute skill folder.
        relative: Path relative to that folder.

    Returns:
        The joined path.
    """
    return os.path.join(skill_root, relative.replace("/", os.sep))


def strip_anchor(path: str) -> str:
    """Return the file part of one path address.

    Args:
        path: Path that may carry a #anchor suffix.

    Returns:
        The path without the suffix.
    """
    return path.split("#", 1)[0]


def plain_path(address: str) -> str:
    """Return the file part of one read-set address.

    The table grammar writes an anchor as `@section`, the resolved read set
    as `#section`, so both separators are stripped.

    Args:
        address: Path with an optional @anchor or #anchor suffix.

    Returns:
        The path without the suffix.
    """
    return strip_anchor(address.replace("@", "#"))


def read_set_items(cell: str) -> List[Tuple[str, str]]:
    """Read the marked items of one read-set cell.

    Args:
        cell: Raw read-set cell text.

    Returns:
        One (mark, item) pair per backticked item, with the mark `!` or `?`
        and the item text after the mark, anchor included.
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


def year_folders(skill_root: str) -> List[str]:
    """List the four-digit year folders under the tax-rules folder.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Sorted folder names such as 2020.
    """
    base = join_skill(skill_root, "references/tax-rules")
    if not os.path.isdir(base):
        return []
    return sorted(
        name
        for name in os.listdir(base)
        if YEAR_FOLDER_RE.fullmatch(name) and os.path.isdir(os.path.join(base, name))
    )


def expand_read_item(
    item: str,
    years: Sequence[str],
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
) -> List[str]:
    """Expand the map tokens and the year token of one read item.

    Args:
        item: Read item text after its mark, with the anchor attached.
        years: Year folders to expand the year token over.
        phase_map: Phase number to phase file from the generated block.
        topic_map: Topic slug to figures file from the generated block.

    Returns:
        The expansion in map and year order, or the item itself when it
        carries no token.
    """
    items = [item]
    if PHASE_PLACEHOLDER in item:
        items = [part.replace(PHASE_PLACEHOLDER, value) for part in items for value in phase_map.values()]
    if TOPIC_PLACEHOLDER in item:
        items = [part.replace(TOPIC_PLACEHOLDER, value) for part in items for value in topic_map.values()]
    expanded: List[str] = []
    for part in items:
        if YEAR_TOKEN in part:
            expanded.extend(part.replace(YEAR_TOKEN, year) for year in years)
        else:
            expanded.append(part)
    return expanded


def split_cells(line: str) -> List[str]:
    """Split a markdown table line into stripped cells.

    Args:
        line: One table line with leading and trailing pipes.

    Returns:
        The cell texts without their surrounding whitespace.
    """
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def signal_phrases(cell: str) -> List[str]:
    """Return the signal phrases of one table cell.

    A cell with backticked spans uses those spans. A plain prose cell is
    split on commas.

    Args:
        cell: Raw Dutch or English signal cell.

    Returns:
        The phrases in file order.
    """
    spans = BACKTICK_RE.findall(cell)
    if spans:
        return [span.strip() for span in spans if span.strip()]
    return [part.strip() for part in cell.split(",") if part.strip()]


def phrase_matches(text: str, phrase: str) -> bool:
    """Tell whether a signal phrase starts a word in one text.

    The phrase needs a non-word character before it and may run on into a
    Dutch compound, so `inkoopfactuur` stays one match and `btw-tarief`
    counts as `btw-tarief`.

    Args:
        text: Lower case request text.
        phrase: Signal phrase.

    Returns:
        True when the phrase starts a word in the text.
    """
    pattern = r"(?<!\w)" + re.escape(phrase.lower())
    return re.search(pattern, text) is not None


def is_replay_row(row: Dict[str, Any]) -> bool:
    """Tell whether a corpus row is scored by the replay mode.

    Args:
        row: One corpus row.

    Returns:
        True when the row carries an expected_exit code.
    """
    return "expected_exit" in row


def select_rows(rows: List[Dict[str, Any]], covers: Sequence[str], mode: str) -> List[Dict[str, Any]]:
    """Select the rows one mode scores and one covers filter keeps.

    Args:
        rows: Corpus rows in file order.
        covers: Phase and requirement tags to keep, empty means all.
        mode: resolve or replay.

    Returns:
        The selected rows in file order.
    """
    selected: List[Dict[str, Any]] = []
    for row in rows:
        replay = is_replay_row(row)
        if mode == "resolve" and replay:
            continue
        if mode == "replay" and not replay:
            continue
        if covers:
            tags = [str(tag) for tag in row.get("covers", [])]
            if not any(tag in tags for tag in covers):
                continue
        selected.append(row)
    return selected


def run_process(command: Sequence[str], env: Dict[str, str]) -> Tuple[int, str]:
    """Run one command and capture its merged output.

    Args:
        command: Command and arguments.
        env: Complete environment for the child process.

    Returns:
        The exit code and the merged output text.

    Raises:
        SystemExit: When the command cannot be started at all.
    """
    try:
        completed = subprocess.run(
            list(command),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=120,
        )
    except OSError as exc:
        fail("cannot run %s: %s" % (command[0], exc))
    except subprocess.SubprocessError as exc:
        fail("command failed to finish: %s" % exc)
    return completed.returncode, completed.stdout.decode("utf-8", "replace")


def parse_preview(output: str) -> Tuple[str, str]:
    """Read the dry-run line and the payload digest out of guard output.

    Args:
        output: Merged stdout and stderr of one guard run.

    Returns:
        The METHOD URL line and the digest, either one empty when absent.
    """
    dry_line = ""
    digest = ""
    for line in output.splitlines():
        stripped = line.strip()
        if not dry_line and re.match(r"^[A-Z]+ https?://", stripped):
            dry_line = stripped
        match = re.match(r"^payload-digest: ([0-9a-f]{64})$", stripped)
        if match:
            digest = match.group(1)
    return dry_line, digest


def flip_digest(digest: str) -> str:
    """Return a digest that cannot match the given one.

    Args:
        digest: Hex digest, empty when the guard cannot print one.

    Returns:
        A changed digest of the same length.
    """
    if not digest:
        return "0" * 64
    last = "0" if digest[-1] != "0" else "1"
    return digest[:-1] + last

# ───────────────────────────────────────────────────────────────
# 4. ROUTER SNAPSHOT
# ───────────────────────────────────────────────────────────────

def parse_route_table(text: str) -> List[Dict[str, str]]:
    """Parse the task-type table between its markers.

    Args:
        text: SKILL.md text.

    Returns:
        One row per task type with its cells.

    Raises:
        SystemExit: When a marker or a row is missing.
    """
    lines = text.splitlines()
    try:
        start = lines.index(START_MARKER)
        end = lines.index(END_MARKER, start + 1)
    except ValueError:
        fail("route table markers missing in %s" % SKILL_MD_NAME)
    rows: List[Dict[str, str]] = []
    for line in lines[start + 1:end]:
        stripped = line.strip()
        match = ROW_RE.match(stripped)
        if not match:
            continue
        cells = split_cells(stripped)
        if len(cells) != 8:
            fail("route row %s has %d cells, expected 8" % (match.group(1), len(cells)))
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
    if not rows:
        fail("route table holds no rows in %s" % SKILL_MD_NAME)
    return rows


def parse_constants(skill_text: str, signals_text: str) -> Dict[str, Any]:
    """Read the routing constants out of the skill prose.

    The table in SKILL.md is the single source of truth for the frozen
    floor. The signal file still carries the warning band, and the pending
    marker in the table applies while the table states no number.

    Args:
        skill_text: SKILL.md text.
        signals_text: routing-signals.md text.

    Returns:
        The margin, the warning band and the fallback floor state.
    """
    margin = 0.25
    match = re.search(r"ROUTE_MARGIN\s*=\s*([0-9.]+)", skill_text)
    if match:
        margin = float(match.group(1))
    warning = 0.08
    match = re.search(r"([0-9.]+)\s*warning band", signals_text)
    if match:
        warning = float(match.group(1))
    floor: Optional[float] = None
    pending = False
    match = re.search(r"FALLBACK_FLOOR[^\n]*?([0-9]+(?:\.[0-9]+)?)", skill_text)
    if match:
        floor = float(match.group(1))
    else:
        pending = "calibration: pending" in skill_text
        floor = 0.0
    return {
        "route_margin": margin,
        "warning_band": warning,
        "fallback_floor": floor,
        "fallback_floor_pending": pending,
    }


def parse_migration_index(text: str) -> Dict[str, str]:
    """Read the phase map out of the migration index.

    The generated block in SKILL.md is the map the scorer uses. This parse
    exists only to prove the block and the authored index still agree.

    Args:
        text: Migration index text.

    Returns:
        Mapping of phase number to its reference path.
    """
    mapping: Dict[str, str] = {}
    for line in text.splitlines():
        match = PHASE_ROW_RE.match(line.strip())
        if not match:
            continue
        mapping[match.group(1)] = "references/migration/" + match.group(2)
    return mapping


def parse_generated_map(text: str, name: str) -> Dict[str, str]:
    """Read one generated map out of the router block.

    Args:
        text: SKILL.md text.
        name: Generated map name, such as PHASE_FILES.

    Returns:
        The mapping, string to string.

    Raises:
        SystemExit: When the markers, the map or a value is malformed.
    """
    if ROUTER_START not in text or ROUTER_END not in text:
        fail("router block markers missing in %s" % SKILL_MD_NAME)
    pattern = re.compile(r"^%s = \{$" % re.escape(name), re.MULTILINE)
    match = pattern.search(text)
    if not match:
        fail("generated router block is missing %s" % name)
    stop = text.find("\n}", match.end())
    if stop == -1:
        fail("generated %s has no closing brace" % name)
    literal = text[match.start():stop + 2]
    try:
        value = ast.literal_eval(literal[literal.index("{"):])
    except (SyntaxError, ValueError):
        fail("generated %s is not a literal map" % name)
    if not isinstance(value, dict) or any(
        not isinstance(key, str) or not isinstance(item, str) for key, item in value.items()
    ):
        fail("generated %s must map strings to strings" % name)
    return dict(value)


def parse_weak_signals(signals_text: str) -> Tuple[str, ...]:
    """Read the weak signal terms out of the signal reference.

    The reference names a term as a weak signal, so only the backticked
    spans before the words weak signal on that line count.

    Args:
        signals_text: routing-signals.md text.

    Returns:
        The weak signal phrases in file order.

    Raises:
        SystemExit: When the file names none.
    """
    for line in signals_text.splitlines():
        index = line.lower().find("weak signal")
        if index == -1:
            continue
        spans = [span.strip() for span in BACKTICK_RE.findall(line[:index]) if span.strip()]
        if spans:
            return tuple(spans)
    fail("no weak signal named in %s" % os.path.basename(SIGNALS_NAME))


def check_phase_agreement(skill_root: str, phase_map: Dict[str, str]) -> None:
    """Prove the generated phase map still matches the migration index.

    Args:
        skill_root: Absolute skill folder.
        phase_map: Phase map read from the generated router block.

    Raises:
        SystemExit: When the two disagree.
    """
    index_path = join_skill(skill_root, MIGRATION_INDEX)
    if not os.path.isfile(index_path):
        return
    index_map = parse_migration_index(read_text(index_path))
    if index_map == phase_map:
        return
    detail = ""
    keys = sorted(set(index_map) | set(phase_map), key=lambda value: int(value))
    for key in keys:
        if index_map.get(key) != phase_map.get(key):
            detail = " (phase %s: %s in the block, %s in the index)" % (
                key,
                phase_map.get(key, "missing"),
                index_map.get(key, "missing"),
            )
            break
    fail("constants disagree: PHASE_FILES does not match references/migration/README.md%s" % detail)


def parse_toc_ranges(text: str) -> Dict[str, Tuple[int, int]]:
    """Read the generated section list of one reference file.

    The list carries H3 subsections with their line ranges, which the
    reference index does not hold.

    Args:
        text: Reference file text.

    Returns:
        Mapping of anchor to the first and last line of the subsection.
    """
    ranges: Dict[str, Tuple[int, int]] = {}
    inside = False
    for line in text.splitlines():
        if line.strip() == TOC_START:
            inside = True
            continue
        if line.strip() == TOC_END:
            break
        if not inside:
            continue
        match = TOC_LINE_RE.match(line.strip())
        if not match:
            continue
        label = match.group(1).strip()
        anchor = re.sub(r"[^\w\s-]", "", label.lower(), flags=re.UNICODE)
        anchor = re.sub(r"\s+", "-", anchor.strip())
        ranges[anchor] = (int(match.group(2)), int(match.group(3)))
    return ranges


def reference_files(skill_root: str) -> List[str]:
    """List every markdown file under the references root.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Paths relative to the skill folder, sorted.
    """
    base = join_skill(skill_root, "references")
    found: List[str] = []
    for directory, _, names in os.walk(base):
        for name in names:
            if name.endswith(".md"):
                absolute = os.path.join(directory, name)
                found.append(os.path.relpath(absolute, skill_root).replace(os.sep, "/"))
    return sorted(found)


def load_resource_map(skill_root: str) -> List[str]:
    """Load the resource map of the references root.

    The generated index is the map. A missing or unreadable index falls back
    to the live file walk so a fixture copy still resolves.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Reference paths relative to the skill folder, sorted.
    """
    index_path = join_skill(skill_root, REFERENCE_INDEX)
    if os.path.isfile(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
            paths = [
                "references/" + item["path"]
                for item in data.get("files", [])
                if isinstance(item, dict) and item.get("path")
            ]
            if paths:
                return sorted(paths)
        except (OSError, ValueError):
            pass
    return reference_files(skill_root)


def build_snapshot(
    route_rows: List[Dict[str, str]],
    constants: Dict[str, Any],
    phase_map: Dict[str, str],
    resources: List[str],
) -> Tuple[Dict[str, Any], str]:
    """Build the frozen router snapshot and its content hash.

    The snapshot holds relative paths and table text only, so time,
    environment and absolute paths cannot reach the hash.

    Args:
        route_rows: Parsed task-type rows.
        constants: Routing constants.
        phase_map: Phase number to reference path.
        resources: Reference paths from the resource map.

    Returns:
        The snapshot and its sha256 hex digest.
    """
    snapshot = {
        "route_rows": route_rows,
        "constants": constants,
        "phase_map": phase_map,
        "resources": resources,
        "specificity_clauses": [
            "an invoice named makes T4 beat T3",
            "one year named makes T5 beat T6",
            "a phase number or gate named makes T1 beat T2",
            "a phase number or gate named makes T1 beat T3",
            "a request for the official source text makes T5 beat T4",
            "T7 is additive and never wins alone",
        ],
        "fallback_tiers": {
            "A": "refuse with the out-of-scope boundary, load nothing",
            "B": "ask one question, print the candidate route per answer",
            "C": "name the missing tax year, resolve it before loading",
        },
    }
    canonical = json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return snapshot, digest


def routed_paths(
    route_rows: List[Dict[str, str]],
    skill_root: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
) -> Tuple[List[str], List[str]]:
    """Read the marked read paths of the route table.

    A year token expands over the year folders under the tax-rules folder,
    a map token expands over the generated map, an anchor is stripped and a
    dash cell holds no path.

    Args:
        route_rows: Parsed task-type rows.
        skill_root: Absolute skill folder.
        phase_map: Phase number to phase file from the generated block.
        topic_map: Topic slug to figures file from the generated block.

    Returns:
        Two sorted path lists, the required reads and the conditional
        reads, relative to the skill folder.
    """
    years = year_folders(skill_root)
    required: List[str] = []
    conditional: List[str] = []
    for row in route_rows:
        for mark, item in read_set_items(row["read_set"]):
            bucket = required if mark == "!" else conditional
            for address in expand_read_item(item, years, phase_map, topic_map):
                path = plain_path(address)
                if path and path not in bucket:
                    bucket.append(path)
    return sorted(required), sorted(conditional)

# ───────────────────────────────────────────────────────────────
# 5. CONNECTIVITY GATE
# ───────────────────────────────────────────────────────────────

def connectivity_report(skill_root: str, rows: List[Dict[str, Any]], required: Sequence[str]) -> List[str]:
    """List every required routed path that does not exist on disk.

    A conditional read is never passed here, so a `?` path that does not
    exist is not a connectivity failure.

    Args:
        skill_root: Absolute skill folder.
        rows: Corpus rows.
        required: Required paths named by the route table.

    Returns:
        One message per missing path, relative to the skill folder.
    """
    wanted = list(required)
    for row in rows:
        wanted.extend(str(path) for path in row.get("expected_paths", []))
    missing: List[str] = []
    seen: Dict[str, bool] = {}
    for address in wanted:
        path = plain_path(address)
        if path in seen:
            continue
        seen[path] = True
        if not os.path.isfile(join_skill(skill_root, path)):
            missing.append("missing routed path: %s" % path)
    return sorted(missing)

# ───────────────────────────────────────────────────────────────
# 6. ENCODING CACHE PIN
# ───────────────────────────────────────────────────────────────

def open_encoder(baseline_root: str) -> Any:
    """Load the pinned lead encoding through the token baseline helpers.

    Args:
        baseline_root: Skill folder that holds scripts/token-baseline.py.

    Returns:
        The o200k_base encoder.

    Raises:
        SystemExit: When the helper, the cache folder or the pin is missing.
    """
    helper = join_skill(baseline_root, BASELINE_HELPER)
    if not os.path.isfile(helper):
        fail("missing token baseline helper: %s" % BASELINE_HELPER)
    spec = importlib.util.spec_from_file_location("route_replay_token_baseline", helper)
    if spec is None or spec.loader is None:
        fail("cannot load token baseline helper: %s" % BASELINE_HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    def token_fail(message: str) -> NoReturn:
        fail(message)

    module.fail = token_fail
    directory = module.cache_dir()
    module.check_cache(directory)
    encoders = module.load_encoders()
    return encoders[module.LEAD_ENCODING]

# ───────────────────────────────────────────────────────────────
# 7. ROUTE RESOLUTION
# ───────────────────────────────────────────────────────────────

def resolve_paths(
    skill_root: str,
    route_type: str,
    text: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    route_rows: List[Dict[str, str]],
) -> List[str]:
    """Resolve the read set of one winning task type.

    Args:
        skill_root: Absolute skill folder.
        route_type: Winning task type.
        text: Lower case request text.
        year: Fixture year for the read set, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        route_rows: Parsed task-type rows for the table-driven fallback.

    Returns:
        Reference paths relative to the skill folder.
    """
    if route_type == "T1":
        paths = [
            "references/migration/shared-mechanisms.md",
            "references/migration/control-framework.md",
        ]
        phases: List[str] = []
        for match in PHASE_RE.finditer(text):
            number = match.group(1)
            before = text[max(0, match.start() - 24):match.start()]
            after = text[match.end():match.end() + 16]
            if PASSED_RE.search(before) or re.match(r"\s+(gehaald|passed|afgerond|doorlopen)\b", after):
                number = str(int(number) + 1)
            phases.append(number)
        if CANCEL_RE.search(text) and "jortt" in text:
            phases.append("22")
        if JORTT_OP_RE.search(text):
            phases.append("22")
        for number in phases:
            phase_path = phase_map.get(number)
            if phase_path and phase_path not in paths:
                paths.append(phase_path)
        # The phase map reaches a named phase directly, so the migration
        # index is read only as the fallback when no phase is named.
        if not phases:
            paths.insert(0, "references/migration/README.md")
        if any(phrase_matches(text, term) for term in ACCESS_TERMS):
            setup = "references/migration/overview-and-setup.md"
            if setup not in paths:
                paths.append(setup)
        return paths
    if route_type == "T2":
        return ["references/migration/jortt-to-moneybird-mapping.md"]
    if route_type == "T3":
        paths = ["references/moneybird-bookkeeping.md"]
        if year:
            paths.append("references/tax-rules/%s/README.md" % year)
        if any(phrase_matches(text, term) for term in VAT_TERMS):
            if year:
                paths.append("references/tax-rules/%s/btw/figures.md" % year)
        if any(phrase_matches(text, term) for term in MONITORING_TERMS):
            paths.extend(["references/migration/README.md", "references/migration/phases-19-to-21.md"])
        return paths
    if route_type == "T4":
        paths = ["references/purchase-invoices.md"]
        if year:
            paths.extend(["references/tax-rules/%s/btw/figures.md" % year, "references/moneybird-bookkeeping.md"])
        if any(phrase_matches(text, term) for term in MIXED_USE_TERMS):
            paths.append("references/mixed-use-costs.md")
        if any(phrase_matches(text, term) for term in FIXED_ASSET_TERMS):
            paths.append("references/fixed-assets.md")
        return paths
    if route_type == "T5":
        if any(phrase_matches(text, term) for term in SOURCE_TERMS):
            return ["references/tax-rules/source-library.md"]
        paths: List[str] = []
        if year:
            paths.append("references/tax-rules/%s/README.md" % year)
            topic = topic_file(text)
            target = topic_map.get(topic)
            if target:
                paths.append(target.replace(YEAR_TOKEN, year).replace("@", "#", 1))
        return paths
    if route_type == "T6":
        return ["references/tax-rules/general/work-relationship-and-procedure.md#310-work-relationship-and-procedure"]
    if route_type == "T9":
        return ["references/migration/overview-and-setup.md"]
    return resolve_table_reads(route_rows, route_type, skill_root, year, phase_map, topic_map)


def resolve_table_reads(
    route_rows: List[Dict[str, str]],
    route_type: str,
    skill_root: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
) -> List[str]:
    """Resolve the required reads of a row the fixed rules do not cover.

    The preparation rows carry their figure reads as `!` items and their
    procedure entry point as a `?` item, so only the required items load.
    The fixture year pins the year token, and the year folders pin it when
    the row carries no year.

    Args:
        route_rows: Parsed task-type rows.
        route_type: Winning task type.
        skill_root: Absolute skill folder.
        year: Fixture year, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.

    Returns:
        The expanded required addresses, anchors in # form.
    """
    row: Optional[Dict[str, str]] = None
    for item in route_rows:
        if item["type"] == route_type:
            row = item
            break
    if row is None:
        return []
    years = [year] if year else year_folders(skill_root)
    paths: List[str] = []
    for mark, item in read_set_items(row["read_set"]):
        if mark != "!":
            continue
        for address in expand_read_item(item, years, phase_map, topic_map):
            converted = address.replace("@", "#", 1)
            if converted and converted not in paths:
                paths.append(converted)
    return paths


def topic_file(text: str) -> str:
    """Pick the year topic folder named by a tax question.

    Args:
        text: Lower case request text.

    Returns:
        One topic folder name.
    """
    for terms, name in TOPIC_SIGNALS:
        for term in terms:
            if phrase_matches(text, term) or term in text:
                return name
    return "kosten-en-auto"


def specificity_winner(text: str, first: str, second: str) -> Optional[str]:
    """Apply the specificity clauses to one tied pair.

    Args:
        text: Lower case request text.
        first: One tied task type.
        second: The other tied task type.

    Returns:
        The decided task type, or None when no clause covers the pair.
    """
    pair = {first, second}
    if pair == {"T4", "T3"} and INVOICE_RE.search(text):
        return "T4"
    if pair == {"T4", "T3"}:
        return "T3"
    if pair == {"T4", "T2"} and INVOICE_RE.search(text):
        return "T4"
    if pair == {"T5", "T6"} and YEAR_RE.search(text):
        return "T5"
    if pair == {"T5", "T4"} and any(phrase_matches(text, term) for term in SOURCE_TERMS):
        return "T5"
    if pair == {"T6", "T4"}:
        return "T6"
    if pair == {"T5", "T4"} and not INVOICE_RE.search(text):
        return "T5"
    if pair == {"T1", "T2"} and (PHASE_RE.search(text) or GATE_RE.search(text)):
        return "T1"
    if pair == {"T1", "T3"} and (PHASE_RE.search(text) or GATE_RE.search(text)):
        return "T1"
    return None


def out_of_scope_hit(text: str) -> bool:
    """Tell whether a request names the out-of-scope boundary.

    A negated mention, as in `do not submit a return`, is not a hit.

    Args:
        text: Lower case request text.

    Returns:
        True when the boundary is named.
    """
    for pattern in OUT_OF_SCOPE_PATTERNS:
        match = re.search(pattern, text)
        if not match:
            continue
        before = text[max(0, match.start() - 24):match.start()]
        if NEGATION_RE.search(before):
            continue
        return True
    return False


def t8_signal_hit(route_rows: List[Dict[str, str]], text: str) -> bool:
    """Tell whether any signal of the refusal row matches one request.

    The scorer reads the filing verbs and the boundary words from the T8
    signal cells. It keeps no list of its own.

    Args:
        route_rows: Parsed task-type rows.
        text: Lower case request text.

    Returns:
        True when one T8 signal matches.
    """
    for row in route_rows:
        if row["type"] != "T8":
            continue
        return any(
            phrase_matches(text, phrase)
            for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"])
        )
    return False


def score_candidates(
    route_rows: List[Dict[str, str]],
    text: str,
    weak_signals: Sequence[str],
) -> Dict[str, int]:
    """Score every task type against one request.

    Args:
        route_rows: Parsed task-type rows.
        text: Lower case request text.
        weak_signals: Phrases that never decide a row.

    Returns:
        Mapping of task type to its matched signal count, zero-count types
        left out.
    """
    scores: Dict[str, int] = {}
    for row in route_rows:
        route_type = row["type"]
        if route_type in ("T7", "T8"):
            continue
        count = 0
        topic_hit = False
        for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"]):
            if phrase.lower() in weak_signals:
                continue
            if phrase_matches(text, phrase):
                if route_type == "T4" and phrase.lower() in T4_TOPIC_TERMS:
                    topic_hit = True
                    continue
                count += 1
        if topic_hit:
            count += 1
        for phrase in EXTRA_SIGNALS.get(route_type, ()):
            if phrase_matches(text, phrase):
                count += 1
        if count:
            scores[route_type] = count
    if "T9" in scores and len(scores) > 1:
        del scores["T9"]
    return scores


def resolve_route(
    route_rows: List[Dict[str, str]],
    skill_root: str,
    prompt: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    constants: Dict[str, Any],
    weak_signals: Sequence[str],
) -> Dict[str, Any]:
    """Resolve one request to a route, a tier and a read set.

    Args:
        route_rows: Parsed task-type rows.
        skill_root: Absolute skill folder.
        prompt: Request text.
        year: Fixture year, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        constants: Routing constants.
        weak_signals: Phrases that never decide a row.

    Returns:
        A route record with mode, type, tier, paths, abstain state, the
        additive flag, the warning band gap and the candidate types.
    """
    text = prompt.lower()
    explicit_year = YEAR_RE.search(text) is not None
    scores = score_candidates(route_rows, text, weak_signals)
    t7_hit = any(
        phrase_matches(text, phrase)
        for row in route_rows
        if row["type"] == "T7"
        for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"])
    )
    t8_hit = t8_signal_hit(route_rows, text)
    # WHY: a filing signal wins over the preparation rows whatever they score.
    if t8_hit:
        for route_type in PREPARE_TYPES:
            scores.pop(route_type, None)
    ordered = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    margin = float(constants.get("route_margin") or 0.25)
    warning = float(constants.get("warning_band") or 0.08)
    floor = float(constants.get("fallback_floor") or 0.0)
    band_gap: Optional[float] = None
    if len(ordered) > 1:
        gap = ordered[0][1] - ordered[1][1]
        if margin <= gap < margin + warning:
            band_gap = round(gap - margin, 6)
    if not ordered:
        if t8_hit or out_of_scope_hit(text):
            return {
                "mode": "ABSTAIN",
                "type": "T8",
                "tier": "A",
                "paths": [],
                "abstain": True,
                "candidates": ["T8"],
                "t7": t7_hit,
                "band_gap": None,
            }
        return {
            "mode": "ABSTAIN",
            "type": "abstain",
            "tier": "B",
            "paths": [],
            "abstain": True,
            "candidates": [],
            "t7": t7_hit,
            "band_gap": None,
        }
    winner = ordered[0][0]
    if ordered[0][1] < floor:
        if out_of_scope_hit(text):
            return {
                "mode": "ABSTAIN",
                "type": "T8",
                "tier": "A",
                "paths": [],
                "abstain": True,
                "candidates": ["T8"],
                "t7": t7_hit,
                "band_gap": None,
            }
        return {
            "mode": "ABSTAIN",
            "type": "abstain",
            "tier": "B",
            "paths": [],
            "abstain": True,
            "candidates": [ordered[0][0]],
            "t7": t7_hit,
            "band_gap": None,
        }
    if len(ordered) > 1 and ordered[0][1] - ordered[1][1] < margin:
        decided = specificity_winner(text, ordered[0][0], ordered[1][0])
        if decided is None:
            return {
                "mode": "ABSTAIN",
                "type": "abstain",
                "tier": "B",
                "paths": [],
                "abstain": True,
                "candidates": sorted([ordered[0][0], ordered[1][0]]),
                "t7": t7_hit,
                "band_gap": None,
            }
        winner = decided
    if winner in ("T5", "T6") and not explicit_year and not year:
        if not any(phrase_matches(text, term) for term in SOURCE_TERMS):
            return {
                "mode": "LIVE",
                "type": winner,
                "tier": "C",
                "paths": [],
                "abstain": True,
                "candidates": [winner],
                "t7": t7_hit,
                "band_gap": band_gap,
            }
    mode = MODE_BY_TYPE.get(winner, "MIGRATION" if t7_hit else "LIVE")
    paths = resolve_paths(skill_root, winner, text, year, phase_map, topic_map, route_rows)
    return {
        "mode": mode,
        "type": winner,
        "tier": "",
        "paths": paths,
        "abstain": False,
        "candidates": [winner],
        "t7": t7_hit,
        "band_gap": band_gap,
    }

# ───────────────────────────────────────────────────────────────
# 8. LOADED TEXT AND TOKENS
# ───────────────────────────────────────────────────────────────

def section_text(
    skill_root: str,
    address: str,
    cache: Dict[str, Dict[str, Any]],
    encoder: Any,
    strict: bool = True,
) -> str:
    """Return the text of one file read or one section read.

    Args:
        skill_root: Absolute skill folder.
        address: Path with an optional #anchor suffix.
        cache: Per-run cache of file texts and section ranges.
        encoder: Pinned encoder.
        strict: Stop with exit 2 on an unreadable file. False returns an
            empty text so a revision run can score the row as a finding.

    Returns:
        The text of the read.
    """
    path, _, anchor = address.partition("#")
    absolute = join_skill(skill_root, path)
    if path not in cache:
        if strict:
            text = read_text(absolute)
        else:
            try:
                with open(absolute, "r", encoding="utf-8") as handle:
                    text = handle.read()
            except OSError:
                text = ""
        h2 = {}
        for section in section_index(text):
            h2[section["anchor"]] = section["text"]
        cache[path] = {"text": text, "sections": h2, "toc": parse_toc_ranges(text)}
    entry = cache[path]
    if not anchor:
        return entry["text"]
    if anchor in entry["sections"]:
        return entry["sections"][anchor]
    if anchor in entry["toc"]:
        start, end = entry["toc"][anchor]
        lines = entry["text"].splitlines(keepends=True)
        return "".join(lines[start - 1:end])
    return entry["text"]


def section_index(text: str) -> List[Dict[str, Any]]:
    """Split one markdown file into its H2 sections.

    Args:
        text: File text.

    Returns:
        Rows with the anchor and the section text, in file order.
    """
    spans: List[Tuple[int, str, int]] = []
    start = 0
    number = 0
    while start < len(text):
        newline = text.find("\n", start)
        if newline == -1:
            number += 1
            spans.append((number, text[start:].rstrip("\r"), start))
            break
        number += 1
        spans.append((number, text[start:newline].rstrip("\r"), start))
        start = newline + 1
    in_code = False
    headings: List[Tuple[int, str, int]] = []
    for line_number, content, offset in spans:
        if content.strip().startswith("```") or content.strip().startswith("~~~"):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = re.match(r"^##\s+(.*?)\s*$", content)
        if not match:
            continue
        title = match.group(1).strip()
        anchor = re.sub(r"[^\w\s-]", "", title.lower(), flags=re.UNICODE)
        anchor = re.sub(r"\s+", "-", anchor.strip())
        headings.append((line_number, anchor, offset))
    rows: List[Dict[str, Any]] = []
    for index, (line_number, anchor, offset) in enumerate(headings):
        stop = headings[index + 1][2] if index + 1 < len(headings) else len(text)
        rows.append({"anchor": anchor, "line": line_number, "text": text[offset:stop]})
    return rows


def count_tokens(encoder: Any, text: str) -> int:
    """Count the tokens of one text in the pinned encoding.

    Args:
        encoder: Pinned encoder.
        text: Text to count.

    Returns:
        The token count.
    """
    return len(encoder.encode_ordinary(text))


def loaded_material(
    skill_root: str,
    paths: Sequence[str],
    cache: Dict[str, Dict[str, Any]],
    encoder: Any,
    strict: bool = True,
) -> Tuple[int, List[str]]:
    """Count and collect the loaded material of one read set.

    Args:
        skill_root: Absolute skill folder.
        paths: Read set addresses.
        cache: Per-run cache of file texts and section ranges.
        encoder: Pinned encoder.
        strict: Stop with exit 2 on a missing read file.

    Returns:
        The token sum and the loaded texts in read-set order.
    """
    tokens = 0
    texts: List[str] = []
    for address in paths:
        text = section_text(skill_root, address, cache, encoder, strict)
        tokens += count_tokens(encoder, text)
        texts.append(text)
    return tokens, texts

# ───────────────────────────────────────────────────────────────
# 9. ROW SCORING
# ───────────────────────────────────────────────────────────────

def base_path(address: str) -> str:
    """Return the file part of one read address.

    Args:
        address: Path with an optional #anchor suffix.

    Returns:
        The path without the suffix.
    """
    return strip_anchor(address)


def check_claims(skill_root: str, row: Dict[str, Any]) -> List[str]:
    """Check the file claims one corpus row asserts against the revision.

    A claim names a path and a text. The text must appear in that file of
    the scored revision, so a row can guard content its read set does not
    load, such as a route class line or a section of the skill markdown.

    Args:
        skill_root: Absolute skill folder of the scored revision.
        row: Corpus row with an expected_claims list.

    Returns:
        One message per claim whose file or text is not present.
    """
    missing: List[str] = []
    for claim in row.get("expected_claims", []):
        if not isinstance(claim, dict):
            missing.append(str(claim))
            continue
        path = strip_anchor(str(claim.get("path", "")))
        wanted = str(claim.get("text", ""))
        try:
            with open(join_skill(skill_root, path), "r", encoding="utf-8") as handle:
                content = handle.read()
        except OSError:
            missing.append("%s: %s" % (path, wanted))
            continue
        if wanted not in content:
            missing.append("%s: %s" % (path, wanted))
    return missing


def score_row(
    skill_root: str,
    row: Dict[str, Any],
    route: Dict[str, Any],
    cache: Dict[str, Dict[str, Any]],
    encoder: Any,
    strict: bool = True,
) -> Dict[str, Any]:
    """Score one corpus row against its resolved route.

    Args:
        skill_root: Absolute skill folder.
        row: Corpus row.
        route: Resolved route.
        cache: Per-run cache of file texts and section ranges.
        encoder: Pinned encoder.
        strict: Stop with exit 2 on a missing read file. False reports the
            missing path as a row problem instead.

    Returns:
        The row result with score, verdict, reason, tokens and facts found.
    """
    expected_paths = [str(path) for path in row.get("expected_paths", [])]
    forbidden = [base_path(str(path)) for path in row.get("forbidden_paths", [])]
    loaded = [base_path(str(path)) for path in route["paths"]]
    tokens_loaded, texts = loaded_material(skill_root, route["paths"], cache, encoder, strict)
    combined = "\n".join(texts).lower()
    facts = [str(fact) for fact in row.get("expected_facts", [])]
    facts_found = [fact for fact in facts if fact.lower() in combined]
    missing_claims = check_claims(skill_root, row)
    missing_paths = [path for path in expected_paths if path not in route["paths"]]
    hit_forbidden = [path for path in forbidden if path in loaded]
    ceiling = int(row.get("token_ceiling", 0))

    problems: List[str] = []
    if not strict:
        missing_reads = [path for path in loaded if not os.path.isfile(join_skill(skill_root, path))]
        if missing_reads:
            problems.append("read paths missing on disk %s" % ", ".join(missing_reads))
    if route["mode"] != row.get("gold_mode"):
        problems.append("mode %s expected %s" % (route["mode"], row.get("gold_mode")))
    if route["type"] != row.get("gold_task_type"):
        problems.append("task type %s expected %s" % (route["type"], row.get("gold_task_type")))
    if missing_paths:
        problems.append("paths not loaded %s" % ", ".join(missing_paths))
    if hit_forbidden:
        problems.append("forbidden paths loaded %s" % ", ".join(hit_forbidden))
    if len(facts_found) != len(facts):
        missing_facts = [fact for fact in facts if fact not in facts_found]
        problems.append("facts not found %s" % ", ".join(missing_facts))
    if missing_claims:
        problems.append("claims not met %s" % ", ".join(missing_claims))
    if tokens_loaded > ceiling:
        problems.append("tokens %d above ceiling %d" % (tokens_loaded, ceiling))
    if route["type"] == "T7":
        problems.append("additive row T7 won alone")
    if "t7" in row and bool(route.get("t7")) != bool(row.get("t7")):
        problems.append("t7 additive hit %s expected %s" % (bool(route.get("t7")), bool(row.get("t7"))))
    score = 5 - len(problems)
    if problems:
        reason = ". ".join(problems)
    else:
        reason = "route, read set, facts, claims and tokens match"
    return {
        "scenario_id": row.get("id", ""),
        "lang": row.get("lang", ""),
        "split": row.get("split", ""),
        "gold_mode": row.get("gold_mode", ""),
        "gold_task_type": row.get("gold_task_type", ""),
        "score": str(score),
        "verdict": "PASS" if not problems else "FAIL",
        "reason": reason,
        "tokens_loaded": str(tokens_loaded),
        "t7": "1" if route.get("t7") else "0",
        "reads": str(len(route.get("paths", []))),
        "band_gap": route.get("band_gap"),
        "facts_found": len(facts_found),
        "expected_facts": len(facts),
        "tier": route["tier"],
        "route": "%s/%s" % (route["mode"], route["type"]),
        "abstain": bool(route["abstain"]),
    }

# ───────────────────────────────────────────────────────────────
# 10. PARITY
# ───────────────────────────────────────────────────────────────

def parity_findings(
    rows: List[Dict[str, Any]],
    resolutions: Dict[str, Dict[str, Any]],
    strict: bool = True,
) -> List[str]:
    """Compare every Dutch twin with its English pair.

    Route equality covers the gold route, the resolved route, the tier and
    the resolved read set. It never compares answer text. A filtered run
    skips a pair whose other half is not selected, because that half is out
    of scope for the run.

    Args:
        rows: Corpus rows.
        resolutions: Resolved route per row id.
        strict: Report a pair whose other half is missing from the selection.

    Returns:
        One finding line per mismatched twin pair.
    """
    by_id = {str(row.get("id", "")): row for row in rows}
    findings: List[str] = []
    for row in rows:
        twin_id = str(row.get("parityOf", "") or "")
        if not twin_id:
            continue
        twin = by_id.get(twin_id)
        if twin is None:
            if strict:
                findings.append("parity pair %s names a missing twin %s" % (row.get("id", ""), twin_id))
            continue
        matches = (
            row.get("gold_mode") == twin.get("gold_mode")
            and row.get("gold_task_type") == twin.get("gold_task_type")
            and resolutions[str(row.get("id", ""))]["mode"] == resolutions[twin_id]["mode"]
            and resolutions[str(row.get("id", ""))]["type"] == resolutions[twin_id]["type"]
            and resolutions[str(row.get("id", ""))]["tier"] == resolutions[twin_id]["tier"]
            and sorted(resolutions[str(row.get("id", ""))]["paths"]) == sorted(resolutions[twin_id]["paths"])
        )
        if not matches:
            findings.append(
                "parity mismatch %s against %s" % (row.get("id", ""), twin_id)
            )
    return findings

# ───────────────────────────────────────────────────────────────
# 11. RESOLVE MODE
# ───────────────────────────────────────────────────────────────

def load_corpus(path: str) -> List[Dict[str, Any]]:
    """Read the fixture corpus.

    Args:
        path: Corpus file.

    Returns:
        The corpus rows.

    Raises:
        SystemExit: When the file is unreadable, is not an object with rows
        or holds no row.
    """
    if not os.path.isfile(path):
        fail("corpus not found: %s" % os.path.basename(path))
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read corpus: %s" % exc)
    rows = data.get("rows") if isinstance(data, dict) else None
    if not isinstance(rows, list) or not rows:
        fail("corpus holds no rows: %s" % os.path.basename(path))
    return rows


def accuracy(rows: List[Dict[str, Any]], results: List[Dict[str, Any]], predicate: Any) -> Tuple[int, int]:
    """Count the route matches over a row subset.

    Args:
        rows: Corpus rows.
        results: Scored rows in corpus order.
        predicate: Callable that selects the subset.

    Returns:
        The matched count and the subset count.
    """
    matched = 0
    total = 0
    for row, result in zip(rows, results):
        if not predicate(row, result):
            continue
        total += 1
        if result["route"] == "%s/%s" % (row.get("gold_mode"), row.get("gold_task_type")):
            matched += 1
    return matched, total


def ratio_text(matched: int, total: int) -> str:
    """Render one accuracy fraction.

    Args:
        matched: Matched rows.
        total: Rows in the subset.

    Returns:
        A text such as 12/12 (1.000).
    """
    value = 1.0 if total == 0 else round(matched / total, 3)
    return "%d/%d (%.3f)" % (matched, total, value)


def metric_text(matched: int, total: int) -> str:
    """Render one precision or recall fraction with its denominator.

    Args:
        matched: Correct rows.
        total: Denominator rows, zero when no row covers the type.

    Returns:
        A text such as 12/15 (0.800), or 0/0 (n/a) when no row covers the
        type.
    """
    if total == 0:
        return "0/0 (n/a)"
    return "%d/%d (%.3f)" % (matched, total, matched / total)


def write_results(path: str, results: List[Dict[str, Any]], columns: Sequence[str] = RESULT_COLUMNS) -> None:
    """Write results.csv with a fixed column order.

    Args:
        path: Output file.
        results: Scored rows.
        columns: Column names in output order.

    Raises:
        SystemExit: When the file cannot be written.
    """
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(columns), lineterminator="\n")
            writer.writeheader()
            for result in results:
                writer.writerow({column: result.get(column, "") for column in columns})
    except OSError as exc:
        fail("cannot write results: %s" % exc)


def write_report(
    path: str,
    snapshot_hash: str,
    corpus_name: str,
    rows: List[Dict[str, Any]],
    results: List[Dict[str, Any]],
    parity: List[str],
    constants: Dict[str, Any],
    revision: str = "",
) -> None:
    """Write report.md with the accuracy lines and the four metric sections.

    Args:
        path: Output file.
        snapshot_hash: Router snapshot hash.
        corpus_name: Corpus file name.
        rows: Corpus rows.
        results: Scored rows in corpus order.
        parity: Parity findings.
        constants: Routing constants.
        revision: Full revision text, empty on a live run.

    Raises:
        SystemExit: When the file cannot be written.
    """
    total = len(results)
    passed = sum(1 for result in results if result["verdict"] == "PASS")
    abstained = sum(1 for result in results if result["tier"] in ("A", "B"))
    tier_c = sum(1 for result in results if result["tier"] == "C")
    false_abstain = sum(
        1
        for row, result in zip(rows, results)
        if result["tier"] in ("A", "B") and row.get("gold_mode") != "ABSTAIN"
    )
    monthly = "calibration: pending" if constants.get("fallback_floor_pending") else str(constants.get("fallback_floor"))
    languages = ("en", "nl", "mixed")
    splits = ("calibration", "held-out")
    languages_accuracy = {
        language: accuracy(rows, results, lambda row, _result, value=language: row.get("lang") == value)
        for language in languages
    }
    splits_accuracy = {
        split: accuracy(rows, results, lambda row, _result, value=split: row.get("split") == value)
        for split in splits
    }
    lines: List[str] = []
    lines.append("# Route replay report")
    lines.append("")
    lines.append("Router snapshot: sha256:%s" % snapshot_hash)
    lines.append("Mode: resolve")
    if revision:
        lines.append("Revision: %s" % revision[:12])
    lines.append("Corpus: %s with %d rows" % (corpus_name, total))
    lines.append("Token encoding: o200k_base from the pinned cache")
    lines.append("Route margin: %s. Warning band: %s. Fallback floor: %s." % (
        constants.get("route_margin"),
        constants.get("warning_band"),
        monthly,
    ))
    lines.append("")
    lines.append("## Scored dimensions")
    lines.append("")
    lines.append("- Route: scored, mode and task type against the gold route.")
    lines.append("- Read set: scored, expected paths loaded and forbidden paths absent.")
    lines.append("- Connectivity: scored by the gate before any row is scored.")
    lines.append("- Answer quality: unscored. No judge model grades an answer.")
    lines.append("")
    lines.append("## Accuracy")
    lines.append("")
    for language in languages:
        matched, size = languages_accuracy[language]
        lines.append("- route accuracy %s: %s" % (language, ratio_text(matched, size)))
    for split in splits:
        matched, size = splits_accuracy[split]
        lines.append("- route accuracy %s: %s" % (split, ratio_text(matched, size)))
    held_matched, held_total = splits_accuracy["held-out"]
    lines.append("- held-out route accuracy: %s" % ratio_text(held_matched, held_total))
    lines.append("- rows passed: %d of %d" % (passed, total))
    lines.append("- abstain: %d of %d expected" % (
        abstained,
        sum(1 for row in rows if row.get("gold_mode") == "ABSTAIN"),
    ))
    lines.append("- missing tax year, tier C: %d" % tier_c)
    lines.append("- false abstain: %d" % false_abstain)
    pair_total = sum(1 for row in rows if row.get("parityOf"))
    lines.append("- Dutch parity: %d of %d twin pairs match" % (pair_total - len(parity), pair_total))
    for finding in parity:
        lines.append("- %s" % finding)
    lines.append("")
    lines.append("## Additive T7 assertion")
    lines.append("")
    lines.append(
        "The additive CLI row never wins alone. A row whose prompt matches a T7 signal keeps the row it matched and appends the sibling tool skill."
    )
    lines.append("")
    t7_rows = [result for result in results if result.get("t7") == "1"]
    t7_alone = [result for result in results if result["route"].endswith("/T7")]
    lines.append("- rows matching a T7 signal: %d" % len(t7_rows))
    lines.append("- additive row wins alone: %d" % len(t7_alone))
    for result in t7_rows:
        lines.append("- %s: T7 signal with route %s" % (result["scenario_id"], result["route"]))
    lines.append("")
    lines.append("## Per-type precision and recall")
    lines.append("")
    lines.append(
        "Precision divides the correct routes by the rows routed to that type. Recall divides them by the rows whose gold type it is."
    )
    lines.append("")
    gold_types: Dict[str, int] = {route_type: 0 for route_type in REPORT_TYPES}
    routed_types: Dict[str, int] = {route_type: 0 for route_type in REPORT_TYPES}
    correct_types: Dict[str, int] = {route_type: 0 for route_type in REPORT_TYPES}
    for row, result in zip(rows, results):
        gold_type = str(row.get("gold_task_type", ""))
        resolved = result["route"].split("/", 1)[1] if "/" in result["route"] else ""
        if gold_type in gold_types:
            gold_types[gold_type] += 1
        if resolved in routed_types:
            routed_types[resolved] += 1
        if resolved in correct_types and gold_type == resolved:
            correct_types[resolved] += 1
    for route_type in REPORT_TYPES:
        correct = correct_types[route_type]
        lines.append(
            "- %s precision %s, recall %s"
            % (
                route_type,
                metric_text(correct, routed_types[route_type]),
                metric_text(correct, gold_types[route_type]),
            )
        )
    lines.append("")
    lines.append("## Read counts")
    lines.append("")
    lines.append("| scenario | route | reads |")
    lines.append("|---|---|---:|")
    for result in results:
        lines.append("| %s | %s | %s |" % (result["scenario_id"], result["route"], result["reads"]))
    lines.append("")
    lines.append("## Warning band sink")
    lines.append("")
    lines.append(
        "Rows whose winning gap sits in the %s warning band above the route margin. Telemetry only, the route never changes."
        % constants.get("warning_band")
    )
    lines.append("")
    band_rows = [result for result in results if result.get("band_gap") is not None]
    if band_rows:
        for result in band_rows:
            lines.append("- %s: %.3f above the margin" % (result["scenario_id"], float(result["band_gap"])))
    else:
        lines.append("- none")
    lines.append("")
    lines.append("## Rows")
    lines.append("")
    lines.append("| scenario | lang | split | route | tokens loaded | facts found | verdict |")
    lines.append("|---|---|---|---|---:|---|---|")
    for row, result in zip(rows, results):
        lines.append("| %s | %s | %s | %s | %s | %d of %d | %s |" % (
            result["scenario_id"],
            result["lang"],
            result["split"],
            result["route"],
            result["tokens_loaded"],
            result["facts_found"],
            result["expected_facts"],
            result["verdict"],
        ))
    lines.append("")
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write("\n".join(lines))
    except OSError as exc:
        fail("cannot write report: %s" % exc)


def write_unscorable(
    args: argparse.Namespace,
    rows: List[Dict[str, Any]],
    reason: str,
    revision: str,
) -> int:
    """Write a failure result for every selected row.

    The revision run reaches this path when the worktree of an older commit
    holds no route table or no signal file, because that missing content is
    the regression the row guards.

    Args:
        args: Parsed command line.
        rows: Selected resolve rows.
        reason: Why the rows cannot be scored.
        revision: Full revision text, empty on a live run.

    Returns:
        1, because every selected row is a finding.
    """
    problems = "unscorable: %s" % reason
    if revision:
        problems = "%s at revision %s" % (problems, revision[:12])
    results: List[Dict[str, Any]] = []
    for row in rows:
        results.append(
            {
                "scenario_id": row.get("id", ""),
                "lang": row.get("lang", ""),
                "split": row.get("split", ""),
                "gold_mode": row.get("gold_mode", ""),
                "gold_task_type": row.get("gold_task_type", ""),
                "score": "0",
                "verdict": "FAIL",
                "reason": problems,
                "tokens_loaded": "0",
            }
        )
    out_dir = os.path.abspath(args.out)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create output folder: %s" % os.path.basename(out_dir))
    write_results(os.path.join(out_dir, "results.csv"), results)
    lines = [
        "# Route replay report",
        "",
        "Mode: resolve",
    ]
    if revision:
        lines.append("Revision: %s" % revision[:12])
    lines.append("Corpus: %s with %d rows" % (os.path.basename(args.corpus), len(results)))
    lines.append("")
    lines.append("## Findings")
    lines.append("")
    lines.append("- %s" % problems)
    lines.append("- rows passed: 0 of %d" % len(results))
    lines.append("")
    try:
        with open(os.path.join(out_dir, "report.md"), "w", encoding="utf-8", newline="") as handle:
            handle.write("\n".join(lines))
    except OSError as exc:
        fail("cannot write report: %s" % exc)
    print("%s: %s" % (PROGRAM, problems))
    return 1


def run_resolve(args: argparse.Namespace) -> int:
    """Score the corpus in resolve mode and write the outputs.

    Args:
        args: Parsed command line.

    Returns:
        0 when every row passes, 1 on a row or parity finding.
    """
    skill_root = os.path.abspath(args.skill_root)
    revision = str(getattr(args, "rev_sha", "") or "")
    rev_mode = bool(revision)
    skill_md = join_skill(skill_root, SKILL_MD_NAME)
    signals_md = join_skill(skill_root, SIGNALS_NAME)
    if not os.path.isfile(skill_md):
        fail("skill markdown not found in %s" % os.path.basename(skill_root))
    rows = select_rows(load_corpus(args.corpus), args.covers, "resolve")
    if not rows:
        fail("no resolve rows match the covers filter")
    skill_text = read_text(skill_md)
    if rev_mode and (START_MARKER not in skill_text or END_MARKER not in skill_text):
        return write_unscorable(args, rows, "route table markers missing", revision)
    if not os.path.isfile(signals_md):
        if rev_mode:
            return write_unscorable(args, rows, "routing signals file missing", revision)
        fail("routing signals file not found in %s" % os.path.basename(skill_root))
    signals_text = read_text(signals_md)
    weak_signals = parse_weak_signals(signals_text)
    route_rows = parse_route_table(skill_text)
    constants = parse_constants(skill_text, signals_text)
    if rev_mode and ("PHASE_FILES = {" not in skill_text or "TOPIC_FILES = {" not in skill_text):
        return write_unscorable(args, rows, "generated router maps missing", revision)
    phase_map = parse_generated_map(skill_text, "PHASE_FILES")
    topic_map = parse_generated_map(skill_text, "TOPIC_FILES")
    if not rev_mode:
        check_phase_agreement(skill_root, phase_map)
    resources = load_resource_map(skill_root)
    snapshot, snapshot_hash = build_snapshot(route_rows, constants, phase_map, resources)
    del snapshot

    required, _conditional = routed_paths(route_rows, skill_root, phase_map, topic_map)
    if not rev_mode:
        missing = connectivity_report(skill_root, rows, required)
        if missing:
            for line in missing:
                print(line)
            print("connectivity gate failed: %d missing path(s)" % len(missing))
            return 2

    baseline_root = str(getattr(args, "baseline_root", "") or skill_root)
    encoder = open_encoder(baseline_root)
    cache: Dict[str, Dict[str, Any]] = {}
    resolutions: Dict[str, Dict[str, Any]] = {}
    results: List[Dict[str, Any]] = []
    for row in rows:
        prompt = str(row.get("prompt", ""))
        previous = str(row.get("previous_prompt", "") or "")
        if previous:
            prompt = previous + " " + prompt
        year = str(row.get("year", ""))
        route = resolve_route(route_rows, skill_root, prompt, year, phase_map, topic_map, constants, weak_signals)
        result = score_row(skill_root, row, route, cache, encoder, strict=not rev_mode)
        if previous:
            first = resolve_route(route_rows, skill_root, previous, year, phase_map, topic_map, constants, weak_signals)
            expected_type = str(row.get("previous_gold_task_type", "") or "")
            expected_mode = str(row.get("previous_gold_mode", "") or "")
            turn_problems: List[str] = []
            if expected_type and first["type"] != expected_type:
                turn_problems.append("first turn type %s expected %s" % (first["type"], expected_type))
            if expected_mode and first["mode"] != expected_mode:
                turn_problems.append("first turn mode %s expected %s" % (first["mode"], expected_mode))
            if not expected_type and not expected_mode and not first["abstain"]:
                turn_problems.append("first turn did not abstain")
            if turn_problems:
                result["verdict"] = "FAIL"
                result["score"] = str(max(0, int(result["score"]) - 1))
                result["reason"] = ". ".join(turn_problems) + ". " + result["reason"]
        resolutions[str(row.get("id", ""))] = route
        results.append(result)

    parity = parity_findings(rows, resolutions, strict=not args.covers)
    out_dir = os.path.abspath(args.out)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create output folder: %s" % os.path.basename(out_dir))
    write_results(os.path.join(out_dir, "results.csv"), results)
    write_report(
        os.path.join(out_dir, "report.md"),
        snapshot_hash,
        os.path.basename(args.corpus),
        rows,
        results,
        parity,
        constants,
        revision,
    )
    failed = sum(1 for result in results if result["verdict"] == "FAIL")
    if failed or parity:
        for finding in parity:
            print(finding)
        print("%s: %d row finding(s), %d parity finding(s)" % (PROGRAM, failed, len(parity)))
        return 1
    print("%s: ok, %d rows passed" % (PROGRAM, len(results)))
    return 0

# ───────────────────────────────────────────────────────────────
# 12. REPLAY MODE
# ───────────────────────────────────────────────────────────────

def guard_and_stub(args: argparse.Namespace) -> Tuple[str, str]:
    """Resolve the guard and the stub CLI to replay.

    Args:
        args: Parsed command line.

    Returns:
        The guard path and the stub path.
    """
    repo_root = os.path.abspath(str(getattr(args, "repo_root", os.path.dirname(SKILL_ROOT))))
    guard = str(getattr(args, "guard", "") or "")
    stub = str(getattr(args, "stub", "") or "")
    if not guard:
        guard = os.path.join(repo_root, GUARD_RELATIVE)
    if not stub:
        stub = os.path.join(repo_root, STUB_RELATIVE)
    return guard, stub


def hostile_body(skill_root: str, case_id: str) -> Tuple[Optional[str], str]:
    """Build the dry-run body of one hostile invoice case.

    Every placeholder is replaced with a run-time generated token, so the
    template never carries a literal value.

    Args:
        skill_root: Absolute skill folder.
        case_id: Case id from the hostile invoice set.

    Returns:
        The body text and an empty error text, or None and the error text.
    """
    path = join_skill(skill_root, HOSTILE_CASES)
    if not os.path.isfile(path):
        return None, "hostile case set missing"
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, "cannot read the hostile case set: %s" % exc
    case = None
    for item in data.get("cases", []):
        if isinstance(item, dict) and str(item.get("id")) == case_id:
            case = item
            break
    if case is None:
        return None, "hostile case missing: %s" % case_id
    body = str(case.get("template", ""))
    for placeholder in data.get("placeholders", []):
        body = body.replace(str(placeholder), "x" + secrets.token_hex(6))
    return body, ""


def approval_reference(command: Sequence[str]) -> str:
    """Read the approval reference out of one guard command line.

    Args:
        command: Guard arguments for one replay row.

    Returns:
        The reference after --approval, or APPROVED-1 when absent.
    """
    parts = [str(part) for part in command]
    for index, part in enumerate(parts):
        if part == "--approval" and index + 1 < len(parts):
            return parts[index + 1]
    return "APPROVED-1"


def write_journal(path: str, row: Dict[str, Any], digest: str) -> None:
    """Write the run journal entry one replay row needs.

    Args:
        path: Journal file under the run-owned temp root.
        row: Corpus row.
        digest: Digest of the approved payload, computed at run time.
    """
    intent = row.get("intent")
    if intent is None:
        if os.path.exists(path):
            os.remove(path)
        return
    reference = approval_reference(row.get("command", []))
    entry: Dict[str, str] = {
        "approval_reference": reference,
        "new_state": "WRITE_INTENT",
        "batch_key": "batch-replay",
    }
    if intent in ("match", "mismatch"):
        entry["payload_digest"] = digest
        entry["attachment_digest"] = ""
    directory = os.path.dirname(path)
    if not os.path.isdir(directory):
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(entry) + "\n")


def replay_row(
    row: Dict[str, Any],
    guard: str,
    base_env: Dict[str, str],
    stub_log: str,
    journal: str,
    key_file: str,
    skill_root: str,
    temp_root: str,
) -> Dict[str, Any]:
    """Replay one refusal or hostile row and score its exit code.

    Args:
        row: Corpus row with an expected_exit code.
        guard: Guard script to run.
        base_env: Test environment for the guard.
        stub_log: Stub invocation log.
        journal: Run journal under the temp root.
        key_file: Generated HMAC key file.
        skill_root: Skill folder that holds the hostile case set.
        temp_root: Run-owned temp root.

    Returns:
        The replay result row.
    """
    env = dict(base_env)
    row_env = row.get("env", {})
    if isinstance(row_env, dict):
        for name, value in row_env.items():
            text = str(value)
            if text == MISSING_WRITER_MARKER:
                text = os.path.join(temp_root, "missing-writer-config")
            env[str(name)] = text
    command = [str(part) for part in row.get("command", [])]
    expected_exit = int(row.get("expected_exit", 0))
    dry_body = row.get("dry_body")
    problems: List[str] = []
    if row.get("kind") == "hostile":
        dry_body, error = hostile_body(skill_root, str(row.get("case_id", "")))
        if error:
            problems.append(error)
    if dry_body is not None:
        env["MONEYBIRD_TEST_DRY_BODY"] = str(dry_body)
    preview_line = ""
    preview_digest = ""
    if row.get("intent") is not None:
        preview_command = [part for part in command if part != "--confirm-write"]
        _preview_status, preview_output = run_process([guard] + preview_command, env)
        preview_line, preview_digest = parse_preview(preview_output)
    digest = preview_digest
    if row.get("intent") == "mismatch":
        digest = flip_digest(preview_digest)
    write_journal(journal, row, digest)
    key_backup = ""
    if row.get("remove_key") and os.path.isfile(key_file):
        key_backup = key_file + ".away"
        os.rename(key_file, key_backup)
    try:
        if row.get("warmup"):
            run_process([guard] + command, env)
        try:
            before_size = os.path.getsize(stub_log)
        except OSError:
            before_size = 0
        status, output = run_process([guard] + command, env)
    finally:
        if key_backup and not os.path.isfile(key_file):
            os.rename(key_backup, key_file)
    new_log = ""
    try:
        with open(stub_log, "r", encoding="utf-8", errors="replace") as handle:
            handle.seek(before_size)
            new_log = handle.read()
    except OSError:
        new_log = ""

    if status != expected_exit:
        problems.append("exit %d, expected %d" % (status, expected_exit))
    expected_stderr = str(row.get("expect_stderr", "") or "")
    if expected_stderr and expected_stderr not in output:
        problems.append("output does not name %r" % expected_stderr)
    if row.get("expect_digest") and not re.search(r"(?m)^payload-digest: [0-9a-f]{64}$", output):
        problems.append("no payload-digest line")
    expected_cli = str(row.get("expect_cli", "") or "")
    if row.get("expect_cli_printed") and expected_cli and expected_cli not in output:
        problems.append("dry-run line %r not printed" % expected_cli)
    if row.get("expect_real"):
        if expected_cli and ("REAL " + expected_cli) not in new_log:
            problems.append("real call %r not recorded" % expected_cli)
        elif not expected_cli and "REAL " not in new_log:
            problems.append("no real call recorded")
    elif "REAL " in new_log:
        problems.append("real call reached")
    if not preview_line and expected_cli and row.get("intent") is not None:
        problems.append("dry run printed no command line")

    return {
        "scenario_id": str(row.get("id", "")),
        "lang": str(row.get("lang", "")),
        "split": str(row.get("split", "")),
        "gold_mode": "REPLAY",
        "gold_task_type": str(row.get("kind", "")),
        "score": "1" if not problems else "0",
        "verdict": "PASS" if not problems else "FAIL",
        "reason": "; ".join(problems) if problems else "exit and command line match",
        "tokens_loaded": "0",
        "t7": "0",
        "reads": "0",
        "command": " ".join(command),
        "expected_exit": str(expected_exit),
        "actual_exit": str(status),
    }


def write_replay_report(
    path: str,
    rows: List[Dict[str, Any]],
    results: List[Dict[str, Any]],
    revision: str,
    guard: str,
    stub: str,
) -> None:
    """Write the replay report with one row per refusal and its exit code.

    Args:
        path: Output file.
        rows: Replay rows.
        results: Replay results in row order.
        revision: Full revision text, empty on a live run.
        guard: Guard that was replayed, as a display path.
        stub: Stub that was replayed, as a display path.

    Raises:
        SystemExit: When the file cannot be written.
    """
    passed = sum(1 for result in results if result["verdict"] == "PASS")
    lines: List[str] = ["# Route replay report", "", "Mode: replay"]
    if revision:
        lines.append("Revision: %s" % revision[:12])
    lines.append("Corpus: %d replay rows" % len(results))
    lines.append("Guard: %s" % os.path.basename(guard))
    lines.append("Stub: %s" % os.path.basename(stub))
    lines.append("")
    lines.append("## Rows")
    lines.append("")
    lines.append("| scenario | kind | command | expected exit | actual exit | verdict |")
    lines.append("|---|---|---|---:|---:|---|")
    for row, result in zip(rows, results):
        lines.append(
            "| %s | %s | %s | %s | %s | %s |"
            % (
                result["scenario_id"],
                result["gold_task_type"],
                result["command"],
                result["expected_exit"],
                result["actual_exit"],
                result["verdict"],
            )
        )
    hostile = [result for result in results if result["gold_task_type"] == "hostile"]
    refused = sum(1 for result in results if result["expected_exit"] != "0")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("- rows passed: %d of %d" % (passed, len(results)))
    lines.append("- refusal rows: %d" % refused)
    lines.append("- hostile case rows: %d" % len(hostile))
    for result in results:
        if result["verdict"] != "PASS":
            lines.append("- %s: %s" % (result["scenario_id"], result["reason"]))
    lines.append("")
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write("\n".join(lines))
    except OSError as exc:
        fail("cannot write report: %s" % exc)


def run_replay(args: argparse.Namespace) -> int:
    """Replay refusal fixtures through the guard stub.

    Args:
        args: Parsed command line.

    Returns:
        0 when every row returns its recorded exit, 1 on a row finding and
        2 when the guard or the stub is missing.
    """
    skill_root = os.path.abspath(args.skill_root)
    revision = str(getattr(args, "rev_sha", "") or "")
    rows = select_rows(load_corpus(args.corpus), args.covers, "replay")
    if not rows:
        fail("no replay rows match the covers filter")
    guard, stub = guard_and_stub(args)
    if not os.path.isfile(guard):
        fail("guard not found: %s" % guard)
    if not os.path.isfile(stub):
        fail("stub not found: %s" % stub)
    temp_root = tempfile.mkdtemp(prefix="route-replay-replay.", dir=os.environ.get("TMPDIR") or "/tmp")
    try:
        home = os.path.join(temp_root, "home")
        accountant = os.path.join(temp_root, "accountant")
        writer_config = os.path.join(temp_root, "writer-config")
        workspace = os.path.join(accountant, "migration-workspace")
        os.makedirs(os.path.join(home, ".config", "moneybird-cli-writer"))
        os.makedirs(os.path.join(workspace, "RunJournal"))
        os.makedirs(writer_config)
        key_dir = os.path.join(workspace, ".secrets")
        os.makedirs(key_dir, mode=0o700)
        key_file = os.path.join(key_dir, "alias-hmac.key")
        with open(key_file, "w", encoding="utf-8") as handle:
            handle.write(secrets.token_hex(32))
        os.chmod(key_file, 0o600)
        journal = os.path.join(workspace, "RunJournal", "run-journal.jsonl")
        stub_log = os.path.join(temp_root, "invocations.log")
        with open(stub_log, "w", encoding="utf-8"):
            pass
        base_env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": home,
            "LANG": os.environ.get("LANG", "C"),
            "MONEYBIRD_GUARD_TEST": "1",
            "MONEYBIRD_ENV_DIR": accountant,
            "MONEYBIRD_CLI": stub,
            "MONEYBIRD_TEST_LOG": stub_log,
            "MONEYBIRD_TEST_ADMINISTRATION_ID": "PILOT_ADMIN",
            "MONEYBIRD_WRITER_CONFIG_DIR": writer_config,
            "MONEYBIRD_HMAC_KEY_FILE": key_file,
            "MONEYBIRD_PILOT_ADMINISTRATION_ID": "PILOT_ADMIN",
        }
        results: List[Dict[str, Any]] = []
        for row in rows:
            results.append(replay_row(row, guard, base_env, stub_log, journal, key_file, skill_root, temp_root))
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)
    out_dir = os.path.abspath(args.out)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create output folder: %s" % os.path.basename(out_dir))
    write_results(os.path.join(out_dir, "results.csv"), results, REPLAY_COLUMNS)
    write_replay_report(
        os.path.join(out_dir, "report.md"),
        rows,
        results,
        revision,
        guard,
        stub,
    )
    failed = sum(1 for result in results if result["verdict"] == "FAIL")
    if failed:
        for result in results:
            if result["verdict"] == "FAIL":
                print("%s: %s" % (result["scenario_id"], result["reason"]))
        print("%s: %d replay row finding(s)" % (PROGRAM, failed))
        return 1
    print("%s: ok, %d replay rows passed" % (PROGRAM, len(results)))
    return 0

# ───────────────────────────────────────────────────────────────
# 13. REVISION WORKTREE
# ───────────────────────────────────────────────────────────────

def add_revision_worktree(revision: str) -> Dict[str, str]:
    """Add a temp worktree for one revision.

    Args:
        revision: Revision argument from the command line.

    Returns:
        The worktree root, the temp root, the full revision and the repo.

    Raises:
        SystemExit: When the revision is unknown or the worktree fails.
    """
    repo = os.path.dirname(SKILL_ROOT)
    temp_root = tempfile.mkdtemp(prefix="route-replay-rev.", dir=os.environ.get("TMPDIR") or "/tmp")
    try:
        probe = subprocess.run(
            ["git", "-C", repo, "rev-parse", "--verify", "%s^{commit}" % revision],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("cannot read the revision %s: %s" % (revision, exc))
    if probe.returncode != 0:
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("unknown revision: %s" % revision)
    full = probe.stdout.decode("utf-8", "replace").strip()
    target = os.path.join(temp_root, "worktree")
    try:
        added = subprocess.run(
            ["git", "-C", repo, "worktree", "add", "--detach", target, full],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("cannot add a worktree for %s: %s" % (full[:12], exc))
    if added.returncode != 0:
        detail = added.stderr.decode("utf-8", "replace").strip()
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("cannot add a worktree for %s: %s" % (full[:12], detail))
    return {"root": target, "temp": temp_root, "sha": full, "repo": repo}


def remove_revision_worktree(context: Dict[str, str]) -> None:
    """Remove the temp worktree and its temp root.

    Args:
        context: Mapping returned by add_revision_worktree.
    """
    try:
        subprocess.run(
            ["git", "-C", context["repo"], "worktree", "remove", "--force", context["root"]],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        subprocess.run(
            ["git", "-C", context["repo"], "worktree", "prune"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        pass
    shutil.rmtree(context["temp"], ignore_errors=True)

# ───────────────────────────────────────────────────────────────
# 14. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the selected mode.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        The exit code of the selected mode.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Resolve the routing fixture corpus and score the routes offline.",
    )
    parser.add_argument(
        "--mode",
        choices=("resolve", "replay"),
        default="resolve",
        help="resolve scores pure route resolution, replay runs the guard against the stub",
    )
    parser.add_argument(
        "--corpus",
        metavar="PATH",
        default=os.path.join(HERE, CORPUS_NAME),
        help="fixture corpus, default %s" % CORPUS_NAME,
    )
    parser.add_argument(
        "--out",
        metavar="DIR",
        default=DEFAULT_OUT,
        help="output folder for results.csv and report.md",
    )
    parser.add_argument(
        "--skill-root",
        metavar="DIR",
        default=None,
        help="skill folder that holds SKILL.md and references",
    )
    parser.add_argument(
        "--rev",
        metavar="SHA",
        default="",
        help="score a git worktree of this revision instead of the live tree",
    )
    parser.add_argument(
        "--covers",
        metavar="PHASE/REQ",
        action="append",
        default=[],
        help="only score rows tagged with this covers value, repeatable",
    )
    parser.add_argument(
        "--guard",
        metavar="PATH",
        default="",
        help="guard script to replay, default from the repository root",
    )
    parser.add_argument(
        "--stub",
        metavar="PATH",
        default="",
        help="stub CLI to replay, default from the repository root",
    )
    args = parser.parse_args(argv)
    if args.rev and args.skill_root is not None:
        fail("--rev scores a worktree, so --skill-root is not allowed")
    context: Optional[Dict[str, str]] = None
    try:
        if args.rev:
            context = add_revision_worktree(args.rev)
            args.skill_root = os.path.join(context["root"], SKILL_FOLDER_NAME)
            args.repo_root = context["root"]
            args.baseline_root = SKILL_ROOT
            args.rev_sha = context["sha"]
        else:
            args.skill_root = os.path.abspath(args.skill_root or SKILL_ROOT)
            args.repo_root = os.path.dirname(SKILL_ROOT)
            args.baseline_root = args.skill_root
            args.rev_sha = ""
        if args.mode == "replay":
            return run_replay(args)
        return run_resolve(args)
    finally:
        if context is not None:
            remove_revision_worktree(context)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
