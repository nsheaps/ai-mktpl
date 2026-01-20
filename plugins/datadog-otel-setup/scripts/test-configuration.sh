#!/usr/bin/env bash
# Test that plugin configuration doesn't leave uncommitted changes
#
# Usage: test-configuration.sh
#
# This script:
# 1. Records initial git state
# 2. Runs the session-start hook directly
# 3. Checks for uncommitted changes to tracked files
# 4. Fails if configuration would cause git changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$PLUGIN_ROOT/../.." && pwd)}"

cd "$PROJECT_DIR"

echo "Testing plugin configuration: datadog-otel-setup"
echo "  Project directory: $PROJECT_DIR"

# Check initial git state (only for tracked files)
INITIAL_STATUS=$(git status --porcelain --untracked-files=no)
if [[ -n "$INITIAL_STATUS" ]]; then
  echo "WARNING: Working directory has uncommitted changes to tracked files"
fi

# Set up test environment
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"

echo "Running session-start hook..."

# Run the hook
if ! bash "$PLUGIN_ROOT/hooks/session-start-otel-setup.sh"; then
  echo "FAIL: Hook execution failed"
  exit 1
fi

# Check for changes to tracked files
FINAL_STATUS=$(git status --porcelain --untracked-files=no)

# Compare with initial state
if [[ "$FINAL_STATUS" != "$INITIAL_STATUS" ]]; then
  NEW_CHANGES=$(comm -13 <(echo "$INITIAL_STATUS" | sort) <(echo "$FINAL_STATUS" | sort) || true)

  if [[ -n "$NEW_CHANGES" ]]; then
    echo "FAIL: Plugin configuration caused uncommitted changes:"
    echo "$NEW_CHANGES"
    echo ""
    echo "Check .claude/plugins.settings.json and ensure target: local"
    exit 1
  fi
fi

# Verify the settings file was created
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  if ! jq -e '.env.OTEL_EXPORTER_OTLP_ENDPOINT' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "FAIL: Settings file doesn't contain expected configuration"
    exit 1
  fi
  echo "Settings file created with env configuration"
else
  echo "WARNING: Settings file was not created"
fi

echo "PASS: Plugin configuration does not cause changes to tracked files"
