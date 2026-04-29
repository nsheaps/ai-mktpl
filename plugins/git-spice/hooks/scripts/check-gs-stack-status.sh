#!/usr/bin/env bash
# check-gs-stack-status.sh — SessionStart hook for git-spice plugin
#
# Checks if gs-stack-status is installed; auto-installs via mise if not already on PATH
# when autoInstall is enabled. Follows the shared tool-install pattern.
set -euo pipefail

PLUGIN_NAME="git-spice"
# shellcheck source=../../lib/plugin-config-read.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
# shellcheck source=../../lib/tool-install.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"
# shellcheck source=../../lib/hook-logging.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }
tool_is_available gs-stack-status && { hook_log "gs-stack-status already available, skipping install"; hook_respond; exit 0; }

# --- Read config ---

auto_install="$(plugin_get_config "autoInstall" "true")"

# --- Check if already available ---

if tool_is_available gs-stack-status; then
  hook_log "gs-stack-status available"
  hook_log_cleanup
  hook_respond
  exit 0
fi

# --- Auto-install disabled ---

if [ "$auto_install" = "false" ]; then
  hook_log "autoInstall=false and gs-stack-status not on PATH, skipping"
  hook_log "gs-stack-status is not installed. Install it with:"
  hook_log "  brew install nsheaps/devsetup/gs-stack-status"
  hook_log_cleanup
  hook_respond
  exit 0
fi

# --- Install via mise ---

do_install() {
  hook_log_step "install-gs-stack-status" "Installing gs-stack-status via mise"

  if ! tool_is_available mise; then
    hook_log "mise not available — install gs-stack-status manually:"
    hook_log "  brew install nsheaps/devsetup/gs-stack-status"
    return 0
  fi

  hook_log "gs-stack-status not found, installing via mise..."
  if mise use -g ubi:nsheaps/gs-stack-status; then
    # Refresh PATH so the binary is available in this session
    eval "$(mise activate bash 2>/dev/null)" || true
    if tool_is_available gs-stack-status; then
      hook_log "gs-stack-status installed successfully via mise"
    else
      hook_log "gs-stack-status installed but not yet on PATH — may require a new session"
    fi
  else
    hook_fail "mise install" \
      "Failed to install gs-stack-status via mise" \
      "Install manually: brew install nsheaps/devsetup/gs-stack-status"
  fi
}

# --- Execute ---

tool_run_install do_install
hook_log_cleanup
hook_respond
