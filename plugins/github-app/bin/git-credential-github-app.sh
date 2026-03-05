#!/usr/bin/env bash
# git-credential-github-app.sh — Git credential helper for GitHub App tokens
#
# Reads the current token from the shared token file and returns it
# as git credentials. Configure via:
#
#   git config --global credential.https://github.com.helper \
#     '!/path/to/git-credential-github-app.sh'
#
# The token file location defaults to ~/.config/agent/github-token
# but can be overridden via GITHUB_TOKEN_FILE environment variable.
set -euo pipefail

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.config/agent/github-token}"

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
