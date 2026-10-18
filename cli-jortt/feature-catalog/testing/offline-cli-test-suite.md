---
title: "Offline CLI test suite"
description: "Runs the jortt-cli contract against a local OpenAPI file with fake credentials and no network call."
trigger_phrases:
  - "Offline CLI test suite"
  - "jortt-cli tests"
  - "run-tests.sh"
  - "trimmed OpenAPI fixture"
version: 1.0.0.0
---

# Offline CLI test suite (cli/jortt-cli/tests/run-tests.sh)

## 1. OVERVIEW

Runs the jortt-cli contract against a local OpenAPI file with fake credentials and no network call.

The suite is the repeatable proof that slugs, gates, output handling, redaction and exit codes still work. It is safe to run before a session because it never contacts Jortt.

---

## 2. HOW IT WORKS

### Core Behavior

`bash cli/jortt-cli/tests/run-tests.sh` reads `JORTT_OPENAPI_FILE` when it is set and otherwise reads the trimmed Swagger fixture shipped beside the tests. It runs each case through the CLI with `test-client` and `test-secret`, prints `PASS` or `FAIL` per case, ends with the pass and fail totals and exits non-zero when any case fails.

### Coverage

The suite checks unique slugs and the collision rule, the description output, the dry-run URL, the write and scope gates, the token scope source labels and the fallback warning, parameter name and type checks, the output workspace guard for `call` and `fetch`, the summary and full-body output modes, the print body guard for every marker, API error redaction with its private log, `--all` paging and its host check, the single 401 retry and the 429 wait and budget. It also injects faults for the upstream, spec and token exit codes. The token, request and paging paths run against a stub `curl` and a logging `sleep`, so the tests stay offline and never wait.

### Fixture

The default fixture is a trimmed Swagger 2.0 document that keeps the operations the cases exercise. Point `JORTT_OPENAPI_FILE` at another file to run the same cases against a different spec.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Test | Runs the offline cases and reports the pass and fail totals. |
| [`cli/jortt-cli/tests/fixtures/openapi-trimmed.json`](../../cli/jortt-cli/tests/fixtures/openapi-trimmed.json) | Test | Trimmed Swagger 2.0 fixture the suite reads by default. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`../../../.github/workflows/skill-health.yml`](../../../.github/workflows/skill-health.yml) | Test harness | Runs the suite on every push and pull request. |
| [`cli/jortt-cli/README.md`](../../cli/jortt-cli/README.md) | Reference | Documents the suite command, the offline fixture and the expected pass line. |

---

## 4. SOURCE METADATA

- Group: Testing and CI
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `testing/offline-cli-test-suite.md`

Related references:
- [skill-health-ci.md](skill-health-ci.md) - Skill health CI
