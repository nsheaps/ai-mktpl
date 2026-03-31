#!/usr/bin/env bash
# github-token-init.sh — SessionStart hook for github-app plugin
#
# Generates a GitHub App installation token on session start.
# Expects secrets in environment variables. Use the 1pass plugin or
# an env-file to populate them before this hook runs.
#
# Supported secret sources via the `ref` setting:
#   - env-file://path/to/file → source KEY=VALUE pairs from a file
# Individual secrets via `secrets.*`:
#   - Literal values
#   - ${VAR_NAME}             → expand from environment
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
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

# --- Guards ---

plugin_is_enabled || { hook_log "plugin disabled, skipping"; hook_respond; exit 0; }

# --- Secret resolution ---

# Resolve a secret value from one of:
#   - ${VAR_NAME}  → expand from environment
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
  if [[ "$REF" == env-file://* ]]; then
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
      "Use env-file:///path/to/file format. For 1Password secrets, configure the 1pass plugin to expose them as environment variables instead."
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

# --- Handle private key (value vs file path) ---

# GITHUB_APP_PRIVATE_KEY contains the key content directly (e.g., from env var)
# GITHUB_APP_PRIVATE_KEY_PATH points to a PEM file on disk
# If we have key content but no path, write it to a temp file
GITHUB_APP_PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY_PATH:-$(plugin_get_config "private_key_path" "")}"

if [[ -n "${GITHUB_APP_PRIVATE_KEY:-}" && -z "$GITHUB_APP_PRIVATE_KEY_PATH" ]]; then
  # Key content provided directly — write to a secure temp file
  KEY_DIR="${HOME}/.config/agent"
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

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$(plugin_get_config "tokenFile" "$HOME/.config/agent/github-token")}"
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

# --- Write runtime env file ---
# This file is sourced via CLAUDE_ENV_FILE so that subsequent Bash commands
# always pick up the latest token. The PreToolUse hook updates this file
# when it refreshes the token.

hook_log_step "write-env" "Writing runtime environment file"

ENV_RUNTIME_FILE="${HOME}/.config/agent/github-app-env"
mkdir -p "$(dirname "$ENV_RUNTIME_FILE")"
cat > "$ENV_RUNTIME_FILE" <<ENVEOF
# Auto-generated by github-app plugin — do not edit
export GH_TOKEN="$TOKEN"
export GITHUB_TOKEN="$TOKEN"
export GITHUB_TOKEN_FILE="$TOKEN_FILE"
export GITHUB_APP_ID="$GITHUB_APP_ID"
export GITHUB_APP_PRIVATE_KEY_PATH="$GITHUB_APP_PRIVATE_KEY_PATH"
export GITHUB_INSTALLATION_ID="$GITHUB_INSTALLATION_ID"
export GITHUB_APP_ENV_FILE="$ENV_RUNTIME_FILE"
ENVEOF
[[ -n "${GITHUB_APP_CLIENT_ID:-}" ]] && echo "export GITHUB_APP_CLIENT_ID=\"$GITHUB_APP_CLIENT_ID\"" >> "$ENV_RUNTIME_FILE"
[[ -n "${GITHUB_APP_CLIENT_SECRET:-}" ]] && echo "export GITHUB_APP_CLIENT_SECRET=\"$GITHUB_APP_CLIENT_SECRET\"" >> "$ENV_RUNTIME_FILE"
chmod 600 "$ENV_RUNTIME_FILE"

# Source the runtime env file from CLAUDE_ENV_FILE so all Bash commands
# get the token. The file is re-sourced on each command, picking up
# any refreshes done by the PreToolUse hook.
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "source \"$ENV_RUNTIME_FILE\"" >> "$CLAUDE_ENV_FILE"
fi

# --- Configure git identity from GitHub App bot account ---

configure_git_identity() {
  local token="$1"
  local app_id="$2"
  local auto_git_config
  auto_git_config="$(plugin_get_config "autoGitConfig" "true")"
  [[ "$auto_git_config" == "true" ]] || return 0

  hook_log_step "git-identity" "Configuring git identity from GitHub App"

  # Skip if git user.name is already configured (don't override user's settings)
  if git config user.name &>/dev/null && git config user.email &>/dev/null; then
    hook_log "git user.name/email already configured, skipping"
    # Still write env vars from existing git config so sub-agent Bash commands
    # inherit the correct identity regardless of their working directory.
    local existing_name existing_email
    existing_name=$(git config user.name)
    existing_email=$(git config user.email)
    if [[ -n "${ENV_RUNTIME_FILE:-}" && -f "$ENV_RUNTIME_FILE" && -n "$existing_name" && -n "$existing_email" ]]; then
      cat >> "$ENV_RUNTIME_FILE" <<GITENV
export GIT_AUTHOR_NAME="$existing_name"
export GIT_AUTHOR_EMAIL="$existing_email"
export GIT_COMMITTER_NAME="$existing_name"
export GIT_COMMITTER_EMAIL="$existing_email"
GITENV
      hook_log "Git identity env vars written from existing git config"
    fi
    return 0
  fi

  # Fetch the App's slug (name) from the API
  local app_info app_slug bot_id
  app_info=$(curl -s \
    -H "Authorization: token $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app" 2>/dev/null) || return 0

  app_slug=$(echo "$app_info" | jq -r '.slug // empty' 2>/dev/null)
  [[ -n "$app_slug" ]] || return 0

  # Get the bot user ID for the noreply email
  local bot_login="${app_slug}[bot]"
  local bot_user
  bot_user=$(curl -s \
    -H "Authorization: token $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/users/${bot_login}" 2>/dev/null) || true

  bot_id=$(echo "$bot_user" | jq -r '.id // empty' 2>/dev/null)

  local bot_name="${app_slug}[bot]"
  local bot_email
  if [[ -n "$bot_id" ]]; then
    bot_email="${bot_id}+${app_slug}[bot]@users.noreply.github.com"
  else
    bot_email="${app_id}+${app_slug}[bot]@users.noreply.github.com"
  fi

  git config user.name "$bot_name"
  git config user.email "$bot_email"
  hook_log "Configured git identity: $bot_name <$bot_email>"

  # Write GIT_AUTHOR_*/GIT_COMMITTER_* to the runtime env file so they are
  # available in ALL Bash commands (including sub-agent ones that may not be
  # in a directory with the project's .git/config).
  if [[ -n "${ENV_RUNTIME_FILE:-}" && -f "$ENV_RUNTIME_FILE" ]]; then
    cat >> "$ENV_RUNTIME_FILE" <<GITENV
export GIT_AUTHOR_NAME="$bot_name"
export GIT_AUTHOR_EMAIL="$bot_email"
export GIT_COMMITTER_NAME="$bot_name"
export GIT_COMMITTER_EMAIL="$bot_email"
GITENV
    hook_log "Git identity env vars written to runtime env file"
  fi

  # Save slug for use by PreToolUse hook output
  APP_SLUG="$app_slug"
}

configure_git_identity "$TOKEN" "$GITHUB_APP_ID"

# --- Print initial token info ---

hook_log "Authenticated as ${APP_SLUG:-app-$GITHUB_APP_ID} (expires: ${EXPIRES_AT:-unknown})"
hook_log "Token available via \$GH_TOKEN and \$GITHUB_TOKEN"

hook_log_cleanup
hook_respond
