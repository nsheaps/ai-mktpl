#!/usr/bin/env bash
# github-token-check.sh — PreToolUse hook for github-app plugin
#
# Runs before each tool call to check GitHub App token validity.
# Debounced and throttled to avoid excessive checks.
#
# Behavior:
#   - Bash commands using gh/git: synchronous check before execution
#     - If token valid but close to expiry: allow + background refresh
#     - If token expired: synchronous refresh, then allow
#   - All other tools: async check, never blocks
#   - Successful refreshes update the runtime env file so subsequent
#     Bash commands pick up the new token automatically
#
# Output rules:
#   - Valid tokens: silent (no output)
#   - Successful refreshes: silent
#   - Valid but refreshing: "token valid, but close to expiration, refreshing in the background"
#   - Failures: print error to stderr
set -euo pipefail

# --- Configuration ---

DEBOUNCE_FILE="${HOME}/.config/agent/github-app-last-check"
DEBOUNCE_SECONDS=30  # Don't check more often than every 30 seconds
TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.config/agent/github-token}"
META_FILE="${TOKEN_FILE}.meta"

# --- Read hook input ---

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# --- Guards ---

# Only act if the github-app plugin has been configured (credentials in env)
if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" || -z "${GITHUB_INSTALLATION_ID:-}" ]]; then
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi

# No token file means SessionStart didn't generate one — skip
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
fi

# --- Debounce/throttle ---

should_check() {
  if [[ ! -f "$DEBOUNCE_FILE" ]]; then
    return 0  # Never checked
  fi
  local last_check
  last_check=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)
  local now
  now=$(date +%s)
  local elapsed=$(( now - last_check ))
  if (( elapsed < DEBOUNCE_SECONDS )); then
    return 1  # Too soon
  fi
  return 0
}

record_check() {
  mkdir -p "$(dirname "$DEBOUNCE_FILE")"
  date +%s > "$DEBOUNCE_FILE"
}

# --- Determine if this tool uses the token ---

uses_token() {
  if [[ "$TOOL_NAME" != "Bash" ]]; then
    return 1
  fi

  local cmd
  cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

  # Check if command uses gh CLI, git push/pull/fetch/clone, or references the token
  if echo "$cmd" | grep -qEi '(^|\s|;|\||&&)(gh |git\s+(push|pull|fetch|clone|remote)|GH_TOKEN|GITHUB_TOKEN)'; then
    return 0
  fi

  return 1
}

# --- Token status check ---

# Resolve the bin/lib directories relative to this script (handles both plugin and symlink cases)
PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$PLUGIN_DIR/lib/token-utils.sh"

BIN_DIR="$PLUGIN_DIR/bin"

# --- Allow helper ---

allow_silent() {
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  exit 0
}

# --- Main logic ---

# Skip debounce if this is a token-using command (always check for those)
if uses_token; then
  # Synchronous path: must verify token before allowing
  record_check
  MINUTES=$(get_minutes_remaining)

  case "$MINUTES" in
    missing|expired)
      # Token is invalid — must refresh synchronously
      echo "github-app: token is ${MINUTES}, refreshing synchronously..." >&2
      if "$BIN_DIR/token-check.sh" --sync --quiet; then
        # Refresh succeeded — read the updated token for injection
        # The runtime env file is already updated by token-check.sh
        allow_silent
      else
        echo "github-app: ERROR: token refresh failed, command may fail" >&2
        # Allow anyway — the command will fail with a 401 which is better
        # than blocking all git/gh commands
        allow_silent
      fi
      ;;
    unknown)
      allow_silent
      ;;
    *)
      if (( MINUTES <= 30 )); then
        # Valid but close to expiry — allow + background refresh
        echo "github-app: token valid, but close to expiration, refreshing in the background" >&2
        "$BIN_DIR/token-check.sh" --quiet 2>/dev/null &
        disown
        allow_silent
      else
        # Valid and plenty of time
        allow_silent
      fi
      ;;
  esac
else
  # Non-token-using tool — debounced async check
  if ! should_check; then
    allow_silent
  fi

  record_check
  MINUTES=$(get_minutes_remaining)

  case "$MINUTES" in
    missing|expired)
      # Token expired but this tool doesn't use it — async refresh
      "$BIN_DIR/token-check.sh" --quiet 2>/dev/null &
      disown
      allow_silent
      ;;
    unknown)
      allow_silent
      ;;
    *)
      if (( MINUTES <= 30 )); then
        echo "github-app: token valid, but close to expiration, refreshing in the background" >&2
        "$BIN_DIR/token-check.sh" --quiet 2>/dev/null &
        disown
      fi
      allow_silent
      ;;
  esac
fi
