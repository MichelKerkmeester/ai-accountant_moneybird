---
title: "API error redaction"
description: "Prints only the HTTP status and safe field or code labels for a failed request and appends the full response to a private workspace log."
trigger_phrases:
  - "API error redaction"
  - "jortt-cli API error"
  - "jortt-errors.log"
  - "Jortt 422 fields"
version: 1.0.0.0
---

# API error redaction (jortt-cli errors)

## 1. OVERVIEW

Prints only the HTTP status and safe field or code labels for a failed request and appends the full response to a private workspace log.

API error bodies can repeat customer data. The redaction keeps the terminal output reportable while the full body stays available in the ignored workspace for diagnosis.

---

## 2. HOW IT WORKS

### Core Behavior

A non-2xx response after the retry loop fails the command with exit 1. The error report prints the HTTP status and, when the body parses as JSON, either the field names under `errors` or a short code-like `error` or `code` value. Free text from the body is never printed.

### Full Response Log

When a body is present, the full response is appended to `migration-workspace/logs/jortt-errors.log`. The log lives inside the guarded workspace and gets owner-only permissions. The message names the log path, and a failed log write is reported in the same message without changing the exit code.

### Paging And Downloads

`--all` uses the same request path, so a page error is redacted and logged once. `fetch` reports the HTTP status of the signed link and an expiry hint instead of a body, because a signed storage response is not a JSON error document.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_api_error_report`, `jortt_error_detail` and `jortt_log_api_error` redact the message and append the body. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that message text stays hidden, field names print and the log keeps owner-only permissions. |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Reference | Maps each status to a read-only recovery check. |

---

## 4. SOURCE METADATA

- Group: Transport
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `transport/api-error-redaction.md`

Related references:
- [token-cache-and-retry.md](token-cache-and-retry.md) - Token cache and request retry
- [paged-list-merge.md](paged-list-merge.md) - Paged list merge
