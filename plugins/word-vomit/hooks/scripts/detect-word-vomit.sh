#!/usr/bin/env bash
# detect-word-vomit.sh — PostToolUse hook for Write/Edit
# Detects when a scratch/word-vomit file is written and suggests
# processing it with the exec-assist agent.
#
# Trigger paths:
#   - .claude/scratch/word-vomit*.md
#   - .claude/scratch/thoughts*.md
#   - .claude/scratch/brain-dump*.md
#   - .claude/scratch/ideas*.md
#   - Any file explicitly tagged with "<!-- word-vomit -->" marker
set -euo pipefail

input="$(cat)"

# Extract the file path from the tool input
file_path="$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [ -z "$file_path" ]; then
  echo '{}'
  exit 0
fi

# Check if file matches word-vomit patterns
is_word_vomit=false

# Pattern 1: Known scratch file patterns
case "$file_path" in
  */.claude/scratch/word-vomit*|*/.claude/scratch/thoughts*|*/.claude/scratch/brain-dump*|*/.claude/scratch/ideas*)
    is_word_vomit=true
    ;;
esac

# Pattern 2: Check for explicit marker in file content (if file exists)
if [ "$is_word_vomit" = "false" ] && [ -f "$file_path" ]; then
  if head -5 "$file_path" 2>/dev/null | grep -q '<!-- word-vomit -->' 2>/dev/null; then
    is_word_vomit=true
  fi
fi

if [ "$is_word_vomit" = "false" ]; then
  echo '{}'
  exit 0
fi

# Inject system message to trigger exec-assist processing
cat <<'EOF'
{
  "systemMessage": "A word-vomit file was just written. You should process it with the exec-assist agent to categorize and file the items. Use the Task tool with subagent_type='general-purpose' and reference the exec-assist agent, or use the word-vomit skill for the full workflow. The exec-assist agent will: (1) parse each thought into discrete items, (2) categorize them (bug, task, feature, research, decision, observation, reminder), (3) file them to the appropriate destination (GitHub issues, TaskCreate, docs), and (4) update the source file with strikethrough + links."
}
EOF
