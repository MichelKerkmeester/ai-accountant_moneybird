---
title: "Official CLI at a pinned commit"
description: "The package adopts the official moneybird/moneybird-cli Shell project at one reviewed commit and wraps it instead of reimplementing the API surface."
trigger_phrases:
  - "official cli at a pinned commit"
  - "official moneybird cli"
  - "moneybird-cli pinned commit"
  - "moneybird cli adoption"
version: 1.0.0.0
---

# Official CLI at a pinned commit (moneybird-cli)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

The package adopts the official moneybird/moneybird-cli Shell project at one reviewed commit and wraps it instead of reimplementing the API surface.

The guard and every recipe call this CLI. Pin updates are a reviewed source change, because the CLI reads its API spec at runtime and a new commit can change routes.

---

## 2. HOW IT WORKS

The adopted project is the official `moneybird/moneybird-cli` Shell CLI. It reads the Moneybird OpenAPI spec at runtime and serves standard actions such as `list`, `get`, `create`, `update` and `delete` plus the custom actions the spec declares. `--dry-run` prints the `METHOD URL` line and the request body without sending it, which is the hook the guard builds on.

The reviewed commit lives once in `PINNED_COMMIT` inside `setup.sh`. The project has no tagged releases, so the setup script checks out a detached commit rather than a version. The skill never calls a second REST client. Independent CLIs and community SDKs were surveyed in the CLI reference and are not used.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/setup.sh`](../../cli/moneybird-cli/setup.sh) | Script | Stores the reviewed commit and installs that exact commit |
| [`cli/moneybird-cli/README.md`](../../cli/moneybird-cli/README.md) | Shared | Records what is adopted and how a pin update is reviewed |
| [`references/cli.md`](../../references/cli.md) | Shared | Adoption notes, CLI flags and the project survey |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [MBD-008](../../manual-testing-playbook/setup/setup-plan-and-check.md) | Manual playbook | Checks that the plan and the pin check report the reviewed commit |
| [`references/cli.md`](../../references/cli.md) | Reference | Survey that records why the official CLI is the only REST client |

---

## 4. SOURCE METADATA

- Group: Official CLI And Setup
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `official-cli-and-setup/official-cli-pinned-commit.md`

Related references:
- [setup-script.md](setup-script.md) - Installs and checks the pinned commit
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
