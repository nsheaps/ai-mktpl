# Create Command Plugin

A Claude Code plugin that helps you create and maintain slash commands with guided assistance.

## Features

- **Guided Command Creation**: Interactive process to create slash commands
- **Scope Selection**: Create commands for user (global), current project, or a specific project
- **Existing Command Detection**: Checks for conflicts and offers to update existing commands
- **Best Practices**: Follows Claude Code slash command conventions
- **Skill Reference**: Includes comprehensive documentation for slash command syntax

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/create-command

# Or locally for testing
cc --plugin-dir /path/to/plugins/create-command
```

## Usage

### Basic Usage

```
/create-command [SCOPE] <command-name> [description]
```

### Arguments

| Argument     | Required | Description                                     |
| ------------ | -------- | ----------------------------------------------- |
| SCOPE        | No       | `user`, `project`, or path to target project    |
| command-name | Yes      | Name of the command (without leading `/`)       |
| description  | No       | Brief description of what the command should do |

### Examples

```bash
# Create a user-level command (available everywhere)
/create-command user backup-db

# Create a project-level command (shared with team)
/create-command project lint-fix

# Create a command in a specific project
/create-command ~/src/myproj deploy

# Let it infer scope, provide description
/create-command review-pr Review pull requests comprehensively
```

## What It Creates

The plugin generates a properly structured slash command file:

```markdown
---
description: Your command description
argument-hint: [expected arguments]
allowed-tools: Bash(command:*) # if needed
---

# Command Name

Clear instructions for Claude...
```

## Scope Locations

| Scope   | Location                       | Notes                        |
| ------- | ------------------------------ | ---------------------------- |
| user    | `~/.claude/commands/`          | Personal, available globally |
| project | `<git-root>/.claude/commands/` | Team-shared, repo-specific   |
| path    | `<path>/.claude/commands/`     | Custom location              |

## Included Skill

This plugin includes a comprehensive skill for writing slash commands at:

```
plugins/create-command/skills/slash-command-writing/SKILL.md
```

The skill covers:

- File format and frontmatter options
- Argument handling (`$ARGUMENTS`, `$1`, `$2`, etc.)
- Bash command execution syntax (`` !`command` ``)
- File references (`@path/to/file`)
- Extended thinking triggers
- Best practices and common patterns
- Troubleshooting guide

## Related Plugins

- [correct-behavior](../correct-behavior/) - Correct AI behavior and update rules
- [skills-maintenance](../skills-maintenance/) - Maintain and update skills
- [command-help-skill](../command-help-skill/) - Help with command discovery

## Contributing

See [Plugin Development Guidelines](../../.claude/rules/plugin-development.md) for contribution guidelines.

## License

MIT
