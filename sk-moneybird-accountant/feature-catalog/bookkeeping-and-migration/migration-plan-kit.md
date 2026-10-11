---
title: Migration plan kit
description: Ships fill-in templates and a workspace setup script so any user can run the 23 migration phases.
trigger_phrases:
  - migration plan kit
  - migration phase plan template
  - init migration workspace
  - migration config template
version: 1.0.0.0
---

# Migration plan kit

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

The plan kit turns the phase references into working files. A user who clones the repository runs one script and gets a configuration template, a phase dashboard, a run-journal event template and one plan per phase, all inside the ignored `migration-workspace/`.

## 2. HOW IT WORKS

`scripts/generate-plan-kit.py` reads the 23 phase contracts and the `MIGRATION_CONFIG` table and writes the templates under `assets/migration/`. Its `--check` mode fails when a template no longer matches its reference, so a phase edit cannot leave a stale plan. `scripts/init-workspace.sh` copies the templates into `migration-workspace/`, creates every workspace and AgentDesk folder, and refuses a symlinked or tracked workspace. It never overwrites an existing file, so a user's filled-in plans and configuration survive a rerun. The templates hold placeholders only.

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/generate-plan-kit.py | Script | Generates and checks the plan templates from the phase references. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/init-workspace.sh | Script | Builds `migration-workspace/` from the templates without overwriting. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/assets/migration/README.md | Asset | Explains each template and how to use it. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/references/migration/overview-and-setup.md | Shared | Names the setup step that runs the script. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/scripts/plan-kit-test.sh | Automated test | Checks generation, drift detection, folder creation, no-overwrite and refusals. |
| AI Systems/Moneybird Accountant/sk-moneybird-accountant/manual-testing-playbook/offline-routing/migration-plan-kit.md | Manual playbook | Checks that a new user is routed to the setup script and the phase plans. |

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-plan-kit.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Phase selection and owner-tagged gates.
- [migration-agent-route.md](migration-agent-route.md) - The M12 seats that work each phase plan.
