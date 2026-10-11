---
title: Year-specific ZZP guidance
description: Checks the tax year and sources general Dutch ZZP income tax, VAT, cost, and administration guidance.
trigger_phrases:
  - Year-specific ZZP guidance
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - TAX-001
version: 1.0.0.0
---

# Year-specific ZZP guidance

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Checks the tax year and sources general Dutch ZZP income tax, VAT, cost, and administration guidance.

The skill explains general Dutch sole-trader rules with year-specific source links. It labels conflicting and unverified facts and escalates personal eligibility decisions.

---

## 2. HOW IT WORKS

Before using a changing amount or rate, the agent checks the relevant tax year and loads the matching tax section. It reports the year and source, and leaves case-specific legal or tax judgement to the operator or a bookkeeper.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/SKILL.md | Shared | Requires a current-year check and prohibits final tax advice. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/zzp-tax-and-vat.md | Shared | Points to the tax folder and keeps the record and invoice duties. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/README.md | Shared | Routes a tax question to the general rules or a year file and lists conflicts and gaps. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/general-rules.md | Shared | Explains how each Dutch ZZP rule works across years. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2020.md | Shared | Verified 2020 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2021.md | Shared | Verified 2021 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2022.md | Shared | Verified 2022 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2023.md | Shared | Verified 2023 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2024.md | Shared | Verified 2024 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2025.md | Shared | Verified 2025 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2026.md | Shared | Verified 2026 figures with status and source. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/tax/year-2027.md | Shared | Verified 2027 figures with status and source. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/current-year-zzp-question.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/year-specific-zzp-guidance.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
