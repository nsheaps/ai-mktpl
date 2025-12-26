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

# Find Python 3
if command -v python3 &> /dev/null; then
    PYTHON="python3"
elif command -v python &> /dev/null; then
    # Check if 'python' is Python 3
    if python -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>/dev/null; then
        PYTHON="python"
    else
        echo "Error: Python 3 is required but only Python 2 was found" >&2
        exit 2
    fi
else
    echo "Error: Python 3 is not installed" >&2
    exit 2
fi

# Check for PyYAML
if ! $PYTHON -c 'import yaml' 2>/dev/null; then
    echo "Warning: PyYAML not installed. Installing..." >&2
    $PYTHON -m pip install --user pyyaml 2>/dev/null || {
        echo "Error: Failed to install PyYAML. Please install manually: pip install pyyaml" >&2
        exit 2
    }
fi

# Run the Python script
exec $PYTHON "$PYTHON_SCRIPT" "$@"
