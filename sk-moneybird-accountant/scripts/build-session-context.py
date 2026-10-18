#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SESSION CONTEXT BUILDER
# ───────────────────────────────────────────────────────────────
"""Write the session context projection for a migration run.

Reads the migration config and the phase dashboard, projects a fixed set of
fields onto the session context and writes that context as JSON. The script
uses the Python standard library only and makes no network call. Every field
outside the projection allowlist is dropped, so a config key never leaks into
the context by accident. A date or year field is kept only when its value has
the exact stored form, otherwise it is written as null. Output is stable for a
given clock and inputs: keys are sorted, the indent is fixed and no value
carries a random part.

The clock comes from SOURCE_DATE_EPOCH when that variable holds an integer,
otherwise from the runtime UTC clock. A set value that is not an integer stops
the run with exit code 3, because a broken stamp must not fall back to a wall
clock. A missing or unreadable config or dashboard file yields null fields
instead of an error.

Usage:
    python3 -I sk-moneybird-accountant/scripts/build-session-context.py

Input:
    migration-workspace/MIGRATION_CONFIG.json under the repo root, read as the
    fields rows of the config template. migration-workspace/Plans/
    phase-dashboard.md under the repo root, the phase table that
    init-workspace.sh copies from the plan kit. The interactive flag is true
    only for a terminal session without the CI variable.

Output:
    session-context.json at the repo root with sorted keys and two-space
    indent, then one summary line on stdout. Exit 0 on success, 2 on a usage
    or write error and 3 when a set SOURCE_DATE_EPOCH value is not an integer.
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
CONFIG_PATH = os.path.join(REPO_ROOT, "migration-workspace", "MIGRATION_CONFIG.json")
# WHY: init-workspace.sh copies the generated markdown dashboard, so a workspace
# built by the documented flow has the phase table.
DASHBOARD_PATH = os.path.join(REPO_ROOT, "migration-workspace", "Plans", "phase-dashboard.md")
CONTEXT_PATH = os.path.join(REPO_ROOT, "session-context.json")

# WHY: only these five statuses are valid on a dashboard row.
STATUSES = ("NOT_STARTED", "IN_PROGRESS", "STOPPED", "GATE_PASSED", "REOPENED")
PASSED_STATUS = "GATE_PASSED"

# WHY: the monitoring window can stay open with no recorded end date.
OPEN_ENDED = "OPEN_ENDED"

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

# WHY: a stored date must be a plain calendar date, so a config value such as
# "2025/01/31" can never reach the context as a date.
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# WHY: a plausible locked year sits inside this range.
YEAR_MIN = 1900
YEAR_MAX = 2100

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
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def lookup(config: Any, path: str) -> Any:
    """Find a config value in the fields list of the config template.

    Args:
        config: Parsed config value.
        path: Dotted key such as "monitoring.start_date".

    Returns:
        The value of the row whose "field" equals the key. None when that
        value is blank or still the placeholder. MISSING when no row names
        the key.
    """
    rows = config.get("fields") if isinstance(config, dict) else None
    if not isinstance(rows, list):
        return MISSING
    for row in rows:
        if isinstance(row, dict) and row.get("field") == path:
            value = row.get("value")
            if isinstance(value, str) and value.strip() in ("", PENDING_VALUE):
                return None
            return value
    return MISSING


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


def resolve_interactive() -> bool:
    """Resolve whether the session runs interactively.

    Returns:
        True only for a terminal session without the CI variable.
    """
    if os.environ.get("CI", "").strip():
        return False
    # WHY: a run with stdin closed, as from a scheduler, has no stdin object.
    return sys.stdin is not None and sys.stdin.isatty()


def read_dashboard(path: str) -> Dict[int, str]:
    """Read the phase table of a markdown dashboard keyed by phase number.

    Args:
        path: Markdown dashboard file to read.

    Returns:
        Mapping of phase number to a valid status, empty when the file is
        missing or holds no table with a Phase and a Status column. A status
        cell such as `GATE PASSED` reads as `GATE_PASSED`, and a row whose
        status is outside the vocabulary is dropped.
    """
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
# 7. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def parse_args(argv: List[str]) -> argparse.Namespace:
    """Parse the command line, which takes no arguments.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        The parsed arguments.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Write the session context projection for a migration run.",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    """Parse arguments and write the session context.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Exit code reported by the write step.
    """
    parse_args(argv)
    clock_utc, clock_source = resolve_clock()
    interactive = resolve_interactive()
    config = read_json(CONFIG_PATH)
    dashboard = read_dashboard(DASHBOARD_PATH)
    context = build_context(clock_utc, clock_source, interactive, config, dashboard)
    return write_context(context, CONTEXT_PATH)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
