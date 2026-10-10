---
title: "Local doctor"
description: "scripts/doctor.sh reports commands, the CLI pin, config folders and credential-file presence without opening credentials and calls the network only with --live."
trigger_phrases:
  - "local doctor"
  - "moneybird doctor"
  - "scripts/doctor.sh"
  - "moneybird offline diagnostics"
version: 1.0.0.0
---

# Local doctor (doctor.sh)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

scripts/doctor.sh reports commands, the CLI pin, config folders and credential-file presence without opening credentials and calls the network only with --live.

The doctor is the first check after setup and the first step of troubleshooting. Its offline mode is safe for an agent to run because it reads no credential.

---

## 2. HOW IT WORKS

The offline run reports whether `bash`, `curl`, `jq` and `git` exist, whether `moneybird-cli` is on PATH and what `setup.sh --check` says. It reports whether the reader and writer config folders exist, whether `.env` and `.env.writer` exist and whether the main Moneybird variables are set in the process environment. It never opens the credential files and never prints a value.

With `--live` and a token in the process environment, it calls the administrations endpoint once and prints the HTTP status, the administration count and a yes or no for each configured administration ID without printing the IDs. The doctor always exits 0 and writes no scratch files.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`scripts/doctor.sh`](../../scripts/doctor.sh) | Script | Offline and live diagnostics |
| [`scripts/README.md`](../../scripts/README.md) | Shared | Doctor usage and expected output |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [MBD-001](../../manual-testing-playbook/setup/doctor-offline.md) | Manual playbook | Operator check of the offline run |
| [`references/troubleshooting.md`](../../references/troubleshooting.md) | Reference | Places the doctor in the diagnostic order |

---

## 4. SOURCE METADATA

- Group: Sessions And Diagnostics
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `sessions-and-diagnostics/local-doctor.md`

Related references:
- [reader-and-writer-login.md](reader-and-writer-login.md) - Creates the sessions the doctor reports
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
