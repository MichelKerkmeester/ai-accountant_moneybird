---
title: Moneybird Accountant Router
description: Stage two routing of the accountant packet. The hub SKILL.md picks this packet, this file routes inside it and SKILL.md holds its contract.
trigger_phrases:
  - "moneybird accountant router"
  - "moneybird accountant smart routing"
importance_tier: important
contextType: general
version: 1.0.0.0
router_state: active
skill_pointer: SKILL.md
---

# Moneybird Accountant Router

## 1. OVERVIEW

This file holds the routing of the accountant packet: the task-type table, the route classes, ties and abstain, year and state, the generated router block and migration phase routing. The hub [`SKILL.md`](../SKILL.md) picks this packet, this file routes inside it and [`SKILL.md`](SKILL.md) holds the packet's contract. `scripts/check-route-table.py --write` regenerates the router block from the table, so edit the table and rerun the mode, never the block by hand.

---

## 2. SMART ROUTING

### Primary Detection Signal

MIGRATION covers historical records, Jortt exports, a migration phase, reconciliation, pilot writes, year locks and moving records into Moneybird. LIVE covers bookkeeping cadence, an ordinary income or cost event, a VAT period, an annual close and an ad hoc ZZP question.

If ambiguous, ask one question: historical migration or current bookkeeping? Do not guess a phase or year.

### Task-Type Table

Every request matches one row, which determines the files read and the tool skill.

<!-- route-table:start -->

| Type | Name | Dutch signals | English signals | Tool route | Read set | Budget | On tie |
|---|---|---|---|---|---|---|---|
| T1 | migration phase | `migratie`, `overzetten`, `historische administratie`, `Jortt`, `migratiefase` | migration phase, migrate, gate, Jortt export, archive, cutover, year lock | `cli-jortt + cli-moneybird` | `!references/migration/shared-mechanisms.md`, `!{phase-file}` for the phase the request names, `?references/migration/README.md` when no phase is named, and `?references/migration/control-framework.md` when a gate, risk or year lock applies | `tok:T1` | Beats T2, T3 and T4 when a phase number or gate is named |
| T2 | migration concept | `migratie`, `overzetten`, `historische administratie`, `categorie`, `valkuil`, `welke rekening` | migrate, mapping, category, which account, trap | `none` | `!references/migration/jortt-to-moneybird-mapping.md` | `tok:T2` | Yields to T1 when a phase number or gate is named |
| T3 | live period | `deze maand`, `afgelopen kwartaal`, `administratie bijhouden` | this month, this quarter, review, reconcile, bank, unmatched, close | `cli-moneybird` | `!references/moneybird-bookkeeping.md`, `!references/tax-rules/{year}/README.md`, `?references/tax-rules/{year}/vat/figures.md` when the period is a VAT period, `?references/migration/README.md` and `?references/migration/phases-19-to-21.md` while the post-cutover state is monitoring_active or monitoring_lapsed_phase22_open | `tok:T3` | Yields to T4 when an invoice is named and to T1 when a phase or gate is named |
| T4 | purchase invoice | `inkoopfactuur`, `bonnetje`, `factuur van een leverancier`, `privégebruik`, `zakelijk en privé`, `deels privé`, `gemengde kosten`, `afschrijven`, `afschrijving`, `inventaris`, `activeren`, `activeer`, `telefoonabonnement` | invoice, receipt, order, supplier, reverse charge, KOR, private use, partly private, mixed use, depreciation, depreciate, fixed asset, capitalise, capitalize, phone subscription | `cli-moneybird` | `!references/purchase-invoices.md`, `!references/tax-rules/{year}/vat/figures.md`, `!references/moneybird-bookkeeping.md`, `?references/mixed-use-costs.md` when the cost is used partly privately, `?references/fixed-assets.md` when the purchase is an asset, inventaris or is depreciated | `tok:T4` | Beats T3 when an invoice is named and yields to it otherwise, yields to T1 when a phase number or gate is named, beats T2 when an invoice is named, yields to T6 when the rule is asked across years and to T5 when a tax figure is asked and no invoice is named |
| T5 | tax figure | `btw-tarief`, `kilometervergoeding`, `zelfstandigenaftrek`, `ondernemersaftrek`, `startersaftrek`, `MKB-winstvrijstelling`, `kleineondernemersregeling`, `voorbelasting`, `drempel`, `KOR-grens`, `hoeveel`, `investeringsaftrek`, `kleinschaligheidsinvesteringsaftrek`, `KIA`, `officiële tekst`, `officiele tekst`, `wetstekst` | rate, threshold, KOR limit, deduction, how much, current year, official text, source library, law text | `none` | `!references/tax-rules/dutch-tax-rules.md`, `?references/tax-rules/{year}/README.md`, `!{topic-figures}` and `?references/tax-rules/source-library.md@2-how-to-reach-a-source` when a figure needs its official source | `tok:T5` | Beats T6 when one year is named |
| T6 | cross-year rule | `vorig jaar`, `sinds wanneer`, `bewaarplicht`, `bewaartermijn` | how does the rule work, changed since, compared with, retention | `none` | `!references/tax-rules/dutch-tax-rules.md@3-general-rules`, then the one general topic file its table names | `tok:T6` | Wins when the rule is asked across years or since a change |
| T7 | CLI action | `haal op`, `boek in`, `synchroniseer` | read Jortt, jortt-cli, cli-jortt, cli-moneybird, moneybird-guard, write, batch, approval | `additive` | `-` | `tok:T7` | Additive and never wins alone, it appends the matching sibling tool skill to the row already matched |
| T8 | unknown or out of scope | `aangifte doen`, `doe aangifte`, `indienen`, `dien`, `insturen`, `aanslag betalen`, `periode afsluiten`, `persoonlijke database` | `filing`, `file my`, `file the`, `file our`, `submit`, `pay the assessment`, `lock the period`, `non-Dutch tax`, `private database`, `personal database` | `none` | `-` | `tok:T8` | Wins over T10, T11 and T12 when an explicit file, submit, send, pay or lock request is present, otherwise only when no other row scores. The filing grammar in `references/routing-signals.md` section 8 adds a filing verb with a return, a destination or a filed state. A question about filing, a deadline (aangiftetermijn), a purpose or a time the user acts in is no filing request |
| T9 | onboarding | `startende ondernemer`, `waar begin ik`, `waar moet ik beginnen`, `eerste keer` | where do I start, first time, setup | `none` | `!references/migration/overview-and-setup.md` | `tok:T9` | Loses to every typed row, it wins only when the request asks where to start with no concrete task |
| T10 | prepare the VAT return | `btw-aangifte`, `aangifte omzetbelasting`, `kwartaalaangifte`, `btw-aangifte voorbereiden`, `btw-aangifte klaarzetten`, `btw-aangifte controleren`, `suppletie`, `correctie vorige periode` | `VAT return`, `quarterly return`, `prepare the VAT return`, `review the VAT return`, `check the VAT return`, `VAT correction`, `correct a VAT error`, `supplementary return` | `cli-moneybird` | `!references/vat-return/README.md`, `!references/tax-rules/{year}/README.md`, `!references/tax-rules/{year}/vat/figures.md`, `?references/tax-rules/{year}/procedure/figures.md` when a deadline, correction or tax interest (belastingrente) applies, and `?references/tax-rules/source-library.md@2-how-to-reach-a-source` when the official source is asked | `tok:T10` | Beats T3 when the VAT return is named and yields to T3 on a period question without it, always yields to T8 on a filing request |
| T11 | prepare the yearly overview | `jaaroverzicht`, `jaarrekening`, `jaarafsluiting`, `eindejaar`, `balans opmaken`, `winst-en-verliesrekening`, `overlopende posten`, `vooruitbetaalde kosten`, `toerekenen`, `privé-opnamen`, `balans en winst-en-verliesrekening`, `jaaroverzicht voorbereiden`, `jaarrekening klaarzetten`, `jaarrekening controleren` | `yearly overview`, `annual accounts`, `prepare the yearly overview`, `review the annual accounts`, `check the yearly overview` | `cli-moneybird` | `!references/yearly-overview/README.md`, `!references/tax-rules/{year}/costs-and-car/figures.md`, `!references/tax-rules/{year}/investments/figures.md`, `?references/tax-rules/{year}/README.md` when a close signal applies, and `?references/fixed-assets.md` when an asset, an investment or depreciation is in scope | `tok:T11` | Beats T3 when the yearly overview is named and yields to T3 on a period question without it, always yields to T8 on a filing request |
| T12 | prepare the income tax return | `aangifte inkomstenbelasting`, `IB-aangifte`, `aangifte inkomstenbelasting voorbereiden`, `IB-aangifte klaarzetten`, `IB-aangifte controleren` | `income tax return`, `prepare the income tax return`, `review the income tax return`, `check the income tax return` | `cli-moneybird` | `!references/income-tax-return/README.md`, `!references/tax-rules/{year}/README.md`, `!references/tax-rules/{year}/income-tax/figures.md`, `!references/tax-rules/{year}/business-deductions/figures.md`, and `?references/tax-rules/source-library.md@2-how-to-reach-a-source` when the official source is asked | `tok:T12` | Beats T5 when the income tax return is named and yields to T5 on a tax figure question without it, always yields to T8 on a filing request |

<!-- route-table:end -->

Read budget ladder in o200k_base tokens: year README 3,000, one section 5,000, full file 15,000.

Asked what a Dutch term means or its English name, a route also reads `references/glossary/README.md` and the glossary file of the term and of each topic it reads.

The generated [reference library](./references/README.md) lists the tax year folders, the tax-rule and migration files, each with a description.

Signal sources, the `tok:Tn` keys and their Belastingdienst pages: `references/routing-signals.md`.

T8 answers in two ways. A request outside scope gets the out-of-scope refusal. A requested yearly deliverable whose procedure is not written gets the documented gap answer from the `gaps` list in `references/index.json`, naming the topic, the owner path and the Operator action. Every tax-portal action stays Operator-only.

### Route Classes

- `KNOWLEDGE`: reference files only.
- `JORTT_READ`: jortt-cli reads only.
- `MONEYBIRD_READ`: moneybird-guard reads under `MONEYBIRD_GUARD_READ_ONLY=1` per the Read Step Contract.
- `MONEYBIRD_GATED_WRITE`: a guarded write after a passed gate and Operator approval, within LIVE write authority.
- `OPERATOR_UI`: the Operator acts in the Moneybird UI.
- `BLOCKED`: stops before any CLI call or dry-run, records the refusal and names the owner. Members: a Jortt write, a return filing, a Moneybird write without a passed gate and approval, `--production` without the per-batch go, a read under `personal database/`, `--print-body`, a LIVE write without recorded authority.
- `CLI_FAILURE`: on any nonzero CLI or guard exit, stop the call sequence, load the tool skill's `references/troubleshooting.md`, follow its row and never reissue the call unchanged. It is separate from the unknown-request fallback and loads no migration file.

Per-row routes:

- T3: MONEYBIRD_READ through the [Bank transactions to match](../cli-moneybird/ROUTER.md#2-smart-routing) row in `cli-moneybird/ROUTER.md`.
- T4: KNOWLEDGE, then MONEYBIRD_READ `tax_rates list`, then MONEYBIRD_GATED_WRITE through the "Purchase invoice (inkoopfactuur) and attachment" row, else OPERATOR_UI.

### Ties and Abstain

- `ROUTE_MARGIN = 0.25`.
- A tie with no deciding clause abstains through tier B.

### Year and State

- Resolve the year as `year_key`: an explicit year, else the period under review, else the return-year mapping, else the clock year from `session-context.json`. A year with no folder is "no year file, unverified".
- T10, T11 and T12 use `year_key = return_coverage`.
- A figure or cross-year question before the corpus returns `year_before_corpus_start`.
- One after the corpus returns `year_after_corpus_end`. MIGRATION routing is never refused by year.
- A figure supported only by `proposed`, `unknown`, `UNVERIFIED` or `adopted-not-yet-in-force` is refused with `value_not_settled`. Keep "adopted but not yet in the Staatsblad" apart from "not adopted".
- The post-cutover state is `pre_cutover`, `monitoring_active`, `monitoring_lapsed_phase22_open`, `migration_complete` or `gate_window_conflict`. Only `monitoring_active` and `monitoring_lapsed_phase22_open` load the recurring-cycle files.
- When `interactive` is false, a tie or missing year returns the candidate routes with the question text.

Details: `references/tax-rules/year-and-state.md`.

### Smart Router Pseudocode

<!-- router-block:start -->
This block is generated from the Task-Type Table by `check-route-table.py --write`. Edit the table and rerun the mode.

```python
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent
RESOURCE_BASES = (SKILL_ROOT / "references",)
INTENT_SIGNALS = {
    "T1": [["migratie", "overzetten", "historische administratie", "Jortt", "migratiefase"], ["migration phase", "migrate", "gate", "Jortt export", "archive", "cutover", "year lock"]],
    "T2": [["migratie", "overzetten", "historische administratie", "categorie", "valkuil", "welke rekening"], ["migrate", "mapping", "category", "which account", "trap"]],
    "T3": [["deze maand", "afgelopen kwartaal", "administratie bijhouden"], ["this month", "this quarter", "review", "reconcile", "bank", "unmatched", "close"]],
    "T4": [["inkoopfactuur", "bonnetje", "factuur van een leverancier", "priv\u00e9gebruik", "zakelijk en priv\u00e9", "deels priv\u00e9", "gemengde kosten", "afschrijven", "afschrijving", "inventaris", "activeren", "activeer", "telefoonabonnement"], ["invoice", "receipt", "order", "supplier", "reverse charge", "KOR", "private use", "partly private", "mixed use", "depreciation", "depreciate", "fixed asset", "capitalise", "capitalize", "phone subscription"]],
    "T5": [["btw-tarief", "kilometervergoeding", "zelfstandigenaftrek", "ondernemersaftrek", "startersaftrek", "MKB-winstvrijstelling", "kleineondernemersregeling", "voorbelasting", "drempel", "KOR-grens", "hoeveel", "investeringsaftrek", "kleinschaligheidsinvesteringsaftrek", "KIA", "offici\u00eble tekst", "officiele tekst", "wetstekst"], ["rate", "threshold", "KOR limit", "deduction", "how much", "current year", "official text", "source library", "law text"]],
    "T6": [["vorig jaar", "sinds wanneer", "bewaarplicht", "bewaartermijn"], ["how does the rule work", "changed since", "compared with", "retention"]],
    "T7": [["haal op", "boek in", "synchroniseer"], ["read Jortt", "jortt-cli", "cli-jortt", "cli-moneybird", "moneybird-guard", "write", "batch", "approval"]],
    "T8": [["aangifte doen", "doe aangifte", "indienen", "dien", "insturen", "aanslag betalen", "periode afsluiten", "persoonlijke database"], ["filing", "file my", "file the", "file our", "submit", "pay the assessment", "lock the period", "non-Dutch tax", "private database", "personal database"]],
    "T9": [["startende ondernemer", "waar begin ik", "waar moet ik beginnen", "eerste keer"], ["where do I start", "first time", "setup"]],
    "T10": [["btw-aangifte", "aangifte omzetbelasting", "kwartaalaangifte", "btw-aangifte voorbereiden", "btw-aangifte klaarzetten", "btw-aangifte controleren", "suppletie", "correctie vorige periode"], ["VAT return", "quarterly return", "prepare the VAT return", "review the VAT return", "check the VAT return", "VAT correction", "correct a VAT error", "supplementary return"]],
    "T11": [["jaaroverzicht", "jaarrekening", "jaarafsluiting", "eindejaar", "balans opmaken", "winst-en-verliesrekening", "overlopende posten", "vooruitbetaalde kosten", "toerekenen", "priv\u00e9-opnamen", "balans en winst-en-verliesrekening", "jaaroverzicht voorbereiden", "jaarrekening klaarzetten", "jaarrekening controleren"], ["yearly overview", "annual accounts", "prepare the yearly overview", "review the annual accounts", "check the yearly overview"]],
    "T12": [["aangifte inkomstenbelasting", "IB-aangifte", "aangifte inkomstenbelasting voorbereiden", "IB-aangifte klaarzetten", "IB-aangifte controleren"], ["income tax return", "prepare the income tax return", "review the income tax return", "check the income tax return"]],
}
REQUIRED_READS = {
    "T1": ["references/migration/shared-mechanisms.md", "{phase-file}"],
    "T2": ["references/migration/jortt-to-moneybird-mapping.md"],
    "T3": ["references/moneybird-bookkeeping.md", "references/tax-rules/{year}/README.md"],
    "T4": ["references/purchase-invoices.md", "references/tax-rules/{year}/vat/figures.md", "references/moneybird-bookkeeping.md"],
    "T5": ["references/tax-rules/dutch-tax-rules.md", "{topic-figures}"],
    "T6": ["references/tax-rules/dutch-tax-rules.md@3-general-rules"],
    "T7": [],
    "T8": [],
    "T9": ["references/migration/overview-and-setup.md"],
    "T10": ["references/vat-return/README.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/vat/figures.md"],
    "T11": ["references/yearly-overview/README.md", "references/tax-rules/{year}/costs-and-car/figures.md", "references/tax-rules/{year}/investments/figures.md"],
    "T12": ["references/income-tax-return/README.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/income-tax/figures.md", "references/tax-rules/{year}/business-deductions/figures.md"],
}
CONDITIONAL_READS = {
    "T1": ["references/migration/README.md", "references/migration/control-framework.md"],
    "T2": [],
    "T3": ["references/tax-rules/{year}/vat/figures.md", "references/migration/README.md", "references/migration/phases-19-to-21.md"],
    "T4": ["references/mixed-use-costs.md", "references/fixed-assets.md"],
    "T5": ["references/tax-rules/{year}/README.md", "references/tax-rules/source-library.md@2-how-to-reach-a-source"],
    "T6": [],
    "T7": [],
    "T8": [],
    "T9": [],
    "T10": ["references/tax-rules/{year}/procedure/figures.md", "references/tax-rules/source-library.md@2-how-to-reach-a-source"],
    "T11": ["references/tax-rules/{year}/README.md", "references/fixed-assets.md"],
    "T12": ["references/tax-rules/source-library.md@2-how-to-reach-a-source"],
}
SECTION_TARGETS = {
    "T1": {},
    "T2": {},
    "T3": {},
    "T4": {},
    "T5": {"{topic-figures}": "2-key-figures", "references/tax-rules/source-library.md": "2-how-to-reach-a-source"},
    "T6": {"references/tax-rules/dutch-tax-rules.md": "3-general-rules"},
    "T7": {},
    "T8": {},
    "T9": {},
    "T10": {"references/tax-rules/source-library.md": "2-how-to-reach-a-source"},
    "T11": {},
    "T12": {"references/tax-rules/source-library.md": "2-how-to-reach-a-source"},
}
PHASE_FILES = {
    "0": "references/migration/phases-0-to-2.md",
    "1": "references/migration/phases-0-to-2.md",
    "2": "references/migration/phases-0-to-2.md",
    "3": "references/migration/phases-3-to-5.md",
    "4": "references/migration/phases-3-to-5.md",
    "5": "references/migration/phases-3-to-5.md",
    "6": "references/migration/phases-6-to-9.md",
    "7": "references/migration/phases-6-to-9.md",
    "8": "references/migration/phases-6-to-9.md",
    "9": "references/migration/phases-6-to-9.md",
    "10": "references/migration/phases-10-to-16.md",
    "11": "references/migration/phases-10-to-16.md",
    "12": "references/migration/phases-10-to-16.md",
    "13": "references/migration/phases-10-to-16.md",
    "14": "references/migration/phases-10-to-16.md",
    "15": "references/migration/phases-10-to-16.md",
    "16": "references/migration/phases-10-to-16.md",
    "17": "references/migration/phases-17-to-18.md",
    "18": "references/migration/phases-17-to-18.md",
    "19": "references/migration/phases-19-to-21.md",
    "20": "references/migration/phases-19-to-21.md",
    "21": "references/migration/phases-19-to-21.md",
    "22": "references/migration/phase-22-completion.md",
}
TOPIC_FILES = {
    "box-2": "references/tax-rules/{year}/box-2/figures.md@2-key-figures",
    "box-3": "references/tax-rules/{year}/box-3/figures.md@2-key-figures",
    "business-deductions": "references/tax-rules/{year}/business-deductions/figures.md@2-key-figures",
    "costs-and-car": "references/tax-rules/{year}/costs-and-car/figures.md@2-key-figures",
    "health-insurance-contribution": "references/tax-rules/{year}/health-insurance-contribution/figures.md@2-key-figures",
    "income-tax": "references/tax-rules/{year}/income-tax/figures.md@2-key-figures",
    "investments": "references/tax-rules/{year}/investments/figures.md@2-key-figures",
    "pension-and-disability-insurance": "references/tax-rules/{year}/pension-and-disability-insurance/figures.md@2-key-figures",
    "private-company-and-corporate-tax": "references/tax-rules/{year}/private-company-and-corporate-tax/figures.md@2-key-figures",
    "procedure": "references/tax-rules/{year}/procedure/figures.md@2-key-figures",
    "vat": "references/tax-rules/{year}/vat/figures.md@2-key-figures",
    "work-relationship": "references/tax-rules/{year}/work-relationship/figures.md@2-key-figures",
}
RESOURCE_MAP = {
    "T1": ["references/migration/shared-mechanisms.md", "{phase-file}", "references/migration/README.md", "references/migration/control-framework.md"],
    "T2": ["references/migration/jortt-to-moneybird-mapping.md"],
    "T3": ["references/moneybird-bookkeeping.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/vat/figures.md", "references/migration/README.md", "references/migration/phases-19-to-21.md"],
    "T4": ["references/purchase-invoices.md", "references/tax-rules/{year}/vat/figures.md", "references/moneybird-bookkeeping.md", "references/mixed-use-costs.md", "references/fixed-assets.md"],
    "T5": ["references/tax-rules/dutch-tax-rules.md", "references/tax-rules/{year}/README.md", "{topic-figures}", "references/tax-rules/source-library.md"],
    "T6": ["references/tax-rules/dutch-tax-rules.md"],
    "T7": [],
    "T8": [],
    "T9": ["references/migration/overview-and-setup.md"],
    "T10": ["references/vat-return/README.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/vat/figures.md", "references/tax-rules/{year}/procedure/figures.md", "references/tax-rules/source-library.md"],
    "T11": ["references/yearly-overview/README.md", "references/tax-rules/{year}/costs-and-car/figures.md", "references/tax-rules/{year}/investments/figures.md", "references/tax-rules/{year}/README.md", "references/fixed-assets.md"],
    "T12": ["references/income-tax-return/README.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/income-tax/figures.md", "references/tax-rules/{year}/business-deductions/figures.md", "references/tax-rules/source-library.md"],
}
LOADING_LEVELS = {
    "tok:T1": ["references/migration/shared-mechanisms.md", "{phase-file}", "references/migration/README.md", "references/migration/control-framework.md"],
    "tok:T2": ["references/migration/jortt-to-moneybird-mapping.md"],
    "tok:T3": ["references/moneybird-bookkeeping.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/vat/figures.md", "references/migration/README.md", "references/migration/phases-19-to-21.md"],
    "tok:T4": ["references/purchase-invoices.md", "references/tax-rules/{year}/vat/figures.md", "references/moneybird-bookkeeping.md", "references/mixed-use-costs.md", "references/fixed-assets.md"],
    "tok:T5": ["references/tax-rules/dutch-tax-rules.md", "references/tax-rules/{year}/README.md", "{topic-figures}", "references/tax-rules/source-library.md"],
    "tok:T6": ["references/tax-rules/dutch-tax-rules.md"],
    "tok:T7": [],
    "tok:T8": [],
    "tok:T9": ["references/migration/overview-and-setup.md"],
    "tok:T10": ["references/vat-return/README.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/vat/figures.md", "references/tax-rules/{year}/procedure/figures.md", "references/tax-rules/source-library.md"],
    "tok:T11": ["references/yearly-overview/README.md", "references/tax-rules/{year}/costs-and-car/figures.md", "references/tax-rules/{year}/investments/figures.md", "references/tax-rules/{year}/README.md", "references/fixed-assets.md"],
    "tok:T12": ["references/income-tax-return/README.md", "references/tax-rules/{year}/README.md", "references/tax-rules/{year}/income-tax/figures.md", "references/tax-rules/{year}/business-deductions/figures.md", "references/tax-rules/source-library.md"],
}
UNKNOWN_FALLBACK_CHECKLIST = [
    "Tier A: Refuse with the out-of-scope boundary, load nothing",
    "Tier B: Ask one question, print the candidate route per answer",
    "Tier C: Name the missing tax year, resolve it before loading",
]

CONTEXT = read_session_context("session-context.json")

def discover_markdown_resources():
    return {p.relative_to(SKILL_ROOT).as_posix() for base in RESOURCE_BASES if base.exists() for p in base.rglob("*.md") if p.is_file()}

def _guard_in_skill(relative_path):
    resolved = (SKILL_ROOT / relative_path).resolve()
    resolved.relative_to(SKILL_ROOT)
    if resolved.suffix.lower() != ".md":
        raise ValueError("local markdown only")
    return resolved.relative_to(SKILL_ROOT).as_posix()

def load_if_available(relative_path, inventory, loaded, missing):
    guarded = _guard_in_skill(relative_path)
    if guarded in inventory and guarded not in loaded:
        load(guarded)
        loaded.append(guarded)
    elif guarded not in inventory:
        missing.append(guarded)

```
<!-- router-block:end -->

### Migration Phase Routing

`references/migration/README.md` maps every phase. Advance only on the last verified exit gate, never on work that appears complete.

A Moneybird read runs with `MONEYBIRD_GUARD_READ_ONLY=1`. A write needs a passed gate, Operator approval, a flushed `WRITE_INTENT`, `payload_digest`, `--confirm-write` and `--approval`, with `--production` only for an approved production batch. The gate tokens, the evidence rule, the idempotency rule and the exit set are in the [write contract](./references/migration/shared-mechanisms.md#route-contract).
