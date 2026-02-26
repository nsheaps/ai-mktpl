#!/usr/bin/env bash
# session-start.sh — SessionStart hook for litellm-proxy plugin
#
# Detects LiteLLM proxy availability and configures Claude Code to route
# through it via CLAUDE_ENV_FILE. Handles four modes:
#   auto     — detect running proxy, configure if found
#   local    — always point at local proxy
#   remote   — point at a remote LiteLLM proxy
#   gateway  — point at an external gateway (Cloudflare AI Gateway, etc.)
#
# Environment variable outputs (via CLAUDE_ENV_FILE):
#   - ANTHROPIC_BASE_URL: Points Claude Code at the proxy
#   - ANTHROPIC_AUTH_TOKEN: Master key for proxy authentication (if configured)
set -euo pipefail

# --- Source shared config lib ---

PLUGIN_NAME="litellm-proxy"
SHARED_LIB="${CLAUDE_PLUGIN_ROOT}/lib/plugin-config.sh"
if [ ! -f "$SHARED_LIB" ]; then
  echo "ERROR: shared lib not found: $SHARED_LIB" >&2
  exit 2
fi
source "$SHARED_LIB"

# --- Write env var to CLAUDE_ENV_FILE ---

write_env() {
  local name="$1"
  local value="$2"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export ${name}=\"${value}\"" >> "$CLAUDE_ENV_FILE"
  fi
}

# --- Check if enabled ---

if ! plugin_is_enabled; then
  exit 0
fi

# --- Read config values ---

mode="$(plugin_config "mode" "auto")"
proxy_host="$(plugin_config "proxy_host" "http://localhost")"
proxy_port="$(plugin_config "proxy_port" "4000")"
master_key_raw="$(plugin_config "master_key" "")"
remote_url="$(plugin_config "remote_url" "")"
anthropic_pass_through="$(plugin_config "anthropic_pass_through" "true")"

# Resolve master key
master_key="$(plugin_resolve_secret "$master_key_raw" "master_key")"

# --- Determine proxy URL ---

get_proxy_url() {
  if [ -n "$remote_url" ] && [ "$remote_url" != "null" ]; then
    echo "$remote_url"
    return
  fi
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
