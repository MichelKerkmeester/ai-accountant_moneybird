#!/usr/bin/env bash
# WHY: Report local Moneybird setup without opening credential files or printing secrets.
set -euo pipefail

LIVE=0
case "${1:-}" in
  "") ;;
  --live)
    [[ $# -eq 1 ]] || { printf 'Usage: doctor.sh [--live]\n' >&2; exit 2; }
    LIVE=1
    ;;
  *)
    printf 'Usage: doctor.sh [--live]\n' >&2
    exit 2
    ;;
esac

SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE" ]]; do
  SOURCE_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd -P)"
  SOURCE_LINK="$(readlink "$SOURCE")"
  case "$SOURCE_LINK" in
    /*) SOURCE="$SOURCE_LINK" ;;
    *) SOURCE="$SOURCE_DIR/$SOURCE_LINK" ;;
  esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd -P)"
SKILL_ROOT="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd -P)"
ACCOUNTANT_ROOT="$(cd -P "$SKILL_ROOT/.." >/dev/null 2>&1 && pwd -P)"
SETUP_SCRIPT="$SKILL_ROOT/cli/moneybird-cli/setup.sh"

log() {
  printf '%s\n' "$*"
}

yes_no_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    printf 'yes'
  else
    printf 'no'
  fi
}

report_env() {
  local name="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    printf '%s: set\n' "$name"
  else
    printf '%s: unset\n' "$name"
  fi
}

log "== cli-moneybird doctor (read-only) =="
for command_name in bash curl jq git; do
  log "$command_name: $(yes_no_command "$command_name")"
done

log "-- official CLI --"
if command -v moneybird-cli >/dev/null 2>&1; then
  log "moneybird-cli on PATH: yes"
else
  log "moneybird-cli on PATH: no"
fi
setup_result=""
if setup_result="$(bash "$SETUP_SCRIPT" --check 2>&1)"; then
  log "$setup_result"
else
  log "$setup_result"
fi

READER_CONFIG_DIR="${MONEYBIRD_CONFIG_DIR:-$HOME/.config/moneybird-cli}"
WRITER_CONFIG_DIR="${MONEYBIRD_WRITER_CONFIG_DIR:-$HOME/.config/moneybird-cli-writer}"
if [[ -d "$READER_CONFIG_DIR" ]]; then
  log "Reader config directory: yes"
else
  log "Reader config directory: no"
fi
if [[ -d "$WRITER_CONFIG_DIR" ]]; then
  log "Writer config directory: yes"
else
  log "Writer config directory: no"
fi

if [[ -f "$ACCOUNTANT_ROOT/.env" ]]; then
  log ".env file: yes"
else
  log ".env file: no"
fi
if [[ -f "$ACCOUNTANT_ROOT/.env.writer" ]]; then
  log ".env.writer file: yes"
else
  log ".env.writer file: no"
fi

report_env "MONEYBIRD_API_TOKEN" "${MONEYBIRD_API_TOKEN:-}"
report_env "MONEYBIRD_ADMINISTRATION_ID" "${MONEYBIRD_ADMINISTRATION_ID:-}"
report_env "MONEYBIRD_PILOT_ADMINISTRATION_ID" "${MONEYBIRD_PILOT_ADMINISTRATION_ID:-}"
report_env "MONEYBIRD_CONFIG_DIR" "${MONEYBIRD_CONFIG_DIR:-}"
report_env "MONEYBIRD_WRITER_CONFIG_DIR" "${MONEYBIRD_WRITER_CONFIG_DIR:-}"

if [[ $LIVE -eq 1 ]]; then
  if [[ -n "${MONEYBIRD_API_TOKEN:-}" ]]; then
    escaped_token="${MONEYBIRD_API_TOKEN//\\/\\\\}"
    escaped_token="${escaped_token//\"/\\\"}"
    if curl_output="$(curl --silent --show-error --config - --write-out $'\n%{http_code}' 2>/dev/null <<EOF
url = "https://moneybird.com/api/v2/administrations.json"
header = "Authorization: Bearer $escaped_token"
EOF
)"; then
      http_status="${curl_output##*$'\n'}"
      response_body="${curl_output%$'\n'*}"
      if [[ "$curl_output" == "$http_status" ]]; then
        response_body=""
      fi
      if administration_count="$(printf '%s' "$response_body" | jq -er 'if type == "array" then length else error("not an array") end' 2>/dev/null)"; then
        log "Administrations HTTP status: $http_status"
        log "Administrations count: $administration_count"
        check_id() {
          local requested_id="$1"
          local match="false"
          if [[ -n "$requested_id" ]]; then
            match="$(printf '%s' "$response_body" | jq -r --arg id "$requested_id" 'any(.[]; (.id | tostring) == $id)' 2>/dev/null || printf 'false')"
          fi
          if [[ "$match" == "true" ]]; then
            printf 'yes'
          else
            printf 'no'
          fi
        }
        log "MONEYBIRD_ADMINISTRATION_ID present: $(check_id "${MONEYBIRD_ADMINISTRATION_ID:-}")"
        log "MONEYBIRD_PILOT_ADMINISTRATION_ID present: $(check_id "${MONEYBIRD_PILOT_ADMINISTRATION_ID:-}")"
      else
        log "Administrations HTTP status: ${http_status:-unavailable}"
        log "Administrations count: unavailable"
        log "MONEYBIRD_ADMINISTRATION_ID present: no"
        log "MONEYBIRD_PILOT_ADMINISTRATION_ID present: no"
      fi
    else
      log "Administrations HTTP status: unavailable"
      log "Administrations count: unavailable"
      log "MONEYBIRD_ADMINISTRATION_ID present: no"
      log "MONEYBIRD_PILOT_ADMINISTRATION_ID present: no"
    fi
    unset escaped_token curl_output response_body
  else
    log "Administrations API check: skipped because MONEYBIRD_API_TOKEN is unset in the process environment"
  fi

fi

log "Doctor is read-only. Credential files were checked for presence only."
exit 0
