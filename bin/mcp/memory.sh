#!/usr/bin/env bash

# MCP Memory Server
# ref https://www.npmjs.com/package/@modelcontextprotocol/server-memory
#
# Usage: memory.sh [memory_file_path project_name]
#   Both arguments must be provided together or not at all
#   memory_file_path: Path to memory.json file
#   project_name: Project name for logging

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if arguments are provided correctly
if [ $# -eq 1 ]; then
    echo "Error: If providing a memory file path, you must also provide a project name"
    echo "Usage: $0 [memory_file_path project_name]"
    exit 1
elif [ $# -eq 2 ]; then
    # Use provided arguments
    MEMORY_FILE_PATH="$1"
    PROJECT_NAME="$2"
else
    # Use defaults
    MEMORY_FILE_PATH="${SCRIPT_DIR}/../../memory.json"
    PROJECT_NAME="memory"
fi

# turn MEMORY_FILE_PATH into an absolute path
if [[ "$MEMORY_FILE_PATH" != /* ]]; then
    # Relative path, make it absolute
    MEMORY_FILE_PATH="$(cd "$(dirname "$MEMORY_FILE_PATH")" && pwd)/$(basename "$MEMORY_FILE_PATH")"
fi

export MEMORY_FILE_PATH

echo "[$PROJECT_NAME] Memory's stored at $MEMORY_FILE_PATH"

exec npx -y @modelcontextprotocol/server-memory
