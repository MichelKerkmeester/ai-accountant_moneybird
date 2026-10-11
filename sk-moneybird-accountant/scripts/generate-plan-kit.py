#!/usr/bin/env python3
"""Generate the migration plan kit and the migration packet templates.

Generated packet files hold placeholders only. Real migration data lives in
the git-ignored migration-workspace/ folder, so the tracked kit stays
shareable. The json files that spec-kit tooling writes into a packet are
never produced, deleted or checked by this script.

Output is byte-stable: sorted inputs, no timestamps, no randomness.

Usage:
    python3 -I scripts/generate-plan-kit.py
    python3 -I scripts/generate-plan-kit.py --check
"""

import argparse
import json
import os
import re
import shutil
import sys

GENERATOR = "scripts/generate-plan-kit.py"
PACKET_GENERATOR = "sk-moneybird-accountant/scripts/generate-plan-kit.py"
SETUP_REFERENCE = "references/migration/overview-and-setup.md"
PARENT_SOURCE = "references/migration/README.md"
PARENT_REFERENCE_LINK = "../../sk-moneybird-accountant/references/migration/README.md"
PARENT_MECHANISMS_LINK = "../../sk-moneybird-accountant/references/migration/shared-mechanisms.md"
CHILD_LINK_ROOT = "../../../sk-moneybird-accountant/references/migration/"
CHILD_MECHANISMS_LINK = "../../../sk-moneybird-accountant/references/migration/shared-mechanisms.md"
PHASE_22_REFERENCE = "phase-22-completion.md"
PHASE_TOTAL = 23
PARENT_FOLDER = "000-migration-template"
CONFIG_HEADING = "## Required `MIGRATION_CONFIG` fields"
CONFIG_COLUMNS = ("Field", "Owner", "Needed by", "Required value or evidence")
WORKSPACE_HEADING = "## Workspace layout"
MECHANISMS_PREFIX = "Mechanisms used:"
SUBGOAL_CHECK = ". Check: "
LINK_FROM = "](./"
OPERATOR_TAG = "[Operator]"
EMPTY_VALUE = "PENDING"
HEADING_LIMIT = 80
FIXED_ROW_FLOOR = 900
METADATA_FILES = ("description.json", "graph-metadata.json")
# Contract fields run to several paragraphs and lists, so a template may only
# place them as a standalone block, once, where the markdown stays intact.
BLOCK_TOKENS = (
    "{{GOAL}}", "{{ENTRY}}", "{{INPUTS}}", "{{ACTIONS}}", "{{TOOL_ROUTE}}",
    "{{OUTPUTS}}", "{{EXIT_GATE}}", "{{STOPS}}", "{{ROLLBACK}}", "{{RESUME}}",
)

OPERATOR_DECISION_FIELDS = (
    "Status: PENDING",
    "Decision: [Operator decision]",
    "Approved by: [Operator name]",
    "Date: [YYYY-MM-DD]",
    "Evidence: [evidence path in migration-workspace/]",
)

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_DIR = os.path.dirname(SKILL_DIR)
REFERENCE_DIR = os.path.join(SKILL_DIR, "references", "migration")
OUTPUT_DIR = os.path.join(SKILL_DIR, "assets", "migration")
TEMPLATE_DIR = os.path.join(OUTPUT_DIR, "spec-template")
LEGACY_PHASE_DIR = os.path.join(OUTPUT_DIR, "phases")
PACKET_DIR = os.path.join(REPO_DIR, "specs", PARENT_FOLDER)

CHILD_TEMPLATES = (
    ("spec.md.tmpl", "spec.md"),
    ("goal.md.tmpl", "goal.md"),
    ("plan.md.tmpl", "plan.md"),
    ("tasks.md.tmpl", "tasks.md"),
    ("acceptance-criteria.md.tmpl", "acceptance-criteria.md"),
    ("decision-record.md.tmpl", "decision-record.md"),
    ("implementation-summary.md.tmpl", "implementation-summary.md"),
)

PARENT_TEMPLATES = (
    ("parent-spec.md.tmpl", "spec.md"),
    ("parent-goal.md.tmpl", "goal.md"),
)

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
PLACEHOLDER = re.compile(r"\{\{[A-Za-z0-9_]+\}\}")
NUMBERED_LINE = re.compile(r"^\d+[.)]\s+")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+")

ROW_PATTERNS = {
    "REQ": re.compile(r"REQ-(\d+)"),
    "AC": re.compile(r"AC-(\d+)"),
    "D": re.compile(r"(?<![A-Za-z0-9])D-(\d+)"),
    "T": re.compile(r"(?<![A-Za-z0-9])T(\d{3})(?!\d)"),
}


def fail(message):
    sys.stderr.write("generate-plan-kit: error: %s\n" % message)
    raise SystemExit(2)


def display(path):
    # WHY: only repo-relative paths are printed, so no home folder ever leaks.
    try:
        return os.path.relpath(path, REPO_DIR)
    except ValueError:
        return path


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", newline="") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (display(path), exc))


def read_lines(path):
    return read_text(path).split("\n")


def template_path(name):
    return os.path.join(TEMPLATE_DIR, name)


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
    return text.replace(LINK_FROM, CHILD_LINK_ROOT)


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


def packet_comment(source_reference):
    return "<!-- Generated by %s from %s. Edit the phase reference and regenerate. -->" % (
        PACKET_GENERATOR, source_reference)


def reference_text(value):
    stripped = value.strip()
    if not stripped:
        return EMPTY_VALUE
    return stripped


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


def phase_title_slug(title):
    # WHY: child folder names must stay stable and link-safe.
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


def child_folder(phase):
    return "%03d-phase-%d-%s" % (phase["number"] + 1, phase["number"],
                                 phase_title_slug(phase["title"]))


def packet_link(phase):
    folder = child_folder(phase)
    return "[%s](../%s/spec.md)" % (folder, folder)


def next_row_number(text, kind):
    # Template rows numbered 900 and up are fixed phase-wide rows, so the
    # generated rows count up from the lower range and never collide.
    highest = 0
    for match in ROW_PATTERNS[kind].finditer(text):
        value = int(match.group(1))
        if FIXED_ROW_FLOOR > value > highest:
            highest = value
    return highest + 1


def row_identifier(kind, number):
    if kind == "T":
        return "T%03d" % number
    return "%s-%03d" % (kind, number)


def subgoal_requirements(subgoals, start):
    rows = []
    number = start
    for subgoal in subgoals:
        rows.append("| %s | %s: %s | %s |"
                    % (row_identifier("REQ", number), subgoal["id"], subgoal["text"], subgoal["check"]))
        number += 1
    return "\n".join(rows)


def subgoal_tasks(subgoals, start):
    lines = []
    number = start
    for subgoal in subgoals:
        lines.append("- [ ] %s [%s] %s (Check: %s)"
                     % (row_identifier("T", number), subgoal["id"], subgoal["text"], subgoal["check"]))
        number += 1
    return "\n".join(lines)


def subgoal_acceptance(subgoals, start):
    rows = []
    number = start
    for subgoal in subgoals:
        rows.append("| %s | %s | PENDING | PENDING |"
                    % (row_identifier("AC", number), subgoal["check"]))
        number += 1
    return "\n".join(rows)


def subgoal_criteria(subgoals):
    return "\n".join("- [ ] %s: %s" % (subgoal["id"], subgoal["check"]) for subgoal in subgoals)


def operator_actions(actions):
    found = []
    for raw in actions.split("\n"):
        line = NUMBERED_LINE.sub("", raw.strip(), count=1)
        if not line:
            continue
        for chunk in SENTENCE_SPLIT.split(line):
            chunk = chunk.strip()
            if chunk.startswith(OPERATOR_TAG):
                found.append(chunk[len(OPERATOR_TAG):].strip())
    return found


def operator_heading(text):
    clean = " ".join(text.split())
    if not clean:
        return "[Decision title]"
    if len(clean) <= HEADING_LIMIT:
        return clean
    cut = clean[:HEADING_LIMIT]
    space = cut.rfind(" ")
    if space <= 0:
        return cut
    return cut[:space]


def operator_decisions(actions, start):
    entries = operator_actions(actions)
    if not entries:
        entries = [""]
    blocks = []
    number = start
    for entry in entries:
        block = ["### %s: %s" % (row_identifier("D", number), operator_heading(entry)), ""]
        block.extend(OPERATOR_DECISION_FIELDS)
        blocks.append("\n".join(block))
        number += 1
    return "\n\n".join(blocks)


def read_templates():
    texts = {}
    for name, _ in CHILD_TEMPLATES + PARENT_TEMPLATES:
        texts[name] = read_text(template_path(name))
    return texts


def insert_generated_comment(text, source, name):
    lines = text.split("\n")
    if not lines or lines[0] != "---":
        fail("%s does not start with frontmatter" % display(template_path(name)))
    # WHY: validators read frontmatter only from the first line, so the notice
    # goes directly after the closing fence.
    for index in range(1, len(lines)):
        if lines[index] == "---":
            lines.insert(index + 1, packet_comment(source))
            return "\n".join(lines)
    fail("%s has no closing frontmatter fence" % display(template_path(name)))


def check_block_tokens(template, name):
    lines = template.split("\n")
    for token in BLOCK_TOKENS:
        uses = [index for index, line in enumerate(lines) if token in line]
        if len(uses) > 1:
            fail("%s uses %s more than once" % (display(template_path(name)), token))
        for index in uses:
            before = lines[index - 1] if index > 0 else ""
            after = lines[index + 1] if index + 1 < len(lines) else ""
            if lines[index].strip() != token or before.strip() or after.strip():
                fail("%s places %s outside a standalone block line"
                     % (display(template_path(name)), token))


def render_packet(template, name, values, source):
    for match in PLACEHOLDER.finditer(template):
        if match.group(0) not in values:
            fail("%s has unknown token %s" % (display(template_path(name)), match.group(0)))
    check_block_tokens(template, name)
    text = template
    for token in sorted(values):
        text = text.replace(token, values[token])
    if "{{" in text:
        leftover = PLACEHOLDER.search(text)
        fail("%s rendered file still holds %s"
             % (display(template_path(name)), leftover.group(0) if leftover else "{{"))
    return insert_generated_comment(text, source, name)


def child_tokens(phase, phases, texts):
    number = phase["number"]
    folder = child_folder(phase)
    fields = phase["fields"]
    subgoals = phase["subgoals"]
    mechanisms = ", ".join("M%d" % value for value in phase["mechanisms"]) or EMPTY_VALUE
    previous = phases[number - 1] if number > 0 else None
    following = phases[number + 1] if number + 1 < len(phases) else None
    values = {
        "{{PHASE_NUMBER}}": str(number),
        "{{PHASE_POSITION}}": str(number + 1),
        "{{CHILD_COUNT}}": str(len(phases)),
        "{{PHASE_TITLE}}": phase["title"],
        "{{PHASE_TITLE_SLUG}}": phase_title_slug(phase["title"]),
        "{{CHILD_FOLDER}}": folder,
        "{{PACKET_POINTER}}": "%s/%s" % (PARENT_FOLDER, folder),
        "{{PARENT_FOLDER}}": PARENT_FOLDER,
        "{{REFERENCE_FILE}}": phase["file"],
        "{{REFERENCE_LINK}}": CHILD_LINK_ROOT + phase["file"],
        "{{MECHANISMS_LINK}}": CHILD_MECHANISMS_LINK,
        "{{GOAL}}": reference_text(fields["Goal"]),
        "{{MECHANISMS}}": mechanisms,
        "{{ENTRY}}": reference_text(fields["Entry criteria"]),
        "{{INPUTS}}": reference_text(fields["Inputs"]),
        "{{ACTIONS}}": reference_text(fields["Owner-tagged actions"]),
        "{{TOOL_ROUTE}}": reference_text(fields["Tool route"]),
        "{{OUTPUTS}}": reference_text(fields["Outputs and evidence artifacts"]),
        "{{EXIT_GATE}}": reference_text(fields["Numeric exit gate"]),
        "{{STOPS}}": reference_text(fields["Stop conditions"]),
        "{{ROLLBACK}}": reference_text(fields["Rollback or compensation"]),
        "{{RESUME}}": reference_text(fields["Resume rule"]),
        "{{SUBGOAL_COUNT}}": str(len(subgoals)),
        "{{REQUIREMENT_ROWS}}": subgoal_requirements(
            subgoals, next_row_number(texts["spec.md.tmpl"], "REQ")),
        "{{SUBGOAL_TASKS}}": subgoal_tasks(
            subgoals, next_row_number(texts["tasks.md.tmpl"], "T")),
        "{{AC_ROWS}}": subgoal_acceptance(
            subgoals, next_row_number(texts["acceptance-criteria.md.tmpl"], "AC")),
        "{{GOAL_CRITERIA}}": subgoal_criteria(subgoals),
        "{{OPERATOR_DECISIONS}}": operator_decisions(
            fields["Owner-tagged actions"],
            next_row_number(texts["decision-record.md.tmpl"], "D")),
        "{{PREV_LINK}}": packet_link(previous) if previous else "None (first phase)",
        "{{NEXT_LINK}}": packet_link(following) if following else "None (last phase)",
    }
    return values


def parent_tokens(phases):
    map_rows = []
    binding_rows = []
    for phase in phases:
        folder = child_folder(phase)
        map_rows.append("| %d | [%s](./%s/spec.md) | Phase %d: %s | Planned |"
                        % (phase["number"], folder, folder, phase["number"], phase["title"]))
        binding_rows.append("| %d | `%s/goal.md` |" % (phase["number"], folder))
    values = {
        "{{PACKET_POINTER}}": PARENT_FOLDER,
        "{{PARENT_FOLDER}}": PARENT_FOLDER,
        "{{REFERENCE_LINK}}": PARENT_REFERENCE_LINK,
        "{{MECHANISMS_LINK}}": PARENT_MECHANISMS_LINK,
        "{{CHILD_COUNT}}": str(len(phases)),
        "{{PHASE_MAP_ROWS}}": "\n".join(map_rows),
        "{{BINDING_ROWS}}": "\n".join(binding_rows),
    }
    return values


def add_packet_outputs(outputs, phases, texts):
    for phase in phases:
        folder = child_folder(phase)
        values = child_tokens(phase, phases, texts)
        source = "references/migration/%s" % phase["file"]
        for template_name, output_name in CHILD_TEMPLATES:
            outputs[os.path.join(PACKET_DIR, folder, output_name)] = render_packet(
                texts[template_name], template_name, values, source)
    values = parent_tokens(phases)
    for template_name, output_name in PARENT_TEMPLATES:
        outputs[os.path.join(PACKET_DIR, output_name)] = render_packet(
            texts[template_name], template_name, values, PARENT_SOURCE)


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
    texts = read_templates()

    outputs = {}
    outputs[os.path.join(OUTPUT_DIR, "migration-config.template.json")] = render_config(parse_config_rows(setup_lines))
    outputs[os.path.join(OUTPUT_DIR, "phase-dashboard.template.md")] = render_dashboard(phases)
    outputs[os.path.join(OUTPUT_DIR, "workspace-folders.txt")] = render_folders(parse_workspace_folders(setup_lines))
    add_packet_outputs(outputs, phases, texts)
    return outputs


def unexpected_markdown_files(outputs):
    found = []
    for root, dirs, files in os.walk(PACKET_DIR):
        dirs.sort()
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            if path not in outputs:
                found.append(path)
    return found


def unexpected_files(outputs):
    # The template packet is published, so every file in it must be either a
    # generated doc or spec-kit metadata beside a generated packet. Anything
    # else is reported, never deleted, because the generator does not own it.
    packet_dirs = set(os.path.dirname(path) for path in outputs
                      if path.startswith(PACKET_DIR + os.sep))
    found = []
    for root, dirs, files in os.walk(PACKET_DIR):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(root, name)
            if path in outputs:
                continue
            if name in METADATA_FILES and root in packet_dirs:
                continue
            found.append(path)
    return found


def remove_tree(path):
    try:
        shutil.rmtree(path)
    except OSError as exc:
        fail("cannot remove %s: %s" % (display(path), exc))


def remove_file(path):
    try:
        os.remove(path)
    except OSError as exc:
        fail("cannot remove %s: %s" % (display(path), exc))


def check_outputs(outputs):
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
    for path in unexpected_files(outputs):
        problems.append("unexpected: %s" % display(path))
    if os.path.isdir(LEGACY_PHASE_DIR):
        problems.append("present: %s" % display(LEGACY_PHASE_DIR))
    if problems:
        for problem in problems:
            print(problem)
        return 1
    print("%d generated files match" % len(outputs))
    return 0


def write_outputs(outputs):
    removed = []
    if os.path.isdir(LEGACY_PHASE_DIR):
        remove_tree(LEGACY_PHASE_DIR)
        removed.append(LEGACY_PHASE_DIR)
    for path in unexpected_markdown_files(outputs):
        remove_file(path)
        removed.append(path)

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
    for path in removed:
        print("removed %s" % display(path))
    print("%d written, %d unchanged" % (written, unchanged))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Generate the migration plan kit and the migration packet templates.",
    )
    parser.add_argument("--check", action="store_true", help="verify the generated files without writing them")
    args = parser.parse_args(argv)
    outputs = build_outputs()
    if args.check:
        return check_outputs(outputs)
    return write_outputs(outputs)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
