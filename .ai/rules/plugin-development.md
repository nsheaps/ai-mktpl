# Plugin & MCP Development Rules

Rules for working with plugins, MCP servers, hooks, and the marketplace repo.

## Marketplace Repo Location

`~/src/nsheaps/ai/...` contains:
- Plugins
- MCP servers
- Hooks
- Shared configuration

## Development Workflow

1. Always review Anthropic documentation before making configuration changes
2. Check if the folder already contains in-flight work
3. Use a git worktree to keep automated changes separate
4. Always make changes in a background Task (`run_in_background: true`)
5. Make a PR for any changes - these require peer review

## Directory Structure

- `~/src/nsheaps/ai/.claude/rules/` - Rules for working on the repo itself (Claude-specific)
- `~/src/nsheaps/ai/.ai/rules/` - User behavior rules (AI-agnostic, syncs to user config)
- `~/src/nsheaps/ai/plugins/*/` - Plugin source code
