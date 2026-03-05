#!/usr/bin/env bash
# sync-permissions.sh — SessionStart hook for permissions-sync plugin
#
# Reads permission scopes from configured source settings.json files
# and merges them into settings.local.json (project or user level).
#
# Sources can be:
#   - Local file paths (with env var expansion)
#   - GitHub repo references: "github:owner/repo:path"
set -euo pipefail

PLUGIN_NAME="permissions-sync"
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# --- Check if enabled ---

plugin_is_enabled || { echo '{}'; exit 0; }

# --- Check for jq ---

if ! command -v jq &>/dev/null; then
  echo "${PLUGIN_NAME}: jq required but not found" >&2
  echo '{}'
  exit 0
fi

# --- Read config ---

target="$(plugin_get_config "target" "project")"
syncAllow="$(plugin_get_config "syncAllow" "true")"
syncDeny="$(plugin_get_config "syncDeny" "true")"
syncAsk="$(plugin_get_config "syncAsk" "true")"
strategy="$(plugin_get_config "strategy" "union")"

# Determine target file
if [ "$target" = "user" ]; then
  SETTINGS_FILE="$HOME/.claude/settings.local.json"
else
  SETTINGS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"
fi

# Source shared lib
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"

# --- Fetch permissions from a source ---

expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  eval "p=\"$p\"" 2>/dev/null || true
  echo "$p"
}

fetch_source_permissions() {
  local source="$1"

  # GitHub repo reference: github:owner/repo:path
  if [[ "$source" == github:* ]]; then
    local remainder="${source#github:}"
    local repo="${remainder%%:*}"
    local path="${remainder#*:}"

    if command -v gh &>/dev/null; then
      local content
      content="$(gh api "repos/${repo}/contents/${path}" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)"
      if [ -n "$content" ]; then
        echo "$content" | jq '.permissions // empty' 2>/dev/null || true
        return
      fi
    fi

    # Fallback: curl with raw GitHub API
    local raw_url="https://raw.githubusercontent.com/${repo}/main/${path}"
    local content
    content="$(curl -fsSL "$raw_url" 2>/dev/null || true)"
    if [ -n "$content" ]; then
      echo "$content" | jq '.permissions // empty' 2>/dev/null || true
      return
    fi

    echo "${PLUGIN_NAME}: Could not fetch from github:${repo}:${path}" >&2
    return
  fi

  # Local file
  local filepath
  filepath="$(expand_path "$source")"
  if [ -f "$filepath" ]; then
    jq '.permissions // empty' "$filepath" 2>/dev/null || true
  else
    echo "${PLUGIN_NAME}: Source file not found: $filepath" >&2
  fi
}

# --- Collect sources ---

sources="$(plugin_get_config_array "sources")"
if [ -z "$sources" ]; then
  echo "${PLUGIN_NAME}: No sources configured" >&2
  echo '{}'
  exit 0
fi

# --- Merge permissions ---

merged='{"allow":[],"deny":[],"ask":[]}'

while IFS= read -r source; do
  [ -z "$source" ] && continue
  echo "${PLUGIN_NAME}: Reading permissions from: $source" >&2

  perms="$(fetch_source_permissions "$source")"
  if [ -z "$perms" ] || [ "$perms" = "null" ]; then
    echo "${PLUGIN_NAME}: No permissions found in $source" >&2
    continue
  fi

  for cat in allow deny ask; do
    case "$cat" in
      allow) sync_flag="$syncAllow" ;;
      deny)  sync_flag="$syncDeny" ;;
      ask)   sync_flag="$syncAsk" ;;
    esac
    [ "$sync_flag" != "true" ] && continue

    if [ "$strategy" = "union" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" --arg c "$cat" '
        .[$c] = (.[$c] + ($src[$c] // []) | unique)
      ' 2>/dev/null || echo "$merged")"
    else
      merged="$(echo "$merged" | jq --argjson src "$perms" --arg c "$cat" '
        .[$c] = ($src[$c] // .[$c])
      ' 2>/dev/null || echo "$merged")"
    fi
  done
done <<< "$sources"

# --- Remove empty arrays ---

merged="$(echo "$merged" | jq 'with_entries(select(.value | length > 0))' 2>/dev/null || echo "$merged")"

# --- Check if there's anything to write ---

if [ "$merged" = "{}" ] || [ -z "$merged" ]; then
  echo "${PLUGIN_NAME}: No permissions to sync" >&2
  echo '{}'
  exit 0
fi

# --- Write to settings.local.json ---

mkdir -p "$(dirname "$SETTINGS_FILE")"

export PERMS_JSON="$merged"

safe_write_settings '.permissions = (
  (.permissions // {}) * ($ENV.PERMS_JSON | fromjson)
)'

count_allow="$(echo "$merged" | jq '.allow // [] | length' 2>/dev/null || echo "0")"
count_deny="$(echo "$merged" | jq '.deny // [] | length' 2>/dev/null || echo "0")"
count_ask="$(echo "$merged" | jq '.ask // [] | length' 2>/dev/null || echo "0")"
echo "${PLUGIN_NAME}: Synced permissions to $SETTINGS_FILE (allow: $count_allow, deny: $count_deny, ask: $count_ask)" >&2

echo '{}'
