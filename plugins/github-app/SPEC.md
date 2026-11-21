# Plugin: github-app

**Purpose**: env-var driven GitHub App token lifecycle for Claude Code sessions.

## Skills

- `github-app-token` — Manage GitHub App installation tokens in Claude Code sessions. Use when tokens expire, auth errors occur in...
- `github-app-session-env` — Manually reproduce the SessionStart env wiring (PEM, token, runtime env file, CLAUDE_ENV_FILE, GH_CONFIG_DIR isolation)...
- `github-app-git-identity` — Manually configure the GitHub App bot git identity (app slug + bot user ID, GIT\_\* env vars, isolated GIT_CONFIG_GLOBAL, gh credential helper)...
- `github-auth` — Guide Claude through GitHub authentication methods including device code flow, personal access tokens, fine-grained...

## Rules

- `github-app-auth` — You have access to GitHub App auth via the `github-app` plugin. When committing, creating PRs, or interacting with the GitHub API, you MUST use the authentication provided by this GitHub App.

## Hooks

- `SessionStart` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook. Also syncs the plugin's rules into project .claude/rules/ via symlink on session start.
- `PreToolUse` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook. Also syncs the plugin's rules into project .claude/rules/ via symlink on session start.
