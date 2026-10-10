---
title: sk-moneybird-accountant
description: Bookkeeping and Jortt to Moneybird migration guidance for a Dutch sole trader.
trigger_phrases:
  - help me migrate my jortt bookkeeping into moneybird
  - review my monthly moneybird bookkeeping
  - check the vat for this quarter
  - what is the current dutch zzp mileage rate
  - how should i book this business expense in moneybird
  - help me prepare a year-end bookkeeping review
  - explain the jortt to moneybird mapping
  - help me review a dutch sole trader yearly close
version: 1.0.0.0
---

# sk-moneybird-accountant

> A Dutch sole-trader bookkeeping assistant that routes migration work, live bookkeeping, and general ZZP questions through clear evidence and human review.

Historical migration needs controlled phase gates. Live bookkeeping needs repeatable period checks. This skill puts the routing and privacy rules in one place while keeping detailed accounting guidance in references.

## 1. AT A GLANCE

| | |
|---|---|
| **Identity** | Dutch sole-trader bookkeeping and migration assistant |
| **Modes** | MIGRATION and LIVE |
| **Tool handoff** | jortt-cli for Jortt reads, moneybird-guard for Moneybird reads and writes |
| **Data location** | migration-workspace/ |

---

## 2. OVERVIEW

### What It Does

The skill routes Jortt to Moneybird migration work by phase and gate. It also guides monthly, quarterly, and yearly bookkeeping, with general support for Dutch ZZP questions. It leaves tax judgements and all return filing with the operator or a bookkeeper.

### The Operating Boundary

Jortt is read-only. Reach Jortt and Moneybird through their CLI skills, with Moneybird writes guarded by moneybird-guard. Migration records and reports stay in migration-workspace/. The private database is never listed or searched, and a migration may read only a specific file the operator names.

---

## 3. QUICK START

Start with the project bootstrap at AGENTS.md, then read SKILL.md. Select MIGRATION for historical Jortt to Moneybird work or LIVE for current bookkeeping and general ZZP questions. Load only the routed reference and matching CLI skill when an operation is needed. Set MONEYBIRD_GUARD_READ_ONLY=1 for read-only Moneybird sessions.

---

## 4. HOW IT WORKS

MIGRATION follows the phase group mapped by references/migration/README.md. Each phase keeps its owner tags and exit gate. LIVE uses the monthly, quarterly, yearly, or ad hoc topic route in SKILL.md.

For Jortt reads, follow cli-jortt/SKILL.md and use jortt-cli. For Moneybird reads or writes, follow cli-moneybird/SKILL.md and use moneybird-guard. Neither this README nor its references repeat CLI mechanics.

---

## 5. INTEGRATION AND NAVIGATION

| Need | Start here |
|---|---|
| Mode selection and safety rules | [SKILL.md](./SKILL.md) |
| Migration phase routing | [Migration index](./references/migration/README.md) |
| Dutch tax, VAT, costs, and administration | [Tax reference](./references/zzp-tax-and-vat.md) |
| Common Moneybird accounting events | [Bookkeeping reference](./references/moneybird-bookkeeping.md) |
| Source-to-target concept mapping | [Mapping reference](./references/jortt-to-moneybird-mapping.md) |
| Jortt CLI reads | [cli-jortt](../cli-jortt/SKILL.md) |
| Guarded Moneybird CLI reads and writes | [cli-moneybird](../cli-moneybird/SKILL.md) |

---

## 6. VERIFICATION

The package checks validate the skill, catalog, playbook, root metadata, and reference documents. The manual scenarios are offline routing checks. They make no API calls.

---

## 7. RELATED DOCUMENTS

- [Project bootstrap](../AGENTS.md) defines the entry route and privacy contract.
- [Migration index](./references/migration/README.md) maps phases to migration files.
- [cli-jortt](../cli-jortt/SKILL.md) and [cli-moneybird](../cli-moneybird/SKILL.md) own CLI mechanics.
