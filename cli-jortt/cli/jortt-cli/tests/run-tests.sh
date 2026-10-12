#!/usr/bin/env bash
# WHY: Exercise the CLI contract against the local OpenAPI file without network access.
set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CLI="$(cd -P "$HERE/.." >/dev/null 2>&1 && pwd)/jortt-cli"
SPEC="${JORTT_OPENAPI_FILE:-$HERE/fixtures/openapi-trimmed.json}"
if [ ! -f "$SPEC" ]; then
  printf 'OpenAPI file not found. Set JORTT_OPENAPI_FILE or restore the trimmed fixture under tests/fixtures/.\n' >&2
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
SPEC_OPERATIONS="$(jq '[.paths | to_entries[] | .value | to_entries[] | select(.key | IN("get", "post", "put", "patch", "delete"))] | length' "$SPEC")"
if printf '%s' "$OPS" | jq -e --argjson expected "$SPEC_OPERATIONS" 'length == $expected and ([.[].slug] | unique | length == $expected)' >/dev/null 2>&1; then record "every spec operation has a unique slug" 1; else record "every spec operation has a unique slug" 0; fi

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

# WHY: token status must report where JORTT_SCOPES came from without exposing the value.
set +e
OUTPUT="$(env JORTT_OPENAPI_FILE="$SPEC" JORTT_SCOPES=expenses:read JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" token status 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 0 ] && printf '%s' "$OUTPUT" | grep -q 'scope source: environment'; then record "token status reports the environment scope source" 1; else record "token status reports the environment scope source" 0; fi

ENV_FILE="$(mktemp "$TEMP_ROOT/scopes-env.XXXXXX")"
printf 'JORTT_SCOPES=expenses:read\n' > "$ENV_FILE"
set +e
OUTPUT="$(env -u JORTT_SCOPES JORTT_OPENAPI_FILE="$SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE="$ENV_FILE" "$CLI" token status 2>&1)"
CODE=$?
set -e
if [ "$CODE" -eq 0 ] && printf '%s' "$OUTPUT" | grep -q 'scope source: env file'; then record "token status reports the env file scope source" 1; else record "token status reports the env file scope source" 0; fi
rm -f "$ENV_FILE"

set +e
OUTPUT="$(env -u JORTT_SCOPES JORTT_OPENAPI_FILE="$SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" token status 2>"$TEMP_ROOT/fallback-stderr.txt")"
CODE=$?
set -e
if [ "$CODE" -eq 0 ] \
  && printf '%s' "$OUTPUT" | grep -q 'scope source: .env.example fallback' \
  && grep -q 'warning: JORTT_SCOPES came from .env.example and may not match the configured key' "$TEMP_ROOT/fallback-stderr.txt"; then
  record "token status warns for the .env.example fallback scope source" 1
else
  record "token status warns for the .env.example fallback scope source" 0
fi

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

STUB_DIR="$TEMP_ROOT/bin"
FAKE_ROOT="$TEMP_ROOT/repo"
FAKE_CLI="$FAKE_ROOT/cli-jortt/cli/jortt-cli/jortt-cli"
mkdir -p "$STUB_DIR" "$TEMP_ROOT/tmp" "$FAKE_ROOT/cli-jortt/cli/jortt-cli/lib"
cp "$CLI" "$FAKE_CLI"
cp "$HERE/../lib/"*.sh "$FAKE_ROOT/cli-jortt/cli/jortt-cli/lib/"
chmod +x "$FAKE_CLI"

cat > "$STUB_DIR/curl" <<'STUB_CURL'
#!/usr/bin/env bash
# WHY: Answer requests from files so the CLI contract is testable offline.
set -euo pipefail
config_file=''
destination=''
read_stdin=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      config_file="$2"
      shift 2
      ;;
    -D)
      : > "$2"
      shift 2
      ;;
    -o)
      destination="$2"
      shift 2
      ;;
    -w)
      shift 2
      ;;
    --data-binary)
      case "$2" in
        @-) read_stdin=1 ;;
      esac
      shift 2
      ;;
    -fsSL|-sS|-L|-f|-S)
      shift
      ;;
    --retry)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [ "$read_stdin" = "1" ]; then
  cat >/dev/null 2>&1 || true
fi
url="$(awk -F'"' '/^url = "/ { print $2; exit }' "$config_file" 2>/dev/null)" || url=''
case "$url" in
  https://app.jortt.nl/oauth-provider/oauth/token*)
    if [ -n "${STUB_TOKEN_STATUS:-}" ]; then
      body='{"error":"invalid_client"}'
      status="$STUB_TOKEN_STATUS"
    else
      body='{"access_token":"stub-token","expires_in":3600}'
      status='200'
    fi
    ;;
  *)
    body="$(cat "${STUB_HTTP_BODY_FILE:?}")"
    status="${STUB_HTTP_STATUS:-200}"
    ;;
esac
if [ -n "$destination" ]; then
  printf '%s' "$body" > "$destination"
  printf '%s' "$status"
else
  printf '%s\n%s' "$body" "$status"
fi
STUB_CURL
chmod +x "$STUB_DIR/curl"

fake_body() {
  printf '%s' "$1" > "$FAKE_ROOT/response.json"
}

run_fake() {
  env -u CLAUDECODE -u AI_SESSION_CHILD -u ACCOUNTANT_AGENT_SESSION -u CODEX_SANDBOX \
    PATH="$STUB_DIR:$PATH" TMPDIR="$TEMP_ROOT/tmp" \
    STUB_HTTP_BODY_FILE="$FAKE_ROOT/response.json" STUB_HTTP_STATUS="${STUB_HTTP_STATUS:-200}" \
    JORTT_OPENAPI_FILE="$SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null \
    "$FAKE_CLI" "$@"
}

fake_body '{"data":[{"id":1,"name":"Secret Customer"},{"id":2,"name":"Other Customer"}],"_links":{"next":null}}'
set +e
SUMMARY="$(run_fake get /customers 2>&1)"
SUMMARY_CODE=$?
set -e
if [ "$SUMMARY_CODE" -eq 0 ] \
  && printf '%s' "$SUMMARY" | grep -q 'HTTP 200' \
  && printf '%s' "$SUMMARY" | grep -q 'data items: 2' \
  && printf '%s' "$SUMMARY" | grep -q 'top-level keys: _links, data' \
  && ! printf '%s' "$SUMMARY" | grep -q 'Secret Customer'; then
  record "summary is the default output and hides values" 1
else
  record "summary is the default output and hides values" 0
fi

set +e
SAVE_OUTPUT="$(run_fake get /customers --out migration-workspace/exports/customers.json 2>&1)"
SAVE_CODE=$?
set -e
SAVED_FILE="$FAKE_ROOT/migration-workspace/exports/customers.json"
if [ "$SAVE_CODE" -eq 0 ] \
  && printf '%s' "$SAVE_OUTPUT" | grep -q 'data items: 2' \
  && jq -e '.data | length == 2' "$SAVED_FILE" >/dev/null 2>&1 \
  && grep -q 'Secret Customer' "$SAVED_FILE"; then
  record "--out saves the full body and still prints a summary" 1
else
  record "--out saves the full body and still prints a summary" 0
fi

set +e
BODY_OUTPUT="$(run_fake get /customers --print-body 2>&1)"
BODY_CODE=$?
set -e
if [ "$BODY_CODE" -eq 0 ] \
  && printf '%s' "$BODY_OUTPUT" | grep -q 'Secret Customer' \
  && printf '%s' "$BODY_OUTPUT" | grep -q '"name"'; then
  record "--print-body prints the full body without session markers" 1
else
  record "--print-body prints the full body without session markers" 0
fi

MARKER_FAILURES=0
for MARKER in CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX; do
  set +e
  MARKER_OUTPUT="$(env "$MARKER=1" PATH="$STUB_DIR:$PATH" TMPDIR="$TEMP_ROOT/tmp" \
    STUB_HTTP_BODY_FILE="$FAKE_ROOT/response.json" \
    JORTT_OPENAPI_FILE="$SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null \
    "$FAKE_CLI" call list-expenses --print-body 2>&1)"
  MARKER_CODE=$?
  set -e
  case "$MARKER_OUTPUT" in
    *$'\n'*) MARKER_FAILURES=$((MARKER_FAILURES + 1)) ;;
  esac
  if [ "$MARKER_CODE" -ne 2 ] || ! printf '%s' "$MARKER_OUTPUT" | grep -q -- '--print-body'; then
    MARKER_FAILURES=$((MARKER_FAILURES + 1))
  fi
done
if [ "$MARKER_FAILURES" -eq 0 ]; then record "--print-body is refused with a one-line reason for every marker" 1; else record "--print-body is refused with a one-line reason for every marker" 0; fi

set +e
GET_MARKER_OUTPUT="$(env CLAUDECODE=1 PATH="$STUB_DIR:$PATH" TMPDIR="$TEMP_ROOT/tmp" \
  STUB_HTTP_BODY_FILE="$FAKE_ROOT/response.json" \
  JORTT_OPENAPI_FILE="$SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null \
  "$FAKE_CLI" get /customers --print-body 2>&1)"
GET_MARKER_CODE=$?
set -e
if [ "$GET_MARKER_CODE" -eq 2 ] && printf '%s' "$GET_MARKER_OUTPUT" | grep -q -- '--print-body'; then
  record "get refuses --print-body in an agent session" 1
else
  record "get refuses --print-body in an agent session" 0
fi

fake_body '{"message":"Secret Customer is invalid","errors":{"vat_number":["is not valid"]}}'
export STUB_HTTP_STATUS=422
set +e
ERROR_OUTPUT="$(run_fake get /customers 2>&1)"
ERROR_CODE=$?
set -e
unset STUB_HTTP_STATUS
ERROR_LOG="$FAKE_ROOT/migration-workspace/logs/jortt-errors.log"
ERROR_LOG_MODE="$(stat -c '%a' "$ERROR_LOG" 2>/dev/null || stat -f '%Lp' "$ERROR_LOG" 2>/dev/null || printf '')"
if [ "$ERROR_CODE" -eq 1 ] \
  && printf '%s' "$ERROR_OUTPUT" | grep -q 'HTTP 422' \
  && printf '%s' "$ERROR_OUTPUT" | grep -q 'fields: vat_number' \
  && ! printf '%s' "$ERROR_OUTPUT" | grep -q 'Secret Customer' \
  && ! printf '%s' "$ERROR_OUTPUT" | grep -q 'is not valid' \
  && printf '%s' "$ERROR_OUTPUT" | grep -q 'jortt-errors.log' \
  && [ "$ERROR_LOG_MODE" = "600" ] \
  && grep -q 'Secret Customer is invalid' "$ERROR_LOG"; then
  record "API errors hide message text and log the full body at mode 600" 1
else
  record "API errors hide message text and log the full body at mode 600" 0
fi

# Fault injection: one case per exit code, 1 to 6. The stub answers and the
# trimmed spec drive codes 1, 2 and 6, and the CLI's own gates drive 3, 4 and 5.

# An upstream server error exits 1.
fake_body '{"message":"the stub answered with a server error"}'
export STUB_HTTP_STATUS=500
set +e
FAULT_1_OUTPUT="$(run_fake get /customers 2>&1)"
FAULT_1_CODE=$?
set -e
unset STUB_HTTP_STATUS
if [ "$FAULT_1_CODE" -eq 1 ] && printf '%s' "$FAULT_1_OUTPUT" | grep -q 'HTTP 500'; then
  record "fault case 1: an upstream 500 exits 1" 1
else
  record "fault case 1: an upstream 500 exits 1" 0
fi

# A file that is not a Swagger 2.0 document exits 2.
BAD_SPEC="$TEMP_ROOT/not-swagger.json"
printf '{"paths":{}}' > "$BAD_SPEC"
set +e
FAULT_2_OUTPUT="$(env JORTT_OPENAPI_FILE="$BAD_SPEC" JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" ops --json 2>&1)"
FAULT_2_CODE=$?
set -e
if [ "$FAULT_2_CODE" -eq 2 ] && printf '%s' "$FAULT_2_OUTPUT" | grep -q 'not a readable Swagger 2.0 document'; then
  record "fault case 2: a broken OpenAPI file exits 2" 1
else
  record "fault case 2: a broken OpenAPI file exits 2" 0
fi

# A write without --allow-write exits 3.
set +e
FAULT_3_OUTPUT="$(env JORTT_OPENAPI_FILE="$SPEC" JORTT_SCOPES=expenses:write JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" call create-an-expense --dry-run 2>&1)"
FAULT_3_CODE=$?
set -e
if [ "$FAULT_3_CODE" -eq 3 ] && printf '%s' "$FAULT_3_OUTPUT" | grep -q -- '--allow-write'; then
  record "fault case 3: a write without --allow-write exits 3" 1
else
  record "fault case 3: a write without --allow-write exits 3" 0
fi

# A write without its scope exits 4.
set +e
FAULT_4_OUTPUT="$(env JORTT_OPENAPI_FILE="$SPEC" JORTT_SCOPES=expenses:read JORTT_CLIENT_ID=test-client JORTT_CLIENT_SECRET=test-secret JORTT_ENV_FILE=/dev/null "$CLI" call create-an-expense --allow-write --dry-run 2>&1)"
FAULT_4_CODE=$?
set -e
if [ "$FAULT_4_CODE" -eq 4 ] && printf '%s' "$FAULT_4_OUTPUT" | grep -q 'expenses:write'; then
  record "fault case 4: a write without its scope exits 4" 1
else
  record "fault case 4: a write without its scope exits 4" 0
fi

# An output path outside the workspace exits 5.
set +e
FAULT_5_OUTPUT="$(run_cli call list-expenses --out "$TEMP_ROOT/outside.json" --dry-run 2>&1)"
FAULT_5_CODE=$?
set -e
if [ "$FAULT_5_CODE" -eq 5 ] && printf '%s' "$FAULT_5_OUTPUT" | grep -q 'must resolve inside migration-workspace'; then
  record "fault case 5: an output path outside the workspace exits 5" 1
else
  record "fault case 5: an output path outside the workspace exits 5" 0
fi

# A refused token request exits 6.
run_fake token clear >/dev/null 2>&1
export STUB_TOKEN_STATUS=401
set +e
FAULT_6_OUTPUT="$(run_fake get /customers 2>&1)"
FAULT_6_CODE=$?
set -e
unset STUB_TOKEN_STATUS
if [ "$FAULT_6_CODE" -eq 6 ] && printf '%s' "$FAULT_6_OUTPUT" | grep -q 'token request failed with HTTP 401'; then
  record "fault case 6: a refused token request exits 6" 1
else
  record "fault case 6: a refused token request exits 6" 0
fi

printf 'Result: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
