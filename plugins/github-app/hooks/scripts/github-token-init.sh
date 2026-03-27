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
# Static env file: PATH/alias lines that must not be overwritten on token refresh.
# token-check.sh only ever rewrites ENV_RUNTIME_FILE; it never touches this file.
ENV_STATIC_FILE="${HOME}/.config/agent/github-app-env-static"
mkdir -p "$(dirname "$ENV_RUNTIME_FILE")"

# Write token-only vars (overwritten on every refresh by token-check.sh)
cat > "$ENV_RUNTIME_FILE" <<ENVEOF
# Auto-generated by github-app plugin — do not edit manually.
# This file is rewritten on every token refresh. Add nothing else here.
export GH_TOKEN="$TOKEN"
export GITHUB_TOKEN="$TOKEN"
export GITHUB_TOKEN_FILE="$TOKEN_FILE"
export GITHUB_APP_TOKEN_FILE="$TOKEN_FILE"
export GITHUB_APP_ENV_FILE="$ENV_RUNTIME_FILE"
export GITHUB_APP_ID="$GITHUB_APP_ID"
export GITHUB_APP_PRIVATE_KEY_PATH="$GITHUB_APP_PRIVATE_KEY_PATH"
export GITHUB_INSTALLATION_ID="$GITHUB_INSTALLATION_ID"
ENVEOF
[[ -n "${GITHUB_APP_CLIENT_ID:-}" ]] && echo "export GITHUB_APP_CLIENT_ID=\"$GITHUB_APP_CLIENT_ID\"" >> "$ENV_RUNTIME_FILE"
[[ -n "${GITHUB_APP_CLIENT_SECRET:-}" ]] && echo "export GITHUB_APP_CLIENT_SECRET=\"$GITHUB_APP_CLIENT_SECRET\"" >> "$ENV_RUNTIME_FILE"
chmod 600 "$ENV_RUNTIME_FILE"

# Write static lines to a separate file that token-check.sh never touches.
# PATH additions and aliases must survive token refreshes.
cat > "$ENV_STATIC_FILE" <<STATICEOF
# Auto-generated by github-app plugin (session start only) — do not edit manually.
# This file is NOT rewritten on token refresh; only on session start.
export PATH="${CLAUDE_PLUGIN_ROOT}/bin:\$PATH"
# Use a shell function instead of an alias so that gh is intercepted reliably
# in both interactive and non-interactive bash. Aliases require
# 'shopt -s expand_aliases' which is not the default in non-interactive shells.
gh() { "${CLAUDE_PLUGIN_ROOT}/bin/gh-wrapper.sh" "\$@"; }
export -f gh
STATICEOF
chmod 600 "$ENV_STATIC_FILE"

# Source both env files from CLAUDE_ENV_FILE so all Bash commands
# get the token. ENV_RUNTIME_FILE is re-sourced on each command, picking up
# any refreshes done by the PreToolUse hook. ENV_STATIC_FILE is also sourced
# so PATH and aliases are always available even after a token refresh.
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "source \"$ENV_RUNTIME_FILE\"" >> "$CLAUDE_ENV_FILE"
  echo "source \"$ENV_STATIC_FILE\"" >> "$CLAUDE_ENV_FILE"
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

  hook_log_step "git-identity" "Configuring git identity env vars from GitHub App"

  # Fetch the App's slug (name) from the API using the already-set GH_TOKEN
  local app_slug bot_id
  app_slug=$(GH_TOKEN="$TOKEN" gh api /app --jq '.slug // empty' 2>/dev/null) || true
  [[ -n "$app_slug" ]] || return 0

  # Get the bot user ID for the noreply email
  bot_id=$(GH_TOKEN="$TOKEN" gh api "/users/${app_slug}[bot]" --jq '.id // empty' 2>/dev/null) || true

  local bot_name="${app_slug}[bot]"
  local bot_email
  if [[ -n "$bot_id" ]]; then
    bot_email="${bot_id}+${app_slug}[bot]@users.noreply.github.com"
  else
    bot_email="${GITHUB_APP_ID}+${app_slug}[bot]@users.noreply.github.com"
  fi

  # Export into current process so the rest of this hook sees them
  export GIT_AUTHOR_NAME="$bot_name"
  export GIT_AUTHOR_EMAIL="$bot_email"
  export GIT_COMMITTER_NAME="$bot_name"
  export GIT_COMMITTER_EMAIL="$bot_email"

  # Append to the static env file so git identity survives token refreshes.
  # Do NOT append to ENV_RUNTIME_FILE — that file is overwritten on each refresh.
  cat >> "$ENV_STATIC_FILE" <<GITENVEOF
export GIT_AUTHOR_NAME="$bot_name"
export GIT_AUTHOR_EMAIL="$bot_email"
export GIT_COMMITTER_NAME="$bot_name"
export GIT_COMMITTER_EMAIL="$bot_email"
GITENVEOF

  hook_log "Configured git identity env vars: $bot_name <$bot_email>"

  # Save slug for use by hook output logging
  APP_SLUG="$app_slug"
}

configure_git_identity_env

# --- Print initial token info ---

hook_log "Authenticated as ${APP_SLUG:-app-$GITHUB_APP_ID} (expires: ${EXPIRES_AT:-unknown})"
hook_log "Token available via \$GH_TOKEN and \$GITHUB_TOKEN"

hook_log_cleanup
hook_respond
