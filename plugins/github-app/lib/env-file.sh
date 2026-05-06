#!/usr/bin/env bash
# env-file.sh — Shared env-file writers for the github-app plugin
#
# This file owns the on-disk layout of the plugin's config under
# ${GITHUB_APP_CONFIG_DIR} (= ${AGENT_CONFIG_DIR}/github-app/). Two separate
# files exist by design (BUG-19):
#
#   static.env        — immutable JWT-signing inputs. Written ONLY by
#                       hooks/scripts/install.sh during Setup. Never re-written
#                       from process env afterwards.
#   runtime.env       — mutable per-session/per-refresh state (token, git
#                       identity, isolation pointers). Written by SessionStart
#                       and every successful PreToolUse refresh.
#
# Splitting them prevents the BUG-19 contamination loop where SessionStart
# would re-read GITHUB_APP_ID etc. from process env and persist whatever was
# in env (possibly another agent's value) back to disk.
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

# Source agent-paths for AGENT_CONFIG_DIR / GITHUB_APP_CONFIG_DIR
_env_file_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=agent-paths.sh
[[ "${_AGENT_PATHS_LOADED:-}" == "true" ]] || source "$_env_file_dir/agent-paths.sh"

# Canonical paths under GITHUB_APP_CONFIG_DIR. Callers may override TOKEN_FILE
# (via GITHUB_TOKEN_FILE / config "tokenFile") but not the static/runtime paths.
STATIC_ENV_FILE="${GITHUB_APP_CONFIG_DIR}/static.env"
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

# write_static_env_file APP_ID INSTALLATION_ID PEM_PATH [CLIENT_ID] [CLIENT_SECRET] [REF_PROVENANCE]
#
# Called only by install.sh during Setup. Writes the immutable JWT-signing
# inputs to ${STATIC_ENV_FILE} from explicit positional arguments — values
# are NEVER read from process env, so there is no path for cross-agent
# env contamination to flow into this file.
write_static_env_file() {
  local app_id="${1:?write_static_env_file: APP_ID required}"
  local installation_id="${2:?write_static_env_file: INSTALLATION_ID required}"
  local pem_path="${3:?write_static_env_file: PEM_PATH required}"
  local client_id="${4:-}"
  local client_secret="${5:-}"
  local ref_provenance="${6:-}"
  local written_at
  written_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    cat <<'STATICEOF'
# github-app plugin static config — written by Setup hook (install.sh).
# DO NOT EDIT. This file is the source of truth for JWT-signing inputs and
# is intentionally NOT rewritten on token refresh. To regenerate, rerun
# `claude --init-only` or delete this file and start a new session.
STATICEOF
    printf 'export GITHUB_APP_ID="%s"\n' "$(_safe_val "$app_id")"
    printf 'export GITHUB_INSTALLATION_ID="%s"\n' "$(_safe_val "$installation_id")"
    printf 'export GITHUB_APP_PRIVATE_KEY_PATH="%s"\n' "$(_safe_val "$pem_path")"
    [[ -n "$client_id" ]]     && printf 'export GITHUB_APP_CLIENT_ID="%s"\n' "$(_safe_val "$client_id")"
    [[ -n "$client_secret" ]] && printf 'export GITHUB_APP_CLIENT_SECRET="%s"\n' "$(_safe_val "$client_secret")"
    printf 'export GITHUB_APP_STATIC_REF="%s"\n' "$(_safe_val "$ref_provenance")"
    printf 'export GITHUB_APP_STATIC_WRITTEN_AT="%s"\n' "$(_safe_val "$written_at")"
  } | _atomic_write "$STATIC_ENV_FILE" 600
}

# read_static_env_file -- sources STATIC_ENV_FILE and verifies required fields.
# Returns 0 on success, 1 if file missing, 2 if a required field is empty.
read_static_env_file() {
  if [[ ! -f "$STATIC_ENV_FILE" ]]; then
    return 1
  fi
  # shellcheck disable=SC1090
  source "$STATIC_ENV_FILE"
  if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_INSTALLATION_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" ]]; then
    echo "github-app: ERROR: $STATIC_ENV_FILE is missing required fields" >&2
    return 2
  fi
  return 0
}

# write_runtime_env_file TOKEN
#
# Writes per-session/per-refresh state. Intentionally does NOT include
# GITHUB_APP_ID, GITHUB_INSTALLATION_ID, or GITHUB_APP_PRIVATE_KEY_PATH —
# those live in static.env exclusively (BUG-19).
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
# Removes the pre-0.4.0 flat env file at ${AGENT_CONFIG_DIR}/github-app-env
# if it exists. Idempotent. Logs to stderr when a file is removed.
migrate_legacy_layout() {
  local legacy="${AGENT_CONFIG_DIR}/github-app-env"
  if [[ -f "$legacy" ]]; then
    echo "github-app: removing legacy env file $legacy (pre-0.4.0 layout)" >&2
    rm -f "$legacy"
  fi
}
