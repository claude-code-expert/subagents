#!/bin/bash
# subagent-chain.sh — Squad Agent pipeline chaining hook
# Register in ~/.claude/settings.json → hooks.SubagentStop
set -euo pipefail

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

AGENT_NAME=$(jq -r '.agent_name // empty' < "$TMPFILE")

case "$AGENT_NAME" in
  "squad-plan")
    echo "✅ Plan done. Next → implement, then /squad-review" ;;
  "squad-review")
    echo "✅ Review done. REQUEST_CHANGES → /squad-refactor. APPROVE → /squad-qa" ;;
  "squad-refactor")
    echo "✅ Refactor done. Next → /squad-review to verify, then /squad-qa" ;;
  "squad-qa")
    echo "✅ QA done. Next → /squad-gitops commit" ;;
  "squad-debug")
    echo "✅ Debug done. Implement the recommended fix." ;;
  "squad-docs")
    echo "✅ Docs done. Documentation updated." ;;
  "squad-gitops")
    echo "✅ Gitops done. Git artifacts generated." ;;
  "squad-audit")
    echo "✅ Audit done. Address findings before deployment." ;;
esac

exit 0
