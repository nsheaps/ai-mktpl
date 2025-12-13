#!/usr/bin/env bash

# If the user is claude or devin, use the graphql endpoint
MCP_USER=${MCP_USER:-$USER}
echo "[linear] Using MCP_USER=${MCP_USER}" >&2
if [[ "$MCP_USER" == "claude" || "$MCP_USER" == "devin" ]]; then
    exec \
        doppler run \
            -p mcp \
            -c "user_${MCP_USER}" \
            --command 'ENDPOINT=https://api.linear.app/graphql HEADERS="{\"Authorization\":\"Bearer $LINEAR_API_KEY\"}" npx -y mcp-graphql'
else
    exec \
        doppler run \
            -p mcp \
            -c "user_${MCP_USER}" \
            --command "npx -y --package=mcp-remote@latest -- mcp-remote https://mcp.linear.app/sse"
fi
