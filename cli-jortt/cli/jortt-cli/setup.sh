#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────
# COMPONENT: JORTT CLI SETUP
# ───────────────────────────────────────────────────────────────
# Print a safe manual install command and check the local runtime
# prerequisites.
#
# Usage: bash setup.sh
#
# Exit Codes:
#   0 - Prerequisites present, symlink command printed
#   1 - Missing CLI file or runtime prerequisite
#   2 - Usage error

set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CLI="$HERE/jortt-cli"
[[ "$#" -eq 0 ]] || { printf 'Usage: bash setup.sh\n' >&2; exit 2; }

if [[ -x "$CLI" ]]; then
  printf 'CLI file: ready\n'
else
  printf 'CLI file: missing or not executable\n' >&2
  exit 1
fi
if [[ -n "${BASH_VERSION:-}" ]]; then printf 'bash: %s\n' "${BASH_VERSION%%(*}"; else printf 'bash: missing\n' >&2; exit 1; fi
if command -v curl >/dev/null 2>&1; then printf 'curl: available\n'; else printf 'curl: missing\n' >&2; exit 1; fi
if command -v jq >/dev/null 2>&1; then printf 'jq: available\n'; else printf 'jq: missing\n' >&2; exit 1; fi

BIN_DIR="${HOME}/.local/bin"
LINK_PATH="$BIN_DIR/jortt-cli"
printf 'Manual symlink command: ln -s "%s" "%s"\n' "$CLI" "$LINK_PATH"
printf 'No files changed. Run the symlink command yourself to install the link.\n'
