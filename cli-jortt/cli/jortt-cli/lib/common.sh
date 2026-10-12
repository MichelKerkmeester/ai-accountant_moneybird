# WHY: Shared helpers keep spec parsing and credential handling consistent.
# shellcheck shell=bash
set -euo pipefail

jortt_error() {
  local code="$1"
  shift
  printf 'jortt-cli: %s\n' "$*" >&2
  exit "$code"
}

# WHY: Agent session markers are a speed bump, not a security boundary. An agent
# can unset them, and AGENTS.md forbids agents from using --print-body at all.
# The check stops an agent that inherits its own session environment.
JORTT_AGENT_SESSION_MARKERS="CLAUDECODE AI_SESSION_CHILD ACCOUNTANT_AGENT_SESSION CODEX_SANDBOX"

jortt_print_body_blocked_by() {
  local marker value
  for marker in $JORTT_AGENT_SESSION_MARKERS; do
    value=''
    eval "value=\${$marker-}"
    if [ -n "$value" ]; then
      printf '%s' "$marker"
      return 0
    fi
  done
  return 1
}

jortt_check_print_body_allowed() {
  local marker
  if marker="$(jortt_print_body_blocked_by)"; then
    jortt_error 2 "--print-body is refused because $marker is set. Use --out and read the saved file instead."
  fi
}

jortt_need_tools() {
  command -v jq >/dev/null 2>&1 || jortt_error 2 "jq is required. Install jq and retry."
  command -v curl >/dev/null 2>&1 || jortt_error 2 "curl is required. Install curl and retry."
}

jortt_cache_path() {
  if [ -n "${XDG_CACHE_HOME:-}" ]; then
    printf '%s/jortt-cli/openapi.json\n' "${XDG_CACHE_HOME%/}"
  else
    printf '%s/.cache/jortt-cli/openapi.json\n' "$HOME"
  fi
}

jortt_stat_mtime() {
  local file="$1"
  stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null || printf '0\n'
}

jortt_spec_file() {
  if [ -n "${JORTT_OPENAPI_FILE:-}" ]; then
    printf '%s\n' "$JORTT_OPENAPI_FILE"
  else
    jortt_cache_path
  fi
}

jortt_validate_spec_file() {
  local file="$1"
  [ -f "$file" ] || jortt_error 2 "OpenAPI file not found. Run jortt-cli spec update or set JORTT_OPENAPI_FILE."
  jq -e '(.swagger == "2.0") and (.paths | type == "object")' "$file" >/dev/null 2>&1 || jortt_error 2 "OpenAPI file is not a readable Swagger 2.0 document."
}

jortt_spec_update() {
  jortt_need_tools
  if [ -n "${JORTT_OPENAPI_FILE:-}" ]; then
    jortt_validate_spec_file "$JORTT_OPENAPI_FILE"
    printf 'Using OpenAPI file: %s\n' "$JORTT_OPENAPI_FILE"
    return 0
  fi
  local cache_dir cache_file temp_file
  cache_file="$(jortt_cache_path)"
  cache_dir="${cache_file%/*}"
  mkdir -p "$cache_dir" || jortt_error 1 "Could not create the OpenAPI cache directory."
  temp_file="$cache_file.tmp.$$"
  if ! curl -fsSL --retry 0 "https://api.jortt.nl/swagger_doc" -o "$temp_file" 2>/dev/null; then
    rm -f "$temp_file"
    jortt_error 1 "Could not download the OpenAPI document. Check the network and retry."
  fi
  if ! jq -e '(.swagger == "2.0") and (.paths | type == "object")' "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    jortt_error 1 "The downloaded OpenAPI document failed validation."
  fi
  mv -f "$temp_file" "$cache_file" || jortt_error 1 "Could not save the OpenAPI cache."
  printf 'OpenAPI cache updated: %s\n' "$cache_file"
}

jortt_ensure_spec() {
  jortt_need_tools
  local file
  file="$(jortt_spec_file)"
  if [ ! -f "$file" ]; then
    if [ -n "${JORTT_OPENAPI_FILE:-}" ]; then
      jortt_error 2 "OpenAPI file not found: JORTT_OPENAPI_FILE does not resolve to a file."
    fi
    jortt_spec_update
    file="$(jortt_spec_file)"
  fi
  jortt_validate_spec_file "$file"
  JORTT_SPEC_FILE="$file"
}

jortt_spec_info() {
  jortt_need_tools
  local file mtime now age paths operations
  file="$(jortt_spec_file)"
  if [ ! -f "$file" ]; then
    printf 'OpenAPI file: missing\nPath count: unavailable\nOperation count: unavailable\nCache age: unavailable\n'
    return 0
  fi
  jortt_validate_spec_file "$file"
  paths="$(jq '.paths | length' "$file")"
  operations="$(jq '[.paths[] | to_entries[] | select(.key | IN("get", "post", "put", "patch", "delete"))] | length' "$file")"
  mtime="$(jortt_stat_mtime "$file")"
  now="$(date +%s)"
  age=$(( (now - mtime) / 60 ))
  [ "$age" -ge 0 ] || age=0
  printf 'OpenAPI file: %s\nPath count: %s\nOperation count: %s\nCache age: %s minutes\n' "$file" "$paths" "$operations" "$age"
}

jortt_read_env_value() {
  local file="$1"
  local wanted="$2"
  local line value
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$wanted"=*)
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
}

jortt_load_config() {
  local env_file example_file found
  env_file="${JORTT_ENV_FILE:-$ACCOUNTANT_ROOT/.env}"
  example_file="$ACCOUNTANT_ROOT/.env.example"
  if [ -z "${JORTT_CLIENT_ID:-}" ]; then
    found="$(jortt_read_env_value "$env_file" JORTT_CLIENT_ID)"
    [ -n "$found" ] && JORTT_CLIENT_ID="$found"
  fi
  if [ -z "${JORTT_CLIENT_SECRET:-}" ]; then
    found="$(jortt_read_env_value "$env_file" JORTT_CLIENT_SECRET)"
    [ -n "$found" ] && JORTT_CLIENT_SECRET="$found"
  fi
  if [ -z "${JORTT_SCOPES:-}" ]; then
    found="$(jortt_read_env_value "$env_file" JORTT_SCOPES)"
    JORTT_SCOPES_SOURCE='env file'
    if [ -z "$found" ]; then
      found="$(jortt_read_env_value "$example_file" JORTT_SCOPES)"
      JORTT_SCOPES_SOURCE='.env.example fallback'
    fi
    if [ -z "$found" ]; then
      JORTT_SCOPES_SOURCE='unset'
    fi
    JORTT_SCOPES="$found"
  else
    JORTT_SCOPES_SOURCE='environment'
  fi
  export JORTT_CLIENT_ID JORTT_CLIENT_SECRET JORTT_SCOPES JORTT_SCOPES_SOURCE
}

jortt_require_credentials() {
  jortt_load_config
  [ -n "${JORTT_CLIENT_ID:-}" ] || jortt_error 2 "JORTT_CLIENT_ID is unset. Set it in the environment or the configured environment file."
  [ -n "${JORTT_CLIENT_SECRET:-}" ] || jortt_error 2 "JORTT_CLIENT_SECRET is unset. Set it in the environment or the configured environment file."
  case "${JORTT_CLIENT_ID}${JORTT_CLIENT_SECRET}" in
    *$'\n'*|*$'\r'*) jortt_error 2 "Credential values must not contain line breaks." ;;
  esac
}

jortt_has_scope() {
  local wanted="$1"
  case " ${JORTT_SCOPES:-} " in
    *" $wanted "*) return 0 ;;
    *) return 1 ;;
  esac
}

jortt_check_scope() {
  local scopes="$1"
  local wanted
  jortt_load_config
  for wanted in $scopes; do
    if ! jortt_has_scope "$wanted"; then
      jortt_error 4 "Missing scope '$wanted'. The key's scopes are configured in JORTT_SCOPES."
    fi
  done
}

jortt_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    jortt_error 2 "A SHA-256 utility is required for the private token cache."
  fi
}

jortt_token_paths() {
  jortt_load_config
  [ -n "${JORTT_CLIENT_ID:-}" ] || return 1
  local key cache_root
  key="$(printf '%s\000%s' "$JORTT_CLIENT_ID" "${JORTT_SCOPES:-}" | jortt_sha256)"
  cache_root="${TMPDIR:-/tmp}/jortt-cli-$(id -u)"
  # shellcheck disable=SC2034
  JORTT_TOKEN_DIR="$cache_root"
  # shellcheck disable=SC2034
  JORTT_TOKEN_FILE="$cache_root/token-$key"
  return 0
}

jortt_curl_quote() {
  local value="$1"
  case "$value" in
    *$'\n'*|*$'\r'*) jortt_error 2 "Request values must not contain line breaks." ;;
  esac
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

jortt_operations_json() {
  local file="$1"
  jq -c '
    def rank($p):
      if ($p | test("(^|/)v3(/|$)")) then 0
      elif ($p | test("(^|/)v2(/|$)")) then 1
      elif ($p | test("(^|/)v1(/|$)")) then 3
      else 2 end;
    def suffix($p):
      if ($p | test("(^|/)v3(/|$)")) then "-v3"
      elif ($p | test("(^|/)v2(/|$)")) then "-v2"
      elif ($p | test("(^|/)v1(/|$)")) then "-v1"
      else "-legacy" end;
    [
      .paths | to_entries[] as $path
      | $path.value | to_entries[]
      | select(.key | IN("get", "post", "put", "patch", "delete")) as $entry
      | $entry.value as $op
      | {
          base_slug: ($op.operationId // ($path.key + "-" + $entry.key) | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("(^-+|-+$)"; "")),
          method: ($entry.key | ascii_upcase),
          path: $path.key,
          tag: ($op.tags[0] // "untagged"),
          scope: ([$op.security[]? | .OAuth2[]?] | unique | join(" ")),
          parameters: [$op.parameters[]? | select(.in == "path" or .in == "query") | {name: .name, in: .in, required: (.required // false), type: (.type // .schema.type // "string")}],
          body_schema: ([$op.parameters[]? | select(.in == "body") | .schema as $schema | if ($schema."$ref" // "") != "" then ($schema."$ref" | split("/") | last) elif ($schema.type // "") != "" then $schema.type else "object" end][0] // ""),
          body_required: ([$op.parameters[]? | select(.in == "body") | (.required // false)][0] // false),
          priority: rank($path.key)
        }
    ]
    | sort_by(.base_slug, .priority, .path, .method)
    | group_by(.base_slug)
    | map(. as $group | [range(0; ($group | length)) as $i | $group[$i] as $row | $row + {slug: (if $i == 0 then $row.base_slug else $row.base_slug + suffix($row.path) end)}])
    | flatten
    | sort_by(.slug, .path, .method)
    | map(del(.base_slug, .priority))
  ' "$file"
}

jortt_operation() {
  local slug="$1"
  jortt_operations_json "$JORTT_SPEC_FILE" | jq -c --arg slug "$slug" '[.[] | select(.slug == $slug)] | if length == 1 then .[0] else empty end'
}
