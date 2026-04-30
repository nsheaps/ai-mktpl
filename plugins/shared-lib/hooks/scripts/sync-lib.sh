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

log() {
  echo "shared-lib: $*" >&2
}

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
  exit 0
fi

# Manifest differs (first run, plugin update, or content drift).
# Copy each file individually (avoid `cp -r src/.` quirks across systems).
log "syncing lib/ to ${DST_DIR}"
copied=0
for f in "$SRC_DIR"/*.sh; do
  [ -e "$f" ] || continue
  cp -f "$f" "$DST_DIR/"
  copied=$((copied + 1))
done

# Write the new manifest LAST, after copies succeed. If copy fails,
# the manifest stays stale and the next session retries.
printf "%s\n" "$NEW_MANIFEST" > "$MANIFEST_FILE"

log "synced ${copied} file(s) to ${DST_DIR}"
exit 0
