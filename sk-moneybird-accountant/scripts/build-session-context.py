#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SESSION CONTEXT BUILDER
# ───────────────────────────────────────────────────────────────
"""Write or check the session context projection for a migration run.

Reads the migration config and the phase dashboard, projects a fixed set of
fields onto the session context and writes that context as JSON. The script
uses the Python standard library only and makes no network call. Every field
outside the projection allowlist is dropped, so a config key never leaks into
the context by accident. A date or year field is kept only when its value has
the exact stored form, otherwise it is written as null. Output is stable for a
given clock and inputs: keys are sorted, the indent is fixed and no value
carries a random part.

The check mode reads an existing context file and reports every rule breach,
one line per problem. It confirms the file is present, holds exactly the
allowlisted fields, keeps the phase statuses inside the dashboard vocabulary,
leaks no path, amount or name through a string value and stays inside the
staleness window. It also confirms that each date field is null or a strict
calendar date, that the gate and year fields are null or whole numbers, that
interactive is a boolean and that both stamps are ISO 8601 UTC text. A clean
file prints one ok line and exits 0, a file with problems exits 1. The check
never echoes a value, only a field name and a reason.

The route-state mode reads an existing context file and prints exactly one
state name for the router. The state is computed from the file alone and is
never written back. It takes one of five values: gate_window_conflict,
migration_complete, pre_cutover, monitoring_active or
monitoring_lapsed_phase22_open. The window conflict is checked first, then
migration completion, then the other three. A missing or unusable file prints
no state and exits 1.

The clock comes from SOURCE_DATE_EPOCH when that variable holds an integer,
otherwise from the runtime UTC clock. A set value that is not an integer stops
the run with exit code 3, because a broken stamp must not fall back to a wall
clock. A missing or unreadable config or dashboard file yields null fields
instead of an error. The check mode measures staleness against the same stamp
when it is set, otherwise against the runtime clock.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py --out /tmp/session-context.json
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py --config /path/MIGRATION_CONFIG.json --dashboard /path/dashboard.json
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py --interactive false
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py --check --out /tmp/session-context.json
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py --check --out /tmp/session-context.json --max-age-hours 48
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py --route-state --out /tmp/session-context.json

Options:
    --config P       Read the migration config from this path. The default is
                     migration-workspace/MIGRATION_CONFIG.json under the repo root.
    --dashboard P    Read the dashboard from this path. A .md file holds the
                     phase table that init-workspace.sh copies from the plan
                     kit, any other file a JSON list of phase rows. The default
                     is migration-workspace/dashboard.json under the repo root
                     when it exists, else migration-workspace/Plans/
                     phase-dashboard.md.
    --out P          Write the session context to this path, or read the file
                     in check or route-state mode. The default is
                     session-context.json at the repo root.
    --interactive V  Force true or false instead of probing the terminal and
                     the CI variable.
    --check          Verify the session context file instead of writing it.
                     Exit 1 with one line per problem, or 0 with one ok line.
    --route-state    Print the post-cutover route state read from the session
                     context file. Write nothing and exit 0 after printing.
    --max-age-hours H
                     In check mode, fail when generated_at is older than this
                     many hours. The default is 24.

Output:
    In write mode, the session context file with sorted keys and two-space
    indent, then one summary line on stdout. In check mode, one line per
    problem on stdout, or one ok line for a clean file. In route-state mode,
    exactly one state name on stdout. Exit 0 on success, 1 when check mode
    finds a problem or route-state mode finds a missing or unusable file, 2 on
    a usage or write error and 3 when a set SOURCE_DATE_EPOCH value is not an
    integer.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import re
import sys
from datetime import date, datetime, timezone
from typing import Any, Dict, List, NoReturn, Optional, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/build-session-context.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_CONFIG = os.path.join(REPO_ROOT, "migration-workspace", "MIGRATION_CONFIG.json")
DEFAULT_DASHBOARD = os.path.join(REPO_ROOT, "migration-workspace", "dashboard.json")
# WHY: init-workspace.sh copies the generated markdown dashboard, so a workspace
# built by the documented flow has the table and no JSON list.
DEFAULT_DASHBOARD_MD = os.path.join(REPO_ROOT, "migration-workspace", "Plans", "phase-dashboard.md")
DEFAULT_OUT = os.path.join(REPO_ROOT, "session-context.json")

# WHY: only these five statuses are valid on a dashboard row.
STATUSES = ("NOT_STARTED", "IN_PROGRESS", "STOPPED", "GATE_PASSED", "REOPENED")
PASSED_STATUS = "GATE_PASSED"

# WHY: the monitoring window can stay open with no recorded end date.
OPEN_ENDED = "OPEN_ENDED"

# WHY: the cutover gate opens the monitoring window the post-cutover states
# hang on.
CUTOVER_GATE = 18

# WHY: the projection is an allowlist. Only these keys ever reach the output,
# so no other config or dashboard key can be copied along.
PROJECTION_KEYS = (
    "clock_utc",
    "clock_source",
    "interactive",
    "generated_at",
    "last_passed_gate",
    "phase_18_status",
    "phase_22_status",
    "monitoring_start_date",
    "monitoring_end_date",
    "configured_start_date",
    "last_locked_year",
)

# WHY: a sentinel keeps a real JSON null apart from a key that is absent.
MISSING = object()

# WHY: the migration config template lists its fields as rows with a value
# cell, and a cell nobody filled in yet holds this placeholder text.
PENDING_VALUE = "PENDING"

# WHY: clock and date values may hold separators such as a slash only by
# accident. Every other string is a candidate for the path check.
CLOCK_AND_DATE_KEYS = (
    "clock_utc",
    "generated_at",
    "monitoring_start_date",
    "monitoring_end_date",
    "configured_start_date",
)

# WHY: a slash or backslash in a plain string suggests a filesystem path.
PATH_MARKERS = ("/", "\\")

# WHY: an amount carries a decimal comma or point with two decimals.
AMOUNT_PATTERN = re.compile(r"(?<!\d)\d+(?:[.,]\d{3})*[.,]\d{2}(?!\d)")

# WHY: a stored date must be a plain calendar date, so a config value such as
# "2025/01/31" can never reach the context as a date.
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# WHY: only these fields carry a calendar date.
DATE_FIELDS = ("configured_start_date", "monitoring_start_date", "monitoring_end_date")

# WHY: a plausible locked year sits inside this range.
YEAR_MIN = 1900
YEAR_MAX = 2100

# WHY: two capitalized words suggest a personal name. An underscore joins the
# parts of a token such as SOURCE_DATE_EPOCH, because an underscore counts as
# a word character and no word boundary follows its segments.
NAME_PATTERN = re.compile(r"\b[A-Z][A-Za-z]*\b")

# WHY: a context older than a day may describe a stale phase state.
DEFAULT_MAX_AGE_HOURS = 24.0

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


def clock_missing() -> NoReturn:
    """Report an unusable clock stamp and stop with exit code 3.

    Raises:
        SystemExit: Always, with code 3.
    """
    print("clock_missing", file=sys.stderr)
    sys.exit(3)


def utc_text(moment: datetime) -> str:
    """Render an instant as ISO 8601 UTC with second precision.

    Args:
        moment: Timezone-aware instant.

    Returns:
        Text such as "2024-01-01T00:00:00Z".
    """
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def reference_moment() -> datetime:
    """Resolve the instant the staleness window is measured from.

    Returns:
        The SOURCE_DATE_EPOCH instant when that variable holds an integer,
        otherwise the current UTC instant.

    Raises:
        SystemExit: With code 3 when a set stamp is not an integer.
    """
    raw = os.environ.get("SOURCE_DATE_EPOCH")
    if raw is not None:
        try:
            return datetime.fromtimestamp(int(raw), timezone.utc)
        except (ValueError, OverflowError, OSError):
            clock_missing()
    return datetime.now(timezone.utc)


def parse_stamp(value: Any) -> Optional[datetime]:
    """Parse a context timestamp as a UTC instant.

    Args:
        value: Stored generated_at value.

    Returns:
        The UTC instant, or None when the value is not a parsable stamp.
    """
    if not isinstance(value, str):
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        stamp = datetime.fromisoformat(text)
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=timezone.utc)
    return stamp.astimezone(timezone.utc)


def is_iso_utc_stamp(value: Any) -> bool:
    """Report whether a stored value is an ISO 8601 UTC timestamp.

    Args:
        value: Stored stamp value.

    Returns:
        True only for text that carries an explicit UTC designator and
        parses as an instant.
    """
    if not isinstance(value, str):
        return False
    text = value.strip()
    if not text.endswith(("Z", "+00:00")):
        return False
    return parse_stamp(text) is not None


def parse_calendar_date(value: Any) -> Optional[date]:
    """Parse a stored text value as a calendar date.

    Args:
        value: Stored date value such as "2025-01-31".

    Returns:
        The date, or None when the value is not a parsable date.
    """
    if not isinstance(value, str):
        return None
    text = value.strip()
    if len(text) < 10:
        return None
    try:
        return date.fromisoformat(text[:10])
    except ValueError:
        return None


def exact_calendar_date(value: Any) -> Optional[str]:
    """Keep a text value only when it is exactly a calendar date.

    Args:
        value: Candidate date text such as "2025-01-31".

    Returns:
        The date text, or None when the shape or the date itself is invalid.
    """
    if not isinstance(value, str):
        return None
    text = value.strip()
    if not DATE_PATTERN.match(text):
        return None
    try:
        date.fromisoformat(text)
    except ValueError:
        return None
    return text


def is_integer(value: Any) -> bool:
    """Report whether a JSON value is an integer and not a boolean.

    Args:
        value: Stored value.

    Returns:
        True only for an integer that is not a boolean.
    """
    return isinstance(value, int) and not isinstance(value, bool)


def read_json(path: str) -> Any:
    """Read a JSON file, treating a missing or unreadable file as absent.

    Args:
        path: File to read.

    Returns:
        The parsed value, or None when the file is missing or unusable.
    """
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def lookup_mapping(config: Any, path: str) -> Any:
    """Find a config value by nested mapping or by literal dotted key.

    Args:
        config: Parsed config value.
        path: Dotted key such as "monitoring.start_date".

    Returns:
        The stored value, or MISSING when no mapping holds it.
    """
    if not isinstance(config, dict):
        return MISSING
    head, _, tail = path.partition(".")
    if tail:
        nested = lookup_mapping(config.get(head), tail)
        if nested is not MISSING:
            return nested
    if path in config:
        return config[path]
    return MISSING


def lookup_field_row(config: Dict[str, Any], path: str) -> Any:
    """Find a config value in the template shape of a fields list.

    Args:
        config: Parsed config mapping that may hold a "fields" list.
        path: Dotted key such as "monitoring.start_date".

    Returns:
        The value of the row whose "field" equals the key, None when that
        value is blank or still the placeholder, or MISSING when no row
        names the key.
    """
    rows = config.get("fields")
    if not isinstance(rows, list):
        return MISSING
    for row in rows:
        if isinstance(row, dict) and row.get("field") == path:
            value = row.get("value")
            if isinstance(value, str) and value.strip() in ("", PENDING_VALUE):
                return None
            return value
    return MISSING


def lookup(config: Any, path: str) -> Any:
    """Find a config value in a nested mapping, a literal dotted key or a fields list.

    Args:
        config: Parsed config value.
        path: Dotted key such as "monitoring.start_date".

    Returns:
        The stored value, or MISSING when no shape holds it. A placeholder in
        a fields row reads as None.
    """
    if not isinstance(config, dict):
        return MISSING
    found = lookup_mapping(config, path)
    if found is not MISSING:
        return found
    return lookup_field_row(config, path)


def config_text(config: Any, path: str) -> Optional[str]:
    """Read a config value as text.

    Args:
        config: Parsed config value.
        path: Dotted key to read.

    Returns:
        The stripped text, or None when the key is absent or blank.
    """
    value = lookup(config, path)
    if value is MISSING or value is None:
        return None
    text = value if isinstance(value, str) else str(value)
    return text.strip() or None


def config_value(config: Any, path: str) -> Any:
    """Read a config value while keeping its JSON type.

    Args:
        config: Parsed config value.
        path: Dotted key to read.

    Returns:
        The value, with a blank string folded to None, or None when absent.
    """
    value = lookup(config, path)
    if value is MISSING or value is None:
        return None
    if isinstance(value, str):
        return value.strip() or None
    return value


def config_date(config: Any, path: str, allow_open_ended: bool = False) -> Optional[str]:
    """Read a config value as a strict calendar date.

    Args:
        config: Parsed config value.
        path: Dotted key to read.
        allow_open_ended: Whether the OPEN_ENDED sentinel is allowed.

    Returns:
        The date text, or None when the value is not a strict date and not
        the allowed sentinel.
    """
    text = config_text(config, path)
    if text is None:
        return None
    if allow_open_ended and text == OPEN_ENDED:
        return OPEN_ENDED
    return exact_calendar_date(text)


def config_locked_year(config: Any) -> Optional[int]:
    """Read the locked year only when it is a plausible integer year.

    Args:
        config: Parsed config value.

    Returns:
        The year as an integer, or None when the value is absent, of the
        wrong type or outside the supported range.
    """
    value = config_value(config, "last_locked_year")
    if not is_integer(value):
        return None
    if value < YEAR_MIN or value > YEAR_MAX:
        return None
    return value


# ───────────────────────────────────────────────────────────────
# 4. INPUT RESOLUTION
# ───────────────────────────────────────────────────────────────

def resolve_clock() -> Tuple[str, str]:
    """Resolve the clock instant and its source.

    Returns:
        The ISO 8601 UTC instant and the source label.

    Raises:
        SystemExit: With code 3 when a set stamp is not an integer.
    """
    raw = os.environ.get("SOURCE_DATE_EPOCH")
    if raw is not None:
        try:
            return utc_text(datetime.fromtimestamp(int(raw), timezone.utc)), "SOURCE_DATE_EPOCH"
        except (ValueError, OverflowError, OSError):
            clock_missing()
    return utc_text(datetime.now(timezone.utc)), "runtime"


def resolve_interactive(override: Optional[bool]) -> bool:
    """Resolve whether the session runs interactively.

    Args:
        override: Forced value from the command line, or None to probe.

    Returns:
        True only for a terminal session without the CI variable.
    """
    if override is not None:
        return override
    if os.environ.get("CI", "").strip():
        return False
    return sys.stdin.isatty()


def read_markdown_dashboard(path: str) -> Dict[int, str]:
    """Read the phase table of a markdown dashboard keyed by phase number.

    Args:
        path: Markdown dashboard file to read.

    Returns:
        Mapping of phase number to a valid status, empty when the file is
        missing or holds no table with a Phase and a Status column. A status
        cell such as `GATE PASSED` reads as `GATE_PASSED`, and a row whose
        status is outside the vocabulary is dropped.
    """
    if not os.path.isfile(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except (OSError, ValueError):
        return {}
    rows: Dict[int, str] = {}
    columns: Optional[Tuple[int, int]] = None
    for line in lines:
        if not line.lstrip().startswith("|"):
            columns = None
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if columns is None:
            names = [cell.lower() for cell in cells]
            if "phase" in names and "status" in names:
                columns = (names.index("phase"), names.index("status"))
            continue
        phase_cell = cells[columns[0]] if columns[0] < len(cells) else ""
        status_cell = cells[columns[1]] if columns[1] < len(cells) else ""
        if not phase_cell.isdigit():
            continue
        status = re.sub(r"\s+", "_", status_cell.upper())
        if status in STATUSES:
            rows[int(phase_cell)] = status
    return rows


def read_dashboard(path: str) -> Dict[int, str]:
    """Read the dashboard rows keyed by phase number.

    Args:
        path: Dashboard file to read, a markdown table or a JSON list.

    Returns:
        Mapping of phase number to a valid status, empty when the file is
        missing or unusable. Invalid rows are dropped.
    """
    if path.lower().endswith(".md"):
        return read_markdown_dashboard(path)
    data = read_json(path)
    rows: Dict[int, str] = {}
    if not isinstance(data, list):
        return rows
    for row in data:
        if not isinstance(row, dict):
            continue
        phase = row.get("phase")
        status = row.get("status")
        if isinstance(phase, bool) or not isinstance(phase, int):
            continue
        if status in STATUSES:
            rows[phase] = status
    return rows

# ───────────────────────────────────────────────────────────────
# 5. PROJECTION
# ───────────────────────────────────────────────────────────────

def build_context(clock_utc: str, clock_source: str, interactive: bool, config: Any, dashboard: Dict[int, str]) -> Dict[str, Any]:
    """Project the allowlisted fields from the clock, config and dashboard.

    Args:
        clock_utc: ISO 8601 UTC instant.
        clock_source: Source label of the instant.
        interactive: Whether the session runs interactively.
        config: Parsed config value, or None when no config was read.
        dashboard: Result of read_dashboard().

    Returns:
        The session context with exactly the allowlisted keys.
    """
    passed = [phase for phase, status in dashboard.items() if status == PASSED_STATUS]
    context = {
        "clock_utc": clock_utc,
        "clock_source": clock_source,
        "interactive": interactive,
        "generated_at": clock_utc,
        "last_passed_gate": max(passed) if passed else None,
        "phase_18_status": dashboard.get(18),
        "phase_22_status": dashboard.get(22),
        "monitoring_start_date": config_date(config, "monitoring.start_date"),
        "monitoring_end_date": config_date(config, "monitoring.end_date", allow_open_ended=True),
        "configured_start_date": config_date(config, "configured_start_date"),
        "last_locked_year": config_locked_year(config),
    }
    return {key: context[key] for key in PROJECTION_KEYS}

# ───────────────────────────────────────────────────────────────
# 6. WRITE
# ───────────────────────────────────────────────────────────────

def write_context(context: Dict[str, Any], out_path: str) -> int:
    """Write the session context and report the output path.

    Args:
        context: Result of build_context().
        out_path: File to write.

    Returns:
        Zero on success.

    Raises:
        SystemExit: If the file cannot be written.
    """
    text = json.dumps(context, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    try:
        with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    except OSError as exc:
        fail("cannot write %s: %s" % (out_path, exc))
    print("session-context: written %s" % out_path)
    return 0

# ───────────────────────────────────────────────────────────────
# 7. CHECK
# ───────────────────────────────────────────────────────────────

def container_paths(value: Any, prefix: str = "") -> List[str]:
    """List the field paths that hold a JSON object or array.

    Args:
        value: Parsed value to walk.
        prefix: Dotted path of the enclosing field.

    Returns:
        One path per object or array found at any depth.
    """
    found: List[str] = []
    if isinstance(value, dict):
        for key in value:
            child = "%s.%s" % (prefix, key) if prefix else str(key)
            if isinstance(value[key], (dict, list)):
                found.append(child)
            found.extend(container_paths(value[key], child))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            child = "%s[%d]" % (prefix, index) if prefix else "[%d]" % index
            if isinstance(item, (dict, list)):
                found.append(child)
            found.extend(container_paths(item, child))
    return found


def check_context(out_path: str, max_age_hours: float) -> int:
    """Check an existing session context against the projection rules.

    The check reports problems on stdout, one line per problem, and never
    echoes a value. A field name and a reason are enough to locate a broken
    context without printing private data.

    Args:
        out_path: Session context file to read.
        max_age_hours: Allowed age of generated_at, in hours.

    Returns:
        Zero when the file is clean, otherwise 1.
    """
    if not os.path.isfile(out_path):
        print("session-context: missing file: %s" % out_path)
        return 1
    try:
        with open(out_path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        print("session-context: unreadable file: %s" % out_path)
        return 1
    if not isinstance(data, dict):
        print("session-context: not a JSON object: %s" % out_path)
        return 1
    problems: List[str] = []
    for key in PROJECTION_KEYS:
        if key not in data:
            problems.append("missing field: %s" % key)
    for key in sorted(data):
        if key not in PROJECTION_KEYS:
            problems.append("unexpected field: %s" % key)
    for path in container_paths(data):
        problems.append("invalid container value: %s" % path)
    for key in ("phase_18_status", "phase_22_status"):
        if data.get(key) is not None and data.get(key) not in STATUSES:
            problems.append("invalid status: %s" % key)
    for key in DATE_FIELDS:
        value = data.get(key)
        if value is None:
            continue
        if key == "monitoring_end_date" and value == OPEN_ENDED:
            continue
        if exact_calendar_date(value) is None:
            problems.append("invalid date: %s" % key)
    if "clock_utc" in data and not is_iso_utc_stamp(data.get("clock_utc")):
        problems.append("invalid timestamp: clock_utc")
    if "generated_at" in data and not is_iso_utc_stamp(data.get("generated_at")):
        problems.append("invalid timestamp: generated_at")
    for key in ("last_locked_year", "last_passed_gate"):
        value = data.get(key)
        if value is None:
            continue
        if not is_integer(value):
            problems.append("invalid integer: %s" % key)
    if "interactive" in data and not isinstance(data.get("interactive"), bool):
        problems.append("invalid boolean: interactive")
    for key in PROJECTION_KEYS:
        value = data.get(key)
        if not isinstance(value, str):
            continue
        if key not in CLOCK_AND_DATE_KEYS and any(marker in value for marker in PATH_MARKERS):
            problems.append("path-like value: %s" % key)
        if "\u20ac" in value or AMOUNT_PATTERN.search(value):
            problems.append("amount-like value: %s" % key)
        if len(NAME_PATTERN.findall(value)) >= 2:
            problems.append("name-like value: %s" % key)
    if "generated_at" in data:
        stamp = parse_stamp(data.get("generated_at"))
        if stamp is None:
            problems.append("unreadable generated_at")
        elif (reference_moment() - stamp).total_seconds() > max_age_hours * 3600.0:
            problems.append("stale generated_at: older than %g hours" % max_age_hours)
    if problems:
        for problem in problems:
            print("session-context: %s" % problem)
        return 1
    print("session-context: ok")
    return 0


# ───────────────────────────────────────────────────────────────
# 8. ROUTE STATE
# ───────────────────────────────────────────────────────────────

def context_clock_date(context: Dict[str, Any]) -> date:
    """Resolve the calendar date of the session clock.

    Args:
        context: Parsed session context.

    Returns:
        The date part of clock_utc, or the reference date when clock_utc is
        absent or unreadable.

    Raises:
        SystemExit: With code 3 when a set stamp is not an integer and
            clock_utc is unreadable.
    """
    stamp = parse_stamp(context.get("clock_utc"))
    if stamp is None:
        return reference_moment().date()
    return stamp.date()


def route_state(context: Dict[str, Any], clock_date: date) -> str:
    """Compute the post-cutover route state from the context fields.

    Args:
        context: Parsed session context.
        clock_date: Calendar date of the session clock.

    Returns:
        One state name. A window with no readable end date cannot cover the
        clock date, so that case counts as lapsed. A passed cutover gate with
        no readable start date counts as a window conflict.
    """
    start = parse_calendar_date(context.get("monitoring_start_date"))
    end = parse_calendar_date(context.get("monitoring_end_date"))
    gate = context.get("last_passed_gate")
    gate_passed = is_integer(gate) and gate >= CUTOVER_GATE
    if gate_passed and start is None:
        return "gate_window_conflict"
    if start is not None and end is not None and end < start:
        return "gate_window_conflict"
    if context.get("phase_22_status") == PASSED_STATUS:
        return "migration_complete"
    if not gate_passed:
        return "pre_cutover"
    end_text = context.get("monitoring_end_date")
    if isinstance(end_text, str) and end_text.strip() == OPEN_ENDED:
        return "monitoring_active"
    if end is not None and end >= clock_date:
        return "monitoring_active"
    return "monitoring_lapsed_phase22_open"


def print_route_state(out_path: str) -> int:
    """Print the route state computed from the session context.

    The file is read only. This mode never writes the context back.

    Args:
        out_path: Session context file to read.

    Returns:
        Zero after one state line, otherwise 1 when the file is missing,
        unreadable or not a JSON object.
    """
    if not os.path.isfile(out_path):
        print("session-context: missing file: %s" % out_path)
        return 1
    try:
        with open(out_path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        print("session-context: unreadable file: %s" % out_path)
        return 1
    if not isinstance(data, dict):
        print("session-context: not a JSON object: %s" % out_path)
        return 1
    print(route_state(data, context_clock_date(data)))
    return 0


# ───────────────────────────────────────────────────────────────
# 9. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def parse_args(argv: List[str]) -> argparse.Namespace:
    """Parse the command line.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        The parsed arguments.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Write or check the session context projection for a migration run.",
    )
    parser.add_argument("--config", default=DEFAULT_CONFIG, metavar="PATH", help="migration config to read")
    parser.add_argument("--dashboard", default=None, metavar="PATH", help="dashboard markdown table or JSON list to read")
    parser.add_argument("--out", default=DEFAULT_OUT, metavar="PATH", help="session context file to write or read")
    parser.add_argument("--interactive", choices=("true", "false"), metavar="true|false", help="force the interactive flag")
    parser.add_argument("--check", action="store_true", help="verify the session context file without writing it")
    parser.add_argument(
        "--route-state",
        action="store_true",
        help="print the computed post-cutover route state from the context file without writing it",
    )
    parser.add_argument(
        "--max-age-hours",
        type=float,
        default=DEFAULT_MAX_AGE_HOURS,
        metavar="HOURS",
        help="in check mode, fail when generated_at is older than this many hours",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    """Parse arguments and write or check the session context.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code reported by the write, check or route-state step.
    """
    args = parse_args(argv)
    if args.route_state:
        return print_route_state(args.out)
    if args.check:
        return check_context(args.out, args.max_age_hours)
    override = None if args.interactive is None else args.interactive == "true"
    clock_utc, clock_source = resolve_clock()
    interactive = resolve_interactive(override)
    config = read_json(args.config)
    dashboard_path = args.dashboard
    if dashboard_path is None:
        dashboard_path = DEFAULT_DASHBOARD if os.path.isfile(DEFAULT_DASHBOARD) else DEFAULT_DASHBOARD_MD
    dashboard = read_dashboard(dashboard_path)
    context = build_context(clock_utc, clock_source, interactive, config, dashboard)
    return write_context(context, args.out)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
