#!/bin/bash
set -e

info() {
  echo "ℹ️  $*"
}

success() {
  echo "✅ $*"
}

failed() {
  echo "❌ $*"
}

warn() {
  echo "⚠️  $*"
}

pbe() {
  # pbe print before executing
  echo "▶️  $*"
  "$@" 2>&1
}

# Detect execution environment
IS_WEB_SESSION="${CLAUDE_CODE_REMOTE:-}"
info "CLAUDE_CODE_REMOTE: ${IS_WEB_SESSION:-false}"

if [ -n "$CLAUDE_ENV_FILE" ]; then
  # if PATHMOD is set, modify PATH accordingly
  if [ -n "$PATHMOD" ]; then
    echo "export PATH=\"$PATHMOD:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    echo "✅ Modified PATH"
  fi
  info "PATH: $PATH"
  info "CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"
fi

# Get project directory
info "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# if the PROJECT_DIR is a git repository, fetch latest changes, and print git status
if [ -d "$PROJECT_DIR/.git" ]; then
  pbe git -C "$PROJECT_DIR" fetch
  pbe git -C "$PROJECT_DIR" status
fi

# Only run expensive operations in web sessions
if [ "$IS_WEB_SESSION" = "true" ]; then
  echo "⚙️  Installing session dependencies..."

  # Install mise (tool version manager) if not already available
  if ! command -v mise &> /dev/null; then
    echo "📦 Installing mise..."
    # Download from GitHub releases instead of mise.run (avoids proxy issues)
    # TODO: Have Renovate manage this version (see docs/specs/drafts/cicd-enhancements.md)
    MISE_VERSION="2024.12.16"
    MISE_URL="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64"
    mkdir -p "$HOME/.local/bin"

    SETUP="$(cat << EOF
export PATH="$HOME/.local/bin:$PATH"
export MISE_VERBOSE=1

EOF
)"
    echo "$SETUP" >> "$CLAUDE_ENV_FILE"
    eval "$SETUP"

    if curl -fsSL "$MISE_URL" -o "$HOME/.local/bin/mise" 2>/dev/null; then
      chmod +x "$HOME/.local/bin/mise"
      success "mise installed successfully"
    else
      failed "mise installation failed (network restricted)\n   Tools from mise.toml will not be available"
    fi
  else
    # TODO cleanup with 01-mise-activate.sh
    mise self-update || warn "mise self-update failed"
  fi
  # Trust and install tools from mise.toml (if mise is available).
  # Activation and CLAUDE_ENV_FILE persistence is handled by the mise-tool plugin.
  # gh auth check is handled by the gh-tool plugin.
  if command -v mise &> /dev/null && [ -f "$PROJECT_DIR/mise.toml" ]; then
    cd "$PROJECT_DIR"
    pbe mise trust
    # GH_TOKEN provides GITHUB_TOKEN for mise to fetch tools from GitHub releases
    GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}" pbe mise install -y
  fi

fi

success "✅ Session setup complete"
exit 0
