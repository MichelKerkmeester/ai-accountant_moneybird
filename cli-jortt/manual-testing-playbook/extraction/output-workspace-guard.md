---
title: "JRT-016 -- Output workspace guard"
description: "This scenario validates Output workspace guard for `JRT-016`. Its objective is to confirm `call`, `get` and `fetch` reject an output path outside the migration workspace and accept a name inside it without writing."
version: 1.0.0.0
---

# JRT-016 -- Output workspace guard

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-016`.

---

## 1. OVERVIEW

This scenario validates Output workspace guard for `JRT-016`. Its objective is to confirm `call`, `get` and `fetch` reject an output path outside the migration workspace and accept a name inside it without writing.

### Why This Matters

Saved records and receipts must stay in the ignored workspace. A wrong destination has to fail before a request, so no partial data lands in a tracked folder.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-016` and confirm the expected signals without contradictory evidence.

- Objective: Confirm `call`, `get` and `fetch` reject an output path outside the migration workspace and accept a name inside it without writing.
- Real user request: `Show that jortt-cli refuses an output path outside the migration workspace.`
- Prompt: `Show that jortt-cli refuses an output path outside the migration workspace.`
- Expected execution process: The agent runs three outside destinations and one parent-traversal path, reads each exit code, then runs one dry run with a name inside the workspace.
- Expected signals: Steps 1, 3 and 4: exit 5 with `jortt-cli: Output path must resolve inside migration-workspace.` Step 2: exit 5 with `jortt-cli: Output path must not escape migration-workspace.` Step 5: exit 0 with the dry-run `GET` line and `Body: none`. No step writes a file.
- Desired user-visible outcome: The operator sees that only a workspace-relative name passes, and that the passing dry run saves nothing.
- Pass/fail: PASS if steps 1 to 4 exit 5 before any request and step 5 exits 0 without creating a file, FAIL if an outside path is accepted, a request is sent or a file is created.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Show that jortt-cli refuses an output path outside the migration workspace.`

### Commands

1. `bash: jortt-cli call list-expenses --out /tmp/jortt-outside.json --dry-run`
2. `bash: jortt-cli call list-expenses --out ../escape.json --dry-run`
3. `bash: jortt-cli get /v3/customers --out /tmp/jortt-outside.json`
4. `bash: jortt-cli fetch https://example.invalid/never-request.bin --out /tmp/jortt-outside.bin`
5. `bash: JORTT_SCOPES=expenses:read jortt-cli call list-expenses --out playbook-guard.json --dry-run`

### Expected

- Step 1: exit 5 with `jortt-cli: Output path must resolve inside migration-workspace.`
- Step 2: exit 5 with `jortt-cli: Output path must not escape migration-workspace.`
- Step 3: exit 5 with the outside-path message before any request.
- Step 4: exit 5 with the outside-path message before any request.
- Step 5: exit 0 with `GET https://api.jortt.nl/v3/expenses` and `Body: none`, and no file appears under `migration-workspace/`.

### Evidence

The five messages and exit codes, plus a workspace listing that shows no new file.

### Pass / Fail

- **Pass**: Steps 1 to 4 exit 5 before any request and step 5 exits 0 without creating a file.
- **Fail**: An outside path is accepted, a request is sent or a file is created.

### Failure Triage

1. Confirm each path was copied exactly, including the parent-directory form in step 2.
2. Inspect `jortt_resolve_output` in `cli/jortt-cli/lib/workspace.sh`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/safety-gates/output-workspace-guard.md`](../../feature-catalog/safety-gates/output-workspace-guard.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/workspace.sh`](../../cli/jortt-cli/lib/workspace.sh) | Workspace resolution and symlink checks |
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Resolve order in `call`, `get` and `fetch` |
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Out-of-workspace cases for `call` and `fetch` |

---

## 5. SOURCE METADATA

- Group: Extraction
- Playbook ID: JRT-016
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `extraction/output-workspace-guard.md`
- Feature catalog entry: [`feature-catalog/safety-gates/output-workspace-guard.md`](../../feature-catalog/safety-gates/output-workspace-guard.md)
