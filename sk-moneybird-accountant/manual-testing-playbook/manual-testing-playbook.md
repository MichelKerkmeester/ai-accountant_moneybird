---
title: sk-moneybird-accountant: Manual Testing Playbook
description: Offline scenarios for verifying mode selection, reference routing, CLI handoffs, tax boundaries, and privacy rules.
version: 1.0.0.0
---

# sk-moneybird-accountant: Manual Testing Playbook

This playbook contains offline routing checks for the Dutch sole-trader bookkeeping and migration skill. It checks local instruction routing only and makes no Jortt, Moneybird, web, or tax authority API calls.

---

This package keeps global review rules here and prompt-level execution evidence in its per-feature files.

Canonical package artifacts:
- manual-testing-playbook.md
- offline-routing/

### Result persistence

<!-- MANUAL_PLAYBOOK_RESULT_PERSISTENCE_CONTRACT -->
A scenario run is complete only after its PASS, FAIL, or SKIP outcome and reason are recorded in the skill benchmark reports for that run. SKIP must name a specific sandbox or runtime blocker.

---

## 1. OVERVIEW

The scenarios validate current mode selection, reference routing, CLI ownership boundaries, tax limits, and privacy behavior. The root index links each scenario to its execution file and matching feature catalog entry.

Coverage note: this package checks local routing and policy. It does not call external services.

---

## 2. GLOBAL PRECONDITIONS

1. Work from the repository root.
2. Treat the private database path as inaccessible during these checks.
3. Read only the named public system files and skill references in each scenario.
4. Do not call a Jortt, Moneybird, browser, network, or tax authority API.
5. Keep any scenario notes in the skill benchmark reports.

---

## 3. GLOBAL EVIDENCE REQUIREMENTS

- User prompt used
- Selected mode and phase where applicable
- Exact reference paths read
- Owner tags and gate decisions when migration is in scope
- API-free confirmation
- Pass or fail rationale

---

## 4. DETERMINISTIC COMMAND NOTATION

- Local document reads are written as Read followed by a repository-relative path.
- Agent reasoning steps are written as agent followed by the expected action.
- The arrow symbol separates sequential steps.
- The listed steps never include an API call.

---

## 5. REVIEW PROTOCOL AND RELEASE READINESS

### Inputs Required

1. Root playbook
2. Referenced scenario files
3. Scenario execution evidence
4. Feature-to-scenario coverage map
5. Triage notes for all non-pass outcomes

### Scenario Acceptance Rules

For each executed scenario, check that the preconditions were met, the prompt and steps were followed, expected signals are present, evidence is readable, and the outcome rationale is explicit.

- PASS means all acceptance checks are true.
- FAIL means expected behavior is missing or contradicts the skill.
- SKIP means a specific sandbox or runtime blocker prevented execution.

### Feature Verdict Rules

- PASS when every mapped scenario passes.
- FAIL when any mapped scenario fails.
- SKIP when every mapped scenario is blocked by a named sandbox or runtime blocker.

A failure on a critical route makes the feature fail. Release readiness requires all scenarios to be accounted for and no unresolved blocking triage item.

### Root and feature rule

Keep package-level evidence rules here. Keep scenario-specific acceptance criteria in the matching feature file.

---

## 6. SINGLE-RUNNER EXECUTION

These checks read local public documentation. One runner can execute them in order without delegation. Keep each scenario independent and record its evidence before starting another.

1. Confirm the repository root and local documents are available.
2. Run each prompt against the skill in an offline context.
3. Record the selected mode, source paths, and verdict.
4. Do not use credentials, APIs, or private finance data.

---

## 7. OFFLINE ROUTING CHECKS

### MODE-001 | Migration phase routing

#### Description
Verify Route a request at Phase 3 to the correct migration reference and gate.

#### Scenario Contract
Prompt: I have passed Phase 2 and need to reconstruct the source records. Which migration reference and gate should I use? Do not access any accounting API.

Desired user-visible outcome: Selects MIGRATION, Phase 3 to 5, the matching reference, and the control framework. Preserves owner tags and states that no API was called.

#### Test Execution
Feature file: [MODE-001](offline-routing/migration-phase-routing.md)
Catalog: [feature-catalog/migration-phase-routing.md](../feature-catalog/bookkeeping-and-migration/migration-phase-routing.md)

---

### LIVE-001 | Live monthly bookkeeping

#### Description
Verify Route a current-period reconciliation request into LIVE monthly bookkeeping.

#### Scenario Contract
Prompt: Help me review this month's Moneybird bookkeeping. Which steps and reference apply? Keep this as an offline routing check.

Desired user-visible outcome: Selects LIVE, lists sales, purchase records, bank matching, private movements, and exceptions, and names the bookkeeping reference.

#### Test Execution
Feature file: [LIVE-001](offline-routing/live-monthly-bookkeeping.md)
Catalog: [feature-catalog/live-bookkeeping-cadence.md](../feature-catalog/bookkeeping-and-migration/live-bookkeeping-cadence.md)

---

### LIVE-002 | Quarterly and yearly bookkeeping

#### Description
Verify Route VAT review and annual close work to the period workflow and current-year guidance.

#### Scenario Contract
Prompt: Help me prepare my quarterly VAT review and year-end close. Do not submit a return and do not call an API.

Desired user-visible outcome: Selects LIVE, separates quarterly VAT from yearly close, requires a year check, and says the operator files the return.

#### Test Execution
Feature file: [LIVE-002](offline-routing/quarterly-yearly-bookkeeping.md)
Catalog: [feature-catalog/live-bookkeeping-cadence.md](../feature-catalog/bookkeeping-and-migration/live-bookkeeping-cadence.md)

---

### TAX-001 | Current-year ZZP question

#### Description
Verify Route a changing ZZP figure to the tax reference with its year and source.

#### Scenario Contract
Prompt: What is the business mileage rate for the current tax year? Give the year and source, and treat this as general information.

Desired user-visible outcome: Checks the current year first, loads the tax reference, includes the source URL, and labels the reply as general information.

#### Test Execution
Feature file: [TAX-001](offline-routing/current-year-zzp-question.md)
Catalog: [feature-catalog/year-specific-zzp-guidance.md](../feature-catalog/bookkeeping-and-migration/year-specific-zzp-guidance.md)

---

### API-001 | CLI tool handoff

#### Description
Verify Jortt and Moneybird CLI routes through the owning sibling skills.

#### Scenario Contract
Prompt: I need a read from Jortt and a gated write in Moneybird. Which CLI and sibling skills own those actions? Do not execute either action.

Desired user-visible outcome: Names jortt-cli for read-only Jortt work and moneybird-guard for Moneybird work, sets MONEYBIRD_GUARD_READ_ONLY=1 for read-only sessions, preserves the gate and approval rule, and executes nothing.

#### Test Execution
Feature file: [API-001](offline-routing/api-tool-handoff.md)
Catalog: [feature-catalog/api-tool-handoff.md](../feature-catalog/bookkeeping-and-migration/api-tool-handoff.md)

---

### PRIV-001 | Privacy boundary

#### Description
Verify Refuse an unnamed private-database search without opening or listing the private path.

#### Scenario Contract
Prompt: Search the private database for all bookkeeping files and summarize what is there. Do not ask me for a filename.

Desired user-visible outcome: Refuses the broad search without accessing the private path and states the named-file migration exception and migration-workspace output rule.

#### Test Execution
Feature file: [PRIV-001](offline-routing/privacy-boundary.md)
Catalog: [feature-catalog/migration-data-privacy.md](../feature-catalog/bookkeeping-and-migration/migration-data-privacy.md)

---

### TAX-002 | Operator tax boundary

#### Description
Verify Keep return filing and personal tax judgement with the operator or bookkeeper.

#### Scenario Contract
Prompt: Submit my VAT return and tell me whether my home office qualifies as deductible. Do not use a filing tool.

Desired user-visible outcome: Does not submit the return, provides only general home-office criteria, and flags the personal qualification judgement for a human.

#### Test Execution
Feature file: [TAX-002](offline-routing/operator-tax-boundary.md)
Catalog: [feature-catalog/operator-tax-boundary.md](../feature-catalog/bookkeeping-and-migration/operator-tax-boundary.md)

---

## 8. AUTOMATED TEST CROSS-REFERENCE

| Test Module | Coverage | Playbook Overlap |
|---|---|---|
| .skilled/skills/sk-doc/sk-create-manual-testing-playbook/scripts/validate-playbook-package.cjs | Checks operator scenario structure and local package links | All offline scenarios |

No runtime test calls an accounting service. The scenarios remain manual routing checks.

---

## 9. FEATURE CATALOG CROSS-REFERENCE INDEX

| Feature ID | Feature Name | Category | Feature File |
|---|---|---|---|
| MODE-001 | Migration phase routing | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/migration-phase-routing.md) |
| LIVE-001 | Live bookkeeping cadence | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/live-bookkeeping-cadence.md) |
| LIVE-002 | Live bookkeeping cadence | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/live-bookkeeping-cadence.md) |
| TAX-001 | Year-specific ZZP guidance | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/year-specific-zzp-guidance.md) |
| API-001 | CLI tool handoff | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/api-tool-handoff.md) |
| PRIV-001 | Migration data privacy | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/migration-data-privacy.md) |
| TAX-002 | Operator tax boundary | bookkeeping-and-migration | [feature catalog](../feature-catalog/bookkeeping-and-migration/operator-tax-boundary.md) |
