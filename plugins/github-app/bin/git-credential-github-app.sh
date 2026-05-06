#!/usr/bin/env bash
# git-credential-github-app.sh — Git credential helper for GitHub App tokens
#
# Reads the current token from the shared token file and returns it
# as git credentials. Configure via:
#
#   git config --global credential.https://github.com.helper \
#     '!/path/to/git-credential-github-app.sh'
#
# The token file location defaults to ~/.agents/${AGENT_NAME}/.config/github-token
# but can be overridden via GITHUB_TOKEN_FILE environment variable.
set -euo pipefail

# shellcheck source=../lib/agent-paths.sh
_self="${BASH_SOURCE[0]}"
while [ -L "$_self" ]; do _self="$(readlink -f "$_self")"; done
# git invokes this helper in subprocesses where AGENT_NAME may already be
# exported. If GITHUB_TOKEN_FILE is explicitly set (typical when SessionStart
# has run), we skip the agent-name guard since the token path is already
# resolved.
if [[ -n "${GITHUB_TOKEN_FILE:-}" ]]; then
  GITHUB_APP_ALLOW_UNKNOWN_AGENT=1
fi
source "$(cd "$(dirname "$_self")/.." && pwd)/lib/agent-paths.sh"

TOKEN_FILE="${GITHUB_TOKEN_FILE:-${GITHUB_APP_CONFIG_DIR}/token}"

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
