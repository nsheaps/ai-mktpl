#!/usr/bin/env bash
# sync-rules.sh — SessionStart hook for common-sense plugin
#
# Creates a symlink at .claude/rules/common-sense pointing to this plugin's
# rules/ directory. Respects plugin configuration for scope and cross-repo sync.
#
# Config keys (via plugins.settings.yaml):
#   alsoSyncToUser    — true/false: also symlink into ~/.claude/rules/
#   alsoAddToRepos    — "": disabled, "org-name": repos in org, "*": all repos
#   syncSettingsTarget — "local" or "shared": which settings file to write to
set -euo pipefail

PLUGIN_NAME="common-sense"
PLUGIN_RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
LINK_NAME="common-sense"

# Source config reader
# shellcheck source=../../lib/plugin-config-read.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

# Source settings writer (needed for alsoAddToRepos)
# shellcheck source=../../lib/safe-settings-write.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"

# --- Read config ---

ALSO_SYNC_TO_USER="$(plugin_get_config "alsoSyncToUser" "false")"
ALSO_ADD_TO_REPOS="$(plugin_get_config "alsoAddToRepos" "")"
SYNC_SETTINGS_TARGET="$(plugin_get_config "syncSettingsTarget" "local")"

# --- Determine target directories ---

PROJECT_RULES_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/rules"
USER_RULES_DIR="${HOME}/.claude/rules"

# --- Helper: clean stale symlinks and create new one ---

setup_symlink() {
  local target_dir="$1"
  local link_path="${target_dir}/${LINK_NAME}"

  mkdir -p "$target_dir"

  # Clean up stale symlinks pointing into any ai-mktpl plugin path
  local ai_mktpl_pattern="ai-mktpl/plugins/common-sense/"
  for entry in "$target_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    if [ -L "$entry" ]; then
      local resolved
      resolved="$(readlink -f "$entry" 2>/dev/null || readlink "$entry" 2>/dev/null || true)"
      if [[ "$resolved" == *"${ai_mktpl_pattern}"* ]]; then
        echo "common-sense: removing stale symlink ${entry} -> ${resolved}" >&2
        rm -f "$entry"
      fi
    fi
  done

  # Don't clobber a real directory
  if [ -L "$link_path" ]; then
    rm -f "$link_path"
  elif [ -d "$link_path" ]; then
    echo "common-sense: WARNING: ${link_path} is a real directory, not replacing" >&2
    return 0
  fi

  ln -s "$PLUGIN_RULES_DIR" "$link_path"
  echo "common-sense: linked ${link_path} -> ${PLUGIN_RULES_DIR}" >&2
}

# --- Helper: add plugin to a repo's settings file ---

add_plugin_to_repo() {
  local repo_dir="$1"
  local target_file

  if [ "$SYNC_SETTINGS_TARGET" = "shared" ]; then
    target_file="${repo_dir}/.claude/settings.json"
  else
    target_file="${repo_dir}/.claude/settings.local.json"
  fi

  # Skip if no .claude dir exists (not a Claude Code project)
  if [ ! -d "${repo_dir}/.claude" ]; then
    return 0
  fi

  # Skip if plugin already enabled
  if [ -f "$target_file" ]; then
    local current
    current="$(jq -r '.enabledPlugins["common-sense@nsheaps-claude-plugins"] // empty' "$target_file" 2>/dev/null || true)"
    if [ "$current" = "true" ]; then
      return 0
    fi
  fi

  mkdir -p "$(dirname "$target_file")"
  SETTINGS_FILE="$target_file"
  safe_write_settings '.enabledPlugins["common-sense@nsheaps-claude-plugins"] = true'
  echo "common-sense: enabled plugin in ${target_file}" >&2
}

# --- Helper: get GitHub org from a repo's remote ---

get_repo_org() {
  local repo_dir="$1"
  local remote_url
  remote_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  if [ -z "$remote_url" ]; then
    return 1
  fi
  # Extract org from github.com/ORG/repo or github.com:ORG/repo
  echo "$remote_url" | sed -E 's#.*(github\.com[:/])([^/]+)/.*#\2#'
}

# --- Main ---

# Always sync to the project scope
setup_symlink "$PROJECT_RULES_DIR"

# Optionally also sync to user scope
if [ "$ALSO_SYNC_TO_USER" = "true" ]; then
  setup_symlink "$USER_RULES_DIR"
fi

# Optionally add plugin to other repos
if [ -n "$ALSO_ADD_TO_REPOS" ] && command -v jq &>/dev/null; then
  # Find git repos with .claude/ dirs
  # Look in common parent directories for sibling repos
  project_parent="$(dirname "${CLAUDE_PROJECT_DIR:-.}")"

  for candidate in "$project_parent"/*/; do
    [ -d "$candidate/.claude" ] || continue
    [ -d "$candidate/.git" ] || continue

    # Skip the current project
    candidate_real="$(cd "$candidate" && pwd)"
    project_real="$(cd "${CLAUDE_PROJECT_DIR:-.}" && pwd)"
    if [ "$candidate_real" = "$project_real" ]; then
      continue
    fi

    if [ "$ALSO_ADD_TO_REPOS" = "*" ]; then
      add_plugin_to_repo "$candidate_real"
    else
      # Check if repo belongs to the specified org
      repo_org="$(get_repo_org "$candidate_real" || true)"
      if [ "$repo_org" = "$ALSO_ADD_TO_REPOS" ]; then
        add_plugin_to_repo "$candidate_real"
      fi
    fi
  done
fi

echo '{}'
