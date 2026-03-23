#!/usr/bin/env bash
# Check if gs-stack-status is installed; auto-install via mise if available

PLUGIN_NAME="git-spice"
# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

if command -v gs-stack-status &>/dev/null; then
  hook_log "gs-stack-status available"
  hook_respond
  exit 0
fi

# Not installed — try to install via mise (delegates to ubi backend for GitHub releases)
if command -v mise &>/dev/null; then
  hook_log "gs-stack-status not found, installing via mise..."
  if mise use -g ubi:nsheaps/gs-stack-status 2>/dev/null; then
    hook_log "gs-stack-status installed successfully via mise"
  else
    hook_log "mise install failed — install manually:"
    hook_log "  mise use -g ubi:nsheaps/gs-stack-status"
    hook_log "  brew install nsheaps/devsetup/gs-stack-status"
  fi
else
  hook_log "gs-stack-status is not installed. Install it with:"
  hook_log "  mise use -g ubi:nsheaps/gs-stack-status"
  hook_log "  brew install nsheaps/devsetup/gs-stack-status"
fi

hook_respond
