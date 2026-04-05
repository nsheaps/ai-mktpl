#!/usr/bin/env bash
# PostToolUse hook: Detect large tool outputs and warn Claude to use files instead.
#
# IMPORTANT LIMITATION: PostToolUse hooks CANNOT modify or replace tool output
# for built-in tools (Read, Bash, Grep, etc.). The output is already in the
# conversation context by the time this hook fires. What this hook CAN do is
# inject a systemMessage that instructs Claude to save the content to a file
# and reference it instead of keeping the full output in working memory.
#
# For MCP tools, updatedMCPToolOutput could replace the output, but that's
# a different code path not handled here.
#
# See: https://github.com/anthropics/claude-code/issues/20470
# See: https://github.com/anthropics/claude-code/issues/18594
set -euo pipefail

input="$(cat)"

# Extract tool result size
tool_result="${input}"
tool_name="$(echo "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")"

# Get the tool_result field and measure its size
result_text="$(echo "$input" | jq -r '.tool_result // ""' 2>/dev/null || echo "")"
result_size="${#result_text}"

# Threshold: 10kB (10240 bytes)
THRESHOLD="${CONTEXT_BLOAT_THRESHOLD:-10240}"

if [ "$result_size" -gt "$THRESHOLD" ]; then
  result_kb=$(( result_size / 1024 ))

  # Determine temp directory
  tmp_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/tmp"
  mkdir -p "$tmp_dir"

  # Save the large output to a file
  timestamp="$(date +%Y%m%d-%H%M%S)"
  safe_tool_name="$(echo "$tool_name" | tr '/' '_' | tr ' ' '_')"
  output_file="${tmp_dir}/large-output-${safe_tool_name}-${timestamp}.txt"
  echo "$result_text" > "$output_file"

  # Return a systemMessage warning Claude
  cat <<EOF
{
  "systemMessage": "WARNING: The previous tool output was ${result_kb}kB (${result_size} bytes), exceeding the ${THRESHOLD}-byte threshold. Large outputs bloat context and can crash sessions. The full output has been saved to: ${output_file} — Use the Read tool to access specific parts of it rather than keeping the full content in working memory. For future commands that may produce large output, redirect to a file first (e.g., command > file.txt) and then read specific sections."
}
EOF
else
  # Under threshold — no action
  echo '{}'
fi
