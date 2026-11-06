# Plugin: direnv

**Purpose**: Install and manage [direnv](https://direnv.net) (per-directory environment loader) in Claude Code sessions.

## Skills

- `direnv` — Use this skill when the user asks about managing per-directory environment variables, working with .envrc, understanding why direnv env vars aren't loaded, or any task involving direnv.

## Hooks

- `SessionStart` (`bash`) — Install direnv, run `direnv allow`, and compute the `.envrc` diff once via `direnv export bash` into `CLAUDE_ENV_FILE`.
- `PreToolUse` (`bash`, matcher `Bash`) — Debounced check of the `.envrc` fingerprint; re-exports only when it changed.
