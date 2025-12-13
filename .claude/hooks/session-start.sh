#!/bin/bash
set -e

# Detect execution environment
IS_WEB_SESSION="${CLAUDE_CODE_REMOTE:-}"

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Set up PATH from NEWPATH if available
if [ -n "$NEWPATH" ]; then
  export PATH="$NEWPATH"
fi

# Only run expensive operations in web sessions
if [ "$IS_WEB_SESSION" = "true" ]; then
  echo "⚙️  Installing session dependencies..."

  # Install mise (tool version manager)
  if ! command -v mise &> /dev/null; then
    echo "📦 Installing mise..."
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # Activate mise and install tools from .mise.toml
  if [ -f "$PROJECT_DIR/.mise.toml" ]; then
    cd "$PROJECT_DIR"
    eval "$(mise activate bash)"
    mise install -y 2>&1 | grep -v "mise" | head -20 || true
  fi

  # Install linter dependencies
  if [ -f "$PROJECT_DIR/.github/actions/lint-files/package.json" ]; then
    cd "$PROJECT_DIR/.github/actions/lint-files"
    npm install --omit=dev 2>&1 | grep -v "npm WARN" || true
    cd "$PROJECT_DIR"
  fi

  # Run any custom setup script
  if [ -f "$PROJECT_DIR/scripts/install-dependencies.sh" ]; then
    bash "$PROJECT_DIR/scripts/install-dependencies.sh"
  fi

  echo "✅ Session setup complete"
fi

exit 0
