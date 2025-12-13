#!/usr/bin/env bash

MCP_USER=${MCP_USER:-$USER}


# MCP_ENDPOINT="https://mcp.context7.com/mcp"
# ADDITIONAL_FLAGS=""

# MCP_USER="${MCP_USER:-$USER}"
# if [[ -z "${MCP_USER:-}" ]]; then
#     echo "❌ Error: MCP_USER not set"
#     exit 1
# fi

# if [[ "${MCP_USER}" == "claude" || "${MCP_USER}" == "devin" ]]; then
#     # shellcheck disable=SC2016
#     ADDITIONAL_FLAGS='--header "Context7-Api-Key: $CONTEXT7_API_KEY"'
# fi

# CMD="npx -y --package=mcp-remote@latest -- mcp-remote ${MCP_ENDPOINT} ${ADDITIONAL_FLAGS}"

# exec \
#     doppler run \
#         -p mcp \
#         -c "user_${MCP_USER:-$USER}" \
#         --command "${CMD}"


CMD="$(cat << EOF
npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
EOF
)"

exec \
  doppler run \
      -p mcp \
      -c "user_${MCP_USER:-$USER}" \
      --command "${CMD}"
