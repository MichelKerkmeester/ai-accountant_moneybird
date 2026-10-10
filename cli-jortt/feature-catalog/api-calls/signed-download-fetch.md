---
title: "Signed download fetch"
description: "Saves a short-lived signed download link into the migration workspace without sending the Jortt bearer token."
trigger_phrases:
  - "Signed download fetch"
  - "jortt-cli fetch"
  - "download a Jortt receipt file"
  - "signed Jortt download link"
version: 1.0.0.0
---

# Signed download fetch (jortt-cli fetch)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Saves a short-lived signed download link into the migration workspace without sending the Jortt bearer token.

Receipt, invoice and attachment downloads return a signed link from a `call`. `fetch` is the second step that turns that link into a file.

---

## 2. HOW IT WORKS

`jortt-cli fetch SIGNED_HTTPS_URL --out receipt.pdf` requires `--out`. The output path is checked against the migration workspace before anything else, so an outside path exits 5 even for a bad link. A link that is not HTTPS exits 2.

The download follows redirects and sends no `Authorization` header, so the Jortt token never reaches the storage host. A 2xx response prints `HTTP 200, file saved` and moves the temporary file into place. Any other status removes the temporary file, prints a message that the link may have expired and exits 1. Request a fresh link and fetch it promptly.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_fetch` requires `--out` and resolves the destination. |
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_download` enforces HTTPS and downloads without a bearer header. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/jortt-cli/tests/run-tests.sh`](../../cli/jortt-cli/tests/run-tests.sh) | Automated test | Checks that a fetch to a path outside the workspace exits 5. |
| [`manual-testing-playbook/extraction/receipt-download.md`](../../manual-testing-playbook/extraction/receipt-download.md) | Manual playbook | JRT-004 downloads one receipt into the workspace. |

---

## 4. SOURCE METADATA

- Group: API calls
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `api-calls/signed-download-fetch.md`

Related references:
- [call-operation.md](call-operation.md) - Call an operation
- [raw-get.md](raw-get.md) - Raw GET
- [organization-check.md](organization-check.md) - Organization check
