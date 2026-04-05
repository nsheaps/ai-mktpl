#!/bin/bash
# sync-settings.sh - Shell wrapper for the sync-settings Python hook
#
# This wrapper script:
# 1. Ensures Python 3 is available
# 2. Checks for required PyYAML dependency
# 3. Runs the sync-settings.py script
#
# Usage: Add this to your Claude Code hooks configuration:
#   "command": "/path/to/sync-settings.sh"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/sync-settings.py"

PLUGIN_NAME="sync-settings"
# shellcheck source=../lib/log.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"

# Find Python 3
if command -v python3 &> /dev/null; then
    PYTHON="python3"
elif command -v python &> /dev/null; then
    # Check if 'python' is Python 3
    if python -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>/dev/null; then
        PYTHON="python"
    else
        log_error "Python 3 is required but only Python 2 was found"
        exit 2
    fi
else
    log_error "Python 3 is not installed"
    exit 2
fi

# Check for PyYAML
if ! $PYTHON -c 'import yaml' 2>/dev/null; then
    log_warn "PyYAML not installed. Installing..."
    $PYTHON -m pip install --user pyyaml 2>/dev/null || {
        log_error "Failed to install PyYAML. Please install manually: pip install pyyaml"
        exit 2
    }
fi

# Run the Python script
exec $PYTHON "$PYTHON_SCRIPT" "$@"
