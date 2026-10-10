#!/usr/bin/env bash
# WHY: Check local setup without printing credentials or making a network request by default.
set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SKILL_ROOT="$(cd -P "$HERE/.." >/dev/null 2>&1 && pwd)"
ACCOUNTANT_ROOT="$(cd -P "$SKILL_ROOT/.." >/dev/null 2>&1 && pwd)"
LOCAL_CLI="$SKILL_ROOT/cli/jortt-cli/jortt-cli"
LIVE=0
if [ "${1:-}" = "--live" ]; then LIVE=1; shift; fi
[ "$#" -eq 0 ] || { printf 'Usage: bash scripts/doctor.sh [--live]\n' >&2; exit 2; }

printf '== cli-jortt doctor ==\n'
if [ -n "${BASH_VERSION:-}" ]; then printf 'bash: available\n'; else printf 'bash: missing\n'; fi
for tool in curl jq; do
  if command -v "$tool" >/dev/null 2>&1; then printf '%s: available\n' "$tool"; else printf '%s: missing\n' "$tool"; fi
done

if command -v jortt-cli >/dev/null 2>&1; then
  printf 'jortt-cli: %s\n' "$(command -v jortt-cli)"
elif [ -x "$LOCAL_CLI" ]; then
  printf 'jortt-cli: available in cli/jortt-cli\n'
else
  printf 'jortt-cli: missing\n'
fi

if [ -f "$ACCOUNTANT_ROOT/.env" ]; then printf '.env exists: yes\n'; else printf '.env exists: no\n'; fi
ENV_FILE="${JORTT_ENV_FILE:-$ACCOUNTANT_ROOT/.env}"

doc_read_value() {
  local name="$1"
  local line value
  case "$name" in
    JORTT_CLIENT_ID) value="${JORTT_CLIENT_ID:-}" ;;
    JORTT_CLIENT_SECRET) value="${JORTT_CLIENT_SECRET:-}" ;;
    JORTT_SCOPES) value="${JORTT_SCOPES:-}" ;;
  esac
  if [ -n "$value" ]; then printf '%s' "$value"; return 0; fi
  if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "$name"=*)
          value="${line#*=}"
          value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
          case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
          esac
          printf '%s' "$value"
          return 0
          ;;
      esac
    done < "$ENV_FILE"
  fi
  if [ "$name" = "JORTT_SCOPES" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        JORTT_SCOPES=*)
          value="${line#*=}"
          value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
          case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
          esac
          printf '%s' "$value"
          return 0
          ;;
      esac
    done < "$ACCOUNTANT_ROOT/.env.example"
  fi
  return 0
}

for variable in JORTT_CLIENT_ID JORTT_CLIENT_SECRET JORTT_SCOPES; do
  value="$(doc_read_value "$variable")"
  if [ -n "$value" ]; then printf '%s: set\n' "$variable"; else printf '%s: unset\n' "$variable"; fi
done
SCOPES_VALUE="$(doc_read_value JORTT_SCOPES)"
if [ -n "$SCOPES_VALUE" ]; then
  case " $SCOPES_VALUE " in
    *:write*) printf 'Configured scopes: contain :write\n' ;;
    *) printf 'Configured scopes: no :write\n' ;;
  esac
else
  printf 'Configured scopes: unset\n'
fi

if [ -n "${JORTT_OPENAPI_FILE:-}" ]; then
  SPEC_PATH="$JORTT_OPENAPI_FILE"
else
  SPEC_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/jortt-cli/openapi.json"
fi
if [ -f "$SPEC_PATH" ]; then
  printf 'OpenAPI spec cache: present\n'
  if [ -x "$LOCAL_CLI" ]; then "$LOCAL_CLI" spec info; fi
else
  printf 'OpenAPI spec cache: missing\n'
fi

if [ "$LIVE" -eq 1 ]; then
  LIVE_CLIENT_ID="$(doc_read_value JORTT_CLIENT_ID)"
  LIVE_CLIENT_SECRET="$(doc_read_value JORTT_CLIENT_SECRET)"
  if [ -n "$LIVE_CLIENT_ID" ] && [ -n "$LIVE_CLIENT_SECRET" ] && [ -x "$LOCAL_CLI" ]; then
    set +e
    LIVE_OUTPUT="$(JORTT_OPENAPI_FILE="${JORTT_OPENAPI_FILE:-}" "$LOCAL_CLI" whoami 2>&1)"
    LIVE_CODE=$?
    set -e
    if [ "$LIVE_CODE" -eq 0 ]; then
      printf '%s\n' "$LIVE_OUTPUT"
    else
      printf 'Live whoami failed with exit code %s.\n' "$LIVE_CODE"
    fi
  else
    printf 'Live whoami skipped: JORTT_CLIENT_ID and JORTT_CLIENT_SECRET are unset.\n'
  fi
fi

if [ "$LIVE" -eq 0 ]; then printf 'Mode: offline. No network calls were made.\n'; fi
