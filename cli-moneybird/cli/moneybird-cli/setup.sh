#!/usr/bin/env bash
# WHY: Install only the reviewed official Moneybird CLI at its pinned commit.
set -euo pipefail

PINNED_COMMIT="2e34e5190f6e918b6f8a60d4f583452c7d0828aa"
CLI_HOME="${MONEYBIRD_CLI_HOME:-$HOME/.moneybird-cli}"
CLI_BIN="${MONEYBIRD_CLI_BIN:-$HOME/.local/bin}"

case "$CLI_HOME" in /*) ;; *) CLI_HOME="$PWD/$CLI_HOME" ;; esac
case "$CLI_BIN" in /*) ;; *) CLI_BIN="$PWD/$CLI_BIN" ;; esac
CLI_LINK="$CLI_BIN/moneybird-cli"
CLI_SOURCE="$CLI_HOME/moneybird-cli"
GUARD_SOURCE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/moneybird-guard"
GUARD_LINK="$CLI_BIN/moneybird-guard"

usage() {
  cat <<'USAGE'
Usage: setup.sh [--install|--check|--uninstall]

With no option, setup.sh prints the install plan and changes nothing.
USAGE
}

print_plan() {
  printf 'Install plan for the official Moneybird CLI at the pinned commit.\n'
  printf 'git clone https://github.com/moneybird/moneybird-cli.git %q\n' "$CLI_HOME"
  printf 'git -C %q checkout --detach %s\n' "$CLI_HOME" "$PINNED_COMMIT"
  printf 'mkdir -p %q\n' "$CLI_BIN"
  printf 'ln -s %q %q\n' "$CLI_SOURCE" "$CLI_LINK"
  printf 'ln -s %q %q\n' "$GUARD_SOURCE" "$GUARD_LINK"
  printf 'Run with --install to install.\n'
}

check_install() {
  local installed="no"
  local pinned="no"
  local on_path="no"
  local guard_on_path="no"
  local head=""

  if [[ -d "$CLI_HOME/.git" && -x "$CLI_SOURCE" ]]; then
    installed="yes"
    head="$(git -C "$CLI_HOME" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$head" == "$PINNED_COMMIT" ]]; then
      pinned="yes"
    fi
  fi
  if command -v moneybird-cli >/dev/null 2>&1; then
    on_path="yes"
  fi
  if command -v moneybird-guard >/dev/null 2>&1; then
    guard_on_path="yes"
  fi

  printf 'CLI source installed: %s\n' "$installed"
  printf 'Pinned commit matches: %s\n' "$pinned"
  printf 'moneybird-cli on PATH: %s\n' "$on_path"
  printf 'moneybird-guard on PATH: %s\n' "$guard_on_path"
  [[ "$installed" == "yes" && "$pinned" == "yes" && "$on_path" == "yes" && "$guard_on_path" == "yes" ]]
}

link_guard() {
  if [[ -L "$GUARD_LINK" ]]; then
    if [[ "$(readlink "$GUARD_LINK")" != "$GUARD_SOURCE" ]]; then
      printf 'Refusing to replace existing symlink: %s\n' "$GUARD_LINK" >&2
      exit 1
    fi
  elif [[ -e "$GUARD_LINK" ]]; then
    printf 'Refusing to replace existing path: %s\n' "$GUARD_LINK" >&2
    exit 1
  else
    ln -s "$GUARD_SOURCE" "$GUARD_LINK"
  fi
}

case "${1:-}" in
  "")
    print_plan
    exit 0
    ;;
  --install)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    for required in bash curl jq git; do
      if ! command -v "$required" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$required" >&2
        exit 1
      fi
    done
    if [[ -e "$CLI_HOME" ]]; then
      if [[ ! -d "$CLI_HOME/.git" ]]; then
        printf 'Refusing to replace existing path: %s\n' "$CLI_HOME" >&2
        exit 1
      fi
    else
      git clone https://github.com/moneybird/moneybird-cli.git "$CLI_HOME"
    fi
    git -C "$CLI_HOME" checkout --detach "$PINNED_COMMIT"
    mkdir -p "$CLI_BIN"
    if [[ -L "$CLI_LINK" ]]; then
      if [[ "$(readlink "$CLI_LINK")" != "$CLI_SOURCE" ]]; then
        printf 'Refusing to replace existing symlink: %s\n' "$CLI_LINK" >&2
        exit 1
      fi
    elif [[ -e "$CLI_LINK" ]]; then
      printf 'Refusing to replace existing path: %s\n' "$CLI_LINK" >&2
      exit 1
    else
      ln -s "$CLI_SOURCE" "$CLI_LINK"
    fi
    link_guard
    printf 'Installed moneybird-cli at the pinned commit and linked moneybird-guard.\n'
    printf 'Add %q to PATH if needed, then run: moneybird-cli --version\n' "$CLI_BIN"
    ;;
  --check)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    check_install
    ;;
  --uninstall)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    printf 'Removal commands, not run:\n'
    printf 'rm -f %q\n' "$CLI_LINK"
    printf 'rm -f %q\n' "$GUARD_LINK"
    printf 'rm -rf %q\n' "$CLI_HOME"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
