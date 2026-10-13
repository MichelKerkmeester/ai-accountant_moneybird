---
title: Migration plan kit
description: Ships fill-in templates and a workspace setup script so any user can run the migration phases.
trigger_phrases:
  - Migration plan kit
  - migration phase plan template
  - init migration workspace
  - migration config template
version: 1.0.0.0
---

# Migration plan kit

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

The plan kit turns the phase references into working files. A user who clones the repository runs one script and gets a configuration template, a phase dashboard and a run-journal event template inside the ignored `migration-workspace/`, plus a git-ignored copy of the spec-kit template packet with one Level 3 packet and nested goal per phase.

## 2. HOW IT WORKS

`scripts/generate-plan-kit.py` reads the phase contracts and the `MIGRATION_CONFIG` table, writes the templates under `assets/migration/` and renders the template packet `specs/000-migration-template/` from the doc templates in `assets/migration/spec-template/`. Its `--check` mode fails when a generated file no longer matches its source or an unexpected doc sits in the packet, so a phase edit cannot leave a stale packet. `scripts/init-workspace.sh` copies the templates into `migration-workspace/`, creates every workspace and AgentDesk folder and copies the template packet to `specs/001-migration/` or the name given with `--spec-name`. It refuses a symlinked or tracked target and never overwrites an existing file, so a user's filled-in packets and configuration survive a rerun. The templates hold placeholders only.

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| sk-moneybird-accountant/scripts/generate-plan-kit.py | Script | Generates and checks the kit templates and the template packet from the phase references. |
| sk-moneybird-accountant/scripts/init-workspace.sh | Script | Builds `migration-workspace/` and the working packet from the templates without overwriting. |
| sk-moneybird-accountant/assets/migration/README.md | Asset | Explains each template and how to use it. |
| specs/000-migration-template/spec.md | Asset | Phase parent of the generated template packet. |
| sk-moneybird-accountant/references/migration/overview-and-setup.md | Shared | Names the setup step that runs the script. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| sk-moneybird-accountant/scripts/plan-kit-test.sh | Automated test | Checks generation, drift detection, folder creation, no-overwrite and refusals. |
| sk-moneybird-accountant/manual-testing-playbook/offline-routing/migration-plan-kit.md | Manual playbook | Checks that a new user is routed to the setup script and the phase packets. |

## 4. SOURCE METADATA

- Group: bookkeeping-and-migration
- Canonical catalog source: feature-catalog.md
- Feature file path: bookkeeping-and-migration/migration-plan-kit.md

Related references:
- [migration-phase-routing.md](migration-phase-routing.md) - Phase selection and owner-tagged gates.
- [migration-agent-route.md](migration-agent-route.md) - The M12 seats that work each phase plan.
