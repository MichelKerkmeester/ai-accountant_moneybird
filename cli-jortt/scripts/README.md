---
title: "cli-jortt Scripts"
description: "Local diagnostics for the cli-jortt skill. The doctor reports setup state without printing secrets or calling Jortt by default."
trigger_phrases:
  - "cli-jortt doctor"
  - "jortt offline diagnostics"
version: 1.0.0.0
---

# cli-jortt Scripts

---

## 1. OVERVIEW

`cli-jortt/scripts/` holds the local doctor for the Jortt skill. Nothing here calls Jortt unless you ask for it.

`doctor.sh` checks command availability, CLI location, spec cache state and whether the named Jortt settings are present in the environment or the configured `.env` file. It reads those settings in memory and prints set or unset status only. It makes no network call. Run `jortt-cli whoami` for a live check.

---

## 2. KEY FILES

| File | Responsibility |
|---|---|
| `doctor.sh` | Reports Bash, curl, jq and CLI availability, the three named Jortt settings, whether the configured scopes contain `:write` and the OpenAPI cache state. It exits 0 and makes no network call |

---

## 3. VALIDATION

Run from the repository root.

```bash
bash cli-jortt/scripts/doctor.sh
```

Expected result: a read-only diagnostic report that ends with `Mode: offline. No network calls were made.` The doctor reports whether `.env` exists and checks only the three named settings. The CLI itself can read the configured environment file when an API call needs credentials.

---

## 4. RELATED

- [`../feature-catalog/diagnostics/offline-doctor.md`](../feature-catalog/diagnostics/offline-doctor.md) describes the doctor as a catalog feature.
- [`../manual-testing-playbook/auth-and-scopes/doctor-offline.md`](../manual-testing-playbook/auth-and-scopes/doctor-offline.md) is the operator scenario that validates it.
