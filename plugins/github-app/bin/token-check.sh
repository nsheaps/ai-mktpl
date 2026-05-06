#!/usr/bin/env bash
# token-check.sh — Check token validity, refresh or re-authenticate as needed
#
# Usage: token-check.sh [--sync] [--quiet]
#
# Checks the current GitHub App token and:
#   - If valid and not close to expiry: exits silently (exit 0)
#   - If valid but within 45 minutes of expiry: refreshes
#   - If expired or invalid: re-authenticates from scratch
#
# Retries up to 3 times with backoff before hard-failing (5 min cooldown).
#
# Flags:
#   --sync   Run refresh synchronously (blocks until complete)
#   --quiet  Suppress all output except errors
#
# Exit codes:
#   0 - Token is valid (possibly refreshed)
#   1 - Token refresh/re-auth failed after retries
#   2 - Not configured (missing credentials)
#   3 - In cooldown period after hard failure
set -euo pipefail

SYNC=false
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --sync)  SYNC=true ;;
    --quiet) QUIET=true ;;
  esac
done

# --- Configuration ---

# shellcheck source=../lib/agent-paths.sh
_self="${BASH_SOURCE[0]}"
while [ -L "$_self" ]; do _self="$(readlink -f "$_self")"; done
source "$(cd "$(dirname "$_self")/.." && pwd)/lib/agent-paths.sh"

TOKEN_FILE="${GITHUB_TOKEN_FILE:-${GITHUB_APP_CONFIG_DIR}/token}"
META_FILE="${TOKEN_FILE}.meta"
LOCKFILE="${TOKEN_FILE}.lock"
COOLDOWN_FILE="${TOKEN_FILE}.cooldown"
REFRESH_THRESHOLD_MINUTES=45  # Proactively refresh when <=45 min remain (token lasts 1h)
MAX_RETRIES=3
COOLDOWN_SECONDS=300

# --- Helpers ---

log() {
  [[ "$QUIET" == "true" ]] && return
  echo "github-app: $*" >&2
}

log_error() {
  echo "github-app: ERROR: $*" >&2
}

# Check if we're in cooldown after a hard failure
check_cooldown() {
  if [[ -f "$COOLDOWN_FILE" ]]; then
    local cooldown_start
    cooldown_start=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    local elapsed=$(( now - cooldown_start ))
    if (( elapsed < COOLDOWN_SECONDS )); then
      local remaining=$(( COOLDOWN_SECONDS - elapsed ))
      log_error "in cooldown period (${remaining}s remaining). Last auth attempt failed."
      return 3
    fi
    rm -f "$COOLDOWN_FILE"
  fi
  return 0
}

# Acquire a simple file-based lock (non-blocking)
acquire_lock() {
  if [[ -f "$LOCKFILE" ]]; then
    local lock_pid
    lock_pid=$(cat "$LOCKFILE" 2>/dev/null || echo "")
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
      return 1  # Another process holds the lock
    fi
    rm -f "$LOCKFILE"  # Stale lock
  fi
  echo $$ > "$LOCKFILE"
  return 0
}

release_lock() {
  rm -f "$LOCKFILE"
}

# Load shared utilities
PLUGIN_DIR="$(cd "$(dirname "$_self")/.." && pwd)"
source "$PLUGIN_DIR/lib/token-utils.sh"
source "$PLUGIN_DIR/lib/env-file.sh"

# Load static config — the source of truth for APP_ID / installation / PEM
# (BUG-19). NEVER trust process env for these fields.
if ! read_static_env_file 2>/dev/null; then
  log_error "static.env missing or invalid — run \`claude --init-only\` to provision"
  exit 2
fi

# update_runtime_env TOKEN — rewrites runtime env file AND gitconfig on each refresh
update_runtime_env() {
  write_runtime_env_file "$1"
  write_git_config_global "${PLUGIN_DIR}/bin/git-credential-github-app.sh"
}

# Generate a new token (full re-auth from keys)
do_generate_token() {
  local script_dir
  script_dir="$(cd "$(dirname "$_self")" && pwd)"

  if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" || -z "${GITHUB_INSTALLATION_ID:-}" ]]; then
    log_error "missing credentials (APP_ID, PRIVATE_KEY_PATH, or INSTALLATION_ID)"
    return 2
  fi

  local output
  output=$("$script_dir/generate-token.sh" \
    "$GITHUB_APP_ID" \
    "$GITHUB_APP_PRIVATE_KEY_PATH" \
    "$GITHUB_INSTALLATION_ID" \
    "$TOKEN_FILE" 2>&1) || {
    log_error "token generation failed: $output"
    return 1
  }

  local token
  token=$(cat "$TOKEN_FILE")
  update_runtime_env "$token"
  return 0
}

# Attempt refresh/re-auth with retries
do_refresh_with_retries() {
  local attempt=0
  local backoff=2

  while (( attempt < MAX_RETRIES )); do
    attempt=$(( attempt + 1 ))

    if do_generate_token; then
      return 0
    fi

    if (( attempt < MAX_RETRIES )); then
      log "retry $attempt/$MAX_RETRIES in ${backoff}s..."
      sleep "$backoff"
      backoff=$(( backoff * 2 ))
    fi
  done

  # Hard failure — enter cooldown
  date +%s > "$COOLDOWN_FILE"
  log_error "failed after $MAX_RETRIES attempts. Backing off for ${COOLDOWN_SECONDS}s."
  return 1
}

# --- Main logic ---

# Static config has already been sourced above via read_static_env_file —
# GITHUB_APP_ID / _PATH / INSTALLATION_ID are guaranteed set at this point.
# We deliberately do NOT fall back to CLAUDE_ENV_FILE-injected values: that
# was the BUG-19 contamination vector.

# Check cooldown
check_cooldown || exit $?

# Check current token status
MINUTES=$(get_minutes_remaining)

case "$MINUTES" in
  missing|expired)
    # Must refresh synchronously regardless of --sync flag
    if ! acquire_lock; then
      log "another refresh is in progress, waiting..."
      # Wait briefly for the other process
      for i in $(seq 1 10); do
        sleep 1
        if ! [[ -f "$LOCKFILE" ]]; then break; fi
      done
      # Re-check after waiting
      MINUTES=$(get_minutes_remaining)
      if [[ "$MINUTES" == "missing" || "$MINUTES" == "expired" ]]; then
        log_error "token still invalid after waiting for concurrent refresh"
        exit 1
      fi
      exit 0
    fi
    trap 'release_lock' EXIT

    log_error "token is ${MINUTES}, re-authenticating..."
    if do_refresh_with_retries; then
      NEW_MINUTES=$(get_minutes_remaining)
      log "re-authenticated successfully (expires in ${NEW_MINUTES} minutes)"
    else
      exit 1
    fi
    ;;

  unknown)
    # Can't determine expiry — assume it's fine
    exit 0
    ;;

  *)
    # We have a numeric minutes remaining
    if (( MINUTES > REFRESH_THRESHOLD_MINUTES )); then
      # Token is valid and not close to expiry — silent success
      exit 0
    fi

    # Token valid but close to expiry
    if ! acquire_lock; then
      # Another process is already refreshing
      exit 0
    fi
    trap 'release_lock' EXIT

    if [[ "$SYNC" == "true" ]]; then
      log "token valid but close to expiration, refreshing synchronously"
      if do_refresh_with_retries; then
        : # silent on success
      else
        log_error "refresh failed, but current token still has ${MINUTES} minutes"
      fi
    else
      log "token valid, but close to expiration, refreshing in the background"
      # Background refresh — fork and exit
      (
        trap 'release_lock' EXIT
        do_refresh_with_retries >/dev/null 2>&1 || true
      ) &
      disown
      exit 0
    fi
    ;;
esac
