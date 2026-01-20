#!/usr/bin/env bash
# Test that plugin configuration doesn't leave uncommitted changes
#
# Usage: test-configuration.sh
#
# This script:
# 1. Records initial git state
# 2. Runs the session-start hook directly (simulates Claude session start)
# 3. Checks for uncommitted changes to tracked files
# 4. Fails if configuration would cause git changes for other users
#
# Note: This test expects that settings.local.json is in .gitignore,
# so changes to that file should not cause failures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$PLUGIN_ROOT/../.." && pwd)}"

cd "$PROJECT_DIR"

echo "🧪 Testing plugin configuration: datadog-otel-setup"
echo "   Project directory: $PROJECT_DIR"

# Check initial git state (only for tracked files)
INITIAL_STATUS=$(git status --porcelain --untracked-files=no)
if [[ -n "$INITIAL_STATUS" ]]; then
  echo "⚠️  WARNING: Working directory has uncommitted changes to tracked files:"
  echo "$INITIAL_STATUS"
  echo ""
  echo "   This may affect test results. Consider committing or stashing changes."
  echo ""
fi

# Set up test environment
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export DD_API_KEY="${DD_API_KEY:-test-api-key-for-validation}"

echo "🔄 Running session-start hook..."

# Run the hook
if ! bash "$PLUGIN_ROOT/hooks/session-start-otel-setup.sh"; then
  echo "❌ FAIL: Hook execution failed"
  exit 1
fi

# Check for changes to tracked files
FINAL_STATUS=$(git status --porcelain --untracked-files=no)

# Compare with initial state
if [[ "$FINAL_STATUS" != "$INITIAL_STATUS" ]]; then
  # Calculate what changed
  NEW_CHANGES=$(comm -13 <(echo "$INITIAL_STATUS" | sort) <(echo "$FINAL_STATUS" | sort) || true)

  if [[ -n "$NEW_CHANGES" ]]; then
    echo ""
    echo "❌ FAIL: Plugin configuration caused uncommitted changes to tracked files:"
    echo "$NEW_CHANGES"
    echo ""
    echo "This indicates the plugin is modifying files that would be committed."
    echo "Ensure 'target: local' is set to use settings.local.json (gitignored)"
    echo ""
    echo "To fix:"
    echo "  1. Check .claude/plugins.settings.yaml and ensure target: local"
    echo "  2. Verify .claude/settings.local.json is in .gitignore"
    exit 1
  fi
fi

# Verify the settings file was created correctly
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  # Validate JSON structure
  if ! jq -e '.env.OTEL_EXPORTER_OTLP_ENDPOINT' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "❌ FAIL: Settings file doesn't contain expected OTEL configuration"
    echo "   File: $SETTINGS_FILE"
    cat "$SETTINGS_FILE"
    exit 1
  fi
  echo "✅ Settings file created with OTEL configuration"
else
  echo "⚠️  WARNING: Settings file was not created (API key may be missing)"
fi

echo ""
echo "✅ PASS: Plugin configuration does not cause changes to tracked files"
