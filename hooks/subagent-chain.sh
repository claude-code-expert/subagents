#!/usr/bin/env zsh
# subagent-chain.sh — Squad Agent notification + pipeline chaining hook
# Handles both SubagentStart and SubagentStop events
# Registered automatically by install.sh
#
# NOTE: Claude Code is a TUI app — stdout/stderr from SubagentStart/Stop hooks
# are not displayed in the terminal. We use macOS notifications + sound instead.
set -uo pipefail

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
  osascript -e "display notification \"Status: RUNNING\" with title \"🚀 Squad: ${DISPLAY_NAME}\"" 2>/dev/null &
  afplay /System/Library/Sounds/Pop.aiff 2>/dev/null &

elif [ "$EVENT" = "SubagentStop" ]; then
  NEXT=""
  case "$AGENT_NAME" in
    "squad-plan")    NEXT="→ implement, then /squad-review" ;;
    "squad-review")  NEXT="→ /squad-refactor or /squad-qa" ;;
    "squad-refactor") NEXT="→ /squad-review to verify" ;;
    "squad-qa")      NEXT="→ /squad-gitops commit" ;;
    "squad-debug")   NEXT="→ implement the fix" ;;
    "squad-docs")    NEXT="Documentation updated." ;;
    "squad-gitops")  NEXT="Git artifacts generated." ;;
    "squad-audit")   NEXT="Address findings before deploy." ;;
  esac
  osascript -e "display notification \"COMPLETED ${NEXT}\" with title \"✅ Squad: ${DISPLAY_NAME}\"" 2>/dev/null &
  afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
fi

exit 0
