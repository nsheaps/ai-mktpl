#!/usr/bin/env bash
# git-push-wrapper.sh — git push wrapper that auto-sources the GitHub App token
#
# Usage: git-push-wrapper.sh [git push arguments...]
#
# Checks if GH_TOKEN is set. If not, sources the token from the runtime env file
# (GITHUB_APP_ENV_FILE, defaults to ~/.config/agent/github-app-env).
#
# If a token is available after sourcing, rewrites the remote URL on-the-fly to
# use https token auth (x-access-token) without permanently modifying git config.
# Falls back to plain git push if no token is available.
#
# Exit codes mirror git push exit codes.

set -euo pipefail

if [[ -z "${GH_TOKEN:-}" ]]; then
  ENV_FILE="${GITHUB_APP_ENV_FILE:-$HOME/.config/agent/github-app-env}"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
  fi
fi

if [[ -n "${GH_TOKEN:-}" ]]; then
  # Determine the push remote (first positional arg, or 'origin')
  REMOTE="${1:-origin}"
  REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null || true)

  if [[ -n "$REMOTE_URL" ]] && [[ "$REMOTE_URL" == https://github.com/* ]]; then
    # Rewrite URL to embed token credentials without storing them in git config
    REPO_PATH="${REMOTE_URL#https://github.com/}"
    TOKEN_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO_PATH}"
    exec git push "$TOKEN_URL" "${@:2}"
  fi

  # Non-https or non-github remote — fall through to plain git push.
  # GH_TOKEN is exported so git credential helpers can also use it.
fi

# No token or non-github URL — fall back to normal git push
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "git-push-wrapper: WARNING: GH_TOKEN is not set, falling back to default git push auth" >&2
fi

exec git push "$@"
