---
title: "JRT-004 -- Receipt download"
description: "This scenario validates Receipt download for `JRT-004`. Its objective is to confirm a receipt download link is fetched promptly into the workspace without sending the API bearer token to the signed URL."
version: 1.0.0.0
---

# JRT-004 -- Receipt download

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `JRT-004`.

---

## 1. OVERVIEW

This scenario validates Receipt download for `JRT-004`. Its objective is to confirm a receipt download link is fetched promptly into the workspace without sending the API bearer token to the signed URL.

### Why This Matters

Receipts are source documents. The signed link must be used quickly and the Jortt token must never reach the storage host.

This scenario makes a live read-only request. Run it only with an operator-approved read-only key.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `JRT-004` and confirm the expected signals without contradictory evidence.

- Objective: Confirm a receipt download link is fetched promptly into the workspace without sending the API bearer token to the signed URL.
- Real user request: `Download one receipt through its Jortt link into the migration workspace.`
- Prompt: `Download one receipt through its Jortt link into the migration workspace.`
- Expected execution process: The agent confirms the operator approved a live read, requests the signed link and fetches it at once.
- Expected signals: Step 1: a response that carries an HTTPS signed link. Step 2: `HTTP 200, file saved` and a file below `migration-workspace/`.
- Desired user-visible outcome: The API call returns a signed URL and fetch saves its file under migration-workspace.
- Pass/fail: PASS if fetch uses HTTPS, sends no bearer header and writes only in the workspace, FAIL if the API token is sent to the signed host or output escapes the workspace.

---

## 3. TEST EXECUTION

### Prompt

- Prompt: `Download one receipt through its Jortt link into the migration workspace.`

### Commands

1. `bash: jortt-cli call download-url-for-a-receipt --id RECEIPT_ID --raw`
2. `bash: jortt-cli fetch SIGNED_HTTPS_URL --out receipt-test.pdf`

### Expected

- Step 1: a response that carries an HTTPS signed link.
- Step 2: `HTTP 200, file saved` and a file below `migration-workspace/`.

### Evidence

Both status lines and the saved file name. Do not copy the URL or the file contents into tracked files.

### Pass / Fail

- **Pass**: Fetch uses HTTPS, sends no bearer header and writes only in the workspace.
- **Fail**: The API token is sent to the signed host or output escapes the workspace.

### Failure Triage

1. Mark the scenario SKIP with the blocker named when live credentials are unavailable or not approved.
2. On a non-2xx fetch, request a fresh link and review link lifetime in `references/exports-and-limits.md`.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/api-calls/signed-download-fetch.md`](../../feature-catalog/api-calls/signed-download-fetch.md) | Feature-catalog source describing the implementation contract |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Signed download without bearer header |
| [`references/exports-and-limits.md`](../../references/exports-and-limits.md) | Download link lifetime |

---

## 5. SOURCE METADATA

- Group: Extraction
- Playbook ID: JRT-004
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `extraction/receipt-download.md`
- Feature catalog entry: [`api-calls/signed-download-fetch.md`](../../feature-catalog/api-calls/signed-download-fetch.md)
