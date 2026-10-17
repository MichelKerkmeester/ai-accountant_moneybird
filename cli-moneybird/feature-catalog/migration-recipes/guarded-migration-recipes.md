---
title: "Guarded migration recipes"
description: "references/migration-recipes.md gives the guarded command sequence for every migration write and the per-year verification reads, with the pilot correction path."
trigger_phrases:
  - "guarded migration recipes"
  - "moneybird opening balance write"
  - "moneybird invoice attachment write"
  - "moneybird pilot correction"
version: 1.0.0.0
---

# Guarded migration recipes (migration-recipes.md)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

`references/migration-recipes.md` gives the guarded command sequence for every migration write and the per-year verification reads, with the pilot correction path.

The recipes turn the guard gates into a repeatable operator sequence. Each one names the resource, the required flags and the fields that still need confirmation from pinned CLI help.

---

## 2. HOW IT WORKS

### Three Steps per Write

Every recipe previews the command first, records the printed `payload-digest` in a fresh `WRITE_INTENT` entry under its own approval reference and then repeats the command with `--confirm-write --approval`. A payload that changed after approval and a reference and digest pair that was already used are both refused. The write contract owns the gate order and the digest rule.

### Write Recipes

The recipes cover the opening balance journal entry (memoriaal), the historical sales invoice and its PDF, purchase invoices and receipts with their files, financial statement mutations, ledger accounts with an RGS code, fixed assets (vaste activa), payment links and document payments. They also cover the auditfile export with its download fetch. Request fields that the supplied facts do not confirm stay `UNVERIFIED` until pinned CLI help is checked.

### Verification And Correction

The per-year verification reads name an explicit period and use synchronization for a full pull. The correction recipe stops the batch when a write response differs from the approved record, deletes against the pilot and confirms removal with a separate read. A corrected record is recreated from the approved source batch and verified through synchronization.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Shared | Owns the command sequences, the field notes and the expected results |
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Runs the preview, digest and confirmation gates every recipe passes |
| [`ROUTER.md`](../../ROUTER.md) | Shared | Routes each recipe to the guarded write path or the UI boundary |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/write-safety/pilot-write-and-undo-rehearsal.md`](../../manual-testing-playbook/write-safety/pilot-write-and-undo-rehearsal.md) | Manual playbook | Live pilot write and undo rehearsal |
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Covers the gates every recipe passes |
| [`references/cli.md`](../../references/cli.md) | Reference | Canonical guard flags and exit codes |

---

## 4. SOURCE METADATA

- Group: Migration Recipes
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `migration-recipes/guarded-migration-recipes.md`

Related references:
- [payload-bound-approval.md](../write-guard/payload-bound-approval.md) - The digest binding and single-use rule behind each recipe
- [pilot-administration-gate.md](../write-guard/pilot-administration-gate.md) - Keeps each recipe write on the pilot
- [operation-routing.md](../routing/operation-routing.md) - Picks the route before the recipe runs
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
