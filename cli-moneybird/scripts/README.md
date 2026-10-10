---
title: "cli-moneybird Scripts"
description: "Local diagnostics for the cli-moneybird skill that never open credential files or print a secret."
trigger_phrases:
  - "cli-moneybird doctor"
  - "moneybird offline diagnostics"
version: 1.0.0.0
---

# cli-moneybird Scripts

> Local diagnostics for the Moneybird skill that never open a credential file.

---

## 1. OVERVIEW

`scripts/` holds the package doctor. The CLI installer and the write guard live under `cli/moneybird-cli/` because they belong to the adopted CLI.

| File | Purpose |
|---|---|
| `doctor.sh` | Reports local command, CLI pin, config folder, credential-file presence and process-environment status |

---

## 2. DOCTOR

`doctor.sh` never opens `.env` or `.env.writer` and never prints a credential value.

```bash
bash scripts/doctor.sh
```

Expected: offline diagnostics ending with `Doctor is read-only.` The script makes no network call.

Use `--live` only when an operator wants a live check:

```bash
bash scripts/doctor.sh --live
```

Expected: with `MONEYBIRD_API_TOKEN` set in the process environment, it prints the administrations HTTP status, count and yes or no matches for configured administration IDs.

The doctor stores no scratch files. The `--live` option makes network calls and is not part of offline verification.

---

## 3. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`../feature-catalog/sessions-and-diagnostics/local-doctor.md`](../feature-catalog/sessions-and-diagnostics/local-doctor.md) | Feature entry for the doctor |
| [`../manual-testing-playbook/setup/doctor-offline.md`](../manual-testing-playbook/setup/doctor-offline.md) | Offline doctor scenario |
| [`../references/troubleshooting.md`](../references/troubleshooting.md) | Where the doctor sits in the diagnostic order |
