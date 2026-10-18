# WHY: Command handlers validate spec-backed inputs before any API request.
# shellcheck shell=bash
set -euo pipefail

jortt_validate_params() {
  local operation="$1"
  shift
  local name valid_names allowed
  valid_names="$(jq -r '[.parameters[]?.name] | unique | join(", ")' <<< "$operation")"
  for name in "$@"; do
    allowed="$(jq -r --arg name "$name" '[.parameters[]? | select(.name == $name)] | length' <<< "$operation")"
    if [ "$allowed" -eq 0 ]; then
      if [ -n "$valid_names" ]; then
        jortt_error 2 "Unknown parameter '$name'. Valid parameters: $valid_names."
      else
        jortt_error 2 "Unknown parameter '$name'. This operation has no path or query parameters."
      fi
    fi
  done
}

jortt_validate_param_value() {
  local operation="$1"
  local name="$2"
  local value="$3"
  local type enum_count enum_match
  type="$(jq -r --arg name "$name" '.parameters[] | select(.name == $name) | .type' <<< "$operation" | head -n 1)"
  case "$type" in
    integer)
      if ! jq -ne --arg value "$value" 'try (($value | tonumber) % 1 == 0) catch false' >/dev/null 2>&1; then
        jortt_error 2 "Parameter '$name' must be an integer."
      fi
      ;;
    number)
      if ! jq -ne --arg value "$value" 'try (($value | tonumber) == ($value | tonumber)) catch false' >/dev/null 2>&1; then
        jortt_error 2 "Parameter '$name' must be a number."
      fi
      ;;
    boolean)
      case "$value" in true|false) ;; *) jortt_error 2 "Parameter '$name' must be true or false." ;; esac
      ;;
  esac
  enum_count="$(jq -r --arg name "$name" '[.parameters[] | select(.name == $name) | .enum[]?] | length' <<< "$operation")"
  if [ "$enum_count" -gt 0 ]; then
    enum_match="$(jq -r --arg name "$name" --arg value "$value" '[.parameters[] | select(.name == $name) | .enum[]? | select(tostring == $value)] | length > 0' <<< "$operation")"
    [ "$enum_match" = "true" ] || jortt_error 2 "Parameter '$name' is not one of the values allowed by the spec."
  fi
}

jortt_encode() {
  printf '%s' "$1" | jq -sRr '@uri'
}

jortt_build_url() {
  local operation="$1"
  shift
  local url name value location encoded encoded_name separator
  url="https://api.jortt.nl$(jq -r '.path' <<< "$operation")"
  while [ "$#" -gt 0 ]; do
    name="$1"
    value="$2"
    shift 2
    location="$(jq -r --arg name "$name" '.parameters[] | select(.name == $name) | .in' <<< "$operation" | head -n 1)"
    encoded="$(jortt_encode "$value")"
    if [ "$location" = "path" ]; then
      url="${url//\{$name\}/$encoded}"
    else
      encoded_name="$(jortt_encode "$name")"
      case "$url" in *\?*) separator='&' ;; *) separator='?' ;; esac
      url="$url$separator$encoded_name=$encoded"
    fi
  done
  case "$url" in
    *'{'*|*'}'*) jortt_error 2 "A required path parameter is missing." ;;
  esac
  printf '%s' "$url"
}

jortt_check_required_params() {
  local operation="$1"
  shift
  local provided="$*"
  local required name
  while IFS= read -r required; do
    [ -n "$required" ] || continue
    case " $provided " in
      *" $required "*) ;;
      *) jortt_error 2 "Required parameter '$required' is missing." ;;
    esac
  done <<EOF_REQUIRED
$(jq -r '.parameters[]? | select(.required == true) | .name' <<< "$operation")
EOF_REQUIRED
}

# WHY: Jortt is read-only for every agent, so a non-GET operation is refused before any
# token request. The scope check follows for the reads that remain.
jortt_check_read_gate() {
  local operation="$1"
  local slug="$2"
  if [ "$(jq -r '.method' <<< "$operation")" != "GET" ]; then
    jortt_error 3 "Write operation '$slug' is refused. Jortt is read-only and jortt-cli sends GET requests only."
  fi
  jortt_check_scope "$(jq -r '.scope' <<< "$operation")"
}

jortt_page_all() {
  local method="$1"
  local url="$2"
  local accumulated='[]'
  local next data current_path current_dir
  while :; do
    if ! jortt_request "$method" "$url"; then return 1; fi
    if ! printf '%s' "$JORTT_HTTP_BODY" | jq -e '.data | type == "array"' >/dev/null 2>&1; then
      jortt_error 1 "The response did not contain a data array for --all."
    fi
    data="$(printf '%s' "$JORTT_HTTP_BODY" | jq -c '.data')"
    accumulated="$(jq -cn --argjson left "$accumulated" --argjson right "$data" '$left + $right')"
    next="$(printf '%s' "$JORTT_HTTP_BODY" | jq -r '._links.next.href // empty' 2>/dev/null)"
    [ -n "$next" ] || break
    case "$next" in
      https://api.jortt.nl/*) url="$next" ;;
      http://api.jortt.nl/*) jortt_error 1 "The API returned a non-HTTPS next link." ;;
      https://*|http://*) jortt_error 1 "The API returned a next link outside api.jortt.nl." ;;
      /*) url="https://api.jortt.nl$next" ;;
      \?*) url="${url%%\?*}$next" ;;
      *)
        current_path="${url#https://api.jortt.nl}"
        current_path="${current_path%%\?*}"
        current_dir="${current_path%/*}"
        if [ "$current_dir" = "$current_path" ]; then current_dir=""; fi
        url="https://api.jortt.nl$current_dir/$next"
        ;;
    esac
  done
  JORTT_RESULT_BODY="$accumulated"
}

jortt_body_summary() {
  local body="$1"
  printf '%s' "$body" | jq -r '
    if type == "array" then
      "items: \(length)"
    elif type == "object" then
      ([to_entries[] | select(.value | type == "array") | "\(.key) items: \(.value | length)"]
        + [if (keys | length) == 0 then "top-level keys: none" else "top-level keys: \(keys | join(", "))" end]
        | join(", "))
    else
      "top-level type: \(type)"
    end
  ' 2>/dev/null || printf 'top-level keys: unavailable'
}

jortt_print_or_save() {
  local body="$1"
  local status="$2"
  local out_path="$3"
  local print_body="$4"
  if [ -n "$out_path" ]; then
    jortt_write_output "$out_path" "$body"
    printf 'HTTP %s, %s\n' "$status" "$(jortt_body_summary "$body")"
    return 0
  fi
  if [ "$print_body" = "1" ]; then
    if printf '%s' "$body" | jq . 2>/dev/null; then
      :
    else
      printf '%s\n' "$body"
    fi
    return 0
  fi
  printf 'HTTP %s, %s\n' "$status" "$(jortt_body_summary "$body")"
}

jortt_cmd_ops() {
  local tag='' json=0 arg operations
  while [ "$#" -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
      --tag)
        [ "$#" -gt 0 ] || jortt_error 2 "--tag requires a value."
        tag="$1"
        shift
        ;;
      --json) json=1 ;;
      *) jortt_error 2 "Unknown ops option: $arg" ;;
    esac
  done
  jortt_ensure_spec
  operations="$(jortt_operations_json "$JORTT_SPEC_FILE" | jq -c --arg tag "$tag" '[.[] | select($tag == "" or .tag == $tag) | {slug, method, path, scope, tag}]')"
  if [ "$json" = "1" ]; then
    printf '%s\n' "$operations" | jq .
  else
    printf '%-55s %-7s %-52s %s\n' 'SLUG' 'METHOD' 'PATH' 'SCOPE'
    printf '%s\n' "$operations" | jq -r '.[] | [.slug, .method, .path, .scope] | @tsv' | while IFS="$(printf '\t')" read -r slug method path scope; do
      printf '%-55s %-7s %-52s %s\n' "$slug" "$method" "$path" "$scope"
    done
  fi
}

jortt_cmd_describe() {
  local slug="$1"
  local operation path_names query_names example scope param
  jortt_ensure_spec
  operation="$(jortt_operation "$slug")"
  [ -n "$operation" ] || jortt_error 2 "Unknown operation slug: $slug. Run jortt-cli ops to list operations."
  path_names="$(jq -r '[.parameters[]? | select(.in == "path") | .name] | if length == 0 then "none" else join(", ") end' <<< "$operation")"
  query_names="$(jq -r '[.parameters[]? | select(.in == "query") | .name] | if length == 0 then "none" else join(", ") end' <<< "$operation")"
  scope="$(jq -r '.scope | if . == "" then "none" else . end' <<< "$operation")"
  example="jortt-cli call $slug"
  while IFS= read -r param; do
    [ -n "$param" ] || continue
    example="$example --$param VALUE"
  done <<EOF_PATHS
$(jq -r '.parameters[]? | select(.in == "path" and .required == true) | .name' <<< "$operation")
EOF_PATHS
  while IFS= read -r param; do
    [ -n "$param" ] || continue
    example="$example --$param VALUE"
  done <<EOF_QUERIES
$(jq -r '.parameters[]? | select(.in == "query" and .required == true) | .name' <<< "$operation")
EOF_QUERIES
  printf 'Slug: %s\nMethod: %s\nPath: %s\nScope: %s\nPath params: %s\nQuery params: %s\nExample: %s\n' \
    "$slug" "$(jq -r '.method' <<< "$operation")" "$(jq -r '.path' <<< "$operation")" "$scope" "$path_names" "$query_names" "$example"
}

jortt_cmd_call() {
  local slug="$1"
  shift
  local operation method all=0 print_body=0 dry_run=0 out='' names=() values=() url
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) all=1; shift ;;
      --print-body) print_body=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      --out)
        [ "$#" -ge 2 ] || jortt_error 2 "--out requires a file path."
        [ -z "$out" ] || jortt_error 2 "Use --out once."
        out="$2"; shift 2
        ;;
      --*)
        local name="${1#--}"
        [ "$#" -ge 2 ] || jortt_error 2 "Parameter --$name requires a value."
        names[${#names[@]}]="$name"
        values[${#values[@]}]="$2"
        shift 2
        ;;
      *) jortt_error 2 "Unexpected argument: $1" ;;
    esac
  done
  if [ "$print_body" = "1" ]; then
    jortt_check_print_body_allowed
  fi
  jortt_ensure_spec
  operation="$(jortt_operation "$slug")"
  [ -n "$operation" ] || jortt_error 2 "Unknown operation slug: $slug. Run jortt-cli ops to list operations."
  if [ "${#names[@]}" -gt 0 ]; then
    local index
    jortt_validate_params "$operation" "${names[@]}"
    for ((index=0; index<${#names[@]}; index++)); do
      jortt_validate_param_value "$operation" "${names[$index]}" "${values[$index]}"
    done
    jortt_check_required_params "$operation" "${names[@]}"
  else
    jortt_check_required_params "$operation"
  fi
  if [ -n "$out" ]; then
    jortt_resolve_output "$out" 0
    out="$JORTT_RESOLVED_OUT"
  fi
  jortt_check_read_gate "$operation" "$slug"
  method="$(jq -r '.method' <<< "$operation")"
  if [ -n "$out" ] && [ "$dry_run" != "1" ]; then
    jortt_resolve_output "$out" 1
    out="$JORTT_RESOLVED_OUT"
  fi
  local paired=()
  local i
  for ((i=0; i<${#names[@]}; i++)); do
    paired[${#paired[@]}]="${names[$i]}"
    paired[${#paired[@]}]="${values[$i]}"
  done
  if [ "${#paired[@]}" -gt 0 ]; then
    url="$(jortt_build_url "$operation" "${paired[@]}")"
  else
    url="$(jortt_build_url "$operation")"
  fi
  if [ "$dry_run" = "1" ]; then
    printf '%s %s\n' "$method" "$url"
    return 0
  fi
  if [ "$all" = "1" ]; then
    jortt_page_all "$method" "$url" || return 1
    jortt_print_or_save "$JORTT_RESULT_BODY" "$JORTT_HTTP_STATUS" "$out" "$print_body"
  else
    jortt_request "$method" "$url" || return 1
    jortt_print_or_save "$JORTT_HTTP_BODY" "$JORTT_HTTP_STATUS" "$out" "$print_body"
  fi
}

jortt_cmd_whoami() {
  local slug='get-the-organization-associated-with-the-api-credentials'
  local operation
  jortt_ensure_spec
  operation="$(jortt_operation "$slug")"
  [ -n "$operation" ] || jortt_error 2 "The organizations/me operation is missing from the OpenAPI file."
  jortt_check_scope "$(jq -r '.scope' <<< "$operation")"
  jortt_request GET 'https://api.jortt.nl/organizations/me' || return 1
  printf 'HTTP status: %s\n' "$JORTT_HTTP_STATUS"
  printf 'Top-level field names: %s\n' "$(printf '%s' "$JORTT_HTTP_BODY" | jq -r 'if type == "object" then keys | join(", ") else "none" end' 2>/dev/null)"
}

jortt_cmd_fetch() {
  local url="$1"
  shift
  local out=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --out)
        [ "$#" -ge 2 ] || jortt_error 2 "--out requires a file path."
        out="$2"; shift 2
        ;;
      *) jortt_error 2 "Unknown fetch option: $1" ;;
    esac
  done
  [ -n "$out" ] || jortt_error 2 "fetch requires --out FILE."
  jortt_resolve_output "$out" 1
  jortt_download "$url" "$JORTT_RESOLVED_OUT"
}
