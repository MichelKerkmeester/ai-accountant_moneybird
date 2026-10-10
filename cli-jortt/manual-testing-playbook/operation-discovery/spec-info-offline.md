---
title: "JRT-008 -- Spec info without network"
description: "This scenario validates Spec info without network for `JRT-008`. Its objective is to confirm spec info reports the loaded spec and a missing spec without any network call."
version: 1.0.0.0
---

# JRT-008 -- Spec info without network

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-008`.

---

## 1. OVERVIEW

This scenario validates Spec info without network for `JRT-008`. Its objective is to confirm spec info reports the loaded spec and a missing spec without any network call.

### Why This Matters

Operators often check the spec on a machine without network access. The report must work offline and must not trigger a download.

This scenario runs offline. It makes no request to Jortt.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-008` and confirm the expected signals without contradictory evidence.

- Objective: Confirm spec info reports the loaded spec and a missing spec without any network call.
- Real user request: `Tell me which Jortt API spec jortt-cli is using, without going online.`
- Prompt: `Tell me which Jortt API spec jortt-cli is using, without going online.`
- Expected execution process: The agent reads the spec report, then points the CLI at a missing file to show the offline fallback report.
- Expected signals: Step 1: `OpenAPI file`, `Path count`, `Operation count` and `Cache age` lines. Step 2: `OpenAPI file: missing` and `unavailable` for the other three lines. Neither step downloads anything.
- Desired user-visible outcome: The operator sees which spec is in use and how a missing spec is reported.
- Pass/fail: PASS if both steps exit 0 and step 2 reports the missing file without a download, FAIL if either step makes a network request or exits non-zero.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Tell me which Jortt API spec jortt-cli is using, without going online.`

### Commands

1. `bash: jortt-cli spec info`
2. `bash: JORTT_OPENAPI_FILE=/nonexistent/openapi.json jortt-cli spec info`

### Expected

- Step 1: `OpenAPI file`, `Path count`, `Operation count` and `Cache age` lines.
- Step 2: `OpenAPI file: missing` and `unavailable` for the other three lines. Neither step downloads anything.

### Evidence

Both outputs with the absolute cache path redacted.

### Pass / Fail

- **Pass**: Both steps exit 0 and step 2 reports the missing file without a download.
- **Fail**: Either step makes a network request or exits non-zero.

### Failure Triage

1. Check `XDG_CACHE_HOME` and `JORTT_OPENAPI_FILE` in the environment.
2. Inspect `jortt_spec_info` in `lib/common.sh`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/operation-discovery/openapi-spec-cache.md`](../../feature-catalog/operation-discovery/openapi-spec-cache.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Spec cache and info |
| [`references/cli.md`](../../references/cli.md) | Spec source rules |

---

## 5. SOURCE METADATA

- Group: Operation discovery
- Playbook ID: JRT-008
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `operation-discovery/spec-info-offline.md`
- Feature catalog entry: [`operation-discovery/openapi-spec-cache.md`](../../feature-catalog/operation-discovery/openapi-spec-cache.md)
