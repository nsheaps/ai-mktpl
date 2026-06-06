#!/usr/bin/env bash
# Self-terminate script for Claude Code
# Sends SIGINT to the Claude process that spawned this shell

set -euo pipefail

LOG_PREFIX="self-terminate"


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
      echo "[self-terminate] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "log.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/log.sh"
# Traverse up the process tree to find Claude
find_claude_pid() {
    local pid="$PPID"
    local max_depth=10
    local depth=0

    while [[ $depth -lt $max_depth ]]; do
        local process_name
        process_name=$(ps -o comm= -p "$pid" 2>/dev/null || echo "")

        if [[ -z "$process_name" ]]; then
            log_error "Could not find Claude in process tree (reached PID $pid)"
            return 1
        fi

        if [[ "$process_name" == *"claude"* ]]; then
            echo "$pid"
            return 0
        fi

        # Get parent of current pid
        local parent_pid
        parent_pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')

        if [[ -z "$parent_pid" || "$parent_pid" == "0" || "$parent_pid" == "1" ]]; then
            log_error "Reached init without finding Claude"
            return 1
        fi

        pid="$parent_pid"
        ((depth++))
    done

    log_error "Max depth reached without finding Claude"
    return 1
}

CLAUDE_PID=$(find_claude_pid)

if [[ -z "$CLAUDE_PID" ]]; then
    exit 1
fi

log_info "Found Claude process (PID: $CLAUDE_PID)"
log_info "Sending SIGINT..."
kill -INT "$CLAUDE_PID"
