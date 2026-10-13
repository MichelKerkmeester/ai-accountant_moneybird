---
title: Operator tax boundary
description: Leaves return filing and final tax judgement with the operator or a bookkeeper.
trigger_phrases:
  - Operator tax boundary
  - Dutch ZZP bookkeeping workflow
  - Moneybird accounting assistant
  - return filing is operator-only
version: 1.0.0.0
---

# Operator tax boundary

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Leaves return filing and final tax judgement with the operator or a bookkeeper.

The skill can organize evidence and explain general rules, but it does not file returns or present personal tax conclusions as final.

---

## 2. HOW IT WORKS

A return-submission request is handed to the operator. A personal eligibility or classification question is answered with general information, the year and source, plus a clear escalation for the operator or a bookkeeper.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AGENTS.md | Shared | Makes return filing operator-only and requires escalation of tax judgement. |
| sk-moneybird-accountant/SKILL.md | Shared | Defines the tax and return boundaries. |
| sk-moneybird-accountant/references/dutch-tax-rules.md | Shared | Gives the general rule that the operator or bookkeeper applies to a personal case and separates verified rules from conflicts, unverified points and proposals. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/operator-tax-boundary.md | Manual playbook | Offline routing scenario for this feature. |

---

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/operator-tax-boundary.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Related workflow behavior.
- [live-bookkeeping-cadence.md](live-bookkeeping-cadence.md) - Related workflow behavior.
