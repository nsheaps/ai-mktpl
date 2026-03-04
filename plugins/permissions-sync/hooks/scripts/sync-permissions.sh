#!/usr/bin/env bash
# sync-permissions.sh — SessionStart hook for permissions-sync plugin
#
# Reads permission scopes from configured source settings.json files
# and merges them into settings.local.json (project or user level).
#
# Sources can be:
#   - Local file paths (with env var expansion)
#   - GitHub repo references: "github:owner/repo:path"
#
# Config resolution order:
#   1. Project-level: ${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.yaml → permissions-sync
#   2. User-level:    ~/.claude/plugins.settings.yaml → permissions-sync
#   3. Plugin-level:  ${CLAUDE_PLUGIN_ROOT}/permissions-sync.settings.yaml → permissions-sync
set -euo pipefail

# --- Config reading ---

read_config_key() {
  local file="$1" key="$2"
  if [ -f "$file" ]; then
    if command -v yq &>/dev/null; then
      local val
      val="$(yq -r ".permissions-sync.${key}" "$file" 2>/dev/null || true)"
      if [ -n "$val" ] && [ "$val" != "null" ]; then
        echo "$val"
        return 0
      fi
    fi
  fi
  return 1
}

read_config_array() {
  local file="$1" key="$2"
  if [ -f "$file" ] && command -v yq &>/dev/null; then
    local val
    val="$(yq -r ".permissions-sync.${key}[]?" "$file" 2>/dev/null || true)"
    if [ -n "$val" ]; then
      echo "$val"
      return 0
    fi
  fi
  return 1
}

get_config() {
  local key="$1" default="$2"
  local val

  if val="$(read_config_key "${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  if val="$(read_config_key "$HOME/.claude/plugins.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  if val="$(read_config_key "${CLAUDE_PLUGIN_ROOT}/permissions-sync.settings.yaml" "$key")"; then
    echo "$val"; return
  fi
  echo "$default"
}

get_sources() {
  local sources

  if sources="$(read_config_array "${CLAUDE_PROJECT_DIR:-.}/.claude/plugins.settings.yaml" "sources")"; then
    echo "$sources"; return
  fi
  if sources="$(read_config_array "$HOME/.claude/plugins.settings.yaml" "sources")"; then
    echo "$sources"; return
  fi
  if sources="$(read_config_array "${CLAUDE_PLUGIN_ROOT}/permissions-sync.settings.yaml" "sources")"; then
    echo "$sources"; return
  fi
}

# --- Check if enabled ---

enabled="$(get_config "enabled" "true")"
if [ "$enabled" = "false" ]; then
  echo '{}'
  exit 0
fi

# --- Check for jq ---

if ! command -v jq &>/dev/null; then
  echo "permissions-sync: jq required but not found" >&2
  echo '{}'
  exit 0
fi

# --- Read config ---

target="$(get_config "target" "project")"
sync_allow="$(get_config "sync_allow" "true")"
sync_deny="$(get_config "sync_deny" "true")"
sync_ask="$(get_config "sync_ask" "true")"
strategy="$(get_config "strategy" "union")"

# Determine target file
if [ "$target" = "user" ]; then
  SETTINGS_FILE="$HOME/.claude/settings.local.json"
else
  SETTINGS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"
fi

# Source shared lib
SHARED_LIB="${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
if [ -f "$SHARED_LIB" ]; then
  source "$SHARED_LIB"
else
  echo "permissions-sync: shared lib not found at $SHARED_LIB" >&2
  echo '{}'
  exit 0
fi

# --- Fetch permissions from a source ---

expand_path() {
  local p="$1"
  # Expand ~ and environment variables
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

    echo "permissions-sync: Could not fetch from github:${repo}:${path}" >&2
    return
  fi

  # Local file
  local filepath
  filepath="$(expand_path "$source")"
  if [ -f "$filepath" ]; then
    jq '.permissions // empty' "$filepath" 2>/dev/null || true
  else
    echo "permissions-sync: Source file not found: $filepath" >&2
  fi
}

# --- Collect sources ---

sources="$(get_sources)"
if [ -z "$sources" ]; then
  echo "permissions-sync: No sources configured" >&2
  echo '{}'
  exit 0
fi

# --- Merge permissions ---

# Start with empty permissions object
merged='{"allow":[],"deny":[],"ask":[]}'

while IFS= read -r source; do
  [ -z "$source" ] && continue
  echo "permissions-sync: Reading permissions from: $source" >&2

  perms="$(fetch_source_permissions "$source")"
  if [ -z "$perms" ] || [ "$perms" = "null" ]; then
    echo "permissions-sync: No permissions found in $source" >&2
    continue
  fi

  if [ "$strategy" = "union" ]; then
    # Union: combine arrays, deduplicate
    if [ "$sync_allow" = "true" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" '
        .allow = (.allow + ($src.allow // []) | unique)
      ' 2>/dev/null || echo "$merged")"
    fi
    if [ "$sync_deny" = "true" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" '
        .deny = (.deny + ($src.deny // []) | unique)
      ' 2>/dev/null || echo "$merged")"
    fi
    if [ "$sync_ask" = "true" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" '
        .ask = (.ask + ($src.ask // []) | unique)
      ' 2>/dev/null || echo "$merged")"
    fi
  else
    # Replace: last source wins
    if [ "$sync_allow" = "true" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" '
        .allow = ($src.allow // .allow)
      ' 2>/dev/null || echo "$merged")"
    fi
    if [ "$sync_deny" = "true" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" '
        .deny = ($src.deny // .deny)
      ' 2>/dev/null || echo "$merged")"
    fi
    if [ "$sync_ask" = "true" ]; then
      merged="$(echo "$merged" | jq --argjson src "$perms" '
        .ask = ($src.ask // .ask)
      ' 2>/dev/null || echo "$merged")"
    fi
  fi
done <<< "$sources"

# --- Remove empty arrays ---

merged="$(echo "$merged" | jq 'with_entries(select(.value | length > 0))' 2>/dev/null || echo "$merged")"

# --- Check if there's anything to write ---

if [ "$merged" = "{}" ] || [ -z "$merged" ]; then
  echo "permissions-sync: No permissions to sync" >&2
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
echo "permissions-sync: Synced permissions to $SETTINGS_FILE (allow: $count_allow, deny: $count_deny, ask: $count_ask)" >&2

echo '{}'
