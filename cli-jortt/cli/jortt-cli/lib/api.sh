# WHY: Auth and request handling never put credentials or bearer tokens in command arguments.
# shellcheck shell=bash
set -euo pipefail

JORTT_LAST_REQUEST=0

jortt_throttle() {
  if [ "$JORTT_LAST_REQUEST" -ne 0 ]; then
    sleep 0.11
  fi
  JORTT_LAST_REQUEST=1
}

jortt_token_cache_ready() {
  local cached_token expires now
  jortt_token_paths || return 1
  [ -f "$JORTT_TOKEN_FILE" ] || return 1
  IFS= read -r cached_token < "$JORTT_TOKEN_FILE" || return 1
  expires="$(sed -n '2p' "$JORTT_TOKEN_FILE")"
  case "$expires" in ''|*[!0-9]*) return 1 ;; esac
  now="$(date +%s)"
  if [ "$((expires - now))" -le 60 ]; then
    return 1
  fi
  JORTT_ACCESS_TOKEN="$cached_token"
  return 0
}

jortt_fetch_token() {
  jortt_require_credentials
  local encoded_scope result status body token expires_in expires temp_file
  encoded_scope="$(printf '%s' "${JORTT_SCOPES:-}" | jq -sRr '@uri')"
  jortt_throttle
  result="$(curl -sS -w $'\n%{http_code}' --config <(printf 'url = "https://app.jortt.nl/oauth-provider/oauth/token"\nuser = "%s:%s"\nheader = "Accept: application/json"\n' "$(jortt_curl_quote "$JORTT_CLIENT_ID")" "$(jortt_curl_quote "$JORTT_CLIENT_SECRET")") --data-binary "grant_type=client_credentials&scope=$encoded_scope" 2>/dev/null || true)"
  status="${result##*$'\n'}"
  body="${result%$'\n'*}"
  case "$status" in
    2??) ;;
    *)
      if [ -n "$body" ] && jq -e . >/dev/null 2>&1 <<EOF_BODY
$body
EOF_BODY
      then
        local api_message
        api_message="$(printf '%s' "$body" | jq -r '(.error_description // .message // .error // "") | if type == "string" then . else tostring end' 2>/dev/null)"
        if [ -n "$api_message" ]; then
          printf 'jortt-cli: token request failed with HTTP %s: %s\n' "$status" "$api_message" >&2
        else
          printf 'jortt-cli: token request failed with HTTP %s.\n' "$status" >&2
        fi
      else
        printf 'jortt-cli: token request failed with HTTP %s.\n' "$status" >&2
      fi
      exit 6
      ;;
  esac
  token="$(printf '%s' "$body" | jq -r '.access_token // empty' 2>/dev/null)"
  expires_in="$(printf '%s' "$body" | jq -r '.expires_in // 0' 2>/dev/null)"
  case "$expires_in" in ''|*[!0-9]*) expires_in=0 ;; esac
  [ -n "$token" ] || jortt_error 6 "Token response did not contain an access token."
  [ "$expires_in" -gt 0 ] || jortt_error 6 "Token response did not contain a valid expiry."
  expires=$(( $(date +%s) + expires_in ))
  jortt_token_paths || jortt_error 6 "Could not prepare the private token cache."
  (umask 077; mkdir -p "$JORTT_TOKEN_DIR"; chmod 700 "$JORTT_TOKEN_DIR"; temp_file="$JORTT_TOKEN_FILE.tmp.$$"; printf '%s\n%s\n' "$token" "$expires" > "$temp_file"; chmod 600 "$temp_file"; mv -f "$temp_file" "$JORTT_TOKEN_FILE") || jortt_error 6 "Could not save the private token cache."
  JORTT_ACCESS_TOKEN="$token"
}

jortt_get_token() {
  if ! jortt_token_cache_ready; then
    jortt_fetch_token
  fi
}

jortt_token_clear() {
  if ! jortt_token_paths; then
    printf 'Cached token: no\n'
    return 0
  fi
  rm -f "$JORTT_TOKEN_FILE"
  printf 'Cached token: cleared\n'
}

jortt_token_status() {
  local expires now remaining
  if ! jortt_token_paths || [ ! -f "$JORTT_TOKEN_FILE" ]; then
    printf 'Cached token: no\nRemaining minutes: 0\n'
    return 0
  fi
  expires="$(sed -n '2p' "$JORTT_TOKEN_FILE")"
  case "$expires" in ''|*[!0-9]*)
    printf 'Cached token: no\nRemaining minutes: 0\n'
    return 0
    ;;
  esac
  now="$(date +%s)"
  remaining=$(( (expires - now) / 60 ))
  if [ "$remaining" -le 0 ]; then
    printf 'Cached token: no\nRemaining minutes: 0\n'
  else
    printf 'Cached token: yes\nRemaining minutes: %s\n' "$remaining"
  fi
}

jortt_raw_request() {
  local method="$1"
  local url="$2"
  local body_data="$3"
  local headers_file result
  headers_file="${TMPDIR:-/tmp}/jortt-cli-headers-$$"
  rm -f "$headers_file"
  jortt_throttle
  if [ -n "$body_data" ]; then
    result="$(printf '%s' "$body_data" | curl -sS -D "$headers_file" -w $'\n%{http_code}' --config <(printf 'url = "%s"\nrequest = "%s"\nheader = "Authorization: Bearer %s"\nheader = "Accept: application/json"\nheader = "Content-Type: application/json"\n' "$(jortt_curl_quote "$url")" "$method" "$(jortt_curl_quote "$JORTT_ACCESS_TOKEN")") --data-binary @- 2>/dev/null || true)"
  else
    result="$(curl -sS -D "$headers_file" -w $'\n%{http_code}' --config <(printf 'url = "%s"\nrequest = "%s"\nheader = "Authorization: Bearer %s"\nheader = "Accept: application/json"\n' "$(jortt_curl_quote "$url")" "$method" "$(jortt_curl_quote "$JORTT_ACCESS_TOKEN")") 2>/dev/null || true)"
  fi
  JORTT_HTTP_STATUS="${result##*$'\n'}"
  JORTT_HTTP_BODY="${result%$'\n'*}"
  JORTT_RETRY_AFTER="$(awk 'BEGIN { IGNORECASE = 1 } /^Retry-After:/ { sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]*\r$/, ""); print; exit }' "$headers_file" 2>/dev/null || true)"
  rm -f "$headers_file"
  case "$JORTT_HTTP_STATUS" in
    [0-9][0-9][0-9]) ;;
    *) JORTT_HTTP_STATUS=000 ;;
  esac
}

# WHY: Error bodies can carry customer data, so the terminal shows codes and field
# names only while the full text goes to the ignored workspace log.
jortt_error_detail() {
  local body="$1"
  if printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$body" | jq -r '
      def codeish: type == "string" and length > 0 and length <= 64 and test("^[A-Za-z0-9_.-]+$");
      if (.errors | type) == "object" then
        (.errors | keys) as $fields
        | if ($fields | length) > 0 then "fields: \($fields | join(", "))" else empty end
      elif (.errors | type) == "array" then
        ([.errors[]? | if type == "object" then (.field // .code // empty) else empty end]
          | map(select(codeish)) | unique)
        | if length > 0 then "fields: \(join(", "))" else empty end
      elif (.error | codeish) then
        "error code: \(.error)"
      elif (.code | codeish) then
        "error code: \(.code)"
      else empty end
    ' 2>/dev/null
  fi
}

jortt_error_log_path() {
  local resolved
  resolved="$(
    umask 077
    jortt_resolve_output 'migration-workspace/logs/jortt-errors.log' 1 >/dev/null 2>&1 && printf '%s' "$JORTT_RESOLVED_OUT"
  )" || return 1
  [ -n "$resolved" ] || return 1
  printf '%s' "$resolved"
}

jortt_log_api_error() {
  local context="$1"
  local status="$2"
  local body="$3"
  local log_path
  log_path="$(jortt_error_log_path)" || return 1
  if [ ! -f "$log_path" ]; then
    (umask 077; : > "$log_path") 2>/dev/null || return 1
  fi
  chmod 600 "$log_path" 2>/dev/null || return 1
  (umask 077; printf '%s HTTP %s\n%s\n' "$context" "$status" "$body" >> "$log_path") 2>/dev/null || return 1
}

jortt_api_error_report() {
  local prefix="$1"
  local status="$2"
  local context="$3"
  local body="$4"
  local detail log_note
  detail="$(jortt_error_detail "$body")"
  log_note=''
  if [ -n "$body" ]; then
    if jortt_log_api_error "$context" "$status" "$body"; then
      log_note=' Full response logged to migration-workspace/logs/jortt-errors.log'
    else
      log_note=' Full response could not be logged.'
    fi
  fi
  if [ -n "$detail" ]; then
    printf '%sHTTP %s, %s.%s\n' "$prefix" "$status" "$detail" "$log_note" >&2
  else
    printf '%sHTTP %s.%s\n' "$prefix" "$status" "$log_note" >&2
  fi
}

jortt_retry_delay() {
  local retry_after="$1"
  local retry_index="$2"
  local retry_epoch now delay
  case "$retry_after" in
    '' ) delay=$((1 << retry_index)) ;;
    *[!0-9]*)
      retry_epoch="$(date -j -f '%a, %d %b %Y %H:%M:%S GMT' "$retry_after" '+%s' 2>/dev/null || date -d "$retry_after" '+%s' 2>/dev/null || printf '')"
      case "$retry_epoch" in
        ''|*[!0-9]*) delay=$((1 << retry_index)) ;;
        *)
          now="$(date +%s)"
          delay=$((retry_epoch - now))
          [ "$delay" -gt 0 ] || delay=1
          ;;
      esac
      ;;
    *) delay="$retry_after" ;;
  esac
  printf '%s' "$delay"
}

jortt_request() {
  local method="$1"
  local url="$2"
  local body_data="$3"
  local auth_retry=0 rate_retry=0 delay
  jortt_get_token
  while :; do
    jortt_raw_request "$method" "$url" "$body_data"
    if [ "$JORTT_HTTP_STATUS" = "401" ] && [ "$auth_retry" -eq 0 ]; then
      if jortt_token_paths; then rm -f "$JORTT_TOKEN_FILE"; fi
      JORTT_ACCESS_TOKEN=""
      jortt_fetch_token
      auth_retry=1
      continue
    fi
    if [ "$JORTT_HTTP_STATUS" = "429" ] && [ "$rate_retry" -lt 3 ]; then
      delay="$(jortt_retry_delay "$JORTT_RETRY_AFTER" "$rate_retry")"
      sleep "$delay"
      rate_retry=$((rate_retry + 1))
      continue
    fi
    break
  done
  case "$JORTT_HTTP_STATUS" in
    2??) return 0 ;;
    *)
      jortt_api_error_report 'jortt-cli: ' "$JORTT_HTTP_STATUS" "$method $url" "$JORTT_HTTP_BODY"
      return 1
      ;;
  esac
}

jortt_download() {
  local url="$1"
  local destination="$2"
  local headers_file status temp_file
  case "$url" in
    https://*) ;;
    *) jortt_error 2 "fetch accepts HTTPS links only." ;;
  esac
  temp_file="$destination.tmp.$$"
  headers_file="${TMPDIR:-/tmp}/jortt-cli-download-headers-$$"
  rm -f "$temp_file" "$headers_file"
  jortt_throttle
  status="$(curl -sS -L -D "$headers_file" -o "$temp_file" -w '%{http_code}' --config <(printf 'url = "%s"\n' "$(jortt_curl_quote "$url")") 2>/dev/null || true)"
  rm -f "$headers_file"
  case "$status" in
    2??)
      mv -f "$temp_file" "$destination" || { rm -f "$temp_file"; jortt_error 5 "Could not save the downloaded file."; }
      printf 'HTTP %s, file saved\n' "$status"
      ;;
    *)
      rm -f "$temp_file"
      printf 'jortt-cli: HTTP %s while fetching the signed link. It may have expired.\n' "$status" >&2
      return 1
      ;;
  esac
}
