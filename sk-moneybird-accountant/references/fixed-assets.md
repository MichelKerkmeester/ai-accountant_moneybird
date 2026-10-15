---
title: Fixed assets and depreciation in Moneybird
description: When a business purchase is an asset that is depreciated, how depreciation and the yearly limits work, VAT on an asset and the revision period, disposal and the Moneybird asset screens, for a Dutch sole trader.
nav_label: "Fixed assets and depreciation in Moneybird"
trigger_phrases:
  - inventaris afschrijven
  - bedrijfsmiddel boeken
  - laptop afschrijven
  - asset toevoegen Moneybird
  - restwaarde en levensduur
  - desinvestering
  - herzieningsperiode btw
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Fixed assets and depreciation in Moneybird

**Rule:** Product behaviour below is per Moneybird help reviewed on 2026-10-13. Tax rules are per the Belastingdienst pages linked in each section. The investment deduction figures are in the year's `investments.md`. A building, a private asset moved into the business, an unusual useful life or a change in use inside the revision period goes to the Operator or a bookkeeper.

---

## 1. OVERVIEW

This reference answers when a business purchase is a cost and when it is a depreciated bedrijfsmiddel (asset). It covers the small-amount rule, the depreciation base and yearly limits, the investment deductions, VAT and the revision period, disposal and the Moneybird asset screens.

Rules and figures change by year, so read the year's `investments.md` and `vat.md`. The bodemwaarde for buildings is the WOZ-waarde since 2024, with the pre-2024 exception in section 4.

Every Moneybird read or write runs through moneybird-guard, following [cli-moneybird](../../cli-moneybird/SKILL.md). A write needs a passed gate and Operator approval.

### Tool route

1. **Knowledge.** Read this reference and the year's `investments.md` and `vat.md`. [Investeringen 2026](./tax-rules/2026/investments/figures.md), [BTW 2026](./tax-rules/2026/vat/figures.md)
2. **Guarded read.** Read the administration's categories and assets through [cli-moneybird](../../cli-moneybird/SKILL.md) section 2 under `MONEYBIRD_GUARD_READ_ONLY=1`.
3. **Gated write.** The Operator enters assets in the Moneybird UI under **Bezittingen**. A gated write through [cli-moneybird](../../cli-moneybird/SKILL.md) section 2 applies only where the LIVE write authority in [SKILL.md](../SKILL.md) allows it.

---

## 2. COST OR ASSET

A purchase is an asset when the business uses it for more than one year. The Belastingdienst calls these bedrijfsmiddelen and spreads their cost over the years of use, for example machines, gereedschappen and inventaris. [What is depreciation](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/), [Costs spread over years](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/kosten_die_u_gespreid_over_een_aantal_jaren_moet_aftrekken)

A good that lasts more than one year but costs less than 450 per item may be expensed at once. The Belastingdienst rule is that low-value goods cost less than 450, excluding VAT when deductible and including VAT when not. [One year](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/kosten_die_u_in_1_jaar_mag_aftrekken). The Handboek adds that such a bedrijfsmiddel need not be depreciated. [Handboek 7.2.1](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf). The statute writes voorwerpen van geringe waarde off at once. [Wet IB 2001, art. 3.30 lid 4](https://wetten.overheid.nl/BWBR0011353/2026-01-01)

Several small purchases can form one asset, such as a computer of 350, a screen of 150, a mouse of 15 and a keyboard of 25, together 540. [Investing](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeren_in_bedrijfsmiddelen)

Moneybird's activation threshold is 450 excluding VAT. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)

---

## 3. DECISION TABLE

| Situation | Treatment | Moneybird entry |
|---|---|---|
| More than one year of use, 450 or more excluding VAT or including VAT when not deductible, per item | Depreciate over the life [art. 3.30](https://wetten.overheid.nl/BWBR0011353/2026-01-01), [One year](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/kosten_die_u_in_1_jaar_mag_aftrekken) | A **Bezitting** with aanschafwaarde, datum ingebruikname, gebruiksduur and restwaarde |
| More than one year of use, under 450 excluding VAT or under 450 including VAT when not deductible, per item | Expense in the purchase year [One year](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/kosten_die_u_in_1_jaar_mag_aftrekken) | A purchase invoice line on a cost category, no bezitting |
| Small goods that together form one asset of 450 or more | One asset [Investing](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeren_in_bedrijfsmiddelen) | One bezitting for the combined value |
| Goodwill or another immaterieel bedrijfsmiddel | An asset under art. 3.30 lid 2 [art. 3.30](https://wetten.overheid.nl/BWBR0011353/2026-01-01) | A bezitting with a useful life |
| A building | Depreciate only above the bodemwaarde [art. 3.30a](https://wetten.overheid.nl/BWBR0011353/2026-01-01) | Not automated, Operator adds entries |
| Used partly privately | Etikettering: 10 percent or less business is verplicht privévermogen, 90 percent or more is verplicht ondernemingsvermogen, between is keuzevermogen. Privévermogen gives 0 percent, ondernemingsvermogen is depreciated in full and the private use is a privéonttrekking | Section 9, [Mixed-use costs](./mixed-use-costs.md) |
| Already in use before the Moneybird start, or moved in from private use | Opening data or Operator value decision [Existing assets](https://helpcenter.moneybird.nl/nl/articles/223936-bestaande-vaste-activa-overzetten-naar-bezittingen) | The existing asset path in section 7 |

---

## 4. DEPRECIATION

The depreciation base is the aanschafkosten minus the restwaarde. The aanschafkosten are the aanschafprijs plus aankoopkosten such as notariskosten and installation, minus kortingen and subsidies, also when these arrive later. [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving), [Investing](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeren_in_bedrijfsmiddelen)

The restwaarde is the estimated value at the end of use and the gebruiksduur the technical life or, if shorter, the economic life. [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving)

The lineaire method writes `(aanschafkosten - restwaarde) : gebruiksduur` off each year. [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving)

The yearly write-off is at most 20% of the aanschaf- or voortbrengingskosten for other bedrijfsmiddelen and at most 10% for goodwill. [Wet IB 2001, art. 3.30 lid 2](https://wetten.overheid.nl/BWBR0011353/2026-01-01)

For a building, depreciation is allowed only while the boekwaarde is above the bodemwaarde and is at most the difference. The bodemwaarde is the WOZ-waarde of the building, except for an own-use building taken into use before 1 January 2024 and not yet depreciated for 3 years, which keeps the 50 percent floor until 3 years after first use. [Art. 3.30a](https://wetten.overheid.nl/BWBR0011353/2026-01-01), [Bedrijfspand](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/afschrijving_bedrijfspand) The Operator takes the WOZ-waarde from the beschikking, so no floor is computed here, and Moneybird does not depreciate bedrijfsgebouwen automatically. [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven)

Depreciation follows the use and starts when the asset is taken into use. The first year counts only the part of the year in use, so an April start gives nine months. [Costs spread over years](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/kosten_die_u_gespreid_over_een_aantal_jaren_moet_aftrekken), [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving)

An asset not yet in use at year end is an Operator case. The willekeurige afschrijving page allows, for that scheme, write-off up to the amount paid in the investment year. [Willekeurige afschrijving](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/willekeurige_afschrijving/)

---

## 5. INVESTMENT DEDUCTIONS AND DISPOSAL

- **The investeringsaftrek does not change the depreciation base.** It is deducted from the winst, not a purchase discount, so only kortingen and subsidies lower the aanschafkosten. [Handboek 7.2.2](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf), [Investing](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeren_in_bedrijfsmiddelen)
- **The year figures.** The KIA bands, the per-asset minimum and the desinvesteringsbijtelling threshold are in the year's [investments.md](./tax-rules/2026/investments/figures.md).
- **The claim register.** An investment allowance claim needs the dated per-asset register in [the investment and claim register](./income-tax-return/investment-and-claim-register.md), with the order date, the payment dates, the in-use date, the RVO reference and the prior aftrek per asset.
- **Desinvesteringsbijtelling.** A sale within five years after the start of the calendar year of the investment brings back a percentage of the earlier investeringsaftrek as profit, never more than the aftrek taken, and the transfer prices count toward the year threshold. [Desinvesteringsbijtelling](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeringsaftrek_en_desinvesteringsbijtelling/desinvesteringsbijtelling)
- **Boekwinst or boekverlies.** On a sale the difference between the sale price and the boekwaarde is winst or verlies. [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving)
- **Scrapping or loss.** Taking a business asset out of use does not change the VAT deduction. [Art. 14 Uitv.besch. OB](https://wetten.overheid.nl/BWBR0002634/2026-01-01) In Moneybird, **Acties > Buitengebruikstellen** removes the asset from the balance. [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven)
- **Herinvesteringsreserve.** A boekwinst may be added to a herinvesteringsreserve when the intention to reinvest exists, under [Wet IB 2001, art. 3.54](https://wetten.overheid.nl/BWBR0011353/2026-01-01). [Herinvesteringsreserve](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/fiscale_reserves/herinvesteringsreserve) Moneybird has **Acties > Herinvesteringsreserve** after a desinvestering. [Bezitting verkopen](https://helpcenter.moneybird.nl/nl/articles/207991-verkoop-van-een-bedrijfsmiddel-verwerken-desinvestering)

---

## 6. VAT ON AN ASSET

VAT on a business asset is voorbelasting, deductible at purchase when the asset serves the business and to the extent it serves turnover that is taxed with VAT. [Handboek 5.4.1](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf) The aanschafwaarde is then excluding the deductible VAT. VAT that is not deductible, in full or for the part that serves exempt turnover, is part of the aanschafwaarde and so of the depreciation base. [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving), [Investing](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeren_in_bedrijfsmiddelen)

The deduction is not final. An investeringsgoed is a roerende zaak that the business depreciates for the inkomstenbelasting or an onroerende zaak. The aftrek is revised for a roerend goed in the year of first use plus the 4 following years, 5 in total, and for an onroerende zaak in the year of first use plus the 9 following years, 10 in total. Each year carries one fifth or one tenth of the VAT, corrected in the last VAT return of the year. [Art. 13 Uitv.besch. OB](https://wetten.overheid.nl/BWBR0002634/2026-01-01), [Herziening](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/belaste_en_vrijgestelde_omzet/inschatting_van_het_gebruik2/herziening_aftrek_bij_investeringsgoederen2/herziening_aftrek_bij_investeringsgoederen)

A correction is due when the ratio of taxed to exempt use differs by more than 10 percent of the first-year percentage. More taxed use adds to rubriek 5b, less means VAT owed. [Art. 13 lid 4 Uitv.besch. OB](https://wetten.overheid.nl/BWBR0002634/2026-01-01), [Herziening](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/belaste_en_vrijgestelde_omzet/inschatting_van_het_gebruik2/herziening_aftrek_bij_investeringsgoederen2/herziening_aftrek_bij_investeringsgoederen)

A sale inside the revision period ends the revision in one go in the sale's return period, at the ratio that follows from the sale. [Art. 13a Uitv.besch. OB](https://wetten.overheid.nl/BWBR0002634/2026-01-01), [Onroerende zaken](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/onroerende_zaken/herziening_btw/)

Private use of a roerend investeringsgoed is corrected for the private share, one fifth of the aanschafkosten each year and a part-year pro rata, when the VAT on the acquisition was fully deducted. When the VAT on the private-use share of the aanschafkosten was not deducted at purchase, no VAT is due on that share, but VAT is still due on the private share of the costs of use, maintenance and repairs. That correction also runs in the years after the revision period. [Roerende investeringsgoederen](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/roerende_investeringsgoederen/roerende_investeringsgoederen)

**KOR or exempt turnover.** A business in the KOR or with only exempt turnover deducts no input VAT on an asset, so nothing is revised at purchase. [purchase-invoices](./purchase-invoices.md) Entering or leaving the KOR can still cause a revision. That KOR revision has its own exception, separate from the 10 percent rule: it is not required for a good taken into use before that book year when the total revision in the book year is below 500, and the exception never applies in the year of first use. [Art. 13 lid 4 Uitv.besch. OB](https://wetten.overheid.nl/BWBR0002634/2026-01-01), [KOR revision](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/hoe_werkt_de_btw/kleineondernemersregeling/wat-betekent-meedoen-met-de-kleineondernemersregeling/moet-ik-mijn-btw-aftrek-herzien-vanwege-de-kleineondernemersregeling)

---

## 7. THE ASSET FLOW IN MONEYBIRD

1. **Book the invoice.** Add the invoice as [purchase invoices](./purchase-invoices.md) explains and choose a vaste activa category from **Investeringen** or **Auto van de zaak** on the line. A hand-made category must be a vaste activa category with a good RGS code and no parent category. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)
2. **Add the bezitting.** On a saved line with a vaste activa category the option **Bezitting toevoegen** appears. Moneybird copies the date and amount and asks for gebruiksduur and restwaarde. The aanschafwaarde is the total excluding VAT, calculated from the selected lines with discount lines included or excluded by checkbox. When part of the VAT is not deductible, that part belongs in the aanschafwaarde too, as section 6 states, and the Operator confirms the value before the bezitting is saved. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)
3. **Fields.** The card holds aanschafwaarde, datum ingebruikname, gebruiksduur and restwaarde. Goodwill defaults to 10 years [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven). Multiple identical products can become separate bezittingen. One asset made of several invoice lines is linked through **Regels koppelen**. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)
4. **Straight-line depreciation.** Moneybird writes off lineair on the last day of each month down to the restwaarde, then stops and marks the asset as afgeschreven. [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven)
5. **After the first depreciation** the aanschafwaarde, gebruiksduur and restwaarde can no longer be changed, only the name. Deleting through **Acties** also deletes the journaalposten, so prefer **Buitengebruikstellen** or **Desinvestering**. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)
6. **An existing asset at the start date.** Add it through **Toevoegen** on the **Bezittingen** tab with the original aanschafwaarde, datum ingebruikname, gebruiksduur and restwaarde, tick that depreciation already happened and enter the balance value at the end of the previous year. The amounts already depreciated appear as 'Handmatige afschrijvingen' with no journaalposten, then Moneybird depreciates monthly from the month after that value. Switch off earlier periodic memoriaalboekingen. [Bestaande activa](https://helpcenter.moneybird.nl/nl/articles/223936-bestaande-vaste-activa-overzetten-naar-bezittingen)
7. **Selling.** Choose **Acties > Desinvestering**. Moneybird books a pro-rata depreciation up to the sale date, removes the asset and books the gain as boekresultaat. A sales invoice with the category **Boekresultaat (naam investering)** can be created in the same step. [Bezitting verkopen](https://helpcenter.moneybird.nl/nl/articles/207991-verkoop-van-een-bedrijfsmiddel-verwerken-desinvestering)
8. **Scrapping or theft.** Choose **Acties > Buitengebruikstellen**. Moneybird removes the asset from the balance. Keep the evidence. [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven)
9. **Building.** Moneybird does not depreciate bedrijfsgebouwen automatically. Add the yearly depreciation through **Acties**. [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven)
10. **Reports.** The activastaat shows aanschafwaarde, current value and depreciation per asset and supports the return. [Inzicht in bezittingen](https://helpcenter.moneybird.nl/nl/articles/207296-inzicht-in-je-bezittingen)

The manual route uses the **Investering** category set: a vaste activa category, an **Afschrijving sinds aanschaf** category and an **Afschrijvingskosten** category, with a periodieke memoriaalboeking per depreciation. [Investeringen en afschrijvingen](https://helpcenter.moneybird.nl/nl/articles/207988-investeringen-en-afschrijvingen) An asset with value at the start can also enter the beginbalans on two lines. [Beginbalans](https://helpcenter.moneybird.nl/nl/articles/207968-investeringen-in-de-beginbalans)

---

## 8. CASES

- **C1 Laptop.** 1200 excluding VAT, taken into use on 1 April, gebruiksduur 5 years, restwaarde 200. One bezitting. See Example 1.
- **C2 Desk under the limit.** 400 excluding VAT is below 450 when the VAT is deductible, so it is a cost in the year of purchase and no bezitting. See Example 2.
- **C3 Existing asset.** An asset from before the Moneybird start follows section 7, with remaining depreciation from the boekwaarde at the start date. An asset brought in from private use is an Operator or bookkeeper decision, and goods moved from private to business generally give no investeringsaftrek. [Handboek 7.2.2](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf)
- **C4 Sale.** Sell the laptop for 700 in the third year at a boekwaarde of 650. The 50 difference is boekwinst. Check the desinvesteringsbijtelling when an investeringsaftrek was claimed, which the Operator or a bookkeeper corrects. [Desinvesteringsbijtelling](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeringsaftrek_en_desinvesteringsbijtelling/desinvesteringsbijtelling)
- **C5 Scrapping.** **Acties > Buitengebruikstellen** takes the laptop off the balance. At a nil boekwaarde there is no further entry, otherwise the remaining boekwaarde is boekverlies. [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven), [How to calculate](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/hoe_berekent_u_het_bedrag_van_de_afschrijving)
- **C6 Building.** A building needs the WOZ bodemwaarde and is an Operator case. Do not compute the floor here. [Art. 3.30a](https://wetten.overheid.nl/BWBR0011353/2026-01-01), [Bedrijfspand](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/afschrijving_bedrijfspand)
- **C7 Private use.** A partly private phone or laptop goes through the etikettering in section 9 first. See [Mixed-use costs](./mixed-use-costs.md).

---

## 9. MIXED PRIVATE AND BUSINESS USE

A good used both privately and for the business falls under vermogensetikettering. At 10 percent business use or less it is verplicht privévermogen, at 90 percent or more it is verplicht ondernemingsvermogen, in between it is keuzevermogen, the entrepreneur's choice within reasonable bounds. [Vermogensetikettering](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/vermogensetikettering-bedrijfsmiddel), [Kosten en auto 2026](./tax-rules/2026/costs-and-car/figures.md) section 27

In the ondernemingsvermogen the asset is depreciated in full and the private use is a privéonttrekking. In the privévermogen it is not depreciated and the costs connected with it are 0 percent deductible under art. 3.16 lid 3 Wet IB 2001. [vermogensetikettering](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/vermogensetikettering-bedrijfsmiddel), [Wet IB 2001, art. 3.16](https://wetten.overheid.nl/BWBR0011353/2026-01-01)

For the VAT the choice is separate. A mixed-use good is private assets, business assets or partly, per good and recorded in the administration. In business assets a roerend goed gets its purchase VAT deducted with a year-end private-use settlement, in full when all turnover is taxed with VAT and only for the taxed share when there is also exempt turnover, while an onroerende zaak gives only the VAT on the business use. Partly in business assets, only the business part is deducted. A business with only exempt turnover deducts no VAT, not even for the business share. [mixed use of investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/investeringsgoederen), [Handboek 5.4.1](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf), [private use of movable investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/roerende_investeringsgoederen/roerende_investeringsgoederen)

A change in use inside the revision period can cause a herziening (section 6) and goes to the Operator or a bookkeeper. The booking split is in [Mixed-use costs](./mixed-use-costs.md).

---

## 10. CALCULATED EXAMPLES

Invented figures.

### Example 1. A laptop over five years

A laptop costs 1200 excluding VAT, is taken into use on 1 April, has a restwaarde of 200 and a gebruiksduur of 5 years.

1. Yearly depreciation: (1200 - 200) : 5 = 200.
2. The limit is 20% of 1200 = 240, so 200 is allowed. [Art. 3.30 lid 2](https://wetten.overheid.nl/BWBR0011353/2026-01-01)
3. First year, nine months: 9/12 x 200 = 150.
4. Boekwaarde end of the first year: 1200 - 150 = 1050.
5. Later years: 200 per year, reaching the restwaarde in the sixth calendar year because of the nine-month first year.
6. Moneybird fields: aanschafwaarde 1200, datum ingebruikname 1 April, gebruiksduur 5 years, restwaarde 200. Moneybird books the monthly part and stops at the restwaarde. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)
7. VAT: 21 percent of 1200 is 252, at the rate in [BTW 2026](./tax-rules/2026/vat/figures.md). When the VAT is deductible the asset is 1200 and the 252 goes to rubriek 5b of the purchase period. [purchase-invoices](./purchase-invoices.md)

### Example 2. A desk under the limit

A desk costs 400 excluding VAT, plus 84 VAT at the 21 percent rate in [BTW 2026](./tax-rules/2026/vat/figures.md), total 484. With the VAT deductible it is under the 450 threshold, so it is a cost.

1. One invoice line: amount 400, rate 21%, category by purpose, no bezitting. [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen)
2. Moneybird shows VAT 84 and total 484, equal to the invoice.
3. Result: cost 400 and 84 voorbelasting in rubriek 5b when the desk serves taxed turnover. [purchase-invoices](./purchase-invoices.md)
4. The desk does not count for the KIA, because it is below the per-asset minimum. [investments.md](./tax-rules/2026/investments/figures.md)

---

## 11. CHECKS AFTER BOOKING

1. The balans shows aanschafwaarde minus depreciation and the activastaat agrees. [Inzicht in bezittingen](https://helpcenter.moneybird.nl/nl/articles/207296-inzicht-in-je-bezittingen)
2. The yearly depreciation stays within 20%, or 10% for goodwill, and the boekwaarde never drops below the restwaarde. [Art. 3.30 lid 2](https://wetten.overheid.nl/BWBR0011353/2026-01-01), [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven)
3. The VAT on the purchase is in the return for the invoice period. A mixed-use asset follows the etikettering of section 9, so a roerend goed gets its VAT deducted with a year-end private-use settlement, in full when all turnover is taxed with VAT and only for the taxed share when there is also exempt turnover, while an onroerende zaak gives only the VAT on the business use. A business with only exempt turnover deducts no VAT, not even for the business share. [mixed use of investment goods](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/investeringsgoederen/investeringsgoederen), [Handboek 5.4.1](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf)
4. A sale inside five years puts the desinvesteringsbijtelling in the year of sale for the Operator's review. [Desinvesteringsbijtelling](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeringsaftrek_en_desinvesteringsbijtelling/desinvesteringsbijtelling)
5. A use change of more than 10 percent of the first-year percentage inside the revision period goes in the last return, which the Operator reviews and files. [Herziening](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/belaste_en_vrijgestelde_omzet/inschatting_van_het_gebruik2/herziening_aftrek_bij_investeringsgoederen2/herziening_aftrek_bij_investeringsgoederen)

---

## 12. OPEN POINTS

- **No herziening screen.** The Moneybird help pages show no step for the VAT revision, which goes into the return for the Operator or a bookkeeper.
- **Threshold wording.** Moneybird states 450 excluding VAT [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen), while the Belastingdienst adds the including-VAT variant when the VAT is not deductible [One year](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/zakelijke_kosten/kosten_die_u_in_1_jaar_mag_aftrekken). Follow the Belastingdienst wording for tax.
- **Useful life.** Moneybird uses 5 years and a nil restwaarde in most cases [Bezitting toevoegen](https://helpcenter.moneybird.nl/nl/articles/207293-bezitting-toevoegen) and 10 years for goodwill [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven), while the tax life depends on the asset.
- **Building depreciation.** No Moneybird help page reviewed computes the WOZ floor [Bezitting lineair](https://helpcenter.moneybird.nl/nl/articles/207294-bezitting-lineair-afschrijven), and the Operator takes the WOZ-waarde from the beschikking.
- **Asset not yet in use at year end.** No general page states the income tax depreciation for that case. The willekeurige afschrijving page gives a payment cap for that scheme [Willekeurige afschrijving](https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/willekeurige_afschrijving/), so the Operator decides.
- **Private asset moved in.** No page states the value basis, and such goods give no investeringsaftrek [Handboek 7.2.2](https://download.belastingdienst.nl/belastingdienst/docs/handboek_ondernemen_2026_aa9701z62fd.pdf), so the Operator or a bookkeeper decides the entry value.

---

## 13. RELATED RESOURCES

- [Investeringsaftrek 2026](./tax-rules/2026/investments/figures.md) holds the KIA bands, the per-asset minimum and the desinvesteringsbijtelling threshold.
- [Mixed-use costs](./mixed-use-costs.md) covers a cost or asset used partly privately.
- [Moneybird bookkeeping](./moneybird-bookkeeping.md) covers categories, the opening balance and bank matching.
- [Booking purchase invoices](./purchase-invoices.md) covers the invoice, the VAT rates and reverse charge.
- [Dutch tax rules](./tax-rules/dutch-tax-rules.md) routes to each year's topic files.
- [cli-moneybird](../../cli-moneybird/SKILL.md) owns the guarded reads and writes.
- [SKILL.md](../SKILL.md) holds the LIVE write authority.
