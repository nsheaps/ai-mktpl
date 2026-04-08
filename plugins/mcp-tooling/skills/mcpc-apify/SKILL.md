---
name: mcpc-apify
description: >
  Use this skill when working with Apify's mcpc — a universal CLI client for MCP
  with persistent sessions, OAuth authentication, and interactive shell mode.
  Use when the user asks about connecting to remote MCP servers, managing MCP
  sessions, authenticating with OAuth for MCP, or using Apify's MCP platform.
  Also use when comparing MCP CLI tools or needing persistent named sessions.
---

# mcpc (Apify MCP CLI Client)

**Repository**: https://github.com/apify/mcp-cli
**Package**: `@apify/mcpc`

A universal CLI client for MCP with persistent sessions, OAuth 2.1 authentication, and interactive shell mode. Configure once, reuse across multiple AI coding agents and environments.

## Installation

```bash
# Via npm
npm install -g @apify/mcpc

# Via Bun
bun install -g @apify/mcpc
```

On Linux, uses the Secret Service API for secure credential storage with automatic fallback to file-based storage on headless systems.

## Core Concepts

### Named Sessions

mcpc maintains persistent named sessions — long-lived connections to MCP servers that survive across commands:

```bash
# Create a persistent session
mcpc connect mcp.apify.com @apify

# Use the session for any command
mcpc @apify tools-list
mcpc @apify tools-call search-actors keywords:="web scraper"

# List all active sessions
mcpc

# Close/restart a session
mcpc @apify close
mcpc @apify restart
```

### Authentication

```bash
# Interactive OAuth 2.1 login (tokens stored in OS keychain)
mcpc login mcp.apify.com

# Logout
mcpc logout mcp.apify.com

# Use specific auth profile
mcpc --profile my-profile @session tools-list
```

## Commands

### Tools

```bash
# List available tools
mcpc @session tools-list

# Get tool details
mcpc @session tools-get <tool-name>

# Call a tool with typed arguments (key:=value syntax)
mcpc @session tools-call search-actors keywords:="website crawler" count:=10
```

Arguments use `key:=value` syntax with automatic JSON type parsing.

### Resources and Prompts

```bash
# Resources
mcpc @session resources-list
mcpc @session resources-read <uri>

# Prompts
mcpc @session prompts-list
mcpc @session prompts-get <prompt-name> arg1:=value1
```

### Discovery and Exploration

```bash
# Search across tools, resources, prompts
mcpc grep <pattern>

# Interactive shell mode
mcpc @session shell
```

### Output Modes

```bash
# JSON output for scripting
mcpc --json @session tools-list
mcpc --json @session tools-call tool-name arg:=value | jq '.result'

# Default: human-readable with colors
mcpc @session tools-list
```

## Configuration

### Storage Locations

- **Session metadata**: `~/.mcpc/sessions.json`
- **Auth tokens**: OS keychain (fallback: `~/.mcpc/credentials` mode 0600)

### Server Configuration Examples

```json
{
  "mcpServers": {
    "apify": {
      "url": "https://mcp.apify.com"
    }
  }
}
```

With bearer token:

```json
{
  "mcpServers": {
    "apify": {
      "url": "https://mcp.apify.com",
      "headers": {
        "Authorization": "Bearer <APIFY_TOKEN>"
      }
    }
  }
}
```

### Custom Tool Selection

```bash
# Via URL parameters
# https://mcp.apify.com?tools=actors,docs,apify/rag-web-browser

# Via CLI
npx @apify/actors-mcp-server --tools actors,docs,apify/web-scraper
```

## Key Differences from philschmid/mcp-cli

| Feature          | mcpc (Apify)                 | mcp-cli (philschmid)       |
| ---------------- | ---------------------------- | -------------------------- |
| Sessions         | Persistent named sessions    | Stateless per-command      |
| Authentication   | Full OAuth 2.1 + keychain    | Environment variables only |
| Transport        | Streamable HTTP + stdio      | stdio + HTTP               |
| Interactive mode | Shell mode (`mcpc @s shell`) | No interactive mode        |
| Connection model | Session-based (connect once) | Per-invocation             |
| Runtime          | Node.js                      | Bun                        |

## Practical Workflow

```bash
# 1. Connect and authenticate
mcpc connect https://mcp.apify.com @apify
mcpc login https://mcp.apify.com

# 2. Discover tools
mcpc @apify tools-list

# 3. Call tools
mcpc @apify tools-call search-actors keywords:="web scraper" count:=10

# 4. Script with JSON output
mcpc --json @apify tools-list | jq '.tools[] | .name'

# 5. Manage session
mcpc @apify close
```
