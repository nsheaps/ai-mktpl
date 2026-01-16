# Linear MCP Sync Plugin

A Claude Code plugin that installs the Linear MCP server and adds hooks to prevent stale ticket updates through hash validation.

## Overview

This plugin ensures data integrity when working with Linear issues by:

1. **Tracking reads**: When you fetch a Linear issue, a hash of its content is saved
2. **Validating updates**: Before updating an issue, the plugin verifies it was previously fetched
3. **Preventing stale writes**: If you try to update an issue without fetching it first, the update is blocked

This prevents accidentally overwriting changes made by teammates or external integrations.

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/linear-mcp-sync

# Or locally for testing
cc --plugin-dir /path/to/plugins/linear-mcp-sync
```

### Additional Configuration

After installation, you need to:

1. Install Linear MCP Server:

   ```bash
   claude mcp add linear --scope user -- npx -y mcp-remote https://mcp.linear.app/sse
   ```

2. Hooks are automatically configured by the plugin

## How It Works

### Hash Save Hook (PostToolUse)

When you fetch a Linear issue using any "get" or read operation:

1. The hook captures the API response
2. Computes a SHA256 hash of the response data
3. Stores the hash with a timestamp in a session-specific file

### Hash Check Hook (PreToolUse)

When you attempt to update a Linear issue:

1. The hook extracts the issue ID from the update request
2. Checks if that issue was previously fetched in this session
3. If **not fetched**: Blocks the update and displays an error message
4. If **fetched**: Allows the update to proceed

### Example Workflow

```
# This will FAIL - issue not fetched first
Claude: Update issue LIN-123 status to "In Progress"
> Error: Cannot update issue LIN-123: This issue has not been fetched
> in the current session. Please read the issue first...

# Correct workflow
Claude: Get details of issue LIN-123
> [Issue details displayed, hash saved]

Claude: Update issue LIN-123 status to "In Progress"
> [Update succeeds]
```

## Configuration

### Hook Matchers

The default matchers cover common Linear MCP tool patterns:

| Hook Type   | Matcher Pattern                                   | Description              |
| ----------- | ------------------------------------------------- | ------------------------ |
| PostToolUse | `mcp__linear__.*(get\|Get\|issue$\|Issue$)`       | Matches read operations  |
| PreToolUse  | `mcp__linear__.*(update\|Update\|create\|Create)` | Matches write operations |

You can customize these patterns in your settings.json if the Linear MCP tool names differ.

### Storage Location

Hashes are stored in session-specific files at:

- `$TMPDIR/linear-mcp-hashes/<session_id>.json` (or `/tmp/linear-mcp-hashes/` if TMPDIR is not set)

This ensures hashes are isolated per session and automatically cleaned up.

## Troubleshooting

### "Cannot update issue: This issue has not been fetched"

This is the expected behavior! The plugin is working correctly. Fetch the issue first:

```
Claude: Get issue LIN-123
```

Then retry your update.

### Hooks Not Triggering

1. Verify hooks are in your settings.json
2. Check the matcher patterns match your Linear MCP tool names
3. Ensure hook scripts are executable: `chmod +x hooks/*.sh`
4. Check Claude Code logs for hook errors

### Linear MCP Authentication

On first use, Linear MCP will prompt for OAuth authentication. Follow the browser prompts to authorize access to your Linear workspace.

## Requirements

- Claude Code CLI installed
- Node.js and npm (for mcp-remote)
- jq (for JSON processing in hooks)
- A Linear account and workspace

## File Structure

```
linear-mcp-sync/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── hooks/
│   ├── linear-hash-save.sh  # PostToolUse: Save hash after reads
│   └── linear-hash-check.sh # PreToolUse: Validate before updates
├── scripts/
│   └── install.sh           # Installation script
├── settings-fragment.json   # Hook configuration template
└── README.md                # This file
```

## Security Considerations

- Hashes are stored locally in temp directories
- Session files are automatically cleaned up on system restart
- No sensitive data (tokens, issue content) is stored in hash files
- OAuth tokens are managed by the Linear MCP server, not this plugin

## Contributing

Issues and pull requests welcome at: https://github.com/nsheaps/.ai

## License

MIT License - See repository for details.
