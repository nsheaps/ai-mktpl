#!/usr/bin/env bash
# check-gs-stack-status.sh — SessionStart hook for git-spice plugin
#
# Checks if gs-stack-status is installed; auto-installs via mise if not already on PATH
# when autoInstall is enabled. Follows the shared tool-install pattern.
set -euo pipefail

PLUGIN_NAME="git-spice"


# --- Source shared libs from shared-lib plugin's persistent data dir ---
#
# shared-lib (declared in plugin.json `dependencies`) copies its lib/*.sh
# files into ${CLAUDE_PLUGIN_DATA}/lib on SessionStart. We resolve its data
# dir by stripping our own data-dir name and appending shared-lib's id.
# Plugin data dir IDs are deterministic: `{plugin-name}-{marketplace-name}`.
# See https://code.claude.com/docs/en/plugins-reference#persistent-data-directory
#
# When CLAUDE_PLUGIN_DATA is unset (e.g. when this script is invoked
# outside a Claude Code hook), fall back to the known path.
if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for a shared-lib file to appear (handles parallel
# SessionStart hooks where shared-lib's copy may not have completed yet).
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[git-spice] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "tool-install.sh"
_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/tool-install.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }
# NOTE: No early exit guard here — the existing check at "Check if already
# available" below already handles gs-stack-status being on PATH.

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
