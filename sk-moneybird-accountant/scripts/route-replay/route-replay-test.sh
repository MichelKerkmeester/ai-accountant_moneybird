#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE REPLAY TEST
# ───────────────────────────────────────────────────────────────
# Tests route-replay.py resolve mode on a temp copy of the skill.
# Usage: route-replay-test.sh [skill folder]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments, missing skill files or a missing encoding cache
#
# WHY: the harness is only trustworthy when a clean corpus passes, a deleted
# routed path stops the run and a broken twin or an injected date changes
# nothing about the numbers. This suite proves each of those on a copy, so the
# real skill tree stays untouched. It also scores the tax deliverable branch,
# pack and refusal rows and fails on a seeded filing claim, a pack row with a
# missing block and a correction row on the wrong side of the boundary.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_SKILL=$(dirname "$(dirname "$SCRIPT_DIR")")
HARNESS="$SCRIPT_DIR/route-replay.py"
CORPUS="$SCRIPT_DIR/routing-gold.json"

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: route-replay-test.sh [skill folder]\n' >&2
    exit 2
fi

SKILL_SRC="${1:-$DEFAULT_SKILL}"
if ! SKILL_SRC=$(cd "$SKILL_SRC" 2>/dev/null && pwd -P); then
    printf 'error: skill folder not found\n' >&2
    exit 2
fi
REPO_SRC=$(dirname "$(dirname "$SKILL_SRC")")
if [[ ! -f "$HARNESS" ]]; then
    printf 'error: missing route-replay.py next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$CORPUS" ]]; then
    printf 'error: missing routing-gold.json next to this test\n' >&2
    exit 2
fi
if [[ ! -f "$SKILL_SRC/SKILL.md" ]]; then
    printf 'error: missing SKILL.md in the skill folder\n' >&2
    exit 2
fi

# ───────────────────────────────────────────────────────────────
# 2. ENCODING CACHE
# ───────────────────────────────────────────────────────────────

CACHE_DIR="${TIKTOKEN_CACHE_DIR:-}"
if [[ -z "$CACHE_DIR" ]]; then
    for candidate in "$REPO_SRC/../tiktoken-cache" "$REPO_SRC/tiktoken-cache" "$HOME/.cache/tiktoken"; do
        if [[ -d "$candidate" ]]; then
            CACHE_DIR=$(cd "$candidate" && pwd -P)
            break
        fi
    done
fi
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

# Prove one results file holds exactly N rows with the wanted verdict
# Args:
#   $1 - Wanted verdict
#   $2 - Results CSV path
#   $3 - Expected row count
#   $4 - Check description
count_rows() {
    local wanted="$1"
    local results="$2"
    local expected="$3"
    local description="$4"
    local actual
    actual=$(python3 -I - "$results" "$wanted" <<'PY'
import csv
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
print(sum(1 for row in rows if row["verdict"] == sys.argv[2]))
PY
    )
    if [[ "$actual" == "$expected" ]]; then
        pass "$description"
    else
        fail "$description ($actual of $expected rows)"
    fi
}

# ───────────────────────────────────────────────────────────────
# 5. CLEAN RUN
# ───────────────────────────────────────────────────────────────

OUT_CLEAN="$TMP_ROOT/out-clean"
check_exit "the clean corpus resolves with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_CLEAN"

if [[ -f "$OUT_CLEAN/results.csv" ]]; then
    pass "the clean run writes results.csv"
else
    fail "the clean run writes results.csv"
fi
if [[ -f "$OUT_CLEAN/report.md" ]]; then
    pass "the clean run writes report.md"
else
    fail "the clean run writes report.md"
fi

if grep -q '^scenario_id,lang,split,gold_mode,gold_task_type,score,verdict,reason,tokens_loaded,t7,destination,reads$' "$OUT_CLEAN/results.csv" 2>/dev/null; then
    pass "results.csv carries the fixed column order"
else
    fail "results.csv carries the fixed column order"
fi
if python3 -I - "$OUT_CLEAN/results.csv" <<'PY' >"$TMP_ROOT/last.log" 2>&1
import csv
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = {row["scenario_id"]: row for row in csv.DictReader(handle)}
problems = []
if rows.get("API-001", {}).get("t7") != "1":
    problems.append("API-001 carries no T7 additive hit")
if rows.get("LIVE-001", {}).get("t7") != "0":
    problems.append("LIVE-001 carries a T7 additive hit")
for row in rows.values():
    if row.get("t7") == "1" and not row.get("reads"):
        problems.append("%s matched T7 without a matched row" % row["scenario_id"])
    if row.get("t7") == "1" and not row.get("destination"):
        problems.append("%s matched T7 without a destination" % row["scenario_id"])
    if row.get("t7") == "0" and row.get("destination"):
        problems.append("%s carries a destination without a T7 hit" % row["scenario_id"])
destinations = {
    "T7-DEST-JORTT-01": "cli-jortt",
    "T7-DEST-MONEYBIRD-01": "cli-moneybird",
    "T7-DEST-BLOCKED-01": "blocked",
}
for row_id, wanted in destinations.items():
    actual = rows.get(row_id, {}).get("destination")
    if actual != wanted:
        problems.append("%s destination %s expected %s" % (row_id, actual, wanted))
print("ok" if not problems else " and ".join(problems))
PY
then
    T7_OK=$(cat "$TMP_ROOT/last.log")
    if [[ "$T7_OK" == "ok" ]]; then
        pass "the t7 column asserts the additive row"
    else
        fail "the t7 column asserts the additive row ($T7_OK)"
    fi
else
    fail "the t7 column asserts the additive row"
fi
if python3 -I - "$OUT_CLEAN/report.md" <<'PY' >"$TMP_ROOT/last.log" 2>&1
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    text = handle.read()
found = {}
for number in range(1, 13):
    match = re.search(r"^- T%d precision (.+?), recall (.+)$" % number, text, re.MULTILINE)
    if match:
        found[number] = match.group(1)
problems = []
if len(found) != 12:
    problems.append("missing: %s" % ", ".join("T%d" % number for number in range(1, 13) if number not in found))
if "- additive row wins alone: 0" not in text:
    problems.append("the additive row alone count is not zero")
print("ok" if not problems else " and ".join(problems))
PY
then
    if [[ "$(cat "$TMP_ROOT/last.log")" == "ok" ]]; then
        pass "the report carries per-type precision and recall rows for T1 to T12"
    else
        fail "the report carries per-type precision and recall rows for T1 to T12 ($(cat "$TMP_ROOT/last.log"))"
    fi
else
    fail "the report carries per-type precision and recall rows for T1 to T12"
fi
if python3 -I - "$OUT_CLEAN/results.csv" "$OUT_CLEAN/report.md" <<'PY' >"$TMP_ROOT/last.log" 2>&1
import csv
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    reads = {row["scenario_id"]: row["reads"] for row in csv.DictReader(handle)}
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    text = handle.read()
section = text.split("## Read counts", 1)[-1].split("\n## ", 1)[0]
table = dict(re.findall(r"^\| (\S+) \| \S+ \| (\d+) \|$", section, re.MULTILINE))
problems = []
if not table or table != reads:
    problems.append("the read counts table differs from the reads column")
if reads.get("MIG-005") != "3" or reads.get("MIG-002") != "3":
    problems.append("a named phase skips the index and an unnamed one reads it: MIG-005 %s, MIG-002 %s" % (reads.get("MIG-005"), reads.get("MIG-002")))
print("ok" if not problems else " and ".join(problems))
PY
then
    if [[ "$(cat "$TMP_ROOT/last.log")" == "ok" ]]; then
        pass "the read counts section matches the reads column"
    else
        fail "the read counts section matches the reads column ($(cat "$TMP_ROOT/last.log"))"
    fi
else
    fail "the read counts section matches the reads column"
fi

# Widen the warning band on a second copy so rows land in the sink, and
# prove the sink is telemetry only: every route stays the clean run's route.
BAND_COPY="$TMP_ROOT/band/sk-moneybird-accountant"
mkdir -p "$TMP_ROOT/band"
cp -R "$COPY" "$BAND_COPY" || exit 2
sed 's/^- The 0\.08 warning band\./- The 100 warning band./' \
    "$COPY/references/routing-signals.md" >"$BAND_COPY/references/routing-signals.md"
OUT_BAND="$TMP_ROOT/out-band"
check_exit "a widened warning band still resolves with exit 0" 0 \
    python3 -I "$BAND_COPY/scripts/route-replay/route-replay.py" --mode resolve --out "$OUT_BAND"
if python3 -I - "$OUT_CLEAN/results.csv" "$OUT_BAND/results.csv" "$OUT_BAND/report.md" <<'PY' >"$TMP_ROOT/last.log" 2>&1
import csv
import sys

def routes(path):
    with open(path, "r", encoding="utf-8") as handle:
        return {row["scenario_id"]: (row["verdict"], row["reason"], row["reads"]) for row in csv.DictReader(handle)}

with open(sys.argv[3], "r", encoding="utf-8") as handle:
    text = handle.read()
sink = text.split("## Warning band sink", 1)[-1].split("\n## ", 1)[0]
problems = []
if "above the margin" not in sink:
    problems.append("the widened band put no row in the sink")
if routes(sys.argv[1]) != routes(sys.argv[2]):
    problems.append("a row changed its verdict when the band widened")
print("ok" if not problems else " and ".join(problems))
PY
then
    if [[ "$(cat "$TMP_ROOT/last.log")" == "ok" ]]; then
        pass "the warning band sink lists rows and never changes a route"
    else
        fail "the warning band sink lists rows and never changes a route ($(cat "$TMP_ROOT/last.log"))"
    fi
else
    fail "the warning band sink lists rows and never changes a route"
fi
if grep -q '^- held-out route accuracy:' "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "report.md carries a held-out accuracy line"
else
    fail "report.md carries a held-out accuracy line"
fi
if grep -q '^\- Dutch parity:' "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "report.md carries the Dutch parity result"
else
    fail "report.md carries the Dutch parity result"
fi
if grep -q 'Answer quality: unscored' "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "report.md marks answer quality as unscored"
else
    fail "report.md marks answer quality as unscored"
fi

FROZEN_FLOOR="$(sed -n 's/^- `FALLBACK_FLOOR = \([0-9.]*\)`, frozen on the calibration split\.$/\1/p' "$COPY/SKILL.md")"
if [[ -n "$FROZEN_FLOOR" ]] && grep -q "Fallback floor: $FROZEN_FLOOR\." "$OUT_CLEAN/report.md" 2>/dev/null; then
    pass "the report states the frozen fallback floor"
else
    fail "the report states the frozen fallback floor"
fi
if grep -q 'Fallback floor: calibration: pending' "$OUT_CLEAN/report.md" 2>/dev/null; then
    fail "the report leaves the fallback floor pending"
else
    pass "the report leaves the fallback floor pending"
fi

# ───────────────────────────────────────────────────────────────
# 6. DATED RUNS
# ───────────────────────────────────────────────────────────────

OUT_DATED_A="$TMP_ROOT/out-dated-a"
OUT_DATED_B="$TMP_ROOT/out-dated-b"
SOURCE_DATE_EPOCH=111 python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_DATED_A" >"$TMP_ROOT/last.log" 2>&1
status_a=$?
SOURCE_DATE_EPOCH=222 python3 -I "$COPY_HARNESS" --mode resolve --out "$OUT_DATED_B" >"$TMP_ROOT/last.log" 2>&1
status_b=$?
if [[ "$status_a" -eq 0 && "$status_b" -eq 0 ]]; then
    pass "two dated runs both exit 0"
else
    fail "two dated runs both exit 0 (exit $status_a and $status_b)"
fi
if cmp -s "$OUT_DATED_A/results.csv" "$OUT_DATED_B/results.csv"; then
    pass "two dated runs give byte-identical results.csv"
else
    fail "two dated runs give byte-identical results.csv"
fi
if cmp -s "$OUT_DATED_A/report.md" "$OUT_DATED_B/report.md"; then
    pass "two dated runs give byte-identical report.md"
else
    fail "two dated runs give byte-identical report.md"
fi

# ───────────────────────────────────────────────────────────────
# 7. CORPUS AND CACHE REFUSALS
# ───────────────────────────────────────────────────────────────

printf '{"rows": []}' >"$TMP_ROOT/empty.json"
check_exit "an empty corpus exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$TMP_ROOT/empty.json" --out "$TMP_ROOT/out-empty"

check_exit_no_cache "a missing encoding cache exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-nocache"

# ───────────────────────────────────────────────────────────────
# 8. DELETED ROUTED PATH
# ───────────────────────────────────────────────────────────────

DELETED="$COPY/references/purchase-invoices.md"
mv "$DELETED" "$TMP_ROOT/purchase-invoices.bak"
check_exit "a deleted routed path exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-deleted"
if grep -q 'missing routed path: references/purchase-invoices.md' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the connectivity gate names the missing path"
else
    fail "the connectivity gate names the missing path"
fi
mv "$TMP_ROOT/purchase-invoices.bak" "$DELETED"

# ───────────────────────────────────────────────────────────────
# 8B. DELETED YEAR README
# ───────────────────────────────────────────────────────────────

# The year token expands over the year folders under references/tax-rules, so
# a missing year README stops the connectivity gate. A root-only listing
# would expand to nothing and pass.
YEAR_DELETED="$COPY/references/tax-rules/2020/README.md"
mv "$YEAR_DELETED" "$TMP_ROOT/year-readme.bak"
check_exit "a missing year README under tax-rules exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-year-deleted"
if grep -q 'missing routed path: references/tax-rules/2020/README.md' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the connectivity gate names the missing year README"
else
    fail "the connectivity gate names the missing year README"
fi
mv "$TMP_ROOT/year-readme.bak" "$YEAR_DELETED"

# ───────────────────────────────────────────────────────────────
# 8C. CONDITIONAL PATH ABSENT
# ───────────────────────────────────────────────────────────────

# A ? read that does not exist is recorded by the table check and never
# stops the connectivity gate. Only the ! reads are gate inputs.
cp "$COPY/SKILL.md" "$TMP_ROOT/SKILL.md.bak"
python3 - "$COPY/SKILL.md" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()
old = "`!references/migration/overview-and-setup.md`"
new = old + ", `?references/route-replay-probe-missing.md`"
if old not in text:
    raise SystemExit("T9 read set anchor not found")
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text.replace(old, new, 1))
PY
check_exit "a missing conditional routed path still resolves with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-conditional"
if ! grep -q 'route-replay-probe-missing' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the missing conditional path is not a connectivity failure"
else
    fail "the missing conditional path is not a connectivity failure"
fi
cp "$TMP_ROOT/SKILL.md.bak" "$COPY/SKILL.md"

# ───────────────────────────────────────────────────────────────
# 8D. PHASE MAP DISAGREEMENT
# ───────────────────────────────────────────────────────────────

# A hand edit inside PHASE_FILES that the migration index does not carry
# must stop the run before any row is scored.
cp "$COPY/SKILL.md" "$TMP_ROOT/SKILL.md.bak"
python3 - "$COPY/SKILL.md" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()
old = '"19": "references/migration/phases-19-to-21.md",'
new = '"19": "references/migration/phases-17-to-18.md",'
if old not in text:
    raise SystemExit("PHASE_FILES anchor not found")
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text.replace(old, new, 1))
PY
check_exit "a phase map that disagrees with the migration index exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-disagree"
if grep -q 'constants disagree' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the phase map disagreement is named constants disagree"
else
    fail "the phase map disagreement is named constants disagree"
fi
cp "$TMP_ROOT/SKILL.md.bak" "$COPY/SKILL.md"

# ───────────────────────────────────────────────────────────────
# 9. TWIN MISMATCH
# ───────────────────────────────────────────────────────────────

python3 - "$COPY_CORPUS" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("parityOf"):
        row["gold_task_type"] = "T6"
        break
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a twin mismatch exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --out "$TMP_ROOT/out-twin"
if grep -q 'parity mismatch' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the twin mismatch names the pair"
else
    fail "the twin mismatch names the pair"
fi

# ───────────────────────────────────────────────────────────────
# 9B. FILE CLAIMS
# ───────────────────────────────────────────────────────────────

# A claim the revision cannot meet fails the row, never the whole run
CLAIMS_CORPUS="$TMP_ROOT/claims-gold.json"
cp "$CORPUS" "$CLAIMS_CORPUS" || exit 2
python3 - "$CLAIMS_CORPUS" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("expected_claims"):
        row["expected_claims"][0]["text"] = "claim that no scored file holds"
        break
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a claim the revision does not meet exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$CLAIMS_CORPUS" --out "$TMP_ROOT/out-claims"
if grep -q 'claims not met' "$TMP_ROOT/out-claims/results.csv" 2>/dev/null; then
    pass "the unmet claim names the claim"
else
    fail "the unmet claim names the claim"
fi

# ───────────────────────────────────────────────────────────────
# 10. REPLAY MODE
# ───────────────────────────────────────────────────────────────

# A run-owned copy keeps the source corpus untouched
REPLAY_CORPUS="$TMP_ROOT/replay-gold.json"
cp "$CORPUS" "$REPLAY_CORPUS" || exit 2
REPO_ROOT="$(dirname "$SKILL_SRC")"
GUARD="$REPO_ROOT/cli-moneybird/cli/moneybird-cli/moneybird-guard"
STUB="$REPO_ROOT/cli-moneybird/cli/moneybird-cli/tests/stub-moneybird-cli"
OUT_REPLAY="$TMP_ROOT/out-replay"

check_exit "the refusal and hostile rows replay with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$STUB" --out "$OUT_REPLAY"

if grep -q '^scenario_id,lang,split,gold_mode,gold_task_type,score,verdict,reason,tokens_loaded,t7,destination,reads,command,expected_exit,actual_exit$' "$OUT_REPLAY/results.csv" 2>/dev/null; then
    pass "the replay results.csv carries the command and exit columns"
else
    fail "the replay results.csv carries the command and exit columns"
fi

# Every refusal row must return the exit code the corpus records
if python3 - "$OUT_REPLAY/results.csv" <<'PY' >"$TMP_ROOT/last.log" 2>&1
import csv
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
bad = [row["scenario_id"] for row in rows if row["expected_exit"] != row["actual_exit"]]
if bad:
    print("exit mismatch: %s" % ", ".join(bad))
    raise SystemExit(1)
if len(rows) < 31:
    print("only %d replay rows" % len(rows))
    raise SystemExit(1)
print("%d replay rows return their recorded exit code" % len(rows))
PY
then
    pass "every refusal row returns its recorded exit code"
else
    fail "every refusal row returns its recorded exit code"
    sed -n '1,5p' "$TMP_ROOT/last.log"
fi

if grep -q '^HOSTILE-H1,' "$OUT_REPLAY/results.csv" 2>/dev/null && [[ "$(grep -c '^HOSTILE-' "$OUT_REPLAY/results.csv" || true)" -eq 22 ]]; then
    pass "all 22 hostile invoice cases replay"
else
    fail "all 22 hostile invoice cases replay"
fi

# A stub path that does not exist is a usage error, never a pass
check_exit "a broken stub path exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$TMP_ROOT/no-such-stub" --out "$TMP_ROOT/out-broken"
if grep -q 'stub not found' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the broken stub path is named"
else
    fail "the broken stub path is named"
fi

# Replay needs no ambient credential, proxy or cache variable
env -i PATH="$PATH" HOME="$TMP_ROOT/home" python3 -I "$COPY_HARNESS" --mode replay \
    --corpus "$REPLAY_CORPUS" --guard "$GUARD" --stub "$STUB" --out "$TMP_ROOT/out-cleared" \
    >"$TMP_ROOT/last.log" 2>&1
status=$?
if [[ "$status" -eq 0 ]]; then
    pass "replay passes in a cleared environment with no network variables"
else
    fail "replay passes in a cleared environment with no network variables (exit $status)"
    sed -n '1,5p' "$TMP_ROOT/last.log"
fi

# A covers filter keeps only the tagged rows
OUT_COVERS="$TMP_ROOT/out-covers"
check_exit "a covers filter scores the tagged replay rows" 0 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$STUB" --covers 006/REQ-002 --out "$OUT_COVERS"
if [[ "$(grep -c '^REFUSE-9-' "$OUT_COVERS/results.csv" 2>/dev/null || true)" -eq 2 ]] && \
   [[ "$(grep -vc '^scenario_id' "$OUT_COVERS/results.csv" 2>/dev/null || true)" -eq 2 ]]; then
    pass "the covers filter keeps exactly the tagged rows"
else
    fail "the covers filter keeps exactly the tagged rows"
fi
check_exit "an unknown covers value exits 2" 2 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$REPLAY_CORPUS" \
    --guard "$GUARD" --stub "$STUB" --covers 999/REQ-999 --out "$TMP_ROOT/out-unknown"

# A row whose recorded exit no longer matches fails the run
python3 - "$REPLAY_CORPUS" "$TMP_ROOT/replay-mutant.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("id") == "REFUSE-3-01":
        row["expected_exit"] = 8
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a wrong expected exit fails the replay" 1 \
    python3 -I "$COPY_HARNESS" --mode replay --corpus "$TMP_ROOT/replay-mutant.json" \
    --guard "$GUARD" --stub "$STUB" --out "$TMP_ROOT/out-mutant"
if grep -q 'REFUSE-3-01' "$TMP_ROOT/last.log" 2>/dev/null; then
    pass "the wrong expected exit names the row"
else
    fail "the wrong expected exit names the row"
fi

# WHY: the resolver keeps its own copy of the T4 conditional signal families,
# so a term the table drops would still load a reference the table no longer
# routes to. Every term must sit in a T4 signal cell.
DRIFT=$(python3 -I - "$HARNESS" "$SKILL_SRC/SKILL.md" <<'PY'
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

# WHY: the table is the single source of the T5 source terms and the T11
# close signals, so a resolver constant the table drops would route a read
# the authored table no longer names.
SIGNAL_DRIFT=$(python3 -I - "$HARNESS" "$SKILL_SRC/SKILL.md" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("route_replay", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    rows = module.parse_route_table(handle.read())

def signals(route_type):
    row = next(item for item in rows if item["type"] == route_type)
    return {module.fold_text(phrase) for phrase in module.signal_phrases(row["dutch"]) + module.signal_phrases(row["english"])}

problems = []
t5 = signals("T5")
for term in module.SOURCE_TERMS:
    if module.fold_text(term) not in t5:
        problems.append("T5 signal missing from the table: %s" % term)
t11 = signals("T11")
for term in module.CLOSE_SIGNALS:
    if module.fold_text(term) not in t11:
        problems.append("T11 close signal missing from the table: %s" % term)
print("ok" if not problems else " and ".join(problems))
PY
)
if [[ "$SIGNAL_DRIFT" == "ok" ]]; then
    pass "the resolver source and close signals equal the table signals"
else
    fail "the resolver source and close signals equal the table signals ($SIGNAL_DRIFT)"
fi

# WHY: a documented specificity clause without a resolver pair would fall
# through to abstain, so every clause pair the prose names must be decided by
# the resolver and every resolver pair needs its own deciding sample.
CLAUSE_DRIFT=$(python3 -I - "$HARNESS" "$SKILL_SRC/references/routing-signals.md" "$SKILL_SRC/SKILL.md" <<'PY'
import importlib.util
import re
import sys

spec = importlib.util.spec_from_file_location("route_replay", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    signals_text = handle.read()
with open(sys.argv[3], "r", encoding="utf-8") as handle:
    rows = module.parse_route_table(handle.read())
section = signals_text.split("## 4. THE SPECIFICITY CLAUSES", 1)[-1].split("\n## ", 1)[0]
clauses = re.findall(r"^\d+\.\s+(.*)$", section, re.MULTILINE)

def normalize(pair):
    return tuple(sorted(pair, key=lambda value: int(value[1:])))

documented = []
for clause in clauses:
    for match in re.finditer(r"(T\d+)\s+beats?\s+((?:T\d+(?:\s*(?:,|and)\s*)?)+)", clause):
        first = match.group(1)
        for second in re.findall(r"T\d+", match.group(2)):
            documented.append(normalize((first, second)))
known = {normalize(pair) for pair in module.SPECIFICITY_PAIRS}
problems = []
for pair in documented:
    if "T8" in pair:
        continue
    if pair not in known:
        problems.append("no resolver pair for %s" % (pair,))
samples = {
    ("T4", "T3"): "an invoice",
    ("T4", "T2"): "an invoice",
    ("T5", "T6"): "the rate in 2026",
    ("T5", "T4"): "the official text",
    ("T6", "T4"): "since when did the rule change",
    ("T1", "T2"): "phase 3",
    ("T1", "T3"): "the gate",
    ("T10", "T3"): "the VAT return",
    ("T11", "T3"): "the yearly overview",
    ("T12", "T5"): "the income tax return",
}
samples = {normalize(pair): sample for pair, sample in samples.items()}
for pair in known:
    sample = samples.get(pair)
    if sample is None:
        problems.append("no resolver sample for %s" % (pair,))
        continue
    if module.specificity_winner(sample, pair[0], pair[1], rows) is None:
        problems.append("pair %s is not decided" % (pair,))
print("ok" if not problems else " and ".join(problems))
PY
)
if [[ "$CLAUSE_DRIFT" == "ok" ]]; then
    pass "every documented specificity clause has a resolver pair"
else
    fail "every documented specificity clause has a resolver pair ($CLAUSE_DRIFT)"
fi

# WHY: the fold and the whole-word filing gate carry the spelling rules, so
# a direct probe guards them before the fixture rows are scored.
GATE_PROBE=$(python3 -I - "$HARNESS" "$SKILL_SRC/SKILL.md" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("route_replay", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], "r", encoding="utf-8") as handle:
    rows = module.parse_route_table(handle.read())
problems = []
if not module.phrase_matches("kun je mijn btw aangifte voorbereiden", "btw-aangifte"):
    problems.append("spaced btw aangifte does not match")
if not module.phrase_matches("mijn ib aangifte klaarzetten", "IB-aangifte"):
    problems.append("spaced IB aangifte does not match")
if module.t8_signal_hit(rows, "de belastingdienst levert diensten"):
    problems.append("dien matched diensten")
if module.t8_signal_hit(rows, "the form was submitted"):
    problems.append("submit matched submitted")
if not module.t8_signal_hit(rows, "prepare the vat return and then submit it"):
    problems.append("submit did not match")
if module.t8_signal_hit(rows, "prepare the vat return, do not submit it"):
    problems.append("a negated submit matched")
if module.t8_signal_hit(rows, "bereid de btw-aangifte voor, maar dien die niet in"):
    problems.append("a negated Dutch filing verb matched")
print("ok" if not problems else " and ".join(problems))
PY
)
if [[ "$GATE_PROBE" == "ok" ]]; then
    pass "the spelling fold and the whole-word filing gate hold"
else
    fail "the spelling fold and the whole-word filing gate hold ($GATE_PROBE)"
fi

# ───────────────────────────────────────────────────────────────
# 10B. TWO TURN PREPARATION AND FILING PRECEDENCE
# ───────────────────────────────────────────────────────────────

# The contract fixes the filing verbs on the refusal row and the prepare
# signals on a T10 row, so the case seeds both into a copy of the table. A
# turn that prepares the VAT return routes T10. A later turn that asks to
# file it stops on T8, whatever T10 scores.
PRECEDENCE_CORPUS="$TMP_ROOT/precedence-gold.json"
python3 - "$PRECEDENCE_CORPUS" <<'PY'
import json
import sys

rows = [
    {
        "id": "TURN-PREPARE",
        "prompt": "Bereid de btw-aangifte voor.",
        "lang": "nl",
        "parityOf": "",
        "split": "calibration",
        "gold_mode": "LIVE",
        "gold_task_type": "T10",
        "category": "clean",
        "tier": "",
        "tie": "",
        "expected_paths": ["references/tax-rules/2026/vat/figures.md"],
        "forbidden_paths": [],
        "expected_facts": [],
        "token_ceiling": 15000,
        "year": "2026",
        "covers": ["004/REQ-002"],
    },
    {
        "id": "TURN-FILE",
        "previous_prompt": "Bereid de btw-aangifte voor.",
        "prompt": "File the VAT return now.",
        "lang": "en",
        "parityOf": "",
        "split": "calibration",
        "gold_mode": "ABSTAIN",
        "gold_task_type": "T8",
        "previous_gold_task_type": "T10",
        "previous_gold_mode": "LIVE",
        "category": "clean",
        "tier": "A",
        "tie": "",
        "expected_paths": [],
        "forbidden_paths": ["references/tax-rules/dutch-tax-rules.md"],
        "expected_facts": [],
        "token_ceiling": 0,
        "year": "2026",
        "covers": ["004/REQ-002"],
    },
]
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump({"rows": rows}, handle, indent=2)
PY
# WHY: the skill's own T8 and T10 rows carry the precedence, so the case
# runs against the real table and fails when either row loses its signals.
if ! grep -q '^| T10 | prepare the VAT return |' "$COPY/SKILL.md"; then
    fail "the skill copy holds the T10 row"
fi
check_exit "a preparation turn then a filing turn resolves with exit 0" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$PRECEDENCE_CORPUS" --out "$TMP_ROOT/out-precedence"
if grep -q '^TURN-FILE,en,calibration,ABSTAIN,T8,.*,PASS,' "$TMP_ROOT/out-precedence/results.csv" 2>/dev/null; then
    pass "the two turn precedence case routes T10 then T8"
else
    fail "the two turn precedence case routes T10 then T8"
    sed -n '1,5p' "$TMP_ROOT/last.log"
fi

# A revision run scores the worktree of that commit and removes it again.
# WHY: the live corpus asserts the routing fixes, which an older revision does
# not carry, so the run keeps the one covers tag whose rows are stable across
# the change. The worktree add and remove still run in full.
check_exit "a revision run scores the worktree of HEAD" 0 \
    python3 -I "$HARNESS" --mode resolve --rev HEAD --corpus "$CORPUS" --covers 005/REQ-001 --out "$TMP_ROOT/out-rev"

# ───────────────────────────────────────────────────────────────
# 10C. TAX DELIVERABLE BRANCH, PACK AND REFUSAL ROWS
# ───────────────────────────────────────────────────────────────

# Every new row must be present and passing in the clean resolve run and in
# the replay run that section 5 and section 10 already produced.
NEW_RESOLVE_ROWS=(
    VAT-BRANCH-Q1-01
    VAT-BRANCH-RC-01
    VAT-BRANCH-KOR-01
    VAT-BRANCH-YE-01
    VAT-BRANCH-COR-01
    PACK-YEARLY-01
    PACK-INCOME-01
    REFUSE-ROUTE-FILE-01
    REFUSE-ROUTE-SUBMIT-01
    REFUSE-ROUTE-PAY-01
    REFUSE-ROUTE-LOCK-01
)
for row_id in "${NEW_RESOLVE_ROWS[@]}"; do
    row_pass "$OUT_CLEAN/results.csv" "$row_id" "the branch, pack or refusal row $row_id resolves PASS"
done

ROUTING_FIX_ROWS=(
    AUDITFILE-LIVE-01
    PREP-KEEP-T10-01
    PREP-KEEP-T11-01
    PREP-KEEP-T12-01
    PREP-TIE-10-01
    PREP-TIE-11-01
    PREP-TIE-12-01
    SRC-PDF-01
    TAX-FIG-SRC-01
    SRC-INV-01
    PREP-T10-SRC-01
    PREP-T12-SRC-01
    VAT-Q4-JAN-01
    T11-CLOSE-01
    PREP-SPACE-T10-01
    PREP-SPACE-T12-01
    T7-DEST-JORTT-01
    T7-DEST-MONEYBIRD-01
    T7-DEST-BLOCKED-01
)
for row_id in "${ROUTING_FIX_ROWS[@]}"; do
    row_pass "$OUT_CLEAN/results.csv" "$row_id" "the routing fix row $row_id resolves PASS"
done

NEW_REPLAY_ROWS=(
    REFUSE-GUARD-FILE-01
    REFUSE-GUARD-SUBMIT-01
    REFUSE-GUARD-PAY-01
    REFUSE-GUARD-LOCK-01
)
for row_id in "${NEW_REPLAY_ROWS[@]}"; do
    row_pass "$OUT_REPLAY/results.csv" "$row_id" "the filing, submitting, paying or locking guard row $row_id replays at its recorded exit"
done

# A covers filter keeps exactly the tagged rows and every one of them passes
OUT_BRANCHES="$TMP_ROOT/out-branches"
check_exit "the five VAT branch rows resolve under their covers tag" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --covers 011/008/REQ-001 --out "$OUT_BRANCHES"
count_rows PASS "$OUT_BRANCHES/results.csv" 5 "five branch rows pass under the covers tag"

OUT_ROUTE_REFUSALS="$TMP_ROOT/out-route-refusals"
check_exit "the four routing refusal rows resolve under their covers tag" 0 \
    python3 -I "$COPY_HARNESS" --mode resolve --covers 011/008/REQ-002 --out "$OUT_ROUTE_REFUSALS"
count_rows PASS "$OUT_ROUTE_REFUSALS/results.csv" 4 "four routing refusal rows pass under the covers tag"

OUT_GUARD_REFUSALS="$TMP_ROOT/out-guard-refusals"
REPO_ROOT="$(dirname "$SKILL_SRC")"
GUARD="$REPO_ROOT/cli-moneybird/cli/moneybird-cli/moneybird-guard"
STUB="$REPO_ROOT/cli-moneybird/cli/moneybird-cli/tests/stub-moneybird-cli"
check_exit "the four guard refusal rows replay under their covers tag" 0 \
    python3 -I "$COPY_HARNESS" --mode replay --covers 011/008/REQ-002 \
    --guard "$GUARD" --stub "$STUB" --out "$OUT_GUARD_REFUSALS"
count_rows PASS "$OUT_GUARD_REFUSALS/results.csv" 4 "four guard refusal rows replay under the covers tag"

# A filing claim inside a prepare row must fail the run and name the row
python3 - "$COPY_CORPUS" "$TMP_ROOT/filing-claim.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("id") == "VAT-BRANCH-Q1-01":
        row["prompt"] = "File my VAT return for the first quarter of 2026."
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a filing claim in a prepare row exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$TMP_ROOT/filing-claim.json" \
    --covers 011/008/REQ-001 --out "$TMP_ROOT/out-filing-claim"
row_fails "$TMP_ROOT/out-filing-claim/results.csv" "VAT-BRANCH-Q1-01" "the filing claim names VAT-BRANCH-Q1-01"

# A pack row that expects a block the procedure does not ship must fail
python3 - "$COPY_CORPUS" "$TMP_ROOT/missing-block.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("id") == "PACK-YEARLY-01":
        row["expected_facts"] = list(row["expected_facts"]) + ["no such pack block"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a pack row with a missing block exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$TMP_ROOT/missing-block.json" \
    --covers 011/008/REQ-003 --out "$TMP_ROOT/out-missing-block"
row_fails "$TMP_ROOT/out-missing-block/results.csv" "PACK-YEARLY-01" "the missing pack block names PACK-YEARLY-01"

# A correction row that expects the read of the other side of the boundary
# must fail, because the below-boundary request loads no procedure figures.
python3 - "$COPY_CORPUS" "$TMP_ROOT/wrong-boundary.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for row in data["rows"]:
    if row.get("id") == "VAT-BRANCH-COR-01":
        row["expected_paths"] = list(row["expected_paths"]) + [
            "references/tax-rules/2026/procedure/figures.md"
        ]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY
check_exit "a correction row on the wrong side of the boundary exits 1" 1 \
    python3 -I "$COPY_HARNESS" --mode resolve --corpus "$TMP_ROOT/wrong-boundary.json" \
    --covers 011/008/REQ-001 --out "$TMP_ROOT/out-wrong-boundary"
row_fails "$TMP_ROOT/out-wrong-boundary/results.csv" "VAT-BRANCH-COR-01" "the wrong boundary side names VAT-BRANCH-COR-01"

# ───────────────────────────────────────────────────────────────
# 11. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
