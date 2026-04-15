#!/usr/bin/env bash
# agent-paths.sh — Shared helper for per-agent config directory resolution
#
# Exports AGENT_CONFIG_DIR based on AGENT_NAME env var.
# All github-app plugin scripts should source this instead of
# computing the path independently.
#
# Usage: source "$(dirname "$0")/../lib/agent-paths.sh"
#   or:  source "${CLAUDE_PLUGIN_ROOT}/lib/agent-paths.sh"

AGENT_CONFIG_DIR="${HOME}/.agents/${AGENT_NAME:-_UNKNOWN}/.config"
