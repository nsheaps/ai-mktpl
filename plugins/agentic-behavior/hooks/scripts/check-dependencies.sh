#!/usr/bin/env bash
# check-dependencies.sh — SessionStart hook for agentic-behavior plugin
#
# Warns if recommended companion plugins are not available.
set -euo pipefail

PLUGIN_NAME="agentic-behavior"

# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# No external dependency checks needed at this time.
# issue-management is a skill within this plugin, not a standalone dependency.

hook_respond
