---
title: "Print body guard"
description: "Refuses --print-body with exit 2 when an agent session marker is set, so a full record body never reaches a terminal transcript."
trigger_phrases:
  - "Print body guard"
  - "jortt-cli --print-body"
  - "agent session marker"
  - "jortt-cli exit 2"
version: 1.0.0.0
---

# Print body guard (--print-body)

## 1. OVERVIEW

Refuses --print-body with exit 2 when an agent session marker is set, so a full record body never reaches a terminal transcript.

`call` and `get` print a summary by default, and only an operator request prints a full body. This gate stops an agent session that inherits its own marker from using that path.

---

## 2. HOW IT WORKS

### Core Behavior

The guard reads the environment for `CLAUDECODE`, `AI_SESSION_CHILD`, `ACCOUNTANT_AGENT_SESSION` or `CODEX_SANDBOX`. A non-empty value refuses the command with exit 2 and a one-line reason that names the marker and points at `--out`. The check runs before the spec load in `call`, before the output path resolves in `get` and again on the print path itself.

### Scope

The guard covers only `--print-body`. `--out` saves the full body inside the migration workspace and prints the summary, so a record read under an agent session still has a supported route. A summary print, `--dry-run` and the gate commands are not affected.

### Configuration

The marker list is fixed in the CLI, and no flag disables it. Unsetting a marker in the shell sits outside the command contract, which is why the reference states that agents never use `--print-body`.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_check_print_body_allowed` reads the markers and exits 2. |
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_call`, `jortt_cmd_get` and `jortt_print_or_save` call the guard. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Refuses every marker for `call`, refuses a marker for `get` and allows `--print-body` without a marker. |
| [`references/cli.md`](../../references/cli.md) | Reference | Documents the refusal and the supported `--out` route. |

---

## 4. SOURCE METADATA

- Group: Safety gates
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `safety-gates/print-body-guard.md`

Related references:
- [write-lock.md](write-lock.md) - Write lock
- [scope-check.md](scope-check.md) - Scope check
- [output-workspace-guard.md](output-workspace-guard.md) - Output workspace guard
