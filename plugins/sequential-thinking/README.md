# sequential-thinking

Set up the [sequential-thinking MCP server](https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking) and auto-configure permissions for all its tools on session start.

## Features

- **MCP server declaration**: Registers `@modelcontextprotocol/server-sequential-thinking` via `.mcp.json`
- **Auto-permissions**: Adds `mcp__sequential-thinking__*` to `permissions.allow` on session start
- **Comprehensive skill**: Full reference for structured thinking patterns (linear, revision, branching)
- **Zero configuration**: Works out of the box after plugin installation

## How It Works

1. **On plugin install**: The `.mcp.json` registers the sequential-thinking MCP server
2. **On session start**: The hook adds `mcp__sequential-thinking__*` to `settings.local.json` permissions
3. **During use**: The `sequentialthinking` tool is available without permission prompts

## What Sequential Thinking Provides

A single tool (`mcp__sequential-thinking__sequentialthinking`) for structured problem-solving:

- **Linear analysis**: Step-by-step reasoning
- **Revision**: Correct earlier assumptions when new information emerges
- **Branching**: Explore multiple approaches in parallel
- **Adaptive depth**: Start small, expand as complexity reveals itself

## Requirements

- `npx` must be available (Node.js)
- `jq` for permission configuration

## Note on Session Restart

MCP servers are established at session startup. If you install this plugin mid-session, you'll need to restart your Claude Code session for the MCP server to become available. The permissions will be configured automatically on the next session start.
