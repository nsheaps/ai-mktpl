#!/usr/bin/env bash

MCP_USER=${MCP_USER:-$USER}

# doppler needs to expose:
# SLACK_BOT_TOKEN, SLACK_TEAM_ID
# optional: SLACK_CHANNEL_IDS
# for containerized and hosted, the auth token for accessing
# the server (but we run local): AUTH_TOKEN
# ref https://github.com/zencoderai/slack-mcp-server
exec \
    doppler run \
        -p mcp \
        -c "user_${MCP_USER:-$USER}" \
        --command "npx -y @zencoderai/slack-mcp-server"
