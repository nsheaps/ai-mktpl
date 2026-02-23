#!/usr/bin/env bash
# Configure statusLine.command in user's settings.local.json to use this plugin's script
#
# IMPORTANT: This plugin writes to settings.local.json (NOT settings.json) to avoid
# blanking or corrupting user-managed settings. Claude Code merges settings.local.json
# on top of settings.json at runtime, so plugin-managed keys still take effect.
set -euo pipefail

# Skip configuration for agent team teammates to avoid race conditions
# on the shared settings file. Only the lead or solo sessions configure.
if [ -n "${CLAUDE_CODE_PARENT_SESSION_ID:-}" ]; then
  echo '{}'
  exit 0
fi

# Use settings.local.json to avoid overwriting user-managed settings.json
SETTINGS_FILE="$HOME/.claude/settings.local.json"
MAIN_SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/bin/statusline.sh"

# Ensure settings directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Backup both settings files to ~/.claude/backups/<date>/<filename>.<epoch>.ext
# Each backup goes to a unique path so previous backups are never overwritten.
backup_date=$(date +%Y-%m-%d)
backup_epoch=$(date +%s)
backup_dir="$HOME/.claude/backups/${backup_date}"
mkdir -p "$backup_dir"
for f in "$SETTINGS_FILE" "$MAIN_SETTINGS_FILE"; do
  if [ -f "$f" ]; then
    base=$(basename "$f" .json)
    cp "$f" "${backup_dir}/${base}.${backup_epoch}.json" 2>/dev/null || true
  fi
done

# Read current statusLine.command from settings.local.json
current_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

# Check settings.json for an existing statusLine.command (read-only, informational)
main_command=""
if [ -f "$MAIN_SETTINGS_FILE" ]; then
  main_command=$(jq -r '.statusLine.command // empty' "$MAIN_SETTINGS_FILE" 2>/dev/null || echo "")
fi

# If settings.json also has a statusLine, warn that local will take precedence
if [ -n "$main_command" ]; then
  echo "NOTE: settings.json also has statusLine.command set. settings.local.json takes precedence at runtime." >&2
fi

# --- Write helper: apply jq filter to settings file with concurrent-write detection ---
# Copies the file to a temp location, applies jq to the original, then compares the
# original against the cached copy to detect if another process modified it concurrently.
write_settings() {
  local jq_filter="$1"

  # Ensure settings file exists
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
  fi

  # Snapshot the file before modification
  local cached
  cached=$(mktemp "${SETTINGS_FILE}.cache.XXXXXX")
  cp "$SETTINGS_FILE" "$cached"

  # Apply jq transformation to a temp file
  local tmpfile
  tmpfile=$(mktemp "${SETTINGS_FILE}.tmp.XXXXXX")

  local jq_args=()
  if [ -n "${STATUSLINE_SCRIPT:-}" ]; then
    jq_args+=(--arg script "$STATUSLINE_SCRIPT")
  fi

  if ! jq ${jq_args[@]+"${jq_args[@]}"} "$jq_filter" "$SETTINGS_FILE" > "$tmpfile" 2>/dev/null; then
    rm -f "$tmpfile" "$cached"
    echo "WARNING: jq transformation failed, skipping update" >&2
    return 0
  fi

  # Validate output is non-empty valid JSON
  if [ ! -s "$tmpfile" ] || ! jq empty "$tmpfile" 2>/dev/null; then
    rm -f "$tmpfile" "$cached"
    echo "WARNING: jq produced invalid output, skipping update" >&2
    return 0
  fi

  # Check for concurrent modification: compare current file against our cached snapshot
  if ! diff -q "$SETTINGS_FILE" "$cached" >/dev/null 2>&1; then
    # File was modified by another process between our read and write.
    # Show what changed so the user can investigate.
    echo "WARNING: settings.local.json was modified by another process during this update." >&2
    echo "Diff between cached snapshot and current file:" >&2
    diff "$cached" "$SETTINGS_FILE" >&2 || true
    echo "---" >&2
    echo "Diff between cached snapshot and our intended write:" >&2
    diff "$cached" "$tmpfile" >&2 || true
    rm -f "$tmpfile" "$cached"
    echo "WARNING: Skipping write due to concurrent modification. Please retry." >&2
    return 1
  fi

  # No concurrent modification detected — apply the change
  mv "$tmpfile" "$SETTINGS_FILE"
  rm -f "$cached"
}

# Case 1: Not present in settings.local.json - set it
if [ -z "$current_command" ]; then
  write_settings '.statusLine.type = "command" | .statusLine.command = $script'
  exit 0
fi

# Case 2: Present and matches this plugin or the original statusline plugin - update silently
if [[ "$current_command" == *"plugins/statusline-iterm"* ]] || [[ "$current_command" == *"plugins/statusline/"* ]]; then
  write_settings '.statusLine.command = $script'
  exit 0
fi

# Case 3: Present in settings.local.json and doesn't match - warn and block
cat <<EOF
statusLine.command is already configured in settings.local.json with a different script:
   Current: $current_command
   This plugin wants to use: $STATUSLINE_SCRIPT

To resolve this issue, either:
1. Ask the user which statusline script they prefer
2. Manually update ~/.claude/settings.local.json to use this plugin's script
3. Disable this plugin if they want to keep their current statusline

The statusline-iterm plugin will not override your existing configuration automatically.
EOF

exit 2
