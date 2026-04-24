#!/usr/bin/env bash
# gh-wrapper.sh — Transparent wrapper around gh that auto-sources the GitHub App token
#
# Usage: gh-wrapper.sh [gh arguments...]
#
# Checks if GH_TOKEN is set. If not, sources the token from the runtime env file
# (GITHUB_APP_ENV_FILE, defaults to ~/.config/agent/github-app-env) before
# passing all arguments through to the real gh binary.
#
# Designed as a drop-in replacement:
#   gh-wrapper.sh pr list   →  gh pr list (with token auto-sourced)
#
# To use as your default gh command:
#   alias gh="$CLAUDE_PLUGIN_ROOT/bin/gh-wrapper.sh"
# Or add to PATH (e.g. in github-app-env):
#   export PATH="$CLAUDE_PLUGIN_ROOT/bin:$PATH"

set -euo pipefail

if [[ -z "${GH_TOKEN:-}" ]]; then
  ENV_FILE="${GITHUB_APP_ENV_FILE:-$HOME/.config/agent/github-app-env}"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
  fi
fi

exec gh "$@"
