---
title: "Failure diagnosis and recovery"
description: "references/troubleshooting.md orders the local checks and maps CLI, guard and REST failures to the safe next step."
trigger_phrases:
  - "failure diagnosis and recovery"
  - "moneybird troubleshooting"
  - "moneybird guard exit code fix"
  - "moneybird 401 403 404 422"
  - "moneybird stale get recovery"
version: 1.0.0.0
---

# Failure diagnosis and recovery (troubleshooting.md)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

`references/troubleshooting.md` orders the local checks and maps CLI, guard and REST failures to the safe next step.

The guide starts from local state before it touches credentials or repeats a call. Every row names the cause and the fix, so a failure does not become a retry against an unknown target.

---

## 2. HOW IT WORKS

### Diagnostic Order

The guide runs the setup check, the CLI version, the selected administration and the doctor in order. After those pass it inspects the pinned CLI help for the failing route and then matches the failure to its row. No step prints a token or an administration ID.

### Guard And API Recovery

Every guard exit has a row with its cause and fix, and the rows point at the canonical exit-code table in `references/cli.md`. For API responses the guide covers a session that returns 401, a scope that returns 403, a wrong administration or route that returns 404, a rejected field or a locked period that returns 422, a 429 with `Retry-After` and a GET that appears stale after a write. A failed route stops the write until the pinned CLI help and the operator confirm the next step.

### Read-Back Issues

The guide covers a list that misses older years because of the default period, a cached GET after a write and a 204 DELETE. Each case points at a separate read or a synchronization read as the proof. The read rules belong to the Read Step Contract.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Shared | Owns the diagnostic order and the failure rows |
| [`ROUTER.md`](../../ROUTER.md) | Shared | Routes a failed operation to the troubleshooting reference |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/setup/doctor-offline.md`](../../manual-testing-playbook/setup/doctor-offline.md) | Manual playbook | Runs the first diagnostic step offline |
| [`references/cli.md`](../../references/cli.md) | Reference | Canonical exit-code table the guard rows point to |

---

## 4. SOURCE METADATA

- Group: API Knowledge
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `api-knowledge/failure-diagnosis-and-recovery.md`

Related references:
- [documented-api-traps.md](documented-api-traps.md) - The API behaviors behind the read-back rows
- [local-doctor.md](../sessions-and-diagnostics/local-doctor.md) - The first diagnostic step
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
