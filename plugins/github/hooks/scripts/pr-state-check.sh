#!/usr/bin/env bash
# pr-state-check.sh — Async hook for tracking PR state changes
#
# Used by PostToolUse, SessionStart, and Stop hooks.
# Silently fetches PR state (comments, reviews, CI, body, merge status)
# and caches it locally. When state changes are detected (e.g., new review,
# CI failure, new comment), outputs a message to inform the agent.
#
# On SessionStart: establishes baseline state for all discovered PRs
# On PostToolUse: checks for changes since last fetch
# On Stop: final check and summary of any pending changes
#
# Environment:
#   HOOK_EVENT — which hook triggered this (SessionStart, PostToolUse, Stop)
#   CLAUDE_PROJECT_DIR — project directory
#   CLAUDE_PLUGIN_ROOT — plugin root for accessing libs
set -euo pipefail

PLUGIN_NAME="github"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"
source "${SCRIPT_DIR}/lib/pr-state.sh"
source "${SCRIPT_DIR}/lib/pr-discover.sh"

# --- Read config ---

pr_state_enabled="$(plugin_get_config "prStateTracking" "true")"
cache_base="$(plugin_get_config "prStateCacheDir" "")"

# --- Guards ---

if [ "$pr_state_enabled" = "false" ]; then
  # Consume stdin and exit silently
  cat > /dev/null
  exit 0
fi

if ! command -v gh &>/dev/null; then
  cat > /dev/null
  exit 0
fi

if ! command -v jq &>/dev/null; then
  cat > /dev/null
  exit 0
fi

# --- Resolve cache directory ---

if [ -z "$cache_base" ]; then
  cache_base="${HOME}/.claude/plugin-cache/github"
fi

# Add project-specific subdirectory based on project dir name
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  project_slug="$(basename "$CLAUDE_PROJECT_DIR")"
else
  project_slug="default"
fi
cache_dir="${cache_base}/${project_slug}/pr-state"
pr_state_init "$cache_dir"

# --- Consume stdin ---
# Hook input is provided via stdin; consume it to avoid broken pipe
hook_input="$(cat)"

# --- Determine hook event ---

hook_event="${HOOK_EVENT:-PostToolUse}"

# --- Discover PRs ---

log_info "Checking PR state (event: ${hook_event})"

pr_list="$(pr_discover_all 2>/dev/null)" || pr_list=""

if [ -z "$pr_list" ]; then
  log_info "No active PRs found for tracked projects"
  exit 0
fi

# --- Fetch and compare state for each PR ---

all_changes=()
pr_count=0

while IFS=' ' read -r owner repo pr_number; do
  [ -z "$owner" ] && continue
  pr_count=$((pr_count + 1))
  log_info "Checking ${owner}/${repo}#${pr_number}"

  if ! pr_state_fetch_and_compare "$owner" "$repo" "$pr_number"; then
    # Changes detected
    for change in "${PR_STATE_CHANGES[@]}"; do
      all_changes+=("$change")
    done
  fi
done <<< "$pr_list"

log_info "Checked ${pr_count} PR(s)"

# --- Output results ---

if [ ${#all_changes[@]} -eq 0 ]; then
  # No changes — silent success
  if [ "$hook_event" = "SessionStart" ]; then
    echo "github: PR state baseline established for ${pr_count} PR(s)"
  fi
  exit 0
fi

# Changes detected — build output message
{
  echo "github: PR state changes detected since last check:"
  echo ""
  for change in "${all_changes[@]}"; do
    echo "  - ${change}"
  done
  echo ""
  echo "Review these changes and determine if any action is needed."
} > /dev/stdout

# For PostToolUse and Stop hooks, exit 2 to provide feedback to Claude
# For SessionStart, exit 0 with the message in stdout
if [ "$hook_event" = "SessionStart" ]; then
  exit 0
else
  # Exit 2 signals "feedback" for Stop hooks (shown to Claude)
  # For PostToolUse, stdout is advisory (additionalContext)
  exit 0
fi
