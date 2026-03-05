#!/usr/bin/env bash
# github-token-init.sh — SessionStart hook for github-app plugin
#
# Generates a GitHub App installation token on session start.
# Requires GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY_PATH, and GITHUB_INSTALLATION_ID.
# Writes token to a shared file readable by gh CLI, git, and MCP server.
set -euo pipefail

PLUGIN_NAME="github-app"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# --- Guards ---

plugin_is_enabled || { echo '{}'; exit 0; }

# Check for required environment variables
GITHUB_APP_ID="${GITHUB_APP_ID:-$(plugin_get_config "github_app_id" "")}"
GITHUB_APP_PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY_PATH:-$(plugin_get_config "private_key_path" "")}"
GITHUB_INSTALLATION_ID="${GITHUB_INSTALLATION_ID:-$(plugin_get_config "github_installation_id" "")}"

if [[ -z "$GITHUB_APP_ID" || -z "$GITHUB_APP_PRIVATE_KEY_PATH" || -z "$GITHUB_INSTALLATION_ID" ]]; then
  echo "${PLUGIN_NAME}: GitHub App not configured (missing APP_ID, PRIVATE_KEY_PATH, or INSTALLATION_ID), skipping" >&2
  echo '{}'
  exit 0
fi

# Expand tilde in key path
GITHUB_APP_PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY_PATH/#\~/$HOME}"

if [[ ! -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]]; then
  echo "${PLUGIN_NAME}: PEM key not found at $GITHUB_APP_PRIVATE_KEY_PATH" >&2
  echo '{}'
  exit 0
fi

# Validate PEM file permissions
PERMS=$(stat -c '%a' "$GITHUB_APP_PRIVATE_KEY_PATH" 2>/dev/null || stat -f '%Lp' "$GITHUB_APP_PRIVATE_KEY_PATH" 2>/dev/null || echo "unknown")
if [[ "$PERMS" != "600" && "$PERMS" != "400" && "$PERMS" != "unknown" ]]; then
  echo "${PLUGIN_NAME}: WARNING: PEM key has permissions $PERMS, should be 600 or 400" >&2
fi

# --- Token generation ---

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$(plugin_get_config "token_file" "$HOME/.config/agent/github-token")}"
TOKEN_FILE="${TOKEN_FILE/#\~/$HOME}"
mkdir -p "$(dirname "$TOKEN_FILE")"

# Use the shared JWT generation script
TOKEN_OUTPUT=$("${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
  "$GITHUB_APP_ID" \
  "$GITHUB_APP_PRIVATE_KEY_PATH" \
  "$GITHUB_INSTALLATION_ID" \
  "$TOKEN_FILE" 2>&1) || {
  echo "${PLUGIN_NAME}: Token generation failed: $TOKEN_OUTPUT" >&2
  echo '{}'
  exit 0
}

echo "${PLUGIN_NAME}: $TOKEN_OUTPUT" >&2

# Export token for this session via CLAUDE_ENV_FILE
if [[ -n "${CLAUDE_ENV_FILE:-}" && -f "$TOKEN_FILE" ]]; then
  TOKEN=$(cat "$TOKEN_FILE")
  echo "export GH_TOKEN=\"$TOKEN\"" >> "$CLAUDE_ENV_FILE"
  echo "export GITHUB_TOKEN=\"$TOKEN\"" >> "$CLAUDE_ENV_FILE"
  echo "export GITHUB_TOKEN_FILE=\"$TOKEN_FILE\"" >> "$CLAUDE_ENV_FILE"
fi

echo '{}'
