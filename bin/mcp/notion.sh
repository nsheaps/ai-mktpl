#!/usr/bin/env bash

MCP_USER=${MCP_USER:-$USER}

# doppler needs to expose:
# OPENAPI_MCP_HEADERS and NOTION_TOKEN
exec \
    doppler run \
        -p mcp \
        -c "user_${MCP_USER:-$USER}" \
        --command "npx -y @notionhq/notion-mcp-server"
