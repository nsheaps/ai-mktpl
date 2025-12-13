#!/usr/bin/env bash

if [[ "$MCP_USER" == "claude" || "$MCP_USER" == "devin" ]]; then
    uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context "agent"
else
    uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context "ide-assistant"
fi