#!/usr/bin/env bash
# hook-logging.sh — Shared library for hook logging with structured error reporting
#
# All output is printed directly to stdout (success messages) or stderr (errors).
# On failure, a structured error message is printed to stderr that includes:
#   - Which plugin failed
#   - What operation failed
#   - Path to the full log file
#   - Suggested remediation steps
#
# Usage:
#   PLUGIN_NAME="my-plugin"                     # Required: set before sourcing
#   source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"
#
#   hook_log "Installing tool v1.2.3"           # Print to stdout + stderr
#   hook_log_always "Tool v1.2.3 ready"         # Alias for hook_log
#   hook_log_step "download" "Downloading binary"  # Start a named step
#
#   # Wrap your main logic:
#   hook_run my_main_function
#
#   # Or manually report failure:
#   hook_fail "download" "curl returned 404" \
#     "Check network connectivity and verify the download URL"
#
# Requires: PLUGIN_NAME must be set before sourcing.
# Note: Plugins symlink this file into their own lib/ directory.
# Symlinked content is resolved and copied on plugin install.

# Guard against double-sourcing
if [ "${_HOOK_LOGGING_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_HOOK_LOGGING_LOADED="true"

# Validate PLUGIN_NAME is set
if [ -z "${PLUGIN_NAME:-}" ]; then
  echo "ERROR: PLUGIN_NAME must be set before sourcing hook-logging.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# --- Log file setup ---

_HOOK_LOG_DIR="${TMPDIR:-/tmp}/claude-plugin-logs"
mkdir -p "$_HOOK_LOG_DIR"
_HOOK_LOG_FILE="${_HOOK_LOG_DIR}/${PLUGIN_NAME}-$(date +%Y%m%d-%H%M%S)-$$.log"
_HOOK_CURRENT_STEP=""
_HOOK_FAILED="false"

# --- Logging functions ---

# Print a message to both stdout (agent sees it) and stderr (user sees it).
# Also appends to the log file for failure diagnostics.
# Args: $1=message
hook_log() {
  local line="${PLUGIN_NAME}: $1"
  echo "[$(date +%H:%M:%S)] ${line}" >> "$_HOOK_LOG_FILE"
  echo "$line"
  echo "$line" >&2
}

# Alias for hook_log. Previously stderr-only; now both channels.
# Args: $1=message
hook_log_always() {
  hook_log "$1"
}

# Alias for hook_log.
# Kept for backwards compatibility with scripts that used hook_session_message.
# Args: $1=message
hook_session_message() {
  hook_log "$1"
}

# Mark the start of a named step (for error attribution).
# Args: $1=step_id (short machine name, e.g. "download") $2=description
hook_log_step() {
  local step_id="$1"
  local description="$2"
  _HOOK_CURRENT_STEP="$step_id"
  hook_log "--- step: ${step_id} --- ${description}"
}

# --- Error reporting ---

# Print a structured failure message to stderr and save the log file.
# Args: $1=failed_component (e.g. "curl", "mise install")
#       $2=error_detail (e.g. "exit code 1", "404 not found")
#       $3=suggestion (e.g. "Check network connectivity")
hook_fail() {
  local component="$1"
  local detail="${2:-unknown error}"
  local suggestion="${3:-}"

  _HOOK_FAILED="true"

  # Touch fail marker for cross-subshell propagation (used by hook_run)
  touch "${_HOOK_LOG_FILE}.failed" 2>/dev/null || true

  # Ensure the log file is preserved (not cleaned up)
  hook_log "FAILED: ${component}: ${detail}"

  # Print structured error to stderr (visible to user and Claude)
  {
    echo ""
    echo "==== Plugin Setup Failed ===="
    echo "  Plugin:    ${PLUGIN_NAME}"
    echo "  Component: ${component}"
    if [ -n "$_HOOK_CURRENT_STEP" ]; then
      echo "  Step:      ${_HOOK_CURRENT_STEP}"
    fi
    echo "  Error:     ${detail}"
    echo "  Logs:      ${_HOOK_LOG_FILE}"
    if [ -n "$suggestion" ]; then
      echo "  Fix:       ${suggestion}"
    fi
    echo "============================="
    echo ""
  } >&2

  return 0
}

# --- Response helper ---

# No-op kept for backwards compatibility.
# Previously output JSON; now all output goes directly to stdout/stderr.
# Scripts can safely remove calls to hook_respond.
hook_respond() {
  :
}

# --- Execution wrapper ---

# Run a function. On failure, prints a structured error if hook_fail wasn't called.
# Args: $1=function_name [remaining args passed through]
hook_run() {
  local func="$1"
  shift

  # Use a temp file marker to track hook_fail across subshell boundaries
  local fail_marker="${_HOOK_LOG_FILE}.failed"

  # Run the function directly — stdout/stderr pass through normally
  local rc=0
  "$func" "$@" || rc=$?

  if [ "$rc" -ne 0 ] && [ ! -f "$fail_marker" ]; then
    # Function failed but didn't call hook_fail — generate a generic error
    hook_fail "${func}" "exited with code ${rc}" \
      "Review the log file for details, then retry or disable the ${PLUGIN_NAME} plugin"
  fi

  # Clean up log file on success (keep on failure)
  if [ "$rc" -eq 0 ] && [ ! -f "$fail_marker" ]; then
    rm -f "$_HOOK_LOG_FILE"
  fi

  # Clean up fail marker
  rm -f "$fail_marker"

  return "$rc"
}

# --- Cleanup helper ---

# Remove the log file (call explicitly if you handle errors yourself).
hook_log_cleanup() {
  if [ "$_HOOK_FAILED" != "true" ] && [ ! -f "${_HOOK_LOG_FILE}.failed" ]; then
    rm -f "$_HOOK_LOG_FILE"
  fi
  rm -f "${_HOOK_LOG_FILE}.failed"
}
