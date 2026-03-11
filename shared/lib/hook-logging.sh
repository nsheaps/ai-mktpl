#!/usr/bin/env bash
# hook-logging.sh — Shared library for buffered hook logging with structured error reporting
#
# Captures all verbose output during hook execution into a log buffer.
# On success, logs are silently discarded. On failure, a structured error
# message is printed to stderr (visible to both user and Claude) that includes:
#   - Which plugin failed
#   - What operation failed
#   - Path to the full log file
#   - Suggested remediation steps
#
# Usage:
#   PLUGIN_NAME="my-plugin"                     # Required: set before sourcing
#   source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"
#
#   hook_log "Installing tool v1.2.3"           # Buffer a verbose log line
#   hook_log_always "Tool v1.2.3 ready"         # Log + always print to stderr
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

# Append a line to the log buffer. Also writes to stderr if HOOK_VERBOSE=true.
# Args: $1=message
hook_log() {
  local msg="$1"
  echo "[$(date +%H:%M:%S)] ${PLUGIN_NAME}: ${msg}" >> "$_HOOK_LOG_FILE"
  if [ "${HOOK_VERBOSE:-false}" = "true" ]; then
    echo "${PLUGIN_NAME}: ${msg}" >&2
  fi
}

# Log a message AND always print it to stderr (visible to the agent/user).
# Use for important status messages the agent should see regardless of success/failure.
# Args: $1=message
hook_log_always() {
  local msg="$1"
  echo "[$(date +%H:%M:%S)] ${PLUGIN_NAME}: ${msg}" >> "$_HOOK_LOG_FILE"
  echo "${PLUGIN_NAME}: ${msg}" >&2
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

# --- Execution wrapper ---

# Run a function with log capture. On failure, prints the structured error.
# The wrapped function can call hook_fail directly for specific errors,
# or this wrapper will produce a generic failure message if the function
# exits non-zero without calling hook_fail.
# Args: $1=function_name [remaining args passed through]
hook_run() {
  local func="$1"
  shift

  # Use a temp file marker to track hook_fail across subshell boundaries
  local fail_marker="${_HOOK_LOG_FILE}.failed"

  # Run the function, capturing stderr into the log buffer as well
  # We use a subshell + fd redirection to tee stderr to the log
  local rc=0
  {
    "$func" "$@" 2>&1 1>&3 | while IFS= read -r line; do
      echo "$line" >> "$_HOOK_LOG_FILE"
      echo "$line" >&2
    done
  } 3>&1 || rc=$?

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

# Remove the log file (call explicitly if you handle errors yourself)
hook_log_cleanup() {
  if [ "$_HOOK_FAILED" != "true" ] && [ ! -f "${_HOOK_LOG_FILE}.failed" ]; then
    rm -f "$_HOOK_LOG_FILE"
  fi
  rm -f "${_HOOK_LOG_FILE}.failed"
}
