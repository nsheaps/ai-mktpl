# Plugin: github-app

**Purpose**: env-var driven GitHub App token lifecycle for Claude Code sessions.

## Skills

- `github-app-token` — Manage GitHub App installation tokens in Claude Code sessions. Use when tokens expire, auth errors occur in...
- `github-app-session-env` — Manually reproduce the SessionStart env wiring (PEM, token, runtime env file, CLAUDE_ENV_FILE, GH_CONFIG_DIR isolation)...
- `github-app-git-identity` — Manually configure the GitHub App bot git identity (app slug + bot user ID, GIT\_\* env vars, isolated GIT_CONFIG_GLOBAL, gh credential helper)...
- `github-auth` — Guide Claude through GitHub authentication methods including device code flow, personal access tokens, fine-grained...

## Hooks

- `SessionStart` / matcher `*` (`bash`) — GitHub App token lifecycle: generate on session start, refresh before expiry via PreToolUse hook
- `SessionStart` / matcher `startup` (`bash`) — Hook-driven event delivery: shows last 10 events and sets cursor baseline
- `SessionStart` / matcher `resume` (`bash`) — Hook-driven event delivery: shows events since last fetch
- `UserPromptSubmit` (`bash`, async + asyncRewake) — Hook-driven event delivery: fetches events since last fetch; rewakes Claude if any new events
- `Stop` (`bash`, async + asyncRewake) — Hook-driven event delivery: polls for events up to eventsStopTimeoutSeconds; rewakes on new events or emits notice at eventsStopNoticeSeconds
- `PreToolUse` (`bash`) — GitHub App token lifecycle: debounced validity check before every tool call

## Entrypoints

- `bin/events-fetch.sh` — One-shot event fetcher used by the hooks above. Accepts `--event <type>` and routes output per `eventsDelivery` config.
- `bin/events-lib.sh` — Shared library: fetch/cursor/delivery logic sourced by events-fetch.sh and events-monitor.sh.
- `bin/events-monitor.sh` — Long-running CLI watcher for use via Monitor tool, cron, or direct invocation. Not a plugin hook.
