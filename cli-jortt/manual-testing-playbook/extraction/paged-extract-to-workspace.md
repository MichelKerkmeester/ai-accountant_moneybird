---
title: "JRT-003 -- Paged extract to workspace"
description: "This scenario validates Paged extract to workspace for `JRT-003`. Its objective is to confirm a paged read saves its merged result under migration-workspace and rejects an outside path."
version: 1.0.0.0
---

# JRT-003 -- Paged extract to workspace

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-003`.

---

## 1. OVERVIEW

This scenario validates Paged extract to workspace for `JRT-003`. Its objective is to confirm a paged read saves its merged result under migration-workspace and rejects an outside path.

### Why This Matters

A source register needs every page and must stay out of tracked files. Both halves of that promise are checked here.

This scenario makes a live read-only request. Run it only with an operator-approved read-only key.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-003` and confirm the expected signals without contradictory evidence.

- Objective: Confirm a paged read saves its merged result under migration-workspace and rejects an outside path.
- Real user request: `Extract expenses for one VAT year into the migration workspace and confirm an outside path is blocked.`
- Prompt: `Extract expenses for one VAT year into the migration workspace and confirm an outside path is blocked.`
- Expected execution process: The agent confirms the operator approved a live read, runs the paged extract and then tries an outside destination.
- Expected signals: Step 1: `HTTP 200, items:` with a count, and the file sits below `migration-workspace/`. Step 2: exit 5 before any request, and no file appears at the outside path.
- Desired user-visible outcome: The allowed command stores one array and reports only status and count. The outside destination fails before a request.
- Pass/fail: PASS if all pages merge into one JSON array in the workspace and the outside path exits 5, FAIL if the body prints with `--out` or an outside file is created.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Extract expenses for one VAT year into the migration workspace and confirm an outside path is blocked.`

### Commands

1. `bash: jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-test.json`
2. `bash: jortt-cli call list-expenses --all --out /tmp/jortt-outside.json`

### Expected

- Step 1: `HTTP 200, items:` with a count, and the file sits below `migration-workspace/`.
- Step 2: exit 5 before any request, and no file appears at the outside path.

### Evidence

Both stdout lines, the exit codes and a listing that shows the saved file name. Never copy record contents.

### Pass / Fail

- **Pass**: All pages merge into one JSON array in the workspace and the outside path exits 5.
- **Fail**: The body prints with `--out` or an outside file is created.

### Failure Triage

1. Mark the scenario SKIP with the blocker named when live credentials are unavailable or not approved.
2. Review the expense recipe in `references/rest-api.md` and the paging and output rules in `references/cli.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/transport/paged-list-merge.md`](../../feature-catalog/transport/paged-list-merge.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Paging loop and output summary |
| [`cli/jortt-cli/lib/workspace.sh`](../../cli/jortt-cli/lib/workspace.sh) | Output path guard |

---

## 5. SOURCE METADATA

- Group: Extraction
- Playbook ID: JRT-003
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `extraction/paged-extract-to-workspace.md`
- Feature catalog entry: [`feature-catalog/transport/paged-list-merge.md`](../../feature-catalog/transport/paged-list-merge.md)
