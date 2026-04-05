# Code Simplifier Plugin

Simplify and refine code for clarity, consistency, and maintainability using the `pr-review-toolkit:code-simplifier` agent.

## Features

- **Automatic dependency management**: Guides installation of required `pr-review-toolkit` plugin
- **Session continuity**: Handles restart requirements with session resumption guidance
- **Flexible targeting**: Simplify recent changes, specific files, or described modules
- **/simplify command**: User-invoked command for on-demand code simplification
- **Skill documentation**: Comprehensive guide for manual usage

## Prerequisites

This plugin requires the `pr-review-toolkit` plugin from the official Claude plugins repository.

### Install the Dependency

```bash
# Install to user settings (available in all projects)
claude plugin install pr-review-toolkit@claude-plugins-official

# OR install to project settings (shared with team)
claude plugin install pr-review-toolkit@claude-plugins-official --scope project
```

### After Installation

Plugins load at session start. After installing, restart Claude Code:

```bash
claude --continue
```

## Installation

### From Marketplace

```bash
claude plugin install code-simplifier@nsheaps-claude-plugins
```

### Local Development

```bash
claude --plugin-dir /path/to/code-simplifier
```

## Usage

### Command

```bash
/simplify                              # Simplify recently modified code
/simplify src/utils/parser.ts          # Simplify a specific file
/simplify the authentication module    # Simplify code matching description
```

### Via Skill

The skill triggers when asking about:

- "simplify code"
- "clean up code"
- "refactor for clarity"
- "reduce complexity"
- "make code more readable"

Example:

> "Can you simplify the parser module? It's gotten too complex."

## File Structure

```
code-simplifier/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── commands/
│   └── simplify.md        # /simplify command
├── skills/
│   └── code-simplifier/
│       └── SKILL.md       # Usage documentation
└── README.md
```

## How It Works

1. **Dependency Check**: Verifies `pr-review-toolkit` is installed
2. **Installation Guide**: If missing, guides through CLI installation
3. **Restart Handling**: Explains session resumption after plugin install
4. **Agent Delegation**: Uses Task tool to launch `pr-review-toolkit:code-simplifier`

## CLI Reference

See [SKILL.md Quick Reference](skills/code-simplifier/SKILL.md#quick-reference) for the full CLI command reference table.

## License

MIT
