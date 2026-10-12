---
title: sk-moneybird-accountant: Feature Catalog
description: Current feature inventory for Dutch ZZP migration, live bookkeeping, tax routing, tool handoffs, and privacy boundaries.
trigger_phrases:
  - Dutch ZZP bookkeeping
  - Jortt to Moneybird migration
  - Moneybird accounting workflow
last_updated: 2026-10-10
version: 1.0.0.0
---

# sk-moneybird-accountant: Feature Catalog

This catalog describes the current bookkeeping and migration behavior of sk-moneybird-accountant and links to the per-feature files with source and validation anchors.

---

## 1. OVERVIEW

Use this catalog as the current feature inventory. Each entry points to a focused reference with its implementation and offline validation anchors.

---

## 2. BOOKKEEPING AND MIGRATION

### Migration phase routing

#### Description

Selects a Jortt to Moneybird migration phase, its reference, owner tags, and exit gate.

#### Current Reality

The skill routes each historical Jortt to Moneybird request through the execution-order phase map and its gate. Phase 17 is source freeze and archive readiness, Phase 18 is the live switch, Phases 19 to 21 are recurring loops that begin after Phase 18, and Phase 22 is the one-time completion and Jortt decommission gate. Shared mechanisms define write keys, the run journal, access expiry, stop recovery, and the auditfile route. The route contract keeps the same tool boundaries in every phase. Jortt reads run through jortt-cli only, XAF and other Jortt exports are Operator UI tasks, Moneybird reads run through moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, a Moneybird write needs a passed gate, Operator approval, `--confirm-write` and `--approval <ref>` for a flushed `WRITE_INTENT`, plus `--production` for a production batch, and an HTTP 429 stops the call sequence for a guarded read-back before any retry. The corresponding manual scenarios check routing without API access.

#### Source Files

See [bookkeeping-and-migration/migration-phase-routing.md](bookkeeping-and-migration/migration-phase-routing.md) for source and validation anchors.

---

### Migration agent route

#### Description

Defines the M12 external agent route for migration work units.

#### Current Reality

The Agent runner coordinates local role sessions, Implementer drafts, Verifier checks, and Final reviewer approval. Record-level processing stays local. Agent-facing payloads contain only typed allowlisted summaries and use opaque aliases. Every phase gates the route with numeric evidence and uses verified-state resume rules.

#### Source Files

See [bookkeeping-and-migration/migration-agent-route.md](bookkeeping-and-migration/migration-agent-route.md) for source and validation anchors.

---

### Migration plan kit

#### Description

Ships fill-in templates and a workspace setup script so any user can run the 23 migration phases.

#### Current Reality

`scripts/init-workspace.sh` builds `migration-workspace/` with a configuration template, a phase dashboard and a run-journal event template, and copies the spec-kit template packet with 23 Level 3 phase packets to a git-ignored working packet. It never overwrites a file. `scripts/generate-plan-kit.py --check` fails when a generated file drifts from its phase reference.

#### Source Files

See [bookkeeping-and-migration/migration-plan-kit.md](bookkeeping-and-migration/migration-plan-kit.md) for source and validation anchors.

---

### Migration write keys and run journal

#### Description

Defines stable local write keys and append-only run-journal evidence for each migration batch.

#### Current Reality

Every non-GET call requires a flushed `WRITE_INTENT`. Uncertain outcomes require source-reference and planned-field read-back before any retry. The offline crash scenario checks journal-based resume and no blind replay.

#### Source Files

See [bookkeeping-and-migration/migration-write-keys-and-run-journal.md](bookkeeping-and-migration/migration-write-keys-and-run-journal.md) for source and validation anchors.

---

### Migration archive and decommission gate

#### Description

Keeps Jortt available until final archive, monitoring, and completion checks pass.

#### Current Reality

Phase 17 verifies source freeze and archive readiness. Phase 22 is the one-time completion gate. An early cancellation request is refused and routed to the Operator decision after Phase 22.

#### Source Files

See [bookkeeping-and-migration/migration-archive-decommission-gate.md](bookkeeping-and-migration/migration-archive-decommission-gate.md) for source and validation anchors.

---

### Migration trial and package expiry

#### Description

Checks trial or paid-package coverage before each non-GET batch and before final verification.

#### Current Reality

A missing, expired, or uncertain access window stops the batch. The offline scenario verifies that expiry before a write prevents the write.

#### Source Files

See [bookkeeping-and-migration/migration-trial-and-package-expiry.md](bookkeeping-and-migration/migration-trial-and-package-expiry.md) for source and validation anchors.

---

### Migration stop and resume

#### Description

Routes a stopped migration through its owner, evidence, retry rule, and closure test.

#### Current Reality

Batches resume from the last verified journal state only after the stop closure condition passes. The crash scenario checks this behavior for an uncertain write.

#### Source Files

See [bookkeeping-and-migration/migration-stop-and-resume.md](bookkeeping-and-migration/migration-stop-and-resume.md) for source and validation anchors.

---

### Migration auditfile export route

#### Description

Routes an auditfile request through the documented export path while preserving the read-only lock.

#### Current Reality

Phase 0 verifies the route. The Operator UI export is preferred. A guarded POST requires a scoped allowance, approval, and artifact receipt hash. The offline scenario verifies that the global lock is not weakened.

#### Source Files

See [bookkeeping-and-migration/migration-auditfile-export-route.md](bookkeeping-and-migration/migration-auditfile-export-route.md) for source and validation anchors.

---

### Live bookkeeping cadence

#### Description

Routes current monthly, quarterly, and yearly bookkeeping through the appropriate review steps.

#### Current Reality

The LIVE mode guides recurring bookkeeping for current periods. It separates monthly reconciliation, quarterly VAT review, and yearly close work. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/live-bookkeeping-cadence.md](bookkeeping-and-migration/live-bookkeeping-cadence.md) for source and validation anchors.

---

### Purchase invoice booking

#### Description

Routes the booking of a purchase invoice, receipt or order to the flow and VAT rate that fit the invoice.

#### Current Reality

The purchase invoice reference sorts each invoice into a case: Dutch VAT, reverse charge from an EU or non-EU supplier, foreign VAT, import or domestic reverse charge. Each case names its Moneybird VAT rate and VAT return rubriek. The corresponding manual scenario checks route selection and the write boundary without API access.

#### Source Files

See [bookkeeping-and-migration/purchase-invoice-booking.md](bookkeeping-and-migration/purchase-invoice-booking.md) for source and validation anchors.

---

### Year-specific ZZP guidance

#### Description

Checks the tax year and sources general Dutch ZZP income tax, VAT, cost, and administration guidance.

#### Current Reality

The skill explains general Dutch sole-trader rules with year-specific source links. It labels conflicting and unverified facts and escalates personal eligibility decisions. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/year-specific-zzp-guidance.md](bookkeeping-and-migration/year-specific-zzp-guidance.md) for source and validation anchors.

---

### External source library

#### Description

Lists every external source the skill family cites, with its authority and how an agent can reach it, so a figure can be traced to the page that states it.

#### Current Reality

The source library reference groups the cited sources by authority, names the most-cited statutes and pages, and records dead links. A generated index holds one row per source with its access result and citing files, and a builder checks it for drift without any network call. The corresponding manual scenario checks the route to the library and the access method without API access.

#### Source Files

See [bookkeeping-and-migration/external-source-library.md](bookkeeping-and-migration/external-source-library.md) for source and validation anchors.

---

### Task type routing

#### Description

Classifies each request to one of nine task types that decide the tool route, read set, token budget, and tie rule.

#### Current Reality

The skill scores the Dutch and English signal columns of the Task-Type Table in SKILL.md section 2 and routes each request to exactly one of the nine task types T1 to T9. Each row names its tool route, its read set, a token budget key such as `tok:T3`, and a tie rule that settles overlaps before the route margin is applied. A near tie abstains, names the candidate rows, and asks one question. The CLI action row is additive and never wins alone. Every answer ends with a route record that names the selected row, the references read, and the boundary result. The corresponding manual scenarios check route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/task-type-routing.md](bookkeeping-and-migration/task-type-routing.md) for source and validation anchors.

---

### CLI tool handoff

#### Description

Routes Jortt reads through jortt-cli and Moneybird reads or writes through moneybird-guard.

#### Current Reality

The skill does not reproduce CLI mechanics. It hands Jortt reads to jortt-cli and Moneybird reads or writes to moneybird-guard through cli-jortt and cli-moneybird. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/api-tool-handoff.md](bookkeeping-and-migration/api-tool-handoff.md) for source and validation anchors.

---

### Migration data privacy

#### Description

Keeps migration records in migration-workspace and limits private-database reads to a named file during migration.

#### Current Reality

The project bootstrap and skill set a strict boundary around private finance records. The agent does not list or search the private database and stores migration work only in migration-workspace. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/migration-data-privacy.md](bookkeeping-and-migration/migration-data-privacy.md) for source and validation anchors.

---

### Operator tax boundary

#### Description

Leaves return filing and final tax judgement with the operator or a bookkeeper.

#### Current Reality

The skill can organize evidence and explain general rules, but it does not file returns or present personal tax conclusions as final. The corresponding manual scenario checks route selection and the stated boundary without API access.

#### Source Files

See [bookkeeping-and-migration/operator-tax-boundary.md](bookkeeping-and-migration/operator-tax-boundary.md) for source and validation anchors.

---
