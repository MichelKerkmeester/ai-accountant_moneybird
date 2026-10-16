---
title: Booking mixed-use costs in Moneybird
description: How to book a cost used partly for business and partly privately in Moneybird, with the income tax share, the VAT share, the evidence and the booking split.
nav_label: "Booking mixed-use costs in Moneybird"
trigger_phrases:
  - book a phone subscription partly private
  - telefoonabonnement zakelijk en prive boeken
  - gemengde kosten boeken
  - mixed-use cost Moneybird
  - private use of a business cost
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Booking mixed-use costs in Moneybird

**Rule:** Product behaviour below is per Moneybird help reviewed on 2026-10-13. Tax rules are per the Dutch Tax and Customs Administration (Belastingdienst) pages, the Income Tax Act 2001 (Wet IB 2001) text and the Handbook for Entrepreneurs (Handboek Ondernemen) 2026, fetched on 2026-10-13 and linked in each section. Take every year amount, including the VAT rates, from that year's `costs-and-car.md` and `vat.md`. The mixed-cost threshold there does not apply to a phone or internet cost. A changed business share, a home in business assets (bedrijfsmiddelen) or a disputed estimate goes to the Operator or a bookkeeper.

---

## 1. OVERVIEW

This reference explains how a cost used partly for the business and partly privately becomes a booked cost in Moneybird. The lead case is a mobile phone subscription, followed by a home internet connection, a phone or laptop handset and the fixed telephone line in the own home. The private part is not a business cost, and it is a private withdrawal (privéonttrekking) on an equity category when the business account paid the invoice. [Moneybird bookkeeping](./moneybird-bookkeeping.md)

Every Moneybird read or write runs through moneybird-guard, following [cli-moneybird](../../cli-moneybird/SKILL.md).

### Tool route

1. **Knowledge.** Read this reference and the year of the booking. The year's `costs-and-car.md` holds the mixed-cost rule, the home telephone subscription (telefoonabonnement thuis) rule and the art. 3.15 threshold for food, drink, representation and conferences, and its `vat.md` holds the rates, the private-use settlement and the small businesses scheme (kleineondernemersregeling, KOR). [Costs and car 2026](tax-rules/2026/costs-and-car/figures.md), [VAT 2026](tax-rules/2026/vat/figures.md)
2. **Guarded read.** Read the purchase VAT rates with `tax_rates list` under `MONEYBIRD_GUARD_READ_ONLY=1`, as [cli-moneybird](../../cli-moneybird/SKILL.md) section 2 states.
3. **Gated write.** Book through the row "Purchase invoice and attachment" in that same section, only where the LIVE write authority in `SKILL.md` allows it. Otherwise the Operator books in the Moneybird UI. [cli-moneybird](../../cli-moneybird/SKILL.md)

---

## 2. DECISION TABLE

| Case | Income tax (inkomstenbelasting) | VAT | Booking |
|---|---|---|---|
| Mobile subscription, mixed | Business part only | Business part of the input VAT (voorbelasting) only | Split the document, private part to the private category |
| Home internet, mixed | Business part only | As above | Same split |
| Fixed home telephone line | Subscription 0 percent, business calls 100 percent | VAT on the estimated business share, as section 4 states | Book the business call charges only |
| Phone or laptop handset, mixed | Labelling (etikettering): 10 percent or less business is compulsory private assets (verplicht privévermogen), 90 percent or more is mandatory business assets (verplicht ondernemingsvermogen), between is freely classifiable assets (keuzevermogen). Private assets give 0 percent, business assets are depreciated in full | VAT choice of section 4, so private, business or partly | Section 9, `fixed-assets.md` |
| Small businesses scheme (kleineondernemersregeling) participant | Business part only, including its VAT, because private costs are not deductible (niet aftrekbaar) and the input VAT may not be deducted ([which business costs may I deduct](https://www.belastingdienst.nl/wps/wcm/connect/nl/werk-en-inkomen/content/welke-kosten-mag-ik-aftrekken-van-mijn-bijverdiensten)), as [Costs and car 2026](tax-rules/2026/costs-and-car/figures.md) section 32 states | No input VAT | No VAT split, private part still to the private category |
| Only exempt turnover (vrijgestelde omzet) | Business part only | No input VAT for either part | No VAT split |

Sources: [business or private](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/zakelijk_of_prive), [overview of deductible business costs](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/overzicht-mogelijk-aftrekbare-zakelijke-kosten), [which VAT may you deduct](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/welke_btw_is_aftrekbaar/welke_btw_mag_u_aftrekken), [what joining the KOR means](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/hoe_werkt_de_btw/kleineondernemersregeling/wat-betekent-meedoen-met-de-kleineondernemersregeling/), [mixed use of investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/investeringsgoederen).

---

## 3. THE INCOME TAX (inkomstenbelasting) RULE

A mixed cost has a business and a personal character. Only the business part is deductible and a dominant personal character blocks deduction entirely. Telephone costs (telefoonkosten) are named among the costs of which only the business part is deductible. [business or private](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/zakelijk_of_prive)

A private telephone subscription is not deductible (niet aftrekbaar), but the business calls made through it are. A business telephone subscription is deductible, but call costs for private use (privégebruik) are not. [which business costs may I deduct](https://www.belastingdienst.nl/wps/wcm/connect/nl/werk-en-inkomen/content/welke-kosten-mag-ik-aftrekken-van-mijn-bijverdiensten)

For a connection in the taxpayer's own home the law adds a fixed exclusion. Costs of telephone subscriptions (telefoonabonnementen) for telephone connections in his residential accommodation (woonruimte) do not reduce profit under art. 3.16 lid 2 onderdeel a Wet IB 2001. [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01) The year's overview table puts the home telephone subscription at 0 percent and business calls at home (zakelijke telefoongesprekken thuis) at 100 percent. [overview of deductible costs](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/overzicht-mogelijk-aftrekbare-zakelijke-kosten)

The exclusion covers a telephone connection in the taxpayer's own residential accommodation only, so a mobile subscription stays under the general mixed-cost rule. [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01), [business or private](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/zakelijk_of_prive)

The business share must be made plausible. The administration must be complete and checkable, the entrepreneur must be able to show that the costs were really incurred for the work and the administration separates fully deductible costs (aftrekbare kosten), costs with a threshold and costs that are not deductible. [setting up an administration](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/een_administratie_opzetten), [which business costs may I deduct](https://www.belastingdienst.nl/wps/wcm/connect/nl/werk-en-inkomen/content/welke-kosten-mag-ik-aftrekken-van-mijn-bijverdiensten), [Handboek Ondernemen 2026](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf) section 5.2

The private use is estimated as accurately as possible, the standard the Dutch Tax and Customs Administration (Belastingdienst) states for the VAT estimate. [goods and services that are not investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/overige_roerende_goederen_en_diensten/overige_roerende_goederen_en_diensten) No fetched page prescribes a method, so the Operator or a bookkeeper chooses it (section 12).

---

## 4. THE VAT RULE

VAT is deductible as input VAT (voorbelasting) when the purchase serves taxed turnover (belaste omzet), including 0 percent and turnover with the VAT shifted to the customer. Exempt turnover (vrijgestelde omzet) gives no deduction. [which VAT may you deduct](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/welke_btw_is_aftrekbaar/welke_btw_mag_u_aftrekken)

For mixed use there are three possibilities. No VAT is deducted, none is deducted for the private part or the VAT is deducted in full with the private use (privégebruik) settled at year end. The kind of good or service decides. [mixed use](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/gemengd_gebruik)

**A service or a non-investment good.** A phone subscription and internet fall here. If the good or service is not put into use in the same VAT period, estimate the private use as accurately as possible at purchase and do not deduct the VAT on that part. When a purchase estimate was made, determine the actual private use in the VAT period of first use and correct the earlier deduction if it differs. When the good or service is put into use in the same VAT period, the deduction follows that first use directly. Then reassess at year end over the whole year of first use and correct the deduction if the year's use differs, after which the deduction is definitive. [goods and services that are not investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/overige_roerende_goederen_en_diensten/overige_roerende_goederen_en_diensten) The handbook adds that only the input VAT attributable to the business use may be deducted. [Handboek Ondernemen 2026](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf) section 5.4.1

**A good used for mixed purposes.** A phone or laptop that lasts more than one year falls under asset classification (vermogensetikettering) for income tax (inkomstenbelasting, section 9) and is a capital good (investeringsgoed) for the VAT when the business depreciates it. For VAT purposes, choose separately for each good whether it is private, business or partly private and partly business, and record the choice in the administration. For movable property (roerende zaken) placed in business assets (bedrijfsmiddelen) the purchase VAT is deducted in full when all turnover is taxed with VAT, and only for the taxed share when there is also exempt turnover, and the VAT on the private use is declared in the last return of the year. Placed partly in business assets, only the VAT on the business part is deducted. For movable property the revision period is the year of first use plus the 4 following years, 5 in total, and for immovable property (onroerende zaak) the year of first use plus the 9 following years, 10 in total. A revision is due only when the percentage of the use for taxed turnover differs from that percentage in the year of first use by more than 10 percent of the first-use percentage. [mixed use of investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/investeringsgoederen), [private use of movable investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/roerende_investeringsgoederen/roerende_investeringsgoederen), [revision of the VAT deduction](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/belaste_en_vrijgestelde_omzet/inschatting_van_het_gebruik2/herziening_aftrek_bij_investeringsgoederen2/herziening_aftrek_bij_investeringsgoederen), [Handboek Ondernemen 2026](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf) section 5.4.1

- When the revision follows entry into or exit from the small businesses scheme (kleineondernemersregeling, KOR) it lapses for a good taken into use in an earlier book year, when the total in the year is below the amount the page states and never in the year of first use. [revision of the VAT deduction](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/belaste_en_vrijgestelde_omzet/inschatting_van_het_gebruik2/herziening_aftrek_bij_investeringsgoederen2)
- A business with only exempt turnover deducts no VAT for either part, and a small businesses scheme participant deducts no input VAT on business costs (bedrijfskosten) and investments. [mixed use of investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/investeringsgoederen), [what joining the KOR means](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/hoe_werkt_de_btw/kleineondernemersregeling/wat-betekent-meedoen-met-de-kleineondernemersregeling/)

Private use is settled in the last VAT return (btw-aangifte) of the year when a VAT return is filed. A small businesses scheme participant files no return and deducts no input VAT, so there is nothing to settle. [VAT 2026](tax-rules/2026/vat/figures.md), [mixed use](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/gemengd_gebruik)

The rate on each line is the rate the invoice prints, taken from the year's `vat.md`, as the [purchase invoice reference](./purchase-invoices.md) states.

---

## 5. THE BOOKING STEPS IN MONEYBIRD

1. **Add and process the document.** Follow [purchase invoices](./purchase-invoices.md) section 4, with type Purchase invoice (Soort Inkoopfactuur) for an invoice and type Receipt (Soort Bon) for a receipt. [process purchase invoices and receipts](https://helpcenter.moneybird.nl/nl/articles/207134-verwerk-inkoopfacturen-en-bonnen)
2. **Set the private split.** Open the document, edit the invoice lines (factuurregels), tick 'Includes private use (Bevat privégebruik)' and fill the field 'Percentage' in the block 'Allocate private use (Privégebruik verdelen)'. The percentage applies to the total including VAT, and a decimal percentage is allowed. [split private costs automatically](https://helpcenter.moneybird.nl/nl/articles/639653-prive-kosten-automatisch-verdelen)
3. **Choose the destination.** Under 'Select by (Selecteren op)' choose 'Account (Rekening)' or 'Category (Categorie)'. With Account you pick a 'Private account (Privérekening)', with Category a 'Private category (Privécategorie)' from the categories of the type 'Own equity (Eigen vermogen)'. The totals show a separate line per private account or category, and after processing the summary shows a row 'Private (Privé)' with a label such as '40% of telephone costs (40% van Telefoonkosten)'. With several cost categories, use 'Add category (Categorie toevoegen)' per category. [split private costs automatically](https://helpcenter.moneybird.nl/nl/articles/639653-prive-kosten-automatisch-verdelen)
4. **The manual alternative or a reverse-charged line.** Moneybird also describes splitting the invoice into two lines, the private line on 'Withdrawals (Onttrekkingen)' at 'No VAT (Geen btw)' and the business line on the cost category with its VAT rate (btw-tarief). [process private payments](https://helpcenter.moneybird.nl/nl/articles/207323-prive-betalingen-verwerken) A line with reverse-charged VAT (verlegde btw) cannot take the private split and goes through a journal entry (memoriaalboeking). [split private costs automatically](https://helpcenter.moneybird.nl/nl/articles/639653-prive-kosten-automatisch-verdelen), [private use of business products or services](https://helpcenter.moneybird.nl/nl/articles/207324-privegebruik-van-zakelijke-producten-of-diensten-voor-eenmanszaken)
5. **The private account and a private payment.** Create a 'Private withdrawals and deposits (Privé-opnames/stortingen)' account under 'Settings > Bank > Accounts (Instellingen > Bank > Rekeningen)'. For a sole trader Moneybird creates 'Private capital (Privé (kapitaal))', 'Withdrawals' and 'Deposits (Stortingen)'. [which private category](https://helpcenter.moneybird.nl/nl/articles/207326-wanneer-welke-categorie-prive-opnames-stortingen) The private share goes to a category such as 'Withdrawals'. When the document was paid privately, choose 'Payment > Register payment (Betaling > Registreer betaling)' and then 'Privately by (Privé door)'. [private use of business products or services](https://helpcenter.moneybird.nl/nl/articles/207324-privegebruik-van-zakelijke-producten-of-diensten-voor-eenmanszaken), [business and private](https://helpcenter.moneybird.nl/nl/articles/207322-zakelijk-en-prive)
6. **The correction route and the lists.** For a later correction, add the rate 'Private use (Privé-gebruik)' under 'Settings > Bookkeeping > VAT rates > Add (Instellingen > Boekhouding > Btw-tarieven > Toevoegen)' under 'Journal entry (Memoriaal)' and the category 'VAT private use (Btw privégebruik)' under 'Settings > Bookkeeping > Categories > Add > Commonly used categories (Instellingen > Boekhouding > Categorieën > Toevoegen > Veelgebruikte categorieën)'. The journal entry puts the VAT in rubriek 1d. The rate overview shows the section each rate reports in, and tax-rate creation is a UI action. [private use of business products or services](https://helpcenter.moneybird.nl/nl/articles/207324-privegebruik-van-zakelijke-producten-of-diensten-voor-eenmanszaken), [add a category](https://helpcenter.moneybird.nl/nl/articles/207276-categorie-toevoegen), [VAT rates](https://helpcenter.moneybird.nl/nl/articles/223671-btw-tarieven-in-moneybird), [cli-moneybird](../../cli-moneybird/SKILL.md)

---

## 6. CASE A: A MOBILE PHONE SUBSCRIPTION

1. Establish the business share from the records and record the basis (section 3), then process the invoice as section 5 describes.
2. The business share of the VAT goes into rubriek 5b with the ordinary return and the private share is not deducted. [Purchase invoices](./purchase-invoices.md) rubriek 3, [OB 141](https://download.belastingdienst.nl/belastingdienst/docs/toelichting_aangifte_omzetbelasting_ondernemers_ob1411t01fdbui.pdf)
3. At year end, check the recorded percentages against the use and settle the private use (privégebruik) in the last return. Under the small businesses scheme (kleineondernemersregeling, KOR) there is no return and no settlement. [VAT 2026](tax-rules/2026/vat/figures.md)

See example 1 in section 10.

---

## 7. CASE B: A HOME INTERNET CONNECTION

A home internet connection is also used for the business and private life. It is not a telephone subscription for a connection in the residential accommodation (woonruimte) and not on the art. 3.16 lid 2 list, so the general mixed-cost rule applies and the business part is deductible. [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01)

The booking is the same split as case A. A doubtful case goes to the Operator or a bookkeeper (section 12). See example 2 in section 10.

---

## 8. CASE C: THE FIXED TELEPHONE LINE IN THE OWN HOME

The subscription is 0 percent deductible, the business calls through it are 100 percent deductible and the fixed exclusion is art. 3.16 lid 2 onderdeel a Wet IB 2001. [overview of deductible costs](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/overzicht-mogelijk-aftrekbare-zakelijke-kosten), [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01)

Book only the business part of the call charges and not the subscription, and keep the receipts and invoices so the business calls can be shown. [which business costs may I deduct](https://www.belastingdienst.nl/wps/wcm/connect/nl/werk-en-inkomen/content/welke-kosten-mag-ik-aftrekken-van-mijn-bijverdiensten) The VAT follows section 4. How to isolate the business calls is a judgement call for the Operator or a bookkeeper (section 12).

---

## 9. CASE D: A PHONE OR LAPTOP BOUGHT FOR MIXED USE

A phone or laptop used for both business and private purposes falls under asset classification (vermogensetikettering) and is not automatically in the business assets (ondernemingsvermogen). At 10 percent business use or less it is compulsory private assets (verplicht privévermogen), at 90 percent or more it is mandatory business assets (verplicht ondernemingsvermogen), in between it is freely classifiable assets (keuzevermogen), the entrepreneur's choice within reasonable bounds. [vermogensetikettering](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/vermogensetikettering-bedrijfsmiddel), [Costs and car 2026](tax-rules/2026/costs-and-car/figures.md) section 27

A device in the business assets is depreciated in full and the costs of its private use (privégebruik) are a private withdrawal (privéonttrekking). A device in the private assets (privévermogen) is not depreciated and the costs connected with it are 0 percent deductible under art. 3.16 lid 3 Wet IB 2001. [vermogensetikettering](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/vermogensetikettering-bedrijfsmiddel), [overview of deductible business costs](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/overzicht-mogelijk-aftrekbare-zakelijke-kosten), [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01)

The booking and the 450 rule are in [fixed assets](./fixed-assets.md), which covers the labelling, the depreciation and the VAT revision.

---

## 10. CALCULATED EXAMPLES

The figures are invented. Both use a Dutch invoice with 21 percent VAT, the rate in [VAT 2026](tax-rules/2026/vat/figures.md) and a sole trader with only taxed turnover (belaste omzet).

### Example 1: a mobile subscription with 60 percent business use

The invoice: 500 excluding VAT, VAT 105, total 605.

1. Business share 60 percent: cost 300 and VAT 63. Private share 40 percent: cost 200 and VAT 42.
2. In Moneybird, set the field 'Amounts and VAT rates (Bedragen en btw-tarieven)' to excluding VAT (exclusief btw). One line: amount 500, rate 21 percent, the telephone costs (telefoonkosten) category. Tick 'Includes private use (Bevat privégebruik)', fill Percentage 40 and choose 'Account (Rekening)' with the 'Private withdrawals and deposits (Privé-opnames/stortingen)' account.
3. The summary shows the business cost 300 with input VAT (voorbelasting) 63 and a 'Private (Privé)' row of 242 on the private account.
4. Result: 300 cost in the profit and loss account (winst- en verliesrekening), 63 input VAT in rubriek 5b and 242 private withdrawal (privéonttrekking). The 42 VAT inside the private part is not deducted.
5. The manual equivalent: line 1 of 300 at 21 percent on the cost category, line 2 of 242 at 'No VAT (Geen btw)' on 'Withdrawals (Onttrekkingen)'. [process private payments](https://helpcenter.moneybird.nl/nl/articles/207323-prive-betalingen-verwerken)

### Example 2: a home internet connection with 50 percent business use

The invoice: 200 excluding VAT, VAT 42, total 242.

1. Business share 50 percent: cost 100 and VAT 21. Private share 50 percent: cost 100 and VAT 21.
2. In Moneybird, set the field 'Amounts and VAT rates (Bedragen en btw-tarieven)' to excluding VAT. One line: amount 200, rate 21 percent, the internet category. Tick 'Includes private use (Bevat privégebruik)', fill Percentage 50 and choose the 'Withdrawals (Onttrekkingen)' category.
3. Result: 100 cost in the profit and loss account, 21 input VAT in rubriek 5b and 121 private withdrawal.

---

## 11. CHECKS AFTER BOOKING

1. The status is Outstanding (Openstaand) or paid, not New (Nieuw), and the document total equals the invoice total. [Purchase invoices](./purchase-invoices.md)
2. Every line carries the VAT rate (btw-tarief) the invoice prints, taken from the year's `vat.md`. [Purchase invoices](./purchase-invoices.md)
3. The business share and the private share add up to the invoice total.
4. The private share sits on an equity category, not on a cost category. [which private category](https://helpcenter.moneybird.nl/nl/articles/207326-wanneer-welke-categorie-prive-opnames-stortingen)
5. For a subscription the business share of the VAT is in rubriek 5b. For a good the VAT follows the choice in rubriek 4, so with business assets (bedrijfsmiddelen) the VAT is in rubriek 5b in full when all turnover is taxed with VAT, and only for the taxed share when there is also exempt turnover (vrijgestelde omzet), and the private use (privégebruik) is settled in the last return of the year. [Purchase invoices](./purchase-invoices.md) rubriek 3
6. The 'Private split off (Privé afgesplitst)' column in the category report shows the percentages, through 'Reports > Profit and loss statement (Rapporten > Resultatenrekening)'. [split private costs automatically](https://helpcenter.moneybird.nl/nl/articles/639653-prive-kosten-automatisch-verdelen)
7. In the last return of the year the private use is settled, unless the business takes part in the small businesses scheme (kleineondernemersregeling, KOR) and files no return. The Operator reviews and files the return. [VAT 2026](tax-rules/2026/vat/figures.md)

---

## 12. OPEN POINTS

- **Method for the income tax (inkomstenbelasting) business share.** No fetched page prescribes an itemised bill, a sample period or another method. The administration must support the share, so the Operator or a bookkeeper chooses and defends the method. [setting up an administration](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/een_administratie_opzetten)
- **Home internet.** The connection is not named in art. 3.16 lid 2 or in the year's overview table. This reference applies the general mixed-cost rule, and a doubtful case goes to the Operator or a bookkeeper. [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01)
- **Business call charges at home.** No fetched page describes how to separate the business calls from the bill, so that is a judgement call for the Operator or a bookkeeper.
- **The administration's own lists.** Rate and category names can differ, so read them through the guarded read route first. [cli-moneybird](../../cli-moneybird/SKILL.md)
- **A changed business share inside the revision period of a good.** That case goes to the Operator or a bookkeeper. [mixed use of investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/investeringsgoederen)
- **Reverse charge with a private part.** Moneybird supports that only through a journal entry (memoriaalboeking). [private use of business products or services](https://helpcenter.moneybird.nl/nl/articles/207324-privegebruik-van-zakelijke-producten-of-diensten-voor-eenmanszaken)

---

## 13. RELATED RESOURCES

- [Purchase invoices](./purchase-invoices.md) explains the document flow and the VAT choice for each invoice kind.
- [Moneybird bookkeeping](./moneybird-bookkeeping.md) covers categories, private withdrawals, assets and bank matching.
- [Fixed assets](./fixed-assets.md) covers the labelling, the 450 threshold, depreciation and the revision period.
- [Costs and car 2026](tax-rules/2026/costs-and-car/figures.md) holds the 2026 mixed-cost and home telephone subscription rules.
- [VAT 2026](tax-rules/2026/vat/figures.md) holds the 2026 rates, the private-use settlement and the small businesses scheme (kleineondernemersregeling).
- [cli-moneybird](../../cli-moneybird/SKILL.md) owns the guarded reads and writes for purchase invoices, receipts and tax rates.
