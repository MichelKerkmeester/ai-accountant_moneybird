---
title: "Moneybird REST API v2 Reference"
description: "Authentication, scopes, periods, paging, caching, synchronization, request limits and deletion behavior for Moneybird REST API v2."
trigger_phrases:
  - "moneybird api authentication"
  - "moneybird api rate limit"
  - "moneybird period filter"
  - "moneybird synchronization endpoint"
  - "moneybird api delete behavior"
importance_tier: important
contextType: research
version: 1.0.0.0
---

# Moneybird REST API v2 Reference

Use this reference before selecting a REST route or verifying a migration batch. The API has period defaults, caching and request caps that can make an incomplete read look complete.

---

## 1. OVERVIEW

### Base URL and Authentication

REST API v2 uses `https://moneybird.com/api/v2/{administration_id}/{resource}.json`. A personal API token is sent as a Bearer token in the `Authorization` header. Treat administration IDs as strings because they can exceed the range supported by some numeric parsers.

The official CLI reads the token from its selected session. Never paste a token into a command, prompt, report or tracked file. Use `moneybird-guard login-from-env` for the reader token and `moneybird-guard login-from-env --writer` for the writer token.

### Scopes

The API authentication page lists six area scopes: `sales_invoices`, `documents`, `estimates`, `bank`, `time_entries` and `settings`. None separates read access from write access. The downloads page and OpenAPI sources also mention `contacts`. These sources disagree about a `contacts` scope. Treat the scope requirement as `UNVERIFIED` until the operator confirms the token's effective access.

Tokens with these scopes can change Moneybird records. Keep the writer token in `.env.writer` after the pilot begins and use the separate writer CLI config directory. Set `MONEYBIRD_GUARD_READ_ONLY=1` for read-only sessions so the guard blocks every non-GET method.

---

## 2. RATE LIMITS AND PAGING

- The general limit is 150 API requests per five minutes per IP.
- Requests under `/reports/` are limited to 50 per five minutes.
- A `429` response includes `Retry-After` and rate limit headers. Wait for the stated retry time before continuing.
- List paging uses `page` and `per_page`. The default page size is 50 and the maximum is 100. Follow the `Link` header when using raw API tooling.
- Keep report requests to no more than twelve months each.

Do not increase concurrency to catch up after a throttle. Resume at a pace that stays inside both the general and report limits.

### Completeness Proof

A paged list read proves it is complete before any count is reported:

1. Request a page size and page through the list until a short page returns. A page smaller than the requested size is the last page.
2. Dedupe by record id. A record seen again on a refetch counts once.
3. Record the count for the read together with the period it covers.

### Twelve-Month Report Split

A report covering more than twelve months is split into parts of at most twelve months each:

- Each part records its own period and count.
- The parts reconcile to the whole. The part counts add up to the whole figure, and a difference means the read is incomplete.
- Reports are limited to 50 per five minutes. Space the parts so the split stays inside that limit.

These rules implement the Read Step Contract in `cli-moneybird/SKILL.md` section 3.

---

## 3. VERIFICATION TRAPS

### Default Period

Moneybird list endpoints default to `period:this_year`. An explicit filter replaces that default. A list can succeed and still omit old years if no period is set.

For a verification list, pass an explicit year filter:

```bash
moneybird-guard sales_invoices list --filter period:YYYY
moneybird-guard financial_mutations list --filter period:YYYY
```

Use date parameters for reports when their route accepts a start and end date. Keep each report request within twelve months.

### Unmatched Bank Mutations

The bank read names the state and an explicit period:

```bash
moneybird-guard financial_mutations list --filter "period:YYYY,state:unprocessed"
```

The comma filter form is `UNVERIFIED` until pinned CLI help confirms it. The state values are:

| Bookkeeping outcome | State value |
|---|---|
| Unmatched | `unprocessed` |
| Processed | `processed` |
| Booked from a suggestion | `auto_booked` |

A filtered bank list caps at 100 records. When the list returns 100 records, treat the count as capped and fall back to `financial_mutations sync` plus `financial_mutations sync_fetch --ids JSON`, then filter the state locally on the returned records. Keep each synchronization ID batch within the cap of 100.

This read and its fallback follow the Read Step Contract in `cli-moneybird/SKILL.md` section 3.

### Caching

Moneybird caches API responses. An immediate GET after a write can return stale data. Use the write response status and body as the first proof. Read the record again through synchronization in a later pass.

### Synchronization

`GET /{resource}/synchronization` returns record IDs and versions. `POST /{resource}/synchronization` accepts IDs and returns records in batches of at most 100. Synchronization is documented for sales invoices, financial mutations and document types.

The CLI exposes these routes as `RESOURCE sync` and `RESOURCE sync_fetch --ids JSON`. Keep each ID batch within the API cap. Do not use `GET /financial_mutations` as a complete export because that endpoint is capped at 100 records.

### Delete Response

Some DELETE endpoints return HTTP 204 even when no record was removed. The guarded CLI records the successful HTTP status, but a separate read is still required to confirm the intended record is absent.

---

## 4. LOCKED PERIODS AND OTHER LIMITS

Records in a locked period cannot be edited or deleted. Period locking is a UI action. The administration API exposes `period_locked_until` as a read-only value. The asset API rejects dates inside a locked period. Behavior for other write endpoints inside a locked period is `UNVERIFIED` until the live API response or current official documentation confirms it.

Other migration limits from the supplied facts:

- Financial statement creation accepts JSON mutations. Resolve the exact body field from pinned CLI help before a write.
- Tax rates have a read endpoint and no create endpoint in the supplied facts. Create them in the UI.
- Historical VAT returns have no API route in the supplied facts. Record an outside filing with **Handmatig indienen** in chronological order.
- CAMT.053 and MT940 bank files are imported in the Moneybird UI. `financial_statements` is a JSON mutation endpoint, not a file upload route.
- The auditfile endpoint is `POST /reports/export/auditfile` with a year and version of `3.2` or `4.0`. Fetch the resulting export through the downloads endpoint.

---

## 5. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`cli.md`](cli.md) | CLI and guard commands |
| [`migration-recipes.md`](migration-recipes.md) | Migration command examples |
| [`troubleshooting.md`](troubleshooting.md) | Recovery for API responses |
