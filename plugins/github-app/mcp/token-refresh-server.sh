#!/usr/bin/env bash
# token-refresh-server.sh — Lightweight MCP stdio server for GitHub App token refresh
#
# This server runs as a background MCP process in Claude Code sessions.
# It provides tools for checking token status and forcing refresh,
# and runs a background loop to refresh the token before it expires.
#
# Protocol: JSON-RPC 2.0 over stdio (MCP)
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.config/agent/github-token}"
META_FILE="${TOKEN_FILE}.meta"
REFRESH_INTERVAL="${GITHUB_TOKEN_REFRESH_INTERVAL:-3000}" # seconds (50 minutes)

# --- Background refresh loop ---

start_refresh_loop() {
  while true; do
    sleep "$REFRESH_INTERVAL"

    # Check if token file still exists (plugin might be disabled)
    [[ -f "$META_FILE" ]] || continue

    # Check if we have the required env vars
    [[ -n "${GITHUB_APP_ID:-}" && -n "${GITHUB_APP_PRIVATE_KEY_PATH:-}" && -n "${GITHUB_INSTALLATION_ID:-}" ]] || continue

    # Refresh the token
    "$PLUGIN_ROOT/bin/generate-token.sh" \
      "$GITHUB_APP_ID" \
      "$GITHUB_APP_PRIVATE_KEY_PATH" \
      "$GITHUB_INSTALLATION_ID" \
      "$TOKEN_FILE" >/dev/null 2>&1 || echo "Token refresh failed" >&2
  done
}

# Start background refresh loop
start_refresh_loop &
REFRESH_PID=$!
trap "kill $REFRESH_PID 2>/dev/null; exit 0" EXIT INT TERM

# --- MCP Protocol Handlers ---

send_response() {
  local id="$1"
  local result="$2"
  printf '{"jsonrpc":"2.0","id":%s,"result":%s}\n' "$id" "$result"
}

send_error() {
  local id="$1"
  local code="$2"
  local message="$3"
  printf '{"jsonrpc":"2.0","id":%s,"error":{"code":%s,"message":%s}}\n' "$id" "$code" "$(echo "$message" | jq -Rsa .)"
}

handle_initialize() {
  local id="$1"
  send_response "$id" '{
    "protocolVersion": "2024-11-05",
    "capabilities": {"tools": {"listChanged": false}},
    "serverInfo": {"name": "github-app-token-refresh", "version": "0.1.0"}
  }'
}

handle_tools_list() {
  local id="$1"
  send_response "$id" '{
    "tools": [
      {
        "name": "token-status",
        "description": "Check the current GitHub App token status, including validity, expiry time, and minutes remaining",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
      },
      {
        "name": "refresh-github-token",
        "description": "Force an immediate refresh of the GitHub App installation token",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
      },
      {
        "name": "get-github-token",
        "description": "Get the current valid GitHub App token value",
        "inputSchema": {"type": "object", "properties": {}, "required": []}
      }
    ]
  }'
}

handle_tool_call() {
  local id="$1"
  local tool_name="$2"

  case "$tool_name" in
    token-status)
      local status
      status=$("$PLUGIN_ROOT/bin/token-status.sh" 2>&1) || status='{"valid":false,"reason":"status check failed"}'
      local escaped
      escaped=$(echo "$status" | jq -Rsa .)
      printf '{"jsonrpc":"2.0","id":%s,"result":{"content":[{"type":"text","text":%s}]}}\n' "$id" "$escaped"
      return
      ;;
    refresh-github-token)
      if [[ -z "${GITHUB_APP_ID:-}" || -z "${GITHUB_APP_PRIVATE_KEY_PATH:-}" || -z "${GITHUB_INSTALLATION_ID:-}" ]]; then
        send_response "$id" '{"content":[{"type":"text","text":"GitHub App not configured (missing env vars)"}]}'
        return
      fi
      local output
      output=$("$PLUGIN_ROOT/bin/generate-token.sh" \
        "$GITHUB_APP_ID" \
        "$GITHUB_APP_PRIVATE_KEY_PATH" \
        "$GITHUB_INSTALLATION_ID" \
        "$TOKEN_FILE" 2>&1) || output="Refresh failed: $output"
      local escaped_output
      escaped_output=$(echo "$output" | jq -Rsa .)
      printf '{"jsonrpc":"2.0","id":%s,"result":{"content":[{"type":"text","text":%s}]}}\n' "$id" "$escaped_output"
      return
      ;;
    get-github-token)
      if [[ -f "$TOKEN_FILE" ]]; then
        local token
        token=$(cat "$TOKEN_FILE")
        local escaped_token
        escaped_token=$(echo "$token" | jq -Rsa .)
        printf '{"jsonrpc":"2.0","id":%s,"result":{"content":[{"type":"text","text":%s}]}}\n' "$id" "$escaped_token"
        return
      else
        send_response "$id" '{"content":[{"type":"text","text":"No token file found"}]}'
      fi
      ;;
    *)
      send_error "$id" -32601 "Unknown tool: $tool_name"
      ;;
  esac
}

# --- Main loop: read JSON-RPC messages from stdin ---

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  method=$(echo "$line" | jq -r '.method // empty' 2>/dev/null) || continue
  id=$(echo "$line" | jq -r '.id // "null"' 2>/dev/null)

  case "$method" in
    initialize)
      handle_initialize "$id"
      ;;
    notifications/initialized)
      # No response needed for notifications
      ;;
    tools/list)
      handle_tools_list "$id"
      ;;
    tools/call)
      tool_name=$(echo "$line" | jq -r '.params.name // empty')
      handle_tool_call "$id" "$tool_name"
      ;;
    *)
      if [[ "$id" != "null" ]]; then
        send_error "$id" -32601 "Method not found: $method"
      fi
      ;;
  esac
done
