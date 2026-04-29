# dangerous-bypass

Auto-approve **ALL** permission requests in Claude Code sessions.

## Warning

This plugin removes all interactive permission prompts. Every tool call (Bash, Edit, Write, etc.) will be automatically approved without user confirmation.

**Only use in trusted environments** where the agent is expected to operate autonomously without human-in-the-loop permission checks.

## How It Works

A single `PermissionRequest` hook returns an `approve` decision for every permission request, regardless of tool type, command, or target.

## Setup

Enable in your project or user settings:

```yaml
# .claude/settings.json
{ "enabledPlugins": { "dangerous-bypass@ai-mktpl": true } }
```

## When to Use

- Agentic AI sessions running unattended (e.g., in tmux)
- Automated workflows where permission prompts would stall execution
- Development/testing environments with trusted code

## When NOT to Use

- Production environments with untrusted input
- Sessions where you want to review commands before execution
- Shared machines where other users might trigger unintended actions
