#!/bin/bash
# Wrapper script to start the memory MCP server with correct project-local path
# This ensures MEMORY_FILE_PATH is an absolute path to the project directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export MEMORY_FILE_PATH="${PROJECT_ROOT}/.claude/memory.jsonl"

exec npx -y @modelcontextprotocol/server-memory "$@"
