---
title: "MBD-012 -- Pilot write and undo rehearsal"
description: "This scenario validates Pilot write and undo rehearsal for `MBD-012`. It focuses on the need to rehearse one live create and its undo in the pilot administration through the guard."
version: 1.0.0.0
---

# MBD-012 -- Pilot write and undo rehearsal

This document captures the realistic user-testing contract, current behavior, execution flow, source anchors and metadata for `MBD-012`.

---

## 1. OVERVIEW

This scenario validates Pilot write and undo rehearsal for `MBD-012`. It focuses on the need to rehearse one live create and its undo in the pilot administration through the guard.

### Why This Matters

The migration plan requires a pilot write and an undo rehearsal before any production batch. This is the only scenario that writes to Moneybird. It writes only to the pilot administration.

### Destructive Scenario

This scenario writes to and deletes from the pilot administration. It never targets another administration. Recovery is the delete step and the later read. The correction recipe covers a record that remains.

---

## 2. SCENARIO CONTRACT

Operators run the exact prompt and command sequence for `MBD-012` and confirm the expected signals without contradictory evidence.

- Objective: Rehearse one live create and its undo in the pilot administration through the guard.
- Real user request: `Rehearse a pilot write and its undo before we touch production.`
- Prompt: `In the pilot administration only, create one throwaway test contact through the guard, delete it again and prove with a separate read that it is gone.`
- Expected execution process: The operator confirms the pilot target. The agent previews the create, writes it with `--confirm-write --approval "$APPROVAL_REF"`, deletes the record with the same flags, reads the last two log lines and runs a later read. Every guarded command names `MONEYBIRD_PILOT_ADMINISTRATION_ID`, and the guard checks it against the pilot ID in the root `.env` file.
- Expected signals: The preview path contains the pilot administration. The create succeeds. The delete prints the 204 caution. The log ends with a POST line and a DELETE line. The later read finds no record.
- Desired user-visible outcome: The operator has evidence that the pilot write path and its undo both work, with nothing left behind in the pilot administration.
- Pass/fail: PASS if the preview names the pilot administration, the create and delete both exit 0, the last two log lines show POST and DELETE with exit status 0 and the later read fails with a not found status. FAIL if any command targets a different administration, the record remains after the read or a write runs without the confirmation step.
- Feature catalog: [Pilot administration gate](../../feature-catalog/write-guard/pilot-administration-gate.md)

---

## 3. TEST EXECUTION

### Recommended Orchestration Process

1. Restate the user request in plain user language.
2. Decide whether the scenario stays local or needs the operator for a live step.
3. Execute the deterministic steps exactly as written.
4. Compare the observed output against the desired user-visible outcome.
5. Return a concise final answer that a real user would understand.

| Feature ID | Feature Name | Scenario Name / Objective | Exact Prompt | Exact Command Sequence | Expected Signals | Evidence | Pass/Fail Criteria | Failure Triage |
|---|---|---|---|---|---|---|---|---|
| MBD-012 | Pilot write and undo rehearsal | Rehearse one live create and its undo in the pilot administration through the guard | `In the pilot administration only, create one throwaway test contact through the guard, delete it again and prove with a separate read that it is gone.` | 1. `moneybird-cli contacts create --help` -> 2. `moneybird-guard --administration "$PILOT" contacts create` -> 3. `moneybird-guard --confirm-write --approval "$APPROVAL_REF" --out migration-workspace/mbd-012/create.json ...` -> 4. `moneybird-guard --confirm-write --approval "$APPROVAL_REF" ... contacts delete "$RECORD_ID"` -> 5. `bash: tail -n 2 moneybird-writes.jsonl` -> 6. `moneybird-guard ... contacts get "$RECORD_ID"` | Step 1: the name field is confirmed from help. Step 2: exit 3 with a `POST` preview for the pilot path. Step 3: exit 0 and a `response:` summary line. Step 4: exit 0 and the 204 caution. Step 5: a `POST` line then a `DELETE` line, both with exit status 0. Step 6: a nonzero not found status | Command output with the administration and record IDs replaced by placeholders and the log lines without IDs. No record content is copied out of `migration-workspace/` | PASS if the preview names the pilot administration, the create and delete both exit 0, the last two log lines show POST and DELETE with exit status 0 and the later read fails with a not found status. FAIL if any command targets a different administration, the record remains after the read or a write runs without the confirmation step. | 1. Stop and confirm the pilot ID with the operator before any retry. 2. Check the writer session with `moneybird-guard login-from-env --writer`. 3. If the read still finds the record, follow the correction recipe in `references/migration-recipes.md` |

### Command Block

This scenario writes to Moneybird. Run it from the `cli-moneybird/` package root only when the operator has approved it, only against the pilot administration and only after `moneybird-guard login-from-env --writer`. The operator sets `MONEYBIRD_PILOT_ADMINISTRATION_ID` and `APPROVAL_REF` in the shell. The guard itself checks the target against the pilot ID in the root `.env` file, never the shell value. Every write carries `--confirm-write --approval "$APPROVAL_REF"`. The reference comes from the `WRITE_INTENT` entry that the operator recorded in `migration-workspace/RunJournal/run-journal.jsonl`. Confirm `NAME_FIELD` from the help output in step 1 rather than guessing it. Mark the run SKIP with the credential blocker named when the operator has not approved it or no pilot session exists.

```bash
PILOT="$MONEYBIRD_PILOT_ADMINISTRATION_ID"
APPROVAL_REF="${APPROVAL_REF:?set the recorded approval reference}"
GUARD="cli/moneybird-cli/moneybird-guard"
moneybird-cli contacts create --help
NAME_FIELD="confirmed-name-field-from-help"
"$GUARD" --administration "$PILOT" contacts create --"$NAME_FIELD" "MBD-012 pilot rehearsal"
echo "preview exit=$?"
"$GUARD" --confirm-write --approval "$APPROVAL_REF" --out "migration-workspace/mbd-012/create.json" --administration "$PILOT" contacts create --"$NAME_FIELD" "MBD-012 pilot rehearsal"
echo "create exit=$?"
RECORD_ID="$(jq -r '.id' ../migration-workspace/mbd-012/create.json)"
"$GUARD" --confirm-write --approval "$APPROVAL_REF" --administration "$PILOT" contacts delete "$RECORD_ID"
echo "delete exit=$?"
tail -n 2 ../migration-workspace/logs/moneybird-writes.jsonl | jq -c '{method, exit_status}'
"$GUARD" --administration "$PILOT" contacts get "$RECORD_ID"
echo "read exit=$?"
```

### Optional Supplemental Checks

Run the final read again in a later pass, because an immediate GET can return cached data. A record that still appears in the later pass is a FAIL and needs the correction recipe.

---

## 4. SOURCE FILES

### Playbook Sources

| File | Role |
|---|---|
| [`manual-testing-playbook.md`](../manual-testing-playbook.md) | Root directory page and scenario summary |
| [`feature-catalog/write-guard/pilot-administration-gate.md`](../../feature-catalog/write-guard/pilot-administration-gate.md) | Feature-catalog entry for Pilot administration gate |
| [`feature-catalog/write-guard/write-log.md`](../../feature-catalog/write-guard/write-log.md) | Feature-catalog entry for Write log |
| [`feature-catalog/write-guard/delete-caution.md`](../../feature-catalog/write-guard/delete-caution.md) | Feature-catalog entry for Delete caution |

### Implementation And Test Anchors

| File | Role |
|---|---|
| [`cli/moneybird-cli/moneybird-guard`](../../cli/moneybird-cli/moneybird-guard) | Guarded write path |
| [`references/migration-recipes.md`](../../references/migration-recipes.md) | Pilot correction recipe |

---

## 5. SOURCE METADATA

- Group: Write safety
- Playbook ID: MBD-012
- Canonical root source: `manual-testing-playbook.md`
- Feature file path: `write-safety/pilot-write-and-undo-rehearsal.md`
