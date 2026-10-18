---
title: "Jortt Troubleshooting"
description: "Ordered diagnostics for jortt-cli authentication, scopes, output paths and API limits."
trigger_phrases:
  - "jortt-cli troubleshooting"
  - "Jortt 401 invalid_scope"
  - "Jortt output path error"
importance_tier: normal
contextType: research
version: 1.0.0.0
---

# Jortt Troubleshooting

Use the checks in order. Keep credentials and extracted records out of terminal captures.

---

## 1. OVERVIEW

### When to Use

- A `jortt-cli` command exits with a non-zero code
- An API call returns 401, 403, 422 or 429
- A signed download fails or a paged list looks incomplete

### Core Principle

Diagnose with read-only checks first. Never widen scopes or consent to make an error disappear.

---

## 2. QUICK DIAGNOSTICS

1. Confirm dependencies with `bash --version`, `curl --version` and `jq --version`.
2. Run `jortt-cli --version` and confirm the expected CLI is on `PATH`.
3. Run `jortt-cli spec info`. If the spec is stale or missing, update it when network use is allowed.
4. Check `jortt-cli token status`. It prints presence and remaining minutes only.
5. Run `jortt-cli whoami` when an API check is appropriate. It shows status and field names only.
6. Run `bash scripts/doctor.sh` for local checks. It is always offline.

---

## 3. CLI ERRORS

| What you see | Meaning | Action |
|---|---|---|
| Exit 1 | The API answered with a non-2xx status after the retries, the transport failed or a paged response broke the `--all` contract. | Read the status line. The full response is in `migration-workspace/logs/jortt-errors.log`. Match the status in the rows below. |
| Exit 2 | A usage, parameter or OpenAPI file error, or `--print-body` in an agent session. | Fix the command with `jortt-cli describe SLUG`. Use `--out` instead of `--print-body`. |
| Exit 3 | The call named a non-GET operation and the CLI refuses every one. | Stop. Jortt is read-only, and no write path exists for an agent. Hand the change to the Operator for the Jortt UI. |
| Exit 4 | The operation's required scope is absent. | Name the missing scope and ask the operator to update key scopes only when the task requires it. |
| Exit 5 | An output path is outside migration-workspace or crosses a symlink. | Choose a destination inside the ignored workspace. |
| Exit 6 | The token request failed or returned no usable token. | Check the client values and key scopes with the operator. Never read `.env` yourself. |
| `HTTP 401` | Token was rejected. The CLI clears its cache and retries once. | If it repeats, run `jortt-cli token clear` and verify the client credentials with the operator. |
| `invalid_scope` | The configured scope string is not accepted for this key. | Compare the requested read scopes with the key configuration in `JORTT_SCOPES`. Do not add write scopes to fix a read error. |
| HTTP 403 | The token is authenticated but lacks permission or access to the resource. | Check the operation scope and account access. Do not retry with broader access without instruction. |
| HTTP 422 | The API rejected the request, often a filter value or a closed-year (boekjaar) limit. | Stop. Check the parameters with `jortt-cli describe SLUG` and the year state. Never retry it as a write. |
| HTTP 429 | The API rate limit was reached. | The CLI waits for `Retry-After` or backs off, for at most three retries, then exits 1. Do not rerun it automatically. Check that only one `jortt-cli` process runs and report the 429. |

---

## 4. DOWNLOAD AND PAGING

A signed download link expires after a few minutes. If `fetch` reports a non-success status, request a new link and fetch it promptly. `fetch` does not send a bearer token to the link.

An empty list is a valid response. `--all` returns an empty JSON array when every page has no data. Do not treat that as an API failure or invent records.

If a page repeats or `--all` rejects the response, preserve the status and error fields then stop. Do not manually change `page` until the next-link behavior is understood.

---

## 5. SPEC CACHE

`jortt-cli spec info` does not make a network call. If the cache is missing, the first regular operation fetches the spec automatically. `jortt-cli spec update` refreshes it directly. If the local snapshot and live operation disagree, inspect the local spec and mark undocumented behavior `UNVERIFIED`.

---

## 6. RELATED RESOURCES

- [`cli.md`](cli.md) - Exit codes and safety checks
- [`../INSTALL-GUIDE.md`](../INSTALL-GUIDE.md) - Setup and rollback
