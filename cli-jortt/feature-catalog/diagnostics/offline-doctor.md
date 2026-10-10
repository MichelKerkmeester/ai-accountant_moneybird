---
title: "Offline doctor"
description: "Reports tool availability, CLI location, credential presence and spec state without printing secrets or calling the network."
trigger_phrases:
  - "Offline doctor"
  - "scripts/doctor.sh"
  - "diagnose the Jortt setup"
  - "doctor --live"
version: 1.0.0.0
---

# Offline doctor (scripts/doctor.sh)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Reports tool availability, CLI location, credential presence and spec state without printing secrets or calling the network.

Run it before a session or when a command fails. Its output is safe to paste because it never shows a value.

---

## 2. HOW IT WORKS

### Core Behavior

`bash scripts/doctor.sh` reports Bash, `curl`, `jq` and the CLI location. It reports whether `.env` exists and prints `set` or `unset` for `JORTT_CLIENT_ID`, `JORTT_CLIENT_SECRET` and `JORTT_SCOPES`. It also states whether the configured scopes contain `:write`. When a spec file is present it runs `spec info`. The report ends with `Mode: offline. No network calls were made.`

### Live Mode

`--live` adds a `whoami` call when both client values are set. Live mode makes a network request, so run it only when the operator allows it.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`scripts/doctor.sh`](../../scripts/doctor.sh) | Script | Runs the offline checks and the optional live checks. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/auth-and-scopes/doctor-offline.md`](../../manual-testing-playbook/auth-and-scopes/doctor-offline.md) | Manual playbook | JRT-001 runs the doctor offline. |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Reference | Places the doctor in the diagnostic order. |

---

## 4. SOURCE METADATA

- Group: Diagnostics
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `diagnostics/offline-doctor.md`

Related references:
- [setup-check.md](setup-check.md) - CLI setup check
