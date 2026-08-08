#!/usr/bin/env bash
# direnv-check.sh — PreToolUse hook for direnv plugin
#
# Runs before each Bash tool call (see hooks/hooks.json matcher). Re-checks
# whether the nearest .envrc has changed (added, removed, or modified) and,
# if so, re-runs `direnv export bash` and rewrites the static runtime env
# file that CLAUDE_ENV_FILE sources. Debounced/throttled so this does not
# stat the filesystem and diff .envrc state on literally every tool call.
#
# Output rules (see .claude/rules/hook-output-patterns.md): this hook never
# has an opinion about allow/deny, so it NEVER writes a permissionDecision.
# It always exits 0 with empty stdout, deferring to the normal permission
# system. Status is logged to stderr only.
set -euo pipefail

PLUGIN_NAME="direnv"

# --- Source shared libs (same resolution as install-direnv.sh) ---

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[$PLUGIN_NAME] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 0
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/plugin-config-read.sh"
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/hook-logging.sh"

# shellcheck source=../../lib/direnv-export.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/direnv-export.sh"

# --- Guards ---

plugin_is_enabled || { hook_respond; exit 0; }

# --- Read hook input ---

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Belt-and-suspenders: hooks.json already matches only Bash, but guard here
# too in case the matcher is ever widened to "*".
if [ "$TOOL_NAME" != "Bash" ]; then
  hook_respond
  exit 0
fi

# --- Resolve target directory ---
#
# Best-effort: a persistent Bash tool shell's actual cwd isn't visible to a
# hook process. If the command starts with a `cd <dir> &&`/`cd <dir>;`
# prefix (a common pattern for this agent's own Bash calls), honor it;
# otherwise fall back to CLAUDE_PROJECT_DIR, matching what SessionStart used.
resolve_target_dir() {
  local cmd
  cmd="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"

  local cd_target
  cd_target="$(echo "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]&;]+).*/\1/p' | head -1)"
  # Strip surrounding quotes if present
  cd_target="${cd_target%\"}"; cd_target="${cd_target#\"}"
  cd_target="${cd_target%\'}"; cd_target="${cd_target#\'}"

  if [ -n "$cd_target" ]; then
    local resolved
    resolved="$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && cd "$cd_target" 2>/dev/null && pwd)" || resolved=""
    if [ -n "$resolved" ]; then
      echo "$resolved"
      return 0
    fi
  fi

  echo "${CLAUDE_PROJECT_DIR:-.}"
}

TARGET_DIR="$(resolve_target_dir)"

# --- Debounce/throttle ---
#
# TODO(agent-hook-throttle): this local debounce is a placeholder. A
# companion task is extracting this exact "DEBOUNCE_FILE + elapsed seconds"
# pattern (first introduced in github-app's github-token-check.sh) into a
# shared, reusable helper in claude-utils. should_check()/record_check() are
# kept as small, isolated functions specifically so that swap is a
# one-function change here, not a rewrite of this script.
DEBOUNCE_FILE="${CLAUDE_PLUGIN_DATA}/direnv-last-check"
DEBOUNCE_SECONDS="$(plugin_get_config "checkIntervalSeconds" "2")"

should_check() {
  [ -f "$DEBOUNCE_FILE" ] || return 0
  local last_check now elapsed
  last_check="$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  elapsed=$((now - last_check))
  [ "$elapsed" -ge "$DEBOUNCE_SECONDS" ]
}

record_check() {
  mkdir -p "$(dirname "$DEBOUNCE_FILE")"
  date +%s > "$DEBOUNCE_FILE"
}

# --- Main ---

should_check || { hook_respond; exit 0; }
record_check

FINGERPRINT_FILE="${CLAUDE_PLUGIN_DATA}/direnv-fingerprint"
RUNTIME_FILE="${CLAUDE_PLUGIN_DATA}/direnv-env"

CURRENT_FP="$(direnv_fingerprint "$TARGET_DIR")"
STORED_FP=""
[ -f "$FINGERPRINT_FILE" ] && STORED_FP="$(cat "$FINGERPRINT_FILE" 2>/dev/null || echo "")"

if [ "$CURRENT_FP" = "$STORED_FP" ]; then
  # No .envrc change — nothing to do, stay silent.
  hook_respond
  exit 0
fi

# .envrc state changed (added, removed, modified, or a different ancestor
# .envrc now applies because the target directory changed). Re-export.
DIRENV_BIN=""
if command -v direnv &>/dev/null; then
  DIRENV_BIN="$(command -v direnv)"
elif [ -x "${CLAUDE_PROJECT_DIR:-.}/bin/.local/direnv" ]; then
  DIRENV_BIN="${CLAUDE_PROJECT_DIR:-.}/bin/.local/direnv"
fi

if [ -z "$DIRENV_BIN" ]; then
  hook_log "direnv binary not found (PATH or bin/.local) — skipping re-export"
  hook_log_cleanup
  hook_respond
  exit 0
fi

hook_log "envrc fingerprint changed, re-exporting via direnv"
direnv_export_and_write "$DIRENV_BIN" "$TARGET_DIR" "$RUNTIME_FILE"
echo "$CURRENT_FP" > "$FINGERPRINT_FILE"

hook_log_cleanup
hook_respond
