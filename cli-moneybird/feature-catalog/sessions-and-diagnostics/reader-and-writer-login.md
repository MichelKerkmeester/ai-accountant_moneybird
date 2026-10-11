---
title: "Reader and writer login"
description: "login-from-env reads the token from .env or with --writer from .env.writer and passes it to the CLI through stdin with all CLI output suppressed."
trigger_phrases:
  - "reader and writer login"
  - "moneybird login from env"
  - "moneybird writer login"
  - "login-from-env --writer"
version: 1.0.0.0
---

# Reader and writer login (login-from-env)

<!-- sk-doc-template: skill_asset_feature_catalog -->

## 1. OVERVIEW

login-from-env reads the token from .env or with --writer from .env.writer and passes it to the CLI through stdin with all CLI output suppressed.

Credentials stay in the operator files and never pass through chat or the process list. The reader and writer tokens also live in separate CLI sessions.

---

## 2. HOW IT WORKS

`moneybird-guard login-from-env` reads `MONEYBIRD_API_TOKEN` from the Accountant folder `.env` and sends it to `moneybird-cli login` on stdin, so the token never appears in the CLI argument list. All CLI output is discarded and the guard prints only a completion line or the failing exit status. The command takes no other CLI arguments and refuses `--out`.

With `--writer` the guard reads `.env.writer` instead and points the CLI at `$HOME/.config/moneybird-cli-writer`, so the writer session never overwrites the reader session. The guard ignores `MONEYBIRD_WRITER_CONFIG_DIR` unless the test-only `MONEYBIRD_GUARD_TEST=1` flag is set. A missing or empty token exits 1 without calling the CLI.

---

## 3. SOURCE FILES

### Implementation

| File | Layer | Role |
|---|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Script | Reads the selected credential file and logs in through stdin |
| [`INSTALL-GUIDE.md`](../../INSTALL-GUIDE.md) | Shared | Operator credential and login steps |

### Validation And Tests

| File | Type | Role |
|---|---|---|
| [`cli/moneybird-cli/tests/run-tests.sh`](../../cli/moneybird-cli/tests/run-tests.sh) | Automated test | Reader and writer logins keep fake tokens out of output and argv |
| [MBD-011](../../manual-testing-playbook/setup/login-keeps-tokens-hidden.md) | Manual playbook | Operator check with throwaway tokens in a temporary folder |

---

## 4. SOURCE METADATA

- Group: Sessions And Diagnostics
- Canonical catalog source: `feature-catalog.md`
- Feature file path: `sessions-and-diagnostics/reader-and-writer-login.md`

Related references:
- [local-doctor.md](local-doctor.md) - Reports whether the reader and writer sessions exist
- [feature-catalog.md](../feature-catalog.md) - Root catalog for every feature
