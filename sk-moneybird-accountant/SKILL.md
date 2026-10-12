---
name: sk-moneybird-accountant
description: Routes Dutch ZZP migration and bookkeeping work to approved references and Jortt or Moneybird tools.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
version: 1.0.0.0
---

<!-- Keywords: Dutch ZZP bookkeeping, Jortt to Moneybird migration, monthly bookkeeping, quarterly VAT review, year-end bookkeeping, current-year tax figures, sole trader expenses -->

# Moneybird Accountant

A bookkeeping and migration assistant for a Dutch sole trader. It routes historical migration work and live bookkeeping through documented gates, keeps records traceable, and leaves tax judgement and return filing to the operator or a bookkeeper.

---

## 1. WHEN TO USE

### Activation Triggers

Use this skill when the request concerns:

- Moving historical sole-trader records from Jortt to Moneybird.
- Monthly, quarterly, or yearly bookkeeping in Moneybird.
- Classifying a business cost, private-use event, asset, mileage record, or VAT item.
- A general Dutch ZZP question about income tax, VAT, deductions, or administration.
- A reconciliation, exception, or migration gate that needs review.

### Use Cases

- Identify a migration phase and load its specific gate and owner instructions.
- Reconcile bookkeeping records against source documents and filed returns.
- Review a live bookkeeping period and prepare a clear exception list.
- Explain general accounting treatment while flagging legal or factual judgement for a human.

### When NOT to Use

Do not use this skill to file an income-tax or VAT return, make a final tax decision, or work in another country's tax system. Do not use it to read private financial data outside the migration rule below.

---

## 2. SMART ROUTING

### Primary Detection Signal

Select MIGRATION when the request mentions historical records, Jortt exports, a migration phase, reconciliation, pilot writes, year locks, or moving records into Moneybird.

Select LIVE when the request concerns the current bookkeeping cadence, an ordinary income or cost event, a VAT period, an annual close, or an ad hoc ZZP question.

If the request is ambiguous between the two modes, ask one concise question about whether it concerns historical migration or current bookkeeping. Do not guess a phase or a tax year.

### Resource Domains

- Migration references contain the phase plan, gates, controls, and Jortt to Moneybird mapping.
- Tax and bookkeeping references contain general Dutch ZZP rules and accounting treatment.
- The Jortt tool skill owns Jortt CLI reads.
- The Moneybird tool skill owns Moneybird CLI reads and writes through moneybird-guard.
- Feature catalog files describe this skill's current behavior.
- Manual testing files contain offline routing checks only.

### Resource Loading Levels

| Level | When to load | Resources |
|---|---|---|
| ALWAYS | Every task | This skill and the project bootstrap |
| MIGRATION | Historical migration request | Migration index, the matching phase group, and control framework when a gate, exception, risk, or year lock applies |
| LIVE BOOKKEEPING | Monthly, quarterly, yearly, or event-level bookkeeping | Moneybird bookkeeping reference, the purchase invoice reference when a purchase invoice, receipt or order is booked, plus the tax index and the year file for any tax topic. During post-cutover migration monitoring, also load references/migration/README.md and references/migration/phases-19-to-21.md. |
| ZZP QUESTION | Tax, VAT, costs, vehicle, or administration question | Tax and VAT reference, then bookkeeping reference if a posting is also requested |
| CLI ACTION | A Jortt or Moneybird CLI operation is needed | The matching sibling tool skill before using that CLI |

### Smart Router Pseudocode

Discover local references at request time, guard each selected path inside the skill root, and load only available resources. The fallback asks for the missing route information instead of silently loading nothing.

    from pathlib import Path

    SKILL_ROOT = Path(__file__).resolve().parent
    RESOURCE_BASES = (SKILL_ROOT / "references",)
    UNKNOWN_FALLBACK = {
        "load_level": "UNKNOWN_FALLBACK",
        "needs_disambiguation": True,
        "checklist": [
            "Confirm historical migration versus current bookkeeping",
            "Confirm the last passed migration gate or current tax year",
        ],
    }

    def discover_markdown_resources():
        docs = []
        for base in RESOURCE_BASES:
            if base.exists():
                docs.extend(path for path in base.rglob("*.md") if path.is_file())
        return {doc.relative_to(SKILL_ROOT).as_posix() for doc in docs}

    def _guard_in_skill(relative_path):
        resolved = (SKILL_ROOT / relative_path).resolve()
        resolved.relative_to(SKILL_ROOT)
        if resolved.suffix.lower() != ".md":
            raise ValueError("Only local markdown references can be loaded")
        return resolved.relative_to(SKILL_ROOT).as_posix()

    def load_if_available(relative_path, inventory, loaded):
        guarded = _guard_in_skill(relative_path)
        if guarded in inventory and guarded not in loaded:
            load(guarded)
            loaded.append(guarded)

    def route_resources(request):
        inventory = discover_markdown_resources()
        loaded = []
        mode = detect_mode(request)
        if mode == "UNKNOWN":
            load_if_available("references/migration/README.md", inventory, loaded)
            return {**UNKNOWN_FALLBACK, "resources": loaded}
        if mode == "MIGRATION":
            load_if_available("references/migration/README.md", inventory, loaded)
            load_if_available(phase_reference(request), inventory, loaded)
            if needs_gate_or_control(request):
                load_if_available("references/migration/control-framework.md", inventory, loaded)
        if mode == "LIVE":
            for resource in live_references_for(request):
                load_if_available(resource, inventory, loaded)
        return {"mode": mode, "resources": loaded}

### Migration Phase Routing

- Phases 0 to 2 cover setup, source inventory, and archive seeding.
- Phases 3 to 5 cover independent reconstruction, cross-reconciliation, and anomaly review.
- Phases 6 to 9 cover mapping, pilot, historical period writes, and VAT verification.
- Phases 10 to 16 cover annual checks, continuity, year locks, and cutover preparation.
- Phase 17 freezes the source and verifies the archive. Phase 18 switches to live bookkeeping.
- Phases 19 to 21 are recurring monthly, VAT-period, and yearly loops that start when Phase 18 passes.
- Phase 22 is a one-time completion and Jortt decommission gate after the configured monitoring period.

The index maps every phase to its reference file. Use the last verified exit gate before advancing. Do not infer a pass from work that appears complete. Jortt stays uncancelled until Phase 22 passes and the Operator records a cancel-or-keep decision.

Every phase uses the route contract in the shared mechanisms reference. Jortt reads run through jortt-cli only, XAF and other Jortt exports are Operator UI tasks, Moneybird reads run through moneybird-guard with `MONEYBIRD_GUARD_READ_ONLY=1`, a Moneybird write needs a passed gate, Operator approval, `--confirm-write` and `--approval <ref>` for a flushed `WRITE_INTENT` journal entry, plus `--production` for a production batch, and an HTTP 429 stops the call sequence for a guarded read-back before any retry.

---

## 3. HOW IT WORKS

### MIGRATION Mode

1. Read the project bootstrap, then this skill.
2. Read the migration index and identify the next phase from the last verified gate.
3. Load the matching phase file and [shared mechanisms](./references/migration/shared-mechanisms.md). Use M12 for the Agent runner, Implementer, Verifier, Final reviewer, and separate Migration Writer seats. Load the control framework when a gate, risk, exception, stop, or year lock applies. Work the phase from its packet in the Operator's working copy of the spec-kit template, `specs/001-migration/` by default, which `scripts/init-workspace.sh` copies from `specs/000-migration-template/`. After editing a phase reference, run `python3 -I scripts/generate-plan-kit.py` and confirm `--check` passes.
4. Keep the phase contract's exact owner tags. The Operator owns approvals, UI exports, bank imports, period locks, return filing, and accounting decisions.
5. Route Jortt reads through jortt-cli. Route Moneybird reads and approved writes through moneybird-guard. Keep `MONEYBIRD_GUARD_READ_ONLY=1` for every reader session. Open a separate approved writer session for non-GET calls and do read-back in a new locked reader session.
6. Before every Moneybird non-GET batch, verify the current trial or package expiry, phase gate, Operator approval, and flushed `WRITE_INTENT`. Use stable local write keys and journal every state change.
7. Keep work in migration-workspace/. Stop on any failed gate or open stop condition. Resume from the last verified journal state. After Phase 18 passes, use the phase 19 to 21 contracts for recurring migration cycles until Phase 22 passes. Never cancel Jortt before Phase 22 passes.

### LIVE Mode

#### Monthly bookkeeping

- Review the period's sales, purchase documents, bank transactions, private movements, and outstanding exceptions.
- Match each bank transaction to its invoice, receipt, category, or private account.
- Check that purchase documents are processed before treating them as booked or included in VAT.
- Keep source documents and explain unmatched items. Route Moneybird CLI reads or writes through moneybird-guard.

#### Quarterly bookkeeping

- Confirm the VAT period assigned to the administration and the applicable return deadline.
- Reconcile VAT by return box against source documents and booked transactions.
- Prepare a review summary for the operator. Never submit or file the return.
- Treat cross-border VAT, reverse charge, mixed-use VAT, and corrections as judgement points for the operator or a bookkeeper.
- Use moneybird-guard for every Moneybird CLI read or write. Set MONEYBIRD_GUARD_READ_ONLY=1 for read-only sessions.

#### Yearly bookkeeping

- Reconcile profit and loss, balance sheet, assets, depreciation, private use, mileage, and year-end VAT adjustments.
- Compare annual totals to the bookkeeping evidence and the relevant filed records.
- Lock a period only when the applicable workflow has passed and the operator directs the action.
- Route Moneybird CLI work through moneybird-guard. Keep income-tax return preparation and filing with the operator or a bookkeeper.

#### Ad hoc ZZP questions

- Check the current tax year before using any rate, threshold, deduction, or vehicle rule.
- Load references/YYYY/README.md for the tax year in question, then the topic file in that folder, such as references/YYYY/btw.md, inkomstenbelasting.md, zvw.md, ondernemersaftrek.md, investeringen.md, kosten-en-auto.md, box-3.md, box-2.md, bv-en-vennootschapsbelasting.md, pensioen-en-aov.md, arbeidsrelatie.md or procedure.md. Load references/dutch-tax-rules.md when the question is how a rule works across years.
- Explain general rules with the year and source. Label conflicting or unverified points clearly.
- Do not present a case-specific tax conclusion as final. Flag judgement calls for the operator or a bookkeeper.

### Output Contract

Return the mode or phase used, a safe decision summary, the references consulted, and any exception or Operator action that remains. Use only phase and record-class labels, opaque keys, aggregate counts, status, and evidence paths. Do not expose names, account identifiers, invoice numbers, amounts, or source payloads. Put migration deliverables under migration-workspace/. Do not create an export/ folder.

---

## 4. RULES

### ✅ ALWAYS

1. Check the current year before relying on any tax figure.
2. Keep a clear distinction between confirmed rules, product documentation, conflicting values, and unverified points.
3. Route every Jortt CLI read through jortt-cli, following cli-jortt/SKILL.md.
4. Route every Moneybird CLI read or write through moneybird-guard, following cli-moneybird/SKILL.md. Every read session sets `MONEYBIRD_GUARD_READ_ONLY=1`.
5. Require the passed phase gate, Operator approval, current access window, stable local write key, a flushed `WRITE_INTENT` with a matching `--approval <ref>`, and read-back for every non-GET batch.
6. Use the documented auditfile export route. Never weaken the global read-only lock for an analysis session.
7. Keep migration records and evidence in migration-workspace/. Record exceptions rather than making unexplained balancing entries.
8. Keep exact phase owner tags and stop at a failed gate. Resume from the last verified run-journal state.
9. Refer legal, VAT, asset classification, private-use, and other judgement calls to the Operator or a bookkeeper.
10. Keep source documents and account records private.

### ❌ NEVER

1. Never file or submit an income-tax or VAT return. Filing is Operator-only.
2. Never present personal tax advice as final. Explain general information and flag judgement calls for the Operator or a bookkeeper.
3. Never read the private database unless the project privacy rule names a specific source file. Do not list, search, wildcard, or follow its symlink.
4. Never put migration data in skill references, chat summaries, or any folder outside migration-workspace/.
5. Never request Jortt write access or use a Jortt write operation.
6. Never write to Moneybird without the active migration gate, current access check, and required Operator approval.
7. Never cancel Jortt before Phase 22 passes. Never clear the read-only lock in a reader session. Use the guarded auditfile report-export route only in a separate approved writer session.
8. Never invent a passed gate, reconciled value, source record, or tax eligibility.
9. Never duplicate a Jortt category into Moneybird by label alone. Map by accounting purpose and tax treatment.
10. Never expose credentials, account identifiers, personal names, amounts, or private source records in documentation.

### ⚠️ ESCALATE IF

- The mode, migration phase, last passed gate, or owner is unclear.
- Required source evidence is missing or contradicts another source.
- A tax or VAT conclusion depends on personal facts or a legal classification.
- A requested return needs to be submitted.
- A write is requested without a passed gate or operator approval.
- The requested source file is not named precisely under the migration privacy rule.
- Product documentation and observed tool behavior differ.

---

## 5. REFERENCES

### Core references

- [Migration index](./references/migration/README.md) - execution-order phase map, old-to-new map, and routing.
- [Shared mechanisms](./references/migration/shared-mechanisms.md) - M1 to M12, including write keys, run journal, external agent route, expiry, and stop recovery.
- [Control framework](./references/migration/control-framework.md) - roles, risk, exception fields, dashboard, and completion.
- [Migration overview and setup](./references/migration/overview-and-setup.md) - workspace and approved `MIGRATION_CONFIG` fields.
- [Dutch tax rules](./references/dutch-tax-rules.md) - how each rule works across years, the year folder index, source conflicts, gaps and record and invoice duties.
- Tax year folders `references/2020/` to `references/2027/` - one sourced file per topic per year, BV and box 2 included, each opened through its `README.md`.
- [Moneybird bookkeeping](./references/moneybird-bookkeeping.md) - accounting treatment for common ZZP events.
- [Purchase invoices](./references/purchase-invoices.md) - booking a purchase invoice, receipt or order, with the VAT rate per case: Dutch VAT, reverse charge from the EU or outside it, foreign VAT, KOR.
- [Jortt to Moneybird mapping](./references/migration/jortt-to-moneybird-mapping.md) - concept matches and migration traps.

### Tool skills

- [cli-jortt](../cli-jortt/SKILL.md) - read-only Jortt CLI operations and extraction guidance.
- [cli-moneybird](../cli-moneybird/SKILL.md) - guarded Moneybird CLI reads and gated writes.
- The migration phase references link to these tool skills. Do not duplicate their CLI mechanics here.

### Loading notes

Load the migration index first for MIGRATION mode. Load one phase group at a time. In LIVE mode, load only the relevant bookkeeping or tax section. Load a sibling tool skill only when a CLI action is required.

---

## 6. SUCCESS CRITERIA

The task is complete when:

- The correct mode and, for migration work, the current phase are identified.
- The applicable reference and gate are loaded and passed before dependent work proceeds.
- All CLI operations use the correct sibling tool skill.
- Current-year figures are checked and sourced.
- No return is filed and no tax judgement is presented as final.
- Migration data stays in migration-workspace/.
- Remaining human decisions and exceptions are clearly stated.

---

## 7. INTEGRATION POINTS

### Inputs

- The project bootstrap at ../AGENTS.md.
- Read-only Jortt records through jortt-cli, following cli-jortt/SKILL.md.
- Moneybird records through moneybird-guard, following cli-moneybird/SKILL.md.
- General tax and bookkeeping references included in this skill.

### Outputs

- Period review notes and reconciliation work in migration-workspace/.
- Operator-ready exception lists and decision questions.
- No deliverables in export/.

### Related workflows

- MIGRATION mode owns historical movement from Jortt to Moneybird.
- LIVE mode owns ongoing bookkeeping and general ZZP questions.
- cli-jortt owns source-system CLI reads through jortt-cli.
- cli-moneybird owns target-system CLI reads and approved writes through moneybird-guard.

---

## 8. RELATED RESOURCES

- [Project bootstrap](../AGENTS.md) sets the entry route and privacy contract.
- [Migration index](./references/migration/README.md) maps phases to the plan and gates.
- [Dutch tax rules](./references/dutch-tax-rules.md) contains the general rules and routes to the topic files per tax year.
- [Moneybird bookkeeping](./references/moneybird-bookkeeping.md) covers common accounting events.
- [Purchase invoices](./references/purchase-invoices.md) covers booking purchase invoices and reverse-charged VAT.
- [Jortt to Moneybird mapping](./references/migration/jortt-to-moneybird-mapping.md) covers source concepts and migration traps.
