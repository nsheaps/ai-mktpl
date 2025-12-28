#!/bin/bash
# Linear MCP Sync Plugin Installation Script
#
# This script:
# 1. Installs the Linear MCP server (via mcp-remote)
# 2. Configures hooks for hash validation
# 3. Makes hook scripts executable
#
# Usage: ./install.sh [--user|--project]
#   --user    Install MCP server to user scope (default)
#   --project Install MCP server to project scope

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="${PLUGIN_DIR}/hooks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Linear MCP Sync Plugin Installer${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Parse arguments
SCOPE="user"
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            SCOPE="user"
            shift
            ;;
        --project)
            SCOPE="project"
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: ./install.sh [--user|--project]"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install it with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: Claude CLI is required but not installed.${NC}"
    echo "Install it with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

echo -e "${GREEN}Prerequisites satisfied.${NC}"
echo ""

echo -e "${YELLOW}Step 2: Installing Linear MCP server...${NC}"

# Check if Linear MCP is already configured
if claude mcp list 2>/dev/null | grep -q "linear"; then
    echo -e "${GREEN}Linear MCP server is already configured.${NC}"
else
    # Install Linear MCP using the official SSE endpoint
    echo "Adding Linear MCP server with ${SCOPE} scope..."

    # Use mcp-remote to connect to Linear's SSE endpoint
    if claude mcp add linear --scope "$SCOPE" -- npx -y mcp-remote https://mcp.linear.app/sse; then
        echo -e "${GREEN}Linear MCP server installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Linear MCP server.${NC}"
        echo "You may need to configure it manually. See README.md for instructions."
        exit 1
    fi
fi
echo ""

echo -e "${YELLOW}Step 3: Making hook scripts executable...${NC}"

chmod +x "${HOOKS_DIR}/linear-hash-save.sh"
chmod +x "${HOOKS_DIR}/linear-hash-check.sh"

echo -e "${GREEN}Hook scripts are now executable.${NC}"
echo ""

echo -e "${YELLOW}Step 4: Configuring hooks...${NC}"
echo ""
echo -e "${BLUE}To enable the hash validation hooks, add the following to your${NC}"
echo -e "${BLUE}Claude Code settings.json file:${NC}"
echo ""
echo -e "Location: ~/.config/claude/settings.json (Linux)"
echo -e "          ~/Library/Application Support/Claude/settings.json (macOS)"
echo -e "          Or project-level: .claude/settings.json"
echo ""

# Display the hooks configuration
cat <<EOF
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "mcp__linear__.*(get|Get|issue\$|Issue\$)",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOKS_DIR}/linear-hash-save.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "mcp__linear__.*(update|Update|create|Create)",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOKS_DIR}/linear-hash-check.sh"
          }
        ]
      }
    ]
  }
}
EOF

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Copy the hooks configuration above to your settings.json"
echo "2. Authenticate with Linear by running a Linear MCP command"
echo "3. Test by fetching an issue, then updating it"
echo ""
echo -e "${YELLOW}Note:${NC} The Linear MCP will prompt for OAuth authentication"
echo "on first use. Follow the browser prompts to authorize."
echo ""
echo "For more information, see: ${PLUGIN_DIR}/README.md"
