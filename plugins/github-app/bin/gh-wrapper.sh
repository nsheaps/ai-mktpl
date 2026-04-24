#!/usr/bin/env bash
# gh-wrapper.sh — Transparent wrapper around gh that auto-sources the GitHub App token
#
# Usage: gh-wrapper.sh [gh arguments...]
#
# Checks if GH_TOKEN is set. If not, sources the token from the runtime env file
# (GITHUB_APP_ENV_FILE, defaults to ~/.agents/<AGENT_NAME>/.config/github-app-env)
# before passing all arguments through to the real gh binary.
#
# When is this needed?
#   In normal Claude Code Bash tool usage, CLAUDE_ENV_FILE already sources the
#   runtime env file before every command, so GH_TOKEN is always set. This
#   wrapper is useful for contexts where CLAUDE_ENV_FILE is NOT sourced, e.g.:
#     - Shell scripts invoked outside of Claude's Bash tool
#     - Subshells spawned by CI or cron that don't inherit the session env
#     - Manual invocations from a terminal where the session env wasn't sourced
#
# Designed as a drop-in replacement:
#   gh-wrapper.sh pr list   →  gh pr list (with token auto-sourced)
#
# To use as your default gh command in one of the above scenarios:
#   alias gh="$CLAUDE_PLUGIN_ROOT/bin/gh-wrapper.sh"
# Or prepend to PATH in your shell profile:
#   export PATH="$CLAUDE_PLUGIN_ROOT/bin:$PATH"

set -euo pipefail

if [[ -z "${GH_TOKEN:-}" ]]; then
  ENV_FILE="${GITHUB_APP_ENV_FILE:-${HOME}/.agents/${AGENT_NAME:-_UNKNOWN}/.config/github-app-env}"
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
  fi
fi

exec gh "$@"
