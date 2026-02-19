#!/usr/bin/env bash
# PostToolUse hook: Check if JSONL conversation files have oversized entries.
#
# Fires after Write/Edit tools that target .jsonl files. Checks the last
# line(s) for entries exceeding the size threshold and warns Claude.
#
# NOTE: This hook cannot retroactively modify JSONL content that's already
# been written. It can only warn Claude about the issue so future writes
# are smaller, and save the oversized content to a separate file for reference.
#
# See: https://github.com/anthropics/claude-code/issues/20470
set -euo pipefail

input="$(cat)"

# Extract the file path from tool input
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || echo "")"

# Only process .jsonl files
if [[ "$file_path" != *.jsonl ]]; then
  echo '{}'
  exit 0
fi

# Check if file exists
if [ ! -f "$file_path" ]; then
  echo '{}'
  exit 0
fi

# Threshold: 10kB (10240 bytes)
THRESHOLD="${CONTEXT_BLOAT_THRESHOLD:-10240}"

# Check the last 5 lines for oversized entries
oversized_count=0
oversized_lines=""
while IFS= read -r line; do
  line_size="${#line}"
  if [ "$line_size" -gt "$THRESHOLD" ]; then
    oversized_count=$((oversized_count + 1))
    line_kb=$((line_size / 1024))
    oversized_lines="${oversized_lines}\n  - Line ${line_size} bytes (${line_kb}kB)"
  fi
done < <(tail -5 "$file_path")

if [ "$oversized_count" -gt 0 ]; then
  # Determine temp directory
  tmp_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp"
  mkdir -p "$tmp_dir"

  cat <<EOF
{
  "systemMessage": "WARNING: JSONL file ${file_path} contains ${oversized_count} oversized entries (>${THRESHOLD} bytes) in the last 5 lines:${oversized_lines}\n\nOversized JSONL entries bloat conversation history and can cause session crashes on resume. When writing to JSONL files, keep entries compact. For large data, save to a separate file and reference the path in the JSONL entry."
}
EOF
else
  echo '{}'
fi
