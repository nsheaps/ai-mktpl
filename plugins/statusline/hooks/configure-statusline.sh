#!/usr/bin/env bash
# Configure statusLine.command in user's settings.json to use this plugin's script
set -euo pipefail

# Skip configuration for agent team teammates to avoid race conditions
# on the shared settings.json file. Only the lead or solo sessions configure.
if [ -n "${CLAUDE_CODE_PARENT_SESSION_ID:-}" ]; then
  echo '{}'
  exit 0
fi

SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh"

# Ensure settings directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# safe_write_settings: atomically update settings.json with locking + validation
# Uses mkdir as a portable POSIX lock (atomic on all filesystems).
# Uses mktemp for unique tmp files to prevent clobbering between processes.
# Validates jq output is non-empty valid JSON before replacing the original.
#
# Usage: safe_write_settings <jq_filter>
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

  # Run jq transformation to tmp file
  if ! jq --arg script "$STATUSLINE_SCRIPT" "$jq_filter" "$SETTINGS_FILE" > "$tmpfile" 2>/dev/null; then
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

# Read current statusLine.command value
current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

# Case 1: Not present - set it
if [ -z "$current_command" ]; then
  safe_write_settings '.statusLine.type = "command" | .statusLine.command = $script'
  exit 0
fi

# Case 2: Present and matches this plugin - update silently
# Match if path contains "plugins/statusline" or points to statusline.sh
if [[ "$current_command" == *"plugins/statusline"* ]] || [[ "$current_command" == *"statusline.sh"* ]]; then
  safe_write_settings '.statusLine.command = $script'
  exit 0
fi

# Case 3: Present and doesn't match - warn and block
cat <<EOF
⚠️  statusLine.command is already configured with a different script:
   Current: $current_command
   This plugin wants to use: $STATUSLINE_SCRIPT

To resolve this issue, either:
1. Ask the user which statusline script they prefer
2. Manually update ~/.claude/settings.json to use this plugin's script
3. Disable this plugin if they want to keep their current statusline

The statusline plugin will not override your existing configuration automatically.
EOF

exit 2
