#!/usr/bin/env bash
# github-token-check.sh — PreToolUse hook for github-app plugin
#
# Validates the JWT-signing inputs are present in process env (populated by
# the launcher's .env chain) and refreshes the token when needed. If the env
# isn't set up (e.g. plugin not configured for this agent), defers silently.
set -euo pipefail

# shellcheck source=../../lib/agent-paths.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/agent-paths.sh"
# shellcheck source=../../lib/env-file.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/env-file.sh"

# Plugin not configured for this agent (launcher didn't source env) — defer
# silently. SessionStart will log the actual failure once if relevant.
if ! require_static_env 2>/dev/null; then
  exit 0
fi

DEBOUNCE_FILE="${GITHUB_APP_CONFIG_DIR}/last-check"
DEBOUNCE_SECONDS=300
REFRESH_THRESHOLD=45
TOKEN_FILE="${GITHUB_TOKEN_FILE:-${GITHUB_APP_CONFIG_DIR}/token}"
META_FILE="${TOKEN_FILE}.meta"

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
HOOK_EVENT="$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)"
HOOK_EVENT="${HOOK_EVENT:-PreToolUse}"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "github-app: token file missing, generating..." >&2
  if ! "${CLAUDE_PLUGIN_ROOT}/bin/token-check.sh" --sync --quiet; then
    echo "github-app: WARNING: on-demand token generation failed" >&2
    exit 0
  fi
fi

source "${CLAUDE_PLUGIN_ROOT}/lib/token-utils.sh"

BIN_DIR="${CLAUDE_PLUGIN_ROOT}/bin"

should_check() {
  local minutes
  minutes="$(get_minutes_remaining)"
  case "$minutes" in
    missing|expired) return 0 ;;
  esac
  if [[ ! -f "$DEBOUNCE_FILE" ]]; then return 0; fi
  local last now elapsed
  last="$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  elapsed=$(( now - last ))
  (( elapsed < DEBOUNCE_SECONDS )) && return 1
  return 0
}

record_check() {
  mkdir -p "$(dirname "$DEBOUNCE_FILE")"
  date +%s > "$DEBOUNCE_FILE"
}

uses_token() {
  [[ "$TOOL_NAME" != "Bash" ]] && return 1
  local cmd
  cmd="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  echo "$cmd" | grep -qEi '(^|\s|;|\||&&)(gh |git\s+(push|pull|fetch|clone|remote)|GH_TOKEN|GITHUB_TOKEN)'
}

allow_silent() {
  jq -n --arg evt "$HOOK_EVENT" '{"hookSpecificOutput":{"hookEventName":$evt,"permissionDecision":"allow"}}'
  exit 0
}

if uses_token; then
  record_check
  MINUTES="$(get_minutes_remaining)"
  case "$MINUTES" in
    missing|expired)
      echo "github-app: token is ${MINUTES}, refreshing synchronously..." >&2
      "$BIN_DIR/token-check.sh" --sync --quiet || \
        echo "github-app: ERROR: token refresh failed, command may fail" >&2
      allow_silent
      ;;
    unknown)
      allow_silent ;;
    *)
      if (( MINUTES <= REFRESH_THRESHOLD )); then
        echo "github-app: token valid, but close to expiration, refreshing in the background" >&2
        "$BIN_DIR/token-check.sh" --quiet 2>/dev/null &
        disown
      fi
      allow_silent
      ;;
  esac
else
  if ! should_check; then allow_silent; fi
  record_check
  MINUTES="$(get_minutes_remaining)"
  case "$MINUTES" in
    missing|expired)
      "$BIN_DIR/token-check.sh" --quiet 2>/dev/null &
      disown
      allow_silent ;;
    unknown) allow_silent ;;
    *)
      if (( MINUTES <= REFRESH_THRESHOLD )); then
        echo "github-app: token valid, but close to expiration, refreshing in the background" >&2
        "$BIN_DIR/token-check.sh" --quiet 2>/dev/null &
        disown
      fi
      allow_silent ;;
  esac
fi
