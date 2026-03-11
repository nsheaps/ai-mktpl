#!/usr/bin/env bash
# token-status.sh — Check the current GitHub App token status
#
# Reads the token file and metadata to report:
# - Whether a token exists and is non-empty
# - When it expires
# - How many minutes remain
# - Which app/installation generated it
#
# Output: JSON object with token status
set -euo pipefail

TOKEN_FILE="${GITHUB_TOKEN_FILE:-$HOME/.config/agent/github-token}"
META_FILE="${TOKEN_FILE}.meta"

# Check if token exists
if [[ ! -f "$TOKEN_FILE" ]]; then
  jq -n '{valid: false, reason: "no token file", token_file: $tf}' --arg tf "$TOKEN_FILE"
  exit 0
fi

TOKEN=$(cat "$TOKEN_FILE")
if [[ -z "$TOKEN" ]]; then
  jq -n '{valid: false, reason: "token file is empty", token_file: $tf}' --arg tf "$TOKEN_FILE"
  exit 0
fi

# Check metadata
if [[ ! -f "$META_FILE" ]]; then
  jq -n '{valid: true, reason: "no metadata (cannot verify expiry)", token_file: $tf}' --arg tf "$TOKEN_FILE"
  exit 0
fi

META=$(cat "$META_FILE")
EXPIRES_AT=$(echo "$META" | jq -r '.expires_at // empty')

if [[ -z "$EXPIRES_AT" ]]; then
  echo "$META" | jq '. + {valid: true, reason: "no expiry in metadata"}'
  exit 0
fi

# Calculate remaining time
NOW=$(date +%s)
EXPIRY=$(date -d "$EXPIRES_AT" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES_AT" +%s 2>/dev/null || echo 0)

if [[ "$EXPIRY" -eq 0 ]]; then
  echo "$META" | jq '. + {valid: true, reason: "could not parse expiry"}'
  exit 0
fi

REMAINING=$((EXPIRY - NOW))
MINUTES_REMAINING=$((REMAINING / 60))

if [[ "$REMAINING" -le 0 ]]; then
  echo "$META" | jq '. + {valid: false, reason: "token expired", minutes_remaining: 0}'
else
  echo "$META" | jq --argjson mr "$MINUTES_REMAINING" '. + {valid: true, minutes_remaining: $mr}'
fi
