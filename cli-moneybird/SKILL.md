---
name: cli-moneybird
description: Works Moneybird through the official moneybird-cli behind a write guard for bookkeeping migration.
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
version: 1.0.0.0
nav_label: "Moneybird CLI"
---

<!-- Keywords: moneybird, moneybird-cli, moneybird-guard, moneybird rest api, bookkeeping migration, accounting migration, jortt migration, pilot administration, confirm write, period filter, read-only lock -->

# Moneybird Migration Skill

Rebuild historical bookkeeping in Moneybird through REST API v2. The official `moneybird-cli` is the API surface behind `moneybird-guard`.

---

## 1. WHEN TO USE

### Activation Triggers

Use this skill when the user asks to:

- Read Moneybird administrations, contacts, documents, ledger accounts, reports or synchronization data.
- Create or correct Moneybird records during a Jortt to Moneybird migration.
- Attach historical source documents, import external sales invoices or link payments.
- Prepare a pilot write, repeat a verified batch or rehearse the correction path.
- Set up or diagnose the official Moneybird CLI and guard.

Keyword triggers: `moneybird`, `moneybird-cli`, `moneybird-guard`, Moneybird REST API v2, opening balance, external sales invoice, purchase invoice (inkoopfactuur), financial mutation, auditfile, pilot administration, write confirmation, read-only lock and period filter.

### Use Cases

- **Migration writes:** pilot administration first, then approved production batches.
- **Verification reads:** an explicit period per year and synchronization for bulk pulls.
- **Setup and diagnosis:** the pinned CLI and reader and writer logins.

### When NOT to Use

- Jortt reads and source exports belong to the sibling `cli-jortt` skill.
- Bank statement file import, tax rate creation, period locking and manual VAT filing stay in the Moneybird UI.
- Do not use the skill to move private finance files or to write data outside the migration workspace.

---

## 2. SMART ROUTING

This skill is a packet of the repository hub. Its routing lives in [`ROUTER.md`](ROUTER.md) beside this file: the operation table, read-only access, phase detection, the resource loading levels and the router pseudocode. Read the hub [`SKILL.md`](../SKILL.md) first, then `ROUTER.md`, then this file.

---

## 3. HOW IT WORKS

### Surface Comparison

| Surface | Best use | Auth and limits |
|---|---|---|
| `moneybird-guard` and official CLI | REST v2 reads, writes, attachments and synchronization | Set `MONEYBIRD_GUARD_READ_ONLY=1` for read-only roles. Other writes need `--confirm-write`, the writer configuration, `--approval` and the pilot gate, with `--production` only after operator approval. |
| Moneybird UI | Bank file imports, tax rates, period locks and manual VAT status | Operator action only. |

### Reader and Writer Sessions

The reader token lives in `.env` and, from the pilot phase onward, the write token lives in `.env.writer`. `moneybird-guard login-from-env` logs in the reader. Adding `--writer` logs in the writer under `~/.config/moneybird-cli-writer`, a session separate from the reader. The guard pins its own repository root, the `moneybird-cli` binary on PATH and the writer configuration folder. It reads the pilot administration ID only from the root `.env` file. `MONEYBIRD_GUARD_TEST=1` is a test-only flag. The variables `MONEYBIRD_ENV_DIR`, `MONEYBIRD_CLI`, `MONEYBIRD_WRITER_CONFIG_DIR`, `MONEYBIRD_HMAC_KEY_FILE` and `MONEYBIRD_PILOT_ADMINISTRATION_ID` are honored only when that flag is set. Real sessions never set it. Without the flag the guard warns that an override is ignored and carries on with the pinned value. The guard never puts a token in CLI arguments and suppresses the CLI login output.

Moneybird token scopes do not separate read from write. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` before guarded CLI reads. The lock blocks every non-GET method except a synchronization fetch even if write flags are present. The lock covers Moneybird calls only: local state changes, such as journal and workspace files, and attachment downloads, which are GET reads that land in `migration-workspace/` only, are not blocked by it.

### Read Step Contract

- **Lock** Set `MONEYBIRD_GUARD_READ_ONLY=1` on every guarded read.
- **Period** Pass an explicit period on every list.
- **Paging** Prove completeness. Page until a short page, dedupe by record id and record the count.
- **Caps** A list caps at 100 records, so larger reads use synchronization. The pinned CLI sends `sync_fetch` as `POST /synchronization`. The guard runs exactly that path as a read, so it passes the read-only lock and needs no write gate. Every other POST stays a write. A report longer than twelve months splits into parts that each record period and count and reconcile to the whole. Reports are limited to 50 per five minutes.
- **Staleness** LIVE: the write response is first proof. Read-back follows the canonical read-back sentence in the write contract. A wait-based read-back needs an Operator-recorded horizon, so LIVE read-back runs by synchronization only, and MIGRATION keeps the M2 and M5 approved horizon.
- **Retry** The guard and the official CLI never retry, so the caller owns every retry, GET only. A synchronization fetch counts as a GET here, because it only reads. Wait for `Retry-After` first. In LIVE work, otherwise use capped exponential backoff with full jitter and a bounded attempt count `LIVE_GET_MAX_ATTEMPTS` of 3 and a backoff ceiling `LIVE_GET_BACKOFF_CEILING` of 60 seconds. A third failed GET stops the read for the Operator. In MIGRATION work a 429 follows the `HTTP_429` row of the shared mechanisms, which allows one Orchestrator-authorized reissue for a read. Never retry a non-GET call.

### Write Path

```text
STEP 1: Approve the batch in the migration plan
       ↓
STEP 1b: Preconditions: the trial or package has not expired, the phase gate has passed, the Operator approved the batch and a WRITE_INTENT was flushed to the run journal. The guard does not check expiry.
       ↓
STEP 2: Guarded dry-run reads the first METHOD URL line
       ↓
STEP 3: Gates, in this order (canonical exit-code table: references/cli.md)
       ├─ Argument conflict, --out on a passthrough command or --print-body in an agent session: exit 2
       ├─ --out outside migration-workspace or through a symlink, or into its .secrets, RunJournal or logs folder: exit 5
       ├─ Dry-run did not start with a METHOD URL line: exit 2
       ├─ Read-only lock on: exit 6
       ├─ No --confirm-write: print the preview and its payload digest and exit 3 (a missing HMAC key exits 1 here)
       ├─ Writer configuration folder missing: exit 7
       ├─ Target is not the pilot and no --production: exit 4
       ├─ Missing or unmatched --approval: exit 8
       ├─ HMAC key file missing or unreadable: exit 1
       ├─ Payload digest missing or mismatched: exit 9 (`PAYLOAD_MISMATCH`)
       └─ Approval reference already consumed for this digest: exit 8
       ↓
STEP 4: Real call, then one body-free JSONL record in migration-workspace/logs/
       ↓
STEP 5: Later read-back
       └─ Read-back follows the canonical read-back sentence in the write contract
```

See `sk-moneybird-accountant/SKILL.md` for the phase gates. The write contract, the evidence rule, the idempotency rule, the exit set and the canonical read-back sentence are in [shared mechanisms](../sk-moneybird-accountant/references/migration/shared-mechanisms.md#route-contract).

Every guarded read runs with `MONEYBIRD_GUARD_READ_ONLY=1`. Outside the LIVE workflows of migration phases 19 to 21, a LIVE Moneybird write is an Operator UI action. Writes target the pilot administration unless the plan's gate allows a production batch and the operator gives an explicit go for that batch. Every write runs in the writer session through `moneybird-guard` with `--confirm-write` and `--approval "$APPROVAL_REF"` for a flushed `WRITE_INTENT` that carries the `payload_digest`, with `--production` only for an approved production batch. The [write contract](../sk-moneybird-accountant/references/migration/shared-mechanisms.md#route-contract) owns the command shape, the gate order, the evidence rule, the idempotency rule and the exit set.

### Output Location

Saved records, attachments, reports and migration logs belong under `migration-workspace/`. Keep personal finance data out of this skill, tracked files, commits and other services. This skill does not use Code Mode.

---

## 4. RULES

### ✅ ALWAYS

- Use the official pinned CLI through `moneybird-guard` for REST calls. Review `--dry-run` output before each confirmed write.
- Keep writes on the pilot administration until the migration plan's gate permits the production batch.
- Use `--production` only after the operator explicitly approves that batch.
- Set an explicit period on every verification list. Use synchronization for bulk reads.
- Check the write's own status first. Treat an immediate GET as potentially stale.
- Keep under 150 requests per five minutes and under 50 requests per five minutes for reports. On `429`, wait for `Retry-After` before retrying.
- Keep outputs under `migration-workspace/` and use the guard's `--out` boundary for saved API responses.

### ❌ NEVER

- Never write without `--confirm-write` and a matching `--approval` reference, or use `--production` without the operator's explicit go for that batch.
- Never trust the default period on a verification list. It can silently omit older years.
- Never use `GET /financial_mutations` as a complete bulk export. The endpoint is capped at one hundred records.
- Never use the deprecated sales invoice `register_payment` action. Its sunset is 2026-12-31. Use `financial_mutations link_booking` or document payments.
- Never call an API write directly through `moneybird-cli`. Use the guarded CLI and confirm deletion with a separate read because `204` can mean nothing was deleted.
- Never pass `--print-body` to `moneybird-guard`. It is for the operator only, and the guard refuses it (exit 2) when any agent session marker is set (`CLAUDECODE`, `AI_SESSION_CHILD`, `ACCOUNTANT_AGENT_SESSION` or `CODEX_SANDBOX`). Use `--out` and read the saved file instead.
- Never write financial data outside `migration-workspace/` or into tracked files, commits or other services.
- Never print or inspect `.env`, `.env.writer` or a credential. Use `login-from-env` and the doctor checks.
- Never open, list, search or read `personal database/`.

### ⚠️ ESCALATE IF

- The operation, request fields or administration cannot be confirmed from the pinned CLI help and supplied facts.
- The planned target is not the pilot and the operator has not approved the production batch.
- A duplicate, missing source document, uncertain tax treatment, locked period or unexplained difference appears.
- A write response does not match the approved record or a `429` persists after `Retry-After`.

---

## 5. REFERENCES

### Core References

- [`ROUTER.md`](ROUTER.md) holds the operation table, the loading levels and the router.
- [`references/cli.md`](references/cli.md) covers the adopted CLI, guard flags, login and the project survey.
- [`references/rest-api.md`](references/rest-api.md) records API auth, scopes, paging, caching and endpoint limits.
- [`references/migration-recipes.md`](references/migration-recipes.md) gives guarded command sequences for migration work.
- [`references/troubleshooting.md`](references/troubleshooting.md) maps common failures to safe next steps.
- [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) covers setup, credentials, verification and rollback.

### Inventory and Validation

- [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) lists what the package does today, with source and test anchors for each feature.
- [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) indexes the operator scenarios that validate those features.

### Reference Loading Notes

Load only the reference the selected operation needs. [`ROUTER.md`](ROUTER.md) section 2 is the single authority for loading rules.

---

## 6. SUCCESS CRITERIA

### Package Check Completion Checklist

A local package check is complete when:

- [ ] `bash scripts/doctor.sh` completes the offline checks without printing credential values.
- [ ] `bash cli/moneybird-cli/tests/run-tests.sh` passes against its local stub.
- [ ] `setup.sh --check` reports the pinned CLI state accurately.
- [ ] With an operator-approved live check, `bash scripts/doctor.sh --live` reports HTTP 200 from the administrations endpoint and whether configured administration selections are present, without printing their IDs.

### Migration Batch Quality Gates

A migration batch is verified when:

- [ ] The plan gate and operator approval cover the exact batch.
- [ ] The pilot write and its undo rehearsal have passed before production work begins.
- [ ] Write responses match the approved records and later synchronization reads confirm the records.
- [ ] Required reports cover explicit periods and no unresolved stop condition remains.

---

## 7. INTEGRATION POINTS

### Migration Plan

The migration plan is [migration/README.md](../sk-moneybird-accountant/references/migration/README.md). Phase 7 runs the pilot and rehearses an undo. Phase 8 moves approved records quarter by quarter. Later phases verify VAT, year-end totals and period locks.

### Sibling Skill and Credentials

Use [`../cli-jortt/`](../cli-jortt/SKILL.md) for read-only Jortt source work. `.env` holds the Moneybird reader token and administration settings. `.env.writer` holds the separate write token after the pilot gate. Never read either file directly.

### External Surfaces

The official `moneybird/moneybird-cli` owns REST routing from the OpenAPI spec. `moneybird-guard` adds the local safety checks. The UI owns the operator-only steps.

---

## 8. QUICK REFERENCE

| Goal | Command |
|---|---|
| Check the local CLI pin | `bash cli/moneybird-cli/setup.sh --check` |
| Log in with the reader token | `moneybird-guard login-from-env` |
| Log in with the writer token | `moneybird-guard login-from-env --writer` |
| Inspect an API route | `moneybird-cli contacts create --help` |
| Read a year of invoices | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard sales_invoices list --filter period:YYYY` |
| List synchronization IDs | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard sales_invoices sync` |
| Preview a write | `moneybird-guard contacts create --...` |
| Run offline diagnostics | `bash scripts/doctor.sh` |
| Run offline guard tests | `bash cli/moneybird-cli/tests/run-tests.sh` |

