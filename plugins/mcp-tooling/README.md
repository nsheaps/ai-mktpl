# mcp-tooling

Skills for MCP CLI tools, frameworks, proxy daemoning, and gateway patterns. Provides knowledge for discovering, calling, building, and sharing MCP servers across sessions, teams, and networks.

## Skills

### mcp-cli-philschmid

Lightweight Bun-based CLI for shell-native MCP interaction. Dynamic tool discovery reduces token consumption for AI agents.

```
/mcp-cli-philschmid
```

Covers: installation, discover → explore → inspect → execute workflow, `mcp_servers.json` configuration, tool filtering, shell composition patterns.

### mcp-use-framework

Fullstack Python/TypeScript framework for building MCP servers, clients, and agents.

```
/mcp-use-framework
```

Covers: decorator-based server API, programmatic client connections, LangChain agent orchestration, multi-server routing, built-in inspector.

### mcpc-apify

Universal MCP CLI client with persistent sessions and OAuth 2.1 authentication.

```
/mcpc-apify
```

Covers: named session management, OAuth login, interactive shell mode, `key:=value` argument syntax, JSON output for scripting.

### mcp-proxy-daemoning

Pattern for running a shared MCP proxy daemon that multiple Claude Code sessions connect to simultaneously.

```
/mcp-proxy-daemoning
```

Covers: daemon lifecycle management, session registration/cleanup, smart-mcp-proxy configuration, the Serena de-duplication pattern (running project-level servers at user level).

### mcp-gateways

Comprehensive guide to MCP gateway infrastructure for off-host servers, federation, and cross-network sharing.

```
/mcp-gateways
```

Covers: Supergateway, mcp-proxy, ContextForge (IBM), AWS MCP Proxy, Envoy AI Gateway, AgentGateway, liteLLM, Kong AI Gateway. Includes security considerations, architecture decision guide, and network patterns.

## When to Use What

| I want to... | Use this skill |
|--------------|---------------|
| Call MCP tools from the shell | mcp-cli-philschmid |
| Build an MCP server or agent in Python | mcp-use-framework |
| Connect to remote MCP servers with auth | mcpc-apify |
| Share MCP servers across local sessions | mcp-proxy-daemoning |
| Run MCP servers off-host or federate them | mcp-gateways |
