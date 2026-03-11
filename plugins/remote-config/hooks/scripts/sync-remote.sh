#!/usr/bin/env bash
# sync-remote.sh — Sync upstream Claude config repo on session start
#
# Reads config from ~/.claude/settings.remote-config.yaml (or env var).
# Clones/pulls the upstream repo to ~/.claude-remote/.
# Reports update status: tag + short sha, or just short sha.
# If verbose: true, prints commit titles since last update.

set -euo pipefail

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

if [ ! -f "$CONFIG_FILE" ]; then
  # No config file — check env var
  if [ -n "${CLAUDE_REMOTE_UPSTREAM:-}" ]; then
    UPSTREAM_REPO="$CLAUDE_REMOTE_UPSTREAM"
    VERBOSE="false"
  else
    # No config at all — silently exit (plugin not configured)
    exit 0
  fi
else
  UPSTREAM_REPO=$(yaml_get "$CONFIG_FILE" "upstream")
  VERBOSE=$(yaml_get "$CONFIG_FILE" "verbose")

  # Env var overrides config file
  UPSTREAM_REPO="${CLAUDE_REMOTE_UPSTREAM:-$UPSTREAM_REPO}"
  VERBOSE="${VERBOSE:-false}"
fi

if [ -z "$UPSTREAM_REPO" ]; then
  echo "[remote-config] Error: No upstream repo configured" >&2
  echo "[remote-config] Set 'upstream' in $CONFIG_FILE or CLAUDE_REMOTE_UPSTREAM env var" >&2
  exit 0
fi

# --- Sync ---

PREV_SHA=""

if [ -d "$REMOTE_DIR/.git" ]; then
  # Repo exists — pull latest
  PREV_SHA=$(git -C "$REMOTE_DIR" rev-parse --short HEAD 2>/dev/null || true)

  if ! git -C "$REMOTE_DIR" pull --ff-only --quiet 2>/dev/null; then
    echo "[remote-config] Error: Cannot update $REMOTE_DIR cleanly" >&2
    echo "[remote-config] Suggest: cd $REMOTE_DIR && git status" >&2
    echo "[remote-config] Claude could fix this — reset to origin and re-pull" >&2
    # Hook stdout is shown to user; they can decide
    exit 0
  fi
else
  # Fresh clone
  if ! git clone --quiet "$UPSTREAM_REPO" "$REMOTE_DIR" 2>/dev/null; then
    echo "[remote-config] Error: Failed to clone $UPSTREAM_REPO" >&2
    echo "[remote-config] Check the upstream URL in $CONFIG_FILE" >&2
    exit 0
  fi
  echo "[remote-config] Cloned $UPSTREAM_REPO → $REMOTE_DIR"
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
  echo "[remote-config] Updated: $PREV_SHA → $STATUS_LINE"

  # Verbose: show commit titles since last update
  if [ "$VERBOSE" = "true" ]; then
    echo "[remote-config] Changes:"
    git -C "$REMOTE_DIR" log --oneline "${PREV_SHA}..HEAD" --reverse 2>/dev/null | while IFS= read -r line; do
      echo "  $line"
    done
  fi
elif [ -z "$PREV_SHA" ]; then
  echo "[remote-config] Ready: $STATUS_LINE"
else
  # No changes
  echo "[remote-config] Up to date: $STATUS_LINE"
fi

exit 0
