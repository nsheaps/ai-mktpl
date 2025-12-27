# Memory Manager Plugin

Intelligent memory management for CLAUDE.md files. Automatically detects and stores user preferences, rules, and instructions with smart scope detection and hierarchical organization.

## Features

- **Automatic Detection**: Watches for phrases like "always", "never", "don't forget", "prefer", "remember to", "from now on"
- **Smart Scope Detection**: Intelligently determines if preferences should be stored globally or per-project
- **Hierarchical Organization**: Organizes memories into categories with proper markdown structure
- **Confirmation Messages**: Shows what was remembered and where it was written

## Installation

```bash
/plugin install memory-manager@nsheaps-claude-plugins
```

## Usage

Simply express preferences naturally in conversation:

- "Never use rebasing, prefer merge instead"
- "Always put API endpoints in src/api/ in this project"
- "Don't forget to run tests before committing"

The plugin will automatically:

1. Detect the memory-worthy statement
2. Determine the appropriate scope (global or project)
3. Update the relevant CLAUDE.md file
4. Confirm with messages like:
   - `I'll remember to prefer merging over rebasing`
   - `Wrote $HOME/.claude/CLAUDE.md`

## Trigger Phrases

The plugin activates on:

- "always", "never"
- "don't forget", "make sure"
- "prefer X over Y"
- "remember to...", "from now on..."
- "I can't believe you did that"
- "You messed up", "did it wrong"
- Important dates (vacation, birthdays, deadlines)

## Scope Detection

**Global scope** (written to `~/.claude/CLAUDE.md`):

- Mentions "all projects", "everywhere"
- Tool preferences, git workflow, communication style

**Project scope** (written to project's CLAUDE.md):

- Mentions specific files or directories
- Architecture decisions for this codebase
- User says "in this project"

## Memory Categories

Memories are organized under sections:

- Git Workflow
- Code Style
- Development Environment
- Testing Preferences
- Documentation
- Architecture
- Dependencies
- Communication Style

## License

MIT
