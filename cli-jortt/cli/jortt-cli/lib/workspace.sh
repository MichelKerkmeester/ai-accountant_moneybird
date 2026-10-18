# WHY: Every saved extraction and downloaded document stays inside the ignored workspace.
# shellcheck shell=bash
set -euo pipefail

jortt_resolve_output() {
  local requested="$1"
  local create_dirs="$2"
  local workspace="$ACCOUNTANT_ROOT/migration-workspace"
  local relative component parent basename current remaining resolved
  case "$requested" in
    /*)
      case "$requested" in
        "$workspace"/*) relative="${requested#"$workspace"/}" ;;
        *) jortt_error 5 "Output path must resolve inside migration-workspace." ;;
      esac
      ;;
    *)
      relative="$requested"
      while [ "${relative#./}" != "$relative" ]; do relative="${relative#./}"; done
      case "$relative" in
        migration-workspace/*) relative="${relative#migration-workspace/}" ;;
      esac
      ;;
  esac
  case "/$relative/" in
    */../*) jortt_error 5 "Output path must not escape migration-workspace." ;;
  esac
  case "$relative" in
    ""|.|./) jortt_error 5 "Output path must name a file inside migration-workspace." ;;
  esac
  if [ -L "$workspace" ]; then
    jortt_error 5 "migration-workspace must not be a symlink."
  fi
  if [ ! -d "$workspace" ]; then
    if [ "$create_dirs" = "1" ]; then
      mkdir -p "$workspace" || jortt_error 5 "Could not create migration-workspace."
    else
      JORTT_RESOLVED_OUT="$workspace/$relative"
      return 0
    fi
  fi
  workspace="$(cd -P "$workspace" >/dev/null 2>&1 && pwd -P)" || jortt_error 5 "migration-workspace is not accessible."
  parent="${relative%/*}"
  basename="${relative##*/}"
  if [ "$parent" = "$relative" ]; then parent=""; fi
  [ -n "$basename" ] || jortt_error 5 "Output path must name a file inside migration-workspace."
  current="$workspace"
  if [ -n "$parent" ]; then
    remaining="$parent"
    while [ -n "$remaining" ]; do
      component="${remaining%%/*}"
      if [ "$remaining" = "$component" ]; then remaining=""; else remaining="${remaining#*/}"; fi
      case "$component" in
        ""|.) continue ;;
        ..) jortt_error 5 "Output path must not escape migration-workspace." ;;
      esac
      current="$current/$component"
      if [ -L "$current" ]; then
        jortt_error 5 "Output path crosses a symlink."
      fi
      if [ -e "$current" ]; then
        [ -d "$current" ] || jortt_error 5 "Output parent is not a directory."
      elif [ "$create_dirs" = "1" ]; then
        mkdir "$current" 2>/dev/null || jortt_error 5 "Could not create an output directory."
      else
        continue
      fi
      resolved="$(cd -P "$current" >/dev/null 2>&1 && pwd -P)" || jortt_error 5 "Output directory is not accessible."
      case "$resolved/" in
        "$workspace"/*/) current="$resolved" ;;
        "$workspace/" ) current="$resolved" ;;
        *) jortt_error 5 "Output path resolves outside migration-workspace." ;;
      esac
    done
  fi
  if [ -L "$current/$basename" ]; then
    jortt_error 5 "Output file must not be a symlink."
  fi
  if [ -e "$current/$basename" ] && [ -d "$current/$basename" ]; then
    jortt_error 5 "Output path names a directory."
  fi
  # shellcheck disable=SC2034
  JORTT_RESOLVED_OUT="$current/$basename"
}

jortt_write_output() {
  local destination="$1"
  local content="$2"
  local temp_file
  temp_file="$destination.tmp.$$"
  (umask 077; printf '%s' "$content" > "$temp_file") || {
    rm -f "$temp_file"
    jortt_error 5 "Could not write the output file."
  }
  mv -f "$temp_file" "$destination" || {
    rm -f "$temp_file"
    jortt_error 5 "Could not save the output file."
  }
}
