#!/usr/bin/env bash
# wait-for-env.sh — Wait for env vars to appear in CLAUDE_ENV_FILE
#
# Polls the shared env file for required variables to appear
# (written by another plugin's SessionStart hook, e.g. the 1pass plugin).
#
# Usage:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"
#
#   # Wait for vars to appear in CLAUDE_ENV_FILE, then source it
#   wait_for_env_file GITHUB_APP_ID GITHUB_APP_INSTALLATION_ID GITHUB_APP_PRIVATE_KEY --timeout 15

[[ -n "${_WAIT_FOR_ENV_LOADED:-}" ]] && return 0
_WAIT_FOR_ENV_LOADED=1

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
