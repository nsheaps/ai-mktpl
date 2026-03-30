#!/usr/bin/env bash
# sync-rules.sh — SessionStart hook for agentic-behavior plugin
#
# Creates a symlink at .claude/rules/agentic-behavior pointing to this plugin's
# rules/ directory.
set -euo pipefail

PLUGIN_RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
LINK_NAME="agentic-behavior"

# Source hook logging
# shellcheck source=../../lib/hook-logging.sh
# Resolve lib path relative to plugin root (sibling of hooks/)
PLUGIN_LIB_DIR="${CLAUDE_PLUGIN_ROOT}/lib"

# Fall back to common-sense lib if no local lib (shared infrastructure)
if [ ! -f "${PLUGIN_LIB_DIR}/hook-logging.sh" ]; then
  CS_PLUGIN_ROOT="$(dirname "${CLAUDE_PLUGIN_ROOT}")/common-sense"
  PLUGIN_LIB_DIR="${CS_PLUGIN_ROOT}/lib"
fi

# shellcheck source=../../lib/hook-logging.sh
source "${PLUGIN_LIB_DIR}/hook-logging.sh"

# --- Determine target directory ---

PROJECT_RULES_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/rules"
link_path="${PROJECT_RULES_DIR}/${LINK_NAME}"

mkdir -p "$PROJECT_RULES_DIR"

# Remove stale symlink if present
if [ -L "$link_path" ]; then
  rm -f "$link_path"
elif [ -d "$link_path" ]; then
  hook_log_always "WARNING: ${link_path} is a real directory, not replacing — remove manually if unintentional"
  hook_respond
  exit 0
fi

if ! ln -s "$PLUGIN_RULES_DIR" "$link_path"; then
  hook_fail "symlink creation" "Failed to create symlink ${link_path} -> ${PLUGIN_RULES_DIR}" \
    "Check directory permissions for ${PROJECT_RULES_DIR}"
  exit 1
fi

hook_log "linked ${link_path} -> ${PLUGIN_RULES_DIR}"
hook_log_cleanup
hook_respond
