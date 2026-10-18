---
title: "CLI setup check"
description: "Checks the CLI file, Bash, curl and jq, then prints the symlink command without changing files."
trigger_phrases:
  - "CLI setup check"
  - "jortt-cli setup.sh"
  - "install jortt-cli"
  - "jortt-cli symlink command"
version: 1.0.0.0
---

# CLI setup check (setup.sh)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Checks the CLI file, Bash, curl and jq, then prints the symlink command without changing files.

It is the install step the operator runs first. The printed command lets the operator review the link before anything changes.

---

## 2. HOW IT WORKS

`bash cli/jortt-cli/setup.sh` prints `CLI file: ready`, the Bash version and `available` for `curl` and `jq`. It then prints `Manual symlink command:` with the full `ln -s` line for `$HOME/.local/bin/jortt-cli` and ends with `No files changed. Run the symlink command yourself to install the link.`

The script never creates the link. A missing prerequisite or a non-executable CLI file exits 1.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/setup.sh`](../../cli/jortt-cli/setup.sh) | Script | Checks prerequisites and prints the symlink command. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/setup/setup-check.md`](../../manual-testing-playbook/setup/setup-check.md) | Manual playbook | JRT-013 runs the check and confirms it changes no file. |
| [`INSTALL-GUIDE.md`](../../INSTALL-GUIDE.md) | Reference | Places the check in the install sequence. |

---

## 4. SOURCE METADATA

- Group: Diagnostics
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `diagnostics/setup-check.md`

Related references:
- [offline-doctor.md](offline-doctor.md) - Offline doctor
