#!/usr/bin/env bash
# git-credential-github-app.sh — Git credential helper for GitHub App tokens
#
# Reads the current token from the shared token file and returns it
# as git credentials. Configure via:
#
#   git config --global credential.https://github.com.helper \
#     '!/path/to/git-credential-github-app.sh'
#
# The token file location is read from GITHUB_TOKEN_FILE if set (the usual
# case — SessionStart exports it via CLAUDE_ENV_FILE/runtime.env). Otherwise
# we derive it from AGENT_NAME/XDG_CONFIG_HOME via lib/agent-paths.sh.
set -euo pipefail

if [[ -z "${GITHUB_TOKEN_FILE:-}" ]]; then
  # Fall back to per-agent path resolution. agent-paths.sh hard-fails if
  # AGENT_NAME / XDG_CONFIG_HOME are missing, which is the desired safe default
  # for callers that haven't gone through the SessionStart hook.
  _self="${BASH_SOURCE[0]}"
  while [ -L "$_self" ]; do _self="$(readlink -f "$_self")"; done
  # shellcheck source=../lib/agent-paths.sh
  source "$(cd "$(dirname "$_self")/.." && pwd)/lib/agent-paths.sh"
  GITHUB_TOKEN_FILE="${GITHUB_APP_CONFIG_DIR}/token"
fi

TOKEN_FILE="$GITHUB_TOKEN_FILE"

# Only respond to "get" requests
case "${1:-}" in
  get)
    if [[ -f "$TOKEN_FILE" ]]; then
      TOKEN=$(cat "$TOKEN_FILE")
      if [[ -n "$TOKEN" ]]; then
        echo "protocol=https"
        echo "host=github.com"
        echo "username=x-access-token"
        echo "password=$TOKEN"
      fi
    fi
    ;;
  store|erase)
    # No-op: token lifecycle is managed by the plugin hooks
    ;;
esac
