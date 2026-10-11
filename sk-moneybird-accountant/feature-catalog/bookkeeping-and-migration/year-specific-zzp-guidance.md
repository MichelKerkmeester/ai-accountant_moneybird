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
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/dutch-tax-rules.md | Shared | Explains how each Dutch tax rule works across years and routes to the year folders. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2020/README.md | Shared | Routes a 2020 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2021/README.md | Shared | Routes a 2021 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2022/README.md | Shared | Routes a 2022 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2023/README.md | Shared | Routes a 2023 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2024/README.md | Shared | Routes a 2024 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2025/README.md | Shared | Routes a 2025 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2026/README.md | Shared | Routes a 2026 question to the topic file for that tax year. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/2027/README.md | Shared | Routes a 2027 question to the topic file for that tax year. |

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
