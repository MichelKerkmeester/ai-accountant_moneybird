---
title: "Moneybird Migration Recipes"
description: "Guarded command sequences for pilot writes, documents, payments, reports, auditfiles and record correction."
trigger_phrases:
  - "moneybird opening balance"
  - "moneybird external invoice attachment"
  - "moneybird purchase invoice migration"
  - "moneybird payment link"
  - "moneybird pilot correction"
  - "moneybird auditfile export"
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Moneybird Migration Recipes

Use these recipes only for approved migration batches. They use variable placeholders so no personal bookkeeping values or administration IDs are stored in the skill.

---

## 1. OVERVIEW

### Before a Write

Confirm the source register, mapping, record ID strategy and target administration. Run every write against the pilot first. Review the guard's `METHOD URL` preview, then use `--confirm-write` only after the operator approves that batch. Every write also needs `--approval "$APPROVAL_REF"`. The reference must match the `approval_reference` of a `WRITE_INTENT` event in `migration-workspace/RunJournal/run-journal.jsonl`.

The CLI parameter names for a route can vary with the OpenAPI schema. For every field not named in the supplied facts, check `moneybird-cli RESOURCE ACTION --help` and mark it `UNVERIFIED` until confirmed. Do not infer a field from a similar endpoint.

### Output Rules

Use `--out migration-workspace/...` for saved reads. Without `--out`, the guard prints one summary line instead of the response body. The guard rejects paths outside the workspace. Keep source files and API output out of this skill and other tracked files.

---

## 2. OPENING BALANCE JOURNAL ENTRY

The migration plan places an opening balance journal entry on the day before the migration start. The journal entry uses `fiscal_year_ending` when that journal type applies. Confirm the period is open before the pilot write.

The entry JSON uses the documented fields `ledger_account_id`, `debit` and `credit`. Populate the JSON from an approved migration-workspace batch file. Keep values out of the command history.

```bash
moneybird-cli documents general_journal_documents create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" documents general_journal_documents create --journal_type fiscal_year_ending --"$ENTRY_FIELD" "$ENTRIES_JSON"
```

Set `ENTRY_FIELD` to the field name confirmed by the pinned CLI help. The supplied facts do not confirm that request parameter name, so it is `UNVERIFIED` until checked.

Expected: the guard previews a POST to the pilot administration and the CLI returns its write status. A later synchronization read confirms the journal document.

---

## 3. HISTORICAL SALES INVOICE AND PDF

Use `external_sales_invoices` for an invoice issued outside Moneybird. Do not recreate it as a new Moneybird sales invoice when preserving historical invoice details. The external invoice attachment endpoint is `attachment`.

```bash
moneybird-cli external_sales_invoices create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" external_sales_invoices create --...
moneybird-cli external_sales_invoices attachment --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" external_sales_invoices attachment "$INVOICE_ID" --file "$PDF"
```

Expected: the first write creates the external invoice. The second uploads its PDF with multipart form data. Confirm both write statuses and later read the record and attachment metadata.

---

## 4. PURCHASE INVOICE AND RECEIPT WITH FILES

Create the document record first. Upload its source file through the document's `attachments` custom action.

```bash
moneybird-cli documents purchase_invoices create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" documents purchase_invoices create --...
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" documents purchase_invoices attachments "$DOCUMENT_ID" --file "$PDF"

moneybird-cli documents receipts create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" documents receipts create --...
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" documents receipts attachments "$RECEIPT_ID" --file "$PDF"
```

Expected: each document write returns its own status. Confirm the file upload status separately. Keep original files and response output under the migration workspace.

---

## 5. FINANCIAL STATEMENT AS JSON MUTATIONS

The API creates financial statements from JSON mutations. The supplied facts do not name the exact request body field. Read the pinned CLI help and OpenAPI-derived parameter list first. Store the approved JSON in `MUTATIONS_JSON` and the confirmed top-level field name in `MUTATION_FIELD`.

```bash
moneybird-cli financial_statements create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" financial_statements create --"$MUTATION_FIELD" "$MUTATIONS_JSON"
```

Expected: the guard previews the JSON request. Do not use this route to upload CAMT.053 or MT940 files. Those files are imported in the UI.

---

## 6. LINK A PAYMENT

The confirmed REST route is `PATCH /financial_mutations/{id}/link_booking`. The request body fields are not fully named in the supplied facts. Check the pinned CLI help before setting `BOOKING_FIELD` and `BOOKING_JSON`.

```bash
moneybird-cli financial_mutations link_booking --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" financial_mutations link_booking "$MUTATION_ID" --"$BOOKING_FIELD" "$BOOKING_JSON"
```

Document payment endpoints use `POST /documents/{type}/{id}/payments`. Confirm the type-specific route and fields before using it:

```bash
moneybird-cli documents purchase_invoices payments --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" documents purchase_invoices payments "$DOCUMENT_ID" --"$PAYMENT_FIELD" "$PAYMENT_JSON"
```

Do not use the deprecated sales invoice `register_payment` action. Its sunset is 2026-12-31.

---

## 7. LEDGER ACCOUNT WITH RGS CODE

The RGS code is required when creating a ledger account. Resolve other required fields from the pinned CLI help and approved mapping.

```bash
moneybird-cli ledger_accounts create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" ledger_accounts create --rgs_code "$RGS_CODE" --...
```

Expected: the guard previews a POST to the pilot. Read the account back after the write response succeeds.

---

## 8. FIXED ASSET

The API supports `assets`, value changes, retroactive linear value changes and disposals. Confirm the exact custom action and fields from the pinned CLI help before writing depreciation details.

```bash
moneybird-cli assets create --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" assets create --...
moneybird-cli assets retroactive_linear_value_changes --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" assets retroactive_linear_value_changes "$ASSET_ID" --...
```

Expected: each call is previewed. Do not write dates inside a locked period. The asset API rejects dates in a locked period.

---

## 9. AUDITFILE EXPORT

The export endpoint is `POST /reports/export/auditfile`. The body takes a year and version `3.2` or `4.0`. The export is fetched through the downloads endpoint.

```bash
moneybird-cli reports export auditfile --help
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" reports export auditfile --year "$YEAR" --version "$AUDITFILE_VERSION"
moneybird-cli downloads get --help
moneybird-guard downloads get "$DOWNLOAD_ID" --out migration-workspace/auditfile-download
```

Expected: the create status confirms the export request. Use the returned download reference for the later fetch. Confirm any additional file retrieval step from pinned CLI help. Keep the export under the migration workspace.

---

## 10. PER-YEAR VERIFICATION READS

Set the year explicitly for each verification list. Reports cover at most twelve months per request.

```bash
moneybird-guard sales_invoices list --filter "period:$YEAR" --out "migration-workspace/$YEAR-sales-invoices.json"
moneybird-guard financial_mutations sync --out "migration-workspace/$YEAR-mutation-sync.json"
REPORT_DATE_ARGS=(--"$START_DATE_FIELD" "$YEAR-01-01" --"$END_DATE_FIELD" "$YEAR-12-31")
moneybird-guard reports profit_loss "${REPORT_DATE_ARGS[@]}" --out "migration-workspace/$YEAR-profit-loss.json"
moneybird-guard reports balance_sheet "${REPORT_DATE_ARGS[@]}" --out "migration-workspace/$YEAR-balance-sheet.json"
moneybird-guard reports general_ledger "${REPORT_DATE_ARGS[@]}" --out "migration-workspace/$YEAR-general-ledger.json"
moneybird-guard reports journal_entries "${REPORT_DATE_ARGS[@]}" --out "migration-workspace/$YEAR-journal-entries.json"
moneybird-guard reports tax "${REPORT_DATE_ARGS[@]}" --out "migration-workspace/$YEAR-tax.json"
```

Confirm `START_DATE_FIELD` and `END_DATE_FIELD` from pinned CLI help before running the example. Those field names are `UNVERIFIED` until confirmed. Each report covers the requested year. Use `sync` and `sync_fetch` in ID batches of no more than 100 for full record reads.

---

## 11. CORRECT A WRONG PILOT WRITE

The migration plan rehearses an undo in the pilot before production work. Stop the batch when the write response differs from the approved record.

1. Record the wrong write as an exception in the migration workspace.
2. Find the record ID in the approved batch's WriteJournal. Do not infer it from a cached list response.
3. For a wrong record that must be removed, use a guarded DELETE against the pilot.
4. Run a separate GET or synchronization read to confirm removal. A `204` response alone is not proof.
5. Recreate the corrected record from the approved source batch and verify it through synchronization later.
6. Do not edit a locked period until the operator has opened an exception and deliberately unlocked it.

```bash
moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$MONEYBIRD_PILOT_ADMINISTRATION_ID" "$RESOURCE" delete "$RECORD_ID"
moneybird-guard "$RESOURCE" get "$RECORD_ID"
```

For an update, inspect the matching resource help and use the guarded `update` action with the approved fields. Keep every correction on the pilot until the migration gate permits production.
