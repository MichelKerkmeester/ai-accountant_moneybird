---
title: "Organization check"
description: "Confirms the configured key reaches the API and prints only the HTTP status and top-level field names."
trigger_phrases:
  - "Organization check"
  - "jortt-cli whoami"
  - "check the Jortt API connection"
  - "Jortt organizations me"
version: 1.0.0.0
---

# Organization check (jortt-cli whoami)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

Confirms the configured key reaches the API and prints only the HTTP status and top-level field names.

Use it as the live connection check. The doctor calls it only when `--live` is passed.

---

## 2. HOW IT WORKS

`jortt-cli whoami` looks up the organization operation in the spec, checks its scope against `JORTT_SCOPES` and then calls `https://api.jortt.nl/organizations/me`. It prints `HTTP status:` and `Top-level field names:` with the key names joined by commas.

No value from the response is printed, so the output is safe to share as evidence. A missing organization operation in the spec exits 2. A missing scope exits 4 and a failed token request exits 6.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/jortt-cli/lib/commands.sh`](../../cli/jortt-cli/lib/commands.sh) | Handler | `jortt_cmd_whoami` runs the scope check and prints field names only. |
| [`cli/jortt-cli/lib/api.sh`](../../cli/jortt-cli/lib/api.sh) | Shared | `jortt_request` handles the token and the request. |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`manual-testing-playbook/auth-and-scopes/whoami-field-names.md`](../../manual-testing-playbook/auth-and-scopes/whoami-field-names.md) | Manual playbook | JRT-012 runs the live read and checks that no values print. |
| [`scripts/doctor.sh`](../../scripts/doctor.sh) | Test harness | Runs `whoami` when `--live` is passed. |

---

## 4. SOURCE METADATA

- Group: API calls
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `api-calls/organization-check.md`

Related references:
- [call-operation.md](call-operation.md) - Call an operation
- [raw-get.md](raw-get.md) - Raw GET
- [signed-download-fetch.md](signed-download-fetch.md) - Signed download fetch
