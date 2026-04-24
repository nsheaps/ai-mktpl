#!/usr/bin/env bash
# wait-for-env.sh — Wait for environment variables to become available
#
# Used when plugins depend on env vars injected by other plugins'
# SessionStart hooks. Claude Code doesn't guarantee hook execution order,
# so a plugin that needs vars from another plugin should poll and wait.
#
# Usage:
#   source "${CLAUDE_PLUGIN_ROOT}/lib/wait-for-env.sh"
#   wait_for_env GITHUB_APP_ID GITHUB_APP_PRIVATE_KEY_PATH --timeout 15
#
# Returns 0 if all vars are set, 1 on timeout.

[[ -n "${_WAIT_FOR_ENV_LOADED:-}" ]] && return 0
_WAIT_FOR_ENV_LOADED=1

wait_for_env() {
  local timeout=15
  local vars=()

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout) timeout="$2"; shift 2 ;;
      *) vars+=("$1"); shift ;;
    esac
  done

  [[ ${#vars[@]} -eq 0 ]] && return 0

  local elapsed=0
  local interval=1
  local max_interval=4

  while (( elapsed < timeout )); do
    # Check if all vars are set and non-empty
    local all_set=true
    for var in "${vars[@]}"; do
      if [[ -z "${!var:-}" ]]; then
        all_set=false
        break
      fi
    done

    if [[ "$all_set" == "true" ]]; then
      return 0
    fi

    sleep "$interval"
    elapsed=$(( elapsed + interval ))
    interval=$(( interval * 2 ))
    (( interval > max_interval )) && interval=$max_interval
  done

  return 1
}
