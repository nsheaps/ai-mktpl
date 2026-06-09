# Plugin: github-app

**Purpose**: env-var driven GitHub App token lifecycle for Claude Code sessions.

## Skills

- `github-app-token` — Manage GitHub App installation tokens in Claude Code sessions. Use when tokens expire, auth errors occur in...
- `github-app-session-env` — Manually reproduce the SessionStart env wiring (PEM, token, runtime env file, CLAUDE_ENV_FILE, GH_CONFIG_DIR isolation)...
- `github-app-git-identity` — Manually configure the GitHub App bot git identity (app slug + bot user ID, GIT\_\* env vars, isolated GIT_CONFIG_GLOBAL, gh credential helper)...
- `github-auth` — Guide Claude through GitHub authentication methods including device code flow, personal access tokens, fine-grained...

## Hooks

- `SessionStart` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook
- `PreToolUse` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook

## Monitors

- `github-events` (`experimental.monitors`) — auto-starts `bin/events-monitor.sh --if-configured`; polls the GitHub events REST API as the App and emits new events as notifications. No-op until `eventsRepo` / `GITHUB_APP_EVENTS_REPO` is set. Does not load for project-scope plugin installs.
