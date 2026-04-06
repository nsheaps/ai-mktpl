#!/usr/bin/env bash
# check-dependencies.sh — SessionStart hook for agentic-behavior plugin
#
# Warns if recommended companion plugins are not available.
set -euo pipefail

PLUGIN_NAME="agentic-behavior"

# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# Check if issue-management plugin is available by looking for its cache directory
PLUGINS_CACHE="${HOME}/.claude/plugins/cache"
issue_mgmt_found=false

# Search any marketplace cache for issue-management
if find "${PLUGINS_CACHE}" -maxdepth 3 -name "issue-management" -type d 2>/dev/null | grep -q .; then
  issue_mgmt_found=true
fi

if [ "$issue_mgmt_found" = false ]; then
  hook_log_always "WARNING: issue-management plugin not found. Some agentic-behavior features work best with issue-management installed. Install via: claude plugins install issue-management@ai-mktpl"
fi

hook_respond
