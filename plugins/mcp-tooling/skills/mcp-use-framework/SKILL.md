---
name: mcp-use-framework
description: >
  Use this skill when working with the mcp-use Python/TypeScript framework for
  building MCP servers, clients, and agents. Use when the user asks about creating
  MCP servers with Python decorators, building MCP agents with LangChain, connecting
  to multiple MCP servers programmatically, or using the mcp-use fullstack framework
  for MCP application development.
---

# mcp-use Framework

**Repository**: https://github.com/mcp-use/mcp-use
**Documentation**: https://manufact.com/docs

A fullstack open-source framework for building MCP applications — servers, clients, agents, and interactive widgets.

## Installation

```bash
# Python (requires 3.11+)
pip install mcp-use

# With E2B sandbox support
pip install "mcp-use[e2b]"

# LLM provider packages (as needed)
pip install langchain-openai      # OpenAI
pip install langchain-anthropic   # Anthropic
pip install langchain-google      # Google

# TypeScript scaffold
npx create-mcp-use-app@latest
```

## Building MCP Servers

Decorator-based, async-first API:

```python
from typing import Annotated
from pydantic import Field
from mcp_use import MCPServer

server = MCPServer(name="Weather Server", version="1.0.0")

@server.tool(
    name="get_weather",
    description="Get weather information for a location"
)
async def get_weather(
    city: Annotated[str, Field(description="City name")]
) -> str:
    return f"Temperature: 72°F, Condition: sunny, City: {city}"

# Run with built-in inspector at /inspector
server.run(transport="streamable-http", port=8000)
```

### Tool Annotations

```python
from mcp_use import MCPServer, ToolAnnotations

@server.tool(
    name="process_data",
    description="Process user data securely",
    annotations=ToolAnnotations(
        readOnlyHint=True,
        openWorldHint=True
    )
)
async def process_data(
    data: Annotated[str, Field(description="Data to process")],
    format: Annotated[str, Field(description="Output format")] = "json"
) -> str:
    return f"Processed: {data} in {format}"
```

## Building MCP Clients

Connect to MCP servers programmatically:

```python
from mcp_use import MCPClient

# From configuration dictionary
config = {
    "mcpServers": {
        "weather": {
            "command": "python",
            "args": ["-m", "weather_server"],
            "env": {"API_KEY": "your_key"}
        }
    }
}
client = MCPClient.from_dict(config)

# From config file
client = MCPClient.from_config_file("config.json")

# From HTTP endpoint
client = MCPClient.from_http("http://localhost:8000/mcp")

# Direct tool invocation (no LLM needed)
result = await client.call_tool("weather", "get_weather", {"city": "San Francisco"})
```

## Building MCP Agents

Agents orchestrate multiple MCP servers with LLM reasoning:

```python
from langchain_openai import ChatOpenAI
from mcp_use import MCPAgent, MCPClient

client = MCPClient.from_config_file("config.json")
llm = ChatOpenAI(model="gpt-4o")

agent = MCPAgent(llm=llm, client=client, max_steps=30)

# Execute a task — agent auto-routes to appropriate servers
result = await agent.run("Find the best restaurant in San Francisco")

# Stream results
async for event in agent.stream("Analyze this code"):
    print(event)

# Target a specific server
result = await agent.run("Get forecast", server_name="weather")

# Restrict tool access
agent = MCPAgent(
    llm=llm,
    client=client,
    allowed_tools=["get_weather", "list_files"]
)
```

## Configuration Format

```json
{
  "mcpServers": {
    "weather": {
      "command": "python",
      "args": ["-m", "weather_server"],
      "env": { "API_KEY": "your_api_key" }
    },
    "remote_api": {
      "url": "http://api.example.com:8000/mcp"
    }
  }
}
```

## Key Features

| Feature | Description |
|---------|-------------|
| Decorator-based API | Simple `@server.tool()` syntax for defining tools |
| Type safety | Pydantic models for automatic parameter validation |
| Async-native | Built for concurrent operations with `async/await` |
| Multi-server agents | Intelligent routing across multiple MCP servers |
| Built-in inspector | Web debugger at `/inspector` on every server |
| Authentication | Bearer token, OAuth middleware support |
| Observability | LangFuse, OpenTelemetry integration |
| LLM agnostic | Works with OpenAI, Anthropic, Google via LangChain |
| Session management | Stateful interactions with `session_id` |

## Debugging

```bash
# INFO level
DEBUG=1 python your_server.py

# Full DEBUG level
DEBUG=2 python your_server.py
```

## When to Use mcp-use

| Scenario | Recommendation |
|----------|---------------|
| Building a new MCP server in Python | mcp-use (decorator API, type safety, built-in inspector) |
| Connecting to multiple MCP servers programmatically | mcp-use client (multi-server config, direct tool calls) |
| Building an AI agent that uses MCP tools | mcp-use agent (LangChain integration, auto-routing) |
| Quick CLI interaction with existing servers | Use mcp-cli or mcpc instead |
| Production deployment with monitoring | mcp-use + Manufact platform |
