#!/usr/bin/env bash
# agent-paths.sh — Shared helper for per-agent config directory resolution
#
# Exports AGENT_CONFIG_DIR and GITHUB_APP_CONFIG_DIR based on AGENT_NAME.
# Refuses to run when AGENT_NAME is unset or "_UNKNOWN" so a misconfigured
# agent cannot silently write into a shared path.
#
# Usage (hooks):  source "${CLAUDE_PLUGIN_ROOT}/lib/agent-paths.sh"
# Usage (bin/):   _self="${BASH_SOURCE[0]}"; while [ -L "$_self" ]; do _self="$(readlink -f "$_self")"; done
#                 source "$(cd "$(dirname "$_self")/.." && pwd)/lib/agent-paths.sh"

[[ -n "${_AGENT_PATHS_LOADED:-}" ]] && return 0
_AGENT_PATHS_LOADED=1

# Hard-fail when AGENT_NAME is missing. This prevents bug classes where one
# agent's config writes into another agent's directory because the launcher
# didn't propagate AGENT_NAME (BUG-19 era misconfig). The fallback can be
# overridden for tooling/test contexts by setting
# GITHUB_APP_ALLOW_UNKNOWN_AGENT=1 explicitly.
if [[ -z "${AGENT_NAME:-}" || "${AGENT_NAME}" == "_UNKNOWN" ]]; then
  if [[ "${GITHUB_APP_ALLOW_UNKNOWN_AGENT:-0}" != "1" ]]; then
    echo "github-app: ERROR: AGENT_NAME is unset or _UNKNOWN — refusing to derive paths" >&2
    echo "github-app: ERROR: set AGENT_NAME in the agent launcher before invoking Claude Code," >&2
    echo "github-app: ERROR: or export GITHUB_APP_ALLOW_UNKNOWN_AGENT=1 for tooling that intentionally runs without an agent identity." >&2
    # Use return when sourced, exit when run directly.
    return 1 2>/dev/null || exit 1
  fi
  AGENT_NAME="${AGENT_NAME:-_UNKNOWN}"
fi

AGENT_CONFIG_DIR="${HOME}/.agents/${AGENT_NAME}/.config"
# All github-app plugin files live under an XDG-style subdirectory so they
# are namespaced and discoverable, mirroring the convention used by every
# app under ~/.config/.
GITHUB_APP_CONFIG_DIR="${AGENT_CONFIG_DIR}/github-app"
