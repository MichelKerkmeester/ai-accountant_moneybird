---
title: "REST API catalogue"
description: "Records the scope map, endpoint catalogue, filters, paging rules and extraction recipes for the local Jortt OpenAPI document."
trigger_phrases:
  - "REST API catalogue"
  - "Jortt scope map"
  - "Jortt endpoint catalogue"
  - "Jortt extraction recipes"
version: 1.0.0.0
---

# REST API catalogue (references/rest-api.md)

## 1. OVERVIEW

Records the scope map, endpoint catalogue, filters, paging rules and extraction recipes for the local Jortt OpenAPI document.

Operation selection starts here. The CLI derives its slugs from the same OpenAPI document, so this guide and `jortt-cli ops` describe the same surface from two angles.

---

## 2. HOW IT WORKS

### Core Behavior

The catalogue groups operations by API tag, names the scope and filters of each one and marks which lists page. It also owns the extraction recipes for expenses, invoices, inbox receipts, bank transactions, reports and payroll, and the record-state notes for archived customers, closed years and signed downloads.

### Source Of Truth

The local Swagger document remains the authority. A behavior the document does not describe stays `UNVERIFIED`, and the guide points at exports-and-limits for records the API cannot return. The catalog and the CLI command reference point here for filters and recipes rather than repeating them.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/rest-api.md`](../../references/rest-api.md) | Shared | Scope map, endpoint catalogue, filters, paging and recipes. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/operation-discovery/list-and-describe-operations.md`](../../manual-testing-playbook/operation-discovery/list-and-describe-operations.md) | Manual playbook | JRT-007 lists operations and confirms one description. |
| [`manual-testing-playbook/extraction/paged-extract-to-workspace.md`](../../manual-testing-playbook/extraction/paged-extract-to-workspace.md) | Manual playbook | JRT-003 extracts a paged list with a recipe. |

---

## 4. SOURCE METADATA

- Group: Reference guides
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reference-guides/rest-api-catalogue.md`

Related references:
- [cli-command-reference.md](cli-command-reference.md) - CLI command reference
- [exports-and-limits.md](exports-and-limits.md) - Exports and limits
- [troubleshooting-guide.md](troubleshooting-guide.md) - Troubleshooting guide
