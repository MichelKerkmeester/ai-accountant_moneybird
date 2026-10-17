---
title: sk-moneybird-accountant: Feature Catalog
description: Current feature inventory for Dutch ZZP migration, live bookkeeping, tax routing, tool handoffs, privacy boundaries, reference state and quality gates.
trigger_phrases:
  - Dutch ZZP bookkeeping
  - Jortt to Moneybird migration
  - Moneybird accounting workflow
last_updated: 2026-10-14
version: 1.0.0.0
---

# sk-moneybird-accountant: Feature Catalog

This catalog describes the current bookkeeping and migration behavior of sk-moneybird-accountant and links to the per-feature files with source and validation anchors.

---

## 1. OVERVIEW

Use this catalog as the current feature inventory. The numbered sections group the package by capability area. Each entry points to a focused reference with its implementation and offline validation anchors.

---

## 2. BOOKKEEPING AND MIGRATION

### Migration phase routing

#### Description

Selects a Jortt to Moneybird migration phase, its reference, owner tags and exit gate.

#### Current Reality

The skill routes each historical Jortt to Moneybird request through the execution-order phase map and its gate. Phase 17 is source freeze and archive readiness, Phase 18 is the live switch, Phases 19 to 21 are recurring loops that begin after Phase 18 and Phase 22 is the one-time completion and Jortt decommission gate. Shared mechanisms define write keys, the run journal, access expiry, stop recovery and the auditfile route. The route contract keeps the same tool boundaries in every phase. Jortt reads run through jortt-cli only, XAF and other Jortt exports are Operator UI tasks, Moneybird reads run through moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, a Moneybird write needs a passed gate, Operator approval, `--confirm-write` and `--approval <ref>` for a flushed `WRITE_INTENT`, plus `--production` for a production batch and an HTTP 429 stops the call sequence for a guarded read-back before any retry. The corresponding manual scenarios check routing without API access.

#### Source Files

See [`bookkeeping-and-migration/migration-phase-routing.md`](bookkeeping-and-migration/migration-phase-routing.md) for source and validation anchors.

---

### Jortt to Moneybird mapping

#### Description

Explains the Jortt to Moneybird concept mapping and the source-export traps that a migration route depends on.

#### Current Reality

The guide maps the Jortt concepts that carry into Moneybird and names the traps in the source exports. It is the read set for the migration concept row and the migration checks in it prove a mapping is complete. The offline command sequence in the tool handoff scenario reads it without an API call.

#### Source Files

See [`bookkeeping-and-migration/jortt-to-moneybird-mapping.md`](bookkeeping-and-migration/jortt-to-moneybird-mapping.md) for source and validation anchors.

---

### Migration agent route

#### Description

Defines the M12 external agent route for migration work units.

#### Current Reality

The Agent runner coordinates local role sessions, Implementer drafts, Verifier checks and Final reviewer approval. Record-level processing stays local. Agent-facing payloads contain only typed allowlisted summaries and use opaque aliases. Every phase gates the route with numeric evidence and uses verified-state resume rules.

#### Source Files

See [`bookkeeping-and-migration/migration-agent-route.md`](bookkeeping-and-migration/migration-agent-route.md) for source and validation anchors.

---

### Migration plan kit

#### Description

Ships fill-in templates and a workspace setup script so any user can run the migration phases.

#### Current Reality

`scripts/init-workspace.sh` builds `migration-workspace/` with a configuration template, a phase dashboard and a run-journal event template and copies the spec-kit template packet with one Level 3 phase packet per phase to a git-ignored working packet. It never overwrites a file. `scripts/generate-plan-kit.py --check` fails when a generated file drifts from its phase reference.

#### Source Files

See [`bookkeeping-and-migration/migration-plan-kit.md`](bookkeeping-and-migration/migration-plan-kit.md) for source and validation anchors.

---

### Migration write keys and run journal

#### Description

Defines stable local write keys and append-only run-journal evidence for each migration batch.

#### Current Reality

Every non-GET call requires a flushed `WRITE_INTENT`. Uncertain outcomes require source-reference and planned-field read-back before any retry. The offline crash scenario checks journal-based resume and no blind replay.

#### Source Files

See [`bookkeeping-and-migration/migration-write-keys-and-run-journal.md`](bookkeeping-and-migration/migration-write-keys-and-run-journal.md) for source and validation anchors.

---

### Migration archive and decommission gate

#### Description

Keeps Jortt available until final archive, monitoring and completion checks pass.

#### Current Reality

Phase 17 verifies source freeze and archive readiness. Phase 22 is the one-time completion gate. An early cancellation request is refused and routed to the Operator decision after Phase 22.

#### Source Files

See [`bookkeeping-and-migration/migration-archive-decommission-gate.md`](bookkeeping-and-migration/migration-archive-decommission-gate.md) for source and validation anchors.

---

### Migration trial and package expiry

#### Description

Checks trial or paid-package coverage before each non-GET batch and before final verification.

#### Current Reality

A missing, expired or uncertain access window stops the batch. The offline scenario verifies that expiry before a write prevents the write.

#### Source Files

See [`bookkeeping-and-migration/migration-trial-and-package-expiry.md`](bookkeeping-and-migration/migration-trial-and-package-expiry.md) for source and validation anchors.

---

### Migration stop and resume

#### Description

Routes a stopped migration through its owner, evidence, retry rule and closure test.

#### Current Reality

Batches resume from the last verified journal state only after the stop closure condition passes. The crash scenario checks this behavior for an uncertain write.

#### Source Files

See [`bookkeeping-and-migration/migration-stop-and-resume.md`](bookkeeping-and-migration/migration-stop-and-resume.md) for source and validation anchors.

---

### Migration auditfile export route

#### Description

Routes an auditfile request through the documented export path while preserving the read-only lock.

#### Current Reality

Phase 0 verifies the route. The Operator UI export is preferred. A guarded POST requires a scoped allowance, approval and artifact receipt hash. The offline scenario verifies that the global lock is not weakened.

#### Source Files

See [`bookkeeping-and-migration/migration-auditfile-export-route.md`](bookkeeping-and-migration/migration-auditfile-export-route.md) for source and validation anchors.

---

### Live bookkeeping cadence

#### Description

Routes current monthly, quarterly and yearly bookkeeping through the appropriate review steps.

#### Current Reality

The LIVE mode guides recurring bookkeeping for current periods. It separates monthly reconciliation, quarterly VAT review and yearly close work. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/live-bookkeeping-cadence.md`](bookkeeping-and-migration/live-bookkeeping-cadence.md) for source and validation anchors.

---

### VAT return (btw-aangifte) preparation

#### Description

Entry index for preparing a Dutch VAT period from Moneybird. The folder holds the ordered procedure, the section and derivation rules, the year-end branch and the review pack. It prepares and never files, submits or pays.

#### Current Reality

The T10 row routes a prepare-the-VAT-return request into `references/vat-return/`. The folder offers the ordered period procedure steps 0 to 12, the section (rubriek) table 1a to 5b with its derivation map and its reverse-charge, small businesses scheme (kleineondernemersregeling, KOR), ICP and OSS rules, the four year-end settlements, the correction routing and the review pack P1 to P9. Every figure is a link into the year files and every human decision carries an `[Operator]` marker. The five branch scenarios VAT-001 to VAT-005, the gold rows VAT-BRANCH-Q1-01 to VAT-BRANCH-COR-01 and the matching eval cases prove the branches offline. The folder prepares and never files, submits or pays.

#### Source Files

See [`bookkeeping-and-migration/vat-return-preparation.md`](bookkeeping-and-migration/vat-return-preparation.md) for source and validation anchors.

---

### Yearly overview (jaaroverzicht) preparation

#### Description

Entry index for preparing a Dutch sole-trader yearly overview in Moneybird. The folder holds the ordered close steps, the preparation checklist, the fiscal reconciliation and the report and export limits. It prepares and never files.

#### Current Reality

The T11 row routes a prepare-the-yearly-overview request into `references/yearly-overview/`. The README holds the ordered close steps and the eleven Dutch close signals, the checklist puts the auditfile export before the year-end closing (jaarafsluiting) as an evidence gate, and the close checks cover the equity continuity and the exception list. The fiscal reconciliation file holds the reconciliation template, the three-column hand-off template and the prepared-not-filed stop. `assets/yearly-overview/yearly-overview-template.html` is the printable A4 layout with bilingual labels and a braced placeholder for every value. Scenario PACK-001, gold row PACK-YEARLY-01 and eval case yearly-overview-pack prove the offline route and the pack blocks. The yearly-overview-template suite proves the template structure: a synthetic fill leaves no brace token, no remote asset and no unescaped value, the repeat blocks expand to the requested count and the prepared-not-filed line stays. Outside the migration route contract and the LIVE workflows of phases 19 to 21 the auditfile export is the Operator's UI export. The folder prepares and never files.

#### Source Files

See [`bookkeeping-and-migration/yearly-overview-preparation.md`](bookkeeping-and-migration/yearly-overview-preparation.md) for source and validation anchors.

---

### Income tax return (aangifte inkomstenbelasting) preparation

#### Description

Entry index for preparing a Dutch sole-trader income tax return from Moneybird. The folder holds the ordered procedure, the Operator input checklist, the investment and claim register and the residual open points. It prepares and never files, submits or pays.

#### Current Reality

The T12 row routes a prepare-the-income-tax-return request into `references/income-tax-return/`. The procedure runs the ordered cross-year steps with a source map, the evidence gates, the review pack and the stop rules. The Operator input checklist gives every item one disposition from `supplied`, `reconciled`, `confirmed`, `not applicable` or `unresolved`, and an item that cannot be settled stays `unresolved` instead of being filled from memory. The investment and claim register is the dated per-asset record with braced placeholder amounts and the residual open points stay named. Scenario PACK-002, gold row PACK-INCOME-01 and eval case income-tax-return-pack prove the pack offline. Filing and payment stay Operator-only.

#### Source Files

See [`bookkeeping-and-migration/income-tax-return-preparation.md`](bookkeeping-and-migration/income-tax-return-preparation.md) for source and validation anchors.

---

### Purchase invoice (inkoopfactuur) booking

#### Description

Routes the booking of a purchase invoice, receipt or order to the flow and VAT rate (btw-tarief) that fit the invoice.

#### Current Reality

The purchase invoice reference sorts each invoice into a case: Dutch VAT, reverse charge from an EU or non-EU supplier, foreign VAT, import or domestic reverse charge. Each case names its Moneybird VAT rate and VAT return section (rubriek). The corresponding manual scenario checks route selection and the write boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/purchase-invoice-booking.md`](bookkeeping-and-migration/purchase-invoice-booking.md) for source and validation anchors.

---

### Mixed-use cost booking

#### Description

Routes a cost used partly for the business and partly privately to the business share, the VAT split and the Moneybird booking.

#### Current Reality

The mixed-use reference covers a phone subscription, a home internet connection, a handset and the fixed home telephone line. It states the income tax share, the VAT share, the evidence the business share needs and the Moneybird split of the private part. A good above the asset threshold follows the fixed asset route. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/mixed-use-cost-booking.md`](bookkeeping-and-migration/mixed-use-cost-booking.md) for source and validation anchors.

---

### Fixed asset booking

#### Description

Routes a large purchase or an equipment item to the cost-or-asset test, depreciation, the VAT revision period and the Moneybird asset screens.

#### Current Reality

The fixed asset reference states when a purchase is capitalised, the small-amount rule, the depreciation base and yearly limit, VAT on an asset and its revision period and disposal. It names the Moneybird asset (bezitting) flow and the existing-asset opening path. A building or a change of use inside the revision period goes to the Operator or a bookkeeper. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/fixed-asset-booking.md`](bookkeeping-and-migration/fixed-asset-booking.md) for source and validation anchors.

---

### Year-specific ZZP guidance

#### Description

Checks the tax year and sources general Dutch ZZP income tax, VAT, cost and administration guidance.

#### Current Reality

The skill explains general Dutch sole-trader rules with year-specific source links. It labels conflicting and unverified facts and escalates personal eligibility decisions. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/year-specific-zzp-guidance.md`](bookkeeping-and-migration/year-specific-zzp-guidance.md) for source and validation anchors.

---

### External source library

#### Description

Lists every external source the skill family cites, with its authority and how an agent can reach it, so a figure can be traced to the page that states it.

#### Current Reality

The source library reference groups the cited sources by authority, names the most-cited statutes and pages and records any dead link. A generated index holds one row per source with its access result, digest and citing files and a builder checks it for drift, for cited dead rows and for perishable parliamentary links without any network call. The builder also checks the reference frontmatter field set and the sourced term map, where every row carries its English gloss and the source the owning year file cites. A monthly job watches the publication series in the watchlist and checks the year files against the release calendar in the year rollover runbook. The corresponding manual scenario checks the route to the library and the access method without API access.

#### Source Files

See [`bookkeeping-and-migration/external-source-library.md`](bookkeeping-and-migration/external-source-library.md) for source and validation anchors.

---

### Task type routing

#### Description

Classifies each request to a task type that decides the tool route, read set, token budget and tie rule.

#### Current Reality

The skill scores the Dutch and English signal columns of the Task-Type Table in ROUTER.md section 2 and routes each request to exactly one task type of that table. The table holds twelve rows. T10 prepares the VAT return, T11 prepares the yearly overview and T12 prepares the income tax return, each with a marked read set and a tie outcome. T8 wins over all three when an explicit file, submit, pay or lock request is present. Each row names its tool route, its read set, a token budget key such as `tok:T3` and a tie rule that settles overlaps before the route margin is applied. A read-set cell uses the `!`, `?`, `@section-id`, `{year}`, `{phase-file}` and `{topic-figures}` grammar and `check-route-table.py` fails a missing required path or anchor and lists a missing conditional read. A near tie abstains, names the candidate rows and asks one question. The CLI action row is additive and never wins alone. Every answer ends with a route record that names the selected row, the references read and the boundary result. The corresponding manual scenarios check route selection and the stated boundary without API access. The router block in ROUTER.md section 2 and the advisor intent signals are generated from the table by `check-route-table.py --write` and its check fails on drift. The route replay harness, the eval grader and the route table suite test the same routes and refusals on every push.

#### Source Files

See [`bookkeeping-and-migration/task-type-routing.md`](bookkeeping-and-migration/task-type-routing.md) for source and validation anchors.

---

### CLI tool handoff

#### Description

Routes Jortt reads through jortt-cli and Moneybird reads or writes through moneybird-guard.

#### Current Reality

The skill does not reproduce CLI mechanics. It hands Jortt reads to jortt-cli and Moneybird reads or writes to moneybird-guard through cli-jortt and cli-moneybird. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/api-tool-handoff.md`](bookkeeping-and-migration/api-tool-handoff.md) for source and validation anchors.

---

### Migration data privacy

#### Description

Keeps migration records in migration-workspace and limits private-database reads to a named file during migration.

#### Current Reality

The project bootstrap and skill set a strict boundary around private finance records. The agent does not list or search the private database and stores migration work only in migration-workspace. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/migration-data-privacy.md`](bookkeeping-and-migration/migration-data-privacy.md) for source and validation anchors.

---

### Operator tax boundary

#### Description

Leaves return filing and final tax judgement with the operator or a bookkeeper.

#### Current Reality

The skill can organize evidence and explain general rules, but it does not file returns or present personal tax conclusions as final. A file, submit, pay or lock request routes to T8 and receives the refusal, never a prepared return, and T8 wins over T10, T11 and T12. The refusal fixtures replay the four forms through the guard stub and the eval case forbids a claimed filing action. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [`bookkeeping-and-migration/operator-tax-boundary.md`](bookkeeping-and-migration/operator-tax-boundary.md) for source and validation anchors.

---

## 3. REFERENCE AND STATE

### Tax knowledge base

#### Description

Holds the Dutch tax knowledge base tree with the eight year folders, the general topic files and the five cross-year files, and routes a figure question through the year index.

#### Current Reality

The tree sits at `references/tax-rules/`. Eight year folders cover 2020 to 2027, each with twelve topic folders, a year README, a correction log and a year change note. Every topic folder holds `figures.md`, `rules.md`, `examples.md` and `notes.md`, and `split-manifest.json` hashes every part. The 13 general topic files sit under `general/`. A figure question resolves the year first, then reads the year README and the one part it names. A cross-year rule question reads section 3 of `dutch-tax-rules.md` and then only the one general file its table names. `check-route-table.py` runs the split check and `check-fragments.py` resolves every link into and inside the tree.

#### Source Files

See [`reference-and-state/tax-knowledge-base.md`](reference-and-state/tax-knowledge-base.md) for source and validation anchors.

---

### Session context and year resolution

#### Description

Writes the git-ignored session context from the clock and a migration projection and resolves the tax year and post-cutover state at route time.

#### Current Reality

The builder writes the git-ignored `session-context.json` from the allowlisted fields of the migration config and the phase dashboard. The reference resolves `year_key`, refuses an out-of-range or unsettled figure and computes the post-cutover state. The offline suite covers the clock, the allowlist, staleness and the state names.

#### Source Files

See [`reference-and-state/session-context-and-year-state.md`](reference-and-state/session-context-and-year-state.md) for source and validation anchors.

---

### Reference index and year changes

#### Description

Regenerates the reference nav blocks, the index, the year README tables and the year changes overview from the files that own them.

#### Current Reality

The generator owns the nav blocks, `references/index.json`, the year README tables, the year-figure rows in the general topic files, the year change blocks, `references/tax-rules/year-changes.md` and the reachability report. A check run reports drift without writing and the offline suite proves the fence rules and byte stability.

#### Source Files

See [`reference-and-state/reference-index-and-year-changes.md`](reference-and-state/reference-index-and-year-changes.md) for source and validation anchors.

---

### Reference entry surfaces

#### Description

Publishes the generated reference landing page, the key figure item index, the answer surface field and labels, the sourced term glosses and the scannability report that measures the first answer.

#### Current Reality

`build-reference-index.py` writes `references/README.md` with three per-group blocks, one item index row per value row inside every value table and an `answerSurface` object with `section`, `rows` and `tokens` on every record in `references/index.json`. Every reference markdown file carries a `nav_label`. `assets/term-map.json` holds one row per Dutch term with its English gloss and the source the owning year file cites, and `build-source-library.py` checks the map. `benchmark/reports/scannability/report.md` publishes the tokens to first answer, the answer position inside the section and the section hit rate, each with the denominator of its own split.

#### Source Files

See [`reference-and-state/reference-entry-surfaces.md`](reference-and-state/reference-entry-surfaces.md) for source and validation anchors.

---

### PDF source reader

#### Description

Reads the `pdf-needs-reader` rows of the source library through poppler so a source behind a PDF download can be checked.

#### Current Reality

`scripts/read-pdf-source.py` accepts a URL only when `assets/source-library.json` records it with access `pdf-needs-reader`, downloads it into a fresh temp directory, extracts the text with `pdftotext -layout -enc UTF-8` and prints it, with an optional page range. `--file` reads a saved PDF with no network call, `--list` prints the 29 rows offline and a missing `pdftotext` exits 3 and names `brew install poppler`. It reads the text layer only, so no OCR runs, and an extraction that holds only whitespace exits 4 with the HTML page or the Operator named as a fallback. The reader never writes inside the repository and the offline suite proves the argument passing, the refusals, the 29 rows and a loopback download.

#### Source Files

See [`reference-and-state/pdf-source-reader.md`](reference-and-state/pdf-source-reader.md) for source and validation anchors.

---

### Hub and packet routers

#### Description

Makes the repository root a hub that picks the accountant, Moneybird CLI or Jortt CLI packet, with each packet's routing in a ROUTER.md beside its SKILL.md.

#### Current Reality

The root `SKILL.md` picks the packet from `mode-registry.json` and `hub-router.json`, with the accountant packet as the default. Each packet holds its routing in `ROUTER.md` and its contract in `SKILL.md`, so a request reads only the routing of the packets it uses. `check-route-table.py` reads the route table from `sk-moneybird-accountant/ROUTER.md` and fails on a missing hub file, a packet without a router, a stage one default the registry does not name or a router left in a packet `SKILL.md`.

#### Source Files

See [`reference-and-state/hub-and-packet-routers.md`](reference-and-state/hub-and-packet-routers.md) for source and validation anchors.

---

### Glossary router

#### Description

Holds every English and Dutch term pair in one file per topic behind a router README, and lets a route read the glossary of the topics it loads when a request asks what a Dutch term means.

#### Current Reality

`references/glossary/README.md` lists 16 category files, one per tax-rules topic plus `bookkeeping.md`, `general.md`, `official-names.md` and `abbreviations.md`, and each pair lives in exactly one of them. A term goes to the topic holding at least half of its uses, else to `general.md`. The accountant `ROUTER.md` states one rule: a request that asks what a Dutch term means or its English name also reads the router, the glossary file of the term and the glossary file of each topic its route reads. The resolver applies it after the route's own reads and on a term request that abstains. A refusal reads no glossary file, a request that asks no meaning reads none and `check-route-table.py` fails on a missing rule, glossary file or router link.

#### Source Files

See [`reference-and-state/glossary-router.md`](reference-and-state/glossary-router.md) for source and validation anchors.

---

### Topic file split

#### Description

Holds every year topic as four part files and the general topics as 13 files, and proves with a hashed manifest that no part drifted after the split.

#### Current Reality

Each year topic is a folder of `figures.md`, `rules.md`, `examples.md` and `notes.md`, and the general topics of `dutch-tax-rules.md` sit in `references/tax-rules/general/`. Every citation names the part that holds its line or heading, and a bare topic path points at `figures.md`. Tracked names use their English form and a reviewed rename lands through the accept-renames mode. The manifest hashes each part body and header and the kept entry file, and `check-route-table.py` runs the check so CI fails on a drifted part.

#### Source Files

See [`reference-and-state/topic-file-split.md`](reference-and-state/topic-file-split.md) for source and validation anchors.

---

### Year rollover runbook

#### Description

Runs the yearly corpus rollover and keeps the year files checked against the release calendar the runbook owns.

#### Current Reality

The runbook carries the corpus into the next tax year with its sources and checked dates. The calendar check compares the year files with the release checkpoints and the monthly watch reports a changed publication series or a page that goes live. The runbook also owns the carry-forward rule, which states that every condition names its alternative or its default, and `outline-check.py` enforces the rule over the year and general topic files.

#### Source Files

See [`reference-and-state/year-rollover-runbook.md`](reference-and-state/year-rollover-runbook.md) for source and validation anchors.

---

## 4. QUALITY GATES

### Fragment link check

#### Description

Resolves every relative link and fragment in the skill family and enforces the year-file section ids.

#### Current Reality

The check resolves every relative link and fragment across the bootstrap, the README and the skill markdown. It rejects a duplicate-suffix slug and reports a missing or out-of-order year section id. The twelve ordinal pointers in the top layer are fragment links the check resolves by path and heading slug. It also counts the sections that open with a positional reference and prints the count with a threshold beside its own findings. The offline suite proves both directions on fixtures and the real corpus.

#### Source Files

See [`quality-gates/fragment-link-check.md`](quality-gates/fragment-link-check.md) for source and validation anchors.

---

### Outline check

#### Description

Checks the carry-forward rule over the year and general topic files and reports every decision step that names no alternative or default branch.

#### Current Reality

`outline-check.py` reads the split part files below `references/tax-rules/`, a flat year topic file and the general topic files beside them, skips the year README, the changelog, the change note and fenced code blocks, and requires a branch on every decision step without judging it. The rule it enforces is stated in `references/tax-rules/year-rollover.md`. The run prints one line per step that names no branch and then the count line. `check-route-table.py` runs the check beside the word and split checks, so the skill health job fails on a decision step that names none, and `outline-check-test.sh` proves the accepted and rejected shapes on a fixture repository.

#### Source Files

See [`quality-gates/outline-check.md`](quality-gates/outline-check.md) for source and validation anchors.

---

### English first check

#### Description

Checks that the skill family writes English first and reports every Dutch term without an English lead, every first use without its Dutch label and every label no glossary row names.

#### Current Reality

`check-english-first.py` reads every category file in `references/glossary/`, scans its router README as prose and reads `assets/english-first-exceptions.json`, blanks the places where Dutch is data, such as code, links, quotes, legal citations, Source columns and the playbook prompts, and then reports residual, first-use, doubled, reversed, unglossed and duplicate problems plus any exception that suppresses nothing. The run prints sorted lines and a count line and makes no network call. The skill health workflow runs `check-english-first-test.sh`, which proves every rule and mask on fixtures and ends with the real corpus.

#### Source Files

See [`quality-gates/english-first-check.md`](quality-gates/english-first-check.md) for source and validation anchors.

---

### Write contract check

#### Description

Checks every write-contract restatement in the bootstrap and skill files against the one canonical contract.

#### Current Reality

The shared mechanisms file owns the canonical contract. The check parses the canonical parts and fails a restatement that drops a gate token, changes the read-back sentence or names an exit outside the canonical set.

#### Source Files

See [`quality-gates/write-contract-check.md`](quality-gates/write-contract-check.md) for source and validation anchors.

---

### Token budget baseline

#### Description

Pins the token counts of the reference corpus and fails when a reference change moves a budgeted row.

#### Current Reality

The baseline counts the reference corpus and the named units in the pinned encodings and fails when a reference change moves a budgeted row. The canary covers the car-question route and its token ceiling. A sibling word check holds each `SKILL.md` and `ROUTER.md` at a 3,000-word loading budget with a 4,000-word ceiling and `check-route-table.py` runs it beside the baseline check.

#### Source Files

See [`quality-gates/token-budget-baseline.md`](quality-gates/token-budget-baseline.md) for source and validation anchors.

---

### Hostile invoice set

#### Description

Guards the untrusted-content rule with a scored corpus and refuses a set that drifts from its declared shape.

#### Current Reality

The synthetic case set holds attack, twin and control invoices with placeholder values only. The shape check proves the corpus, the score mode compares the observed rates with the Operator thresholds and the offline suite seeds the broken shapes.

#### Source Files

See [`quality-gates/hostile-invoice-set.md`](quality-gates/hostile-invoice-set.md) for source and validation anchors.

---

### Route replay harness

#### Description

Scores the routing corpus offline and replays the refusal and hostile rows through the guard and the stub.

#### Current Reality

The harness builds a router snapshot from the table, the routing constants and the resource map. Resolve mode scores the corpus and replay mode runs the guard against the stub and the suite proves both modes on a temp copy. The corpus covers the T10 to T12 prepare rows, the five VAT branch rows, the two pack rows and the four refusal forms with their guard twins.

#### Source Files

See [`quality-gates/route-replay-harness.md`](quality-gates/route-replay-harness.md) for source and validation anchors.

---

### Eval grader

#### Description

Grades captured answers against the eval assertion blocks and writes the pass rates and the skill hash.

#### Current Reality

The grader checks the required tokens and forbidden patterns of every eval case and writes the per-case rows, the pass rates and the skill hash. The case set covers the five VAT branches, the yearly overview (jaaroverzicht) pack, the income tax return (aangifte inkomstenbelasting) pack and the tax-deliverable filing refusal. No model judges an answer, so a captured run still gets a human read.

#### Source Files

See [`quality-gates/eval-grader.md`](quality-gates/eval-grader.md) for source and validation anchors.

---

### Hardening matrix check

#### Description

Fails a P0 matrix row whose test path or case name no longer exists.

#### Current Reality

The matrix holds one row per failure mode with its control, test, owner and status. The check fails a P0 row whose test path is missing or whose case name no longer occurs in that file.

#### Source Files

See [`quality-gates/hardening-matrix-check.md`](quality-gates/hardening-matrix-check.md) for source and validation anchors.

---

### Regression trailer check

#### Description

Requires a covering test or a Regression-Test trailer when a guarded file changes in one commit.

#### Current Reality

A commit that changes a guarded file needs a covering test change or a `Regression-Test:` trailer naming a registered test that exists at that commit. The suite proves the refusal, the valid trailer and the deleted-test case on fixture repositories.

#### Source Files

See [`quality-gates/regression-trailer-check.md`](quality-gates/regression-trailer-check.md) for source and validation anchors.

---

### Privacy gate

#### Description

Blocks personal or finance data in the tracked tree, a commit message and a pushed range before it leaves the machine.

#### Current Reality

The gate scans the index, the tree, the history, a commit message or a drafted answer and masks every finding. The hooks call it before a commit and a push, a gate-file change needs the Operator approval trailer and the suite proves every pattern.

#### Source Files

See [`quality-gates/privacy-gate.md`](quality-gates/privacy-gate.md) for source and validation anchors.

---

### Repository CI gates

#### Description

Runs the plan kit, privacy and skill health workflows that check this package on every push and pull request.

#### Current Reality

The plan kit, privacy and skill health workflows check the package on every push and pull request. The skill health links job runs on a schedule and reports a changed watch or a stale year as an issue.

#### Source Files

See [`quality-gates/repository-ci-gates.md`](quality-gates/repository-ci-gates.md) for source and validation anchors.

---
