---
title: "Setup script"
description: "setup.sh prints the install plan by default and changes the machine only when an operator passes --install, with --check and --uninstall for state and removal."
trigger_phrases:
  - "setup script"
  - "moneybird setup script"
  - "install moneybird-cli"
  - "setup.sh --check"
version: 1.0.0.0
---

# Setup script (setup.sh)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

setup.sh prints the install plan by default and changes the machine only when an operator passes --install, with --check and --uninstall for state and removal.

An agent can print the plan and run the check safely. Only an operator runs `--install`, because it clones and links software on the machine.

---

## 2. HOW IT WORKS

With no option the script prints the `git clone`, detached `checkout`, `mkdir` and `ln -s` commands it would run and exits without changing anything. `--install` first confirms that `bash`, `curl`, `jq` and `git` exist, then clones the official repository into `$HOME/.moneybird-cli`, checks out the pinned commit and links `moneybird-cli` and this package's `moneybird-guard` into `$HOME/.local/bin`. `MONEYBIRD_CLI_HOME` and `MONEYBIRD_CLI_BIN` move those locations.

The installer refuses to replace an existing path that is not a git checkout and refuses to replace a symlink that points somewhere else. It never pipes a remote script into a shell. `--check` prints one yes or no line for source presence, the pin match and whether each command is on PATH, and exits nonzero unless every line is yes. `--uninstall` prints its removal commands without running them.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/setup.sh`](../../cli/moneybird-cli/setup.sh) | Script | Plan, install, check and uninstall modes |
| [`INSTALL-GUIDE.md`](../../INSTALL-GUIDE.md) | Shared | Operator install steps and rollback |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [MBD-008](../../manual-testing-playbook/setup/setup-plan-and-check.md) | Manual playbook | Runs the plan and the check without installing |
| [MBD-001](../../manual-testing-playbook/setup/doctor-offline.md) | Manual playbook | The doctor reuses the check output |

---

## 4. SOURCE METADATA

- Group: Official CLI And Setup
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `official-cli-and-setup/setup-script.md`

Related references:
- [official-cli-pinned-commit.md](official-cli-pinned-commit.md) - The commit this script installs
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
