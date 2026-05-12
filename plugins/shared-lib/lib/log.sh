#!/usr/bin/env bash
# log.sh — Lightweight general-purpose logging for any bash script
#
# Provides consistent stderr logging with a configurable prefix.
# Works in any context: hooks, session-start scripts, utility scripts, etc.
#
# Usage:
#   LOG_PREFIX="my-script"                  # Optional: defaults to PLUGIN_NAME or "script"
#   source "/path/to/log.sh"
#
#   log_info "Installing tool v1.2.3"       # my-script: Installing tool v1.2.3
#   log_warn "Fallback to default"          # my-script: [warn] Fallback to default
#   log_error "File not found"              # my-script: [error] File not found
#   log_step "download" "Downloading..."    # my-script: [download] Downloading...
#
# All output goes to stderr so it never interferes with stdout (hook responses, etc).

# Guard against double-sourcing
if [ "${_LOG_SH_LOADED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi
_LOG_SH_LOADED="true"

# Resolve prefix: explicit LOG_PREFIX > PLUGIN_NAME > "script"
_LOG_PREFIX="${LOG_PREFIX:-${PLUGIN_NAME:-script}}"

# --- Logging functions ---

# Log an informational message to stderr.
# Args: $1=message
log_info() {
  echo "${_LOG_PREFIX}: $1" >&2
}

# Log a warning message to stderr.
# Args: $1=message
log_warn() {
  echo "${_LOG_PREFIX}: [warn] $1" >&2
}

# Log an error message to stderr.
# Args: $1=message
log_error() {
  echo "${_LOG_PREFIX}: [error] $1" >&2
}

# Log a named step to stderr.
# Args: $1=step_id  $2=message
log_step() {
  echo "${_LOG_PREFIX}: [$1] $2" >&2
}
