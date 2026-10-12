---
title: Routing signals for the task-type table
description: Where each routing signal in the SKILL.md task-type table comes from, with the Belastingdienst page per signal group, the skill vocabulary that has no public source, and the tie margin, fallback floor, warning band, abstain outcome and specificity clauses.
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

**Rule:** This reference holds the signal sources behind the Task-Type Table in `SKILL.md` and the tie and abstain mechanics behind it. The table itself stays the single source of truth for routing. Nothing here changes a row or its read set.

---

## 1. OVERVIEW

Every signal word in the Task-Type Table has a source. Most signal words come from a Belastingdienst page that uses the same words for the same concept. The migration terms, the CLI terms, the period words and the onboarding term are skill vocabulary. They name this skill's own work, so no public page defines them.

`btw` alone is a weak signal that never decides a row. It only confirms a route already chosen by a strong noun such as `aangifte`, `tarief` or `voorbelasting`.

---

## 2. SIGNAL SOURCES

- Administration terms `administratie`, `boekhouding`, `bewaarplicht`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/ondernemen/administratie/
- Record-keeping, document and cost terms `administratie bijhouden`, `factuur`, `verkoopfactuur`, `inkoopfactuur`, `bonnetje`, `kassabon`, `omzet`, `kosten`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/administratie_bijhouden/
- VAT and return terms `aangifte doen`, `btw-aangifte`, `aangifte omzetbelasting`, `voorbelasting`, `btw-tarief`, `btw-identificatienummer`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aangifte_doen_en_betalen/btw-aangifte-waar-moet-u-aan-denken/hoe-btw-aangifte-invullen-en-versturen
- Income tax deduction terms `zelfstandigenaftrek`, `ondernemersaftrek`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/winst/inkomstenbelasting/inkomstenbelasting_voor_ondernemers/ondernemersaftrek/zelfstandigenaftrek1/verrekenen_niet_gerealiseerde_zelfstandigenaftrek
- Car terms `kilometervergoeding`, `privégebruik auto`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/btw_aftrekken/btw_en_de_auto/zakelijk_gebruik_van_de_priveauto/zakelijk_gebruik_van_de_priveauto
- Threshold terms `drempel`, `kleineondernemersregeling`: https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/btw/hoe_werkt_de_btw/kleineondernemersregeling/wat-betekent-meedoen-met-de-kleineondernemersregeling/
- Skill vocabulary, not from the Belastingdienst: the migration terms `migratie`, `overzetten` and `historische administratie`, the CLI terms `haal op`, `boek in` and `synchroniseer`, the period words `deze maand`, `afgelopen kwartaal`, `vorig jaar` and `sinds wanneer` and the onboarding term `startende ondernemer`.

---

## 3. TIE MARGIN, FLOOR, WARNING BAND AND ABSTAIN

These four constants and one outcome govern what happens when two rows score close together.

- `ROUTE_MARGIN = 0.25`. When the top two row scores differ by less than 0.25 and no specificity clause decides between them, the answer does not pick a row. The margin is the distance a winning row must keep over the runner-up.
- `FALLBACK_FLOOR`. This is the minimum top score for any route. A winner below the floor is not trusted even when it leads alone. Its value is set at calibration and stays marked `calibration: pending` until the held-out fixtures freeze it. The fallback threshold stays below the route threshold.
- The 0.08 warning band. A gap under 0.08 above the margin means the winner cleared the margin only barely. The router logs such a case for telemetry only and never changes the route.
- The abstain outcome. When the router abstains, the answer names the candidate rows and asks one question through tier B of the fallback.

---

## 4. THE FOUR SPECIFICITY CLAUSES

The four specificity clauses match the On tie column of the Task-Type Table. Each one lets a more specific request beat a broader row before the margin rule is applied.

1. An invoice named makes T4 beat T3.
2. One year named makes T5 beat T6.
3. A phase number or gate named makes T1 beat T2.
4. T7 is additive and never wins alone. It appends the matching sibling tool skill to the row already matched.

---

## 5. TOKEN BUDGETS FOR THE ROUTE KEYS

The Budget column of the Task-Type Table holds one key per row, `tok:T1` to `tok:T9`. Each key resolves to the token cost of that row's read set, built from the read budget ladder in `SKILL.md`. The ladder units are token counts in o200k_base, the lead encoding, with the cl100k_base column beside them in `../benchmark/token-baseline.json`:

- A README or index file: 3,000 tokens, which covers a year README and the migration index.
- One section: 5,000 tokens.
- One full reference file: 15,000 tokens.
- Section 3 of `dutch-tax-rules.md`: at most 80,000 tokens, and only after a jump through its section list.

A row shows two numbers. The base is the ladder sum of the read path that answers the question. The ceiling adds every further read its read set allows, so no route may load more than its ceiling.

| Key | Base | Ceiling | Built from |
|---|---|---|---|
| `tok:T1` | 33,000 | 48,000 | migration index 3,000, shared mechanisms 15,000 and one phase file 15,000, plus the control framework 15,000 when a gate, risk or year lock applies |
| `tok:T2` | 15,000 | 15,000 | one full reference file |
| `tok:T3` | 18,000 | 51,000 | bookkeeping file 15,000 and a year README 3,000, plus the year btw file 15,000 on a VAT period, plus the migration index 3,000 and the recurring-cycle file 15,000 while the post-cutover state is open |
| `tok:T4` | 45,000 | 45,000 | purchase invoices 15,000, the year btw file 15,000 and the bookkeeping file 15,000 |
| `tok:T5` | 8,000 | 18,000 | a year README 3,000 plus one section 5,000, and 5,000 more for a rules subsection and 5,000 more for the source library when either is needed |
| `tok:T6` | 80,000 | 80,000 | section 3 of the rules file, at most 80,000, only after a jump through its section list |
| `tok:T7` | 0 | 0 | no reference file, the sibling tool skill carries its own reads |
| `tok:T8` | 0 | 0 | loads nothing |
| `tok:T9` | 15,000 | 15,000 | one full reference file |

---

## 6. RELATED RESOURCES

- `SKILL.md` holds the Task-Type Table, the weak-signal note and the compact tie block.
- `references/migration/README.md` maps every migration phase to its reference file.
