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


# --- Source shared libs from shared-lib plugin's persistent data dir ---
#
# shared-lib (declared in plugin.json `dependencies`) copies its lib/*.sh
# files into ${CLAUDE_PLUGIN_DATA}/lib on SessionStart. We resolve its data
# dir by stripping our own data-dir name and appending shared-lib's id.
# Plugin data dir IDs are deterministic: `{plugin-name}-{marketplace-name}`.
# See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
#
# When CLAUDE_PLUGIN_DATA is unset (e.g. when this script is invoked
# outside a Claude Code hook), fall back to the known path.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for a shared-lib file to appear (handles parallel
# SessionStart hooks where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[edit-utils] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "log.sh"
_wait_for_shared_lib "plugin-config-read.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/log.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
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
