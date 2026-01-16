---
name: Code Simplifier
description: This skill should be used when the user asks to "simplify code", "clean up code", "refactor for clarity", "reduce complexity", "make code more readable", or mentions wanting cleaner, simpler, or more maintainable code. Provides guidance on using the code-simplifier agent and installing required dependencies.
---

# Code Simplifier

Simplify and refine code for clarity, consistency, and maintainability while preserving all functionality. This skill leverages the `pr-review-toolkit:code-simplifier` agent from the official Claude Code plugins.

## Prerequisites

This skill requires the `pr-review-toolkit` plugin from the official Claude plugins repository.

### Check if Dependency is Installed

To verify the plugin is installed, run:

```bash
claude plugin list --json | jq '.[] | select(.id | contains("pr-review-toolkit"))'
```

If output is empty, the plugin needs to be installed.

### Install the Dependency

Install using the Claude CLI:

```bash
# Install to user settings (available in all projects)
claude plugin install pr-review-toolkit@claude-plugins-official --scope user

# OR install to project settings (shared with team via git)
claude plugin install pr-review-toolkit@claude-plugins-official --scope project

# OR install to local settings (personal, not committed)
claude plugin install pr-review-toolkit@claude-plugins-official --scope local
```

**Scope guidance:**

- `user` - Personal use across all projects (default)
- `project` - Team-shared, committed to `.claude/settings.json`
- `local` - Personal override, not committed

### After Installation

Plugins load at session start. If the `pr-review-toolkit:code-simplifier` agent is not available after installation:

1. Note the current session ID (visible in prompt or via `/session`)
2. Exit Claude Code
3. Resume the session:

```bash
# Resume most recent session
claude --continue

# OR resume specific session by ID (replace $SESSION_ID with your actual session ID)
claude --resume $SESSION_ID
```

The agent becomes available after restart.

## Using the Code Simplifier Agent

Once the dependency is installed and available, delegate to the `pr-review-toolkit:code-simplifier` agent using the Task tool:

```
Task tool with subagent_type: "pr-review-toolkit:code-simplifier"
```

### What the Agent Does

The code-simplifier agent:

- Simplifies and refines code for clarity
- Ensures consistency and maintainability
- Preserves all existing functionality
- Focuses on recently modified code unless instructed otherwise

### When to Use

Invoke the code-simplifier agent:

- After completing a feature implementation
- Before creating a pull request
- When code feels overly complex
- During refactoring efforts
- When reviewing unfamiliar code that seems convoluted

### Example Invocations

**Simplify recent changes:**

```
Use the pr-review-toolkit:code-simplifier agent to review and simplify the code I just wrote.
```

**Target specific files:**

```
Use the code-simplifier agent to clean up src/utils/parser.ts - it's gotten too complex.
```

**Broader refactoring:**

```
Launch the code-simplifier agent to review the authentication module for opportunities to reduce complexity.
```

## Troubleshooting

### Agent Not Available

If the agent is not available after installation:

1. Verify installation succeeded:

   ```bash
   claude plugin list --json | jq '.[] | select(.id | contains("pr-review-toolkit"))'
   ```

2. Check if enabled:

   ```bash
   claude plugin list --json | jq '.[] | select(.id | contains("pr-review-toolkit")) | {id, enabled}'
   ```

3. If disabled, enable it:

   ```bash
   claude plugin enable pr-review-toolkit@claude-plugins-official
   ```

4. Restart Claude Code session (plugins load at session start)

### Wrong Marketplace

The plugin is in `claude-plugins-official`, not `claude-code-plugins`. Use the correct identifier:

- ✅ `pr-review-toolkit@claude-plugins-official`
- ❌ `pr-review-toolkit@claude-code-plugins`

### Session Resumption

To continue work after restarting:

```bash
# Continue most recent session in current directory
claude --continue

# Resume specific session (replace $SESSION_ID with your actual session ID)
claude --resume $SESSION_ID

# Fork session (new ID, preserves context)
claude --resume $SESSION_ID --fork-session
```

## Quick Reference

| Task               | Command                                                                                 |
| ------------------ | --------------------------------------------------------------------------------------- |
| Check if installed | `claude plugin list --json \| jq '.[] \| select(.id \| contains("pr-review-toolkit"))'` |
| Install (user)     | `claude plugin install pr-review-toolkit@claude-plugins-official`                       |
| Install (project)  | `claude plugin install pr-review-toolkit@claude-plugins-official --scope project`       |
| Enable             | `claude plugin enable pr-review-toolkit@claude-plugins-official`                        |
| Resume session     | `claude --continue`                                                                     |
| List marketplaces  | `claude plugin marketplace list`                                                        |
