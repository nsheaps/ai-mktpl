#!/usr/bin/env bash
# token-utils.sh — Shared token utility functions for the github-app plugin
#
# Requires: META_FILE to be set before sourcing
# Requires: jq

if [ "${_TOKEN_UTILS_LOADED:-}" = "true" ]; then return 0; fi
_TOKEN_UTILS_LOADED="true"

# Get token minutes remaining
# Returns: a number (minutes), or "unknown", "expired", "missing"
get_minutes_remaining() {
  if [[ ! -f "$META_FILE" ]]; then
    echo "missing"
    return
  fi

  local expires_at
  expires_at=$(jq -r '.expires_at // empty' "$META_FILE" 2>/dev/null)
  if [[ -z "$expires_at" ]]; then
    echo "unknown"
    return
  fi

  local now expiry
  now=$(date +%s)
  expiry=$(date -d "$expires_at" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || echo 0)

  if (( expiry == 0 )); then
    echo "unknown"
    return
  fi

  local remaining=$(( (expiry - now) / 60 ))
  if (( remaining <= 0 )); then
    echo "expired"
  else
    echo "$remaining"
  fi
}
