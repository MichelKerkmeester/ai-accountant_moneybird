#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: SOURCE TO TARGET HANDOFF TEST
# ───────────────────────────────────────────────────────────────
# Tests the provenance chain from a synthetic source manifest to a guarded
# Moneybird write without a network call. The suite builds an artifact, a
# manifest, a mapping and a flushed WRITE_INTENT, runs a precheck over the
# three hashes and only then calls the real guard through its stub. A changed
# artifact, manifest, mapping or payload digest has to fail before the stub
# records any real call.
# Usage: source-to-target-handoff-test.sh [repository root]
# Exit Codes:
#   0 - All checks pass
#   1 - One or more checks fail
#   2 - Invalid arguments or missing files
#
# WHY: the source-manifest hash reaches the mapping and the intent while no
# shipped code reads it, so one offline chain proves the binding before the
# migration mirror batches and fails loudly when a hash drifts.
# WHY: the suite inspects $? after commands that are expected to fail, so -e stays off.
set -uo pipefail

# ───────────────────────────────────────────────────────────────
# 1. SCRIPT PATHS
# ───────────────────────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P) || exit 1
DEFAULT_REPO=$(dirname "$(dirname "$SCRIPT_DIR")")

# ───────────────────────────────────────────────────────────────
# 2. ARGUMENT AND FILE VALIDATION
# ───────────────────────────────────────────────────────────────

if [[ "$#" -gt 1 ]]; then
    printf 'error: usage: source-to-target-handoff-test.sh [repository root]\n' >&2
    exit 2
fi

REPO_SRC="${1:-$DEFAULT_REPO}"
if ! REPO_SRC=$(cd "$REPO_SRC" 2>/dev/null && pwd -P); then
    printf 'error: repository root not found\n' >&2
    exit 2
fi

GUARD="$REPO_SRC/cli-moneybird/cli/moneybird-cli/moneybird-guard"
STUB="$REPO_SRC/cli-moneybird/cli/moneybird-cli/tests/stub-moneybird-cli"
SHARED="$REPO_SRC/sk-moneybird-accountant/references/migration/shared-mechanisms.md"

for required in "$GUARD" "$STUB" "$SHARED"; do
    if [[ ! -f "$required" ]]; then
        printf 'error: missing %s\n' "$required" >&2
        exit 2
    fi
done

# ───────────────────────────────────────────────────────────────
# 3. TEMP ROOT AND CLEANUP
# ───────────────────────────────────────────────────────────────

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/source-to-target-handoff-test.XXXXXX") || exit 2

# Remove the temp root on exit so no fixture survives the run
# shellcheck disable=SC2329  # the EXIT trap calls it
cleanup() {
    if [[ -n "${TEST_ROOT:-}" ]] && [[ -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}
trap cleanup EXIT

# WHY: the guard is offline only under its test flag, and the flag exists for
# the offline suite alone, so the harness pins the stub, the temp workspace and
# the writer folder here and never reads a real credential.
export HOME="$TEST_ROOT/home"
export MONEYBIRD_GUARD_TEST=1
export MONEYBIRD_ENV_DIR="$TEST_ROOT/accountant"
export MONEYBIRD_CLI="$STUB"
export MONEYBIRD_TEST_LOG="$TEST_ROOT/invocations.log"
export MONEYBIRD_TEST_ADMINISTRATION_ID="PILOT_ADMIN"
export MONEYBIRD_WRITER_CONFIG_DIR="$TEST_ROOT/writer-config"
unset MONEYBIRD_PILOT_ADMINISTRATION_ID MONEYBIRD_GUARD_READ_ONLY MONEYBIRD_HMAC_KEY_FILE || true
unset CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX || true
mkdir -p "$HOME/.config/moneybird-cli-writer" "$MONEYBIRD_ENV_DIR/migration-workspace" "$MONEYBIRD_WRITER_CONFIG_DIR"
printf 'MONEYBIRD_PILOT_ADMINISTRATION_ID=PILOT_ADMIN\n' >"$MONEYBIRD_ENV_DIR/.env"
: > "$MONEYBIRD_TEST_LOG"

KEY_FILE="$MONEYBIRD_ENV_DIR/migration-workspace/.secrets/alias-hmac.key"
mkdir -p "$(dirname "$KEY_FILE")"
if ! python3 -I -c 'import secrets, sys; open(sys.argv[1], "w").write(secrets.token_hex(32))' "$KEY_FILE"; then
    printf 'error: could not write the fake key file\n' >&2
    exit 2
fi
JOURNAL_DIR="$MONEYBIRD_ENV_DIR/migration-workspace/RunJournal"
JOURNAL="$JOURNAL_DIR/run-journal.jsonl"
WRITE_LOG="$MONEYBIRD_ENV_DIR/migration-workspace/logs/moneybird-writes.jsonl"

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

# Print a section heading before the next block of checks
# Args:
#   $1 - Group title
group() {
    printf '\n== %s\n' "$1"
}

# Count the stub log lines that start with one marker
# Args:
#   $1 - Marker text
count_log() {
    grep -c "^$1" "$MONEYBIRD_TEST_LOG" 2>/dev/null || true
}

# ───────────────────────────────────────────────────────────────
# 5. FIXTURE CHAIN
# ───────────────────────────────────────────────────────────────

ARTIFACT="$TEST_ROOT/export.bin"
MANIFEST="$TEST_ROOT/manifest.json"
MAPPING="$TEST_ROOT/mapping.json"
INTENT="$TEST_ROOT/intent.json"
PRECHECK="$TEST_ROOT/handoff-precheck.py"

# WHY: the precheck stands in for the parent that recomputes every approved
# input hash immediately before a non-GET call. The guard keeps its own
# payload binding, and this chain adds the source-manifest hash it never reads.
cat >"$PRECHECK" <<'PY' || exit 2
import hashlib
import hmac
import json
import sys

key_path, artifact_path, manifest_path, mapping_path, intent_path = sys.argv[1:6]


def sha256_file(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")


with open(key_path, "rb") as handle:
    key = handle.read()
with open(manifest_path, "rb") as handle:
    manifest = json.load(handle)
with open(mapping_path, "rb") as handle:
    mapping = json.load(handle)
with open(intent_path, "rb") as handle:
    intent = json.load(handle)

if manifest.get("artifact_sha256") != sha256_file(artifact_path):
    print("drift artifact_sha256")
    sys.exit(1)
manifest_hash = hashlib.sha256(canonical(manifest)).hexdigest()
if mapping.get("source_manifest_hash") != manifest_hash:
    print("drift source_manifest_hash mapping")
    sys.exit(1)
if intent.get("source_manifest_hash") != manifest_hash:
    print("drift source_manifest_hash intent")
    sys.exit(1)

method = "POST"
url = mapping["target_url"]
body = canonical(mapping["planned_payload"]).decode("utf-8")
host_path = url.split("://", 1)[-1]
path = "/" + host_path.split("/", 1)[1]
canonical_text = method + "\n" + path + "\n"
for line in body.split("\n"):
    canonical_text += line + "\n"
digest = hmac.new(key, canonical_text.encode("utf-8"), hashlib.sha256).hexdigest()
if intent.get("payload_digest") != digest:
    print("drift payload_digest")
    sys.exit(1)
print("ok")
PY

# Build the synthetic chain and flush its forced intent to the run journal
# Args:
#   $1 - Planned payload batch key
# Returns:
#   0 when every file is written, 1 when a write fails
build_chain() {
    local batch_key="$1"
    mkdir -p "$JOURNAL_DIR" "$(dirname "$WRITE_LOG")" "$MONEYBIRD_ENV_DIR/migration-workspace/logs" || return 1
    printf 'synthetic export bytes\n' >"$ARTIFACT" || return 1
    python3 -I - "$KEY_FILE" "$ARTIFACT" "$MANIFEST" "$MAPPING" "$INTENT" "$batch_key" <<'PY' || return 1
import hashlib
import hmac
import json
import sys

key_path, artifact_path, manifest_path, mapping_path, intent_path, batch_key = sys.argv[1:7]
with open(key_path, "rb") as handle:
    key = handle.read()


def sha256_file(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")


manifest = {
    "source": "jortt",
    "scope": "contacts",
    "period": "2023",
    "record_count": 1,
    "artifact_sha256": sha256_file(artifact_path)
}
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, sort_keys=True, indent=2)
    handle.write("\n")
manifest_hash = hashlib.sha256(canonical(manifest)).hexdigest()

mapping = {
    "write_key": "jortt|pilot|contact|stub-record|moneybird|pilot",
    "schema_version": "1",
    "source_manifest_hash": manifest_hash,
    "planned_payload": {"contacts": {}},
    "target_url": "https://moneybird.com/api/v2/PILOT_ADMIN/contacts.json"
}
with open(mapping_path, "w", encoding="utf-8") as handle:
    json.dump(mapping, handle, sort_keys=True, indent=2)
    handle.write("\n")

method = "POST"
host_path = mapping["target_url"].split("://", 1)[-1]
path = "/" + host_path.split("/", 1)[1]
body = canonical(mapping["planned_payload"]).decode("utf-8")
canonical_text = method + "\n" + path + "\n"
for line in body.split("\n"):
    canonical_text += line + "\n"
digest = hmac.new(key, canonical_text.encode("utf-8"), hashlib.sha256).hexdigest()

intent = {
    "approval_reference": "HANDOFF-APPROVED",
    "new_state": "WRITE_INTENT",
    "payload_digest": digest,
    "batch_key": batch_key,
    "source_manifest_hash": manifest_hash
}
with open(intent_path, "w", encoding="utf-8") as handle:
    json.dump(intent, handle, sort_keys=True, indent=2)
    handle.write("\n")
PY
    python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); print(json.dumps(d, sort_keys=True))' "$INTENT" >"$JOURNAL" || return 1
}

# Run the provenance precheck over the chain
# Returns:
#   The precheck exit status, with its line in $TEST_ROOT/precheck.out
handoff_precheck() {
    python3 -I "$PRECHECK" "$KEY_FILE" "$ARTIFACT" "$MANIFEST" "$MAPPING" "$INTENT" >"$TEST_ROOT/precheck.out" 2>&1
}

# Run the whole handoff: the precheck, then the guarded write only when it passes
# Returns:
#   0 when the guard wrote, the precheck status when it refused, else the guard status
# WHY: every case goes through this one path, so a drift case proves the
# precheck keeps the guard from being called, not only that the precheck fails.
handoff_write() {
    handoff_precheck || return $?
    "$GUARD" --confirm-write --approval HANDOFF-APPROVED contacts create >"$TEST_ROOT/guard.out" 2>&1
}

# ───────────────────────────────────────────────────────────────
# 6. CHAIN CASES
# ───────────────────────────────────────────────────────────────

group "provenance chain"

if build_chain "handoff-clean"; then
    pass "the synthetic source chain builds"
else
    fail "the synthetic source chain builds"
fi

if grep -qF 'source-manifest hash' "$SHARED"; then
    pass "the shared mechanism names the source-manifest hash in the chain"
else
    fail "the shared mechanism names the source-manifest hash in the chain"
fi

: > "$MONEYBIRD_TEST_LOG"
if handoff_write; then
    GUARD_STATUS=0
else
    GUARD_STATUS=$?
fi
if grep -q '^ok$' "$TEST_ROOT/precheck.out"; then
    pass "a consistent artifact, manifest, mapping and intent pass the precheck"
else
    fail "a consistent artifact, manifest, mapping and intent pass the precheck"
fi

if [[ "$GUARD_STATUS" -eq 0 && "$(count_log 'REAL POST ')" == "1" && -f "$WRITE_LOG" ]] \
    && printf '%s\n' "$(tail -n1 "$WRITE_LOG")" | jq -e --arg digest "$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["payload_digest"])' "$INTENT")" \
        'has("approval_reference") and has("batch_key") and has("payload_digest") and (has("body") | not) and .payload_digest == $digest' >/dev/null; then
    pass "the consistent chain writes once through the guard stub"
else
    fail "the consistent chain writes once through the guard stub (status $GUARD_STATUS, posts $(count_log 'REAL POST '))"
fi

# ───────────────────────────────────────────────────────────────
# 7. DRIFT CASES
# ───────────────────────────────────────────────────────────────

group "drift stops before the call"

# WHY: the manifest changed after approval, so its recomputed hash no longer
# matches the hash the mapping and the intent carry.
# WHY: each drift case starts from a fresh chain, an unused batch key and an
# empty write log, so the guard would write if the precheck let it through.
fresh_chain() {
    rm -f "$WRITE_LOG"
    : > "$MONEYBIRD_TEST_LOG"
    build_chain "$1"
}
fresh_chain "handoff-manifest" || fail "the manifest drift chain builds"
python3 -I - "$MANIFEST" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["record_count"] = 2
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, sort_keys=True, indent=2)
    handle.write("\n")
PY
if ! handoff_write && grep -q 'drift source_manifest_hash' "$TEST_ROOT/precheck.out" \
    && [[ "$(count_log 'REAL POST ')" == "0" ]]; then
    pass "a changed manifest hash stops before the call"
else
    fail "a changed manifest hash stops before the call"
fi

# WHY: the mapping changed, so the planned payload no longer digests to the
# value the intent carries.
if fresh_chain "handoff-mapping"; then
    python3 -I - "$MAPPING" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["planned_payload"]["contacts"]["company_name"] = "changed"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, sort_keys=True, indent=2)
    handle.write("\n")
PY
    if ! handoff_write && grep -q 'drift payload_digest' "$TEST_ROOT/precheck.out" \
        && [[ "$(count_log 'REAL POST ')" == "0" ]]; then
        pass "a changed mapping stops before the call"
    else
        fail "a changed mapping stops before the call"
    fi
else
    fail "a changed mapping stops before the call"
fi

# WHY: the intent carries a stale digest, so the precheck and the guard both
# refuse it and the stub sees no call.
if fresh_chain "handoff-digest"; then
    python3 -I - "$INTENT" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
data["payload_digest"] = "0" * 64
with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, sort_keys=True, indent=2)
    handle.write("\n")
PY
    if ! handoff_write && grep -q 'drift payload_digest' "$TEST_ROOT/precheck.out" \
        && [[ "$(count_log 'REAL POST ')" == "0" ]]; then
        pass "a changed payload digest stops before the call"
    else
        fail "a changed payload digest stops before the call"
    fi
    python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); print(json.dumps(d, sort_keys=True))' "$INTENT" >"$JOURNAL"
    if "$GUARD" --confirm-write --approval HANDOFF-APPROVED contacts create >"$TEST_ROOT/guard.out" 2>&1; then
        STALE_STATUS=0
    else
        STALE_STATUS=$?
    fi
    if [[ "$STALE_STATUS" -eq 9 ]] && grep -q 'PAYLOAD_MISMATCH' "$TEST_ROOT/guard.out" \
        && [[ "$(count_log 'REAL POST ')" == "0" ]]; then
        pass "the guard refuses the stale digest before the real call"
    else
        fail "the guard refuses the stale digest before the real call (status $STALE_STATUS)"
    fi
else
    fail "a changed payload digest stops before the call"
    fail "the guard refuses the stale digest before the real call"
fi

# WHY: the exported artifact changed after its hash was recorded, so the
# manifest no longer describes the bytes it ships.
if fresh_chain "handoff-artifact"; then
    printf 'changed export bytes\n' >"$ARTIFACT"
    if ! handoff_write && grep -q 'drift artifact_sha256' "$TEST_ROOT/precheck.out" \
        && [[ "$(count_log 'REAL POST ')" == "0" ]]; then
        pass "a changed artifact stops before the call"
    else
        fail "a changed artifact stops before the call"
    fi
else
    fail "a changed artifact stops before the call"
fi

# ───────────────────────────────────────────────────────────────
# 8. RESULT SUMMARY AND EXIT
# ───────────────────────────────────────────────────────────────

printf '\nResult: %d passed, %d failed\n' "$passed" "$failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi
exit 0
