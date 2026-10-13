---
title: "cli-moneybird Scripts"
description: "Local diagnostics for the cli-moneybird skill that never open credential files or print a secret."
trigger_phrases:
  - "cli-moneybird doctor"
  - "moneybird offline diagnostics"
version: 1.0.0.0
---

# cli-moneybird Scripts: offline diagnostics

---

## 1. OVERVIEW

`scripts/` holds the local diagnostics for the `cli-moneybird` package: the doctor, the exit-code parity check and the parity test. None of them needs a Moneybird login. The CLI installer and the write guard live under `cli/moneybird-cli/` because they belong to the adopted CLI.

Current state:

- `doctor.sh` reports the local commands, the CLI pin, the config folder, credential-file presence and the process environment without opening a credential file.
- `exit-code-parity.sh` compares the guard exit codes, 2 and up, with the exit table, the troubleshooting rows and the SKILL keywords in both directions.
- `exit-code-parity-test.sh` proves the parity check on a clean copy and on six mutated copies.
- Every script is offline by default. Only `doctor.sh --live` makes a network call, and an operator runs it by hand.

---

## 2. KEY FILES

| File | Purpose |
|---|---|
| `doctor.sh` | Reports local command, CLI pin, config folder, credential-file presence and process-environment status |
| `exit-code-parity.sh` | Compares the guard exit codes, 2 and up, with the exit table, the troubleshooting rows and the SKILL keywords |
| `exit-code-parity-test.sh` | Runs the parity check on a clean copy and on six mutated copies |

`exit-code-parity.sh` reads the guard's own die codes from 2 and up, then compares that set, in both directions, with the exit table in [`../references/cli.md`](../references/cli.md), the exit rows in [`../references/troubleshooting.md`](../references/troubleshooting.md), the TROUBLESHOOT keywords and the gate ladder in [`../SKILL.md`](../SKILL.md).

---

## 3. BOUNDARIES AND FLOW

| Boundary | Rule |
|---|---|
| Credential files | `doctor.sh` never opens `.env` or `.env.writer` and never prints a credential value. It checks presence only |
| File access | `exit-code-parity.sh` reads files only. It never calls the CLI and never opens a credential file |
| Network | The default doctor run makes no network call. `--live` makes network calls and is not part of offline verification |
| Scratch files | The doctor stores no scratch files |

---

## 4. ENTRYPOINTS

| Entrypoint | Type | Purpose |
|---|---|---|
| `bash scripts/doctor.sh` | CLI | Runs the offline report, which ends with the read-only notice |
| `bash scripts/doctor.sh --live` | CLI | Adds the administrations HTTP status, count and yes or no matches for configured administration IDs, and needs `MONEYBIRD_API_TOKEN` in the process environment |
| `bash scripts/exit-code-parity.sh` | CLI | Compares the guard die codes with the four documentation surfaces |
| `bash scripts/exit-code-parity-test.sh` | CLI | Runs the parity check on a clean copy and on six mutated copies |

---

## 5. VALIDATION

Run from the `cli-moneybird/` package root.

```bash
bash scripts/doctor.sh
```

Expected: offline diagnostics ending with `Doctor is read-only. Credential files were checked for presence only.` The script makes no network call.

```bash
bash scripts/exit-code-parity.sh
```

Expected: `exit-code-parity: ok (codes: 2 3 4 5 6 7 8 9)`.

```bash
bash scripts/exit-code-parity-test.sh
```

Expected: `Result: 7 passed, 0 failed`. Every mutant fails and names the drift in the report.

---

## 6. RELATED

| Document | Purpose |
|---|---|
| [`../feature-catalog/sessions-and-diagnostics/local-doctor.md`](../feature-catalog/sessions-and-diagnostics/local-doctor.md) | Feature entry for the doctor |
| [`../manual-testing-playbook/setup/doctor-offline.md`](../manual-testing-playbook/setup/doctor-offline.md) | Offline doctor scenario |
| [`../references/troubleshooting.md`](../references/troubleshooting.md) | Where the doctor sits in the diagnostic order |
