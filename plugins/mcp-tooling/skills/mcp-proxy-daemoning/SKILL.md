---
name: mcp-proxy-daemoning
description: >
  Use this skill when working with mcp-proxy daemoning patterns — running a shared
  MCP proxy daemon that multiple Claude Code sessions can connect to simultaneously.
  Use when the user asks about sharing MCP servers across sessions, reducing MCP server
  overhead, running a single MCP proxy instance for multiple clients, configuring
  smart-mcp-proxy, or understanding the daemon lifecycle pattern from nsheaps/aitkit.
  Also use for the Serena de-duplication pattern — running project-level MCP servers
  at the user level to avoid duplicate instances across projects.
---

# MCP Proxy Daemoning

Pattern for running a shared MCP proxy daemon that multiple Claude Code sessions connect to simultaneously, reducing resource overhead and enabling cross-session tool sharing.

## The Problem

When multiple Claude Code sessions each spawn their own MCP server processes:

- **Resource waste**: N sessions × M servers = N×M processes
- **No shared state**: Each session has its own isolated tool instances
- **Startup overhead**: Every new session pays the full initialization cost
- **Serena duplication**: A project-level MCP server like Serena that should maintain knowledge across projects gets duplicated per-session, losing cross-project context

## The Solution: Daemon Architecture

A single daemon process runs the MCP proxy, and multiple sessions connect to it via HTTP:

```
Session A ──stdio──→ run-mcp-proxy.sh ──HTTP──→ mcp-proxy daemon (port 12476)
Session B ──stdio──→ run-mcp-proxy.sh ──HTTP──→     (same daemon)
Session C ──stdio──→ run-mcp-proxy.sh ──HTTP──→     (same daemon)
```

## Reference Implementation (nsheaps/aitkit)

The `run-mcp-proxy.sh` script in nsheaps/aitkit implements a full daemon lifecycle:

### Configuration

```bash
MCPPROXY_TOP_K="10"                              # Tools to register per session
MCPPROXY_TOOLS_LIMIT="50"                        # Max tools in active pool
MCPPROXY_DATA_DIR="$AITKIT_ROOT/lib/mcpproxy"    # Database/index location
MCPPROXY_CONFIG_PATH="$MCPPROXY_DATA_DIR/mcp_proxy_config.json"
MCPPROXY_PORT="12476"                            # Listen port
MCPPROXY_TRANSPORT="streamable-http"              # Transport type
```

### Directory Structure

```
~/.aitkit/
├── run/                          # PID files for daemon management
│   ├── mcp-proxy-<name>.pid     # Daemon PID
│   └── mcp-servers/             # Per-session registration
│       ├── 12345                 # Session A's PID
│       └── 12346                 # Session B's PID
└── lib/mcpproxy/
    ├── mcp_proxy_config.json    # MCP server definitions
    ├── mcp-proxy.log            # Daemon log
    └── (database/index files)   # Smart proxy state
```

### Daemon Lifecycle

1. **First session starts** → checks if daemon running → starts daemon
2. **Subsequent sessions** → reuse existing daemon, register their PID
3. **Session exits** → unregisters PID, checks if last session
4. **Last session exits** → kills daemon

```bash
# Simplified lifecycle logic
start_or_reuse_daemon() {
    if daemon_is_running; then
        echo "Reusing existing daemon at PID $(daemon_pid)"
    else
        daemon --name "$DAEMON_NAME" --pidfile "$PID_FILE" \
            --command "uvx smart-mcp-proxy \
                --port $MCPPROXY_PORT \
                --transport $MCPPROXY_TRANSPORT \
                --config $MCPPROXY_CONFIG_PATH"
    fi
    # Register this session
    echo $$ > "$MCP_PID_DIR/$$"
}

on_exit() {
    rm -f "$MCP_PID_DIR/$$"
    if [ "$(ls "$MCP_PID_DIR" | wc -l)" -eq 0 ]; then
        kill_daemon
    fi
}
trap on_exit EXIT
```

### MCP Proxy Config (mcp_proxy_config.json)

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "."]
    },
    "serena": {
      "command": "uvx",
      "args": ["serena", "--workspace", "/path/to/project"]
    }
  }
}
```

### Smart Proxy Features

The `smart-mcp-proxy` (via `uvx`) provides:

- **BM25 tool indexing**: Only registers top-K relevant tools per session
- **Active tool pooling**: Limits active tools to prevent context bloat
- **Tool output truncation**: Prevents oversized responses
- **Dynamic routing**: Routes tool calls to appropriate backend servers

## The Serena De-Duplication Pattern

### Problem

Serena is a code-aware AI agent tool that stores project knowledge in `.serena/memories/`. When configured at the project level:

- Each project gets its own Serena instance
- If Serena should track knowledge across projects (e.g., for a monorepo or related repos), duplicating it per-project defeats the purpose
- The hardcoded path pattern (`/Users/nheaps/.aitkit/upstreams/gathertown/.ai/bin/mcp/serena.sh`) in per-project configs is fragile and non-portable

### Solution: User-Level Daemon with Project Registration

1. **Run Serena at user level** via the mcp-proxy daemon (not per-project)
2. **Register projects** with the daemon config, not in each project's `.mcp.json`
3. **De-duplicate**: If a project's `.mcp.json` declares Serena AND the user-level daemon already runs it, the daemon version takes precedence
4. **Cross-project memory**: Serena's memories persist in the daemon's data directory, shared across all sessions

```
# Instead of this (per-project, fragile):
# project/.mcp.json → serena.sh → standalone serena process

# Do this (user-level, shared):
# ~/.aitkit/lib/mcpproxy/mcp_proxy_config.json includes serena
# All sessions connect to the shared daemon
# Serena runs once, with access to all registered projects
```

### Implementation Steps

1. Add Serena to the mcp-proxy config at `~/.aitkit/lib/mcpproxy/mcp_proxy_config.json`
2. Remove Serena from individual project `.mcp.json` files
3. The daemon manages Serena's lifecycle
4. All sessions access Serena through the shared daemon's HTTP endpoint

## Integrating with Claude Code

In your project's `.mcp.json` or user-level settings, point to the daemon wrapper:

```json
{
  "mcpServers": {
    "shared-proxy": {
      "type": "stdio",
      "command": "/path/to/aitkit/bin/run-mcp-proxy.sh",
      "args": ["mcp-user"]
    }
  }
}
```

The wrapper script:

1. Starts the daemon if not running
2. Registers this session
3. Proxies stdio ↔ HTTP between Claude Code and the daemon
4. Cleans up on exit

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| Daemon not starting | Check `~/.aitkit/lib/mcpproxy/mcp-proxy.log` |
| Stale PID files | Remove `~/.aitkit/run/mcp-servers/*` and `~/.aitkit/run/mcp-proxy-*.pid` |
| Port conflict | Change `MCPPROXY_PORT` in the config |
| Tool not found | Verify `mcp_proxy_config.json` includes the server |
| Daemon crashes between sessions | Background health loop auto-recovers; check logs |
