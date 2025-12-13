#!/usr/bin/env bash
set -euo pipefail

# Accept config file path as first argument, default to .mcp.json
CONFIG_FILE="${1:-.mcp.json}"

# Check for required env vars
MCP_USER="${MCP_USER:-$USER}"
if [[ -z "${MCP_USER:-}" ]]; then
    echo "❌ Error: MCP_USER not set"
    exit 1
else
    echo "Using MCP_USER=${MCP_USER}"
fi

DOPPLER_TOKEN="${DOPPLER_TOKEN:-}"
if [[ -z "${DOPPLER_TOKEN:-}" ]]; then
    if doppler me >/dev/null 2>&1; then
        echo "Logged in to Doppler, DOPPLER_TOKEN not required"
    else
        echo "❌ Error: DOPPLER_TOKEN not set and not logged into Doppler"
        exit 1
    fi
fi

echo "=== Generating MCP documentation from live servers ==="

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Error: Config file '$CONFIG_FILE' not found"
    exit 1
fi

# Check required tools
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq not found. Please install jq first."
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "❌ Error: yq not found. Please install yq first."
    exit 1
fi

if ! command -v npx &> /dev/null; then
    echo "❌ Error: npx not found. Please install Node.js and npm first."
    exit 1
fi

echo "::group::Downloading MCP Inspector"
npm_config_loglevel=verbose npx --from github:nsheaps/inspector -- mcp-inspector --help
echo "::endgroup::"

# Create output directory
mkdir -p lib/mcp

echo "Using MCP Inspector to query servers from '$CONFIG_FILE'"

# Get list of servers from config using jq
echo "Discovering servers from config file..."
if ! servers=$(jq -r '.mcpServers | keys[]' "$CONFIG_FILE" 2>/dev/null); then
    echo "❌ Error: Failed to parse config file"
    exit 1
fi

# Count servers
server_count=$(echo "$servers" | wc -l | tr -d ' ')
echo "Found $server_count servers to process"

# Initialize counters
total_servers=0
total_tools=0
total_resources=0
total_prompts=0

# Process each server
while IFS= read -r server_name; do
    [[ -z "$server_name" ]] && continue

    echo ""
    echo "Processing server: ${server_name}"
    total_servers=$((total_servers + 1))

    # Initialize empty arrays for this server
    tools="[]"
    resources="[]"
    prompts="[]"

    # Get tools
    echo "  Getting tools..."
    if tool_output=$(MCP_USER="$MCP_USER" DOPPLER_TOKEN="$DOPPLER_TOKEN" \
        # bug: see fix: https://github.com/modelcontextprotocol/inspector/pull/739
        # npx -y @modelcontextprotocol/inspector \
        npx --from github:nsheaps/inspector -- mcp-inspector \
        --cli \
        --config "$CONFIG_FILE" \
        --server "$server_name" \
        --method tools/list 2>/dev/null); then

        # Parse the JSON output directly
        if echo "$tool_output" | jq -e '.' >/dev/null 2>&1; then
            # Check if it's wrapped in a result object
            if echo "$tool_output" | jq -e '.tools' >/dev/null 2>&1; then
                tools=$(echo "$tool_output" | jq '.tools')
            elif echo "$tool_output" | jq -e 'type == "array"' >/dev/null 2>&1; then
                tools="$tool_output"
            else
                tools="[]"
            fi

            # Filter tool properties (inputSchema is the parameter schema in inspector output)
            tools=$(echo "$tools" | jq '[.[] | {
                name: .name,
                description: .description,
                parameters: .inputSchema,
                is_async: .is_async,
                tags: .tags,
                aliases: .aliases
            }]' 2>/dev/null || echo "[]")

            tool_count=$(echo "$tools" | jq 'length')
            echo "    ✓ Found $tool_count tools"
            total_tools=$((total_tools + tool_count))
        else
            echo "    ⚠ No valid JSON response for tools"
        fi
    else
        echo "    ⚠ Failed to get tools (server may not support this method)"
    fi

    # Get resources
    echo "  Getting resources..."
    if resource_output=$(MCP_USER="$MCP_USER" DOPPLER_TOKEN="$DOPPLER_TOKEN" \
        # bug: see fix: https://github.com/modelcontextprotocol/inspector/pull/739
        # npx -y @modelcontextprotocol/inspector \
        npx --from github:nsheaps/inspector -- mcp-inspector \
        --cli \
        --config "$CONFIG_FILE" \
        --server "$server_name" \
        --method resources/list 2>/dev/null); then

        # Parse the JSON output directly
        if echo "$resource_output" | jq -e '.' >/dev/null 2>&1; then
            # Check if it's wrapped in a result object
            if echo "$resource_output" | jq -e '.resources' >/dev/null 2>&1; then
                resources=$(echo "$resource_output" | jq '.resources')
            elif echo "$resource_output" | jq -e 'type == "array"' >/dev/null 2>&1; then
                resources="$resource_output"
            else
                resources="[]"
            fi

            resource_count=$(echo "$resources" | jq 'length' 2>/dev/null || echo "0")
            echo "    ✓ Found $resource_count resources"
            total_resources=$((total_resources + resource_count))
        else
            echo "    ⚠ No valid JSON response for resources"
        fi
    else
        echo "    ⚠ Failed to get resources (server may not support this method)"
    fi

    # Get prompts
    echo "  Getting prompts..."
    if prompt_output=$(MCP_USER="$MCP_USER" DOPPLER_TOKEN="$DOPPLER_TOKEN" \
        # bug: see fix: https://github.com/modelcontextprotocol/inspector/pull/739
        # npx -y @modelcontextprotocol/inspector \
        npx --from github:nsheaps/inspector -- mcp-inspector \
        --cli \
        --config "$CONFIG_FILE" \
        --server "$server_name" \
        --method prompts/list 2>/dev/null); then

        # Parse the JSON output directly
        if echo "$prompt_output" | jq -e '.' >/dev/null 2>&1; then
            # Check if it's wrapped in a result object
            if echo "$prompt_output" | jq -e '.prompts' >/dev/null 2>&1; then
                prompts=$(echo "$prompt_output" | jq '.prompts')
            elif echo "$prompt_output" | jq -e 'type == "array"' >/dev/null 2>&1; then
                prompts="$prompt_output"
            else
                prompts="[]"
            fi

            prompt_count=$(echo "$prompts" | jq 'length' 2>/dev/null || echo "0")
            echo "    ✓ Found $prompt_count prompts"
            total_prompts=$((total_prompts + prompt_count))
        else
            echo "    ⚠ No valid JSON response for prompts"
        fi
    else
        echo "    ⚠ Failed to get prompts (server may not support this method)"
    fi

    # Save to YAML file
    echo "  Writing to lib/mcp/${server_name}.yaml"
    echo "{
        \"tools\": $tools,
        \"resources\": $resources,
        \"prompts\": $prompts
    }" | yq -P > "lib/mcp/${server_name}.yaml"

done <<< "$servers"

# Generate summary file
echo ""
echo "Generating summary file..."
server_list=$(jq -n --arg count "$total_servers" --arg tools "$total_tools" --arg resources "$total_resources" --arg prompts "$total_prompts" \
    '{
        summary: {
            total_servers: ($count | tonumber),
            total_tools: ($tools | tonumber),
            total_resources: ($resources | tonumber),
            total_prompts: ($prompts | tonumber)
        },
        servers: []
    }')

# Add server names to the list
while IFS= read -r server_name; do
    [[ -z "$server_name" ]] && continue
    server_list=$(echo "$server_list" | jq --arg name "$server_name" '.servers += [$name]')
done <<< "$servers"

echo "$server_list" | yq -P > "lib/mcp_servers.yaml"

echo ""
echo "=== Summary ==="
echo "✅ Processed $total_servers MCP servers"
echo "   - $total_tools tools"
echo "   - $total_resources resources"
echo "   - $total_prompts prompts"
echo ""
echo "✅ MCP documentation generated successfully"
