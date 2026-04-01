#!/bin/bash
# install.sh — Squad Agent installer (local + remote)
# Usage:
#   Local:  bash install.sh
#   Remote: curl -sL https://raw.githubusercontent.com/.../install.sh | bash
#   Remove: bash install.sh --uninstall
#   Version: bash install.sh --version
set -euo pipefail

VERSION="1.1.0"
REPO="claude-code-expert/subagents"
RELEASE_BASE="https://github.com/$REPO/releases"

AGENTS_DIR="$HOME/.claude/agents"
COMMANDS_DIR="$HOME/.claude/commands"
HOOKS_DIR="$HOME/.claude/hooks"

SQUAD_AGENTS=(
  squad-review squad-plan squad-refactor squad-qa
  squad-debug squad-docs squad-gitops squad-audit
)
SQUAD_COMMANDS=(
  squad squad-review squad-plan squad-refactor squad-qa
  squad-debug squad-docs squad-gitops squad-audit
)
SQUAD_HOOKS=(subagent-chain.sh)

# ─── Helpers ──────────────────────────────────────────

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

banner() {
  echo ""
  bold "Squad Agent Installer v$VERSION"
  echo "================================"
  echo ""
}

# ─── Uninstall ────────────────────────────────────────

uninstall() {
  banner
  yellow "Uninstalling Squad Agent..."
  echo ""

  local removed=0

  echo "Agents:"
  for name in "${SQUAD_AGENTS[@]}"; do
    local f="$AGENTS_DIR/${name}.md"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name.md"
      ((removed++)) || true
    fi
  done

  echo ""
  echo "Commands:"
  for name in "${SQUAD_COMMANDS[@]}"; do
    local f="$COMMANDS_DIR/${name}.md"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name.md"
      ((removed++)) || true
    fi
  done

  echo ""
  echo "Hooks:"
  for name in "${SQUAD_HOOKS[@]}"; do
    local f="$HOOKS_DIR/$name"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name"
      ((removed++)) || true
    fi
  done

  echo ""
  if [ "$removed" -gt 0 ]; then
    green "Uninstalled $removed file(s). Restart Claude Code."
    yellow "Note: .bak backup files were preserved."
  else
    yellow "No Squad Agent files found."
  fi
}

# ─── Detect source directory ─────────────────────────

find_source_dir() {
  local script_dir
  # If running from a local clone
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$script_dir/agents" ] && [ -d "$script_dir/commands" ]; then
      echo "$script_dir"
      return 0
    fi
  fi
  return 1
}

# ─── Remote install ───────────────────────────────────

install_remote() {
  banner
  yellow "No local source found. Downloading latest release..."
  echo ""

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  # Get latest release tag
  local latest_tag
  latest_tag=$(curl -sI "$RELEASE_BASE/latest" | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n')

  if [ -z "$latest_tag" ]; then
    red "Error: Could not determine latest release."
    red "Please install manually from: $RELEASE_BASE"
    exit 1
  fi

  green "Latest version: $latest_tag"

  local archive_url="$RELEASE_BASE/download/$latest_tag/squad-agents-${latest_tag}.tar.gz"
  echo "Downloading $archive_url ..."

  if ! curl -sL "$archive_url" -o "$tmpdir/squad.tar.gz"; then
    red "Error: Download failed."
    exit 1
  fi

  tar xzf "$tmpdir/squad.tar.gz" -C "$tmpdir"

  # Find the extracted directory
  local src
  src=$(find "$tmpdir" -name "agents" -type d -maxdepth 2 | head -1)
  if [ -z "$src" ]; then
    red "Error: Invalid archive — agents/ not found."
    exit 1
  fi
  src=$(dirname "$src")

  SOURCE_DIR="$src"
  install_local
}

# ─── Local install ────────────────────────────────────

install_local() {
  banner

  local src="${SOURCE_DIR:-}"
  if [ -z "$src" ]; then
    src=$(find_source_dir) || { install_remote; return; }
  fi

  mkdir -p "$AGENTS_DIR" "$COMMANDS_DIR" "$HOOKS_DIR"

  echo "Agents (${#SQUAD_AGENTS[@]}):"
  for f in "$src"/agents/*.md; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$AGENTS_DIR/$n" ]; then
      cp "$AGENTS_DIR/$n" "$AGENTS_DIR/${n}.bak"
      yellow "  Backed up $n"
    fi
    cp "$f" "$AGENTS_DIR/$n"
    green "  Installed $n"
  done

  echo ""
  echo "Commands (${#SQUAD_COMMANDS[@]}):"
  for f in "$src"/commands/*.md; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$COMMANDS_DIR/$n" ]; then
      cp "$COMMANDS_DIR/$n" "$COMMANDS_DIR/${n}.bak"
    fi
    cp "$f" "$COMMANDS_DIR/$n"
    local cmd_name="${n%.md}"
    green "  Installed /$cmd_name"
  done

  echo ""
  echo "Hooks:"
  for f in "$src"/hooks/*.sh; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$HOOKS_DIR/$n" ]; then
      cp "$HOOKS_DIR/$n" "$HOOKS_DIR/${n}.bak"
    fi
    cp "$f" "$HOOKS_DIR/$n"
    chmod +x "$HOOKS_DIR/$n"
    green "  Installed $n"
  done

  cat << 'DONE'

================================

  Squad Agent installed!

  Next steps:
    1. Restart Claude Code
    2. Run /agents to verify
    3. (Optional) Add SubagentStop hook to ~/.claude/settings.json:

       "hooks": {
         "SubagentStop": [{
           "matcher": "",
           "hooks": [{
             "type": "command",
             "command": "zsh ~/.claude/hooks/subagent-chain.sh"
           }]
         }]
       }

================================

  Commands:
    /squad-review          Code review
    /squad-plan <feature>  Planning + wireframes
    /squad-refactor [scope] Refactoring
    /squad-qa              Testing + QA
    /squad-debug <error>   Debugging
    /squad-docs <type>     Documentation
    /squad-gitops <type>   Commit / PR
    /squad-audit           Security audit
    /squad <member>        Universal invoke

DONE
}

# ─── Main ─────────────────────────────────────────────

case "${1:-}" in
  --uninstall|-u)
    uninstall
    ;;
  --version|-v)
    echo "Squad Agent v$VERSION"
    ;;
  --help|-h)
    echo "Usage: bash install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (no args)      Install Squad Agent"
    echo "  --uninstall    Remove Squad Agent files"
    echo "  --version      Show version"
    echo "  --help         Show this help"
    ;;
  *)
    install_local
    ;;
esac
