---
title: "Troubleshooting guide"
description: "Maps jortt-cli exit codes and API responses to ordered read-only recovery checks."
trigger_phrases:
  - "Troubleshooting guide"
  - "jortt-cli troubleshooting"
  - "Jortt 401 recovery"
  - "Jortt exit code recovery"
version: 1.0.0.0
---

# Troubleshooting guide (references/troubleshooting.md)

## 1. OVERVIEW

Maps jortt-cli exit codes and API responses to ordered read-only recovery checks.

It is the recovery companion to the command reference. Every check stays read-only, so an error never widens a scope or asks for a write.

---

## 2. HOW IT WORKS

### Core Behavior

The guide runs diagnostics in order, from dependency checks through the spec report and token status to `whoami` and the offline doctor, then maps the common exit codes and API statuses to a meaning and an action. It also covers an expired download link, an empty page and a repeated page.

### Boundaries

A read task never gains a write scope to clear an error. When a response needs a change, the guide hands the step to the operator in the Jortt UI. The offline doctor prints the local facts that the recovery steps depend on.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Shared | Ordered diagnostics and the error-to-action table. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/auth-and-scopes/doctor-offline.md`](../../manual-testing-playbook/auth-and-scopes/doctor-offline.md) | Manual playbook | JRT-001 runs the doctor offline. |
| [`manual-testing-playbook/auth-and-scopes/token-status.md`](../../manual-testing-playbook/auth-and-scopes/token-status.md) | Manual playbook | JRT-010 reads token status and clears the cache. |

---

## 4. SOURCE METADATA

- Group: Reference guides
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `reference-guides/troubleshooting-guide.md`

Related references:
- [cli-command-reference.md](cli-command-reference.md) - CLI command reference
- [rest-api-catalogue.md](rest-api-catalogue.md) - REST API catalogue
- [exports-and-limits.md](exports-and-limits.md) - Exports and limits
