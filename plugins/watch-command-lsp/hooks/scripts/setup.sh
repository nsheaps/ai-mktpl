#!/usr/bin/env bash
# setup.sh — SessionStart hook for watch-command-lsp plugin
#
# 1. Adds MCP tool permissions to settings.local.json
# 2. Installs npm dependencies and builds the server if needed
set -euo pipefail

PLUGIN_NAME="watch-command-lsp"
SETTINGS_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"

source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/add-permission.sh"

# Auto-approve all watch-command-lsp MCP tools
add_permission_to_allow "mcp__watch-command-lsp__*"

# Build the server if bin/index.mjs doesn't exist
if [ ! -f "${CLAUDE_PLUGIN_ROOT}/bin/index.mjs" ]; then
  cd "${CLAUDE_PLUGIN_ROOT}"
  if command -v bun &>/dev/null; then
    bun install --frozen-lockfile 2>/dev/null || bun install
    bun run build
  elif command -v npm &>/dev/null; then
    npm install
    npx bun build --target=node --outdir=./bin --entry-naming='[name].mjs' src/index.ts
  fi
fi

echo '{}'
