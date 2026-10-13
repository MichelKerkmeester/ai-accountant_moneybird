---
title: "Exports and limits"
description: "States which records only the Jortt UI can export and owns the API rate, page and retention limits the extraction path respects."
trigger_phrases:
  - "Exports and limits"
  - "Jortt UI-only exports"
  - "Jortt API limits"
  - "Jortt no general ledger export"
version: 1.0.0.0
---

# Exports and limits (references/exports-and-limits.md)

## 1. OVERVIEW

States which records only the Jortt UI can export and owns the API rate, page and retention limits the extraction path respects.

The guide separates an API read from a document only the operator can download, so a VAT summary is never presented as a filed return.

---

## 2. HOW IT WORKS

### Core Behavior

The guide names the UI-only exports, which are XAF auditfiles, annual accounts and filed VAT returns, and states that no general ledger export exists in the API or the UI. It owns the API rate, page, retention and history statements that other pages link to. It also records the Dropbox export coverage and the unconfirmed items that stay `UNVERIFIED`.

### Routing

Surface routing sends a UI-only request to the operator and points here for the download path. The paging and retry entries cite this guide as the limit owner instead of repeating its figures.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/exports-and-limits.md`](../../references/exports-and-limits.md) | Shared | UI-only export routes, retention and API limit ownership. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/routing/xaf-request-goes-to-ui.md`](../../manual-testing-playbook/routing/xaf-request-goes-to-ui.md) | Manual playbook | JRT-005 routes an XAF request to the operator. |
| [`manual-testing-playbook/routing/moneybird-request-deferred.md`](../../manual-testing-playbook/routing/moneybird-request-deferred.md) | Manual playbook | JRT-006 hands a Moneybird request to the sibling skill. |

---

## 4. SOURCE METADATA

- Group: Reference guides
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reference-guides/exports-and-limits.md`

Related references:
- [cli-command-reference.md](cli-command-reference.md) - CLI command reference
- [rest-api-catalogue.md](rest-api-catalogue.md) - REST API catalogue
- [troubleshooting-guide.md](troubleshooting-guide.md) - Troubleshooting guide
