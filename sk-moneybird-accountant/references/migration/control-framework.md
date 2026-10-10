---
title: Migration control framework
description: Agent roles, verification, risks, exceptions, stop conditions, dashboard, first runs, and completion.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration control framework

Agent roles, verification, risks, exceptions, stop conditions, dashboard, first runs, and completion. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

---

<!-- SOURCE PLAN BODY START -->

## 4. AGENT STRUCTURE

| Agent | Reads | Writes | Moneybird access |
|---|---|---|---|
| Orchestrator | Reports, registers, gate status | `MIGRATION_CONFIG`, input folders | None |
| Evidence Archivist | Document archive | Manifest, registry | None |
| Document Agent | `Inputs/document/` only | `DOCUMENT_REGISTER` | None |
| Ledger Agent | `Inputs/ledger/` (XAF) only | `LEDGER_REGISTER` | None |
| Bank Agent | `Inputs/bank/` only | `BANK_REGISTER` | None |
| Tax Filing Agent | `Inputs/tax/` only | `TAX_REGISTER` | None |
| VAT Agent | `Inputs/vat/` (invoices, no bookings) | `VAT_CLASSIFICATION_REGISTER` | None |
| Reconciliation Agent | All registers | `CANONICAL_DATASET` | None |
| Mapping Agent | Canonical dataset | Mappings | Guarded CLI reads with `MONEYBIRD_GUARD_READ_ONLY=1` |
| Migration Writer | Approved pre-write reports | Moneybird, write journal | Writer token through `moneybird-guard` |
| Independent Auditor | Originals and Moneybird | Audit reports | Guarded CLI reads with `MONEYBIRD_GUARD_READ_ONLY=1` |
| Red Team | Everything | Red team reports | Guarded CLI reads with `MONEYBIRD_GUARD_READ_ONLY=1` |

The Orchestrator manages phases and decides whether gates pass. It books nothing. The Migration Writer is the only agent with write access. Every independent agent runs in its own session (see Phase 3).

---

## 5. VERIFICATION LOOP PER RECORD

How much checking a record gets depends on its risk class.

**GREEN records:**

```
original document
  -> Document, Ledger, Bank and VAT agents, each independent
  -> Reconciliation Agent
  -> risk classification
  -> batch pre-write report, approved by the operator
  -> Migration Writer
  -> read-back through the synchronization endpoints
  -> Independent Auditor sample per batch
  -> Red Team per quarter (Phase 8) and per year (Phase 13)
  -> VERIFIED
```

**AMBER records and every high-risk transaction:** the same path, plus an individual review by the Independent Auditor and the Red Team before the record counts as `VERIFIED`.

**RED and BLACK records:** never written.

Reviewing every green record one by one would multiply the runs without finding more. The per-quarter and per-year Red Team passes still cover green records.

---

## 6. RISK MODEL

| Class | Meaning | Write |
|---|---|---|
| **GREEN** | Several sources support the same conclusion | Allowed after batch approval |
| **AMBER** | Probably correct, but a secondary source is missing or differs for a known reason | After individual review |
| **RED** | Primary sources contradict each other | Never |
| **BLACK** | Not enough evidence | Never |

---

## 7. HIGH-RISK TRANSACTIONS

Always add an extra check for:

- EU reverse charge and non-EU reverse charge.
- Foreign VAT.
- A new international supplier.
- Assets and depreciation.
- Private versus business.
- Journal entries.
- The opening balance and the year-end closing.
- A historical tax difference.
- A credit note.
- An unusual currency.

---

## 8. EXCEPTION LEDGER

Every difference gets a permanent ID.

| ID | Year | Migration ID | Problem | € impact | VAT impact | Risk | Status |
|---|---|---|---|---:|---:|---|---|

Status values:

- `OPEN`
- `INVESTIGATING`
- `RESOLVED`
- `ACCEPTED HISTORICAL DIFFERENCE`
- `TAX REVIEW REQUIRED`
- `SOURCE MISSING`

An exception is never removed automatically.

---

## 9. STOP CONDITIONS

Stop all writes when any of these occur:

- A duplicate fingerprint.
- An invoice amount that differs from the ledger.
- An unexplained currency difference.
- An uncertain supplier.
- Uncertain VAT.
- A `RED` or `BLACK` record.
- An unexplained bank balance.
- An unexplained VAT difference.
- A missing original document.
- An unexpected depreciation.
- An unexplained opening item.
- A material difference between the annual accounts and the ledger.
- A `429` rate-limit response that persists after waiting for `Retry-After`.
- A write response that does not match the planned record.

Never invent a closing entry to make a difference disappear.

---

## 10. MASTER DASHBOARD

| Phase | Status | Blocking issues |
|---|---|---|
| 0 Setup | | |
| 1 Inventory | | |
| 2 Sources | | |
| 3 Independent extraction | | |
| 4 Reconciliation | | |
| 5 Anomalies | | |
| 6 Mapping | | |
| 7 Pilot | | |
| 8 Migration | | |
| 9 VAT | | |
| 10 Year-end | | |
| 11 IB | | |
| 12 Continuity | | |
| 13 Red Team | | |
| 14 Lock | | |

Per year:

| Year | Docs | Ledger | Bank | VAT | IB | Balance | Exceptions | Status |
|---|---|---|---|---|---|---|---|---|

---

## 11. CONCRETE FIRST RUNS

**Run 1.** Do Phase 0 and Phase 1 only. Then generate the `INITIAL MIGRATION REPORT` with:

1. The business years found.
2. The number of archive invoices per year.
3. The Jortt data available through the API.
4. The bank data available.
5. The tax documents available.
6. Missing sources, as an operator task list.
7. Duplicates.
8. The proposed Moneybird start year.
9. The proposed pilot month.

Make no Moneybird write.

**Run 2.** After the missing sources are collected, run Phases 2 to 6. Generate the `MIGRATION BLUEPRINT`.

**Run 3.** Run Phase 7, the pilot in the trial administration, only.

**Run 4 onward.** Migrate one quarter per run through Phases 8 and 9.

**After a full year.** Run Phases 10 to 14. Only then start the next year.

---

## Definition of done

The migration as a whole is done only when every year from the start year onward is `YEAR VERIFIED & LOCKED`. The newest year must also connect without unexplained discontinuity.

From then on, Moneybird is the complete, verified historical administration and the base for future bookkeeping.

---

## Sources

Checked on 2026-10-10.

- Jortt developer docs: https://developer.jortt.nl/
- Jortt OpenAPI spec: https://api.jortt.nl/swagger_doc
- Jortt auditfile: https://www.jortt.nl/boekhouder/boekhouder-uitleg/auditfile/
- Jortt general ledger export: https://www.jortt.nl/uitleg/faq/uitdraai-maken-van-een-grootboek/
- Leaving Jortt: https://www.jortt.nl/boekhouder/boekhouder-uitleg/weggaan-bij-jortt/
- Moneybird AI connection: https://helpcenter.moneybird.nl/nl/articles/396511-ai-koppeling
- Moneybird API introduction: https://developer.moneybird.com/introduction.md
- Moneybird authentication: https://developer.moneybird.com/authentication
- Moneybird CLI: https://developer.moneybird.com/tools/cli
- Moneybird OpenAPI spec: https://github.com/moneybird/openapi
- Moneybird external invoices: https://developer.moneybird.com/integration/importing-external-invoices.md
- Moneybird reports: https://developer.moneybird.com/api/reports
- Switching to Moneybird: https://helpcenter.moneybird.nl/nl/articles/207241-overstappen-naar-moneybird
- Moneybird period locking: https://helpcenter.moneybird.nl/nl/articles/207253-periodes-vergrendelen
- Moneybird VAT filing: https://helpcenter.moneybird.nl/nl/articles/223650-de-btw-aangifte-indienen

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
