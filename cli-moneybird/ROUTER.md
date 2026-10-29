---
title: Moneybird CLI Router
description: Stage two routing of the Moneybird CLI packet. The hub SKILL.md picks this packet, this file routes inside it and SKILL.md holds its contract.
trigger_phrases:
  - "moneybird cli router"
  - "moneybird cli smart routing"
importance_tier: important
contextType: general
version: 1.0.0.0
router_state: active
skill_pointer: SKILL.md
---

# Moneybird CLI Router

## 1. OVERVIEW

This file holds the routing of the Moneybird CLI packet: the operation table, read-only access, phase detection, the resource loading levels and the router pseudocode. The hub [`SKILL.md`](../SKILL.md) picks this packet, this file routes inside it and [`SKILL.md`](SKILL.md) holds the packet's contract.

---

## 2. INTENT MODEL

### Read-only Access

Moneybird token scopes do not separate read access from write access. Read-only roles set `MONEYBIRD_GUARD_READ_ONLY=1` so every non-GET CLI call except a synchronization fetch is blocked before the real request. Historical sales invoices use `external_sales_invoices` and its attachment route.

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

---

## 3. MACHINE ROUTER

The machine-readable part of this router, kept verbatim: the operation table, the loading levels and the Smart Router Pseudocode. This section is the last in the file.

### Primary Detection Signal

The operation the request names picks the guarded CLI route or the Moneybird UI. Every guarded read sets `MONEYBIRD_GUARD_READ_ONLY=1`. The pseudocode below then picks the resources to load. Commands use shell variables for identifiers, periods, files and payloads.

| Operation | CLI route | Boundary |
|---|---|---|
| Administration sessions | `moneybird-guard administration list`, `moneybird-guard administration current` (Read Step Contract) or `moneybird-guard administration use "$ADMIN_ID"` | Select the intended administration and verify it before a write. Switching to the pilot passes. Any other switch is blocked by the read-only lock and otherwise needs `--confirm-write`, the writer configuration, `--production` and `--approval`. |
| Contacts | `moneybird-guard contacts list` (Read Step Contract) or `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$ADMIN_ID" contacts create --...` | Reads use the guard. Create or update only through the guarded CLI. |
| Ledger accounts | `moneybird-guard ledger_accounts list` (Read Step Contract) or `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$ADMIN_ID" ledger_accounts create --rgs_code "$RGS_CODE"` | `rgs_code` is required on create. |
| Tax rates | `moneybird-guard tax_rates list` (Read Step Contract) | Create a tax rate in the UI. |
| Historical sales invoice and PDF | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --administration "$ADMIN_ID" external_sales_invoices create --...` then `moneybird-guard --confirm-write --approval "$APPROVAL_REF" external_sales_invoices attachment "$INVOICE_ID" --file "$PDF"` | Guard every write and verify it with a later read. |
| Purchase invoice (inkoopfactuur) and attachment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents purchase_invoices create --...` then `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents purchase_invoices attachments "$DOCUMENT_ID" --file "$PDF"` | Guard every write and verify it with a later read. |
| Receipt and attachment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents receipts create --...` then `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents receipts attachments "$DOCUMENT_ID" --file "$PDF"` | Guard every write and verify it with a later read. |
| General journal document | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents general_journal_documents create --journal_type "$JOURNAL_TYPE" --"$ENTRY_FIELD" "$ENTRIES_JSON"` | The body field name is `UNVERIFIED` until confirmed with pinned CLI help. |
| Financial statement mutations | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" financial_statements create --"$MUTATION_FIELD" "$MUTATIONS_JSON"` | Do not use for bank statement imports. Resolve the JSON field from pinned CLI help. |
| Bank transactions to match | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard financial_mutations list --filter "period:YYYY,state:unprocessed"` (Read Step Contract). The list defaults to `period:this_year` since API version `v2-20260710`, and a passed filter replaces every default. The comma filter form and the `unprocessed` state match the pinned CLI's OpenAPI spec. The read covers `unprocessed` mutations only, never `auto_booked` mutations or private accounts. Past 100 records, a complete pull needs `financial_mutations sync` and `sync_fetch`, then a local state filter. | Read only. Linking is the separate gated write row "Link a payment". |
| Financial accounts | `MONEYBIRD_GUARD_READ_ONLY=1 moneybird-guard financial_accounts list` (Read Step Contract) | Needed before narrowing to one account. The pinned CLI routes it to `GET /{administration_id}/financial_accounts.json`. |
| Link a payment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" financial_mutations link_booking "$MUTATION_ID"` | Request body fields are `UNVERIFIED` until confirmed with pinned CLI help. |
| Document payment | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" documents purchase_invoices payments "$DOCUMENT_ID" --"$PAYMENT_FIELD" "$PAYMENT_JSON"` | Resolve body fields from CLI help. |
| Fixed asset | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" assets create --...` then use the confirmed `assets` value change action | Confirm the action with pinned CLI help. |
| Reports | `moneybird-guard reports profit_loss "${REPORT_DATE_ARGS[@]}"` and the matching `balance_sheet`, `general_ledger`, `journal_entries` or `tax` action (Read Step Contract) | Confirm date argument names from pinned CLI help. Each request covers at most twelve months. |
| Bulk reads | `moneybird-guard sales_invoices sync` then `moneybird-guard sales_invoices sync_fetch --ids "$ID_BATCH_JSON"` (Read Step Contract) | Use REST synchronization for complete bulk pulls. `sync_fetch` is a POST, and the guard runs it as a read, so the read-only lock lets it through. |
| Auditfile export | `moneybird-guard --confirm-write --approval "$APPROVAL_REF" reports export auditfile --year "$YEAR" --version "$AUDITFILE_VERSION"` then fetch the returned download through the confirmed downloads route | Applies to the migration route contract and to the LIVE workflows of phases 19 to 21 only, per [LIVE write authority](../sk-moneybird-accountant/SKILL.md#live-write-authority). An ordinary LIVE year uses the Operator UI export. Confirm the route with pinned CLI help. |
| CAMT.053 or MT940 import, tax rate creation, period lock or a historical VAT return (btw-aangifte) | Moneybird UI only. Mark VAT returns filed with **Submit manually (Handmatig indienen)** in chronological order. | Operator action. |

### Resource Loading Levels

| Level | When to load | Resources |
|---|---|---|
| ALWAYS | Every Moneybird task | `SKILL.md` and this file |
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
    "TROUBLESHOOT": {"weight": 8, "keywords": ["401", "403 scope", "404 administration", "422", "429", "stale get", "exit 1", "exit 2", "exit 3", "exit 4", "exit 5", "exit 6", "exit 7", "exit 8", "exit 9", "--print-body", "needs authentication"]},  # canonical exit-code table: references/cli.md
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
