#!/usr/bin/env bash
# github-token-init.sh — SessionStart hook for github-app plugin
#
# As of 0.4.0 the immutable JWT-signing inputs (GITHUB_APP_ID,
# GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY_PATH) live in
# ${GITHUB_APP_CONFIG_DIR}/static.env, written exclusively by the Setup hook
# (hooks/scripts/install.sh). This hook NEVER reads those values from process
# env — that path was the BUG-19 contamination vector.
#
# Steps:
#   1. Source static.env (if missing, fall back to running install.sh once
#      so existing 0.3.x sessions self-heal).
#   2. Refresh-or-regenerate the token.
#   3. Resolve bot identity from token.meta and write runtime.env +
#      git-identity.env.
#   4. Append source lines to CLAUDE_ENV_FILE so subsequent Bash calls inherit
#      the runtime + identity.
set -euo pipefail

PLUGIN_NAME="github-app"

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
      echo "[github-app] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
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
source "${CLAUDE_PLUGIN_ROOT}/lib/agent-paths.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/env-file.sh"

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

# --- Load static config (the ONLY source of APP_ID / installation / PEM path) ---

if ! read_static_env_file; then
  rc=$?
  if [[ ${rc} -eq 1 ]]; then
    hook_log "static.env missing — running Setup (install.sh) inline as fallback"
    if ! bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/install.sh" 2>&1; then
      hook_log "install.sh fallback failed; plugin not configured, skipping"
      hook_log_cleanup
      hook_respond; exit 0
    fi
    if ! read_static_env_file; then
      hook_log "static.env still missing after install.sh; skipping"
      hook_log_cleanup
      hook_respond; exit 0
    fi
  else
    hook_log "static.env malformed (rc=${rc}); skipping"
    hook_log_cleanup
    hook_respond; exit 0
  fi
fi

# Always run legacy migration on session start (idempotent).
migrate_legacy_layout

# --- Token paths ---

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$(plugin_get_config "tokenFile" "${GITHUB_APP_CONFIG_DIR}/token")}"
TOKEN_FILE="${TOKEN_FILE/#\~/$HOME}"
META_FILE="${TOKEN_FILE}.meta"
mkdir -p "$(dirname "$TOKEN_FILE")"
export GITHUB_TOKEN_FILE="$TOKEN_FILE"

source "${CLAUDE_PLUGIN_ROOT}/lib/token-utils.sh"

# --- Refresh or regenerate ---
#
# Decision: try refresh only when the token is healthy and within the refresh
# window (≤ 45 min remaining). Otherwise (missing/expired/refresh-failed),
# regenerate from scratch via JWT signing. One linear path, one fallback.

hook_log_step "token" "Refreshing or regenerating installation token"

_minutes="$(get_minutes_remaining)"
_should_regen=true
case "$_minutes" in
  missing|expired) ;;  # regen
  *)
    if (( _minutes > 45 )); then
      _should_regen=false  # token healthy, no action
    elif "${CLAUDE_PLUGIN_ROOT}/bin/token-check.sh" --sync --quiet; then
      _should_regen=false  # refresh succeeded
    else
      hook_log "token-check refresh failed; falling back to fresh generation"
    fi
    ;;
esac

if [[ "$_should_regen" == "true" ]]; then
  TOKEN_OUTPUT="$("${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
    "$GITHUB_APP_ID" \
    "$GITHUB_APP_PRIVATE_KEY_PATH" \
    "$GITHUB_APP_INSTALLATION_ID" \
    "$TOKEN_FILE" 2>&1)" || {
    hook_fail "token-gen" "Token generation failed: $TOKEN_OUTPUT" \
      "Re-run \`claude --init-only\` and verify ref/secrets resolve to the correct GitHub App"
    exit 0
  }
fi

TOKEN="$(cat "$TOKEN_FILE")"
EXPIRES_AT="$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null || true)"

# --- gh + git isolation directories ---
# GH_CONFIG_DIR / GIT_CONFIG_GLOBAL are set in static.env (sourced above) by
# the Setup hook, derived from AGENT_HOME_DIR. We just ensure the dirs exist.

: "${GH_CONFIG_DIR:?github-token-init: GH_CONFIG_DIR not in static.env (rerun claude --init-only)}"
: "${GIT_CONFIG_GLOBAL:?github-token-init: GIT_CONFIG_GLOBAL not in static.env (rerun claude --init-only)}"
mkdir -p "${GH_CONFIG_DIR}"
chmod 700 "${GH_CONFIG_DIR}"
mkdir -p "$(dirname "${GIT_CONFIG_GLOBAL}")"
export GH_CONFIG_DIR GIT_CONFIG_GLOBAL

# --- Bot identity from token metadata ---

APP_SLUG="$(jq -r '.app_slug // empty' "$META_FILE" 2>/dev/null || true)"
BOT_ID="$(jq -r '.bot_id // empty' "$META_FILE" 2>/dev/null || true)"

if [[ -z "$BOT_ID" && -n "$APP_SLUG" ]]; then
  hook_log "bot_id missing from metadata — runtime resolution via /users/${APP_SLUG}[bot]"
  _user_resp="$(curl -s -w '\n%{http_code}' \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/users/${APP_SLUG}%5Bbot%5D" 2>/dev/null || true)"
  _user_code="$(echo "$_user_resp" | tail -1)"
  _user_body="$(echo "$_user_resp" | sed '$d')"
  if [[ "$_user_code" == "200" ]]; then
    BOT_ID="$(echo "$_user_body" | jq -r '.id // empty' 2>/dev/null || true)"
    if [[ -n "$BOT_ID" && -w "$META_FILE" ]] && command -v jq >/dev/null 2>&1; then
      _tmp="${META_FILE}.tmp.$$"
      if jq --arg bid "$BOT_ID" '.bot_id = $bid' "$META_FILE" > "$_tmp" 2>/dev/null; then
        mv "$_tmp" "$META_FILE"
        chmod 600 "$META_FILE"
      else
        rm -f "$_tmp"
      fi
    fi
  fi
fi

# Configure git identity ONLY if we have both slug and bot_id.
# (BUG-7: never silently fall back to APP_ID, which would miscredit commits.)
_auto_git="$(plugin_get_config "autoGitConfig" "true")"
if [[ "$_auto_git" == "true" && -n "$APP_SLUG" && -n "$BOT_ID" ]]; then
  GIT_AUTHOR_NAME="${APP_SLUG}[bot]"
  GIT_AUTHOR_EMAIL="${BOT_ID}+${APP_SLUG}[bot]@users.noreply.github.com"
  GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  write_git_config_global "${CLAUDE_PLUGIN_ROOT}/bin/git-credential-github-app.sh"
  write_git_identity_file "$GIT_AUTHOR_NAME" "$GIT_AUTHOR_EMAIL"
  hook_log "Configured git identity: $GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>"
elif [[ "$_auto_git" == "true" ]]; then
  hook_log "WARNING: cannot resolve bot_id for ${APP_SLUG:-<unknown>} — git identity not configured (commits will fail until resolved)"
fi

# --- Write runtime.env ---

write_runtime_env_file "$TOKEN"

# --- Source from CLAUDE_ENV_FILE for subsequent Bash tool calls ---

if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  {
    echo "source \"$RUNTIME_ENV_FILE\""
    [[ -f "$GIT_IDENTITY_FILE" ]] && echo "source \"$GIT_IDENTITY_FILE\""
  } >> "$CLAUDE_ENV_FILE"
fi

hook_log "Authenticated as ${APP_SLUG:-app-$GITHUB_APP_ID} (expires: ${EXPIRES_AT:-unknown})"
hook_log "Token available via \$GH_TOKEN and \$GITHUB_TOKEN"

hook_log_cleanup
hook_respond
