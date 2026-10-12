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
| `exit-code-parity.sh` | Compares the guard exit codes, 2 and up, with the exit table, the troubleshooting rows and the SKILL keywords |
| `exit-code-parity-test.sh` | Runs the parity check on a clean copy and on six mutated copies |

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

## 3. EXIT CODE PARITY

`exit-code-parity.sh` reads the guard's own die codes from 2 and up, then compares that set, in both directions, with the exit table in `../references/cli.md`, the exit rows in `../references/troubleshooting.md`, the TROUBLESHOOT keywords and the gate ladder in `../SKILL.md`. The script reads files only. It never calls the CLI and never opens a credential file.

```bash
bash scripts/exit-code-parity.sh
```

Expected: `exit-code-parity: ok (codes: 2 3 4 5 6 7 8 9)`.

`exit-code-parity-test.sh` runs the check on a clean copy and on six mutated copies. Every mutant must fail and name the drift in the report.

```bash
bash scripts/exit-code-parity-test.sh
```

Expected: `Result: 7 passed, 0 failed`.

---

## 4. RELATED DOCUMENTS

| Document | Purpose |
|---|---|
| [`../feature-catalog/sessions-and-diagnostics/local-doctor.md`](../feature-catalog/sessions-and-diagnostics/local-doctor.md) | Feature entry for the doctor |
| [`../manual-testing-playbook/setup/doctor-offline.md`](../manual-testing-playbook/setup/doctor-offline.md) | Offline doctor scenario |
| [`../references/troubleshooting.md`](../references/troubleshooting.md) | Where the doctor sits in the diagnostic order |
