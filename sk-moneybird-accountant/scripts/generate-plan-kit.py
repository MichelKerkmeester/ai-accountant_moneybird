#!/usr/bin/env python3
"""Generate the migration plan kit under assets/migration/.

The generated files hold placeholders only. Real migration data lives in the
git-ignored migration-workspace/ folder, so the tracked kit stays shareable.

Output is byte-stable: sorted inputs, no timestamps, no randomness.

Usage:
    python3 -I scripts/generate-plan-kit.py
    python3 -I scripts/generate-plan-kit.py --check
"""

import argparse
import json
import os
import re
import sys

GENERATOR = "scripts/generate-plan-kit.py"
SETUP_REFERENCE = "references/migration/overview-and-setup.md"
PHASE_22_REFERENCE = "phase-22-completion.md"
PHASE_TOTAL = 23
CONFIG_HEADING = "## Required `MIGRATION_CONFIG` fields"
CONFIG_COLUMNS = ("Field", "Owner", "Needed by", "Required value or evidence")
WORKSPACE_HEADING = "## Workspace layout"
MECHANISMS_PREFIX = "Mechanisms used:"
SUBGOAL_CHECK = ". Check: "
LINK_FROM = "](./"
LINK_TO = "](../../../references/migration/"

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_DIR = os.path.dirname(SKILL_DIR)
REFERENCE_DIR = os.path.join(SKILL_DIR, "references", "migration")
OUTPUT_DIR = os.path.join(SKILL_DIR, "assets", "migration")
PHASE_OUTPUT_DIR = os.path.join(OUTPUT_DIR, "phases")

FIELD_NAMES = (
    "Goal",
    "Nested sub-goals",
    "Entry criteria",
    "Inputs",
    "Owner-tagged actions",
    "Tool route",
    "Outputs and evidence artifacts",
    "Numeric exit gate",
    "Stop conditions",
    "Rollback or compensation",
    "Resume rule",
)

AGENT_DESK_FOLDERS = (
    "AgentDesk/Briefs/",
    "AgentDesk/Drafts/",
    "AgentDesk/Fixtures/",
    "AgentDesk/Scripts/",
    "AgentDesk/Checks/",
    "AgentDesk/Summaries/",
    "AgentDesk/Verdicts/",
    "AgentDesk/FinalReviews/",
    "AgentDesk/Logs/",
)

PHASE_HEADING = re.compile(r"^## Phase (\d+): (.+?)\s*$")
FIELD_HEADING = re.compile(r"^### (\d+)\. (.+?)\s*$")
SUBGOAL_LINE = re.compile(r"^- \*\*SG-(\d+)\.(\d+)\*\*: (.+?)\s*$")
MECHANISM = re.compile(r"\[M(\d+)\]")
FOLDER_BULLET = re.compile(r"^- `([^`]+)`")
FIELD_CODE = re.compile(r"`([^`]+)`")


def fail(message):
    sys.stderr.write("generate-plan-kit: error: %s\n" % message)
    raise SystemExit(2)


def display(path):
    # WHY: only repo-relative paths are printed, so no home folder ever leaks.
    try:
        return os.path.relpath(path, REPO_DIR)
    except ValueError:
        return path


def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read().split("\n")
    except OSError as exc:
        fail("cannot read %s: %s" % (display(path), exc))


def phase_reference_paths():
    try:
        names = sorted(os.listdir(REFERENCE_DIR))
    except OSError as exc:
        fail("cannot list references: %s" % exc)
    selected = [name for name in names if name.startswith("phases-") and name.endswith(".md")]
    if PHASE_22_REFERENCE not in selected:
        selected.append(PHASE_22_REFERENCE)
    paths = []
    for name in selected:
        path = os.path.join(REFERENCE_DIR, name)
        if not os.path.isfile(path):
            fail("missing phase reference references/migration/%s" % name)
        paths.append(path)
    return paths


def rewrite_links(text):
    return text.replace(LINK_FROM, LINK_TO)


def parse_subgoals(name, number, text):
    subgoals = []
    for line in text.split("\n"):
        match = SUBGOAL_LINE.match(line)
        if not match:
            continue
        rest = match.group(3).strip()
        cut = rest.find(SUBGOAL_CHECK)
        if cut < 0:
            fail("%s phase %d: sub-goal SG-%s.%s has no `%s` separator"
                 % (name, number, match.group(1), match.group(2), SUBGOAL_CHECK))
        subgoals.append({
            "id": "SG-%s.%s" % (match.group(1), match.group(2)),
            "text": rest[:cut + 1],
            "check": rest[cut + len(SUBGOAL_CHECK):].strip(),
        })
    return subgoals


def parse_phase(name, number, title, body):
    index = 0
    while index < len(body) and not body[index].strip():
        index += 1
    if index >= len(body) or not body[index].lstrip().startswith(MECHANISMS_PREFIX):
        fail("%s phase %d: the line after the heading must start with `%s`"
             % (name, number, MECHANISMS_PREFIX))
    mechanisms = sorted({int(value) for value in MECHANISM.findall(body[index])})

    headings = []
    for position, line in enumerate(body):
        match = FIELD_HEADING.match(line)
        if match:
            headings.append((position, int(match.group(1)), match.group(2).strip()))
    if len(headings) < len(FIELD_NAMES):
        fail("%s phase %d: missing field %d. %s"
             % (name, number, len(headings) + 1, FIELD_NAMES[len(headings)]))
    for slot in range(len(FIELD_NAMES)):
        found_number = headings[slot][1]
        found_name = headings[slot][2]
        if found_number != slot + 1 or found_name != FIELD_NAMES[slot]:
            fail("%s phase %d: field %d is `%s`, expected `%d. %s`"
                 % (name, number, found_number, found_name, slot + 1, FIELD_NAMES[slot]))

    fields = {}
    for slot in range(len(FIELD_NAMES)):
        start = headings[slot][0]
        stop = headings[slot + 1][0] if slot + 1 < len(FIELD_NAMES) else len(body)
        fields[FIELD_NAMES[slot]] = rewrite_links("\n".join(body[start + 1:stop]).strip())

    return {
        "number": number,
        "title": title,
        "file": name,
        "mechanisms": mechanisms,
        "fields": fields,
        "subgoals": parse_subgoals(name, number, fields["Nested sub-goals"]),
    }


def parse_phase_file(path, phases):
    name = os.path.basename(path)
    lines = read_lines(path)
    starts = [index for index, line in enumerate(lines) if PHASE_HEADING.match(line)]
    if not starts:
        fail("%s: no heading like `## Phase N: Title` found" % name)
    for start in starts:
        stop = len(lines)
        for index in range(start + 1, len(lines)):
            if lines[index].startswith("## "):
                stop = index
                break
        heading = PHASE_HEADING.match(lines[start])
        number = int(heading.group(1))
        title = heading.group(2).strip()
        if number in phases:
            fail("%s phase %d: number already used in %s" % (name, number, phases[number]["file"]))
        phases[number] = parse_phase(name, number, title, lines[start + 1:stop])


def find_heading(lines, heading):
    for index, line in enumerate(lines):
        if line.strip() == heading:
            return index
    fail("%s: heading `%s` not found" % (SETUP_REFERENCE, heading))


def split_row(line):
    if len(line) < 2 or not line.startswith("|") or not line.endswith("|"):
        fail("%s: table row is not bounded by pipes" % SETUP_REFERENCE)
    return [cell.strip() for cell in line[1:-1].split("|")]


def is_separator_row(cells):
    return all(cell and set(cell) <= set("-: ") for cell in cells)


def parse_config_rows(lines):
    start = find_heading(lines, CONFIG_HEADING)
    rows = []
    header_seen = False
    separator_seen = False
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        stripped = line.strip()
        if not stripped.startswith("|"):
            if header_seen:
                break
            continue
        cells = split_row(stripped)
        if not header_seen:
            if tuple(cells) != CONFIG_COLUMNS:
                fail("%s: unexpected config table header `%s`" % (SETUP_REFERENCE, stripped))
            header_seen = True
            continue
        if not separator_seen:
            separator_seen = True
            continue
        if is_separator_row(cells):
            continue
        if len(cells) != 4:
            fail("%s: config table row has %d cells, expected 4" % (SETUP_REFERENCE, len(cells)))
        code = FIELD_CODE.search(cells[0])
        if not code:
            fail("%s: config table row has no backticked field name" % SETUP_REFERENCE)
        rows.append({
            "field": code.group(1),
            "owner": cells[1],
            "needed_by": cells[2],
            "requirement": cells[3],
        })
    if not rows:
        fail("%s: the config table has no data rows" % SETUP_REFERENCE)
    return rows


def folder_name(value):
    # WHY: Inputs/<role>/ is a pattern, only the shared parent folder is created.
    parts = [part for part in value.split("/") if part and "<" not in part and ">" not in part]
    if not parts:
        return ""
    return "/".join(parts) + "/"


def parse_workspace_folders(lines):
    start = find_heading(lines, WORKSPACE_HEADING)
    folders = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        match = FOLDER_BULLET.match(line)
        if not match:
            continue
        name = folder_name(match.group(1))
        if name and name not in folders:
            folders.append(name)
    if not folders:
        fail("%s: no folder bullets found under `%s`" % (SETUP_REFERENCE, WORKSPACE_HEADING))
    for name in ("Plans/",) + AGENT_DESK_FOLDERS:
        if name not in folders:
            folders.append(name)
    return folders


def generated_comment(source_reference):
    return "<!-- Generated by %s from %s. Do not edit by hand. -->" % (GENERATOR, source_reference)


def reference_text(value):
    stripped = value.strip()
    if not stripped:
        return "PENDING"
    return stripped


def one_line(value):
    return " ".join(value.split())


def render_phase(phase):
    number = phase["number"]
    title = phase["title"]
    fields = phase["fields"]
    lines = []
    lines.append("---")
    lines.append('title: "Phase %d plan: %s"' % (number, title))
    lines.append("description: Working copy of the phase %d contract, to fill in under migration-workspace/Plans/ and never commit." % number)
    lines.append("trigger_phrases:")
    lines.append("  - Phase %d migration plan" % number)
    lines.append("  - migration phase gate and exit criteria")
    lines.append("  - Jortt to Moneybird migration")
    lines.append("importance_tier: normal")
    lines.append("contextType: implementation")
    lines.append("version: 1.0.0.0")
    lines.append("---")
    # The notice follows the frontmatter because validators read frontmatter only from the first line.
    lines.append(generated_comment("references/migration/%s" % phase["file"]))
    lines.append("")
    lines.append("# Phase %d plan: %s" % (number, title))
    lines.append("")
    lines.append("This is the working copy of the phase contract in [%s](../../../references/migration/%s). Fill it in under `migration-workspace/Plans/` and never commit it." % (phase["file"], phase["file"]))
    lines.append("")
    lines.append("## Status")
    lines.append("")
    lines.append("| Item | Value |")
    lines.append("|---|---|")
    lines.append("| Status | NOT STARTED |")
    lines.append("| Owner | PENDING |")
    lines.append("| Started | PENDING |")
    lines.append("| Gate passed | PENDING |")
    lines.append("| Last journal checkpoint | PENDING |")
    lines.append("| Evidence index | PENDING |")
    lines.append("")
    lines.append("## Goal")
    lines.append("")
    lines.append(reference_text(fields["Goal"]))
    lines.append("")
    lines.append("## Mechanisms")
    lines.append("")
    lines.append(", ".join("M%d" % mechanism for mechanism in phase["mechanisms"]) or "PENDING")
    lines.append("")
    lines.append("## Entry criteria")
    lines.append("")
    lines.append("- [ ] %s" % one_line(reference_text(fields["Entry criteria"])))
    lines.append("")
    lines.append("## Nested sub-goals")
    lines.append("")
    for subgoal in phase["subgoals"]:
        lines.append("- [ ] **%s**: %s" % (subgoal["id"], subgoal["text"]))
        lines.append("  - Check: %s" % subgoal["check"])
        lines.append("  - Evidence: PENDING")
    for name in ("Inputs", "Owner-tagged actions", "Tool route", "Outputs and evidence artifacts"):
        lines.append("")
        lines.append("## %s" % name)
        lines.append("")
        lines.append(reference_text(fields[name]))
    lines.append("")
    lines.append("## Numeric exit gate")
    lines.append("")
    lines.append(reference_text(fields["Numeric exit gate"]))
    lines.append("")
    lines.append("- [ ] Every exit-gate item verified against recorded evidence")
    for name in ("Stop conditions", "Rollback or compensation", "Resume rule"):
        lines.append("")
        lines.append("## %s" % name)
        lines.append("")
        lines.append(reference_text(fields[name]))
    lines.append("")
    lines.append("## Run record")
    lines.append("")
    lines.append("| Date | Event | Journal state | Evidence path | Note |")
    lines.append("|---|---|---|---|---|")
    lines.append("|  |  |  |  |  |")
    return "\n".join(lines) + "\n"


def render_dashboard(phases):
    lines = []
    lines.append("---")
    lines.append("title: Migration phase dashboard")
    lines.append("description: Master status table for the 23 phases of the Jortt to Moneybird migration.")
    lines.append("trigger_phrases:")
    lines.append("  - migration phase dashboard")
    lines.append("  - migration phase gate and exit criteria")
    lines.append("  - Jortt to Moneybird migration")
    lines.append("importance_tier: normal")
    lines.append("contextType: implementation")
    lines.append("version: 1.0.0.0")
    lines.append("---")
    lines.append(generated_comment("references/migration/phases-*.md and references/migration/%s" % PHASE_22_REFERENCE))
    lines.append("")
    lines.append("# Migration phase dashboard")
    lines.append("")
    lines.append("Keep these rows current with M9 in [shared-mechanisms.md](../../references/migration/shared-mechanisms.md#m9-master-phase-dashboard).")
    lines.append("")
    lines.append("| Phase | Title | Status | Contract check | Owner | Evidence link | Due date | Exceptions | Last resume checkpoint |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for phase in phases:
        lines.append("| %d | %s | NOT STARTED | PENDING | PENDING | PENDING | PENDING | 0 | PENDING |"
                     % (phase["number"], phase["title"]))
    return "\n".join(lines) + "\n"


def render_config(rows):
    fields = []
    for row in rows:
        fields.append({
            "field": row["field"],
            "owner": row["owner"],
            "needed_by": row["needed_by"],
            "requirement": row["requirement"],
            "value": "PENDING",
            "evidence": "PENDING",
            "approved_by": "PENDING",
            "approved_on": "PENDING",
        })
    document = {
        "_generated": "Generated by %s from %s. Do not edit by hand." % (GENERATOR, SETUP_REFERENCE),
        "config_version": 1,
        "status": "DRAFT",
        "fields": fields,
    }
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def render_folders(folders):
    lines = ["# Generated by %s from %s. Do not edit by hand." % (GENERATOR, SETUP_REFERENCE)]
    lines.extend(folders)
    return "\n".join(lines) + "\n"


def build_outputs():
    collected = {}
    for path in phase_reference_paths():
        parse_phase_file(path, collected)
    missing = [number for number in range(PHASE_TOTAL) if number not in collected]
    if missing:
        fail("expected %d phases numbered 0 to %d, found %d (missing %s)"
             % (PHASE_TOTAL, PHASE_TOTAL - 1, len(collected),
                ", ".join(str(number) for number in missing)))
    if len(collected) != PHASE_TOTAL:
        fail("expected %d phases numbered 0 to %d, found %d"
             % (PHASE_TOTAL, PHASE_TOTAL - 1, len(collected)))
    phases = [collected[number] for number in range(PHASE_TOTAL)]

    setup_lines = read_lines(os.path.join(REFERENCE_DIR, "overview-and-setup.md"))

    outputs = {}
    for phase in phases:
        name = "phase-%02d-plan.md" % phase["number"]
        outputs[os.path.join(PHASE_OUTPUT_DIR, name)] = render_phase(phase)
    outputs[os.path.join(OUTPUT_DIR, "migration-config.template.json")] = render_config(parse_config_rows(setup_lines))
    outputs[os.path.join(OUTPUT_DIR, "phase-dashboard.template.md")] = render_dashboard(phases)
    outputs[os.path.join(OUTPUT_DIR, "workspace-folders.txt")] = render_folders(parse_workspace_folders(setup_lines))
    return outputs


def main(argv):
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Generate the migration plan kit under assets/migration/.",
    )
    parser.add_argument("--check", action="store_true", help="verify the generated files without writing them")
    args = parser.parse_args(argv)
    outputs = build_outputs()

    if args.check:
        problems = []
        for path in sorted(outputs):
            expected = outputs[path]
            if not os.path.isfile(path):
                problems.append("missing: %s" % display(path))
                continue
            try:
                with open(path, "r", encoding="utf-8", newline="") as handle:
                    current = handle.read()
            except OSError as exc:
                problems.append("unreadable: %s (%s)" % (display(path), exc))
                continue
            if current != expected:
                problems.append("differs: %s" % display(path))
        if problems:
            for problem in problems:
                print(problem)
            return 1
        print("%d generated files match" % len(outputs))
        return 0

    written = 0
    unchanged = 0
    for path in sorted(outputs):
        expected = outputs[path]
        if os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8", newline="") as handle:
                    current = handle.read()
            except OSError:
                current = None
            if current == expected:
                unchanged += 1
                continue
        try:
            directory = os.path.dirname(path)
            if directory and not os.path.isdir(directory):
                os.makedirs(directory)
            with open(path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(expected)
        except OSError as exc:
            fail("cannot write %s: %s" % (display(path), exc))
        written += 1
        print("wrote %s" % display(path))
    print("%d written, %d unchanged" % (written, unchanged))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
