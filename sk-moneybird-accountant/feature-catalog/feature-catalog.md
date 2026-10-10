---
title: sk-moneybird-accountant: Feature Catalog
description: Current feature inventory for Dutch ZZP migration, live bookkeeping, tax routing, tool handoffs, and privacy boundaries.
trigger_phrases:
  - Dutch ZZP bookkeeping
  - Jortt to Moneybird migration
  - Moneybird accounting workflow
last_updated: 2026-10-10
version: 1.0.0.0
---

# sk-moneybird-accountant: Feature Catalog

This catalog describes the current bookkeeping and migration behavior of sk-moneybird-accountant and links to the per-feature files with source and validation anchors.

---

## 1. OVERVIEW

Use this catalog as the current feature inventory. Each entry points to a focused reference with its implementation and offline validation anchors.

---

## 2. BOOKKEEPING AND MIGRATION

### Migration phase routing

#### Description

Selects a Jortt to Moneybird migration phase, its reference, owner tags, and exit gate.

#### Current Reality

The skill routes historical Jortt to Moneybird work to a phase-group reference and its gate. The index maps phase groups, while the control framework carries cross-phase verification and stop conditions. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/migration-phase-routing.md](bookkeeping-and-migration/migration-phase-routing.md) for source and validation anchors.

---

### Live bookkeeping cadence

#### Description

Routes current monthly, quarterly, and yearly bookkeeping through the appropriate review steps.

#### Current Reality

The LIVE mode guides recurring bookkeeping for current periods. It separates monthly reconciliation, quarterly VAT review, and yearly close work. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/live-bookkeeping-cadence.md](bookkeeping-and-migration/live-bookkeeping-cadence.md) for source and validation anchors.

---

### Year-specific ZZP guidance

#### Description

Checks the tax year and sources general Dutch ZZP income tax, VAT, cost, and administration guidance.

#### Current Reality

The skill explains general Dutch sole-trader rules with year-specific source links. It labels conflicting and unverified facts and escalates personal eligibility decisions. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/year-specific-zzp-guidance.md](bookkeeping-and-migration/year-specific-zzp-guidance.md) for source and validation anchors.

---

### CLI tool handoff

#### Description

Routes Jortt reads through jortt-cli and Moneybird reads or writes through moneybird-guard.

#### Current Reality

The skill does not reproduce CLI mechanics. It hands Jortt reads to jortt-cli and Moneybird reads or writes to moneybird-guard through cli-jortt and cli-moneybird. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/api-tool-handoff.md](bookkeeping-and-migration/api-tool-handoff.md) for source and validation anchors.

---

### Migration data privacy

#### Description

Keeps migration records in migration-workspace and limits private-database reads to a named file during migration.

#### Current Reality

The project bootstrap and skill set a strict boundary around private finance records. The agent does not list or search the private database and stores migration work only in migration-workspace. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/migration-data-privacy.md](bookkeeping-and-migration/migration-data-privacy.md) for source and validation anchors.

---

### Operator tax boundary

#### Description

Leaves return filing and final tax judgement with the operator or a bookkeeper.

#### Current Reality

The skill can organize evidence and explain general rules, but it does not file returns or present personal tax conclusions as final. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/operator-tax-boundary.md](bookkeeping-and-migration/operator-tax-boundary.md) for source and validation anchors.

---
