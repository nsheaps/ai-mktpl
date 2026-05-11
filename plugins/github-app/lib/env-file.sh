#!/usr/bin/env bash
# env-file.sh — Shared env-file writers for the github-app plugin
#
# This file owns the on-disk layout of the plugin's config under
# ${GITHUB_APP_CONFIG_DIR} (= ${XDG_CONFIG_HOME}/github-app/).
#
# Architecture (post-PR #487):
#
#   The plugin is no longer responsible for persisting static credentials.
#   The launcher (bin/agent) sources $AGENT_HOME_DIR/.env / .env.local
#   (managed by the 1pass plugin) before exec'ing claude, so the JWT-signing
#   inputs (GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID,
#   GITHUB_APP_PRIVATE_KEY_PATH) are guaranteed present in process env by
#   the time any hook fires.
#
#   This plugin owns ONLY mutable runtime state:
#     runtime.env       — token + identity, rewritten on every refresh.
#     git-identity.env  — stable git identity (written once per session).
#
# Required variables when calling write_*:
#   GITHUB_APP_CONFIG_DIR   — set by lib/agent-paths.sh
#
# Optional variables (sourced from environment by write_runtime_env_file):
#   GH_CONFIG_DIR
#   GIT_CONFIG_GLOBAL
#   GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL / GIT_COMMITTER_NAME / GIT_COMMITTER_EMAIL

if [ "${_ENV_FILE_LOADED:-}" = "true" ]; then return 0; fi
_ENV_FILE_LOADED="true"

# Source agent-paths for GITHUB_APP_CONFIG_DIR (derived from XDG_CONFIG_HOME).
# `agent-paths.sh` self-guards on `[[ -n "${_AGENT_PATHS_LOADED:-}" ]]` and sets
# the flag to `1`, so we match the same string-presence check here rather than
# comparing to the literal "true". (See PR #487 review.)
_env_file_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agent-paths.sh
[[ -n "${_AGENT_PATHS_LOADED:-}" ]] || source "$_env_file_dir/agent-paths.sh"

# Canonical paths under GITHUB_APP_CONFIG_DIR. Callers may override TOKEN_FILE
# (via GITHUB_TOKEN_FILE / config "tokenFile") but not the runtime paths.
RUNTIME_ENV_FILE="${GITHUB_APP_CONFIG_DIR}/runtime.env"
GIT_IDENTITY_FILE="${GITHUB_APP_CONFIG_DIR}/git-identity.env"

# _safe_val VALUE
#
# Escapes a value for safe embedding in a double-quoted shell assignment.
# Handles $, `, \, ", and newlines so that sourcing the resulting file
# cannot cause shell injection.
_safe_val() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\$/\\\$}"
  v="${v//\`/\\\`}"
  v="${v//\"/\\\"}"
  printf '%s' "$v"
}

# _atomic_write PATH MODE -- writes stdin to PATH atomically with chmod MODE.
_atomic_write() {
  local target="$1" mode="$2"
  local tmp
  mkdir -p "$(dirname "$target")"
  tmp="$(mktemp "$(dirname "$target")/.$(basename "$target").XXXXXX")"
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$target"
}

# require_static_env -- asserts that the JWT-signing inputs are present in
# process env. Fails loudly with a clear message naming each missing var.
# The plugin runs independently of any specific secret manager; the launcher
# is responsible for sourcing the agent's .env/.env.local before exec'ing
# claude. If any required var is missing, we fail fast so the operator knows
# the launcher chain is misconfigured.
#
# Returns 0 if all required vars are non-empty, 1 otherwise.
require_static_env() {
  local missing=()
  [[ -z "${GITHUB_APP_ID:-}" ]] && missing+=("GITHUB_APP_ID")
  [[ -z "${GITHUB_APP_INSTALLATION_ID:-}" ]] && missing+=("GITHUB_APP_INSTALLATION_ID")
  [[ -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" ]] && missing+=("GITHUB_APP_PRIVATE_KEY_PATH")
  if (( ${#missing[@]} > 0 )); then
    echo "github-app: ERROR: required env var(s) missing: ${missing[*]}" >&2
    echo "github-app: ERROR: the launcher (bin/agent) must source \$AGENT_HOME_DIR/.env" >&2
    echo "github-app: ERROR: before invoking claude. See the github-app plugin README for setup." >&2
    return 1
  fi
  return 0
}

# write_runtime_env_file TOKEN
#
# Writes per-session/per-refresh state. Intentionally does NOT include
# GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, or GITHUB_APP_PRIVATE_KEY_PATH —
# those come from the launcher-sourced env chain (see require_static_env).
#
# Args:
#   $1  — the raw token string
write_runtime_env_file() {
  local token="$1"
  local token_file="${TOKEN_FILE:-${GITHUB_APP_CONFIG_DIR}/token}"

  {
    cat <<'RTEOF'
# github-app plugin runtime env — auto-generated, rewritten on every token
# refresh. Add nothing else here.
RTEOF
    printf 'export GH_TOKEN="%s"\n' "$(_safe_val "$token")"
    printf 'export GITHUB_TOKEN="%s"\n' "$(_safe_val "$token")"
    printf 'export GITHUB_TOKEN_FILE="%s"\n' "$(_safe_val "$token_file")"
    printf 'export GITHUB_APP_ENV_FILE="%s"\n' "$(_safe_val "$RUNTIME_ENV_FILE")"
    [[ -n "${GH_CONFIG_DIR:-}" ]]      && printf 'export GH_CONFIG_DIR="%s"\n' "$(_safe_val "$GH_CONFIG_DIR")"
    [[ -n "${GIT_CONFIG_GLOBAL:-}" ]]  && printf 'export GIT_CONFIG_GLOBAL="%s"\n' "$(_safe_val "$GIT_CONFIG_GLOBAL")"
    [[ -n "${GIT_AUTHOR_NAME:-}" ]]    && printf 'export GIT_AUTHOR_NAME="%s"\n' "$(_safe_val "$GIT_AUTHOR_NAME")"
    [[ -n "${GIT_AUTHOR_EMAIL:-}" ]]   && printf 'export GIT_AUTHOR_EMAIL="%s"\n' "$(_safe_val "$GIT_AUTHOR_EMAIL")"
    [[ -n "${GIT_COMMITTER_NAME:-}" ]] && printf 'export GIT_COMMITTER_NAME="%s"\n' "$(_safe_val "$GIT_COMMITTER_NAME")"
    [[ -n "${GIT_COMMITTER_EMAIL:-}" ]]&& printf 'export GIT_COMMITTER_EMAIL="%s"\n' "$(_safe_val "$GIT_COMMITTER_EMAIL")"
  } | _atomic_write "$RUNTIME_ENV_FILE" 600
}

# write_git_identity_file BOT_NAME BOT_EMAIL
#
# Writes a stable identity file that is NOT overwritten by token refreshes.
# Sourced from CLAUDE_ENV_FILE after runtime.env so it takes precedence if
# the runtime file ever drops the identity vars.
write_git_identity_file() {
  local bot_name="$1"
  local bot_email="$2"
  {
    cat <<'GIEOF'
# Stable git identity for the GitHub App bot — written once per session.
# This file is NOT overwritten by token refreshes. Delete it to force a refresh.
GIEOF
    printf 'export GIT_AUTHOR_NAME="%s"\n' "$(_safe_val "$bot_name")"
    printf 'export GIT_AUTHOR_EMAIL="%s"\n' "$(_safe_val "$bot_email")"
    printf 'export GIT_COMMITTER_NAME="%s"\n' "$(_safe_val "$bot_name")"
    printf 'export GIT_COMMITTER_EMAIL="%s"\n' "$(_safe_val "$bot_email")"
  } | _atomic_write "$GIT_IDENTITY_FILE" 600
}

# write_git_config_global [CREDENTIAL_HELPER_PATH]
#
# Rewrites the isolated gitconfig with current identity from env vars
# (GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL) plus an optional credential helper.
write_git_config_global() {
  local cred_helper="${1:-}"
  local bot_name="${GIT_AUTHOR_NAME:-}"
  local bot_email="${GIT_AUTHOR_EMAIL:-}"
  local target="${GIT_CONFIG_GLOBAL:-${GITHUB_APP_CONFIG_DIR}/git/config}"

  [[ -n "$bot_name" && -n "$bot_email" ]] || return 0

  {
    cat <<GCEOF
[user]
    name = ${bot_name}
    email = ${bot_email}
GCEOF
    if [[ -n "$cred_helper" ]]; then
      cat <<GCEOF
[credential "https://github.com"]
    helper = !${cred_helper}
GCEOF
    fi
  } | _atomic_write "$target" 600
}

# migrate_legacy_layout
#
# Removes pre-0.4.0 artifacts. Idempotent. Logs to stderr when a file is
# removed.
#   - ${XDG_CONFIG_HOME}/github-app-env   (pre-0.4.0 flat env file)
#   - ${GITHUB_APP_CONFIG_DIR}/static.env (pre-rework static.env, PR #487)
migrate_legacy_layout() {
  local legacy_flat="${XDG_CONFIG_HOME}/github-app-env"
  if [[ -f "$legacy_flat" ]]; then
    echo "github-app: removing legacy env file $legacy_flat (pre-0.4.0 layout)" >&2
    rm -f "$legacy_flat"
  fi
  local legacy_static="${GITHUB_APP_CONFIG_DIR}/static.env"
  if [[ -f "$legacy_static" ]]; then
    echo "github-app: removing legacy static.env $legacy_static (replaced by launcher-sourced env)" >&2
    rm -f "$legacy_static"
  fi
}
