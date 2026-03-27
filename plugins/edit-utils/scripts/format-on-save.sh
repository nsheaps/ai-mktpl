#!/usr/bin/env bash
# format-on-save.sh — Auto-format files after Write/Edit tool calls
#
# PostToolUse hook for Write and Edit tools. Runs the project's configured
# formatter on the file that was just written or edited.
#
# Configuration is loaded from edit-utils.settings.yaml. If no config
# exists, the hook does nothing. Use the auto-config skill or manually
# create a settings file to enable formatting.
#
# Exit codes:
#   0 — always (PostToolUse hooks are advisory)

set -euo pipefail

PLUGIN_NAME="edit-utils"
LOG_PREFIX="edit-utils"

# shellcheck source=../lib/log.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"
# shellcheck source=../lib/plugin-config-read.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

input=$(cat)

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Check if plugin is enabled
if ! plugin_is_enabled; then
  exit 0
fi

# Get formatter command from config (e.g., "prettier --write")
formatter=$(plugin_get_config "formatter" "")
if [[ -z "$formatter" ]]; then
  exit 0
fi

# Get file extensions to format (one per line)
# If not configured, format all files the formatter supports
extensions=$(plugin_get_config_array "extensions" 2>/dev/null || true)

if [[ -n "$extensions" ]]; then
  # Check if file matches configured extensions
  file_ext=".${file_path##*.}"
  match=false
  while IFS= read -r ext; do
    if [[ "$file_ext" == "$ext" || "$file_ext" == ".$ext" ]]; then
      match=true
      break
    fi
  done <<< "$extensions"

  if [[ "$match" != "true" ]]; then
    exit 0
  fi
fi

# Run formatter
if [[ -f "$file_path" ]]; then
  if eval "$formatter \"$file_path\"" >/dev/null 2>&1; then
    log_info "Formatted: $file_path"
  fi
fi

exit 0
