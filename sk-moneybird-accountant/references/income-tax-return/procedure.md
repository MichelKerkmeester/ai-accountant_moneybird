---
title: Income tax return preparation procedure
description: The ordered cross-year procedure to prepare one Dutch sole-trader income tax return from Moneybird for Operator review. Steps 1 to 12 with their owner tags, the source map, the evidence gates, the review pack differences, the stop rules and the residual risk list.
trigger_phrases:
  - income tax return procedure
  - aangifte inkomstenbelasting stappen
  - IB-aangifte voorbereiden stappen
  - prepare the income tax return
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Income tax return preparation procedure

**Rule:** Run the steps in order. Stop at the first failed check and record it. Every figure, rate, threshold and deadline comes from the year files under `references/tax-rules/`. The agent prepares and never files, submits or pays.

---

## 1. OVERVIEW

Steps 1 to 12 follow the order the 019 research fixes. Each step names its check, the evidence it leaves and its owner tag. `[AI]` means the agent performs the step, `[Operator + AI]` means the agent prepares and the Operator supplies a fact or decides, and `[Operator]` means only the human acts. Step 12 is Operator-only.

Before step 1, resolve the year as `year_key = return_coverage`, load the year README and the topic files, and confirm that every figure used carries the resolved year and a settled status. The resolution rule is in [year and state resolution](../tax-rules/year-and-state.md). Reads run through moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, following [cli-moneybird](../../../cli-moneybird/SKILL.md).

The steps prepare a pack. Filing, payment and the period lock stay Operator-only and the agent does nothing further after step 11.

---

## 2. THE STEPS

| Step | Action | Check that closes the step | Evidence | Owner |
|---|---|---|---|---|
| 1 | Resolve the return year and confirm the year folder is current. | The year README exists and every figure used carries the resolved year and a settled status. | The resolved `year_key` and the year file paths read. | `[Operator + AI]` The agent resolves, the Operator confirms the return year. |
| 2 | Confirm the administration, the book period and the VAT period in a guarded read-only session. | The session is read-only and the administration and periods match the return year. | The guarded session record with the administration and the periods. | `[Operator + AI]` The agent reads, the Operator confirms the administration when more than one exists. |
| 3 | Finish the monthly and quarterly reconciliations. | Sales, purchase documents, bank matching, private movements and exceptions are closed and every unexplained difference is recorded. | The reconciliation state and the exception rows. | `[Operator + AI]` The agent reconciles, the Operator dispositions an unexplained difference. |
| 4 | Pull the year's reports before any closing booking. | The auditfile exists for the resolved year and each report covers the return year inside the report window and rate limit. | The auditfile with its year version and hash, and the report pulls. | `[Operator + AI]` The agent pulls, the Operator authorizes the export route. |
| 5 | Build the commercial profit and loss account and the balance from those reports. | Totals tie to category and ledger support, the balance ties opening to closing and the asset register reconciles to the balance. | The statements, the reconciliation and the asset tie. | `[AI]` |
| 6 | Apply the fiscal bridge domain by domain. | Every adjustment has a reason, an amount and a source and the adjustment-domain list of the year corpus is walked in full. | The bridge schedule with the source and the reflected note per row. | `[Operator + AI]` The agent prepares, the Operator or a bookkeeper decides classification and mixed-use shares. |
| 7 | Collect the dated per-asset register and compute the investment deductions and any desinvesteringsbijtelling. | The per-asset floor, the RVO notification window, the payment condition, the in-use condition and the desinvesterings window are each checked against the register. | [The investment and claim register](investment-and-claim-register.md) with the RVO proof. | `[Operator + AI]` The agent computes from supplied facts, the Operator supplies the order, payment and RVO records. |
| 8 | Apply the ondernemersaftrek chain with the urencriterium evidence, then the MKB-winstvrijstelling. | The IB-ondernemer status, the urencriterium, the deduction order and the profit cap or carry-forward are checked. | The deduction chain with the hours evidence and the Operator attestation. | `[Operator + AI]` The agent computes, the Operator attests the hours and the starter history. |
| 9 | Assemble box 1 income, the box 3 peildatum inventory and the partner facts from Operator input. | The peildatum values are dated, no business asset is duplicated and the partner split totals the whole joint grondslag. | The VIA comparison sheet and the private-part input rows in [operator inputs](operator-inputs.md). | `[Operator + AI]` The agent prepares, the Operator supplies and confirms every private value. |
| 10 | Verify the figures against the evidence and run the checks. | Totals tie to evidence, every pack check has a status and only settled values are presented as settled. | The check result per pack block and the open-exception list. | `[Operator + AI]` The agent runs the checks, the Operator resolves or accepts an exception with a reason. |
| 11 | Hand over the review pack, the Operator input list and the VIA comparison sheet. | The pack holds every part the procedure requires and every prefilled field is listed against its source. | The pack in the private workspace and the comparison sheet. | `[AI]` |
| 12 | Record the confirmation and stop. | The confirmation record holds identity, role, decision, timestamp, pack version and path, return year, accepted exceptions and evidence references. | The confirmation record. | `[Operator]` The Operator reviews the pack, confirms it, files and pays in the product UI. |

The year rules behind steps 6 to 9 are in the year files, for example [Inkomstenbelasting 2026 figures](../tax-rules/2026/inkomstenbelasting/figures.md), [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md), [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md) and [Zvw 2026 figures](../tax-rules/2026/zvw/figures.md). Every rate and threshold changes by year, so read the file for the resolved `year_key`.

---

## 3. THE SOURCE MAP

One row per input on the official return checklist plus the business cijfers list. The evidence class is Moneybird, the books outside Moneybird, the year corpus, or the Operator and the vooraf ingevulde aangifte. A Moneybird row names what the guarded read shows. Every figure is a link into the year corpus and never copied here.

| Return part or figure | Where it comes from | Evidence class | Year file that owns the rule |
|---|---|---|---|
| Commercial result and profit and loss categories | Moneybird resultatenrekening with its category reports | Moneybird | [The year README](../tax-rules/2026/README.md) |
| Balance-sheet lines | Moneybird balans computed from all bookings, period-end figures | Moneybird | [The year README](../tax-rules/2026/README.md) |
| Asset book values and depreciation | Moneybird bezittingen and activastaat plus [fixed assets](../fixed-assets.md) | Moneybird | [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md) |
| VAT position for the year | Moneybird btw-overzicht plus the filed returns | Moneybird | [BTW 2026 figures](../tax-rules/2026/btw/figures.md) |
| Audit trail | The auditfile before the jaarafsluiting, the grootboekkaarten and the RGS Brugstaat | Moneybird | [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md) |
| Commercial-to-fiscal adjustments | The books, the Operator facts and the year corpus | Books outside Moneybird, year corpus | [Dutch tax rules](../tax-rules/dutch-tax-rules.md) |
| Depreciation caps and building floor | [Fixed assets](../fixed-assets.md) plus the Operator WOZ beschikking | Year corpus, Operator | [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md) and [Kosten en auto 2026 figures](../tax-rules/2026/kosten-en-auto/figures.md) |
| KIA, EIA, MIA and Vamil figures | The year file plus the per-asset register and the RVO proof | Year corpus, Operator | [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md) |
| Desinvesteringsbijtelling | The prior claims plus this year's disposals | Books outside Moneybird, Operator | [Investeringen 2026 figures](../tax-rules/2026/investeringen/figures.md) |
| Urencriterium and hours | Moneybird uren registration plus the Operator hours log | Moneybird, Operator | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| Zelfstandigenaftrek and startersaftrek | The year file plus the prior returns and beschikkingen | Year corpus, Operator | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| Aftrek speur- en ontwikkelingswerk | The Operator S&O statement plus the year file | Operator | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| Meewerkaftrek | The Operator partner hours and pay plus the year file | Operator | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| Startersaftrek bij arbeidsongeschiktheid | The Operator beschikking plus the year file | Operator | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| Stakingsaftrek | The Operator staking facts plus the year file | Operator | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| MKB-winstvrijstelling | Computed after the ondernemersaftrek | Year corpus | [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) |
| Oudedagsreserve opening and movements | The Operator prior return plus the annuity evidence | Operator | [Pensioen en AOV 2026 figures](../tax-rules/2026/pensioen-en-aov/figures.md) |
| Private-use car, phone and home | The Operator facts and evidence plus the year file | Operator | [Kosten en auto 2026 figures](../tax-rules/2026/kosten-en-auto/figures.md) |
| Box 1 income, loon and other income | The Operator, the jaaropgaven and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [Inkomstenbelasting 2026 figures](../tax-rules/2026/inkomstenbelasting/figures.md) |
| Box 3 inventory and peildatum | The Operator and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Partner data and allocation | The Operator and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Personal, partner and children details | The Operator, DigiD and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [The year README](../tax-rules/2026/README.md) |
| Children's bank data | The Operator and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Received and paid partneralimentatie | The Operator and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [Inkomstenbelasting 2026 figures](../tax-rules/2026/inkomstenbelasting/figures.md) |
| Crypto holdings | The Operator and the vooraf ingevulde aangifte | Operator, vooraf ingevulde aangifte | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Home and mortgage interest | The Operator with the WOZ beschikking, the hypotheek jaaropgaaf and the notary statement | Operator | [Inkomstenbelasting 2026 figures](../tax-rules/2026/inkomstenbelasting/figures.md) |
| Gifts and care costs | The Operator betalingsbewijzen | Operator | [Inkomstenbelasting 2026 figures](../tax-rules/2026/inkomstenbelasting/figures.md) |
| Annuity premiums and AOV | The Operator jaaropgaaf and premium statements | Operator | [Pensioen en AOV 2026 figures](../tax-rules/2026/pensioen-en-aov/figures.md) |
| Dividend | The Operator dividend statements | Operator | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Voorlopige aanslagen IB and Zvw | The Operator and the Belastingdienst decisions | Operator | [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md) and [Zvw 2026 figures](../tax-rules/2026/zvw/figures.md) |
| Rates, thresholds and rules | The year corpus, the year README first and then the topic KEY FIGURES section | Year corpus | [The year README](../tax-rules/2026/README.md) |
| Deadlines, uitstel and aftercare | The year procedure file | Year corpus | [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md) |
| Filing, payment and period lock | Operator only, behind DigiD and the product UI | Operator | [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md) |

Two product points stay unverified and are never a computation basis. Whether Moneybird automates the investment deduction or holds a fiscal-basis or investment-claim field is unverified, so the activastaat stays supporting evidence until a product check settles it. A historical open-creditors list with per-invoice detail is also unverified, so the balance check does not rely on that report alone.

---

## 4. EVIDENCE GATES

Run the gates in this order. A gate that fails leaves the pack in the open state and blocks the hand-off.

1. **Auditfile first.** Export the auditfile before any closing action. The export is the evidence gate for everything below it, because a jaarafsluiting before the export can strip the profit and loss data from the auditfile. The route and the gate are in [the auditfile-first gate](../yearly-overview/preparation-checklist.md#1-auditfile-first). `[Operator + AI]`
2. **Report window and rate limit.** Every report covers the return year only and each request stays inside the guarded window and rate limit named in [cli-moneybird](../../../cli-moneybird/SKILL.md). `[AI]`
3. **Opening and closing continuity.** Opening balances plus movements equal the closing balance and the asset register reconciles to the business balance. `[AI]`
4. **Bridge completeness.** Walk the adjustment-domain list of the year corpus, not the adjustments someone remembers, and mark each row as reflected in the books or added in the calculation. `[Operator + AI]`
5. **Register conditions.** Check the per-asset floor, the RVO notification window, the payment condition, the in-use condition and the desinvesterings window against [the register](investment-and-claim-register.md). `[Operator + AI]`
6. **Hours plausibility.** Check that the hours log is complete, that standby is excluded, that the urencriterium is not prorated and that the exceptions the year file names are applied. `[Operator + AI]`
7. **Deduction order and cap.** Check that the MKB-winstvrijstelling follows the ondernemersaftrek, that the zelfstandigenaftrek is capped at the profit unless the starters exception applies, and that the benefit cap and the reserve triggers are walked. `[Operator + AI]`
8. **Box 3 peildatum and duplication.** Check the peildatum values, the anti-arbitrage window and that no business asset appears in both the balance and the box 3 inventory. `[Operator + AI]`
9. **VIA comparison and value status.** Compare every prefilled field with its source, present only settled values as settled and label every other value with its settling source. `[Operator + AI]`
10. **Privacy.** No amounts, identifiers, names or private records appear in chat, a summary or a skill file. `[AI]`

The figures each gate reads are in the year files, for example [Aangifte en procedure 2026 figures](../tax-rules/2026/procedure/figures.md) for the report window and [Ondernemersaftrek 2026 figures](../tax-rules/2026/ondernemersaftrek/figures.md) for the deduction chain.

---

## 5. THE REVIEW PACK

The pack shape is the one in [the VAT return review pack](../vat-return/review-pack.md). The nine blocks `P1` to `P9`, the three confirmation parts `C1` to `C3` and the escalation list carry over. What differs for this return:

- The pack is ordered like the Belastingdienst return parts, namely winst uit onderneming, box 1, box 3 and the partner, rather than Binnenland, Buitenland and Voorbelasting.
- `P3` holds the fiscal bridge schedule instead of a rubriek table, with one row per commercial-to-fiscal adjustment and its source.
- An extra block carries the deduction chain from the profit to the belastbare winst uit onderneming and the per-asset register from [the register](investment-and-claim-register.md).
- An extra block carries the VIA comparison sheet, one line per prefilled field with its source and its correction.
- `C2` covers the filing route for the income tax return behind DigiD. `C3` covers the payment or receipt of the assessment. Both stay with the Operator.
- A block carries the rows from [risks and open points](risks-and-open-points.md) with their unresolved label.

Everything else, including the escalation list and the prepared-not-filed stop, stays as the linked pack defines it.

---

## 6. STOP RULES

Stop and record the item when any of these remain open:

- An auditfile that does not exist for the resolved year before the jaarafsluiting.
- An unmatched or undispositioned bank mutation or incoming document.
- An unexplained commercial-to-fiscal difference.
- An item in [operator inputs](operator-inputs.md) with no disposition or with `unresolved`.
- A figure that no year file owns or that carries an unsettled status.
- A judgement call on classification, mixed-use, hours or eligibility that the Operator has not confirmed.
- An open point that a step needs.

A stop condition leaves the pack open. The next action is an Operator question with the evidence attached.

---

## 7. RESIDUAL RISKS

The five residual unknowns are labelled `unresolved` in [risks and open points](risks-and-open-points.md) with the page or check that would settle each one.

- The year-less RVO maxima.
- The derived starters' willekeurige afschrijving cap.
- The undated werkruimte publication.
- The massaal-bezwaar decision date.
- The 2027 bill status.

An unresolved item is never a computation basis and never a rule. The pack keeps it labelled and the year file that owns it keeps its status tag.

---

## 8. RELATED RESOURCES

- [README](README.md) for the boundary, the figure link rule and the disposition vocabulary.
- [Operator inputs](operator-inputs.md) for the input list and the evidence checklist.
- [Investment and claim register](investment-and-claim-register.md) for the per-asset evidence shape.
- [Risks and open points](risks-and-open-points.md) for the residual unknowns.
- [Yearly overview preparation checklist](../yearly-overview/preparation-checklist.md) for the auditfile gate and the close checks.
- [VAT return review pack](../vat-return/review-pack.md) for the shared pack shape.
- [Fixed assets](../fixed-assets.md) for the asset register and the depreciation schedule.
- [Moneybird bookkeeping](../moneybird-bookkeeping.md) for the cadence and the reconciliation.
- [Dutch tax rules](../tax-rules/dutch-tax-rules.md) for the cross-year routing.
- [cli-moneybird](../../../cli-moneybird/SKILL.md) for the guarded reads.
