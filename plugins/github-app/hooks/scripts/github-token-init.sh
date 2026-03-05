#!/usr/bin/env bash
# github-token-init.sh — SessionStart hook for github-app plugin
#
# Generates a GitHub App installation token on session start.
# Supports multiple secret sources:
#   - Literal values in settings
#   - Environment variable references: ${VAR_NAME}
#   - 1Password field references: op://vault/item/field
#   - 1Password item reference (via op_item): fetches all fields as env vars
#
# Writes token to a shared file readable by gh CLI, git, and MCP server.
set -euo pipefail

PLUGIN_NAME="github-app"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# --- Guards ---

plugin_is_enabled || { echo '{}'; exit 0; }

# --- Secret resolution ---

# Resolve a secret value from one of:
#   - ${VAR_NAME}       → expand from environment
#   - op://vault/item/field → resolve via `op read`
#   - literal           → use as-is
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
      echo "${PLUGIN_NAME}: WARNING: env var $var_name is not set (for $name)" >&2
    fi
    echo "$resolved"
    return
  fi

  # 1Password reference: op://vault/item/field
  if [[ "$raw" == op://* ]]; then
    if ! command -v op &>/dev/null; then
      echo "${PLUGIN_NAME}: WARNING: 1Password CLI (op) not found, cannot resolve $name" >&2
      echo ""
      return
    fi
    local resolved
    resolved="$(op read "$raw" 2>/dev/null || true)"
    if [[ -z "$resolved" ]]; then
      echo "${PLUGIN_NAME}: WARNING: failed to resolve 1Password ref for $name" >&2
    fi
    echo "$resolved"
    return
  fi

  # Literal value
  echo "$raw"
}

# --- Load secrets ---

# Strategy 1: op_item — fetch all secrets from a single 1Password item via op-exec
# The item fields are converted to env vars (GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, etc.)
OP_ITEM="$(plugin_get_config "op_item" "")"

if [[ -n "$OP_ITEM" ]]; then
  if [[ "$OP_ITEM" != op://* ]]; then
    echo "${PLUGIN_NAME}: op_item must be an op:// reference, got: $OP_ITEM" >&2
    echo '{}'
    exit 0
  fi

  # Find op-exec: check PATH, then common locations
  OP_EXEC=""
  if command -v op-exec &>/dev/null; then
    OP_EXEC="$(command -v op-exec)"
  elif [[ -x "${CLAUDE_PROJECT_DIR:-}/bin/op-exec" ]]; then
    OP_EXEC="${CLAUDE_PROJECT_DIR}/bin/op-exec"
  fi

  if [[ -z "$OP_EXEC" ]]; then
    echo "${PLUGIN_NAME}: op-exec not found (needed for op_item), install nsheaps/op-exec" >&2
    echo '{}'
    exit 0
  fi

  if ! command -v op &>/dev/null; then
    echo "${PLUGIN_NAME}: 1Password CLI (op) not found, cannot resolve op_item" >&2
    echo '{}'
    exit 0
  fi

  # Source the env vars from the 1Password item
  eval "$("$OP_EXEC" "$OP_ITEM")" || {
    echo "${PLUGIN_NAME}: Failed to fetch secrets from $OP_ITEM" >&2
    echo '{}'
    exit 0
  }

  echo "${PLUGIN_NAME}: Loaded secrets from 1Password item" >&2
fi

# Strategy 2: Individual secret settings (override env vars if present)
# Each secrets.* value can be a literal, ${ENV_VAR}, or op://vault/item/field
SECRETS_APP_ID="$(plugin_get_config "secrets.github_app_id" "")"
SECRETS_CLIENT_ID="$(plugin_get_config "secrets.github_app_client_id" "")"
SECRETS_CLIENT_SECRET="$(plugin_get_config "secrets.github_app_client_secret" "")"
SECRETS_PRIVATE_KEY="$(plugin_get_config "secrets.github_app_private_key" "")"
SECRETS_INSTALLATION_ID="$(plugin_get_config "secrets.github_installation_id" "")"

# Resolve individual secrets if configured (these take priority over op_item env vars)
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

# GITHUB_APP_PRIVATE_KEY contains the key content directly (e.g., from 1Password)
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
  echo "${PLUGIN_NAME}: Wrote private key to $GITHUB_APP_PRIVATE_KEY_PATH" >&2
fi

# --- Validate required credentials ---

if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" || -z "${GITHUB_INSTALLATION_ID:-}" ]]; then
  echo "${PLUGIN_NAME}: GitHub App not configured (missing APP_ID, PRIVATE_KEY_PATH/PRIVATE_KEY, or INSTALLATION_ID), skipping" >&2
  echo '{}'
  exit 0
fi

# Expand tilde in key path
GITHUB_APP_PRIVATE_KEY_PATH="${GITHUB_APP_PRIVATE_KEY_PATH/#\~/$HOME}"

if [[ ! -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]]; then
  echo "${PLUGIN_NAME}: PEM key not found at $GITHUB_APP_PRIVATE_KEY_PATH" >&2
  echo '{}'
  exit 0
fi

# Validate PEM file permissions
PERMS=$(stat -c '%a' "$GITHUB_APP_PRIVATE_KEY_PATH" 2>/dev/null || stat -f '%Lp' "$GITHUB_APP_PRIVATE_KEY_PATH" 2>/dev/null || echo "unknown")
if [[ "$PERMS" != "600" && "$PERMS" != "400" && "$PERMS" != "unknown" ]]; then
  echo "${PLUGIN_NAME}: WARNING: PEM key has permissions $PERMS, should be 600 or 400" >&2
fi

# --- Token generation ---

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$(plugin_get_config "token_file" "$HOME/.config/agent/github-token")}"
TOKEN_FILE="${TOKEN_FILE/#\~/$HOME}"
mkdir -p "$(dirname "$TOKEN_FILE")"

# Use the shared JWT generation script
TOKEN_OUTPUT=$("${CLAUDE_PLUGIN_ROOT}/bin/generate-token.sh" \
  "$GITHUB_APP_ID" \
  "$GITHUB_APP_PRIVATE_KEY_PATH" \
  "$GITHUB_INSTALLATION_ID" \
  "$TOKEN_FILE" 2>&1) || {
  echo "${PLUGIN_NAME}: Token generation failed: $TOKEN_OUTPUT" >&2
  echo '{}'
  exit 0
}

echo "${PLUGIN_NAME}: $TOKEN_OUTPUT" >&2

# Export token and related vars for this session via CLAUDE_ENV_FILE
if [[ -n "${CLAUDE_ENV_FILE:-}" && -f "$TOKEN_FILE" ]]; then
  TOKEN=$(cat "$TOKEN_FILE")
  echo "export GH_TOKEN=\"$TOKEN\"" >> "$CLAUDE_ENV_FILE"
  echo "export GITHUB_TOKEN=\"$TOKEN\"" >> "$CLAUDE_ENV_FILE"
  echo "export GITHUB_TOKEN_FILE=\"$TOKEN_FILE\"" >> "$CLAUDE_ENV_FILE"

  # Also export app metadata for the MCP server refresh loop
  echo "export GITHUB_APP_ID=\"$GITHUB_APP_ID\"" >> "$CLAUDE_ENV_FILE"
  echo "export GITHUB_APP_PRIVATE_KEY_PATH=\"$GITHUB_APP_PRIVATE_KEY_PATH\"" >> "$CLAUDE_ENV_FILE"
  echo "export GITHUB_INSTALLATION_ID=\"$GITHUB_INSTALLATION_ID\"" >> "$CLAUDE_ENV_FILE"

  # Export optional credentials if available
  [[ -n "${GITHUB_APP_CLIENT_ID:-}" ]] && echo "export GITHUB_APP_CLIENT_ID=\"$GITHUB_APP_CLIENT_ID\"" >> "$CLAUDE_ENV_FILE"
  [[ -n "${GITHUB_APP_CLIENT_SECRET:-}" ]] && echo "export GITHUB_APP_CLIENT_SECRET=\"$GITHUB_APP_CLIENT_SECRET\"" >> "$CLAUDE_ENV_FILE"
fi

echo '{}'
