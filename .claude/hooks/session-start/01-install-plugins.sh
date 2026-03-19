#!/usr/bin/env bash
# Install enabled plugins on session start (web sessions only).
# Locally, Claude Code auto-resolves enabled plugins; web sessions need this explicit step.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

# Plugins enabled in .claude/settings.json enabledPlugins
PLUGINS=(
    "plugin-dev@claude-plugins-official"
    "git-spice@ai-mktpl"
    "mise@ai-mktpl"
)

echo "Installing enabled plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo "  -> $plugin"
    claude plugin install "$plugin" --scope project 2>&1 || echo "  [warn] Failed to install $plugin, continuing..."
done
echo "Plugin installation complete."
