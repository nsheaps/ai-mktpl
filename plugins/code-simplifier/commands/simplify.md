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

After installing the plugin:

1. Wait approximately 15 seconds for the plugin to load
2. Re-check if the `pr-review-toolkit:code-simplifier` agent is now available
3. If the agent is available, proceed with simplification
4. If the agent is still NOT available after waiting, inform the user:

> The plugin has been installed, but the agent is not yet available. Plugins typically load at session start, so you may need to restart Claude Code.
>
> To continue this session after restarting:
>
> ```bash
> claude --continue
> ```
>
> Or resume by session ID (replace `$SESSION_ID` with the current session ID from `/session`):
>
> ```bash
> claude --resume $SESSION_ID
> ```

Only stop if the agent is unavailable after the availability check - do not assume a restart is needed.

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

**Note:** After simplification, the agent should verify these safety claims by running tests and reviewing the changes to confirm functionality is preserved.

## Troubleshooting

See [SKILL.md Troubleshooting](../skills/code-simplifier/SKILL.md#troubleshooting) for common issues and solutions.
