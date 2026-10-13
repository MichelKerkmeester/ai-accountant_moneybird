---
title: "CLI command reference"
description: "Documents every jortt-cli command, its configuration, its safety checks and its exit codes."
trigger_phrases:
  - "CLI command reference"
  - "jortt-cli command reference"
  - "jortt-cli exit codes"
  - "jortt-cli flags"
version: 1.0.0.0
---

# CLI command reference (references/cli.md)

## 1. OVERVIEW

Documents every jortt-cli command, its configuration, its safety checks and its exit codes.

It is the reference the router loads for an install, scope or safety question, and the one place that owns the complete command list and the failure code table.

---

## 2. HOW IT WORKS

### Core Behavior

The reference states each command, its flags and its output shape, then the configuration precedence for the Jortt settings, the token cache behavior, the output and write safety rules and the exit code for every failure class. Command entries in this catalog summarize one behavior each and point here for the complete contract instead of restating it.

### Routing

`SKILL.md` loads this reference for a REST extraction or scope question, and on demand for setup or an error. It is also the recovery companion to the troubleshooting guide, which maps a code to an action.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/cli.md`](../../references/cli.md) | Shared | Command, configuration, safety and exit code reference. |
| [`cli/jortt-cli/jortt-cli`](../../cli/jortt-cli/jortt-cli) | Handler | The command surface this reference documents. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/auth-and-scopes/write-lock.md`](../../manual-testing-playbook/auth-and-scopes/write-lock.md) | Manual playbook | JRT-002 confirms the gate codes and messages offline. |
| [`manual-testing-playbook/extraction/raw-get-path-guard.md`](../../manual-testing-playbook/extraction/raw-get-path-guard.md) | Manual playbook | JRT-009 confirms the raw GET guards offline. |

---

## 4. SOURCE METADATA

- Group: Reference guides
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reference-guides/cli-command-reference.md`

Related references:
- [rest-api-catalogue.md](rest-api-catalogue.md) - REST API catalogue
- [exports-and-limits.md](exports-and-limits.md) - Exports and limits
- [troubleshooting-guide.md](troubleshooting-guide.md) - Troubleshooting guide
