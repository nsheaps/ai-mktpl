#!/usr/bin/env bash
# github-token-init.sh — SessionStart hook for github-app plugin
#
# Generates a GitHub App installation token on session start.
# Expects secrets in environment variables. Use the 1pass plugin or
# an env-file to populate them before this hook runs.
#
# Supported secret sources via the `ref` setting:
#   - op://vault/item         → resolve fields directly from 1Password (primary)
#   - env-file://path/to/file → source KEY=VALUE pairs from a file
# Individual secrets via `secrets.*`:
#   - Literal values
#   - ${VAR_NAME}             → expand from environment
#   - op://vault/item/field   → resolve a single field from 1Password
#
# Required env vars (set directly or via ref/secrets config):
#   GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY or GITHUB_APP_PRIVATE_KEY_PATH,
#   GITHUB_INSTALLATION_ID
#
# Writes token to a shared file and creates a runtime env file that is
# sourced by CLAUDE_ENV_FILE. The PreToolUse hook updates the runtime
# env file on refresh, so subsequent Bash commands always get fresh tokens.
set -euo pipefail

PLUGIN_NAME="github-app"


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
source "${CLAUDE_PLUGIN_ROOT}/lib/resolve-secrets.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

# --- Secret resolution ---

# Resolve a secret value from one of:
#   - ${VAR_NAME}  → expand from environment
#   - op://...     → resolve from 1Password directly
#   - literal      → use as-is
resolve_secret() {
  local raw="$1"
  local name="${2:-secret}"

  # Empty
  if [[ -z "$raw" ]]; then
    echo ""
    return
  fi

  # Environment variable reference: ${VAR_NAME}
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    local resolved="${!var_name:-}"
    if [[ -z "$resolved" ]]; then
      hook_log "WARNING: env var $var_name is not set (for $name)"
    fi
    echo "$resolved"
    return
  fi

  # 1Password reference: op://vault/item/field
  if [[ "$raw" == op://* ]]; then
    if _op_available; then
      local resolved
      resolved=$(op read "$raw" 2>/dev/null) || {
        hook_log "WARNING: Failed to resolve $name from 1Password ($raw)"
        echo ""
        return
      }
      echo "$resolved"
      return
    else
      hook_log "WARNING: op:// reference for $name but op CLI not available or OP_SERVICE_ACCOUNT_TOKEN not set"
      echo ""
      return
    fi
  fi

  # Literal value
  echo "$raw"
}

# Resolve an env-file:// path to an absolute path.
# Relative paths (env-file://./...) are resolved relative to CLAUDE_PROJECT_DIR.
resolve_env_file_path() {
  local raw="$1"
  local path="${raw#env-file://}"

  # Relative path: resolve against project dir
  if [[ "$path" == ./* || "$path" == ../* ]]; then
    path="${CLAUDE_PROJECT_DIR:-.}/${path}"
  fi

  # Expand tilde
  path="${path/#\~/$HOME}"

  # Canonicalize
  realpath "$path" 2>/dev/null || echo "$path"
}

# --- Load secrets from ref ---

hook_log_step "load-secrets" "Loading secrets from configured source"

REF="$(plugin_get_config "ref" "")"

if [[ -n "$REF" ]]; then
  if [[ "$REF" == op://* ]]; then
    # 1Password item reference — resolve all fields directly
    if _op_available; then
      hook_log "Resolving secrets directly from 1Password: $REF"
      GITHUB_APP_ID="${GITHUB_APP_ID:-$(op read "${REF}/GITHUB_APP_ID" 2>/dev/null || true)}"
      GITHUB_APP_CLIENT_ID="${GITHUB_APP_CLIENT_ID:-$(op read "${REF}/GITHUB_APP_CLIENT_ID" 2>/dev/null || true)}"
      GITHUB_APP_CLIENT_SECRET="${GITHUB_APP_CLIENT_SECRET:-$(op read "${REF}/GITHUB_APP_CLIENT_SECRET" 2>/dev/null || true)}"
      GITHUB_APP_PRIVATE_KEY="${GITHUB_APP_PRIVATE_KEY:-$(op read "${REF}/GITHUB_APP_PRIVATE_KEY" 2>/dev/null || true)}"
      GITHUB_INSTALLATION_ID="${GITHUB_INSTALLATION_ID:-$(op read "${REF}/GITHUB_INSTALLATION_ID" 2>/dev/null || true)}"
      hook_log "Resolved secrets from 1Password item"
    else
      hook_log "op:// ref configured but op CLI not available or OP_SERVICE_ACCOUNT_TOKEN not set"
    fi

  elif [[ "$REF" == env-file://* ]]; then
    # Env file reference — source KEY=VALUE pairs
    ENV_FILE_PATH="$(resolve_env_file_path "$REF")"

    if [[ ! -f "$ENV_FILE_PATH" ]]; then
      hook_fail "env file" "env file not found: $ENV_FILE_PATH" \
        "Create the env file or update the 'ref' setting in plugin config"
      hook_respond; exit 0
    fi

    # Source only lines matching KEY=VALUE (skip comments and blanks)
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip comments and blank lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      # Strip optional 'export ' prefix
      line="${line#export }"
      # Only process lines with =
      if [[ "$line" == *=* ]]; then
        key="${line%%=*}"
        value="${line#*=}"
        # Strip surrounding quotes from value
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
      fi
    done < "$ENV_FILE_PATH"

    hook_log "Loaded secrets from env file: $ENV_FILE_PATH"

  else
    hook_fail "ref config" "Unsupported ref format: $REF" \
      "Use op://vault/item or env-file:///path/to/file format."
    hook_respond; exit 0
  fi
fi

# --- Load individual secret overrides ---

hook_log_step "resolve-secrets" "Resolving individual secret overrides"

# Each secrets.* value can be a literal or ${ENV_VAR}
SECRETS_APP_ID="$(plugin_get_config "secrets.github_app_id" "")"
SECRETS_CLIENT_ID="$(plugin_get_config "secrets.github_app_client_id" "")"
SECRETS_CLIENT_SECRET="$(plugin_get_config "secrets.github_app_client_secret" "")"
SECRETS_PRIVATE_KEY="$(plugin_get_config "secrets.github_app_private_key" "")"
SECRETS_INSTALLATION_ID="$(plugin_get_config "secrets.github_installation_id" "")"

# Resolve individual secrets if configured (these take priority over ref env vars)
if [[ -n "$SECRETS_APP_ID" ]]; then
  GITHUB_APP_ID="$(resolve_secret "$SECRETS_APP_ID" "github_app_id")"
fi
if [[ -n "$SECRETS_CLIENT_ID" ]]; then
  GITHUB_APP_CLIENT_ID="$(resolve_secret "$SECRETS_CLIENT_ID" "github_app_client_id")"
fi
if [[ -n "$SECRETS_CLIENT_SECRET" ]]; then
  GITHUB_APP_CLIENT_SECRET="$(resolve_secret "$SECRETS_CLIENT_SECRET" "github_app_client_secret")"
fi
if [[ -n "$SECRETS_PRIVATE_KEY" ]]; then
  GITHUB_APP_PRIVATE_KEY="$(resolve_secret "$SECRETS_PRIVATE_KEY" "github_app_private_key")"
fi
if [[ -n "$SECRETS_INSTALLATION_ID" ]]; then
  GITHUB_INSTALLATION_ID="$(resolve_secret "$SECRETS_INSTALLATION_ID" "github_installation_id")"
fi

# Fall back to legacy flat settings for backwards compatibility
GITHUB_APP_ID="${GITHUB_APP_ID:-$(plugin_get_config "github_app_id" "")}"
GITHUB_INSTALLATION_ID="${GITHUB_INSTALLATION_ID:-$(plugin_get_config "github_installation_id" "")}"

# --- Wait for credentials (hook ordering fallback) ---
#
# Claude Code doesn't guarantee SessionStart hook execution order.
# Primary path: credentials resolved via op:// ref or secrets.* config above.
# Fallback path: poll CLAUDE_ENV_FILE in case another plugin (e.g., 1pass)
# writes them there. The wait runs before private-key resolution so that
# GITHUB_APP_PRIVATE_KEY (inline content) can still be written to a temp
# file if it arrives late.

if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_INSTALLATION_ID:-}" ]]; then
  hook_log "credentials not yet available, checking CLAUDE_ENV_FILE..."
  if wait_for_env_file GITHUB_APP_ID GITHUB_INSTALLATION_ID --timeout 15; then
    # Check for private key (value or path)
    if wait_for_env_file GITHUB_APP_PRIVATE_KEY_PATH --timeout 2 || wait_for_env_file GITHUB_APP_PRIVATE_KEY --timeout 2; then
      hook_log "credentials found in CLAUDE_ENV_FILE"
    else
      hook_log "timeout waiting for private key — GitHub App not configured, skipping"
      hook_log_cleanup
      hook_respond; exit 0
    fi
  else
    hook_log "timeout waiting for credentials — GitHub App not configured, skipping"
    hook_log_cleanup
    hook_respond; exit 0
  fi
fi

# --- Handle private key (value vs file path) ---

# GITHUB_APP_PRIVATE_KEY contains the key content directly (e.g., from env var)
# GITHUB_APP_PRIVATE_KEY_PATH points to a PEM file on disk
# If we have key content but no path, write it to a temp file
GITHUB_APP_PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY_PATH:-$(plugin_get_config "private_key_path" "")}"

if [[ -n "${GITHUB_APP_PRIVATE_KEY:-}" && -z "$GITHUB_APP_PRIVATE_KEY_PATH" ]]; then
  # Key content provided directly — write to a secure temp file
  KEY_DIR="${AGENT_CONFIG_DIR}"
  mkdir -p "$KEY_DIR"
  GITHUB_APP_PRIVATE_KEY_PATH="${KEY_DIR}/github-app-${GITHUB_APP_ID:-unknown}.pem"
  echo "$GITHUB_APP_PRIVATE_KEY" > "$GITHUB_APP_PRIVATE_KEY_PATH"
  chmod 600 "$GITHUB_APP_PRIVATE_KEY_PATH"
  hook_log "Wrote private key to $GITHUB_APP_PRIVATE_KEY_PATH"
fi

# --- Validate required credentials ---

if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" || -z "${GITHUB_INSTALLATION_ID:-}" ]]; then
  hook_log "GitHub App not configured (missing GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY/GITHUB_APP_PRIVATE_KEY_PATH, or GITHUB_INSTALLATION_ID), skipping"
  hook_log_cleanup
  hook_respond; exit 0
fi

# Expand tilde in key path
GITHUB_APP_PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY_PATH/#\~/$HOME}"

if [[ ! -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]]; then
  hook_fail "private key" "PEM key not found at $GITHUB_APP_PRIVATE_KEY_PATH" \
    "Ensure the private key file exists, or set GITHUB_APP_PRIVATE_KEY env var with the key content"
  exit 0
fi

# Validate PEM file permissions
PERMS=$(stat -c '%a' "$GITHUB_APP_PRIVATE_KEY_PATH" 2>/dev/null || stat -f '%Lp' "$GITHUB_APP_PRIVATE_KEY_PATH" 2>/dev/null || echo "unknown")
if [[ "$PERMS" != "600" && "$PERMS" != "400" && "$PERMS" != "unknown" ]]; then
  hook_log "WARNING: PEM key has permissions $PERMS, should be 600 or 400"
fi

# --- Token generation ---

hook_log_step "generate-token" "Generating GitHub App installation token"

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$(plugin_get_config "tokenFile" "${AGENT_CONFIG_DIR}/github-token")}"
TOKEN_FILE="${TOKEN_FILE/#\~/$HOME}"
mkdir -p "$(dirname "$TOKEN_FILE")"

# Export credentials so token-check.sh can use them
export GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY_PATH GITHUB_INSTALLATION_ID
export GITHUB_TOKEN_FILE="$TOKEN_FILE"

# Use the shared JWT generation script
TOKEN_OUTPUT=$("${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
  "$GITHUB_APP_ID" \
  "$GITHUB_APP_PRIVATE_KEY_PATH" \
  "$GITHUB_INSTALLATION_ID" \
  "$TOKEN_FILE" 2>&1) || {
  hook_fail "token generation" "Token generation failed: $TOKEN_OUTPUT" \
    "Verify GitHub App credentials (GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY_PATH, GITHUB_INSTALLATION_ID) are correct and the app is installed on the target org/repo"
  exit 0
}

# Read generated token and metadata for output
TOKEN=$(cat "$TOKEN_FILE")
META_FILE="${TOKEN_FILE}.meta"
EXPIRES_AT=""
APP_SLUG=""

if [[ -f "$META_FILE" ]]; then
  EXPIRES_AT=$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null)
fi

# --- GH_CONFIG_DIR isolation ---
# Create an agent-specific, empty gh config directory so that gh never falls
# back to the handler's personal keyring when the App token expires.
# Scoped to AGENT_CONFIG_DIR (per-agent) so multiple agents on the same
# machine or in the same project don't share gh config.

hook_log_step "gh-config-dir" "Creating isolated GH_CONFIG_DIR"

GH_CONFIG_DIR="${AGENT_CONFIG_DIR}/gh"
mkdir -p "$GH_CONFIG_DIR"
chmod 700 "$GH_CONFIG_DIR"
export GH_CONFIG_DIR
hook_log "GH_CONFIG_DIR isolated at $GH_CONFIG_DIR"

# --- Write runtime env file ---
# This file is sourced via CLAUDE_ENV_FILE so that subsequent Bash commands
# always pick up the latest token. The PreToolUse hook updates this file
# when it refreshes the token.

hook_log_step "write-env" "Writing runtime environment file"

ENV_RUNTIME_FILE="${AGENT_CONFIG_DIR}/github-app-env"
write_runtime_env_file "$TOKEN"

# Source the runtime env file from CLAUDE_ENV_FILE so all Bash commands
# get the token. The file is re-sourced on each command, picking up
# any refreshes done by the PreToolUse hook.
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "source \"$ENV_RUNTIME_FILE\"" >> "$CLAUDE_ENV_FILE"
fi

# --- Configure git identity from GitHub App bot account via env vars ---
#
# Sets GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME, GIT_COMMITTER_EMAIL
# as environment variables instead of writing to git config. This avoids polluting
# the global git config on shared machines where multiple agents may be running.

configure_git_identity_env() {
  local auto_git_config
  auto_git_config="$(plugin_get_config "autoGitConfig" "true")"
  [[ "$auto_git_config" == "true" ]] || return 0

  hook_log_step "git-identity" "Configuring git identity env vars"

  # BUG-7 fix: Never preserve existing git identity from the host machine.
  # On shared machines all agents run as the same OS user and inherit the
  # handler's ~/.gitconfig. We ALWAYS resolve the bot identity from the
  # token metadata and write an isolated GIT_CONFIG_GLOBAL so agents never
  # commit as the handler.

  # Read app slug and bot ID from token metadata (written by generate-token.sh
  # which has JWT auth needed for the /app endpoint — installation tokens
  # cannot access /app).
  local app_slug bot_id
  app_slug=$(jq -r '.app_slug // empty' "$META_FILE" 2>/dev/null) || true
  [[ -n "$app_slug" ]] || { hook_log "WARNING: app_slug not in metadata — git identity not configured"; return 0; }

  bot_id=$(jq -r '.bot_id // empty' "$META_FILE" 2>/dev/null) || true

  # Runtime fallback: if metadata is missing bot_id (older metadata file, or the
  # API was unreachable at token-generation time), try to resolve it now via the
  # PUBLIC /users/<slug>[bot] endpoint. This endpoint requires NO authentication
  # (passing a bearer token there causes 401 — see BUG-7).
  if [[ -z "$bot_id" ]]; then
    hook_log "bot_id missing from metadata — attempting runtime resolution via /users/${app_slug}[bot]"
    local user_resp user_code user_body
    user_resp=$(curl -s -w "\n%{http_code}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/users/${app_slug}%5Bbot%5D" 2>/dev/null) || true
    user_code=$(echo "$user_resp" | tail -1)
    user_body=$(echo "$user_resp" | sed '$d')
    if [[ "$user_code" == "200" ]]; then
      bot_id=$(echo "$user_body" | jq -r '.id // empty' 2>/dev/null) || true
      if [[ -n "$bot_id" ]]; then
        hook_log "Runtime-resolved bot user ID for ${app_slug}[bot]: ${bot_id}"
        # Persist into metadata so we don't repeat the API call on every
        # session start. Use a temp file + mv for atomic update.
        if command -v jq >/dev/null 2>&1 && [[ -w "$META_FILE" ]]; then
          local tmp_meta="${META_FILE}.tmp.$$"
          if jq --arg bid "$bot_id" '.bot_id = $bid' "$META_FILE" > "$tmp_meta" 2>/dev/null; then
            mv "$tmp_meta" "$META_FILE"
            chmod 600 "$META_FILE"
          else
            rm -f "$tmp_meta"
          fi
        fi
      fi
    else
      hook_log "Runtime resolution failed (HTTP ${user_code}): ${user_body}"
    fi
  fi

  local bot_name="${app_slug}[bot]"
  local bot_email
  if [[ -n "$bot_id" ]]; then
    bot_email="${bot_id}+${app_slug}[bot]@users.noreply.github.com"
  else
    # FAIL LOUD: We cannot determine the correct bot user ID. Falling back to
    # GITHUB_APP_ID is wrong — the App ID and bot user ID are different numbers,
    # and commits authored with the App ID in the noreply email will NOT be
    # attributed to the bot account on GitHub. This was the root cause of BUG-7.
    #
    # Rather than silently produce miscredited commits, refuse to configure
    # git identity. Subsequent commits will fail with "Author identity unknown",
    # which is loud and recoverable. The handler can rerun token generation or
    # fix network/API access. Commits silently miscredited to the App ID are
    # NOT recoverable without rewriting history.
    hook_log "ERROR: Could not resolve bot user ID for ${app_slug}[bot]."
    hook_log "ERROR: The /users/${app_slug}[bot] API call failed both at token-generation time and at session-start runtime."
    hook_log "ERROR: Refusing to configure git identity with the wrong email (App ID ${GITHUB_APP_ID} != bot user ID)."
    hook_log "ERROR: Resolve by ensuring api.github.com is reachable, then regenerate the token (delete ${META_FILE} or run bin/generate-token.sh)."
    return 0
  fi

  # --- GIT_CONFIG_GLOBAL isolation ---
  # Write an agent-specific gitconfig file and set GIT_CONFIG_GLOBAL to point
  # to it. This prevents git from reading the handler's ~/.gitconfig, which is
  # the root cause of BUG-7 (agents committing as the handler on shared machines).
  # This mirrors the GH_CONFIG_DIR pattern already used for gh CLI isolation.
  local agent_base="${AGENT_CONFIG_DIR:-${GH_CONFIG_DIR:+$(dirname "$GH_CONFIG_DIR")}}"
  agent_base="${agent_base:-${HOME}/.agents/github-app/.config}"
  local git_config_file="${agent_base}/git/config"
  mkdir -p "$(dirname "$git_config_file")"

  export GIT_CONFIG_GLOBAL="$git_config_file"
  # BUG-12 fix: use `gh auth git-credential` as the credential helper.
  # Previously we copied a custom script to $CLAUDE_SETTINGS_DIR/plugins/data/
  # and embedded the versioned helper path in gitconfig. Now we write just
  # `!gh auth git-credential` — no script file, no versioned path, no token
  # file path baked into gitconfig. gh reads $GH_TOKEN from the process env
  # (always up-to-date via CLAUDE_ENV_FILE). GH_CONFIG_DIR is already exported
  # per-agent by bin/agent, so gh resolves the correct per-agent config.
  write_git_config_global
  hook_log "GIT_CONFIG_GLOBAL isolated at $git_config_file (credential helper: gh auth git-credential)"

  # Defense-in-depth: also set GIT_AUTHOR_*/GIT_COMMITTER_* env vars.
  # These take precedence over gitconfig, so even if GIT_CONFIG_GLOBAL is
  # somehow bypassed, commits still use the bot identity.
  export GIT_AUTHOR_NAME="$bot_name"
  export GIT_AUTHOR_EMAIL="$bot_email"
  export GIT_COMMITTER_NAME="$bot_name"
  export GIT_COMMITTER_EMAIL="$bot_email"

  # Rewrite the runtime env file now that identity vars are in the environment
  write_runtime_env_file "$TOKEN"

  # Write a separate stable file that is NOT overwritten by token refreshes.
  # This is defense-in-depth: even if the env file template drifts, the
  # git identity file remains correct for the lifetime of the session.
  write_git_identity_file "$bot_name" "$bot_email"

  # Source the stable git identity file from CLAUDE_ENV_FILE after the
  # runtime env file. It takes precedence if the runtime env file ever
  # loses the identity vars (e.g., due to future template drift).
  # Also persist GIT_CONFIG_GLOBAL so subprocesses inherit gitconfig isolation.
  if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "export GIT_CONFIG_GLOBAL=\"$git_config_file\"" >> "$CLAUDE_ENV_FILE"
    echo "source \"$GIT_IDENTITY_FILE\"" >> "$CLAUDE_ENV_FILE"
  fi

  hook_log "Configured git identity env vars: $bot_name <$bot_email>"
  hook_log "Git identity written to stable file: $GIT_IDENTITY_FILE"

  # Save slug for use by hook output logging
  APP_SLUG="$app_slug"
}

configure_git_identity_env

# --- Print initial token info ---

hook_log "Authenticated as ${APP_SLUG:-app-$GITHUB_APP_ID} (expires: ${EXPIRES_AT:-unknown})"
hook_log "Token available via \$GH_TOKEN and \$GITHUB_TOKEN"

hook_log_cleanup
hook_respond
