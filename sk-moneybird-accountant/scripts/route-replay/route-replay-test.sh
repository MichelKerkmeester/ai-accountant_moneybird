#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE REPLAY TEST
# ───────────────────────────────────────────────────────────────
# Tests route-replay.py in resolve and replay mode on a temp copy of the skill.
# Usage: route-replay-test.sh
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, missing skill files, a missing encoding cache or a
#       fixture that could not be set up
#
# WHY: the harness is only trustworthy when a clean corpus passes and each
# seeded defect turns the right row red. This suite seeds every defect in a
# temp copy of the skill and restores it, so the real skill tree stays
# untouched. It fails on a broken twin, an unmet file claim, a seeded filing
# claim, a pack row with a missing block and a correction row on the wrong side
# of the boundary. The hub rows score the packet chain, and a dropped hub
# signal or a missing hub file fails them. A fixture that cannot be applied
# stops the suite with exit 2, so a mutant never passes unseeded.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
SKILL_SRC=$(dirname "$(dirname "$SCRIPT_DIR")")
HUB_SRC=$(dirname "$SKILL_SRC")
HARNESS="$SCRIPT_DIR/route-replay.py"
CORPUS="$SCRIPT_DIR/routing-gold.json"

if [[ "$#" -gt 0 ]]; then
    printf 'error: usage: route-replay-test.sh\n' >&2
    exit 2
fi

if [[ ! -f "$HARNESS" ]]; then
    printf 'error: missing route-replay.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$CORPUS" ]]; then
    printf 'error: missing routing-gold.json next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_SRC/ROUTER.md" ]]; then
    printf 'error: missing ROUTER.md in the skill folder\n' >&2
    exit 2
fi
HUB_FILES=(hub-router.json mode-registry.json)
for hub_file in "${HUB_FILES[@]}"; do
    if [[ ! -f "$HUB_SRC/$hub_file" ]]; then
        printf 'error: missing %s above the skill folder\n' "$hub_file" >&2
        exit 2
    fi
done
if [[ ! -d "$HUB_SRC/cli-moneybird" ]]; then
    printf 'error: missing cli-moneybird above the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. ENCODING CACHE
# ───────────────────────────────────────────────────────────────

CACHE_DIR="${TIKTOKEN_CACHE_DIR:-}"
if [[ -z "$CACHE_DIR" || ! -d "$CACHE_DIR" ]]; then
    printf 'error: no encoding cache. Set TIKTOKEN_CACHE_DIR to the pinned cache folder.\n' >&2
    exit 2
fi
export TIKTOKEN_CACHE_DIR="$CACHE_DIR"

# ───────────────────────────────────────────────────────────────
# 3. TEMP COPY AND CLEANUP
# ───────────────────────────────────────────────────────────────

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/route-replay-test.XXXXXX") || exit 2
COPY="$TMP_ROOT/sk-moneybird-accountant"
cp -R "$SKILL_SRC" "$COPY" || exit 2
for hub_file in "${HUB_FILES[@]}"; do
    cp "$HUB_SRC/$hub_file" "$TMP_ROOT/$hub_file" || exit 2
done
# WHY: replay runs the guard and the stub that sit beside the skill folder.
cp -R "$HUB_SRC/cli-moneybird" "$TMP_ROOT/cli-moneybird" || exit 2
COPY_HARNESS="$COPY/scripts/route-replay/route-replay.py"
COPY_CORPUS="$COPY/scripts/route-replay/routing-gold.json"

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TMP_ROOT:-}" ]] && [[ -d "$TMP_ROOT" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}
trap cleanup EXIT

# ───────────────────────────────────────────────────────────────
# 4. TEST HELPERS
# ───────────────────────────────────────────────────────────────

passed=0
failed=0

# Record a passing check and print its report line
# Args:
#   $1 - Check description
pass() {
    passed=$((passed + 1))
    printf 'PASS %s\n' "$1"
}

# Record a failing check and print its report line
# Args:
#   $1 - Check description
fail() {
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
}

# Stop the suite when a fixture cannot be set up
# Args:
#   $1 - What could not be set up
setup_abort() {
    printf 'error: fixture setup failed: %s\n' "$1" >&2
    exit 2
}

# Run one command and compare its exit code with the expected one
# Args:
#   $1 - Check description
#   $2 - Expected exit code
#   $3... - Command and arguments to run
check_exit() {
    local description="$1"
    local expected="$2"
    shift 2
    "$@" >"$TMP_ROOT/last.log" 2>&1
    local status=$?
    if [[ "$status" -eq "$expected" ]]; then
        pass "$description"
    else
        fail "$description (exit $status, expected $expected)"
        sed -n '1,5p' "$TMP_ROOT/last.log"
    fi
}

# Run one command without a token cache and compare its exit code
# Args:
#   $1 - Check description
#   $2 - Expected exit code
#   $3... - Command and arguments to run
check_exit_no_cache() {
    local description="$1"
    local expected="$2"
    shift 2
    env TIKTOKEN_CACHE_DIR= "$@" >"$TMP_ROOT/last.log" 2>&1
    local status=$?
    if [[ "$status" -eq "$expected" ]]; then
        pass "$description"
    else
        fail "$description (exit $status, expected $expected)"
        sed -n '1,5p' "$TMP_ROOT/last.log"
    fi
}

# Prove one row is present and PASS in one results file
# Args:
#   $1 - Results CSV path
#   $2 - Row id
#   $3 - Check description
row_pass() {
    local results="$1"
    local row_id="$2"
    local description="$3"
    local report
    report=$(python3 -I - "$results" "$row_id" <<'PY'
import csv
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = {row["scenario_id"]: row for row in csv.DictReader(handle)}
row = rows.get(sys.argv[2])
if row is None:
    print("row absent")
elif row["verdict"] != "PASS":
    print("verdict %s: %s" % (row["verdict"], row["reason"]))
else:
    print("ok")
PY
    )
    if [[ "$report" == "ok" ]]; then
        pass "$description"
    else
        fail "$description ($report)"
    fi
}

# Prove one row is present and FAIL in one results file
# Args:
#   $1 - Results CSV path
#   $2 - Row id
#   $3 - Check description
row_fails() {
    local results="$1"
    local row_id="$2"
    local description="$3"
    local report
    report=$(python3 -I - "$results" "$row_id" <<'PY'
import csv
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = {row["scenario_id"]: row for row in csv.DictReader(handle)}
row = rows.get(sys.argv[2])
if row is None:
    print("row absent")
elif row["verdict"] != "FAIL":
    print("verdict %s" % row["verdict"])
else:
    print("ok")
PY
    )
    if [[ "$report" == "ok" ]]; then
        pass "$description"
    else
        fail "$description ($report)"
    fi
}

# Edit one row of the corpus copy in place, the way ROUTER.md is edited below
# Args:
#   $1 - Row id to mutate
#   $2 - Python statement that edits `row`
mutate_row() {
    local row_id="$1"
    local statement="$2"
    python3 -I - "$COPY_CORPUS" "$row_id" "$statement" <<'PY' || setup_abort "no corpus row $row_id to mutate"
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
hits = [row for row in data["rows"] if row.get("id") == sys.argv[2]]
if len(hits) != 1:
    raise SystemExit(1)
row = hits[0]
before = json.dumps(row, sort_keys=True)
exec(sys.argv[3])
if json.dumps(row, sort_keys=True) == before:
    raise SystemExit(1)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, ensure_ascii=False)
PY
}

# Put the pristine corpus back into the copy
restore_corpus() {
    cp "$CORPUS" "$COPY_CORPUS" || setup_abort "cannot restore the corpus copy"
}

# Seed one corpus defect in the copy, run one mode on it and restore the copy
# Args:
#   $1 - Mode, resolve or replay
#   $2 - Case tag, which names the output folder and the log
#   $3 - Row id to mutate
#   $4 - Python statement that edits `row`
run_corpus_mutant() {
    local mode="$1"
    local tag="$2"
    mutate_row "$3" "$4"
    python3 -I "$COPY_HARNESS" --mode "$mode" --out "$TMP_ROOT/out-$tag" >"$TMP_ROOT/$tag.log" 2>&1
    restore_corpus
}

# Print a checksum line for every file of the skill copy, bytecode caches aside
copy_state() {
    (cd "$COPY" && find . -name __pycache__ -prune -o -type f -exec cksum {} + | LC_ALL=C sort)
}

# Run one mode with no --out and prove the outputs land in a fresh temp folder
# that the last line names, while the skill copy stays as it was
# Args:
#   $1 - Mode, resolve or replay
check_default_out() {
    local mode="$1"
    local scratch="$TMP_ROOT/default-tmp-$mode"
    local log="$TMP_ROOT/default-$mode.log"
    local before
    local after
    local folder
    local status
    mkdir -p "$scratch" || setup_abort "cannot create $scratch"
    before=$(copy_state)
    TMPDIR="$scratch" python3 -I "$COPY_HARNESS" --mode "$mode" >"$log" 2>&1
    status=$?
    after=$(copy_state)
    folder=$(tail -n 1 "$log" | sed -n 's/^route-replay: output in //p')
    if [[ "$status" -eq 0 && "$before" == "$after" && -n "$folder" && "$folder" == "$scratch"/* \
        && -f "$folder/results.csv" && -f "$folder/report.md" ]]; then
        pass "a $mode run with no --out writes a fresh temp folder named on its last line and leaves the skill tree as it was"
    else
        fail "a $mode run with no --out writes a fresh temp folder named on its last line and leaves the skill tree as it was (exit $status, folder '$folder')"
        sed -n '1,5p' "$log"
    fi
}

# ───────────────────────────────────────────────────────────────
# 5. CLEAN RUN
# ───────────────────────────────────────────────────────────────

OUT_CLEAN="$TMP_ROOT/out-clean"
check_exit "the clean corpus resolves with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_CLEAN"

check_default_out resolve
check_default_out replay

# ───────────────────────────────────────────────────────────────
# 6. HUB PACKET CHAIN
# ───────────────────────────────────────────────────────────────

# WHY: stage one is scored only when a dropped hub signal or a missing hub file
# turns the hub rows red, so each mutant runs on the copy and is restored.
run_corpus_mutant resolve packet-twin HUB-003-nl \
    'row["prompt"] = "Wat is de kilometervergoeding voor 2026? Boek hem met moneybird-guard."'
if grep -qF 'parity mismatch HUB-003-nl against HUB-003' "$TMP_ROOT/packet-twin.log"; then
    pass "a twin pair that differs only in its packet chain is a parity mismatch"
else
    fail "a twin pair that differs only in its packet chain is a parity mismatch"
    sed -n '1,3p' "$TMP_ROOT/packet-twin.log"
fi

cp "$TMP_ROOT/hub-router.json" "$TMP_ROOT/hub-router.json.bak" || setup_abort "cannot back up hub-router.json"
python3 -I - "$TMP_ROOT/hub-router.json" <<'HUBPY' || setup_abort "hub-router.json holds no Jortt signal to drop"
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
if not data["signals"]["cli-jortt"]:
    raise SystemExit(1)
data["signals"]["cli-jortt"] = []
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
HUBPY
python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-hub-signal" >"$TMP_ROOT/last.log" 2>&1
row_fails "$TMP_ROOT/out-hub-signal/results.csv" "HUB-001" "a dropped Jortt hub signal fails HUB-001"
row_pass "$TMP_ROOT/out-hub-signal/results.csv" "HUB-002" "a dropped Jortt hub signal leaves HUB-002 passing"
mv "$TMP_ROOT/hub-router.json.bak" "$TMP_ROOT/hub-router.json" || setup_abort "cannot restore hub-router.json"

mv "$TMP_ROOT/mode-registry.json" "$TMP_ROOT/mode-registry.json.bak" || setup_abort "cannot move mode-registry.json"
python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-hub-missing" >"$TMP_ROOT/last.log" 2>&1
if grep -qF 'hub files missing or malformed for the packet chain' "$TMP_ROOT/out-hub-missing/results.csv" 2>/dev/null; then
    pass "a missing mode registry names the hub files"
else
    fail "a missing mode registry names the hub files"
fi
mv "$TMP_ROOT/mode-registry.json.bak" "$TMP_ROOT/mode-registry.json" || setup_abort "cannot restore mode-registry.json"

# ───────────────────────────────────────────────────────────────
# 7. ENCODING CACHE REFUSAL
# ───────────────────────────────────────────────────────────────

check_exit_no_cache "a missing encoding cache exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-nocache"

# ───────────────────────────────────────────────────────────────
# 8. TWIN MISMATCH
# ───────────────────────────────────────────────────────────────

run_corpus_mutant resolve twin GR-YEARLY-01-nl 'row["gold_task_type"] = "T6"'
if grep -qF 'parity mismatch GR-YEARLY-01-nl against GR-YEARLY-01' "$TMP_ROOT/twin.log"; then
    pass "the twin mismatch names the pair"
else
    fail "the twin mismatch names the pair"
    sed -n '1,3p' "$TMP_ROOT/twin.log"
fi

# ───────────────────────────────────────────────────────────────
# 9. FILE CLAIMS
# ───────────────────────────────────────────────────────────────

# A claim the skill tree cannot meet fails the row, never the whole run
run_corpus_mutant resolve claims API-001 'row["expected_claims"][0]["text"] = "claim that no scored file holds"'
if grep -qF 'claims not met ROUTER.md: claim that no scored file holds' "$TMP_ROOT/out-claims/results.csv" 2>/dev/null; then
    pass "the unmet claim names the claim"
else
    fail "the unmet claim names the claim"
fi

# ───────────────────────────────────────────────────────────────
# 10. REPLAY MODE
# ───────────────────────────────────────────────────────────────

OUT_REPLAY="$TMP_ROOT/out-replay"
check_exit "the refusal and hostile rows replay with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode replay --out "$OUT_REPLAY"

if grep -q '^HOSTILE-H1,' "$OUT_REPLAY/results.csv" 2>/dev/null && [[ "$(grep -c '^HOSTILE-' "$OUT_REPLAY/results.csv" || true)" -eq 22 ]]; then
    pass "all 22 hostile invoice cases replay"
else
    fail "all 22 hostile invoice cases replay"
fi

# Replay needs no ambient credential, proxy or cache variable
env -i PATH="$PATH" HOME="$TMP_ROOT/home" python3 -I "$COPY_HARNESS" --mode replay \
    --out "$TMP_ROOT/out-cleared" >"$TMP_ROOT/last.log" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "replay passes in a cleared environment with no network variables"
else
    fail "replay passes in a cleared environment with no network variables (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/last.log"
fi

# A row whose recorded exit no longer matches fails the run
run_corpus_mutant replay replay-mutant REFUSE-3-01 'row["expected_exit"] = 8'
if grep -qF 'REFUSE-3-01: exit 3, expected 8' "$TMP_ROOT/replay-mutant.log"; then
    pass "the wrong expected exit names the row"
else
    fail "the wrong expected exit names the row"
    sed -n '1,3p' "$TMP_ROOT/replay-mutant.log"
fi

# ───────────────────────────────────────────────────────────────
# 11. RESOLVER CONSTANTS AGAINST THE TABLE AND THE PROSE
# ───────────────────────────────────────────────────────────────

# WHY: the resolver keeps its own copy of the T4 conditional signal families,
# so a term the table drops would still load a reference the table no longer
# routes to. Every term must sit in a T4 signal cell.
DRIFT=$(python3 -I - "$HARNESS" "$SKILL_SRC/ROUTER.md" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("route_replay", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    rows = module.parse_route_table(handle.read())
row = next(item for item in rows if item["type"] == "T4")
signals = {phrase.lower() for phrase in module.signal_phrases(row["dutch"]) + module.signal_phrases(row["english"])}
missing = [term for term in module.MIXED_USE_TERMS + module.FIXED_ASSET_TERMS if term not in signals]
purchase = {"inkoopfactuur", "bonnetje", "factuur van een leverancier", "invoice", "receipt", "order", "supplier", "reverse charge", "kor"}
unlisted = sorted(signals - purchase - set(module.T4_TOPIC_TERMS))
problems = (["missing: " + ", ".join(missing)] if missing else []) + (["unlisted: " + ", ".join(unlisted)] if unlisted else [])
print("ok" if not problems else " and ".join(problems))
PY
)
if [[ "$DRIFT" == "ok" ]]; then
    pass "the T4 conditional read terms equal the T4 topic signals in the table"
else
    fail "the T4 conditional read terms equal the T4 topic signals in the table ($DRIFT)"
fi

# WHY: the table is the single source of the T5 source terms, so a resolver
# constant the table drops would route a read the authored table no longer
# names.
SIGNAL_DRIFT=$(python3 -I - "$HARNESS" "$SKILL_SRC/ROUTER.md" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("route_replay", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    rows = module.parse_route_table(handle.read())
row = next(item for item in rows if item["type"] == "T5")
t5 = {module.fold_text(phrase) for phrase in module.signal_phrases(row["dutch"]) + module.signal_phrases(row["english"])}
problems = ["T5 signal missing from the table: %s" % term for term in module.SOURCE_TERMS if module.fold_text(term) not in t5]
print("ok" if not problems else " and ".join(problems))
PY
)
if [[ "$SIGNAL_DRIFT" == "ok" ]]; then
    pass "the resolver source terms equal the T5 table signals"
else
    fail "the resolver source terms equal the T5 table signals ($SIGNAL_DRIFT)"
fi

# WHY: a documented specificity clause without a gold tie row would fall
# through to abstain unnoticed, so every clause pair the prose names needs a
# corpus row that labels it, and a label must name the route its row expects.
CLAUSE_DRIFT=$(python3 -I - "$CORPUS" "$SKILL_SRC/references/routing-signals.md" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = json.load(handle)["rows"]
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    signals_text = handle.read()
section = signals_text.split("## 4. THE SPECIFICITY CLAUSES", 1)[-1].split("\n## ", 1)[0]
clauses = re.findall(r"^\d+\.\s+(.*)$", section, re.MULTILINE)

def normalize(pair):
    return tuple(sorted(pair, key=lambda value: int(value[1:])))

documented = set()
for clause in clauses:
    for match in re.finditer(r"(T\d+)\s+beats?\s+((?:T\d+(?:\s*(?:,|and)\s*)?)+)", clause):
        for second in re.findall(r"T\d+", match.group(2)):
            documented.add(normalize((match.group(1), second)))
problems = []
labelled = set()
for row in rows:
    tie = row.get("tie")
    if not tie:
        continue
    parts = re.fullmatch(r"(T\d+)-over-(T\d+)", tie)
    if parts is None:
        problems.append("%s carries the malformed tie label %s" % (row["id"], tie))
        continue
    labelled.add(normalize(parts.groups()))
    if row.get("gold_task_type") != parts.group(1):
        problems.append("%s labels %s as the winner but expects %s" % (row["id"], parts.group(1), row.get("gold_task_type")))
for pair in sorted(documented):
    if "T8" not in pair and pair not in labelled:
        problems.append("no gold tie row for %s" % (pair,))
print("ok" if not problems else " and ".join(problems))
PY
)
if [[ "$CLAUSE_DRIFT" == "ok" ]]; then
    pass "every documented specificity clause has a gold tie row"
else
    fail "every documented specificity clause has a gold tie row ($CLAUSE_DRIFT)"
fi

# ───────────────────────────────────────────────────────────────
# 12. TAX DELIVERABLE BRANCH, PACK AND REFUSAL ROWS
# ───────────────────────────────────────────────────────────────

# A filing claim inside a prepare row must fail the run and name the row
run_corpus_mutant resolve filing-claim VAT-BRANCH-Q1-01 \
    'row["prompt"] = "File my VAT return for the first quarter of 2026."'
row_fails "$TMP_ROOT/out-filing-claim/results.csv" "VAT-BRANCH-Q1-01" "the filing claim names VAT-BRANCH-Q1-01"

# A pack row that expects a block the procedure does not ship must fail
run_corpus_mutant resolve missing-block PACK-YEARLY-01 \
    'row["expected_facts"] = list(row["expected_facts"]) + ["no such pack block"]'
row_fails "$TMP_ROOT/out-missing-block/results.csv" "PACK-YEARLY-01" "the missing pack block names PACK-YEARLY-01"

# A correction row that expects the read of the other side of the boundary
# must fail, because the below-boundary request loads no procedure figures.
run_corpus_mutant resolve wrong-boundary VAT-BRANCH-COR-01 \
    'row["expected_paths"] = list(row["expected_paths"]) + ["references/tax-rules/2026/procedure/figures.md"]'
row_fails "$TMP_ROOT/out-wrong-boundary/results.csv" "VAT-BRANCH-COR-01" "the wrong boundary side names VAT-BRANCH-COR-01"

# ───────────────────────────────────────────────────────────────
# 13. ROUTER BLOCK MARKERS
# ───────────────────────────────────────────────────────────────

cp "$COPY/ROUTER.md" "$TMP_ROOT/ROUTER.md.bak" || setup_abort "cannot back up ROUTER.md"
grep -v -F '<!-- router-block:start -->' "$TMP_ROOT/ROUTER.md.bak" >"$COPY/ROUTER.md"
if cmp -s "$TMP_ROOT/ROUTER.md.bak" "$COPY/ROUTER.md"; then
    setup_abort "ROUTER.md holds no router block start marker to drop"
fi
python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-no-block" >"$TMP_ROOT/no-block.log" 2>&1
status=$?
if [[ "$status" -ne 0 ]] && grep -qF 'router block markers missing in sk-moneybird-accountant/ROUTER.md' "$TMP_ROOT/no-block.log"; then
    pass "a missing router block names the routing file"
else
    fail "a missing router block names the routing file (exit $status)"
    sed -n '1,3p' "$TMP_ROOT/no-block.log"
fi
cp "$TMP_ROOT/ROUTER.md.bak" "$COPY/ROUTER.md" || setup_abort "cannot restore ROUTER.md"

# ───────────────────────────────────────────────────────────────
# 14. SCORING HOLES
# ───────────────────────────────────────────────────────────────

# WHY: each case breaks one scored field in the corpus copy, so a scorer that
# stops reading that field passes the row and fails the case.
run_corpus_mutant resolve hole-tier TIER-C-01 'row["tier"] = ""'
row_fails "$TMP_ROOT/out-hole-tier/results.csv" "TIER-C-01" "a gold tier that differs from the route tier fails the row"

run_corpus_mutant resolve hole-ceiling HUB-004 'row["token_ceiling"] = 1'
row_fails "$TMP_ROOT/out-hole-ceiling/results.csv" "HUB-004" "a read set above the token ceiling fails the row"

run_corpus_mutant resolve hole-forbidden HUB-004 'row["forbidden_paths"] = row["forbidden_paths"] + ["references/purchase-invoices.md"]'
row_fails "$TMP_ROOT/out-hole-forbidden/results.csv" "HUB-004" "a loaded forbidden path fails the row"

run_corpus_mutant resolve hole-turn TWO-TURN-01 'row["previous_gold_task_type"] = "T3"'
row_fails "$TMP_ROOT/out-hole-turn/results.csv" "TWO-TURN-01" "a first turn that differs from its gold fails the follow-up row"

run_corpus_mutant resolve hole-readset HUB-004-nl 'row["prompt"] = row["prompt"] + " Ik gebruik de laptop deels privé."'
if grep -qF 'parity mismatch HUB-004-nl against HUB-004' "$TMP_ROOT/hole-readset.log"; then
    pass "a twin that reads a different set fails parity"
else
    fail "a twin that reads a different set fails parity"
    sed -n '1,3p' "$TMP_ROOT/hole-readset.log"
fi

# ───────────────────────────────────────────────────────────────
# 15. FIXTURE RESTORE
# ───────────────────────────────────────────────────────────────

# WHY: every mutant above edits the copy in place, so a copy that differs from
# the skill folder means a later check ran on a defect it did not seed.
RESTORE_DIFF=$(
    diff -rq -x __pycache__ "$SKILL_SRC" "$COPY" 2>&1
    for hub_file in "${HUB_FILES[@]}"; do
        cmp "$HUB_SRC/$hub_file" "$TMP_ROOT/$hub_file" 2>&1
    done
)
if [[ -z "$RESTORE_DIFF" ]]; then
    pass "every mutant restored the skill copy and the hub files"
else
    fail "every mutant restored the skill copy and the hub files ($RESTORE_DIFF)"
fi

# ───────────────────────────────────────────────────────────────
# 16. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
