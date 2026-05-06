#!/usr/bin/env bash
# install.sh — Setup{matcher: init} hook for github-app plugin
#
# Trusts that the launcher (bin/agent) has already sourced the agent's
# .env.local (populated by the 1pass plugin) before running claude, so the
# JWT-signing inputs are present in process env. We just write them to
# static.env (with AGENT_HOME_DIR-derived isolation paths) and mint the
# initial token.
#
# TODO(future): once MCP server env propagation is solved, move the 1pass
# secret fetch into a Setup hook directly. Today MCP servers are spawned
# before SessionStart, so they need the env populated by the launcher.
# Companion follow-up: an mcpmon-style watcher that restarts MCP servers
# when .env.local changes.
set -euo pipefail

PLUGIN_NAME="github-app"

# --- Source shared libs from shared-lib plugin's persistent data dir ---
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

_wait_for_shared_lib() {
  local lib="$1" i=0
  while [[ ! -f "${SHARED_LIB_DIR}/${lib}" ]]; do
    i=$((i + 1))
    if [[ "${i}" -ge 20 ]]; then
      echo "[github-app] timed out waiting for ${SHARED_LIB_DIR}/${lib}" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "plugin-config-read.sh"
_wait_for_shared_lib "hook-logging.sh"

# shellcheck source=/dev/null
source "${SHARED_LIB_DIR}/plugin-config-read.sh"
# shellcheck source=/dev/null
source "${SHARED_LIB_DIR}/hook-logging.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/agent-paths.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/env-file.sh"

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

# AGENT_NAME and AGENT_HOME_DIR are set by the launcher (bin/agent). Hard-fail
# loudly if either is missing — no defaults, no fallbacks.
: "${AGENT_NAME:?install.sh: AGENT_NAME unset (launcher must export it)}"
: "${AGENT_HOME_DIR:?install.sh: AGENT_HOME_DIR unset (launcher must export it)}"

# Required JWT-signing inputs. Sourced from process env (populated by 1pass +
# bin/agent before claude exec). If they're missing, fail loudly — operators
# will know the secret is misconfigured.
: "${GITHUB_APP_ID:?install.sh: GITHUB_APP_ID unset (check 1pass secret + bin/agent .env.local sourcing)}"
: "${GITHUB_INSTALLATION_ID:?install.sh: GITHUB_INSTALLATION_ID unset}"

# PEM key: accept either inline content (GITHUB_APP_PRIVATE_KEY) or a path.
if [[ -n "${GITHUB_APP_PRIVATE_KEY_PATH:-}" ]]; then
  _private_key_path="${GITHUB_APP_PRIVATE_KEY_PATH/#\~/${HOME}}"
elif [[ -n "${GITHUB_APP_PRIVATE_KEY:-}" ]]; then
  _private_key_path="${GITHUB_APP_CONFIG_DIR}/private-key.pem"
  mkdir -p "${GITHUB_APP_CONFIG_DIR}"
  chmod 700 "${GITHUB_APP_CONFIG_DIR}"
  printf '%s' "${GITHUB_APP_PRIVATE_KEY}" | _atomic_write "${_private_key_path}" 600
else
  echo "install.sh: GITHUB_APP_PRIVATE_KEY (content) or GITHUB_APP_PRIVATE_KEY_PATH must be set" >&2
  exit 1
fi

mkdir -p "${GITHUB_APP_CONFIG_DIR}"
chmod 700 "${GITHUB_APP_CONFIG_DIR}"

# Derive isolation paths from AGENT_HOME_DIR — these never come from process
# env; they are programmatically built from the agent's identity.
GH_CONFIG_DIR="${AGENT_HOME_DIR}/.config/gh"
GIT_CONFIG_GLOBAL="${AGENT_HOME_DIR}/.config/git/config"

# --- Write static.env ---
hook_log_step "write-static" "Writing static.env to ${STATIC_ENV_FILE}"
write_static_env_file \
  "${GITHUB_APP_ID}" \
  "${GITHUB_INSTALLATION_ID}" \
  "${_private_key_path}" \
  "${GITHUB_APP_CLIENT_ID:-}" \
  "${GITHUB_APP_CLIENT_SECRET:-}" \
  "env" \
  "${GH_CONFIG_DIR}" \
  "${GIT_CONFIG_GLOBAL}"

# --- Generate initial token ---
hook_log_step "generate-token" "Generating initial GitHub App installation token"
TOKEN_FILE="${GITHUB_APP_CONFIG_DIR}/token"
"${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
  "${GITHUB_APP_ID}" \
  "${_private_key_path}" \
  "${GITHUB_INSTALLATION_ID}" \
  "${TOKEN_FILE}"

# --- Migrate from pre-0.4.0 flat layout (kept one cycle for auto-cleanup) ---
migrate_legacy_layout

hook_log "Setup complete: ${GITHUB_APP_CONFIG_DIR}"
hook_log_cleanup
hook_respond
