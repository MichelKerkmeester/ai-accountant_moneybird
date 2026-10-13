---
title: "Paged list merge"
description: "Follows _links.next.href across pages and merges each page's data array into one JSON array."
trigger_phrases:
  - "Paged list merge"
  - "jortt-cli --all"
  - "merge Jortt pages"
  - "follow next links"
version: 1.0.0.0
---

# Paged list merge (--all)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Follows _links.next.href across pages and merges each page's data array into one JSON array.

A source register needs every page, so the merge turns a paged list into one complete file. The page size and the API rate limit are owned by [`references/rest-api.md`](../../references/rest-api.md).

---

## 2. HOW IT WORKS

### Core Behavior

With `--all`, the CLI requests the first page, appends its `data` array and follows `_links.next.href` until no next link remains. The result is one JSON array. A list with no records returns `[]`, which is a valid result. With `--out`, stdout reports `items:` and the merged count.

### Link Handling

An absolute next link must use HTTPS on `api.jortt.nl`. A plain HTTP link or another host exits 1. A path or query-only link is resolved against the current request. `call --all` on a non-GET operation exits 2 before any request.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_page_all` follows next links and merges data arrays. |
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_request` fetches each page with retry and pacing. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/extraction/paged-extract-to-workspace.md`](../../manual-testing-playbook/extraction/paged-extract-to-workspace.md) | Manual playbook | JRT-003 checks a merged array inside the workspace. |
| [`references/rest-api.md`](../../references/rest-api.md) | Reference | Documents page size and next-link paging. |

---

## 4. SOURCE METADATA

- Group: Transport
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `transport/paged-list-merge.md`

Related references:
- [token-cache-and-retry.md](token-cache-and-retry.md) - Token cache and request retry
