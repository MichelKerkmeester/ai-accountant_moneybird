---
title: Investment and claim register
description: The dated per-asset register for an investment allowance claim. Order date, payment dates, in-use date, RVO reference and prior aftrek as one row per asset, with every value cell a braced placeholder.
nav_label: "Investment and claim register"
trigger_phrases:
  - investment and claim register
  - investeringsaftrek register
  - per-asset investment register
  - RVO reference register
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Investment and claim register

**Rule:** One row per asset. The Operator supplies the order, payment and in-use facts and the RVO reference. The agent computes the claim from those facts and the year file. The register is the evidence artifact the procedure requires before an investment allowance is claimed, and every value cell in the table is a braced placeholder. Every rule reference is a link into the year files under `references/tax-rules/`.

---

## 1. OVERVIEW

The KIA, EIA, MIA, Vamil and the desinvesteringsbijtelling cannot be reconstructed from the yearly profit and loss account. This register carries the facts per asset so the claim and any later recapture can be traced. The Operator fills the five columns from the order confirmation, the bank records, the in-use record and the RVO notification. The agent computes the claim and records the source.

The register lives in the pack and in the private workspace. It is never a promise that an allowance is granted, because the conditions and the eligibility stay Operator or bookkeeper judgement.

---

## 2. THE REGISTER

One row per asset. Every value cell is a braced placeholder.

| Order date | Payment dates | In-use date | RVO reference | Prior aftrek |
|---|---|---|---|---|
| `{order_date}` | `{payment_dates}` | `{in_use_date}` | `{rvo_reference}` | `{prior_aftrek}` |
| `{order_date}` | `{payment_dates}` | `{in_use_date}` | `{rvo_reference}` | `{prior_aftrek}` |

A row with a missing order date, a missing payment date, a missing in-use date or a missing RVO reference is an open row and blocks the claim. A row with no prior claim records the check that proved there is none instead of a guess.

---

## 3. THE CONDITIONS THE REGISTER EVIDENCES

- **The per-asset floor.** The asset must meet the floor in [Investeringen 2026 figures](../tax-rules/2026/investments/figures.md).
- **The RVO notification window.** The notification must fall inside the window in [Investeringen 2026 notes](../tax-rules/2026/investments/notes.md).
- **The payment condition.** The payments made before use are tied to the register's payment dates under the rule in [Investeringen 2026 rules](../tax-rules/2026/investments/rules.md).
- **The in-use condition.** The in-use date is checked against the rule in [Investeringen 2026 rules](../tax-rules/2026/investments/rules.md).
- **The desinvesteringsbijtelling.** Disposals inside the recapture window are checked against the prior aftrek and the threshold in [Investeringen 2026 figures](../tax-rules/2026/investments/figures.md).
- **The claim combination.** EIA and MIA do not combine on one asset and either can combine with the KIA per [Investeringen 2026 rules](../tax-rules/2026/investments/rules.md).

The year file for the resolved `year_key` owns every value these conditions read. The register carries the facts only.

---

## 4. THE RULES FOR THE REGISTER

- The Operator supplies the facts. The agent never infers an order date or an in-use date from a booking.
- A missing fact stays open and the asset stays out of the claim until it lands.
- The prior aftrek and the RVO reference carry across years so a later desinvestering can be checked.
- The register is evidence, not a grant. The claim is recorded with its source and the year file that owns each condition.
- The pack keeps the register rows and the [open-point list](risks-and-open-points.md) apart, because the register facts are per asset and the open points are settled by a page or a decision.

---

## 5. RELATED RESOURCES

- [README](README.md) for the boundary and the shared disposition vocabulary.
- [Procedure](procedure.md) for step 7 and the register evidence gate.
- [Operator inputs](operator-inputs.md) for the per-asset register row and its disposition.
- [Fixed assets](../fixed-assets.md) for the asset flow, the depreciation schedule and the desinvestering.
- [Risks and open points](risks-and-open-points.md) for the unresolved items that touch an investment claim.
- [Investeringen 2026 figures](../tax-rules/2026/investments/figures.md), [rules](../tax-rules/2026/investments/rules.md) and [notes](../tax-rules/2026/investments/notes.md) for the resolved year's values and mechanics.
