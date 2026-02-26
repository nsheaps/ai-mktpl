#!/usr/bin/env bash
# session-start.sh — SessionStart hook for litellm-proxy plugin
#
# Detects LiteLLM proxy availability and configures Claude Code to route
# through it via CLAUDE_ENV_FILE. Handles four modes:
#   1. auto     — detect running proxy, configure if found
#   2. local    — always point at local proxy
#   3. remote   — point at a remote LiteLLM proxy
#   4. gateway  — point at an external gateway (Cloudflare AI Gateway, etc.)
#
# Config resolution order:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml → litellm-proxy
#   2. User-level:    ~/.claude/plugins.settings.yaml → litellm-proxy
#   3. Plugin-level:  ${CLAUDE_PLUGIN_ROOT}/config/litellm-proxy.settings.yaml
#
# Environment variable outputs (via CLAUDE_ENV_FILE):
#   - ANTHROPIC_BASE_URL: Points Claude Code at the proxy
#   - ANTHROPIC_AUTH_TOKEN: Master key for proxy authentication (if configured)
set -euo pipefail

# --- Write env var to CLAUDE_ENV_FILE ---

write_env() {
  local name="$1"
  local value="$2"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export ${name}=\"${value}\"" >> "$CLAUDE_ENV_FILE"
  fi
}

# --- Config resolution ---

read_config_key() {
  local file="$1"
  local key="$2"
  if [ -f "$file" ] && command -v yq &>/dev/null; then
    local val
    val="$(yq -r ".litellm-proxy.${key}" "$file" 2>/dev/null || true)"
    if [ -n "$val" ] && [ "$val" != "null" ]; then
      echo "$val"
      return 0
    fi
  fi
  return 1
}

get_config() {
  local key="$1"
  local default="$2"

  # 1. Project-level
  local project_config="${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml"
  local val
  if val="$(read_config_key "$project_config" "$key")"; then
    echo "$val"
    return
  fi

  # 2. User-level
  local user_config="$HOME/.claude/plugins.settings.yaml"
  if val="$(read_config_key "$user_config" "$key")"; then
    echo "$val"
    return
  fi

  # 3. Plugin-level defaults
  local plugin_config="${CLAUDE_PLUGIN_ROOT}/config/litellm-proxy.settings.yaml"
  if val="$(read_config_key "$plugin_config" "$key")"; then
    echo "$val"
    return
  fi

  # 4. Hardcoded default
  echo "$default"
}

# --- Resolve secret values (env var, 1Password, literal) ---

resolve_secret() {
  local raw="$1"
  local label="$2"

  # Empty/null
  if [ -z "$raw" ] || [ "$raw" = "null" ]; then
    echo ""
    return
  fi

  # env var reference: ${VAR_NAME}
  if [[ "$raw" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    local resolved="${!var_name:-}"
    if [ -z "$resolved" ]; then
      echo "INFO: litellm-proxy: env var $var_name is not set ($label)" >&2
    fi
    echo "$resolved"
    return
  fi

  # 1Password reference: op://vault/item/field
  if [[ "$raw" == op://* ]]; then
    if ! command -v op &>/dev/null; then
      echo "WARNING: litellm-proxy: 1Password CLI (op) not found, cannot resolve $label" >&2
      echo ""
      return
    fi
    local resolved
    resolved="$(op read "$raw" 2>/dev/null || true)"
    if [ -z "$resolved" ]; then
      echo "WARNING: litellm-proxy: failed to resolve 1Password ref for $label" >&2
    fi
    echo "$resolved"
    return
  fi

  # Literal value
  echo "$raw"
}

# --- Check if enabled ---

enabled="$(get_config "enabled" "true")"
if [ "$enabled" = "false" ]; then
  exit 0
fi

# --- Read config values ---

mode="$(get_config "mode" "auto")"
proxy_host="$(get_config "proxy_host" "http://localhost")"
proxy_port="$(get_config "proxy_port" "4000")"
master_key_raw="$(get_config "master_key" "")"
config_path="$(get_config "config_path" "")"
remote_url="$(get_config "remote_url" "")"
anthropic_pass_through="$(get_config "anthropic_pass_through" "true")"

# Resolve master key
master_key="$(resolve_secret "$master_key_raw" "master_key")"

# --- Determine proxy URL ---

get_proxy_url() {
  # If remote_url is set, use it directly (remote proxy or gateway)
  if [ -n "$remote_url" ] && [ "$remote_url" != "null" ]; then
    echo "$remote_url"
    return
  fi
  # Local proxy
  echo "${proxy_host}:${proxy_port}"
}

# --- Check if proxy is reachable ---

check_proxy_health() {
  local url="$1"
  if command -v curl &>/dev/null; then
    local status
    status="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 "${url}/health" 2>/dev/null || echo "000")"
    if [ "$status" = "200" ]; then
      return 0
    fi
  fi
  return 1
}

# --- Check if LiteLLM is installed ---

check_litellm_installed() {
  if command -v litellm &>/dev/null; then
    return 0
  fi
  if python3 -m litellm --help &>/dev/null 2>&1; then
    return 0
  fi
  if command -v docker &>/dev/null && docker image inspect ghcr.io/berriai/litellm:main-latest &>/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# --- Determine the base URL for Claude Code ---

get_claude_base_url() {
  local url="$1"
  if [ "$anthropic_pass_through" = "true" ]; then
    echo "${url}/anthropic"
  else
    echo "${url}"
  fi
}

# --- Main logic ---

proxy_url="$(get_proxy_url)"

case "$mode" in
  auto)
    if check_proxy_health "$proxy_url"; then
      base_url="$(get_claude_base_url "$proxy_url")"
    elif [ -n "$remote_url" ] && [ "$remote_url" != "null" ]; then
      echo "WARNING: litellm-proxy: remote proxy at $remote_url is not reachable" >&2
      base_url="$(get_claude_base_url "$proxy_url")"
    elif check_litellm_installed; then
      echo "INFO: litellm-proxy: LiteLLM is installed but proxy is not running" >&2
      echo "INFO: litellm-proxy: Use the setup-litellm skill to start the proxy" >&2
      exit 0
    else
      exit 0
    fi
    ;;
  local)
    base_url="$(get_claude_base_url "$proxy_url")"
    ;;
  remote)
    if [ -z "$remote_url" ] || [ "$remote_url" = "null" ]; then
      echo "ERROR: litellm-proxy: mode=remote but remote_url is not set" >&2
      exit 0
    fi
    base_url="$(get_claude_base_url "$remote_url")"
    ;;
  gateway)
    if [ -z "$remote_url" ] || [ "$remote_url" = "null" ]; then
      echo "ERROR: litellm-proxy: mode=gateway but remote_url is not set" >&2
      exit 0
    fi
    base_url="$remote_url"
    ;;
  disabled)
    # Nothing to write — env vars won't be set, Claude Code uses defaults
    exit 0
    ;;
  *)
    echo "WARNING: litellm-proxy: unknown mode '$mode', skipping" >&2
    exit 0
    ;;
esac

# --- Write env vars via CLAUDE_ENV_FILE ---

write_env "ANTHROPIC_BASE_URL" "$base_url"

if [ -n "$master_key" ]; then
  write_env "ANTHROPIC_AUTH_TOKEN" "$master_key"
fi
