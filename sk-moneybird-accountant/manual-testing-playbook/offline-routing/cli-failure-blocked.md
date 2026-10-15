---
title: FAIL-001 -- Blocked answer after a failed CLI read
description: This scenario validates the blocked answer contract for FAIL-001. It focuses on offline routing and policy.
id: FAIL-001
catalog_applicable: true
version: 1.0.0.0
---

# FAIL-001 -- Blocked answer after a failed CLI read

This document captures the offline prompt, local read sequence, expected signals and evidence for FAIL-001.

---

## 1. OVERVIEW

This scenario validates the blocked answer contract after a required CLI read fails. It focuses on the retry owners, the bounded attempts and the stop that names the missing capability.

### Why This Matters

A failed read is easy to hide behind a value from memory. This check confirms that the parent stops, names the capability that is missing and keeps each retry with its documented owner. A local-only check confirms the route without touching accounting tools or private finance data.

---

## 2. SCENARIO CONTRACT

- Objective: Route an exhausted CLI read to the blocked answer and keep every retry with its documented owner.
- Real user request: A required Moneybird contacts read is rate limited and stops after three attempts. What does the answer say and what may be retried? Keep this as an offline routing check.
- Prompt: A required Moneybird contacts read is rate limited and stops after three attempts. What does the answer say and what may be retried? Keep this as an offline routing check.
- Fixture rows: cli-read-exhausted-blocked (en). The offline suites cover the retry owners and the bounded attempts.
- Expected execution process: Read the project bootstrap and skill, then inspect only the listed local references. Do not use network access or accounting CLIs.
- Expected signals: Answers blocked, names the missing contacts read as the missing capability, says one guard invocation makes one call, keeps the three-attempt bounded GET loop with the parent, keeps the one authorized read reissue with the migration orchestrator, keeps the Jortt 429 retries with jortt-cli and repeats no non-GET call.
- Desired user-visible outcome: A concise blocked report with the missing capability, each retry owner and no value taken from memory.
- Pass/fail: PASS if the answer stops with blocked, names the missing capability and keeps each retry with its owner. FAIL if the answer invents a value, retries a non-GET call or adds a second retry layer around a CLI.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and the skill.
2. Follow the listed local reference sequence.
3. Compare the observed route to the expected signals.
4. Record a concise verdict and evidence without calling an API.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| FAIL-001 | CLI tool handoff | Route an exhausted CLI read to the blocked answer and keep every retry with its documented owner. | A required Moneybird contacts read is rate limited and stops after three attempts. What does the answer say and what may be retried? Keep this as an offline routing check. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md -> 4. Read cli-moneybird/SKILL.md -> 5. Read cli-jortt/SKILL.md -> 6. Report blocked, the missing capability and each retry owner | Answers blocked, names the missing contacts read as the missing capability, says one guard invocation makes one call, keeps the three-attempt bounded GET loop with the parent, keeps the one authorized read reissue with the migration orchestrator, keeps the Jortt 429 retries with jortt-cli and repeats no non-GET call. | Capture the prompt, the blocked answer, the named capability and the retry owners. | PASS if the answer stops with blocked, names the missing capability and keeps each retry with its owner. FAIL if the answer invents a value, retries a non-GET call or adds a second retry layer around a CLI. | Check the CLI failure route class in the skill, then section M5 of the shared mechanisms. Repeat with both CLIs unavailable. |

### Prompt

- Prompt: A required Moneybird contacts read is rate limited and stops after three attempts. What does the answer say and what may be retried? Keep this as an offline routing check.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md
4. Read cli-moneybird/SKILL.md
5. Read cli-jortt/SKILL.md
6. Report blocked, the missing capability and each retry owner

### Expected

Answers blocked, names the missing contacts read as the missing capability, says one guard invocation makes one call, keeps the three-attempt bounded GET loop with the parent, keeps the one authorized read reissue with the migration orchestrator, keeps the Jortt 429 retries with jortt-cli and repeats no non-GET call.

### Evidence

Capture the prompt, the blocked answer, the named capability and the retry owners.

### Pass / Fail

- **Pass**: the answer stops with blocked, names the missing capability and keeps each retry with its owner.
- **Fail**: the answer invents a value, retries a non-GET call or adds a second retry layer around a CLI.

### Failure Triage

Check the CLI failure route class in the skill, then section M5 of the shared mechanisms. Repeat with both CLIs unavailable.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index |
| [feature-catalog entry](../../feature-catalog/bookkeeping-and-migration/api-tool-handoff.md) | Current feature summary and source anchors |

### Implementation And Test Anchors

| File | Role |
|---|---|
| sk-moneybird-accountant/SKILL.md | Defines the CLI_FAILURE route class and the blocked answer rule |
| sk-moneybird-accountant/references/migration/shared-mechanisms.md | Holds the M5 rate-limit recovery and the one authorized read reissue |
| cli-moneybird/SKILL.md | Holds the three-attempt GET bound and the non-GET stop |
| cli-jortt/SKILL.md | Keeps jortt-cli the 429 retry owner |
| sk-moneybird-accountant/scripts/cli-failure-handoff-test.sh | Proves the retry owners and the blocked answer contract offline |
| sk-moneybird-accountant/evals/evals.json | Holds the cli-read-exhausted-blocked case |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: FAIL-001
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/cli-failure-blocked.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/shared-mechanisms.md -> 4. Read cli-moneybird/SKILL.md -> 5. Read cli-jortt/SKILL.md -> 6. Report blocked, the missing capability and each retry owner

**Expected resources:** sk-moneybird-accountant/references/migration/shared-mechanisms.md
