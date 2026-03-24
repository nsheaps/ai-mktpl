#!/usr/bin/env bash
# check-dependency-change.sh — Remind about related updates when dependency files change
#
# PostToolUse hook for Write and Edit tools. When a dependency file
# (e.g., package.json, requirements.txt) is modified, outputs a reminder
# about actions that may need to follow (e.g., updating license disclosures).
#
# Configuration is loaded from hookify.settings.yaml. If no config
# exists, the hook does nothing. Use the auto-config skill to set up.
#
# Exit codes:
#   0 — always (PostToolUse hooks are advisory)

set -euo pipefail

PLUGIN_NAME="hookify"
LOG_PREFIX="hookify"

# shellcheck source=../../lib/log.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"
# shellcheck source=../../lib/plugin-config-read.sh
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

# Get watched file patterns (one per line)
# e.g., "package.json", "requirements.txt", "Cargo.toml"
watched_files=$(plugin_get_config_array "watchFiles" 2>/dev/null || true)

if [[ -z "$watched_files" ]]; then
  exit 0
fi

# Check if the edited file matches any watched pattern
basename_file=$(basename "$file_path")
match=false
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  # Support both exact filenames and glob-like patterns
  # shellcheck disable=SC2254
  case "$basename_file" in
    $pattern) match=true; break ;;
  esac
done <<< "$watched_files"

if [[ "$match" != "true" ]]; then
  exit 0
fi

# Get the reminder message
reminder=$(plugin_get_config "reminderMessage" "")

if [[ -z "$reminder" ]]; then
  reminder="Dependency file '$basename_file' was modified. Check if related files need updating."
fi

# Get the list of files to check (optional, for more specific reminders)
check_files=$(plugin_get_config_array "checkFiles" 2>/dev/null || true)

context="$reminder"
if [[ -n "$check_files" ]]; then
  context="$context\n\nFiles to review:\n"
  while IFS= read -r cf; do
    [[ -z "$cf" ]] && continue
    context="$context- $cf\n"
  done <<< "$check_files"
fi

log_info "Dependency file changed: $basename_file"

# Output advisory context for the agent
printf '{"additionalContext":"%s"}' "$(echo -e "$context" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n')"

exit 0
