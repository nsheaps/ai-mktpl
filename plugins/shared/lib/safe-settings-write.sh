#!/usr/bin/env bash
# safe-settings-write.sh — Atomic, concurrent-safe settings.json writer
#
# Shared library for plugins that need to modify ~/.claude/settings.json.
# Uses mkdir-based POSIX lock (portable, works on macOS where flock is absent),
# mktemp for unique tmp files, jq output validation, and atomic rename.
#
# Usage:
#   SETTINGS_FILE="$HOME/.claude/settings.json"
#   source "path/to/safe-settings-write.sh"
#   safe_write_settings '.some.key = "value"'
#
# The jq filter receives $script as --arg if STATUSLINE_SCRIPT is set,
# or you can use any valid jq expression.
#
# Requires: jq, SETTINGS_FILE must be set before sourcing.
# Note: Callers locate this lib via relative path from plugins/<name>/hooks/.
# This assumes all plugins and shared/ are siblings under the same plugins/ tree.

safe_write_settings() {
  local jq_filter="$1"
  local lockdir="${SETTINGS_FILE}.lock"
  local tmpfile
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

  # Create unique tmp file in same directory (for same-filesystem atomic rename)
  tmpfile=$(mktemp "${SETTINGS_FILE}.XXXXXX")

  # Build jq args — pass $script if STATUSLINE_SCRIPT is set
  local jq_args=()
  if [ -n "${STATUSLINE_SCRIPT:-}" ]; then
    jq_args+=(--arg script "$STATUSLINE_SCRIPT")
  fi

  # Run jq transformation to tmp file
  # Note: ${jq_args[@]+"${jq_args[@]}"} avoids "unbound variable" on bash 3.2 (macOS default) with set -u
  if ! jq ${jq_args[@]+"${jq_args[@]}"} "$jq_filter" "$SETTINGS_FILE" > "$tmpfile" 2>/dev/null; then
    rm -f "$tmpfile"
    rmdir "$lockdir" 2>/dev/null || true
    trap - EXIT
    echo "WARNING: jq transformation failed, skipping update" >&2
    return 0
  fi

  # Validate output is non-empty valid JSON
  if [ ! -s "$tmpfile" ] || ! jq empty "$tmpfile" 2>/dev/null; then
    rm -f "$tmpfile"
    rmdir "$lockdir" 2>/dev/null || true
    trap - EXIT
    echo "WARNING: jq produced invalid output, skipping update" >&2
    return 0
  fi

  # Atomic rename (same filesystem guarantees atomicity)
  mv "$tmpfile" "$SETTINGS_FILE"

  # Release lock
  rmdir "$lockdir" 2>/dev/null || true
  trap - EXIT
}
