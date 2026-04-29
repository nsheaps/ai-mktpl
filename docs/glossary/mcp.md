# MCP (Model Context Protocol)

**Definition:** A protocol for AI models to interact with external tools and services in a standardized way.

**Key Concepts:**

- **MCP Server**: A service that exposes tools via the protocol
- **MCP Tool**: A specific capability provided by a server (e.g., `mcp__github__create_issue`)
- **MCP Configuration**: JSON specifying which servers are available and how to invoke them

**Permission Model:**

- Tools must be explicitly allowed via `permissions.allow` in settings
- `enableAllProjectMcpServers` makes project-defined servers discoverable
- CLI args (`--mcp-config`) specify servers but don't grant permissions
