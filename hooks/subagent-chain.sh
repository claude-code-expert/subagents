#!/usr/bin/env zsh
# subagent-chain.sh — Squad Agent banner + pipeline chaining hook
# Handles both SubagentStart and SubagentStop events
# Registered automatically by install.sh
set -euo pipefail

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

EVENT=$(jq -r '.hook_event_name // empty' < "$TMPFILE")
AGENT_NAME=$(jq -r '.agent_type // .agent_name // empty' < "$TMPFILE")

# Only handle squad-* agents
case "$AGENT_NAME" in squad-*) ;; *) exit 0 ;; esac

DISPLAY_NAME="${AGENT_NAME#squad-}"

if [ "$EVENT" = "SubagentStart" ]; then
  echo "╭─────────────────────────────────────────╮"
  echo "│ 🚀 Squad Agent: ${DISPLAY_NAME}"
  echo "│ Status: RUNNING (independent context)"
  echo "╰─────────────────────────────────────────╯"

elif [ "$EVENT" = "SubagentStop" ]; then
  echo "╭─────────────────────────────────────────╮"
  echo "│ ✅ Squad Agent: ${DISPLAY_NAME}"
  echo "│ Status: COMPLETED (context released)"
  echo "╰─────────────────────────────────────────╯"

  case "$AGENT_NAME" in
    "squad-plan")
      echo "│ Next → implement, then /squad-review" ;;
    "squad-review")
      echo "│ Next → /squad-refactor or /squad-qa" ;;
    "squad-refactor")
      echo "│ Next → /squad-review to verify" ;;
    "squad-qa")
      echo "│ Next → /squad-gitops commit" ;;
    "squad-debug")
      echo "│ Next → implement the fix" ;;
    "squad-docs")
      echo "│ Documentation updated." ;;
    "squad-gitops")
      echo "│ Git artifacts generated." ;;
    "squad-audit")
      echo "│ Address findings before deploy." ;;
  esac
fi

exit 0
