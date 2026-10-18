#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: SCANNABILITY REPORT
# ───────────────────────────────────────────────────────────────
"""Publish the three scannability metrics of the reference corpus.

The report answers one question: how far does a reader travel before the
first value row answers a figure question? It reads the pinned token baseline
for the section rows and the routing gold rows for the replay splits, and it
writes benchmark/reports/scannability/report.md. The three metrics are:

1. tokens to first answer, the token count of the answer surface section of
   the first tax file a row names.
2. answer position inside the section, the place of the answer surface among
   the sections of its file, as a fraction of the file's sections.
3. section hit rate, the share of rows whose read set holds the section a
   fact came from. While a gold row carries no section label the metric
   records the labelled row count as its denominator instead of a number.

Every metric row carries the denominator of its own split, so a reader can
tell a measured value from a vacuous one. The run is offline, byte-stable and
reads only the repository tree.

Usage:
    python3 -I sk-moneybird-accountant/scripts/scannability-report.py
    python3 -I sk-moneybird-accountant/scripts/scannability-report.py --check

Options:
    --check     Recompute the report in memory and report drift without
                writing. Exits 1 on drift.

Output:
    benchmark/reports/scannability/report.md in write mode, one summary line
    per split in both modes. Exit 0 when the report is written or matches, 1
    on drift or a missing input, and 2 on a usage or read error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import json
import os
import sys
from typing import Any, Dict, List, NoReturn, Optional, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

GENERATOR = "sk-moneybird-accountant/scripts/scannability-report.py"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKILL_ROOT = os.path.join(REPO_ROOT, "sk-moneybird-accountant")
BASELINE_PATH = os.path.join(SKILL_ROOT, "benchmark", "token-baseline.json")
GOLD_PATH = os.path.join(SKILL_ROOT, "scripts", "route-replay", "routing-gold.json")
REPORT_DIR = os.path.join(SKILL_ROOT, "benchmark", "reports", "scannability")
REPORT_PATH = os.path.join(REPORT_DIR, "report.md")
ANSWER_ANCHOR = "2-key-figures"
FIGURE_SUFFIX = "/figures.md"
SPLITS = ("calibration", "held-out", "regression")
SECTION_LABEL_FIELD = "expected_sections"

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
    print("%s: %s" % (os.path.basename(GENERATOR), message), file=sys.stderr)
    sys.exit(2)


def read_json(path: str) -> Any:
    """Read one JSON file.

    Args:
        path: Absolute path.

    Returns:
        The parsed value.

    Raises:
        SystemExit: If the file is missing, unreadable or invalid JSON.
    """
    if not os.path.isfile(path):
        fail("missing %s" % os.path.relpath(path, REPO_ROOT))
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail("cannot read %s: %s" % (os.path.relpath(path, REPO_ROOT), exc))

# ───────────────────────────────────────────────────────────────
# 4. METRICS
# ───────────────────────────────────────────────────────────────

def file_rows(baseline: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    """Map the baseline file rows by their reference path.

    Args:
        baseline: Token baseline record.

    Returns:
        File rows keyed by the path relative to the references root.
    """
    prefix = "sk-moneybird-accountant/references/"
    rows: Dict[str, Dict[str, Any]] = {}
    for row in baseline.get("files", []):
        if isinstance(row, dict) and isinstance(row.get("path"), str):
            path = row["path"]
            rows[path[len(prefix):] if path.startswith(prefix) else path] = row
    return rows


def lead_encoding(baseline: Dict[str, Any]) -> str:
    """Return the lead encoding name of a baseline.

    Args:
        baseline: Token baseline record.

    Returns:
        The encoding name, empty when the baseline names none.
    """
    pin = baseline.get("pin")
    if isinstance(pin, dict) and isinstance(pin.get("lead_encoding"), str):
        return pin["lead_encoding"]
    return ""


def answer_path(row: Dict[str, Any]) -> Optional[str]:
    """Return the first answer surface file of one gold row.

    Args:
        row: One gold row.

    Returns:
        The path of the first tax figures file the row names, or None.
    """
    for path in row.get("expected_paths", []):
        if isinstance(path, str) and path.endswith(FIGURE_SUFFIX) and path.startswith("references/"):
            return path[len("references/"):]
    return None


def section_row(file: Dict[str, Any], anchor: str) -> Optional[Dict[str, Any]]:
    """Return the section row of one anchor.

    Args:
        file: Baseline file row.
        anchor: Section anchor.

    Returns:
        The section row, or None when the file holds no such row.
    """
    for section in file.get("sections", []):
        if isinstance(section, dict) and section.get("anchor") == anchor:
            return section
    return None


def split_metrics(rows: List[Dict[str, Any]], files: Dict[str, Dict[str, Any]], lead: str) -> Dict[str, Any]:
    """Compute the three metrics of one split.

    Args:
        rows: Gold rows of the split.
        files: Baseline file rows by reference path.
        lead: Lead encoding name.

    Returns:
        A record with the two measured values, their denominator, the
        section-label count and the row count.
    """
    tokens_total = 0
    tokens_rows = 0
    position_total = 0.0
    position_rows = 0
    labelled = 0
    for row in rows:
        if row.get(SECTION_LABEL_FIELD):
            labelled += 1
        path = answer_path(row)
        if path is None:
            continue
        file = files.get(path)
        if file is None:
            continue
        section = section_row(file, ANSWER_ANCHOR)
        if section is None:
            continue
        counts = section.get("tokens")
        if not isinstance(counts, dict) or not isinstance(counts.get(lead), int):
            continue
        tokens_total += counts[lead]
        tokens_rows += 1
        sections = file.get("sections", [])
        for index, item in enumerate(sections, 1):
            if item is section:
                position_total += index / len(sections)
                position_rows += 1
                break
    return {
        "rows": len(rows),
        "tokens_rows": tokens_rows,
        "tokens_mean": round(tokens_total / tokens_rows) if tokens_rows else 0,
        "position_rows": position_rows,
        "position_mean": round(position_total / position_rows, 3) if position_rows else 0,
        "labelled": labelled,
    }

# ───────────────────────────────────────────────────────────────
# 5. REPORT
# ───────────────────────────────────────────────────────────────

def render(metrics: Dict[str, Dict[str, Any]], lead: str) -> str:
    """Render the scannability report.

    Args:
        metrics: Split metrics keyed by split name.
        lead: Lead encoding name.

    Returns:
        The complete report text.
    """
    lines = [
        "# Scannability report",
        "",
        "Generated by `sk-moneybird-accountant/scripts/scannability-report.py`. "
        "Token counts come from `benchmark/token-baseline.json`, the split labels "
        "from `scripts/route-replay/routing-gold.json`. The encoding is `%s`." % lead,
        "",
        "Every row carries its own denominator. A metric whose prerequisite is "
        "missing records the missing denominator instead of a number.",
        "",
        "## Metric rows",
        "",
        "| Metric | Split | Value | Denominator |",
        "|---|---|---|---|",
    ]
    for split in SPLITS:
        data = metrics[split]
        lines.append(
            "| Tokens to first answer | %s | %d %s tokens | %d of %d rows name a tax figures file |"
            % (split, data["tokens_mean"], lead, data["tokens_rows"], data["rows"])
        )
        lines.append(
            "| Answer position inside the section | %s | %.3f of the file's sections | %d of %d rows name a tax figures file |"
            % (split, data["position_mean"], data["position_rows"], data["rows"])
        )
        hit_value = (
            "no number, the gold rows carry no section label"
            if not data["labelled"]
            else "no number, the metric is not computed yet"
        )
        lines.append(
            "| Section hit rate | %s | %s | %d of %d rows carry a section label |"
            % (split, hit_value, data["labelled"], data["rows"])
        )
    lines.append("")
    lines.append("## What each metric means")
    lines.append("")
    lines.append(
        "- Tokens to first answer: the lead-encoding token count of the KEY FIGURES "
        "section of the first tax figures file a row names. A smaller count means the "
        "answer surface is cheaper to open."
    )
    lines.append(
        "- Answer position inside the section: the place of that section among the "
        "sections of its file, as a fraction of the file's section count. A value near "
        "the top means the answer surface sits early in the file."
    )
    lines.append(
        "- Section hit rate: the share of rows whose loaded set holds the section a "
        "fact came from. It needs a section label on every replay row, so while a "
        "gold row carries none this row records the labelled row count as its "
        "denominator rather than a number."
    )
    lines.append("")
    return "\n".join(lines)


def build_report() -> Tuple[str, Dict[str, Dict[str, Any]]]:
    """Build the report text from the baseline and the gold rows.

    Returns:
        The report text and the split metrics.
    """
    baseline = read_json(BASELINE_PATH)
    gold = read_json(GOLD_PATH)
    files = file_rows(baseline)
    lead = lead_encoding(baseline)
    rows = gold.get("rows", [])
    metrics: Dict[str, Dict[str, Any]] = {}
    for split in SPLITS:
        metrics[split] = split_metrics(
            [row for row in rows if isinstance(row, dict) and row.get("split") == split],
            files,
            lead,
        )
    return render(metrics, lead), metrics

# ───────────────────────────────────────────────────────────────
# 6. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Run the write or check mode.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        Zero when the report is written or matches, one on drift.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Publish the three scannability metrics of the reference corpus.",
    )
    parser.add_argument("--check", action="store_true", help="verify the report without writing it")
    args = parser.parse_args(argv)
    text, metrics = build_report()
    stored = None
    if os.path.isfile(REPORT_PATH):
        with open(REPORT_PATH, "r", encoding="utf-8", newline="") as handle:
            stored = handle.read()
    for split in SPLITS:
        data = metrics[split]
        print(
            "%s: %s %d rows, tokens denominator %d, position denominator %d, section labels %d"
            % (
                os.path.basename(GENERATOR),
                split,
                data["rows"],
                data["tokens_rows"],
                data["position_rows"],
                data["labelled"],
            )
        )
    if args.check:
        if stored != text:
            print("%s: drift: %s" % (os.path.basename(GENERATOR), os.path.relpath(REPORT_PATH, REPO_ROOT)))
            return 1
        print("%s: check ok" % os.path.basename(GENERATOR))
        return 0
    os.makedirs(REPORT_DIR, exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    print("%s: wrote %s" % (os.path.basename(GENERATOR), os.path.relpath(REPORT_PATH, REPO_ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
