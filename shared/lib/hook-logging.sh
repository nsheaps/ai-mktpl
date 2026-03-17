#!/usr/bin/env bash
# hook-logging.sh — Shared library for hook logging with structured JSON output
#
# All hooks output structured JSON to stdout (the only channel Claude Code
# processes for both user-visible systemMessage and agent-visible
# additionalContext). Human-readable messages also go to stderr for
# Ctrl+O verbose mode and log file diagnostics.
#
# Usage:
#   PLUGIN_NAME="my-plugin"                     # Required: set before sourcing
#   source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"
#
#   hook_log "Installing tool v1.2.3"           # stderr + accumulate for JSON
#   hook_log_always "Tool v1.2.3 ready"         # Alias for hook_log
#   hook_log_step "download" "Downloading binary"  # Start a named step
#   hook_fail "curl" "404 not found" "Check URL"   # Structured error to stderr
#   hook_run my_main_function                      # Wrap function, auto-fail on error
#
#   hook_respond                                   # MUST be last — outputs JSON to stdout
#
# IMPORTANT: hook_respond MUST be called exactly once, as the last thing
# before the script exits. It outputs the accumulated messages as JSON.
# Scripts MUST always exit 0.
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
_HOOK_MSG_FILE="${_HOOK_LOG_DIR}/${PLUGIN_NAME}-msgs-$$.txt"
_HOOK_CURRENT_STEP=""
_HOOK_FAILED="false"

# Initialize message accumulator
: > "$_HOOK_MSG_FILE"

# --- Logging functions ---

# Print a message to stderr and accumulate for JSON output.
# Also appends to the log file for failure diagnostics.
# Args: $1=message
hook_log() {
  local line="${PLUGIN_NAME}: $1"
  echo "[$(date +%H:%M:%S)] ${line}" >> "$_HOOK_LOG_FILE"
  echo "$line" >> "$_HOOK_MSG_FILE"
  echo "$line" >&2
}

# Alias for hook_log.
# Args: $1=message
hook_log_always() {
  hook_log "$1"
}

# Alias for hook_log.
# Kept for backwards compatibility.
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

  # Log the failure
  hook_log "FAILED: ${component}: ${detail}"

  # Print structured error to stderr
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

# Output accumulated messages as structured JSON to stdout.
# MUST be called exactly once as the last thing before exit.
# Outputs JSON with both systemMessage (user sees) and additionalContext (agent sees).
hook_respond() {
  local combined=""
  if [ -s "$_HOOK_MSG_FILE" ]; then
    combined=$(cat "$_HOOK_MSG_FILE")
  fi

  # Clean up message file
  rm -f "$_HOOK_MSG_FILE" 2>/dev/null || true

  if [ -n "$combined" ]; then
    if command -v jq &>/dev/null; then
      jq -n --arg msg "$combined" \
        '{additionalContext: $msg, systemMessage: $msg}'
    else
      # Fallback: escape for JSON manually
      local escaped
      escaped=$(printf '%s' "$combined" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | sed ':a;N;$!ba;s/\n/\\n/g')
      echo "{\"additionalContext\":\"${escaped}\",\"systemMessage\":\"${escaped}\"}"
    fi
  else
    echo '{}'
  fi
}

# --- Execution wrapper ---

# Run a function. On failure, prints a structured error if hook_fail wasn't called.
# Always returns 0 (hooks must always exit 0).
# Args: $1=function_name [remaining args passed through]
hook_run() {
  local func="$1"
  shift

  # Use a temp file marker to track hook_fail across subshell boundaries
  local fail_marker="${_HOOK_LOG_FILE}.failed"

  # Run the function with stdout redirected to stderr so stray echo/printf
  # from the function cannot pollute the JSON output on stdout.
  # hook_log already writes to stderr, so it's unaffected.
  local rc=0
  "$func" "$@" 1>&2 || rc=$?

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

  # Always return 0 — hooks must always exit 0
  return 0
}

# --- Cleanup helper ---

# Remove the log file (call explicitly if you handle errors yourself).
hook_log_cleanup() {
  if [ "$_HOOK_FAILED" != "true" ] && [ ! -f "${_HOOK_LOG_FILE}.failed" ]; then
    rm -f "$_HOOK_LOG_FILE"
  fi
  rm -f "${_HOOK_LOG_FILE}.failed"
}
