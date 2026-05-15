#!/usr/bin/env bash
# sync-remote.sh — Sync upstream Claude config repo on session start
#
# Reads config from ~/.claude/settings.remote-config.yaml (or env var).
# Clones/pulls the upstream repo to ~/.claude-remote/.
# Reports update status: tag + short sha, or just short sha.
# If verbose: true, prints commit titles since last update.

set -euo pipefail

PLUGIN_NAME="remote-config"


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
      echo "[remote-config] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"
CONFIG_FILE="${CLAUDE_REMOTE_CONFIG:-$HOME/.claude/settings.remote-config.yaml}"
REMOTE_DIR="$HOME/.claude-remote"

# --- Config Reading ---

# Read a YAML key (simple single-line values only)
yaml_get() {
  local file="$1" key="$2"
  if command -v yq &>/dev/null; then
    yq -r ".$key // empty" "$file" 2>/dev/null || true
  else
    # Fallback: grep-based for simple key: value pairs
    grep -E "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | sed 's/^["'\'']//' | sed 's/["'\'']$//' || true
  fi
}

# --- Load Config ---

hook_log_step "load-config" "Loading remote-config settings"

if [ ! -f "$CONFIG_FILE" ]; then
  # No config file — check env var
  if [ -n "${CLAUDE_REMOTE_UPSTREAM:-}" ]; then
    UPSTREAM_REPO="$CLAUDE_REMOTE_UPSTREAM"
    VERBOSE="false"
  else
    # No config at all — exit (plugin not configured)
    hook_log "not configured, skipping"
    hook_log_cleanup
    hook_respond; exit 0
  fi
else
  UPSTREAM_REPO=$(yaml_get "$CONFIG_FILE" "upstream")
  VERBOSE=$(yaml_get "$CONFIG_FILE" "verbose")

  # Env var overrides config file
  UPSTREAM_REPO="${CLAUDE_REMOTE_UPSTREAM:-$UPSTREAM_REPO}"
  VERBOSE="${VERBOSE:-false}"
fi

if [ -z "$UPSTREAM_REPO" ]; then
  hook_fail "config" "No upstream repo configured" \
    "Set 'upstream' in $CONFIG_FILE or set the CLAUDE_REMOTE_UPSTREAM env var"
  hook_respond; exit 0
fi

# --- Sync ---

hook_log_step "sync" "Syncing upstream config repo"

PREV_SHA=""

if [ -d "$REMOTE_DIR/.git" ]; then
  # Repo exists — pull latest
  PREV_SHA=$(git -C "$REMOTE_DIR" rev-parse --short HEAD 2>/dev/null || true)
  hook_log "Pulling latest from upstream (current: $PREV_SHA)"

  if ! git -C "$REMOTE_DIR" pull --ff-only --quiet 2>/dev/null; then
    hook_fail "git pull" "Cannot update $REMOTE_DIR cleanly (merge conflicts or diverged history)" \
      "Run: cd $REMOTE_DIR && git status — then reset to origin with: git fetch origin && git reset --hard origin/main"
    hook_respond; exit 0
  fi
else
  # Fresh clone
  hook_log "Cloning $UPSTREAM_REPO to $REMOTE_DIR"
  if ! git clone --quiet "$UPSTREAM_REPO" "$REMOTE_DIR" 2>/dev/null; then
    hook_fail "git clone" "Failed to clone $UPSTREAM_REPO" \
      "Check the upstream URL in $CONFIG_FILE and verify network connectivity"
    hook_respond; exit 0
  fi
  hook_log "Cloned $UPSTREAM_REPO → $REMOTE_DIR"
fi

# --- Status ---

CURRENT_SHA=$(git -C "$REMOTE_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Check for tag at HEAD
TAG=$(git -C "$REMOTE_DIR" describe --tags --exact-match HEAD 2>/dev/null || true)

if [ -n "$TAG" ]; then
  STATUS_LINE="$TAG ($CURRENT_SHA)"
else
  STATUS_LINE="$CURRENT_SHA"
fi

if [ -n "$PREV_SHA" ] && [ "$PREV_SHA" != "$CURRENT_SHA" ]; then
  hook_log "Updated: $PREV_SHA → $STATUS_LINE"

  # Verbose: show commit titles since last update
  if [ "$VERBOSE" = "true" ]; then
    hook_log "Changes:"
    git -C "$REMOTE_DIR" log --oneline "${PREV_SHA}..HEAD" --reverse 2>/dev/null | while IFS= read -r line; do
      hook_log "  $line"
    done
  fi
elif [ -z "$PREV_SHA" ]; then
  hook_log "Ready: $STATUS_LINE"
else
  # No changes
  hook_log "up to date: $STATUS_LINE"
fi

hook_log_cleanup
hook_respond
