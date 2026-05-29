# Plugin: github-app

**Purpose**: env-var driven GitHub App token lifecycle for Claude Code sessions.

## Skills

- `github-app-token` — Manage GitHub App installation tokens in Claude Code sessions. Use when tokens expire, auth errors occur in...
- `github-auth` — Guide Claude through GitHub authentication methods including device code flow, personal access tokens, fine-grained...

## Hooks

- `SessionStart` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook
- `PreToolUse` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook
