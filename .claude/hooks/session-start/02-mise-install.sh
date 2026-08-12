#!/bin/bash
# Install mise and mise-managed tools on session start (web/cloud sessions only).
#
# Closes a gap identified in the cross-repo consistency audit
# (nsheaps/.ai-agent-jack docs/research/github-app-cloud-session-consistency-audit-2026-08-12.md):
# this repo's own environment-setup-and-maintenance.md rule describes this
# behavior as the intended design, but 01-install-plugins.sh only ever
# installed Claude Code plugins, not mise tools. Modeled on the one repo
# that already does this correctly: nsheaps/.github's
# .claude/hooks/session-start.sh (minus its yarn/corepack-specific steps,
# which don't apply here).
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Setting up mise-managed tools..."

if ! command -v mise &>/dev/null; then
  echo "Installing mise..."
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# Persist PATH so mise (and the tools it shims, e.g. gh) resolve in later tool calls.
echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$CLAUDE_ENV_FILE"

cd "$CLAUDE_PROJECT_DIR"

echo "Installing mise tools..."
mise trust --yes
mise install --yes

eval "$(mise activate bash)"
echo 'eval "$(mise activate bash)"' >>"$CLAUDE_ENV_FILE"

echo "mise tool setup complete."
