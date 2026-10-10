---
title: "Token cache and request retry"
description: "Caches the client-credentials token privately, refreshes it near expiry and retries once after a 401 and up to three times after a 429."
trigger_phrases:
  - "Token cache and request retry"
  - "jortt-cli token status"
  - "Jortt 401 retry"
  - "Jortt 429 backoff"
version: 1.0.0.0
---

# Token cache and request retry (jortt-cli token)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Caches the client-credentials token privately, refreshes it near expiry and retries once after a 401 and up to three times after a 429.

The cache keeps repeated extraction calls fast and inside the rate limit. The retries absorb an expired token or a short burst limit without manual reruns.

---

## 2. HOW IT WORKS

### Token Cache

The CLI requests a token with the client credentials grant at `https://app.jortt.nl/oauth-provider/oauth/token`. The client ID and secret travel through a private curl config stream, never through command arguments. The token is cached in `${TMPDIR:-/tmp}/jortt-cli-<uid>/` with an owner-only folder and file, under a key hashed from the client ID and the configured scopes. A cached token is reused until it is within sixty seconds of expiry. A failed token request exits 6.

### Token Commands

`jortt-cli token status` prints `Cached token:` with `yes` or `no` and `Remaining minutes:`. `jortt-cli token clear` deletes the entry for the current client and scopes and prints `Cached token: cleared`.

### Retry And Pacing

A 401 clears the cached token, requests a new one and retries the request once. A 429 waits for the `Retry-After` value in seconds or as an HTTP date, or backs off for one, two and four seconds when the header is absent, for at most three retries. The CLI also pauses briefly between requests so a run stays under ten requests per second.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_fetch_token`, `jortt_token_cache_ready`, `jortt_request` and `jortt_retry_delay` own the cache and the retries. |
| [`cli/jortt-cli/lib/common.sh`](../../cli/jortt-cli/lib/common.sh) | Shared | `jortt_token_paths` and `jortt_curl_quote` build the private cache path and the curl config. |
| [`cli/jortt-cli/jortt-cli`](../../cli/jortt-cli/jortt-cli) | Handler | Dispatches `token status` and `token clear`. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/auth-and-scopes/token-status.md`](../../manual-testing-playbook/auth-and-scopes/token-status.md) | Manual playbook | JRT-010 reads token status and clears the cache offline. |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Reference | Maps 401 and 429 behavior to operator actions. |

---

## 4. SOURCE METADATA

- Group: Transport
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `transport/token-cache-and-retry.md`

Related references:
- [paged-list-merge.md](paged-list-merge.md) - Paged list merge
