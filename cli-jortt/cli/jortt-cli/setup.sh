#!/usr/bin/env bash
# WHY: Print a safe manual install command and check the local runtime prerequisites.
set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CLI="$HERE/jortt-cli"
LINK=0
if [ "${1:-}" = "--link" ]; then LINK=1; shift; fi
[ "$#" -eq 0 ] || { printf 'Usage: bash setup.sh [--link]\n' >&2; exit 2; }

if [ -x "$CLI" ]; then
  printf 'CLI file: ready\n'
else
  printf 'CLI file: missing or not executable\n' >&2
  exit 1
fi
if [ -n "${BASH_VERSION:-}" ]; then printf 'bash: %s\n' "${BASH_VERSION%%(*}"; else printf 'bash: missing\n' >&2; exit 1; fi
if command -v curl >/dev/null 2>&1; then printf 'curl: available\n'; else printf 'curl: missing\n' >&2; exit 1; fi
if command -v jq >/dev/null 2>&1; then printf 'jq: available\n'; else printf 'jq: missing\n' >&2; exit 1; fi

BIN_DIR="${HOME}/.local/bin"
LINK_PATH="$BIN_DIR/jortt-cli"
printf 'Manual symlink command: ln -s "%s" "%s"\n' "$CLI" "$LINK_PATH"
if [ "$LINK" -eq 1 ]; then
  mkdir -p "$BIN_DIR"
  if [ -e "$LINK_PATH" ] || [ -L "$LINK_PATH" ]; then
    printf 'Refusing to replace an existing path: %s\n' "$LINK_PATH" >&2
    exit 1
  fi
  ln -s "$CLI" "$LINK_PATH"
  printf 'Symlink created: %s\n' "$LINK_PATH"
else
  printf 'No files changed. Pass --link to create this symlink.\n'
fi
