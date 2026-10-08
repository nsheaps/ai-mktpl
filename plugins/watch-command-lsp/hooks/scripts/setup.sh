#!/usr/bin/env bash
# setup.sh — SessionStart hook for watch-command-lsp plugin
#
# Installs npm dependencies and builds the LSP server if needed.
set -euo pipefail

# Build the server if bin/server.mjs doesn't exist
if [ ! -f "${CLAUDE_PLUGIN_ROOT}/bin/server.mjs" ]; then
  cd "${CLAUDE_PLUGIN_ROOT}"
  if command -v bun &>/dev/null; then
    bun install --frozen-lockfile 2>/dev/null || bun install
    bun run build
  elif command -v npm &>/dev/null; then
    npm install
    npx bun build --target=node --outdir=./bin --entry-naming='[name].mjs' src/server.ts
  fi
fi

echo '{}'
