#!/usr/bin/env bash
# safe-settings-write.sh — Atomic, concurrent-safe settings writer
#
# Shared library for plugins that need to modify Claude Code settings.
# IMPORTANT: Plugins should write to settings.local.json (not settings.json)
# to avoid truncating user configuration. Claude Code merges settings.local.json
# on top of settings.json at runtime.
#
# Uses mkdir-based POSIX lock (portable, works on macOS where flock is absent),
# jq output validation via variable capture, and direct file write.
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
  local lockdir="${SETTINGS_FILE}.lock"
  local retries=0

  # Acquire lock via mkdir (atomic on POSIX)
  while ! mkdir "$lockdir" 2>/dev/null; do
    retries=$((retries + 1))
    if [ "$retries" -ge 30 ]; then
      # Stale lock detection: if lock is older than 10 seconds, remove it
      if [ -d "$lockdir" ]; then
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -f %m "$lockdir" 2>/dev/null || stat -c %Y "$lockdir" 2>/dev/null || echo "0") ))
        if [ "$lock_age" -gt 10 ]; then
          rmdir "$lockdir" 2>/dev/null || true
          retries=0
          continue
        fi
      fi
      echo "WARNING: Could not acquire lock on settings.json after 3s, skipping update" >&2
      return 0
    fi
    sleep 0.1
  done

  # Ensure lock is released on exit (even on error/signal)
  trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT

  # Ensure settings file exists (inside lock to prevent race)
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
  fi

  # Build jq args — pass $script if STATUSLINE_SCRIPT is set
  local jq_args=()
  if [ -n "${STATUSLINE_SCRIPT:-}" ]; then
    jq_args+=(--arg script "$STATUSLINE_SCRIPT")
  fi

  # Run jq transformation into a variable (no temp file)
  # Note: ${jq_args[@]+"${jq_args[@]}"} avoids "unbound variable" on bash 3.2 (macOS default) with set -u
  local result
  if ! result=$(jq ${jq_args[@]+"${jq_args[@]}"} "$jq_filter" "$SETTINGS_FILE" 2>/dev/null); then
    rmdir "$lockdir" 2>/dev/null || true
    trap - EXIT
    echo "WARNING: jq transformation failed, skipping update" >&2
    return 0
  fi

  # Validate output is non-empty valid JSON
  if [ -z "$result" ] || ! echo "$result" | jq empty 2>/dev/null; then
    rmdir "$lockdir" 2>/dev/null || true
    trap - EXIT
    echo "WARNING: jq produced invalid output, skipping update" >&2
    return 0
  fi

  # Write directly to the settings file (no temp file)
  echo "$result" > "$SETTINGS_FILE"

  # Release lock
  rmdir "$lockdir" 2>/dev/null || true
  trap - EXIT
}
