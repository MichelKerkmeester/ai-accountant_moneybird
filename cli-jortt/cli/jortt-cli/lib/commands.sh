# WHY: Command handlers validate spec-backed inputs before any API request.
# shellcheck shell=bash
set -euo pipefail

jortt_json_param_names() {
  jq -r '.parameters[]?.name' <<< "$1"
}

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
  type="$(jq -r --arg name "$name" '.parameters[] | select(.name == $name) | (.type // (.schema // {} | .type) // "string")' <<< "$operation" | head -n 1)"
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

jortt_required_scope_from_op() {
  jq -r '.scope' <<< "$1"
}

jortt_check_write_gate() {
  local operation="$1"
  local slug="$2"
  local allow_write="$3"
  local method scope
  method="$(jq -r '.method' <<< "$operation")"
  scope="$(jortt_required_scope_from_op "$operation")"
  if [ "$method" != "GET" ] && [ "$allow_write" != "1" ]; then
    jortt_error 3 "Write operation '$slug' requires --allow-write."
  fi
  jortt_check_scope "$scope"
}

jortt_pretty_body() {
  local body="$1"
  if [ -z "$body" ]; then
    printf 'Body: none\n'
  elif printf '%s' "$body" | jq . 2>/dev/null; then
    :
  else
    printf '%s\n' "$body"
  fi
}

jortt_page_all() {
  local method="$1"
  local url="$2"
  local body="$3"
  local accumulated='[]'
  local next data current_path current_dir
  while :; do
    if ! jortt_request "$method" "$url" "$body"; then return 1; fi
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
    method="GET"
    body=""
  done
  JORTT_RESULT_BODY="$accumulated"
}

jortt_print_or_save() {
  local body="$1"
  local status="$2"
  local raw="$3"
  local out_path="$4"
  local summary
  if [ -n "$out_path" ]; then
    jortt_write_output "$out_path" "$body"
    summary="$(printf '%s' "$body" | jq -r '
      if type == "array" then "items: \(length)"
      elif (.data | type) == "array" then "items: \(.data | length)"
      elif type == "object" then "top-level keys: \(keys | join(", "))"
      else "top-level type: \(type)" end
    ' 2>/dev/null || printf 'top-level keys: unavailable')"
    printf 'HTTP %s, %s\n' "$status" "$summary"
    return 0
  fi
  if [ "$raw" = "1" ]; then
    printf '%s\n' "$body"
  elif printf '%s' "$body" | jq . 2>/dev/null; then
    :
  else
    printf '%s\n' "$body"
  fi
}

jortt_cmd_ops() {
  local tag='' writes=0 json=0 arg operations
  while [ "$#" -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
      --tag)
        [ "$#" -gt 0 ] || jortt_error 2 "--tag requires a value."
        tag="$1"
        shift
        ;;
      --writes) writes=1 ;;
      --json) json=1 ;;
      *) jortt_error 2 "Unknown ops option: $arg" ;;
    esac
  done
  jortt_ensure_spec
  operations="$(jortt_operations_json "$JORTT_SPEC_FILE" | jq -c --arg tag "$tag" --argjson writes "$writes" '[.[] | select(($tag == "" or .tag == $tag) and ($writes == 0 or .method != "GET")) | {slug, method, path, scope, tag}]')"
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
  local operation path_names query_names example body_schema scope param
  jortt_ensure_spec
  operation="$(jortt_operation "$slug")"
  [ -n "$operation" ] || jortt_error 2 "Unknown operation slug: $slug. Run jortt-cli ops to list operations."
  path_names="$(jq -r '[.parameters[]? | select(.in == "path") | .name] | if length == 0 then "none" else join(", ") end' <<< "$operation")"
  query_names="$(jq -r '[.parameters[]? | select(.in == "query") | .name] | if length == 0 then "none" else join(", ") end' <<< "$operation")"
  body_schema="$(jq -r '.body_schema | if . == "" then "none" else . end' <<< "$operation")"
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
  if [ "$body_schema" != "none" ]; then example="$example --data '{}'"; fi
  printf 'Slug: %s\nMethod: %s\nPath: %s\nScope: %s\nPath params: %s\nQuery params: %s\nBody schema: %s\nExample: %s\n' \
    "$slug" "$(jq -r '.method' <<< "$operation")" "$(jq -r '.path' <<< "$operation")" "$scope" "$path_names" "$query_names" "$body_schema" "$example"
}

jortt_cmd_call() {
  local slug="$1"
  shift
  local operation method path scope body_data data_set=0 all=0 raw=0 dry_run=0 allow_write=0 out='' names=() values=() url summary
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --data)
        [ "$#" -ge 2 ] || jortt_error 2 "--data requires JSON."
        [ "$data_set" -eq 0 ] || jortt_error 2 "Use only one of --data and --data-file."
        body_data="$2"; data_set=1; shift 2
        ;;
      --data-file)
        [ "$#" -ge 2 ] || jortt_error 2 "--data-file requires a path."
        [ "$data_set" -eq 0 ] || jortt_error 2 "Use only one of --data and --data-file."
        [ -f "$2" ] || jortt_error 2 "Data file not found."
        body_data="$(cat "$2")"; data_set=1; shift 2
        ;;
      --all) all=1; shift ;;
      --raw) raw=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      --allow-write) allow_write=1; shift ;;
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
    jortt_validate_params "$operation"
    jortt_check_required_params "$operation"
  fi
  if [ -n "$out" ]; then
    jortt_resolve_output "$out" 0
    out="$JORTT_RESOLVED_OUT"
  fi
  jortt_check_write_gate "$operation" "$slug" "$allow_write"
  method="$(jq -r '.method' <<< "$operation")"
  path="$(jq -r '.path' <<< "$operation")"
  scope="$(jq -r '.scope' <<< "$operation")"
  if [ "$data_set" -eq 1 ]; then
    printf '%s' "$body_data" | jq -e . >/dev/null 2>&1 || jortt_error 2 "Request body must be valid JSON."
  else
    body_data=''
    if [ "$(jq -r '.body_required' <<< "$operation")" = "true" ]; then
      jortt_error 2 "This operation requires --data or --data-file."
    fi
  fi
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
    jortt_pretty_body "$body_data"
    return 0
  fi
  if [ "$all" = "1" ]; then
    [ "$method" = "GET" ] || jortt_error 2 "--all is supported for GET operations only."
    jortt_page_all "$method" "$url" "$body_data" || return 1
    jortt_print_or_save "$JORTT_RESULT_BODY" "$JORTT_HTTP_STATUS" "$raw" "$out"
  else
    jortt_request "$method" "$url" "$body_data" || return 1
    jortt_print_or_save "$JORTT_HTTP_BODY" "$JORTT_HTTP_STATUS" "$raw" "$out"
  fi
}

jortt_cmd_get() {
  local path="$1"
  shift
  local all=0 raw=0 out='' url separator pair name value encoded
  local pairs=()
  case "$path" in
    http://*|https://*|*\?*|*\#*) jortt_error 2 "get accepts an API path without a host, query string or fragment." ;;
  esac
  case "/$path/" in */../*) jortt_error 2 "get path must not contain parent-directory segments." ;; esac
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) all=1; shift ;;
      --raw) raw=1; shift ;;
      --out)
        [ "$#" -ge 2 ] || jortt_error 2 "--out requires a file path."
        out="$2"; shift 2
        ;;
      *)
        pair="$1"; shift
        case "$pair" in *=*) name="${pair%%=*}"; value="${pair#*=}" ;; *) jortt_error 2 "GET parameters must use name=value." ;; esac
        [ -n "$name" ] || jortt_error 2 "GET parameter names cannot be empty."
        pairs[${#pairs[@]}]="$name"
        pairs[${#pairs[@]}]="$value"
        ;;
    esac
  done
  if [ -n "$out" ]; then
    JORTT_CREATE_WORKSPACE=1
    jortt_resolve_output "$out" "$JORTT_CREATE_WORKSPACE"
    out="$JORTT_RESOLVED_OUT"
  fi
  url="https://api.jortt.nl/${path#/}"
  separator='?'
  while [ "${#pairs[@]}" -gt 0 ]; do
    name="${pairs[0]}"; value="${pairs[1]}"
    pairs=("${pairs[@]:2}")
    encoded="$(jortt_encode "$name")=$(jortt_encode "$value")"
    url="$url$separator$encoded"
    separator='&'
  done
  if [ "$all" = "1" ]; then
    jortt_page_all GET "$url" '' || return 1
    jortt_print_or_save "$JORTT_RESULT_BODY" "$JORTT_HTTP_STATUS" "$raw" "$out"
  else
    jortt_request GET "$url" '' || return 1
    jortt_print_or_save "$JORTT_HTTP_BODY" "$JORTT_HTTP_STATUS" "$raw" "$out"
  fi
}

jortt_cmd_whoami() {
  local slug='get-the-organization-associated-with-the-api-credentials'
  local operation
  jortt_ensure_spec
  operation="$(jortt_operation "$slug")"
  [ -n "$operation" ] || jortt_error 2 "The organizations/me operation is missing from the OpenAPI file."
  jortt_check_scope "$(jq -r '.scope' <<< "$operation")"
  jortt_request GET 'https://api.jortt.nl/organizations/me' '' || return 1
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
