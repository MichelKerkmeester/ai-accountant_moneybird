---
title: "jortt-cli tests: Offline Contract Suite"
description: "Offline contract tests for jortt-cli that stub curl and sleep so no network call or real wait happens."
trigger_phrases:
  - "jortt-cli tests"
  - "jortt cli offline suite"
  - "jortt cli contract tests"
version: 1.0.0.0
---

# jortt-cli tests: Offline Contract Suite

---

## 1. OVERVIEW

`cli/jortt-cli/tests/` holds the offline contract suite for `jortt-cli`. `run-tests.sh` copies the CLI and its libraries into a temporary root, stubs `curl` and `sleep` ahead of `PATH`, and exercises the command surface against a trimmed OpenAPI fixture. No network call happens, and a trap removes the temporary root on exit.

Current state:

- The suite runs 28 checks covering slug generation and collision order, `describe` output, dry-run URL building, the non-GET refusal, scope checks, token status sources, `--out` workspace confinement, the `--print-body` refusal under agent session markers, API error redaction, fault exits 1, 2 and 6, paged `--all` merging, the 401 retry, 429 `Retry-After` handling and the HTTPS-only signed download.
- `fixtures/openapi-trimmed.json` is the trimmed Swagger 2.0 document the suite reads unless `JORTT_OPENAPI_FILE` names another file.

---

## 2. DIRECTORY TREE

```text
tests/
+-- run-tests.sh                 # Offline contract suite
+-- fixtures/
|   `-- openapi-trimmed.json     # Trimmed Swagger 2.0 spec
`-- README.md
```

---

## 3. BOUNDARIES

- The suite exports `JORTT_OPENAPI_FILE`, test credentials and `JORTT_ENV_FILE=/dev/null` for each run, so no real environment file or cache is read.
- A stub `curl` answers from files under `STUB_*` variables and a stub `sleep` records retry delays, while `TMPDIR` points inside the temporary root.
- `--print-body` runs with the agent session markers unset for the allowed case, then once per marker for the refusal cases.

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
- [`../lib/README.md`](../lib/README.md) covers the libraries this suite exercises.
- [`../../../manual-testing-playbook/manual-testing-playbook.md`](../../../manual-testing-playbook/manual-testing-playbook.md) holds the operator scenarios for the live CLI.
