# Plugin: github-app

**Purpose**: TODO: add description

## Skills

- `github-app-token` — Manage GitHub App installation tokens in Claude Code sessions. Use when tokens expire, auth errors occur in long-running...
- `github-auth` — Guide Claude through GitHub authentication methods including device code flow, personal access tokens, fine-grained toke...

## Hooks

- `PreToolUse` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook
- `SessionStart` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook

