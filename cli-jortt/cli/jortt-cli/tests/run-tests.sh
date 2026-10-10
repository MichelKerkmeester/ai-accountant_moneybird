#!/usr/bin/env bash
# WHY: Exercise the CLI contract against the local OpenAPI file without network access.
set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CLI="$(cd -P "$HERE/.." >/dev/null 2>&1 && pwd)/jortt-cli"
SPEC="${JORTT_OPENAPI_FILE:-}"
if [ -z "$SPEC" ] || [ ! -f "$SPEC" ]; then
  printf 'Set JORTT_OPENAPI_FILE to the local OpenAPI JSON before running tests.\n' >&2
  exit 2
fi
TEMP_ROOT="$HERE/.tmp-run-$$"
mkdir -p "$TEMP_ROOT"
trap 'rm -rf "$TEMP_ROOT"' EXIT HUP INT TERM
PASS=0
FAIL=0

record() {
  local name="$1"
  local passed="$2"
  if [ "$passed" = "1" ]; then
    PASS=$((PASS + 1))
    printf 'PASS %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s\n' "$name"
  fi
}

run_cli() {
  env JORTT_OPENAPI_FILE="$SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" "$@"
}

OPS="$(run_cli ops --json)"
if printf '%s' "$OPS" | jq -e 'length == 158 and ([.[].slug] | unique | length == 158)' >/dev/null 2>&1; then record "158 operations have unique slugs" 1; else record "158 operations have unique slugs" 0; fi

if printf '%s' "$OPS" | jq -e '([.[] | select(.path == "/customers" and .method == "GET")][0].slug == "list-customers") and ([.[] | select(.path == "/v1/customers" and .method == "GET")][0].slug == "list-customers-v1")' >/dev/null 2>&1; then record "collision prefers unversioned path over v1" 1; else record "collision prefers unversioned path over v1" 0; fi

DESCRIBE="$(run_cli describe list-expenses)"
if printf '%s' "$DESCRIBE" | grep -q 'Path: /v3/expenses' && printf '%s' "$DESCRIBE" | grep -q 'vat_date_from' && printf '%s' "$DESCRIBE" | grep -q 'Body schema: none'; then record "describe includes operation details" 1; else record "describe includes operation details" 0; fi

DRY="$(run_cli call list-expenses --vat_date_from 2023-01-01 --vat_date_till 2023-12-31 --dry-run)"
if printf '%s' "$DRY" | grep -q 'GET https://api.jortt.nl/v3/expenses?vat_date_from=2023-01-01&vat_date_till=2023-12-31'; then record "dry-run builds URL with query parameters" 1; else record "dry-run builds URL with query parameters" 0; fi

set +e
OUTPUT="$(env JORTT_OPENAPI_FILE="$SPEC" JORTT_SCOPES=expenses:write JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" call create-an-expense --dry-run 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 3 ] && printf '%s' "$OUTPUT" | grep -q -- '--allow-write'; then record "write without allow flag exits 3" 1; else record "write without allow flag exits 3" 0; fi

set +e
OUTPUT="$(env JORTT_OPENAPI_FILE="$SPEC" JORTT_SCOPES=expenses:read JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" call create-an-expense --allow-write --dry-run 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 4 ] && printf '%s' "$OUTPUT" | grep -q 'expenses:write'; then record "missing write scope exits 4" 1; else record "missing write scope exits 4" 0; fi

set +e
OUTPUT="$(run_cli call list-expenses --unknown_filter value --dry-run 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 2 ] && printf '%s' "$OUTPUT" | grep -q 'vat_date_from'; then record "unknown parameter lists valid parameters" 1; else record "unknown parameter lists valid parameters" 0; fi

set +e
OUTPUT="$(run_cli call list-expenses --page invalid --dry-run 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 2 ] && printf '%s' "$OUTPUT" | grep -q 'must be an integer'; then record "parameter type follows the spec" 1; else record "parameter type follows the spec" 0; fi

set +e
OUTPUT="$(run_cli call list-expenses --out "$TEMP_ROOT/outside.json" --dry-run 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 5 ]; then record "out-of-workspace call output exits 5" 1; else record "out-of-workspace call output exits 5" 0; fi

VALID_OUTPUT="$(
  ACCOUNTANT_ROOT="$TEMP_ROOT/accountant"
  mkdir -p "$ACCOUNTANT_ROOT/migration-workspace"
  # shellcheck disable=SC2329
  jortt_error() { local error_code="$1"; shift; printf '%s\n' "$*" >&2; exit "$error_code"; }
  # shellcheck disable=SC1091
  . "$HERE/../lib/workspace.sh"
  jortt_resolve_output migration-workspace/export.json 0
  printf '%s' "$JORTT_RESOLVED_OUT"
)"
if [ "$VALID_OUTPUT" = "$TEMP_ROOT/accountant/migration-workspace/export.json" ]; then record "in-workspace output resolves to its destination" 1; else record "in-workspace output resolves to its destination" 0; fi

set +e
OUTPUT="$(run_cli fetch https://example.invalid/never-request.bin --out "$TEMP_ROOT/outside.bin" 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 5 ]; then record "out-of-workspace fetch exits 5" 1; else record "out-of-workspace fetch exits 5" 0; fi

printf 'Result: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
