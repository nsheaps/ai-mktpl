#!/bin/bash
set -e

pbe() {
  # pbe print before executing
  echo "▶️  $*"
  "$@"
}

# Detect execution environment
IS_WEB_SESSION="${CLAUDE_CODE_REMOTE:-}"

if [ -n "$CLAUDE_ENV_FILE" ]; then
  # if PATHMOD is set, modify PATH accordingly
  if [ -n "$PATHMOD" ]; then
    echo "export PATH=\"$PATHMOD:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    echo "✅ Modified PATH"
    echo "  PATH: $PATH"
    echo "  CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"
  fi
fi

# Get project directory
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
    MISE_VERSION="2024.12.16"
    MISE_URL="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64"
    mkdir -p "$HOME/.local/bin"

    if curl -fsSL "$MISE_URL" -o "$HOME/.local/bin/mise" 2>/dev/null; then
      chmod +x "$HOME/.local/bin/mise"
      export PATH="$HOME/.local/bin:$PATH"
      eval "$(mise activate bash)"
      echo 'eval "$(mise activate bash)"' >> "$CLAUDE_ENV_FILE"
      echo "✅ mise installed successfully"
    else
      echo "⚠️  mise installation failed (network restricted)"
      echo "   Tools from .mise.toml will not be available"
    fi
  else
    # mise already available, activate it
    eval "$(mise activate bash)"
    echo 'eval "$(mise activate bash)"' >> "$CLAUDE_ENV_FILE"
  fi

  # Activate mise and install tools from .mise.toml (if mise is available)
  if command -v mise &> /dev/null && [ -f "$PROJECT_DIR/.mise.toml" ]; then
    cd "$PROJECT_DIR"
    mise trust
    pbe mise install -y
  fi

  echo "✅ Session setup complete"
fi

exit 0
