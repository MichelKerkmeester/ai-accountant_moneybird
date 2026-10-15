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

Keyword triggers: `moneybird`, `moneybird-cli`, `moneybird-guard`, Moneybird REST API v2, opening balance, external sales invoice, purchase invoice, financial mutation, auditfile, pilot administration, write confirmation, read-only lock and period filter.

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

### Primary Detection Signal

The operation the request names picks the guarded CLI route or the Moneybird UI. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` before CLI reads. The pseudocode below then picks the resources to load. Commands use shell variables for identifiers, periods, files and payloads.

| Operation | CLI route or boundary |
|---|---|
| Administration sessions | `moneybird-guard administration list`, `moneybird-guard administration current` (Read Step Contract) or `moneybird-guard administration use "$ADMIN_ID"` | Select the intended administration and verify it before a write. Switching to the pilot passes. Any other switch is blocked by the read-only lock and otherwise needs `--confirm-write`, the writer configuration, `--production` and `--approval`. |
| Contacts | `moneybird-guard contacts list` (Read Step Contract) or `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$ADMIN_ID" contacts create --...` | Reads use the guard. Create or update only through the guarded CLI. |
| Ledger accounts | `moneybird-guard ledger_accounts list` (Read Step Contract) or `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$ADMIN_ID" ledger_accounts create --rgs_code "$RGS_CODE"` | `rgs_code` is required on create. |
| Tax rates | `moneybird-guard tax_rates list` (Read Step Contract) | Create a tax rate in the UI. |
| Historical sales invoice and PDF | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$ADMIN_ID" external_sales_invoices create --...` then `moneybird-guard --confirm-write --approval "$APPROVAL_REF" external_sales_invoices attachment "$INVOICE_ID" --file "$PDF"` | Guard every write and verify it with a later read. |
| Purchase invoice and attachment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents purchase_invoices create --...` then `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents purchase_invoices attachments "$DOCUMENT_ID" --file "$PDF"` | Guard every write and verify it with a later read. |
| Receipt and attachment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents receipts create --...` then `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents receipts attachments "$DOCUMENT_ID" --file "$PDF"` | Guard every write and verify it with a later read. |
| General journal document | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents general_journal_documents create --journal_type "$JOURNAL_TYPE" --"$ENTRY_FIELD" "$ENTRIES_JSON"` | The body field name is `UNVERIFIED` until confirmed with pinned CLI help. |
| Financial statement mutations | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" financial_statements create --"$MUTATION_FIELD" "$MUTATIONS_JSON"` | Do not use for bank statement imports. Resolve the JSON field from pinned CLI help. |
| Bank transactions to match | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard financial_mutations list --filter "period:YYYY,state:unprocessed"` (Read Step Contract). The list defaults to `period:this_year` since API version `v2-20260710`, and a passed filter replaces every default. The comma filter form and the `unprocessed` state match the pinned CLI's OpenAPI spec. The read covers `unprocessed` mutations only, never `auto_booked` mutations or private accounts. Past 100 records, read through `financial_mutations sync` and `sync_fetch` and filter the state locally. Linking is the separate gated write row "Link a payment". |
| Financial accounts | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard financial_accounts list` (Read Step Contract) | Needed before narrowing to one account. The pinned CLI routes it to `GET /{administration_id}/financial_accounts.json`. |
| Link a payment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" financial_mutations link_booking "$MUTATION_ID"` | Request body fields are `UNVERIFIED` until confirmed with pinned CLI help. |
| Document payment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents purchase_invoices payments "$DOCUMENT_ID" --"$PAYMENT_FIELD" "$PAYMENT_JSON"` | Resolve body fields from CLI help. |
| Fixed asset | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" assets create --...` then use the confirmed `assets` value change action | Confirm the action with pinned CLI help. |
| Reports | `moneybird-guard reports profit_loss "${REPORT_DATE_ARGS[@]}"` and the matching `balance_sheet`, `general_ledger`, `journal_entries` or `tax` action (Read Step Contract) | Confirm date argument names from pinned CLI help. Each request covers at most twelve months. |
| Bulk reads | `moneybird-guard sales_invoices sync` then `moneybird-guard sales_invoices sync_fetch --ids "$ID_BATCH_JSON"` (Read Step Contract) | Use REST synchronization for complete bulk pulls. |
| Auditfile export | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" reports export auditfile --year "$YEAR" --version "$AUDITFILE_VERSION"` then fetch the returned download through the confirmed downloads route | Applies to the migration route contract and to the LIVE workflows of phases 19 to 21 only, per [LIVE write authority](../sk-moneybird-accountant/SKILL.md#live-write-authority). An ordinary LIVE year uses the Operator UI export. Confirm the route with pinned CLI help. |
| CAMT.053 or MT940 import, tax rate creation, period lock or a historical VAT return | Moneybird UI only. Mark VAT returns filed with **Handmatig indienen** in chronological order. | Operator action. |

### Read-only Access

Moneybird token scopes do not separate read access from write access. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` so every non-GET CLI call is blocked before the real request. Historical sales invoices use `external_sales_invoices` and its attachment route.

Body fields and report date arguments that the supplied facts do not name stay `UNVERIFIED` until pinned CLI help and a dry-run confirm them. Never guess a field name.

### Phase Detection

```text
MONEYBIRD REQUEST
    |
    +- STEP 0: Detect the operation and pick the guarded CLI route or UI handoff
    +- STEP 1: Score intents (top-2 when close)
    +- Phase 1: Read or plan with explicit periods and a dry-run
    +- Phase 2: Confirmed pilot write or a UI handoff
    +- Phase 3: Verify by write status, then a later sync read
```

### Resource Domains

The references are flat, so the routing key selects a `RESOURCE_MAP` entry rather than a keyed folder. Discovery covers `references/` for operational guidance, `feature-catalog/` for the current-state inventory, `manual-testing-playbook/` for operator scenarios and the root `INSTALL-GUIDE.md`. Runtime code in `scripts/` and `cli/` is never routed.

### Resource Loading Levels

| Level | When to load | Resources |
|---|---|---|
| ALWAYS | Every Moneybird task | This file |
| CONDITIONAL | REST route, auth or API limit | `references/rest-api.md` and `references/cli.md` |
| CONDITIONAL | A multi-record migration action | `references/migration-recipes.md` |
| CONDITIONAL | A feature inventory or manual validation request | `feature-catalog/feature-catalog.md` and `manual-testing-playbook/manual-testing-playbook.md` |
| ON_DEMAND | Setup or failure | `INSTALL-GUIDE.md` and `references/troubleshooting.md` |

### Smart Router Pseudocode

```python
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent
RESOURCE_BASES = tuple(SKILL_ROOT / name for name in ("references", "feature-catalog", "manual-testing-playbook"))
ROOT_RESOURCES = ("INSTALL-GUIDE.md",)
DEFAULT_RESOURCE = "references/cli.md"
AMBIGUITY_DELTA = 1

INTENT_MODEL = {
    "CLI_READ": {"weight": 6, "keywords": ["read moneybird", "list contacts", "verify a year", "moneybird report", "administration"]},
    "CLI_WRITE": {"weight": 7, "keywords": ["create in moneybird", "update moneybird", "delete moneybird", "attach invoice", "link payment"]},
    "MIGRATION_RECIPE": {"weight": 7, "keywords": ["opening balance", "external sales invoice", "purchase invoice", "journal entry", "pilot migration", "correct a wrong write"]},
    "UI_ONLY": {"weight": 8, "keywords": ["camt.053 import", "mt940 import", "create tax rate", "lock a period", "handmatig indienen"]},
    "INSTALL": {"weight": 6, "keywords": ["install moneybird-cli", "moneybird token", "login-from-env"]},
    "TROUBLESHOOT": {"weight": 8, "keywords": ["401", "403 scope", "404 administration", "422", "429", "stale get", "exit 2", "exit 3", "exit 4", "exit 5", "exit 6", "exit 7", "exit 8", "exit 9", "--print-body", "needs authentication"]},  # canonical exit-code table: references/cli.md
    "FEATURE_INVENTORY": {"weight": 6, "keywords": ["feature catalog", "moneybird capabilities", "what does the moneybird skill do"]},
    "MANUAL_TEST": {"weight": 6, "keywords": ["manual testing playbook", "test scenario", "validate the guard"]},
}

RESOURCE_MAP = {
    "CLI_READ": ["references/rest-api.md", "references/cli.md"],
    "CLI_WRITE": ["references/cli.md", "references/rest-api.md", "references/troubleshooting.md"],
    "MIGRATION_RECIPE": ["references/migration-recipes.md", "references/rest-api.md"],
    "UI_ONLY": ["references/rest-api.md", "references/migration-recipes.md"],
    "INSTALL": ["INSTALL-GUIDE.md", "references/cli.md"],
    "TROUBLESHOOT": ["references/troubleshooting.md"],
    "FEATURE_INVENTORY": ["feature-catalog/feature-catalog.md"],
    "MANUAL_TEST": ["manual-testing-playbook/manual-testing-playbook.md", "feature-catalog/feature-catalog.md"],
}

UNKNOWN_FALLBACK_CHECKLIST = [
    "Confirm whether the task is a REST read, confirmed write, migration recipe or UI task",
    "Ask for the resource, period or intended output when the request does not name one",
    "Keep writes on the pilot administration until the migration plan permits production",
]

def _guard_in_skill(relative_path):
    root = SKILL_ROOT.resolve()
    resolved = (root / relative_path).resolve()
    resolved.relative_to(root)
    if resolved.suffix.lower() != ".md":
        raise ValueError("Only skill-local markdown resources are routable")
    return resolved.relative_to(root).as_posix()

def discover_markdown_resources():
    docs = [p for base in RESOURCE_BASES if base.exists() for p in base.rglob("*.md") if p.is_file()]
    docs += [SKILL_ROOT / name for name in ROOT_RESOURCES if (SKILL_ROOT / name).is_file()]
    return {doc.relative_to(SKILL_ROOT).as_posix() for doc in docs}

def classify_intents(request):
    text = str(request or "").lower()
    scores = {name: sum(cfg["weight"] for word in cfg["keywords"] if word in text) for name, cfg in INTENT_MODEL.items()}
    ranked = sorted(scores.items(), key=lambda pair: pair[1], reverse=True)
    (first, top), (second, runner_up) = ranked[0], ranked[1]
    if top == 0:
        return [], scores
    return ([first, second] if runner_up and top - runner_up <= AMBIGUITY_DELTA else [first]), scores

def get_routing_key(task, intents):
    override = str(getattr(task, "routing_key", "")).strip().upper()
    return override if override in RESOURCE_MAP else (intents[0] if intents else "unknown")

def route_moneybird_resources(request, task=None):
    inventory = discover_markdown_resources()
    intents, scores = classify_intents(request)
    routing_key = get_routing_key(task, intents)
    loaded, seen = [], set()

    def load_if_available(relative_path):
        guarded = _guard_in_skill(relative_path)
        if guarded in inventory and guarded not in seen:
            load(guarded)
            loaded.append(guarded)
            seen.add(guarded)

    if routing_key == "unknown":
        load_if_available(DEFAULT_RESOURCE)
        return {"load_level": "UNKNOWN_FALLBACK", "needs_disambiguation": True,
                "disambiguation_checklist": UNKNOWN_FALLBACK_CHECKLIST, "resources": loaded}
    for intent in dict.fromkeys([routing_key] + intents):
        for relative_path in RESOURCE_MAP.get(intent, []):
            load_if_available(relative_path)
    if not loaded:
        load_if_available(DEFAULT_RESOURCE)
        return {"routing_key": routing_key, "notice": "No mapped resource exists on disk", "resources": loaded}
    return {"routing_key": routing_key, "intents": intents, "intent_scores": scores, "resources": loaded}
```

---

## 3. HOW IT WORKS

### Surface Comparison

| Surface | Best use | Auth and limits |
|---|---|---|
| `moneybird-guard` and official CLI | REST v2 reads, writes, attachments and synchronization | Set `MONEYBIRD_GUARD_READ_ONLY=1` for read-only roles. Other writes need `--confirm-write`, the writer configuration, `--approval` and the pilot gate, with `--production` only after operator approval. |
| Moneybird UI | Bank file imports, tax rates, period locks and manual VAT status | Operator action only. |

### Reader and Writer Sessions

The reader token lives in `.env` and, from the pilot phase onward, the write token lives in `.env.writer`. `moneybird-guard login-from-env` logs in the reader. Adding `--writer` logs in the writer under `~/.config/moneybird-cli-writer`, a session separate from the reader. The guard pins its own repository root, the `moneybird-cli` binary on PATH and the writer configuration folder. It reads the pilot administration ID only from the root `.env` file. `MONEYBIRD_GUARD_TEST=1` is a test-only flag. The variables `MONEYBIRD_ENV_DIR`, `MONEYBIRD_CLI`, `MONEYBIRD_WRITER_CONFIG_DIR` and `MONEYBIRD_PILOT_ADMINISTRATION_ID` are honored only when that flag is set. Real sessions never set it. Without the flag the guard warns that an override is ignored and carries on with the pinned value. The guard never puts a token in CLI arguments and suppresses the CLI login output.

Moneybird token scopes do not separate read from write. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` before guarded CLI reads. The lock blocks every non-GET method even if write flags are present. The lock covers Moneybird calls only: local state changes, such as journal and workspace files, and attachment downloads, which are GET reads that land in `migration-workspace/` only, are not blocked by it.

### Read Step Contract

- **Lock** Set `MONEYBIRD_GUARD_READ_ONLY=1` on every guarded read.
- **Period** Pass an explicit period on every list.
- **Paging** Prove completeness. Page until a short page, dedupe by record id and record the count.
- **Caps** A list caps at 100 records, so larger reads use synchronization. A report longer than twelve months splits into parts that each record period and count and reconcile to the whole. Reports are limited to 50 per five minutes.
- **Staleness** LIVE: the write response is first proof. Read-back follows the canonical read-back sentence in the write contract. A wait-based read-back needs an Operator-recorded horizon, so LIVE read-back runs by synchronization only, and MIGRATION keeps the M2 and M5 approved horizon.
- **Retry** One owner per tool, GET only. Wait for `Retry-After` first. Otherwise use capped exponential backoff with full jitter and a bounded attempt count `LIVE_GET_MAX_ATTEMPTS` of 3 and a backoff ceiling `LIVE_GET_BACKOFF_CEILING` of 60 seconds. A third failed GET stops the read for the Operator. Never retry a non-GET call.

### Write Path

```text
STEP 1: Approve the batch in the migration plan
       ↓
STEP 1b: Preconditions: the trial or package has not expired, the phase gate has passed, the Operator approved the batch and a WRITE_INTENT was flushed to the run journal. The guard does not check expiry.
       ↓
STEP 2: Guarded dry-run reads the first METHOD URL line
       ↓
STEP 3: Gates, in this order (canonical exit-code table: references/cli.md)
       ├─ Argument conflict, or --out on a passthrough command: exit 2
       ├─ --out outside migration-workspace or through a symlink: exit 5
       ├─ Dry-run did not start with a METHOD URL line: exit 2
       ├─ Read-only lock on: exit 6
       ├─ No --confirm-write: print the preview and exit 3
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

Trial or package expiry is the Operator's check before STEP 2. See `sk-moneybird-accountant/SKILL.md` for the phase gates. The write contract, the evidence rule, the idempotency rule, the exit set and the canonical read-back sentence are in [shared mechanisms](../sk-moneybird-accountant/references/migration/shared-mechanisms.md#route-contract).

Writes target the pilot administration unless the plan's gate allows a production batch and the operator gives an explicit go for that batch. Every write runs in the writer session through `moneybird-guard` with `--confirm-write` and `--approval "$APPROVAL_REF"` for a flushed `WRITE_INTENT` that carries the `payload_digest`, with `--production` only for an approved production batch. The [write contract](../sk-moneybird-accountant/references/migration/shared-mechanisms.md#route-contract) owns the command shape, the gate order, the evidence rule, the idempotency rule and the exit set.

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

- [`references/cli.md`](references/cli.md) covers the adopted CLI, guard flags, login and the project survey.
- [`references/rest-api.md`](references/rest-api.md) records API auth, scopes, paging, caching and endpoint limits.
- [`references/migration-recipes.md`](references/migration-recipes.md) gives guarded command sequences for migration work.
- [`references/troubleshooting.md`](references/troubleshooting.md) maps common failures to safe next steps.
- [`INSTALL-GUIDE.md`](INSTALL-GUIDE.md) covers setup, credentials, verification and rollback.

### Inventory and Validation

- [`feature-catalog/feature-catalog.md`](feature-catalog/feature-catalog.md) lists what the package does today, with source and test anchors for each feature.
- [`manual-testing-playbook/manual-testing-playbook.md`](manual-testing-playbook/manual-testing-playbook.md) indexes the operator scenarios that validate those features.

### Reference Loading Notes

Load only the reference the selected operation needs. [Section 2](#2-smart-routing) is the single authority for loading rules.

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
| Read a year of invoices | `moneybird-guard sales_invoices list --filter period:YYYY` |
| Bulk read a resource | `moneybird-guard sales_invoices sync` then `moneybird-guard sales_invoices sync_fetch --ids "$ID_BATCH_JSON"` |
| Preview a write | `moneybird-guard contacts create --...` |
| Run offline diagnostics | `bash scripts/doctor.sh` |
| Run offline guard tests | `bash cli/moneybird-cli/tests/run-tests.sh` |
| Run a read-only session | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard contacts list --filter period:YYYY` |

---

## 9. REFERENCES AND RELATED RESOURCES

The router discovers reference, catalog and playbook docs dynamically. Start with `references/cli.md`, then follow [Section 2](#2-smart-routing).

Scripts: `scripts/doctor.sh` and `cli/moneybird-cli/setup.sh` plus `moneybird-guard` beside it.

Related skills: `cli-jortt` reads the Jortt source data that this skill writes into Moneybird.

Install guide: [INSTALL-GUIDE.md](INSTALL-GUIDE.md).
