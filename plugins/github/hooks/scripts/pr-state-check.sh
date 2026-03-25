#!/usr/bin/env bash
# pr-state-check.sh — Async hook for tracking PR state changes
#
# Used by PostToolUse, SessionStart, and Stop hooks.
# Silently fetches PR state (comments, reviews, CI, body, merge status)
# and caches it locally. When state changes are detected (e.g., new review,
# CI failure, new comment), outputs a message to inform the agent.
#
# On SessionStart: establishes baseline state for all discovered PRs
# On PostToolUse: checks for changes since last fetch (throttled)
# On Stop: final check and summary of any pending changes
#
# Environment:
#   HOOK_EVENT — which hook triggered this (SessionStart, PostToolUse, Stop)
#   CLAUDE_PROJECT_DIR — project directory
#   CLAUDE_PLUGIN_ROOT — plugin root for accessing libs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Consume stdin early ---
# Hook input is provided via stdin; consume it to avoid broken pipe
hook_input="$(cat)"

# --- Minimal config for early exit checks ---
# Source only what's needed for guards and throttle — defer heavy libs
PLUGIN_NAME="github"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

pr_state_enabled="$(plugin_get_config "prStateTracking" "true")"
if [ "$pr_state_enabled" = "false" ]; then
  exit 0
fi

if ! command -v gh &>/dev/null || ! command -v jq &>/dev/null; then
  exit 0
fi

# --- Resolve cache directory (needed for throttle check) ---

cache_base="$(plugin_get_config "prStateCacheDir" "")"
check_interval="$(plugin_get_config "prStateCheckInterval" "60")"

if [ -z "$cache_base" ]; then
  cache_base="${HOME}/.claude/plugin-cache/github"
fi

# Expand tilde in user-configured paths
cache_base="${cache_base/#\~/$HOME}"

# Add project-specific subdirectory based on project dir name
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  project_slug="$(basename "$CLAUDE_PROJECT_DIR")"
else
  project_slug="default"
fi
cache_dir="${cache_base}/${project_slug}/pr-state"

# --- Determine hook event ---

hook_event="${HOOK_EVENT:-PostToolUse}"

# --- Throttle for PostToolUse ---
# PostToolUse fires on every tool use. To avoid excessive API calls,
# enforce a cooldown period (default 60s) between checks.
# This runs BEFORE sourcing heavy libraries for performance.

if [ "$hook_event" = "PostToolUse" ]; then
  mkdir -p -m 700 "$cache_dir"
  last_check_file="${cache_dir}/.last-check"
  now="$(date +%s)"
  if [ -f "$last_check_file" ]; then
    last_check="$(cat "$last_check_file")"
    # Validate check_interval is a positive integer
    if [[ "$check_interval" =~ ^[0-9]+$ ]] && [ "$((now - last_check))" -lt "$check_interval" ]; then
      exit 0
    fi
  fi
  # Atomic timestamp write
  echo "$now" > "${last_check_file}.tmp.$$"
  mv -f "${last_check_file}.tmp.$$" "$last_check_file"
fi

# --- Source heavy libraries (only reached when we actually need to check) ---

source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"
source "${SCRIPT_DIR}/lib/pr-state.sh"
source "${SCRIPT_DIR}/lib/pr-discover.sh"

pr_state_init "$cache_dir"

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
}

exit 0
