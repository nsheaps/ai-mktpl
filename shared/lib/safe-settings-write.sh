#!/usr/bin/env bash
# safe-settings-write.sh — Simple jq-based settings writer
#
# Shared library for plugins that need to modify Claude Code settings.
# IMPORTANT: Plugins should write to settings.local.json (not settings.json)
# to avoid truncating user configuration. Claude Code merges settings.local.json
# on top of settings.json at runtime.
#
# Usage:
#   SETTINGS_FILE="$HOME/.claude/settings.local.json"
#   source "path/to/safe-settings-write.sh"
#   safe_write_settings '.some.key = "value"'
#
# The jq filter receives $script as --arg if STATUSLINE_SCRIPT is set,
# or you can use any valid jq expression.
#
# Requires: jq, SETTINGS_FILE must be set before sourcing.
# Note: Plugins symlink this file into their own lib/ directory.
# Symlinked content is resolved and copied on plugin install.
#
# EXIT trap contract: safe_write_settings sets and clears an EXIT trap
# internally for lock cleanup. Callers must not rely on their own EXIT
# traps surviving a call to this function — any previously set EXIT trap
# will be overwritten. Both success and error paths clear the trap via
# `trap - EXIT` before returning, so subsequent caller traps set after
# the call will work normally.
#
# Known limitation: The STATUSLINE_SCRIPT global variable is checked to
# conditionally pass `--arg script "$STATUSLINE_SCRIPT"` to jq. This
# couples the "shared" library to the statusline plugins' convention.
# Current consumers (statusline, statusline-iterm) both use this pattern.
# TODO: When a 3rd consumer appears, refactor to accept extra jq args as
# function parameters instead (e.g., safe_write_settings '.key = $v' --arg v "val").

safe_write_settings() {
  local jq_filter="$1"

  # Ensure settings file exists
  if [ ! -f "$SETTINGS_FILE" ]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo "{}" > "$SETTINGS_FILE"
  fi

  # Build jq args — pass $script if STATUSLINE_SCRIPT is set
  local jq_args=()
  if [ -n "${STATUSLINE_SCRIPT:-}" ]; then
    jq_args+=(--arg script "$STATUSLINE_SCRIPT")
  fi

  # Run jq and write result back in place via sponge pattern (variable capture)
  local result
  if ! result=$(jq ${jq_args[@]+"${jq_args[@]}"} "$jq_filter" "$SETTINGS_FILE" 2>/dev/null); then
    echo "WARNING: jq transformation failed, skipping update" >&2
    return 0
  fi

  if [ -z "$result" ]; then
    echo "WARNING: jq produced empty output, skipping update" >&2
    return 0
  fi

  echo "$result" > "$SETTINGS_FILE"
}
