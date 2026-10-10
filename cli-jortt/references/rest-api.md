---
title: "Jortt REST API Catalogue"
description: "Authentication, scopes, endpoint catalogue and extraction patterns from the local Jortt OpenAPI snapshot."
trigger_phrases:
  - "Jortt REST API catalogue"
  - "Jortt API scopes"
  - "Jortt endpoint filters"
  - "Jortt paged extraction"
importance_tier: important
contextType: research
version: 1.0.0.0
---

# Jortt REST API Catalogue

This reference records the OpenAPI 2.0 surface used by `jortt-cli` and the confirmed migration behaviors from the supplied local research.

---

## 1. OVERVIEW

### When to Use

- Choosing the operation slug for an extraction
- Checking which scope an operation needs before a call
- Copying a paged extraction recipe for a migration register

### Core Principle

The local Swagger document is the authority. A behavior it does not describe stays `UNVERIFIED` until a source confirms it.

---

## 2. AUTHENTICATION AND REQUEST RULES

The API base is `https://api.jortt.nl`. OAuth uses the client credentials grant at `https://app.jortt.nl/oauth-provider/oauth/token`. The client ID and secret use HTTP Basic auth for the token request. The returned bearer token lasts two hours. The CLI caches it privately and retries once after a 401.

The rate limit is 10 requests per second. A list page contains at most 100 items. Follow `_links.next.href` until it is absent. `jortt-cli --all` performs that loop and merges each page `data` array.

A call requires the scope named by its OpenAPI operation. The migration default in `.env.example` is read-only:

```text
organizations:read customers:read invoices:read expenses:read receipts:read financing:read reconciling:read reports:read
```

`payroll:read` is not in that default. Add it only if payroll records are in the approved extraction scope. Never add a `:write` scope for a read task.

---

## 3. SCOPE MAP

| Scope | Operations in this snapshot | What it opens |
|---|---:|---|
| `customers:read` | 9 | Read customer records and customer VAT percentage details. |
| `customers:write` | 10 | Create, update, archive or delete customer records. |
| `estimates:read` | 7 | Read estimate records and related invoice data. |
| `estimates:write` | 10 | Create invoices from estimates and perform estimate write operations. |
| `expenses:read` | 7 | Read expenses and expense ledger account categories. |
| `expenses:write` | 4 | Create, update, delete or attach receipts to expenses. |
| `financing:read` | 3 | Read bank accounts, bank transactions and payment source details. |
| `inbox:write` | 2 | Upload receipt images into the inbox. |
| `invoices:read` | 35 | Read invoices, invoice ledger accounts and project records. |
| `invoices:write` | 32 | Create, update, send or delete invoices and projects. |
| `organizations:read` | 8 | Read organization details, labels and attachment download links. |
| `organizations:write` | 5 | Create labels and request attachment upload links. |
| `payroll:read` | 2 | Read payroll journal entries. |
| `payroll:write` | 6 | Create, update or delete payroll journal entries. |
| `receipts:read` | 3 | Operation scope from the OpenAPI document. |
| `reconciling:read` | 1 | Listed as a default read scope in the local environment template. No operation in this Swagger snapshot names it directly. |
| `reconciling:write` | 2 | Operation scope from the OpenAPI document. |
| `reports:read` | 12 | Read report summaries and profit and loss or balance reports. |

The default list contains `reconciling:read`, but this snapshot assigns no operation directly to that scope. The CLI checks the scope string exactly as the operation declares it.

---

## 4. ENDPOINT CATALOGUE

The CLI derives slugs from `operationId` by lowercasing it and replacing non-alphanumeric runs with a hyphen. When slugs collide, it selects `/v3` first then `/v2`, then unversioned and `/v1`. Other entries receive a `-v3`, `-v2`, `-v1` or `-legacy` suffix. The selected endpoint uses the unsuffixed slug.

### Bank-Accounts

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `list-bank-accounts-v3` | GET | `/v3/bank-accounts` | `financing:read` | none | none | no | none |
| `list-bank-transactions-v3` | GET | `/v3/bank-accounts/{id}/bank-transactions` | `financing:read` | `id` | none | yes | none |
| `list-payment-method-sources-of-a-bank-transaction` | GET | `/v3/bank-accounts/{id}/bank-transactions/{transaction_id}/payment_methods/sources` | `financing:read` | `id` / `transaction_id` | none | yes | none |

### Customers

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `create-customer` | POST | `/customers` | `customers:write` | none | none | no | `CreateCustomer` |
| `create-customer-v1` | POST | `/v1/customers` | `customers:write` | none | none | no | `CreateCustomer` |
| `delete-a-customer` | DELETE | `/customers/{customer_id}` | `customers:write` | `customer_id` | none | no | none |
| `delete-a-customer-v1` | DELETE | `/v1/customers/{customer_id}` | `customers:write` | `customer_id` | none | no | none |
| `get-customer-by-id` | GET | `/customers/{customer_id}` | `customers:read` | `customer_id` | none | no | none |
| `get-customer-by-id-v1` | GET | `/v1/customers/{customer_id}` | `customers:read` | `customer_id` | none | no | none |
| `get-customer-s-details-by-id` | GET | `/customers/{customer_id}/extra_details` | `customers:read` | `customer_id` | none | no | none |
| `get-customer-s-details-by-id-v1` | GET | `/v1/customers/{customer_id}/extra_details` | `customers:read` | `customer_id` | none | no | none |
| `get-vat-percentages-for-a-customer-by-id` | GET | `/customers/{customer_id}/vat-percentages` | `customers:read` | `customer_id` | none | no | none |
| `get-vat-percentages-for-a-customer-by-id-v1` | GET | `/v1/customers/{customer_id}/vat-percentages` | `customers:read` | `customer_id` | none | no | none |
| `get-vat-percentages-for-a-customer-by-id-v2` | GET | `/v2/customers/{customer_id}/vat-percentages` | `customers:read` | `customer_id` | none | no | none |
| `list-customers` | GET | `/customers` | `customers:read` | none | `query` | yes | none |
| `list-customers-v1` | GET | `/v1/customers` | `customers:read` | none | `query` | yes | none |
| `send-direct-debit-authorization-to-a-customer` | POST | `/customers/{customer_id}/direct_debit_mandate` | `customers:write` | `customer_id` | none | no | none |
| `send-direct-debit-authorization-to-a-customer-v1` | POST | `/v1/customers/{customer_id}/direct_debit_mandate` | `customers:write` | `customer_id` | none | no | none |
| `set-customer-archived` | PUT | `/customers/{customer_id}/set_archived` | `customers:write` | `customer_id` | none | no | `SetCustomerArchived` |
| `set-customer-archived-v1` | PUT | `/v1/customers/{customer_id}/set_archived` | `customers:write` | `customer_id` | none | no | `SetCustomerArchived` |
| `update-customer` | PUT | `/customers/{customer_id}` | `customers:write` | `customer_id` | none | no | `UpdateCustomer` |
| `update-customer-v1` | PUT | `/v1/customers/{customer_id}` | `customers:write` | `customer_id` | none | no | `UpdateCustomer` |

### Estimates

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `accept-estimate-v2` | POST | `/v2/estimates/{id}/accept` | `estimates:write` | `id` | none | no | none |
| `copy-estimate-v2` | POST | `/v2/estimates/{id}/copy` | `estimates:write` | `id` | none | no | none |
| `create-and-optionally-send-an-estimate-v2` | POST | `/v2/estimates` | `estimates:write` | none | none | no | `CreateEstimateV2` |
| `create-and-optionally-send-an-estimate-v3` | POST | `/v3/estimates` | `estimates:write` | none | none | no | `CreateEstimateV3` |
| `create-invoice-from-estimate-v2` | POST | `/v2/estimates/{id}/invoice` | `estimates:write` | `id` | none | no | none |
| `delete-estimate-v2` | DELETE | `/v2/estimates/{id}` | `estimates:write` | `id` | none | no | none |
| `edit-estimate-v2` | PUT | `/v2/estimates/{id}` | `estimates:write` | `id` | none | no | `EditEstimateV2` |
| `get-estimate-by-id-v3` | GET | `/v3/estimates/{id}` | `estimates:read` | `id` | none | no | none |
| `get-estimate-line-item-suggestions` | GET | `/v2/estimates/{id}/line_item_suggestions` | `estimates:read` | `id` | `query` | no | none |
| `list-estimates-v3` | GET | `/v3/estimates` | `estimates:read` | none | `query` / `estimate_status` / `acceptance_status` | yes | none |
| `reject-estimate-v2` | POST | `/v2/estimates/{id}/reject` | `estimates:write` | `id` | none | no | `RejectEstimateV2` |
| `send-estimate-v2` | POST | `/v2/estimates/{id}/send` | `estimates:write` | `id` | none | no | `SendEstimateV2` |
| `send-estimate-v3` | POST | `/v3/estimates/{id}/send` | `estimates:write` | `id` | none | no | `SendEstimateV3` |

### Expenses

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `attach-receipt-to-expense` | POST | `/v3/expenses/id/{id}/receipt` | `expenses:write` | `id` | none | no | `AttachReceiptToExpense` |
| `create-an-expense` | POST | `/v3/expenses` | `expenses:write` | none | none | no | `CreateExpense` |
| `delete-an-expense` | DELETE | `/v3/expenses/id/{id}` | `expenses:write` | `id` | `force` | no | none |
| `get-expense-by-id` | GET | `/v3/expenses/id/{id}` | `expenses:read` | `id` | none | no | none |
| `list-expenses` | GET | `/v3/expenses` | `expenses:read` | none | `vat_date_from` / `vat_date_till` / `delivery_date_from` / `delivery_date_till` / `expense_type` | yes | none |
| `list-payment-method-ledger-accounts-of-an-expense` | GET | `/v3/expenses/id/{id}/payment_methods/ledger_accounts` | `expenses:read` | `id` | none | no | none |
| `list-payment-method-sources-of-an-expense` | GET | `/v3/expenses/id/{id}/payment_methods/sources` | `expenses:read` | `id` | none | yes | none |
| `update-an-expense` | POST | `/v3/expenses/id/{id}` | `expenses:write` | `id` | none | no | `UpdateExpense` |

### Files

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `download-url-for-attachments` | GET | `/v3/files/attachment_download` | `organizations:read` | none | `id` / `name` | no | none |
| `upload-attachment` | POST | `/v3/files/attachment_upload` | `organizations:write` | none | none | no | `UploadAttachment` |
| `upload-url-for-attachments` | GET | `/files/put_url` | `organizations:write` | none | `id` / `name` / `mime_type` / `content_length` | no | none |
| `upload-url-for-attachments-v1` | GET | `/v1/files/put_url` | `organizations:write` | none | `id` / `name` / `mime_type` / `content_length` | no | none |

### Inbox

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `upload-receipt` | POST | `/inbox/images` | `inbox:write` | none | none | no | `UploadReceipt` |
| `upload-receipt-v1` | POST | `/v1/inbox/images` | `inbox:write` | none | none | no | `UploadReceipt` |

### Invoices

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `copy-an-invoice` | POST | `/invoices/{id}/copy` | `invoices:write` | `id` | none | no | none |
| `copy-an-invoice-v1` | POST | `/v1/invoices/{id}/copy` | `invoices:write` | `id` | none | no | none |
| `create-and-optionally-send-an-invoice` | POST | `/invoices` | `invoices:write` | none | none | no | `CreateInvoice` |
| `create-and-optionally-send-an-invoice-v1` | POST | `/v1/invoices` | `invoices:write` | none | none | no | `CreateInvoice` |
| `create-and-optionally-send-an-invoice-v2` | POST | `/v2/invoices` | `invoices:write` | none | none | no | `CreateInvoiceV2` |
| `create-and-optionally-send-an-invoice-v3` | POST | `/v3/invoices` | `invoices:write` | none | none | no | `CreateInvoiceV3` |
| `creates-and-optionally-sends-a-credit-invoice` | POST | `/invoices/{id}/credit` | `invoices:write` | `id` | none | no | `CreateCreditInvoice` |
| `creates-and-optionally-sends-a-credit-invoice-v1` | POST | `/v1/invoices/{id}/credit` | `invoices:write` | `id` | none | no | `CreateCreditInvoice` |
| `delete-invoice-by-id` | DELETE | `/invoices/{id}` | `invoices:write` | `id` | none | no | none |
| `delete-invoice-by-id-v1` | DELETE | `/v1/invoices/{id}` | `invoices:write` | `id` | none | no | none |
| `download-invoice-pdf` | GET | `/invoices/{id}/download` | `invoices:read` | `id` | none | no | none |
| `download-invoice-pdf-v1` | GET | `/v1/invoices/{id}/download` | `invoices:read` | `id` | none | no | none |
| `edit-invoice` | PUT | `/invoices/{id}` | `invoices:write` | `id` | none | no | `EditInvoice` |
| `edit-invoice-v1` | PUT | `/v1/invoices/{id}` | `invoices:write` | `id` | none | no | `EditInvoice` |
| `edit-invoice-v2` | PUT | `/v2/invoices/{id}` | `invoices:write` | `id` | none | no | `EditInvoiceV2` |
| `get-invoice-by-id` | GET | `/invoices/{id}` | `invoices:read` | `id` | none | no | none |
| `get-invoice-by-id-v1` | GET | `/v1/invoices/{id}` | `invoices:read` | `id` | none | no | none |
| `get-invoice-by-id-v3` | GET | `/v3/invoices/{id}` | `invoices:read` | `id` | none | no | none |
| `get-line-item-suggestions` | GET | `/v2/invoices/{id}/line_item_suggestions` | `invoices:read` | `id` | `query` | no | none |
| `get-line-item-suggestions-legacy` | GET | `/invoices/{id}/line_item_suggestions` | `invoices:read` | `id` | `query` | no | none |
| `get-line-item-suggestions-v1` | GET | `/v1/invoices/{id}/line_item_suggestions` | `invoices:read` | `id` | `query` | no | none |
| `get-next-possible-invoice-number` | GET | `/invoices/{id}/next_possible_invoice_number` | `invoices:read` | `id` | none | no | none |
| `get-next-possible-invoice-number-v1` | GET | `/v1/invoices/{id}/next_possible_invoice_number` | `invoices:read` | `id` | none | no | none |
| `get-peppol-scheme-catalog` | GET | `/v3/invoices/peppol-scheme-catalog` | `invoices:read` | none | none | no | none |
| `get-peppol-scheme-catalog-v2` | GET | `/v2/invoices/peppol-scheme-catalog` | `invoices:read` | none | none | no | none |
| `get-send-settings` | GET | `/invoices/{id}/send_settings` | `invoices:read` | `id` | none | no | none |
| `get-send-settings-v1` | GET | `/v1/invoices/{id}/send_settings` | `invoices:read` | `id` | none | no | none |
| `list-invoices` | GET | `/invoices` | `invoices:read` | none | `query` / `invoice_status` | yes | none |
| `list-invoices-v1` | GET | `/v1/invoices` | `invoices:read` | none | `query` / `invoice_status` | yes | none |
| `list-invoices-v3` | GET | `/v3/invoices` | `invoices:read` | none | `query` / `invoice_status` | yes | none |
| `list-payment-method-ledger-accounts-of-an-invoice` | GET | `/v3/invoices/{id}/payment_methods/ledger_accounts` | `invoices:read` | `id` | none | no | none |
| `list-payment-method-sources-of-an-invoice` | GET | `/v3/invoices/{id}/payment_methods/sources` | `invoices:read` | `id` | none | yes | none |
| `send-invoice` | POST | `/invoices/{id}/send` | `invoices:write` | `id` | none | no | `SendInvoice` |
| `send-invoice-v1` | POST | `/v1/invoices/{id}/send` | `invoices:write` | `id` | none | no | `SendInvoice` |
| `send-invoice-v3` | POST | `/v3/invoices/{id}/send` | `invoices:write` | `id` | none | no | `SendInvoiceV3` |
| `set-invoice-labels` | PUT | `/invoices/{id}/set_labels` | `invoices:write` | `id` | none | no | `SetLabels` |
| `set-invoice-labels-v1` | PUT | `/v1/invoices/{id}/set_labels` | `invoices:write` | `id` | none | no | `SetLabels` |

### Labels

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `create-a-label` | POST | `/labels` | `organizations:write` | none | none | no | `CreateLabel` |
| `create-a-label-v1` | POST | `/v1/labels` | `organizations:write` | none | none | no | `CreateLabel` |
| `list-labels` | GET | `/labels` | `organizations:read` | none | none | no | none |
| `list-labels-v1` | GET | `/v1/labels` | `organizations:read` | none | none | no | none |

### Ledger Accounts

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `list-balance-ledger-accounts` | GET | `/v3/ledger_accounts/expenses/balance` | `expenses:read` | none | none | no | none |
| `list-cost-ledger-accounts` | GET | `/v3/ledger_accounts/expenses/cost` | `expenses:read` | none | none | no | none |
| `list-income-ledger-accounts` | GET | `/v3/ledger_accounts/expenses/income` | `expenses:read` | none | none | no | none |
| `list-invoice-ledger-accounts` | GET | `/ledger_accounts/invoices` | `invoices:read` | none | none | no | none |
| `list-invoice-ledger-accounts-v1` | GET | `/v1/ledger_accounts/invoices` | `invoices:read` | none | none | no | none |
| `the-default-ledger-account-for-invoice-line-items` | GET | `/ledger_accounts/invoices/default` | `invoices:read` | none | none | no | none |
| `the-default-ledger-account-for-invoice-line-items-v1` | GET | `/v1/ledger_accounts/invoices/default` | `invoices:read` | none | none | no | none |

### Loonjournaalposten

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `create-a-loonjournaalpost` | POST | `/loonjournaalposten` | `payroll:write` | none | none | no | `CreateLoonjournaalpost` |
| `create-a-loonjournaalpost-v1` | POST | `/v1/loonjournaalposten` | `payroll:write` | none | none | no | `CreateLoonjournaalpost` |
| `delete-a-loonjournaalpost` | DELETE | `/loonjournaalposten/{loonjournaalpost_id}` | `payroll:write` | `loonjournaalpost_id` | none | no | none |
| `delete-a-loonjournaalpost-v1` | DELETE | `/v1/loonjournaalposten/{loonjournaalpost_id}` | `payroll:write` | `loonjournaalpost_id` | none | no | none |
| `list-loonjournaalposten` | GET | `/loonjournaalposten` | `payroll:read` | none | `year` | no | none |
| `list-loonjournaalposten-v1` | GET | `/v1/loonjournaalposten` | `payroll:read` | none | `year` | no | none |
| `update-a-loonjournaalpost` | PUT | `/loonjournaalposten/{loonjournaalpost_id}` | `payroll:write` | `loonjournaalpost_id` | none | no | `UpdateLoonjournaalpost` |
| `update-a-loonjournaalpost-v1` | PUT | `/v1/loonjournaalposten/{loonjournaalpost_id}` | `payroll:write` | `loonjournaalpost_id` | none | no | `UpdateLoonjournaalpost` |

### Organizations

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `get-the-organization-associated-with-the-api-credentials` | GET | `/organizations/me` | `organizations:read` | none | none | no | none |
| `get-the-organization-associated-with-the-api-credentials-v1` | GET | `/v1/organizations/me` | `organizations:read` | none | none | no | none |
| `list-organizations-v3` | GET | `/v3/organizations` | `organizations:read` | none | none | no | none |

### Payments

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `deregister-payment-v3` | POST | `/v3/payments/deregister` | `reconciling:write` | none | none | no | `DeregisterPayment` |
| `list-payments-v3` | GET | `/v3/payments/{sink_id}` | `reconciling:read` | `sink_id` | none | no | none |
| `register-payment-v3` | POST | `/v3/payments/register` | `reconciling:write` | none | none | no | `RegisterPayment` |

### Projects

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `create-project` | POST | `/projects` | `invoices:write` | none | none | no | `CreateProject` |
| `create-project-line-item` | POST | `/projects/{id}/line_items` | `invoices:write` | `id` | none | no | `ProjectsIdLineItems` |
| `create-project-line-item-v1` | POST | `/v1/projects/{id}/line_items` | `invoices:write` | `id` | none | no | `V1ProjectsIdLineItems` |
| `create-project-v1` | POST | `/v1/projects` | `invoices:write` | none | none | no | `CreateProject` |
| `delete-project` | DELETE | `/projects/{id}` | `invoices:write` | `id` | none | no | none |
| `delete-project-line-item` | DELETE | `/projects/{id}/line_items/{line_item_id}` | `invoices:write` | `id` / `line_item_id` | none | no | none |
| `delete-project-line-item-v1` | DELETE | `/v1/projects/{id}/line_items/{line_item_id}` | `invoices:write` | `id` / `line_item_id` | none | no | none |
| `delete-project-v1` | DELETE | `/v1/projects/{id}` | `invoices:write` | `id` | none | no | none |
| `get-project` | GET | `/projects/{id}` | `invoices:read` | `id` | none | no | none |
| `get-project-line-item` | GET | `/projects/{id}/line_items/{line_item_id}` | `invoices:read` | `id` / `line_item_id` | none | no | none |
| `get-project-line-item-summary` | GET | `/projects/{id}/line_items/summary` | `invoices:read` | `id` | `period` / `start_date` / `end_date` | no | none |
| `get-project-line-item-summary-v1` | GET | `/v1/projects/{id}/line_items/summary` | `invoices:read` | `id` | `period` / `start_date` / `end_date` | no | none |
| `get-project-line-item-v1` | GET | `/v1/projects/{id}/line_items/{line_item_id}` | `invoices:read` | `id` / `line_item_id` | none | no | none |
| `get-project-v1` | GET | `/v1/projects/{id}` | `invoices:read` | `id` | none | no | none |
| `invoice-project` | POST | `/projects/{id}/invoice` | `invoices:write` | `id` | none | no | `InvoiceProject` |
| `invoice-project-v1` | POST | `/v1/projects/{id}/invoice` | `invoices:write` | `id` | none | no | `InvoiceProject` |
| `list-project-line-items` | GET | `/projects/{id}/line_items` | `invoices:read` | `id` | `start_date` / `end_date` / `status_filter` | yes | none |
| `list-project-line-items-v1` | GET | `/v1/projects/{id}/line_items` | `invoices:read` | `id` | `start_date` / `end_date` / `status_filter` | yes | none |
| `list-projects` | GET | `/projects` | `invoices:read` | none | none | yes | none |
| `list-projects-v1` | GET | `/v1/projects` | `invoices:read` | none | none | yes | none |
| `update-project` | PUT | `/projects/{id}` | `invoices:write` | `id` | none | no | `UpdateProject` |
| `update-project-line-item` | PUT | `/projects/{id}/line_items/{line_item_id}` | `invoices:write` | `id` / `line_item_id` | none | no | `ProjectsIdLineItems` |
| `update-project-line-item-v1` | PUT | `/v1/projects/{id}/line_items/{line_item_id}` | `invoices:write` | `id` / `line_item_id` | none | no | `V1ProjectsIdLineItems` |
| `update-project-v1` | PUT | `/v1/projects/{id}` | `invoices:write` | `id` | none | no | `UpdateProject` |

### Receipts

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `download-url-for-a-receipt` | GET | `/v3/receipts/id/{id}/download` | `receipts:read` | `id` | none | no | none |
| `get-receipt-by-id` | GET | `/v3/receipts/id/{id}` | `receipts:read` | `id` | none | no | none |
| `list-receipts` | GET | `/v3/receipts` | `receipts:read` | none | `scope` | yes | none |

### Reports

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `balance-report` | GET | `/v3/reports/balance` | `reports:read` | none | `year` / `quarter` / `month` | no | none |
| `dashboard-balance` | GET | `/reports/summaries/balance` | `reports:read` | none | none | no | none |
| `dashboard-balance-v1` | GET | `/v1/reports/summaries/balance` | `reports:read` | none | none | no | none |
| `dashboard-btw` | GET | `/reports/summaries/btw` | `reports:read` | none | none | no | none |
| `dashboard-btw-v1` | GET | `/v1/reports/summaries/btw` | `reports:read` | none | none | no | none |
| `dashboard-cash-and-bank` | GET | `/reports/summaries/cash_and_bank` | `reports:read` | none | none | no | none |
| `dashboard-cash-and-bank-v1` | GET | `/v1/reports/summaries/cash_and_bank` | `reports:read` | none | none | no | none |
| `dashboard-invoices` | GET | `/reports/summaries/invoices` | `reports:read` | none | none | no | none |
| `dashboard-invoices-v1` | GET | `/v1/reports/summaries/invoices` | `reports:read` | none | none | no | none |
| `dashboard-profit-and-loss` | GET | `/reports/summaries/profit_and_loss` | `reports:read` | none | none | no | none |
| `dashboard-profit-and-loss-v1` | GET | `/v1/reports/summaries/profit_and_loss` | `reports:read` | none | none | no | none |
| `profit-and-loss-report` | GET | `/v3/reports/profit-and-loss` | `reports:read` | none | `year` / `quarter` / `month` / `label_ids` | no | none |

### Tradenames

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `list-tradenames` | GET | `/tradenames` | `organizations:read` | none | none | no | none |
| `list-tradenames-v1` | GET | `/v1/tradenames` | `organizations:read` | none | none | no | none |

### V2

| Slug | Method | Path | Scope | Path params | Filters | Page | Body schema |
|---|---|---|---|---|---|---|---|
| `download-estimate-pdf-v2` | GET | `/v2/estimates/{id}/download` | `estimates:read` | `id` | `version` | no | none |
| `get-estimate-by-id-v2` | GET | `/v2/estimates/{id}` | `estimates:read` | `id` | none | no | none |
| `get-estimate-send-settings-v2` | GET | `/v2/estimates/{id}/send_settings` | `estimates:read` | `id` | none | no | none |
| `get-invoice-by-id-v2` | GET | `/v2/invoices/{id}` | `invoices:read` | `id` | none | no | none |
| `list-estimates-v2` | GET | `/v2/estimates` | `estimates:read` | none | `query` / `estimate_status` / `acceptance_status` | yes | none |
| `list-invoices-v2` | GET | `/v2/invoices` | `invoices:read` | none | `query` / `invoice_status` | yes | none |

---

## 5. MIGRATION BEHAVIOR

### Filters and record state

Expenses accept `vat_date_from` and `vat_date_till`. Use the VAT date for year extraction. Invoices have no date filter in the listed operations, so fetch every page and filter locally after extraction. Receipts accept `scope=in_inbox` for unlinked inbox items and `scope=all` for the broader receipt list.

Archived customers can behave as deleted records and return `deleted: true`. Projects and bank accounts expose an `archived` flag. The spec has no `include_deleted` filter. Preserve these flags in the migration register.

### Closed years and payment matching

Writes to a closed financial year fail with HTTP 422. Payment-matching source operations are limited to the last 24 months and are unavailable inside a closed year. Stop after a 422 and inspect the request and year status.

### Downloads

Receipt, invoice and attachment download operations return short-lived signed links that last a few minutes. Call `jortt-cli fetch SIGNED_HTTPS_URL --out FILE` promptly. The fetch command sends no authorization header to the signed link.

---

## 6. EXTRACTION RECIPES

Run these from the Accountant root or use an absolute destination inside `migration-workspace/`. Relative output names resolve beneath that directory. Substitute IDs and years locally. Do not paste extracted contents into tracked documentation.

### Expenses by VAT year

```bash
jortt-cli call list-expenses --vat_date_from YYYY-01-01 --vat_date_till YYYY-12-31 --all --out expenses-YYYY.json
```

### Invoices

```bash
jortt-cli call list-invoices-v3 --all --out invoices.json
```

Filter the extracted invoice set client-side because the list operation has no date filter.

### Inbox receipts

```bash
jortt-cli call list-receipts --scope in_inbox --all --out receipts-inbox.json
```

### Bank transactions per account

```bash
jortt-cli call list-bank-accounts-v3 --out bank-accounts.json
jortt-cli call list-bank-transactions-v3 --id BANK_ACCOUNT_ID --all --out bank-transactions.json
```

### Reports by year

```bash
jortt-cli call profit-and-loss-report --year YYYY --out profit-and-loss.json
jortt-cli call balance-report --year YYYY --out balance.json
```

### Payroll journal entries

```bash
jortt-cli call list-loonjournaalposten --year YYYY --out payroll-journal.json
```

This requires `payroll:read`, which is not in the default scope list.

---

## 7. SOURCE AND LIMITS

The catalogue reflects the supplied local Swagger snapshot. UI-only exports and behavior not declared by that spec are documented in [`exports-and-limits.md`](exports-and-limits.md). Mark any operation behavior absent from these local facts as `UNVERIFIED`.

---

## 8. RELATED RESOURCES

- [`cli.md`](cli.md) - Commands that call these operations
- [`exports-and-limits.md`](exports-and-limits.md) - Records the API cannot return
- [`../feature-catalog/feature-catalog.md`](../feature-catalog/feature-catalog.md) - Command inventory with source and test anchors
