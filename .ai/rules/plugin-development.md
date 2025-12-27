# Plugin Development Guidelines

## Technology Preferences

**For compiled binaries and complex plugins:**

- Prefer **Bun** as the runtime (fast, TypeScript-native, all-in-one tooling)
- Prefer **TypeScript** for type safety and better developer experience
- Use `bun build --compile` for standalone executables

**Why Bun + TypeScript:**

- Single tool for package management, building, testing, and running
- Native TypeScript support (no transpilation step needed)
- Fast startup and execution times
- Can compile to standalone binaries

## Plugin Structure Requirements

Every plugin must have:

```
plugins/plugin-name/
├── .claude-plugin/
│   └── plugin.json     # Required: name, version, description
├── commands/           # Optional: slash commands
│   └── command-name.md
├── skills/             # Optional: agent skills
│   └── skill-name/
│       └── SKILL.md
└── README.md           # Required: usage documentation
```

**Required plugin.json fields:**

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "What the plugin does",
  "author": {
    "name": "Author Name"
  }
}
```

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

## See Also

- [Versioning Rules](versioning.md) - When and how to bump versions
- [CI/CD Conventions](ci-cd/conventions.md) - Workflow behavior
