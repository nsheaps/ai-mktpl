---
name: simplify
description: Simplify and refine code for clarity, consistency, and maintainability using the code-simplifier agent
argument-hint: "[optional: file path or description of code to simplify]"
allowed-tools: Task, Read, Glob, Grep, Bash(claude plugin:*)
---

# Simplify Code Command

Simplify and refine code for clarity, consistency, and maintainability while preserving all functionality.

## Prerequisites Check

Before proceeding, verify the required dependency is installed.

### Check for pr-review-toolkit

Run this command to check if the dependency is available:

```bash
claude plugin list --json | jq '.[] | select(.id | contains("pr-review-toolkit"))'
```

**If output is empty**, the plugin needs to be installed. Ask the user:

> The `pr-review-toolkit` plugin is required but not installed. Would you like me to install it?
>
> - **User scope** (default): Available in all your projects
> - **Project scope**: Shared with team via git commit
> - **Local scope**: Personal override, not committed

Then install based on their choice:

```bash
# User scope (default)
claude plugin install pr-review-toolkit@claude-plugins-official

# Project scope
claude plugin install pr-review-toolkit@claude-plugins-official --scope project

# Local scope
claude plugin install pr-review-toolkit@claude-plugins-official --scope local
```

### After Installation

If the plugin was just installed, inform the user:

> The plugin has been installed. Plugins load at session start, so you'll need to restart Claude Code.
>
> To continue this session after restarting:
>
> ```bash
> claude --continue
> ```
>
> Or resume by session ID:
>
> ```bash
> claude --resume <session-id>
> ```

Then stop - do not attempt to use the agent until after restart.

## When Dependency is Available

If `pr-review-toolkit` is installed and the agent is available, proceed with simplification.

### Determine Scope

Based on **$ARGUMENTS**:

- **No arguments**: Focus on recently modified code (check `git status` for unstaged changes)
- **File path provided**: Focus on the specified file
- **Description provided**: Identify relevant files matching the description

### Launch the Agent

Use the Task tool to delegate to the code-simplifier agent:

```
Task tool:
  subagent_type: "pr-review-toolkit:code-simplifier"
  prompt: "Simplify and refine the following code for clarity, consistency, and maintainability: [describe scope based on arguments]"
```

The agent will:

1. Analyze the code structure and complexity
2. Identify opportunities for simplification
3. Refactor for clarity while preserving functionality
4. Report what was simplified and why

## Usage Examples

```bash
/simplify                              # Simplify recently modified code
/simplify src/utils/parser.ts          # Simplify a specific file
/simplify the authentication module    # Simplify code matching description
```

## What Gets Simplified

The code-simplifier agent focuses on:

- Reducing unnecessary complexity
- Improving code readability
- Ensuring consistent patterns
- Removing dead code
- Simplifying conditional logic
- Extracting repeated patterns

## Safety

- All functionality is preserved
- Changes are made incrementally
- Original logic is maintained
- No breaking changes introduced

## Troubleshooting

### Agent Not Found After Install

Plugins load at session start. After installing, restart Claude:

```bash
claude --continue
```

### Wrong Plugin Installed

Ensure you're using the correct marketplace:

- ✅ `pr-review-toolkit@claude-plugins-official`
- ❌ `pr-review-toolkit@claude-code-plugins`

### Plugin Disabled

Re-enable if disabled:

```bash
claude plugin enable pr-review-toolkit@claude-plugins-official
```
