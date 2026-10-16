---
title: Income tax return preparation procedure
description: The ordered cross-year procedure to prepare one Dutch sole-trader income tax return from Moneybird for Operator review. Steps 1 to 12 with their owner tags, the source map, the evidence gates, the review pack differences, the stop rules and the residual risk list.
nav_label: "Income tax return preparation procedure"
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
| 7 | Collect the dated per-asset register and compute the investment deductions and any disinvestment addition (desinvesteringsbijtelling). | The per-asset floor, the Netherlands Enterprise Agency (RVO) notification window, the payment condition, the in-use condition and the disinvestment window are each checked against the register. | [The investment and claim register](investment-and-claim-register.md) with the RVO proof. | `[Operator + AI]` The agent computes from supplied facts, the Operator supplies the order, payment and RVO records. |
| 8 | Apply the entrepreneur's allowance (ondernemersaftrek) chain with the hours criterion (urencriterium) evidence, then the SME profit exemption (MKB-winstvrijstelling). | The entrepreneur for income tax purposes (IB-ondernemer) status, the hours criterion, the deduction order and the profit cap or carry-forward are checked. | The deduction chain with the hours evidence and the Operator attestation. | `[Operator + AI]` The agent computes, the Operator attests the hours and the starter history. |
| 9 | Assemble box 1 income, the box 3 reference date (peildatum) inventory and the partner facts from Operator input. | The reference date values are dated, no business asset is duplicated and the partner split totals the whole joint tax base (grondslag). | The VIA comparison sheet and the private-part input rows in [operator inputs](operator-inputs.md). | `[Operator + AI]` The agent prepares, the Operator supplies and confirms every private value. |
| 10 | Verify the figures against the evidence and run the checks. | Totals tie to evidence, every pack check has a status and only settled values are presented as settled. | The check result per pack block and the open-exception list. | `[Operator + AI]` The agent runs the checks, the Operator resolves or accepts an exception with a reason. |
| 11 | Hand over the review pack, the Operator input list and the VIA comparison sheet. | The pack holds every part the procedure requires and every prefilled field is listed against its source. | The pack in the private workspace and the comparison sheet. | `[AI]` |
| 12 | Record the confirmation and stop. | The confirmation record holds identity, role, decision, timestamp, pack version and path, return year, accepted exceptions and evidence references. | The confirmation record. | `[Operator]` The Operator reviews the pack, confirms it, files and pays in the product UI. |

The year rules behind steps 6 to 9 are in the year files, for example [Income tax 2026 figures](../tax-rules/2026/income-tax/figures.md), [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md), [Investments 2026 figures](../tax-rules/2026/investments/figures.md) and [Zvw 2026 figures](../tax-rules/2026/health-insurance-contribution/figures.md). Every rate and threshold changes by year, so read the file for the resolved `year_key`.

---

## 3. THE SOURCE MAP

One row per input on the official return checklist plus the business figures (cijfers) list. The evidence class is Moneybird, the books outside Moneybird, the year corpus or the Operator and the pre-filled tax return (vooraf ingevulde aangifte). A Moneybird row names what the guarded read shows. Every figure is a link into the year corpus and never copied here.

| Return part or figure | Where it comes from | Evidence class | Year file that owns the rule |
|---|---|---|---|
| Commercial result and profit and loss categories | Moneybird profit and loss statement (resultatenrekening) with its category reports | Moneybird | [The year README](../tax-rules/2026/README.md) |
| Balance-sheet lines | Moneybird balance sheet (balans) computed from all bookings, period-end figures | Moneybird | [The year README](../tax-rules/2026/README.md) |
| Asset book values and depreciation | Moneybird assets (bezittingen) and fixed asset register (activastaat) plus [fixed assets](../fixed-assets.md) | Moneybird | [Investments 2026 figures](../tax-rules/2026/investments/figures.md) |
| VAT position for the year | Moneybird VAT overview (btw-overzicht) plus the filed returns | Moneybird | [VAT 2026 figures](../tax-rules/2026/vat/figures.md) |
| Audit trail | The auditfile before the year-end closing (jaarafsluiting), the general ledger cards (grootboekkaarten) and the RGS bridging statement (RGS Brugstaat) | Moneybird | [Return and procedure 2026 figures](../tax-rules/2026/procedure/figures.md) |
| Commercial-to-fiscal adjustments | The books, the Operator facts and the year corpus | Books outside Moneybird, year corpus | [Dutch tax rules](../tax-rules/dutch-tax-rules.md) |
| Depreciation caps and building floor | [Fixed assets](../fixed-assets.md) plus the Operator WOZ decision (beschikking) | Year corpus, Operator | [Investments 2026 figures](../tax-rules/2026/investments/figures.md) and [Costs and car 2026 figures](../tax-rules/2026/costs-and-car/figures.md) |
| KIA, EIA, MIA and Vamil figures | The year file plus the per-asset register and the RVO proof | Year corpus, Operator | [Investments 2026 figures](../tax-rules/2026/investments/figures.md) |
| Disinvestment addition (desinvesteringsbijtelling) | The prior claims plus this year's disposals | Books outside Moneybird, Operator | [Investments 2026 figures](../tax-rules/2026/investments/figures.md) |
| Hours criterion (urencriterium) and hours | Moneybird hours (uren) registration plus the Operator hours log | Moneybird, Operator | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| Self-employed person's deduction (zelfstandigenaftrek) and starter's deduction (startersaftrek) | The year file plus the prior returns and decisions | Year corpus, Operator | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| Deduction for research and development work (aftrek speur- en ontwikkelingswerk) | The Operator R&D declaration (S&O verklaring) plus the year file | Operator | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| Deduction for assisting partner (meewerkaftrek) | The Operator partner hours and pay plus the year file | Operator | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| Starter's deduction for disabled entrepreneurs (startersaftrek bij arbeidsongeschiktheid) | The Operator decision (beschikking) plus the year file | Operator | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| Discontinuation deduction (stakingsaftrek) | The Operator cessation (staking) facts plus the year file | Operator | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| SME profit exemption (MKB-winstvrijstelling) | Computed after the entrepreneur's allowance | Year corpus | [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) |
| Old-age reserve (oudedagsreserve) opening and movements | The Operator prior return plus the annuity evidence | Operator | [Pension and disability insurance 2026 figures](../tax-rules/2026/pension-and-disability-insurance/figures.md) |
| Private-use car, phone and home | The Operator facts and evidence plus the year file | Operator | [Costs and car 2026 figures](../tax-rules/2026/costs-and-car/figures.md) |
| Box 1 income, wage (loon) and other income | The Operator, the annual statements (jaaropgaven) and the pre-filled tax return | Operator, pre-filled tax return | [Income tax 2026 figures](../tax-rules/2026/income-tax/figures.md) |
| Box 3 inventory and reference date (peildatum) | The Operator and the pre-filled tax return | Operator, pre-filled tax return | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Partner data and allocation | The Operator and the pre-filled tax return | Operator, pre-filled tax return | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Personal, partner and children details | The Operator, DigiD and the pre-filled tax return | Operator, pre-filled tax return | [The year README](../tax-rules/2026/README.md) |
| Children's bank data | The Operator and the pre-filled tax return | Operator, pre-filled tax return | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Received and paid spousal maintenance (partneralimentatie) | The Operator and the pre-filled tax return | Operator, pre-filled tax return | [Income tax 2026 figures](../tax-rules/2026/income-tax/figures.md) |
| Crypto holdings | The Operator and the pre-filled tax return | Operator, pre-filled tax return | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Home and mortgage interest (hypotheekrente) | The Operator with the WOZ decision, the annual mortgage statement (hypotheek jaaropgaaf) and the notary statement | Operator | [Income tax 2026 figures](../tax-rules/2026/income-tax/figures.md) |
| Gifts and care costs | The Operator proofs of payment (betalingsbewijzen) | Operator | [Income tax 2026 figures](../tax-rules/2026/income-tax/figures.md) |
| Annuity premiums and disability insurance (AOV) | The Operator annual statement (jaaropgaaf) and premium statements | Operator | [Pension and disability insurance 2026 figures](../tax-rules/2026/pension-and-disability-insurance/figures.md) |
| Dividend | The Operator dividend statements | Operator | [Box 3 2026 figures](../tax-rules/2026/box-3/figures.md) |
| Provisional assessments (voorlopige aanslagen) for income tax and Zvw | The Operator and the Dutch Tax and Customs Administration (Belastingdienst) decisions | Operator | [Return and procedure 2026 figures](../tax-rules/2026/procedure/figures.md) and [Zvw 2026 figures](../tax-rules/2026/health-insurance-contribution/figures.md) |
| Rates, thresholds and rules | The year corpus, the year README first and then the topic KEY FIGURES section | Year corpus | [The year README](../tax-rules/2026/README.md) |
| Deadlines, deferral (uitstel) and aftercare | The year procedure file | Year corpus | [Return and procedure 2026 figures](../tax-rules/2026/procedure/figures.md) |
| Filing, payment and period lock | Operator only, behind DigiD and the product UI | Operator | [Return and procedure 2026 figures](../tax-rules/2026/procedure/figures.md) |

A year file citation whose index row is `pdf-needs-reader` is read through [section 2 of the source library guide](../tax-rules/source-library.md#2-how-to-reach-a-source), and its text backs the year file's value without replacing it.

Two product points stay unverified and are never a computation basis. Whether Moneybird automates the investment deduction (investeringsaftrek) or holds a fiscal-basis or investment-claim field is unverified, so the fixed asset register (activastaat) stays supporting evidence until a product check settles it. A historical open-creditors list with per-invoice detail is also unverified, so the balance check does not rely on that report alone.

---

## 4. EVIDENCE GATES

Run the gates in this order. A gate that fails leaves the pack in the open state and blocks the hand-off.

1. **Auditfile first.** Export the auditfile before any closing action. The export is the evidence gate for everything below it, because a year-end closing (jaarafsluiting) before the export can strip the profit and loss data from the auditfile. The route and the gate are in [the auditfile-first gate](../yearly-overview/preparation-checklist.md#2-auditfile-first). `[Operator + AI]`
2. **Report window and rate limit.** Every report covers the return year only and each request stays inside the guarded window and rate limit named in [cli-moneybird](../../../cli-moneybird/SKILL.md). `[AI]`
3. **Opening and closing continuity.** Opening balances plus movements equal the closing balance and the asset register reconciles to the business balance. `[AI]`
4. **Bridge completeness.** Walk the adjustment-domain list of the year corpus, not the adjustments someone remembers, and mark each row as reflected in the books or added in the calculation. `[Operator + AI]`
5. **Register conditions.** Check the per-asset floor, the RVO notification window, the payment condition, the in-use condition and the disinvestment window against [the register](investment-and-claim-register.md). `[Operator + AI]`
6. **Hours plausibility.** Check that the hours log is complete, that standby is excluded, that the hours criterion (urencriterium) is not prorated and that the exceptions the year file names are applied. `[Operator + AI]`
7. **Deduction order and cap.** Check that the SME profit exemption (MKB-winstvrijstelling) follows the entrepreneur's allowance (ondernemersaftrek), that the self-employed person's deduction (zelfstandigenaftrek) is capped at the profit unless the starters exception applies, and that the benefit cap and the reserve triggers are walked. `[Operator + AI]`
8. **Box 3 reference date and duplication.** Check the reference date (peildatum) values, the anti-arbitrage window and that no business asset appears in both the balance and the box 3 inventory. `[Operator + AI]`
9. **VIA comparison and value status.** Compare every prefilled field with its source, present only settled values as settled and label every other value with its settling source. `[Operator + AI]`
10. **Privacy.** No amounts, identifiers, names or private records appear in chat, a summary or a skill file. `[AI]`

The figures each gate reads are in the year files, for example [Return and procedure 2026 figures](../tax-rules/2026/procedure/figures.md) for the report window and [Entrepreneur's allowance 2026 figures](../tax-rules/2026/business-deductions/figures.md) for the deduction chain.

---

## 5. THE REVIEW PACK

The pack shape is the one in [the VAT return review pack](../vat-return/review-pack.md). The nine blocks `P1` to `P9`, the three confirmation parts `C1` to `C3` and the escalation list carry over. What differs for this return:

- The pack is ordered like the Dutch Tax and Customs Administration (Belastingdienst) return parts, namely profits from business activities (winst uit onderneming), box 1, box 3 and the partner, rather than Domestic (Binnenland), Foreign (Buitenland) and Input VAT (Voorbelasting).
- `P3` holds the fiscal bridge schedule instead of a VAT section (rubriek) table, with one row per commercial-to-fiscal adjustment and its source.
- An extra block carries the deduction chain from the profit to the taxable profit from business (belastbare winst uit onderneming) and the per-asset register from [the register](investment-and-claim-register.md).
- An extra block carries the VIA comparison sheet, one line per prefilled field with its source and its correction.
- `C2` covers the filing route for the income tax return behind DigiD. `C3` covers the payment or receipt of the assessment. Both stay with the Operator.
- A block carries the rows from [risks and open points](risks-and-open-points.md) with their unresolved label.

Everything else, including the escalation list and the prepared-not-filed stop, stays as the linked pack defines it.

---

## 6. STOP RULES

Stop and record the item when any of these remain open:

- An auditfile that does not exist for the resolved year before the year-end closing (jaarafsluiting).
- An unmatched or undispositioned bank transaction or incoming document.
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
- The derived starters' arbitrary depreciation (willekeurige afschrijving) cap.
- The undated work space (werkruimte) publication.
- The mass objection (massaal-bezwaar) decision date.
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
