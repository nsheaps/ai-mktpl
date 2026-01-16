#!/usr/bin/env bash
# Pre-tool-use hook for Write tool
# Ensures the target directory exists before writing a file
#
# This hook automatically creates parent directories using mkdir -p,
# so Claude doesn't need to manually run mkdir commands.

set -euo pipefail
source "$(dirname "$0")/../lib/pretooluse.sh"

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only process Write tool calls
if [ "$TOOL_NAME" != "Write" ]; then
  allow
fi

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  deny "No file_path provided to Write tool"
fi

# Get the directory portion of the path
DIR_PATH=$(dirname "$FILE_PATH")

# Check if directory exists, create if not
if [ ! -d "$DIR_PATH" ]; then
  echo "ℹ️  Creating directory: $DIR_PATH" >&2
  mkdir -p "$DIR_PATH"
  echo "✅ Directory created: $DIR_PATH" >&2
fi

# Allow the Write to proceed
allow
