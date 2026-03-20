#!/usr/bin/env bash
# Check if gs-stack-status is installed and print install instructions if not

PLUGIN_NAME="git-spice"
# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

if ! command -v gs-stack-status &>/dev/null; then
  hook_log "gs-stack-status is not installed. Install it with:"
  hook_log "  brew install nsheaps/devsetup/gs-stack-status"
  hook_log ""
  hook_log "gs-stack-status provides a terminal dashboard for git-spice stacked branch workflows."
else
  hook_log "gs-stack-status available"
fi

hook_respond
