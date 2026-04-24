#!/usr/bin/env bash
# resolve-secrets.sh — Resolve op:// references and wait for env file fallback
#
# Provides two mechanisms for cross-plugin secret resolution:
#
# 1. Direct op:// resolution: If `op` is installed and OP_SERVICE_ACCOUNT_TOKEN
#    is set, resolve op:// references directly without depending on 1pass plugin.
#
# 2. CLAUDE_ENV_FILE fallback: Poll the shared env file for required variables
#    to appear (written by another plugin's SessionStart hook).
#
# Usage:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/resolve-secrets.sh"
#
#   # Try to resolve an op:// reference
#   value=$(resolve_op_ref "op://vault/item/field")
#
#   # Wait for vars to appear in CLAUDE_ENV_FILE, then source it
#   wait_for_env_file GITHUB_APP_ID GITHUB_INSTALLATION_ID --timeout 15

[[ -n "${_RESOLVE_SECRETS_LOADED:-}" ]] && return 0
_RESOLVE_SECRETS_LOADED=1

# Check if op CLI is available and authenticated
_op_available() {
  command -v op >/dev/null 2>&1 && [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]
}

# Resolve an op:// reference to its value
# Returns 0 and prints the value on success, 1 on failure
resolve_op_ref() {
  local ref="$1"
  if ! _op_available; then
    return 1
  fi
  op read "$ref" 2>/dev/null
}

# Wait for env vars to appear in CLAUDE_ENV_FILE, then source it
wait_for_env_file() {
  local timeout=15
  local vars=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout) timeout="$2"; shift 2 ;;
      *) vars+=("$1"); shift ;;
    esac
  done

  [[ ${#vars[@]} -eq 0 ]] && return 0

  local env_file="${CLAUDE_ENV_FILE:-}"
  if [[ -z "$env_file" ]]; then
    return 1  # No env file mechanism available
  fi

  local elapsed=0
  local interval=1
  local max_interval=4

  while (( elapsed < timeout )); do
    if [[ -f "$env_file" ]]; then
      # Check if all required vars are exported in the file
      local all_found=true
      for var in "${vars[@]}"; do
        if ! grep -q "^export ${var}=" "$env_file" 2>/dev/null; then
          all_found=false
          break
        fi
      done

      if [[ "$all_found" == "true" ]]; then
        # Source the file to make vars available in this process
        # shellcheck disable=SC1090
        source "$env_file"
        return 0
      fi
    fi

    sleep "$interval"
    elapsed=$(( elapsed + interval ))
    interval=$(( interval * 2 ))
    (( interval > max_interval )) && interval=$max_interval
  done

  return 1
}
