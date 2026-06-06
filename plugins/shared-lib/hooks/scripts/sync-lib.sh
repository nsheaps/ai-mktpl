#!/usr/bin/env bash
# sync-lib.sh — SessionStart hook for shared-lib plugin (BUG-17 workaround)
#
# Copies bundled lib/*.sh from ${CLAUDE_PLUGIN_ROOT}/lib/ into
# ${CLAUDE_PLUGIN_DATA}/lib/ so that dependent plugins can source them via a
# stable path that survives the upstream symlink-resolution bug
# (anthropics/claude-code#53948).
#
# Uses a manifest-diff pattern (per Anthropic's official persistent-data-directory
# example): compute a content hash of all bundled lib files; only re-copy when the
# hash differs from the stored manifest. This keeps the hot path fast on every
# subsequent session.
#
# Reference: https://code.claude.com/docs/en/plugins-reference#persistent-data-directory

set -euo pipefail

# Required vars (set by Claude Code when the hook runs).
: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}"
: "${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA not set}"

SRC_DIR="${CLAUDE_PLUGIN_ROOT}/lib"
DST_DIR="${CLAUDE_PLUGIN_DATA}/lib"
MANIFEST_FILE="${CLAUDE_PLUGIN_DATA}/lib.manifest"
# Diagnostic: every invocation appends a line here. Lets operators verify
# the hook actually fired and which trigger fired it. Pure observability —
# never gates behavior. Each line: ISO-8601 + hook event + plugin root version
# + outcome.
INVOCATION_LOG="${CLAUDE_PLUGIN_DATA}/sync-lib.invocations.log"

# Capture the hook payload JSON once. Guarded against an interactive TTY so
# `bash sync-lib.sh` (manual invocation) doesn't block on cat waiting for EOF.
HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT="$(cat 2>/dev/null || true)"
fi

log() {
  echo "shared-lib: $*" >&2
}

# Record this invocation. The hook event name is delivered in the stdin
# JSON payload as `hook_event_name`; there is no CLAUDE_HOOK_EVENT_NAME
# env var. Captured once at top-level (see HOOK_INPUT above) so the
# trap-driven record_invocation can read it without re-reading stdin.
# Plugin version is grep'd from plugin.json so we don't take a hard jq
# dep just for version; jq is only used opportunistically for event name.
record_invocation() {
  local outcome="$1"
  local plugin_version="unknown"
  local hook_event="unknown"
  if [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    plugin_version="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' \
      "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null \
      | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    [ -z "$plugin_version" ] && plugin_version="unknown"
  fi
  if [ -n "${HOOK_INPUT:-}" ] && command -v jq >/dev/null 2>&1; then
    hook_event="$(printf '%s' "$HOOK_INPUT" \
      | jq -r '.hook_event_name // "unknown"' 2>/dev/null || echo "unknown")"
    [ -z "$hook_event" ] && hook_event="unknown"
  fi
  mkdir -p "$(dirname "$INVOCATION_LOG")"
  printf '%s event=%s version=%s outcome=%s root=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$hook_event" \
    "$plugin_version" \
    "$outcome" \
    "$CLAUDE_PLUGIN_ROOT" \
    >>"$INVOCATION_LOG" 2>/dev/null || true
}

# Always record entry, even on early exit / error.
trap 'record_invocation "${SYNC_OUTCOME:-error}"' EXIT

if [ ! -d "$SRC_DIR" ]; then
  log "[error] source dir missing: $SRC_DIR"
  exit 1
fi

# Compute manifest: name+size+sha256 of every file in lib/, sorted.
# This is content-stable: any change to any file changes the manifest.
compute_manifest() {
  # Use find with -print0 + sort for deterministic ordering across filesystems.
  find "$SRC_DIR" -maxdepth 1 -type f -print0 \
    | sort -z \
    | xargs -0 -I{} bash -c 'f="$1"; printf "%s %s\n" "$(basename "$f")" "$(sha256sum "$f" | cut -d" " -f1)"' _ {}
}

mkdir -p "$DST_DIR"

NEW_MANIFEST="$(compute_manifest)"
OLD_MANIFEST=""
if [ -f "$MANIFEST_FILE" ]; then
  OLD_MANIFEST="$(cat "$MANIFEST_FILE")"
fi

if [ "$NEW_MANIFEST" = "$OLD_MANIFEST" ] && [ -n "$OLD_MANIFEST" ]; then
  # Manifest matches; nothing to do.
  SYNC_OUTCOME="noop"
  exit 0
fi

# Manifest differs (first run, plugin update, or content drift).
# Copy each file via mktemp + mv for atomic replacement. `cp -f` is NOT
# atomic — it opens dst with O_TRUNC and writes sequentially, so a concurrent
# reader (e.g. a dependent plugin's wait-and-source guard during an update)
# could observe a partially-written file. `mv` on the same filesystem is a
# rename(2) syscall, which atomically replaces the destination.
# The temp prefix (".<base>.XXXXXX") keeps temp files alphabetically distinct
# and out of the way of dependents that glob for "*.sh".
log "syncing lib/ to ${DST_DIR}"
copied=0
for f in "$SRC_DIR"/*.sh; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  tmp="$(mktemp "$DST_DIR/.${base}.XXXXXX")"
  cp -f "$f" "$tmp"
  mv -f "$tmp" "$DST_DIR/$base"
  copied=$((copied + 1))
done

# Write the new manifest LAST, after copies succeed. If copy fails,
# the manifest stays stale and the next session retries.
printf "%s\n" "$NEW_MANIFEST" > "$MANIFEST_FILE"

log "synced ${copied} file(s) to ${DST_DIR}"
SYNC_OUTCOME="synced-${copied}"
exit 0
