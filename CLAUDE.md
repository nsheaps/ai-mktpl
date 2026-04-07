# ai-mktpl -- Claude Code Plugin Marketplace

This is the **ai-mktpl** plugin marketplace repository for Claude Code. It contains reusable plugins, organization-wide rules, agents, and commands.

## Before You Start

1. Read the repo overview: [README.md](README.md)
2. Read the plugin schema: [docs/PLUGIN_SCHEMA.md](docs/PLUGIN_SCHEMA.md)
3. Read the development rules: @.claude/rules/plugin-development.md
4. Review existing plugins in `plugins/` for patterns before creating anything new

## Plugin Development Skills (CRITICAL)

When creating or modifying any plugin component, you MUST recall and follow the appropriate `plugin-dev` skill:

| Component       | Skill to recall                  |
| --------------- | -------------------------------- |
| Plugin scaffold | `plugin-dev:plugin-structure`    |
| Skills          | `plugin-dev:skill-development`   |
| Hooks           | `plugin-dev:hook-development`    |
| MCP servers     | `plugin-dev:mcp-integration`     |
| Settings/config | `plugin-dev:plugin-settings`     |
| Commands        | `plugin-dev:command-development` |
| Agents          | `plugin-dev:agent-development`   |
| Creating new    | `plugin-dev:create-plugin`       |

Always recall the relevant skill BEFORE writing code. These skills contain the canonical patterns, schema requirements, and validation steps.

## Rules

All rules in `.claude/rules/` apply. Key ones:

- **plugin-development.md** -- tech stack (Bun + TypeScript), structure requirements, rules vs skills
- **versioning.md** -- when and how to bump plugin versions
- **plugin-hooks-organization.md** -- how to structure hook files
- **shared-libs.md** -- shared library conventions
- **hook-output-patterns.md** -- stdout/stderr patterns for hooks

## Patterns: Learn From Existing Plugins

Before creating a new plugin, study at least 2-3 existing plugins in `plugins/` that have similar components (hooks, MCP servers, skills, commands). Match their conventions.

## Documentation

- [Installation guide](docs/installation.md)
- [Plugin dependencies](docs/plugins-depending-on-another.md)
- [Glossary](docs/glossary.md)
- [Shared logging](docs/shared-logging.md)
- Specs and research live in `docs/specs/` and `docs/research/`
