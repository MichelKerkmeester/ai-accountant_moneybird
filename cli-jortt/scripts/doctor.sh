#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: JORTT CLI DOCTOR
# ───────────────────────────────────────────────────────────────
# Check local setup without printing credentials or making a network
# request by default.
#
# Usage: bash scripts/doctor.sh
#
# Exit Codes:
#   0 - Report printed
#   2 - Usage error

set -euo pipefail

# ───────────────────────────────────────────────────────────────
# 1. PATH RESOLUTION
# ───────────────────────────────────────────────────────────────

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SKILL_ROOT="$(cd -P "$HERE/.." >/dev/null 2>&1 && pwd)"
ACCOUNTANT_ROOT="$(cd -P "$SKILL_ROOT/.." >/dev/null 2>&1 && pwd)"
LOCAL_CLI="$SKILL_ROOT/cli/jortt-cli/jortt-cli"
[[ "$#" -eq 0 ]] || { printf 'Usage: bash scripts/doctor.sh\n' >&2; exit 2; }

# ───────────────────────────────────────────────────────────────
# 2. RUNTIME CHECKS
# ───────────────────────────────────────────────────────────────

printf '== cli-jortt doctor ==\n'
if [[ -n "${BASH_VERSION:-}" ]]; then printf 'bash: available\n'; else printf 'bash: missing\n'; fi
for tool in curl jq; do
  if command -v "$tool" >/dev/null 2>&1; then printf '%s: available\n' "$tool"; else printf '%s: missing\n' "$tool"; fi
done

if command -v jortt-cli >/dev/null 2>&1; then
  printf 'jortt-cli: %s\n' "$(command -v jortt-cli)"
elif [[ -x "$LOCAL_CLI" ]]; then
  printf 'jortt-cli: available in cli/jortt-cli\n'
else
  printf 'jortt-cli: missing\n'
fi

if [[ -f "$ACCOUNTANT_ROOT/.env" ]]; then printf '.env exists: yes\n'; else printf '.env exists: no\n'; fi
ENV_FILE="${JORTT_ENV_FILE:-$ACCOUNTANT_ROOT/.env}"

# ───────────────────────────────────────────────────────────────
# 3. ENVIRONMENT CHECKS
# ───────────────────────────────────────────────────────────────

doc_read_file_value() {
  local file="$1"
  local name="$2"
  local line value
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
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
  done < "$file"
  return 1
}

doc_read_value() {
  local name="$1"
  local value=''
  case "$name" in
    JORTT_CLIENT_ID) value="${JORTT_CLIENT_ID:-}" ;;
    JORTT_CLIENT_SECRET) value="${JORTT_CLIENT_SECRET:-}" ;;
    JORTT_SCOPES) value="${JORTT_SCOPES:-}" ;;
  esac
  if [[ -n "$value" ]]; then printf '%s' "$value"; return 0; fi
  doc_read_file_value "$ENV_FILE" "$name" && return 0
  if [[ "$name" == "JORTT_SCOPES" ]]; then
    doc_read_file_value "$ACCOUNTANT_ROOT/.env.example" "$name" && return 0
  fi
  return 0
}

for variable in JORTT_CLIENT_ID JORTT_CLIENT_SECRET JORTT_SCOPES; do
  value="$(doc_read_value "$variable")"
  if [[ -n "$value" ]]; then printf '%s: set\n' "$variable"; else printf '%s: unset\n' "$variable"; fi
done
SCOPES_VALUE="$(doc_read_value JORTT_SCOPES)"
if [[ -n "$SCOPES_VALUE" ]]; then
  case " $SCOPES_VALUE " in
    *:write*) printf 'Configured scopes: contain :write\n' ;;
    *) printf 'Configured scopes: no :write\n' ;;
  esac
else
  printf 'Configured scopes: unset\n'
fi

# ───────────────────────────────────────────────────────────────
# 4. SPEC CACHE CHECK
# ───────────────────────────────────────────────────────────────

if [[ -n "${JORTT_OPENAPI_FILE:-}" ]]; then
  SPEC_PATH="$JORTT_OPENAPI_FILE"
else
  SPEC_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/jortt-cli/openapi.json"
fi
if [[ -f "$SPEC_PATH" ]]; then
  printf 'OpenAPI spec cache: present\n'
  if [[ -x "$LOCAL_CLI" ]]; then "$LOCAL_CLI" spec info; fi
else
  printf 'OpenAPI spec cache: missing\n'
fi

printf 'Mode: offline. No network calls were made.\n'
