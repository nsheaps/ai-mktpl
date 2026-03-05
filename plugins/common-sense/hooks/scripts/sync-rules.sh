#!/usr/bin/env bash
# sync-rules.sh — SessionStart hook for common-sense plugin
#
# Creates a symlink at $PROJECT/.claude/rules/common-sense pointing to
# this plugin's rules/ directory. Cleans up any stale symlinks first.
set -euo pipefail

PLUGIN_RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
LINK_NAME="common-sense"

# --- Determine target directories ---

# Project-level rules directory (always used, even if plugin is user-level)
PROJECT_RULES_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/rules"

# User-level rules directory
USER_RULES_DIR="${HOME}/.claude/rules"

# --- Helper: clean and create symlink ---

setup_symlink() {
  local target_dir="$1"
  local link_path="${target_dir}/${LINK_NAME}"

  # Ensure the target directory exists
  mkdir -p "$target_dir"

  # Clean up any existing symlinks in rules dirs that point into this repo's
  # plugin directories (stale references from prior installs or other plugins
  # that may have been symlinking rules from this marketplace repo)
  local ai_mktpl_pattern="ai-mktpl/plugins/"
  for entry in "$target_dir"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    if [ -L "$entry" ]; then
      local resolved
      resolved="$(readlink -f "$entry" 2>/dev/null || readlink "$entry" 2>/dev/null || true)"
      # Remove symlinks pointing into any ai-mktpl plugin path
      if [[ "$resolved" == *"${ai_mktpl_pattern}"* ]]; then
        echo "common-sense: removing stale symlink ${entry} -> ${resolved}" >&2
        rm -f "$entry"
      fi
    fi
  done

  # Remove existing link/dir at the target path if present
  if [ -L "$link_path" ]; then
    rm -f "$link_path"
  elif [ -d "$link_path" ]; then
    echo "common-sense: WARNING: ${link_path} is a real directory, not replacing" >&2
    echo '{}'
    return 0
  fi

  # Create the symlink
  ln -s "$PLUGIN_RULES_DIR" "$link_path"
  echo "common-sense: linked ${link_path} -> ${PLUGIN_RULES_DIR}" >&2
}

# --- Main ---

# Always set up in project-level .claude/rules/
setup_symlink "$PROJECT_RULES_DIR"

# Also set up in user-level if the plugin is installed at user scope
# (detected by checking if CLAUDE_PLUGIN_ROOT is under ~/.claude/)
if [[ "${CLAUDE_PLUGIN_ROOT}" == "${HOME}/.claude/"* ]]; then
  # User-level install: also ensure project rules get the symlink
  # (already handled above since we always do project-level)
  # Additionally create the user-level symlink for global access
  setup_symlink "$USER_RULES_DIR"
fi

echo '{}'
