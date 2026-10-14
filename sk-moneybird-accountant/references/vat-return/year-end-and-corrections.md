---
title: Year-end settlements and corrections for the VAT return
description: The four year-end settlements S1 to S4 in the final VAT period of a calendar year and the correction routing between the next return and the suppletie. The route, the suppletie filing and the payment are Operator actions.
trigger_phrases:
  - last VAT return of the year
  - laatste btw-aangifte van het jaar
  - btw suppletie
  - btw correctie vorige periode
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Year-end settlements and corrections for the VAT return

**Rule:** The final VAT period of a calendar year carries four settlements before the pack and before the arithmetic gate. Every figure, threshold and deadline is in the year files under `references/tax-rules/`. The correction route, the suppletie filing and the payment are `[Operator]` actions.

---

## 1. OVERVIEW

A final-period request runs the settlements `S1` to `S4` in section 2. Step 12 of [preparation.md](preparation.md) sends the period here. A correction that belongs to an earlier period follows section 3.

The settlements are decisions, not arithmetic alone. The private-use split, the car facts and the revision allocation rest on the facts of the administration, so the Operator or a bookkeeper decides them. The agent prepares the figures and the evidence.

---

## 2. THE FOUR SETTLEMENTS

| ID | Settlement | What it covers | Owner |
|---|---|---|---|
| S1 | Private use of business goods and services | The private-use charge on business goods and services, settled in rubriek 1d. Private use after a full deduction needs the memoriaal. A purchase-time split limits the input VAT at purchase instead. | Agent prepares. `[Operator]` decides the private share when the facts are unclear. |
| S2 | The business car | The car private-use adjustment for the year. Actual use needs a usage record. Without adequate records the year file states the standard calculation and its variants. | `[Operator]` or a bookkeeper decides the use records, the acquisition history and the forfait. |
| S3 | The taxed versus exempt turnover pro-rata | The re-estimate of the in-year estimate. Every other quarter marks the running estimate open. Investment-goods revision is separate from the 1d charge. | `[Operator]` or a bookkeeper decides the allocation and the revision. |
| S4 | The BUA correction for provisions and gifts | The correction where the staff-provision and gift exclusion applies above the threshold the year file states. | `[Operator]` or a bookkeeper decides each case. |

The revision window, the car calculations, the BUA threshold and the pro-rata rules are in the year file, for example [BTW 2026 figures](../tax-rules/2026/vat/figures.md) and [BTW 2026 rules](../tax-rules/2026/vat/rules.md). Investment-goods revision and its window are in [Fixed assets](../fixed-assets.md). The lease scope of the car forfait is an open point. See [README](README.md#5-open-points), open point `O4`.

A final period with nothing to settle still records why each settlement is not applicable. A settlement that cannot be decided is a blocker for the pack.

---

## 3. CORRECTION ROUTING

A corrected period is not always the period under review. Split every correction at the boundary the year file states.

| Correction | Route | Owner |
|---|---|---|
| At or below the boundary | Include it in the next regular return in the same rubriek and name it in the pack. | `[Operator]` confirms the route and files the return. |
| Above the boundary | File the suppletie form on top of the period's own history. State the corrected figures for the period or the year, not only the difference. | `[Operator]` owns the route, the suppletie filing and the payment. |

Rules that apply to both routes:

- The boundary, the reporting deadline and the correction window are in the year file, for example [BTW 2026 figures](../tax-rules/2026/vat/figures.md) and [BTW 2026 rules](../tax-rules/2026/vat/rules.md). Never state the boundary from memory.
- The phrases a correction request uses are `suppletie`, `naheffing` and `correctie vorige periode`.
- Moneybird can file a suppletie only on top of its own filing history. A period filed wholly outside Moneybird goes through the Belastingdienst route.
- Mark a correction that the Belastingdienst already knows so it is not counted twice.
- A correction the year file's window no longer covers is a blocker and goes to the Operator.
- The payment and any belastingrente are in the year's procedure file, for example [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md).

---

## 4. RELATED RESOURCES

- [README](README.md) for the boundary and the open points.
- [Preparation](preparation.md) for the step 12 that sends a final period here.
- [Rubrieken](return-boxes.md) for the correction phrases and the rubriek table.
- [Review pack](review-pack.md) for the output contract.
- [Fixed assets](../fixed-assets.md) for the revision rules.
