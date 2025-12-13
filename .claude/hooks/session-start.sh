#!/bin/bash
set -e

# Detect execution environment
IS_WEB_SESSION="${CLAUDE_CODE_REMOTE:-}"

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

echo "🚀 Starting Claude Code Plugin Marketplace session..."
echo "📍 Environment: $([ "$IS_WEB_SESSION" = "true" ] && echo "Web/Remote" || echo "Local CLI")"
echo "📁 Project: $PROJECT_DIR"
echo ""

# Only run expensive operations in web sessions
if [ "$IS_WEB_SESSION" = "true" ]; then
  echo "⚙️  Installing web session dependencies..."

  # Install linter dependencies for CI workflows
  if [ -f "$PROJECT_DIR/.github/actions/lint-files/package.json" ]; then
    cd "$PROJECT_DIR/.github/actions/lint-files"
    echo "📦 Installing linter dependencies..."
    npm install --omit=dev 2>&1 | grep -v "npm WARN" || true
    echo "✅ Linter dependencies installed"
    cd "$PROJECT_DIR"
  fi

  # Install Python linters for validation
  echo "🐍 Installing Python linters..."
  pip install -q yamllint black flake8 isort 2>&1 || true
  echo "✅ Python linters installed"

  # Run any custom setup script
  if [ -f "$PROJECT_DIR/scripts/install-dependencies.sh" ]; then
    echo "🔧 Running custom setup script..."
    bash "$PROJECT_DIR/scripts/install-dependencies.sh"
  fi

  echo ""
fi

# Display available commands
echo "📚 Available Marketplace Commands:"
echo "  /commit              - AI-generated git commits"
echo ""

# Load project context (works in both local and web)
if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
  echo "=== PROJECT CONTEXT (CLAUDE.md) ==="
  cat "$PROJECT_DIR/CLAUDE.md"
  echo "===================================="
  echo ""
fi

# Display project stats
if [ -d "$PROJECT_DIR/plugins" ]; then
  PLUGIN_COUNT=$(find "$PROJECT_DIR/plugins" -mindepth 1 -maxdepth 1 -type d | wc -l)
  echo "📊 Marketplace Stats:"
  echo "  Plugins: $PLUGIN_COUNT"
  echo "  Location: $PROJECT_DIR/plugins/"
  echo ""
fi

echo "✨ Session setup complete! Ready to work on the plugin marketplace."
exit 0
