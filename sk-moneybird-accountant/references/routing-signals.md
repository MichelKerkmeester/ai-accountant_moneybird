---
title: Routing signals for the task-type table
description: Where each routing signal in the ROUTER.md task-type table comes from, with the Dutch Tax and Customs Administration (Belastingdienst) page per signal group, the skill vocabulary that has no public source and the tie margin, fallback floor, warning band, abstain outcome, specificity clauses and year change route.
nav_label: "Routing signals for the task-type table"
trigger_phrases:
  - routing signals
  - signal sources
  - route margin
  - tie clause
  - abstain outcome
importance_tier: important
contextType: general
version: 1.0.0.0
---

# Routing signals

**Rule:** This reference holds the signal sources behind the Task-Type Table in `ROUTER.md` and the tie and abstain mechanics behind it. The table itself stays the single source of truth for routing. Nothing here changes a row or its read set.

---

## 1. OVERVIEW

Every signal word in the Task-Type Table has a source. Most signal words come from a Dutch Tax and Customs Administration page that uses the same words for the same concept. The migration terms, the CLI terms, the period words and the onboarding term are skill vocabulary. They name this skill's own work, so no public page defines them.

`btw` alone is a weak signal that never decides a row. It only confirms a route already chosen by a strong noun such as `aangifte`, `tarief` or `voorbelasting`.

Signal matching folds a hyphen and a space to one space, so `btw aangifte` equals `btw-aangifte` and `IB aangifte` equals `IB-aangifte`. A preparation request with no tax named still reaches no preparation row. The fallback refusal reads the bare word `aangifte`, so `kun je een aangifte voorbereiden?` alone receives the T8 refusal.

The T8 filing gate reads the T8 signals of the table and the filing grammar in section 8, which finds a filing verb that governs a return, a destination such as the Belastingdienst or a filed state. A signal matches whole words on both sides, so `dien` misses `diensten` and `submit` misses `submitted`. Every guard is anchored to the filing verb, so a question word, a time or a deadline elsewhere in the clause does not keep the request.

- A negation governs the verb, also across an adverb, a wish, `not allowed to` or an alternative verb, as in `do not ever submit it`, `I don't want you to submit it`, `you are not allowed to file it` and `do not file or submit it`. A Dutch separable verb keeps a `niet` before its particle, as in `dien hem niet in`. A conjunction or a subordinator ends that reach, so `dien hem in als ik niet reageer` and `don't wait and submit it` still ask to file. A user who cannot file asks the assistant, so `I can't file it myself, so please do it` still asks to file, and so does `I need you to submit it`.
- The sentence is a question that asks the assistant nothing, as in `is it mandatory to file a VAT return?`. A question that addresses the assistant or a shared we, as in `can you file it?`, `wilt u de aangifte indienen?`, `how about you file it` `can we file it today?` and `why don't we file it now?`, still asks to file, and so does a sentence that opens with the verb, as in `file the VAT return, ok?`.
- The clause asks when, how or what the user files (`when do I have to file`), asks for information (`tell me when it must be submitted`, `de stappen om hem in te dienen`), sets a reminder (`remind me to file it`, `reminder: file it before 1 May`), asks another person to file (`ask my accountant to file it`), says the user is not yet ready or about to file (`ik sta op het punt hem in te dienen`), sets a time someone else or the user acts in (`before I send it in`, `voordat mijn boekhouder hem indient`), states a purpose (`so she can file it`), names a deadline for the verb (`the deadline to file`), holds a relative clause with another subject (`that my accountant will submit`), names a lapse (`I forgot to file`) or names the user or another person as the subject (`I'll send it in myself`, `she will file it`, `the accountant is going to file it`). An information or reminder frame stops at `and`, `then` or `but`, so `tell me when it is due and submit it` still asks to file, a time frame stops at its own verb, so `when I am done please file it` and `wanneer ik klaar ben dien hem in` still ask to file, and `todo:` or `task:` before a colon assigns the filing.
- A filing noun names the act after a preposition, as in `before filing` and `voor het indienen`, and when the user owns it, as in `leave the filing to me`. A request verb before it, as in `go ahead with the filing` or `zorg voor het indienen`, still asks to file.

`after I approve, please submit it`, `the deadline is Friday so file it` and `when you are ready file it` still ask to file. The fallback refusal on `filing`, `aangifte` and `file the return` reads the same guards. A boundary word such as `personal database` keeps a negation up to four words away, so `without reading my personal database` names no boundary.

A tool name such as `jortt-cli` or `moneybird-guard` scores no row. When a request names the Jortt CLI and neither Moneybird, a move verb such as `copy`, `import` or `push`, a phase number nor a write it does not rule out, the word `Jortt` names the source it reads, not a migration. A write verb anywhere in a Jortt request with no Moneybird target blocks the T7 handoff, because Jortt is read only. Its stems count, as do `add`, `modify`, `cancel`, `post` and `approve`, so `de inkoopfactuur te verwijderen` blocks. `edit nothing`, `wijzig niets`, a local output such as `write the summary to a file` and a noun such as `the change history` block nothing. A negated tool name, such as `do not use jortt-cli`, starts no CLI packet, though a route whose tool route names it still hands off. `not only` and `don't forget` negate nothing.

A source line below may name a related term that is no row signal, such as `administratie` or `omzet`. Only the table decides what routes. The VAT procedure lists `naheffing` as a correction phrase, but it is no signal, because as a prefix it would also claim a term question such as `naheffingsaanslag`.

---

## 2. SIGNAL SOURCES

- Administration terms `administratie`, `boekhouding`, `bewaarplicht`, `bewaartermijn`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/
- Record-keeping, document and cost terms `administratie bijhouden`, `factuur`, `verkoopfactuur`, `inkoopfactuur`, `bonnetje`, `kassabon`, `omzet`, `kosten`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/administratie_bijhouden/
- VAT and return terms `aangifte doen`, `doe aangifte`, `indienen`, `dien`, `insturen`, `aanslag betalen`, `btw-aangifte`, `aangifte omzetbelasting`, `kwartaalaangifte`, `suppletie`, `correctie vorige periode`, `voorbelasting`, `btw-tarief`, `btw-identificatienummer`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aangifte_doen_en_betalen/btw-aangifte-waar-moet-u-aan-denken/hoe-btw-aangifte-invullen-en-versturen
- Administration and yearly overview terms `jaaroverzicht`, `jaarrekening`, `jaarafsluiting`, `eindejaar`, `balans opmaken`, `winst-en-verliesrekening`, `overlopende posten`, `vooruitbetaalde kosten`, `toerekenen`, `privé-opnamen`, `balans en winst-en-verliesrekening`, `yearly overview` and `annual accounts`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/een_administratie_opzetten
- Income tax return terms `aangifte inkomstenbelasting`, `IB-aangifte` and `income tax return`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/prive/inkomstenbelasting/hoe_werkt_inkomstenbelasting/aangifte_doen/hoeveel-jaar-terug-belastingaangifte-doen
- Income tax deduction terms `zelfstandigenaftrek`, `ondernemersaftrek`, `startersaftrek`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/ondernemersaftrek/zelfstandigenaftrek1/verrekenen_niet_gerealiseerde_zelfstandigenaftrek
- Small business profit exemption term `MKB-winstvrijstelling`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/mkb_winstvrijstelling
- Car terms `kilometervergoeding`, `privégebruik auto`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/btw_en_de_auto/zakelijk_gebruik_van_de_priveauto/zakelijk_gebruik_van_de_priveauto
- Mixed-use and private-use terms `privégebruik`, `zakelijk en privé`, `deels privé`, `gemengde kosten`, `telefoonabonnement`, `private use`, `partly private`, `mixed use` and `phone subscription`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/privegebruik/gemengd_gebruik/gemengd_gebruik
- Asset and depreciation terms `afschrijven`, `afschrijving`, `inventaris`, `activeren`, `activeer`, `depreciation`, `depreciate`, `fixed asset`, `capitalise` and `capitalize`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/afschrijving/
- Investment deduction terms `investeringsaftrek`, `kleinschaligheidsinvesteringsaftrek`, `KIA`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/investeringsaftrek_en_desinvesteringsbijtelling/kleinschaligheidsinvesteringsaftrek_kia
- Threshold terms `drempel`, `KOR-grens`, `kleineondernemersregeling`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/hoe_werkt_de_btw/kleineondernemersregeling/wat-betekent-meedoen-met-de-kleineondernemersregeling/
- Skill vocabulary, not from the Dutch Tax and Customs Administration (Belastingdienst). The migration terms are `migratie`, `overzetten`, `historische administratie`, `migratiefase` and `migrate`. The CLI terms are `haal op`, `boek in` and `synchroniseer`. The period words are `deze maand`, `afgelopen kwartaal`, `vorig jaar` and `sinds wanneer`, and the question word is `hoeveel`. The migration concept terms are `categorie`, `valkuil` and `welke rekening`. The onboarding terms are `startende ondernemer`, `waar begin ik`, `waar moet ik beginnen` and `eerste keer`. The filing terms are `periode afsluiten`, `file`, `submit`, `pay` and `lock the period`, and the filing grammar of section 8 is skill vocabulary too. The boundary terms are `personal database` and `persoonlijke database`. The English figure and rule words are `KOR limit` and `retention`. The VAT correction phrases are `VAT correction`, `correct a VAT error` and `supplementary return`. The tool and packet names are `jortt-cli`, `cli-jortt` and `cli-moneybird`. The source terms are `officiële tekst`, `officiele tekst`, `wetstekst`, `official text`, `source library` and `law text`. The preparation verbs `voorbereiden`, `klaarzetten`, `controleren`, `prepare`, `review` and `check` route only inside a type phrase.

---

## 3. TIE MARGIN, FLOOR, WARNING BAND AND ABSTAIN

These four constants and one outcome govern what happens when two rows score close together.

- `ROUTE_MARGIN = 0.25`. When the top two row scores differ by less than 0.25 and no specificity clause decides between them, the answer does not pick a row. The margin is the distance a winning row must keep over the runner-up.
- `FALLBACK_FLOOR = 0.5`. This is the minimum top score for any route. A winner below the floor is not trusted even when it leads alone. The value was frozen on the calibration split. The frozen sweep and the held-out result are recorded in `../assets/route-calibration.json`.
- The 0.08 warning band. A gap under 0.08 above the margin means the winner cleared the margin only barely. The router logs such a case for telemetry only and never changes the route.
- The abstain outcome. When the router abstains, the answer names the candidate rows and asks one question through tier B of the fallback.

The offline resolver in `scripts/route-replay/route-replay.py` scores a row by its count of matched signals. With whole counts, any lead of one signal clears the margin, one signal clears the floor and no gap falls inside the warning band, so in that resolver a tie means an equal count.

---

## 4. THE SPECIFICITY CLAUSES

The specificity clauses match the On tie column of the Task-Type Table. Each one decides a tie between two rows, so a more specific request beats a broader row before the margin rule is applied.

1. An invoice named makes T4 beat T3, and with no invoice named T3 beats T4. An invoice named also makes T4 beat T2.
2. One year named makes T5 beat T6.
3. A request for the official text or the source library with no invoice named makes T5 beat T4, and with an invoice named T4 keeps the invoice route.
4. A rule asked across years or since a change makes T6 beat T4.
5. A tax figure asked with no invoice named makes T5 beat T4.
6. A phase number or gate named makes T1 beat T2, T3 and T4.
7. T7 is additive and never wins alone. It appends the matching sibling tool skill to the row already matched. The destination is `cli-jortt` for a Jortt read, `cli-moneybird` for a Moneybird read and blocked for a refused write. A request that names both systems reads Jortt first, so its destination is `cli-jortt`.
8. A VAT return named makes T10 beat T3, and with no return named T3 beats T10.
9. A yearly overview named makes T11 beat T3, and with no overview named T3 beats T11.
10. An income tax return named makes T12 beat T5, and with no return named T5 beats T12.
11. An explicit request to file, submit, send, transmit, upload, pay or lock a return or a period, or to mark a return as filed, makes T8 beat T10, T11 and T12, and every row once the request names the VAT return, the yearly overview or the income tax return. The T8 signals and the filing grammar of section 8 find the request, and the guards of section 1 keep a question, a negation, a purpose or a time the user acts in. A request to prepare, assemble, check or review one of the three yearly deliverables routes to T10, T11 or T12, and only the explicit filing request is refused.

The mixed-use and asset terms of T4 name what is booked, not the kind of request. Together they add one point to T4 at most, so a tax figure, rule or period request that names an asset reaches the tie clauses above instead of losing to T4 on signal count.

---

## 5. TOKEN BUDGETS FOR THE ROUTE KEYS

The Budget column of the Task-Type Table holds one key per row. Each key resolves to the token cost of that row's read set, built from the read budget ladder in `ROUTER.md`. The ladder units are token counts in o200k_base, the lead encoding, with the cl100k_base column beside them in `../benchmark/token-baseline.json`:

- A README or index file: 3,000 tokens, which covers a year README, the migration index and the rules entry file `dutch-tax-rules.md`.
- One section: 5,000 tokens.
- One full reference file: 15,000 tokens.

A row shows two numbers. The base is the ladder sum of the read path that answers the question. The ceiling adds every further read its read set allows, so no route may load more than its ceiling.

| Key | Base | Ceiling | Built from |
|---|---|---|---|
| `tok:T1` | 30,000 | 45,000 | shared mechanisms 15,000 and the phase file the request names 15,000, read through the phase map, plus the control framework 15,000 when a gate, risk or year lock applies. The migration index 3,000 replaces the phase file when no phase is named |
| `tok:T2` | 15,000 | 15,000 | one full reference file |
| `tok:T3` | 18,000 | 51,000 | bookkeeping file 15,000 and a year README 3,000, plus the year VAT figures part 15,000 on a VAT period, plus the migration index 3,000 and the recurring-cycle file 15,000 while the post-cutover state is open |
| `tok:T4` | 45,000 | 75,000 | purchase invoices 15,000, the year VAT figures part 15,000 and the bookkeeping file 15,000, plus the mixed-use file 15,000 and the fixed-asset file 15,000 when their condition applies |
| `tok:T5` | 8,000 | 18,000 | a year README 3,000 plus one section 5,000, and 5,000 more for a rules subsection and 5,000 more for the source library when either is needed |
| `tok:T6` | 18,000 | 18,000 | the rules entry file 3,000 and the one general topic file its table names 15,000 |
| `tok:T7` | 0 | 0 | no reference file, the sibling tool skill carries its own reads |
| `tok:T8` | 0 | 0 | loads nothing |
| `tok:T9` | 15,000 | 15,000 | one full reference file |
| `tok:T10` | 21,000 | 41,000 | the VAT return procedure README 3,000, a year README 3,000 and the year VAT figures part 15,000, plus the year procedure figures part 15,000 when a deadline, correction or tax interest (belastingrente) applies and one source section 5,000 when the official source is asked |
| `tok:T11` | 33,000 | 51,000 | the yearly overview procedure README 3,000, the year cost and car figures part 15,000 and the year investments figures part 15,000, plus a year README 3,000 when a close signal applies and the fixed-asset file 15,000 when an asset, an investment or depreciation is in scope |
| `tok:T12` | 36,000 | 41,000 | the income tax return procedure README 3,000, a year README 3,000, the year income tax figures part 15,000 and the year entrepreneur's allowance (ondernemersaftrek) figures part 15,000, plus one source section 5,000 when the official source is asked |

---

## 6. YEAR CHANGE ROUTE

A question about what changed in one year, the difference between two years or `verschil met vorig jaar` loads `references/tax-rules/<year>/changes.md` first. That note holds the year's unique differences, and every bullet links the one topic section 5 that owns the fact. From there the route opens the linked `<topic>/notes.md#5-changes` section. When the question names no year, `references/tax-rules/year-changes.md` gathers every year, newest first, with the path to each year note.

---

## 7. DOCUMENTED GAPS

A row here names a deliverable the skill routes but does not document yet. The T8 documented gap answer reads this table through the `gaps` list in `references/index.json`, so the answer names the topic, the owner path and the Operator action. The owner path is the file a later phase creates, and its coverage flips from `gap` to `covered` when that file lands.

| Topic | Owner | Coverage | Operator action |
|---|---|---|---|
| vat-return | references/vat-return/README.md | covered | The Operator prepares and files the VAT return in the Dutch Tax and Customs Administration portal and keeps the filed copy with the records |
| yearly-overview | references/yearly-overview/README.md | covered | The Operator assembles the yearly overview in the Moneybird UI and keeps the balance sheet and the profit and loss statement (resultatenrekening) with the records |
| income-tax-return | references/income-tax-return/README.md | covered | The Operator prepares and files the income tax return in the Dutch Tax and Customs Administration (Belastingdienst) portal and keeps the assessment with the records |

---

## 8. FILING GRAMMAR

The T8 filing gate reads this grammar beside the T8 signals of the table. A clause asks to file when a filing verb governs a filing object or names a filing destination, when a status verb sets a filing object to a filed state or when a want verb asks for a filing object in a filed state. A verb-final form counts with a filing object before it in its clause part, as in `om de btw-aangifte in te dienen`, or with `van` and the object after it at the start of a clause, as in `verzenden van de btw-aangifte`, and an object pronoun counts when the sentence names a filing object, as in `prepare the VAT return and file it`. The object must be the direct object, so `send me a summary of the VAT return` asks for no filing, and any recipient that is no filing destination, as in `stuur de btw-aangifte naar mijn boekhouder`, `send it to Jan de Vries`, `send it via email`, `stuur hem als PDF` or `file it in the archive folder`, makes the verb no filing. A recipient check also covers a want, status or passive form, as in `I want the VAT return sent to my accountant`, and the `file the` table signal. A `to` before a verb, as in `file it to meet the deadline`, states a purpose and names no receiver, and the portal is the filing channel. A destination followed by a service noun, as in `the Belastingdienst helpdesk`, is none. A quarter or a period counts only before a preposition, an adverb or the end of its clause and with nothing but an article or an ordinal between it and the verb, so `report revenue per quarter` files nothing, and a return before another noun, as in `return label`, is no filing object, so `betaal de Q3 factuur` files nothing. A status verb and a filing verb take an object pronoun only when the sentence names a filing object other than a quarter or a period, so `stuur hem in Q3` files nothing. A negation or a second clause between a status or want verb and the filed state, as in `make sure it is not submitted` or `markeer de aangifte als klaar en de facturen als verstuurd`, sets no filing object to a filed state. The guards of section 1 then read the clause up to the verb.

- Filing verbs: `file`, `submit`, `send`, `transmit`, `upload`, `deliver`, `report`, `hand`, `lodge`, `forward`, `pay`, `lock`, `close`, `dien`, `doe`, `stuur`, `verstuur`, `verzend`, `lever`, `betaal`, `vergrendel`, `sluit`, `meld`
- Verb-final forms: `indienen`, `in te dienen`, `insturen`, `in te sturen`, `versturen`, `te versturen`, `verzenden`, `te verzenden`, `betalen`, `te betalen`, `aanleveren`, `indient`, `instuurt`
- Filing objects: `yearly overview`, `annual overview`, `annual accounts`, `jaaroverzicht`, `jaarrekening`, `return`, `aangifte`, `assessment`, `aanslag`, `suppletie`, `period`, `periode`, `quarter`, `kwartaal`, `Q1`, `Q2`, `Q3`, `Q4`
- Object pronouns: `it`, `them`, `hem`, `die`
- Filing destinations: `to the Belastingdienst`, `to the tax office`, `to the tax authorities`, `naar de Belastingdienst`, `bij de Belastingdienst`
- Status verbs: `mark`, `flag`, `set`, `markeer`, `zet`
- Want verbs: `need`, `want`, `get`, `have`, `make sure`, `ensure`, `zorg`, `wil`
- Filed states: `filed`, `submitted`, `sent`, `done`, `ingediend`, `verstuurd`, `verzonden`, `ingestuurd`

---

## 9. RELATED RESOURCES

- `ROUTER.md` holds the Task-Type Table, the weak-signal note and the compact tie block.
- `references/migration/README.md` maps every migration phase to its reference file.
