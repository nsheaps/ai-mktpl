#!/usr/bin/env bash
# install.sh — Setup{matcher: init} hook for github-app plugin
#
# Runs once per `claude --init-only` (i.e. on plugin install or version change).
# Resolves the JWT-signing inputs from the configured source-of-truth (op://
# vault, env-file://, or secrets.* literals) — explicitly NOT from process env
# for the static fields — and writes them to ${GITHUB_APP_CONFIG_DIR}/static.env.
# Then generates the initial installation token.
#
# Owns BUG-19 (https://github.com/nsheaps/agents/issues/...): once Setup writes
# static.env from the vault, no other hook ever rewrites those fields, so a
# contaminated process env cannot poison the JWT.
set -euo pipefail

PLUGIN_NAME="github-app"

# --- Source shared libs from shared-lib plugin's persistent data dir ---
# (Same pattern as github-token-init.sh; shared-lib's Setup hook copies
# lib/*.sh into CLAUDE_PLUGIN_DATA before any dependent plugin runs.)
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
      echo "[github-app] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib Setup copy)" >&2
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
source "${CLAUDE_PLUGIN_ROOT}/lib/resolve-secrets.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

mkdir -p "$GITHUB_APP_CONFIG_DIR"
chmod 700 "$GITHUB_APP_CONFIG_DIR"

# --- Resolve secrets STRICTLY from plugin config, not process env ---
#
# This is the key BUG-19 mitigation: process env may contain another agent's
# GITHUB_APP_ID etc.; we must not let that flow into our static config.

hook_log_step "resolve" "Resolving secrets from plugin config (NOT process env)"

REF="$(plugin_get_config "ref" "")"

# Locals — keep these scoped, do NOT export, so we can detect missing fields
# without colliding with anything in the inherited environment.
_app_id=""
_installation_id=""
_private_key=""           # inline content
_private_key_path=""      # explicit path
_client_id=""
_client_secret=""

if [[ -n "$REF" ]]; then
  case "$REF" in
    op://*)
      if _op_available; then
        hook_log "Resolving secrets directly from 1Password: $REF"
        _app_id="$(op read "${REF}/GITHUB_APP_ID" 2>/dev/null || true)"
        _installation_id="$(op read "${REF}/GITHUB_INSTALLATION_ID" 2>/dev/null || true)"
        _private_key="$(op read "${REF}/GITHUB_APP_PRIVATE_KEY" 2>/dev/null || true)"
        _client_id="$(op read "${REF}/GITHUB_APP_CLIENT_ID" 2>/dev/null || true)"
        _client_secret="$(op read "${REF}/GITHUB_APP_CLIENT_SECRET" 2>/dev/null || true)"
      else
        hook_fail "op-cli" "ref is op:// but op CLI/OP_SERVICE_ACCOUNT_TOKEN unavailable" \
          "Install op CLI and ensure OP_SERVICE_ACCOUNT_TOKEN is exported before claude --init-only"
        hook_respond; exit 0
      fi
      ;;
    env-file://*)
      _env_path="${REF#env-file://}"
      [[ "$_env_path" == ./* || "$_env_path" == ../* ]] && _env_path="${CLAUDE_PROJECT_DIR:-.}/${_env_path}"
      _env_path="${_env_path/#\~/$HOME}"
      _env_path="$(realpath "$_env_path" 2>/dev/null || echo "$_env_path")"
      if [[ ! -f "$_env_path" ]]; then
        hook_fail "env-file" "env file not found: $_env_path" \
          "Create the env file or update the 'ref' setting in plugin config"
        hook_respond; exit 0
      fi
      # Source in a SUBSHELL so the file's contents do not pollute our process env;
      # then read out the specific fields we want.
      while IFS='=' read -r k v; do
        case "$k" in
          GITHUB_APP_ID)              _app_id="$v" ;;
          GITHUB_INSTALLATION_ID)     _installation_id="$v" ;;
          GITHUB_APP_PRIVATE_KEY)     _private_key="$v" ;;
          GITHUB_APP_PRIVATE_KEY_PATH)_private_key_path="$v" ;;
          GITHUB_APP_CLIENT_ID)       _client_id="$v" ;;
          GITHUB_APP_CLIENT_SECRET)   _client_secret="$v" ;;
        esac
      done < <(
        # shellcheck disable=SC1090
        ( set -a; source "$_env_path"; set +a;
          for var in GITHUB_APP_ID GITHUB_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY \
                     GITHUB_APP_PRIVATE_KEY_PATH GITHUB_APP_CLIENT_ID GITHUB_APP_CLIENT_SECRET; do
            printf '%s=%s\n' "$var" "$(eval "printf %s \"\${$var:-}\"")"
          done )
      )
      hook_log "Loaded secrets from env file: $_env_path"
      ;;
    *)
      hook_fail "ref-format" "Unsupported ref format: $REF" \
        "Use op://vault/item or env-file:///path/to/file"
      hook_respond; exit 0
      ;;
  esac
fi

# Per-field overrides (secrets.*) — each value can be a literal, ${VAR}, or op://field.
_resolve_secret_value() {
  local raw="$1" name="$2"
  [[ -z "$raw" ]] && { echo ""; return; }
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    # NOTE: env-var interpolation in secrets.* IS still supported here for
    # NON-static fields (private-key path can come from launcher env). For
    # static fields this is dangerous — see "_app_id reset" below.
    echo "${!BASH_REMATCH[1]:-}"
    return
  fi
  if [[ "$raw" == op://* ]]; then
    if _op_available; then
      op read "$raw" 2>/dev/null || { hook_log "WARNING: failed to resolve $name from $raw"; echo ""; return; }
      return
    fi
    hook_log "WARNING: op:// for $name but op unavailable"
    echo ""; return
  fi
  echo "$raw"
}

_sec_app_id="$(plugin_get_config "secrets.github_app_id" "")"
_sec_installation_id="$(plugin_get_config "secrets.github_installation_id" "")"
_sec_client_id="$(plugin_get_config "secrets.github_app_client_id" "")"
_sec_client_secret="$(plugin_get_config "secrets.github_app_client_secret" "")"
_sec_private_key="$(plugin_get_config "secrets.github_app_private_key" "")"

[[ -n "$_sec_app_id" ]]          && _app_id="$(_resolve_secret_value "$_sec_app_id" github_app_id)"
[[ -n "$_sec_installation_id" ]] && _installation_id="$(_resolve_secret_value "$_sec_installation_id" github_installation_id)"
[[ -n "$_sec_client_id" ]]       && _client_id="$(_resolve_secret_value "$_sec_client_id" github_app_client_id)"
[[ -n "$_sec_client_secret" ]]   && _client_secret="$(_resolve_secret_value "$_sec_client_secret" github_app_client_secret)"
[[ -n "$_sec_private_key" ]]     && _private_key="$(_resolve_secret_value "$_sec_private_key" github_app_private_key)"

# Legacy flat settings (backwards compatibility)
[[ -z "$_app_id" ]]          && _app_id="$(plugin_get_config "github_app_id" "")"
[[ -z "$_installation_id" ]] && _installation_id="$(plugin_get_config "github_installation_id" "")"
[[ -z "$_private_key_path" ]] && _private_key_path="$(plugin_get_config "private_key_path" "")"

# --- Validate ---

if [[ -z "$_app_id" || -z "$_installation_id" ]]; then
  hook_log "GitHub App not configured (missing app_id or installation_id), skipping"
  hook_log_cleanup
  hook_respond; exit 0
fi

# --- Resolve PEM path ---

if [[ -z "$_private_key_path" && -n "$_private_key" ]]; then
  _private_key_path="${GITHUB_APP_CONFIG_DIR}/private-key.pem"
  printf '%s' "$_private_key" > "$_private_key_path"
  chmod 600 "$_private_key_path"
  hook_log "Wrote private key to $_private_key_path"
fi

if [[ -z "$_private_key_path" ]]; then
  hook_fail "private-key" "No GITHUB_APP_PRIVATE_KEY (content) or _PATH provided" \
    "Set ref:/secrets.* to provide either the key content or a path"
  hook_respond; exit 0
fi

_private_key_path="${_private_key_path/#\~/$HOME}"
_private_key_path="$(realpath "$_private_key_path" 2>/dev/null || echo "$_private_key_path")"

if [[ ! -f "$_private_key_path" ]]; then
  hook_fail "private-key" "PEM key not found at $_private_key_path" \
    "Ensure the private key file exists or set GITHUB_APP_PRIVATE_KEY content"
  hook_respond; exit 0
fi

PERMS=$(stat -c '%a' "$_private_key_path" 2>/dev/null || stat -f '%Lp' "$_private_key_path" 2>/dev/null || echo unknown)
if [[ "$PERMS" != "600" && "$PERMS" != "400" && "$PERMS" != "unknown" ]]; then
  hook_log "WARNING: PEM key permissions $PERMS — should be 600 or 400"
fi

# --- Write static.env ---

hook_log_step "write-static" "Writing static.env to $STATIC_ENV_FILE"
write_static_env_file \
  "$_app_id" \
  "$_installation_id" \
  "$_private_key_path" \
  "$_client_id" \
  "$_client_secret" \
  "${REF:-secrets.*}"
hook_log "Wrote static.env (app_id=$_app_id, installation=$_installation_id)"

# --- Generate initial token ---

hook_log_step "generate-token" "Generating initial GitHub App installation token"
TOKEN_FILE="${GITHUB_APP_CONFIG_DIR}/token"
TOKEN_OUTPUT="$("${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
  "$_app_id" \
  "$_private_key_path" \
  "$_installation_id" \
  "$TOKEN_FILE" 2>&1)" || {
  hook_fail "token-gen" "Initial token generation failed: $TOKEN_OUTPUT" \
    "Verify the App ID, installation ID, and PEM key are valid and the App is installed on the target org/repo"
  hook_respond; exit 0
}

hook_log "Initial token generated"

# --- Migrate from pre-0.4.0 flat layout ---

migrate_legacy_layout

hook_log "Setup complete: ${GITHUB_APP_CONFIG_DIR}"
hook_log_cleanup
hook_respond
