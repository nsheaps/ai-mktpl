# Granola AI Plugin

MCP server integration for [Granola.ai](https://granola.ai) meeting notes. Provides access to meeting search, transcripts, documents, and pattern analysis from Granola's local cache.

## Requirements

- **macOS** with Granola.ai installed
- **[mise](https://mise.jdx.dev/)** - handles Python and uv dependencies automatically
- Granola cache file at `~/Library/Application Support/Granola/cache-v3.json`

## Installation

Add the MCP server to your Claude Code settings. See `settings-fragment.json` for the configuration:

```json
{
  "mcpServers": {
    "granola-ai": {
      "type": "stdio",
      "command": "mise",
      "args": [
        "exec",
        "uv",
        "--",
        "uvx",
        "--from",
        "git+https://github.com/proofgeist/granola-ai-mcp-server",
        "granola-mcp-server"
      ]
    }
  }
}
```

## Environment Variables

| Variable               | Required | Description                                                                        |
| ---------------------- | -------- | ---------------------------------------------------------------------------------- |
| `GRANOLA_PARSE_PANELS` | No       | Set to `0` to disable parsing of rich notes in documentPanels (enabled by default) |

**No authentication secrets required** - the server reads entirely from Granola's local cache.

## Available Tools

| Tool                       | Description                                              |
| -------------------------- | -------------------------------------------------------- |
| `search_meetings`          | Search meetings by title, content, or participants       |
| `get_meeting_details`      | Get comprehensive meeting metadata with local timezone   |
| `get_meeting_transcript`   | Access complete transcript with speaker identification   |
| `get_meeting_documents`    | Retrieve associated notes and summaries                  |
| `analyze_meeting_patterns` | Identify patterns across participants, topics, frequency |

## Important Limitations

- **Read-only access** to cached meeting data
- **macOS only** - requires Granola.ai desktop app
- Cache updates are managed by Granola - long-term cloud data may not be available
- **`search_meetings` does not guarantee ordering** - results may return in any order and ordering cannot be specified

## Documentation

- **Source Repository**: https://github.com/proofgeist/granola-ai-mcp-server
- **Granola.ai**: https://granola.ai

## Skills

This plugin includes the `granola-mcp` skill with detailed guidance on using the MCP server effectively.
