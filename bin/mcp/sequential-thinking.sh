#!/usr/bin/env bash

MCP_USER=${MCP_USER:-$USER}

exec \
    doppler run \
        -p mcp \
        -c "user_${MCP_USER:-$USER}" \
        --command "npx -y @modelcontextprotocol/server-sequential-thinking"