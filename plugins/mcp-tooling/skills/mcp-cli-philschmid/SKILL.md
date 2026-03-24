---
name: mcp-cli-philschmid
description: >
  Use this skill when working with philschmid/mcp-cli — a lightweight Bun-based CLI
  for interacting with MCP servers from the shell. Use when the user asks about
  discovering MCP tools, calling MCP tools from the command line, reducing token
  consumption with dynamic tool discovery, or integrating MCP servers into shell
  scripts and AI agent workflows. Also use when encountering questions about
  mcp_servers.json configuration for CLI-based MCP access.
---

# philschmid/mcp-cli

**Repository**: https://github.com/philschmid/mcp-cli

A lightweight, Bun-based CLI for interacting with MCP servers from the shell. Designed for AI coding agents (Gemini CLI, Claude Code, etc.) and shell scripting workflows.

## Why Use It

Traditional MCP integration loads entire tool schemas into the AI context window, consuming thousands of tokens. mcp-cli enables **dynamic, on-demand discovery** — the agent only fetches schemas for tools it actually needs.

Key advantages:

- **Token efficiency**: Discover tools incrementally instead of loading all schemas upfront
- **Connection pooling**: Lazy-spawn daemons keep connections warm (60s idle timeout)
- **Shell-native**: JSON output compatible with pipes and `jq` for chaining
- **Minimal footprint**: Fast startup via Bun runtime

## Installation

```bash
# Via install script
curl -fsSL https://raw.githubusercontent.com/philschmid/mcp-cli/main/install.sh | bash

# Via Bun
bun install -g https://github.com/philschmid/mcp-cli
```

## Core Commands

| Command | Purpose |
|---------|---------|
| `mcp-cli` | List all servers and tools |
| `mcp-cli -d` | List all servers and tools with descriptions |
| `mcp-cli info <server>` | Show all tools available in a server |
| `mcp-cli info <server> <tool>` | Display complete tool JSON schema |
| `mcp-cli grep "<pattern>"` | Search tools by name using glob pattern |
| `mcp-cli call <server> <tool> <json>` | Execute a tool with JSON arguments |

## Recommended Workflow (Discover → Explore → Inspect → Execute)

```bash
# 1. Discover — list all servers and available tools
mcp-cli
mcp-cli -d  # with descriptions

# 2. Explore — view tools for a specific server
mcp-cli info filesystem

# 3. Inspect — examine a specific tool's schema
mcp-cli info filesystem read_file

# 4. Execute — call the tool with arguments
mcp-cli call filesystem read_file '{"path": "./README.md"}'
```

## Configuration

Create `mcp_servers.json` in one of these locations (searched in order):

1. `$MCP_CONFIG` environment variable
2. `-c <path>` command-line argument
3. Current directory
4. `~/.config/mcp/`

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "."]
    },
    "web": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-web"]
    }
  }
}
```

### Tool Filtering

Control which tools are exposed per server:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "."],
      "allowedTools": ["read_file", "list_directory"],
      "disabledTools": ["write_file"]
    }
  }
}
```

### Environment Variable Substitution

```json
{
  "mcpServers": {
    "api": {
      "command": "node",
      "args": ["api-server.js"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    }
  }
}
```

Missing variables cause errors unless `MCP_STRICT_ENV=false`.

## Shell Composition Examples

```bash
# Pipe JSON from stdin
echo '{"path": "./file"}' | mcp-cli call filesystem read_file

# Chain with jq
mcp-cli call filesystem list_directory '{"path": "."}' | jq '.[] | .name'

# Search for tools matching a pattern
mcp-cli grep "read*"
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Client error |
| `2` | Server error |
| `3` | Network issue |

## When to Use mcp-cli vs Native MCP Integration

| Scenario | Recommendation |
|----------|---------------|
| AI agent needs a few specific tools | mcp-cli (discover on demand, save tokens) |
| Shell scripts calling MCP tools | mcp-cli (native shell integration) |
| Debugging MCP server issues | mcp-cli (inspect schemas, test calls) |
| Full IDE integration with many tools | Native MCP (persistent connection, all tools available) |
| CI/CD pipelines | mcp-cli (scriptable, JSON output) |
