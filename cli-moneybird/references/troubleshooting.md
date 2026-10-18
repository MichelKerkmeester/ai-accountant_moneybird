---
title: "Moneybird Troubleshooting Guide"
description: "Quick diagnosis and recovery for Moneybird CLI, REST API and guard failures."
trigger_phrases:
  - "moneybird cli not found"
  - "moneybird 401 error"
  - "moneybird 403 scope"
  - "moneybird stale get"
  - "moneybird guard exit code"
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Moneybird Troubleshooting Guide

Start with the local checks before changing credentials or retrying an API operation. Do not print a token to diagnose a failure.

---

## 1. OVERVIEW

### Quick Diagnostics in Order

```bash
bash cli/moneybird-cli/setup.sh --check
moneybird-cli --version
moneybird-guard administration current
bash scripts/doctor.sh
```

Expected: the setup check reports whether the official CLI matches its pin, the CLI prints a version, the administration command prints the selected local session and the doctor prints offline checks without reading credentials.

If the route fails after local checks, inspect `moneybird-cli RESOURCE ACTION --help`, then use the matching issue below. For any write, stop after an unexpected response and follow the migration plan's correction path.

---

## 2. CLI AND GUARD FAILURES

The canonical exit-code table lives in [`cli.md`](cli.md) section 3. The rows below cover the guard's own exits 2 to 9.

| What you see | Why | Fix |
|---|---|---|
| `moneybird-cli` is not found | The CLI is missing or its symlink directory is not on `PATH` | Review `setup.sh` output. An operator can run `setup.sh --install` and add `$HOME/.local/bin` to `PATH`. |
| Pin check fails | The local source is not at the reviewed commit | Review the diff before pin changes. Reinstall the reviewed commit with the setup script. |
| Guard exit 2 | A usage error, including a malformed dry-run header, `--print-body` in an agent session or `--print-body` with `--out` | Use `--out` and read the saved file. Agents never use `--print-body`. |
| Guard exit 3 | A non-GET call lacks `--confirm-write` | Review the dry-run line and approved batch. Retry only after explicit operator approval. |
| Guard exit 4 | The target differs from the pilot or the pilot is unset | Set the intended pilot ID in the `MONEYBIRD_PILOT_ADMINISTRATION_ID=` line of the root `.env` file. Use `--production` only after the operator approves that batch. |
| Guard exit 5 | `--out` is outside `migration-workspace/`, crosses a symlink, names a folder or points into the guard's `.secrets/`, `RunJournal/` or `logs/` folder | Choose a file path below `<Accountant root>/migration-workspace/` outside those three folders. |
| Guard exit 6 | `MONEYBIRD_GUARD_READ_ONLY=1` blocks a non-GET method | Keep the lock set for read-only work. Use a write role only when the migration gate requires a write. |
| Guard exit 7 | The writer configuration folder `$HOME/.config/moneybird-cli-writer` does not exist | Run `moneybird-guard login-from-env --writer` after the pilot gate. The guard never falls back to the reader session. |
| Guard exit 8 | The write lacks `--approval <ref>`, the reference is not in the run journal, or the reference and payload digest pair already has a write-log row | Check the `WRITE_INTENT` entry in `migration-workspace/RunJournal/run-journal.jsonl` and repeat with `--approval "$APPROVAL_REF"`. A consumed pair needs a new `WRITE_INTENT` entry. |
| Guard exit 9 | The writer-session payload or the attachment bytes do not match the approved digest, or the approved entry carries no digest (`PAYLOAD_MISMATCH`) | Re-run the preview, copy its `payload-digest` line, and its `attachment-digest` line for a `--file` write, into a new `WRITE_INTENT` entry, then retry with the new reference. A rotated key file has the same recovery. |
| CLI dry-run does not begin with `METHOD URL` | Route help or the local spec does not resolve the operation | Stop. Check the resource and action with pinned CLI help. Do not hand-build an unguarded request. |

---

## 3. REST API RESPONSES

### `401 Unauthorized`

The selected CLI session may be missing, expired or revoked. Confirm that the intended reader or writer session is selected. The operator can use `moneybird-guard login-from-env` or `moneybird-guard login-from-env --writer`. Never pass the token as a command argument or print it.

### `403 Forbidden`

The token may lack the scope or account access for that endpoint. Check the operation's documented scope and effective token permissions with the operator. The `contacts` scope is disputed by the supplied API and OpenAPI sources, so treat it as `UNVERIFIED` until confirmed.

### `404 Not Found`

The CLI may be targeting the wrong administration or using an invalid resource action. Inspect the dry-run URL and verify the administration selection. Do not paste the real administration ID into tracked documentation or reports.

### `422 Validation Error` or Locked Period

The API rejected a field, value or write in a locked period. Check the pinned CLI help and approved mapping. For a locked period, stop and follow the migration plan exception path. Period locks are changed in the UI. Behavior for non-asset write routes in a locked period is `UNVERIFIED` until confirmed.

### `429 Too Many Requests`

Wait for the response's `Retry-After` value. Keep under 150 requests per five minutes and under 50 requests per five minutes for reports. Do not retry immediately or increase concurrency.

The Read Step Contract in `cli-moneybird/SKILL.md` section 3 owns the retry rule. It allows a GET retry only. Wait for `Retry-After` first. Never retry a non-GET call.

---

## 4. READ-BACK AND LIST ISSUES

### A GET Appears Stale After a Write

Moneybird caches API responses. The CLI's successful write status is the immediate proof. Do not repeat the write because an immediate GET appears unchanged. Read the record through synchronization in a later pass.

### A List Misses Older Years

List endpoints default to `period:this_year`. The filter you pass replaces that default. Re-run with an explicit period such as `--filter period:$YEAR`. Use synchronization for a full bulk read. `GET /financial_mutations` is capped at 100 records.

### A DELETE Returned `204`

HTTP 204 can be returned when nothing was deleted. Read the resource separately or use synchronization to confirm the intended record is absent. Do not treat the status alone as proof of deletion.

---

## 5. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`cli.md`](cli.md) | Guard syntax and exit codes |
| [`rest-api.md`](rest-api.md) | Rate limits, periods, caching and synchronization |
| [`migration-recipes.md`](migration-recipes.md) | Approved write and correction sequences |
