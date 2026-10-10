# cli-jortt scripts

Local diagnostics for the Jortt skill. Nothing here calls Jortt unless you ask for it.

---

## 1. OVERVIEW

`doctor.sh` checks command availability, CLI location, spec cache state and whether the named Jortt settings are present in the environment or configured `.env` file. It reads those settings in memory and prints set or unset status only. By default it makes no network call.

Pass `--live` only when you want the `whoami` check. It calls the Jortt API when the client values and local CLI are present.

---

## 2. USAGE

```bash
bash "AI Systems/Moneybird Accountant/cli-jortt/scripts/doctor.sh"
```

Expected: a read-only diagnostic report ending with `Mode: offline. No network calls were made.` The doctor reports whether `.env` exists and checks only the three named settings. The CLI itself can read the configured environment file when an API call needs credentials.

---

## 3. RELATED

- [`../feature-catalog/diagnostics/offline-doctor.md`](../feature-catalog/diagnostics/offline-doctor.md) describes the doctor as a catalog feature.
- [`../manual-testing-playbook/auth-and-scopes/doctor-offline.md`](../manual-testing-playbook/auth-and-scopes/doctor-offline.md) is the operator scenario that validates it.
