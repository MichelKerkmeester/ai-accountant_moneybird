---
title: Migration phases 3 to 5
description: Independent reconstruction, cross-reconciliation, and anomaly review.
trigger_phrases:
  - moneybird migration
  - jortt historical bookkeeping
  - migration phase gate
  - sole trader accounting migration
importance_tier: important
contextType: implementation
version: 1.0.0.0
---

# Migration phases 3 to 5

Independent reconstruction, cross-reconciliation, and anomaly review. Use the migration index to select this phase group and preserve the source plan's owner tags.

---

## 1. OVERVIEW

This file preserves the source plan text for its named phase group. The source body below keeps the plan wording and section order. Only source heading levels were adjusted to fit this reference.

<!-- SOURCE PLAN BODY START -->

## Phase 3: Reconstruct each source independently

### Goal

Rebuild every evidence layer on its own before the layers can influence each other. No Moneybird writes.

### How independence is enforced

Each agent in 3A to 3E runs in its own Claude Code session. The Orchestrator copies, never moves, only that agent's inputs into `migration-workspace/Inputs/<agent>/`. The agent's prompt names that folder as its only input. Each agent writes its register to `migration-workspace/Registers/`. No agent reads another agent's register until Phase 4.

A shared session cannot keep this promise, because everything earlier in a conversation stays visible.

### 3A: Document Truth

**Input:** original documents only.

The Document Agent analyses every invoice and records:

- Supplier, legal entity and country.
- Invoice number and date.
- VAT ID and currency.
- Net, VAT and gross amounts.
- Reverse charge.
- Type: purchase or sale.

Output: `DOCUMENT_REGISTER`

### 3B: Ledger Truth

**Input:** the XAF files only.

The Ledger Agent parses the XAF and extracts:

- Booking date, account, amount and debit or credit.
- VAT code, document reference, relation and invoice number.
- Journal entries, assets and private items.
- Opening entries and year-end closings.

Check: debits equal credits, per journal and per year.

Output: `LEDGER_REGISTER`

### 3C: Cash Truth

**Input:** the bank files only.

The Bank Agent records per transaction:

- Account, date, amount and currency.
- Counterparty, description and payment reference.

It also records opening and closing balances per file.

Output: `BANK_REGISTER`

### 3D: Filing Truth

**Input:** the filed returns, assessments and annual accounts only.

The Tax Filing Agent reads:

- VAT returns and supplementary returns.
- IB returns and final assessments.
- Jortt annual accounts.
- Jortt VAT summaries, kept apart from filed returns.

Output: `TAX_REGISTER`

### 3E: Independent VAT classification

**Input:** the original invoices, without the Jortt bookings.

The VAT Agent classifies each invoice as one of:

- Dutch VAT
- EU reverse charge
- Non-EU reverse charge
- 0%
- No VAT
- Foreign VAT
- Unclear

Output: `VAT_CLASSIFICATION_REGISTER`

### Exit Gate 3

Every source layer has been processed independently, each in its own session with its own input folder. No one has tried to hide or reconcile differences yet.

Status: `PHASE 3 COMPLETE`

---

## Phase 4: Cross-reconciliation

### Goal

Link all independent evidence sources to each other.

### Reconciliation Agent

For each economic event, link the four sources:

```
DOCUMENT  <->  XAF ENTRY  <->  BANK TRANSACTION  <->  TAX PERIOD
```

Create one `MIGRATION_RECORD` per event.

### Migration ID

Every event gets a permanent ID, for example `MIG-2024-000123`.

### Record contents

- Source ID and Migration ID.
- Invoice, ledger match, bank match and tax match.
- Historical category and historical VAT code.
- Independent VAT classification.
- Risk class, confidence and differences.

Output: `CANONICAL_DATASET`, the set of all migration records.

---

## Phase 5: Completeness and anomaly scan

### Goal

Find everything that does not match before Moneybird is filled.

**Check A, documents to ledger.** Look for `DOCUMENT WITHOUT LEDGER`. Possible causes:

- The invoice was never booked.
- It is a duplicate.
- It is private.
- It belongs to another year.
- The supplier is booked under a different name.

**Check B, ledger to documents.** Look for `LEDGER WITHOUT DOCUMENT`.

**Check C, bank to documents and ledger.** Look for `BANK WITHOUT EXPLANATION`.

**Check D, documents to bank.** Look for `DOCUMENT WITHOUT PAYMENT`. This is not automatically wrong. Check whether it is:

- Still open.
- Paid privately.
- Settled by a credit note.
- Offset against another amount.

**Check E, duplicates.** Use both the SHA-256 hash and the fingerprint `supplier + invoice number + date + currency + gross amount`.

**Check F, foreign suppliers.** Review all of these:

- AI subscriptions.
- SaaS.
- Hosting.
- Developer tools.
- International services.

### Red Team pass 1

The Red Team looks on purpose for:

- Duplicate invoices and duplicate payments.
- Missing credit notes.
- Wrong currency or wrong supplier entity.
- EU versus non-EU mistakes.
- 0% versus reverse charge mistakes.
- Private versus business mistakes.
- Wrongly booked tax payments.
- Assets booked as costs.
- Double depreciation.

### Output

`EXCEPTION_LEDGER`

### Exit Gate 5

Every record has one of these risk classes: `GREEN`, `AMBER`, `RED` or `BLACK`. No Moneybird write happens for `RED` or `BLACK`.

Status: `PHASE 5 COMPLETE`

---

<!-- SOURCE PLAN BODY END -->

---

## 2. RELATED RESOURCES

- [Migration index](./README.md) maps every phase to its reference.
- [cli-jortt](../../../cli-jortt/SKILL.md) owns Jortt reads.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) owns Moneybird reads and writes.
