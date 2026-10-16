---
title: MIG-006 -- Migration plan kit
description: Validates that a new user is routed to the workspace setup script and the generated phase packets without service calls.
id: MIG-006
catalog_applicable: true
version: 1.0.0.0
---

# MIG-006 -- Migration plan kit

This scenario checks that a user starting fresh is sent to the plan kit before any migration work, without reading accounting records or calling an external service.

---

## 1. OVERVIEW

The scenario confirms that Phase 0 setup runs `scripts/init-workspace.sh`, that each phase is worked from its packet in the git-ignored `specs/001-migration/`, and that the script never overwrites a filled-in file.

### Why This Matters

A new user has the phase references but no working files. Routing them to the kit keeps every phase checklist, the configuration and the dashboard consistent with the references.

---

## 2. SCENARIO CONTRACT

- Objective: Route a first-time user to the plan kit and explain what it creates.
- Real user request: I just cloned this repo and want to start the migration. Where do I start? Do not read records or call an API.
- Prompt: I just cloned this repo and want to start the migration. Where do I start? Do not read records or call an API.
- Fixture rows: MIG-006 (English) and MIG-006-nl (Dutch twin).
- Expected execution process: Read the project bootstrap and skill, then the migration index, the overview and setup reference and the plan kit README. Do not use network access, accounting APIs, private finance data or a live agent dispatch.
- Expected signals: Names Phase 0, the command `bash sk-moneybird-accountant/scripts/init-workspace.sh`, the config template, the phase dashboard and the 23 phase packets in the git-ignored `specs/001-migration/`. States that the script never overwrites an existing file and that the workspace stays git-ignored. Reports no API call.
- Desired user-visible outcome: A short start route that names the setup command, what it creates and the first Phase 0 actions.
- Pass/fail: PASS if the setup command and the working packet are named and no service call is made. FAIL if the user is sent to work from the references alone, or a service call occurs.

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Read the bootstrap and skill.
2. Read sk-moneybird-accountant/references/migration/README.md and sk-moneybird-accountant/references/migration/overview-and-setup.md.
3. Read sk-moneybird-accountant/assets/migration/README.md.
4. Report the setup command, the created files, the no-overwrite rule and the no-call status.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MIG-006 | Migration plan kit | Route a first-time user to the plan kit. | I just cloned this repo and want to start the migration. Where do I start? Do not read records or call an API. | 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/README.md -> 4. Read sk-moneybird-accountant/references/migration/overview-and-setup.md -> 5. Read sk-moneybird-accountant/assets/migration/README.md -> 6. Report the setup command, created files, no-overwrite rule and no-call status | Names init-workspace.sh, the config template, the dashboard, the 23 phase packets and the no-overwrite rule | Capture prompt, references, the setup command and no-call status | PASS if the setup command and working packet are named and no service call occurs. FAIL if the kit is skipped or a service call occurs. | Check the Phase 0 setup sequence in overview-and-setup.md and the kit README, then repeat offline. |

### Prompt

- Prompt: I just cloned this repo and want to start the migration. Where do I start? Do not read records or call an API.

### Commands

1. Read AGENTS.md
2. Read sk-moneybird-accountant/SKILL.md
3. Read sk-moneybird-accountant/references/migration/README.md
4. Read sk-moneybird-accountant/references/migration/overview-and-setup.md
5. Read sk-moneybird-accountant/assets/migration/README.md
6. Report the setup command, created files, no-overwrite rule and API-free status

### Expected

Phase 0 starts with `bash sk-moneybird-accountant/scripts/init-workspace.sh`. It creates the workspace folders, `MIGRATION_CONFIG.json`, the phase dashboard and copies the 23 phase packets to the git-ignored `specs/001-migration/`, and never overwrites an existing file. No service is called.

### Evidence

Capture the prompt, the references read, the setup command, the list of created files and a record that no service call occurred.

### Pass / Fail

- **Pass**: Names the setup command and the working packet, keeps the workspace and the packet ignored and makes no service call.
- **Fail**: Skips the kit, suggests editing templates in the skill folder or calls a service.

### Failure Triage

Check step 3 of the Phase 0 setup sequence and the kit README. Repeat the scenario offline.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [manual-testing-playbook.md](../manual-testing-playbook.md) | Root playbook rules and scenario index. |
| [feature catalog entry](../../feature-catalog/bookkeeping-and-migration/migration-plan-kit.md) | Plan kit behavior and source anchors. |

### Implementation And Test Anchors

| File | Role |
|---|---|
| AGENTS.md | Defines entry route and privacy boundaries. |
| sk-moneybird-accountant/SKILL.md | Routes phase work to the plans. |
| sk-moneybird-accountant/references/migration/overview-and-setup.md | Names the setup step. |
| sk-moneybird-accountant/assets/migration/README.md | Describes the templates. |

---

## 5. SOURCE METADATA

- Group: offline-routing
- Playbook ID: MIG-006
- Canonical root source: manual-testing-playbook.md
- Feature file path: offline-routing/migration-plan-kit.md

**Exact command sequence:** 1. Read AGENTS.md -> 2. Read sk-moneybird-accountant/SKILL.md -> 3. Read sk-moneybird-accountant/references/migration/README.md -> 4. Read sk-moneybird-accountant/references/migration/overview-and-setup.md -> 5. Read sk-moneybird-accountant/assets/migration/README.md -> 6. Report the setup command, created files, no-overwrite rule and no-call status

**Expected resources:** AGENTS.md, sk-moneybird-accountant/SKILL.md, sk-moneybird-accountant/references/migration/README.md, sk-moneybird-accountant/references/migration/overview-and-setup.md, sk-moneybird-accountant/assets/migration/README.md

---
