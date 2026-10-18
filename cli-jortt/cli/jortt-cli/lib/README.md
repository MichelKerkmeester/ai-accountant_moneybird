---
title: "jortt-cli lib: Sourced Shell Libraries"
description: "The four Bash libraries jortt-cli sources at startup: shared helpers, the workspace output guard, token and request handling, and command handlers."
trigger_phrases:
  - "jortt-cli lib"
  - "jortt cli sourced libraries"
  - "jortt cli shell helpers"
version: 1.0.0.0
---

# jortt-cli lib: Sourced Shell Libraries

---

## 1. OVERVIEW

`cli/jortt-cli/lib/` holds the four Bash libraries the `jortt-cli` entry point sources at startup. Nothing here runs alone. Each file inherits the strict mode and the `ACCOUNTANT_ROOT` and `JORTT_SCRIPT_DIR` values the entry point sets first.

Current state:

- The load order is `common.sh`, `workspace.sh`, `api.sh`, `commands.sh`, and later files use helpers the earlier ones define.
- Public function names carry the `jortt_` prefix, and cross-file state travels in `JORTT_` globals such as `JORTT_SPEC_FILE`, `JORTT_ACCESS_TOKEN`, `JORTT_HTTP_STATUS` and `JORTT_HTTP_BODY`.
- Refusals exit through `jortt_error` in `common.sh`, so each keeps its documented exit code. A failed token request in `api.sh` prints its own message and exits 6 directly.

---

## 2. KEY FILES

| File | Responsibility |
|---|---|
| `common.sh` | `jortt_error`, print-body session guard, tool check, spec cache and validation, `.env` reading, credential and scope checks, token cache paths, curl quoting, operation lookup |
| `workspace.sh` | `jortt_resolve_output` keeps every `--out` target inside `migration-workspace/` and refuses escapes, symlinks and directory targets, and `jortt_write_output` saves atomically with owner-only permissions |
| `api.sh` | Request throttle, OAuth token fetch and private cache, authenticated requests, redacted API error reporting plus the workspace error log, 401 and 429 retry handling, HTTPS-only signed downloads |
| `commands.sh` | Parameter validation against the spec, URL building, the read-only gate, paged list merging, body summaries, and the `ops`, `describe`, `call`, `whoami` and `fetch` handlers |

---

## 3. BOUNDARIES AND FLOW

| Boundary | Rule |
|---|---|
| Imports | Files source nothing themselves. `jortt-cli` sources all four in the fixed order above |
| Exports | `jortt_*` functions and `JORTT_*` globals are the package surface for the entry point |
| Ownership | Spec parsing and credentials stay in `common.sh`, workspace path safety in `workspace.sh`, HTTP in `api.sh`, command behavior in `commands.sh` |

Main flow:

```text
command handler (commands.sh)
    |
    v
spec load and operation lookup (common.sh)
    |
    v
read gate and scope check (common.sh)
    |
    v
token and request (api.sh)
    |
    v
summary print or workspace save (commands.sh, workspace.sh)
```

---

## 4. VALIDATION

Run from the repository root:

```bash
bash cli-jortt/cli/jortt-cli/tests/run-tests.sh
```

Expected result: `Result: 28 passed, 0 failed`.

---

## 5. RELATED

- [`../README.md`](../README.md) describes the CLI package and its commands.
- [`../jortt-cli`](../jortt-cli) is the entry point that sources these files.
- [`../../../references/cli.md`](../../../references/cli.md) documents the command surface.
