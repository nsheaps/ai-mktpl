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

  # Run linters to check for issues
  echo "🔍 Running linters to check code quality..."
  cd "$PROJECT_DIR"

  LINT_ERRORS=0

  # YAML linting
  echo -n "  • YAML files... "
  if yamllint -c .github/actions/lint-files/yamllint.yaml . > /dev/null 2>&1; then
    echo "✅"
  else
    echo "❌ (run 'yamllint -c .github/actions/lint-files/yamllint.yaml .' to see errors)"
    LINT_ERRORS=$((LINT_ERRORS + 1))
  fi

  # JSON linting
  echo -n "  • JSON files... "
  cd .github/actions/lint-files
  if npx prettier --check "../../../**/*.json" > /dev/null 2>&1; then
    echo "✅"
  else
    echo "❌ (run 'npx prettier --write \"**/*.json\"' to fix)"
    LINT_ERRORS=$((LINT_ERRORS + 1))
  fi
  cd "$PROJECT_DIR"

  # Markdown linting
  echo -n "  • Markdown files... "
  if npx markdownlint-cli2 "**/*.md" > /dev/null 2>&1; then
    echo "✅"
  else
    echo "❌ (run 'npx markdownlint-cli2 \"**/*.md\"' to see errors)"
    LINT_ERRORS=$((LINT_ERRORS + 1))
  fi

  # Python linting (if Python files exist)
  if find . -name "*.py" -not -path "*/\.*" | grep -q .; then
    echo -n "  • Python files... "
    if black --check . > /dev/null 2>&1 && flake8 . > /dev/null 2>&1; then
      echo "✅"
    else
      echo "❌ (run 'black .' and 'flake8 .' to see/fix errors)"
      LINT_ERRORS=$((LINT_ERRORS + 1))
    fi
  fi

  if [ $LINT_ERRORS -eq 0 ]; then
    echo "  ✅ All linters passed!"
  else
    echo "  ⚠️  Found $LINT_ERRORS linting issue(s) - fix before pushing"
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
