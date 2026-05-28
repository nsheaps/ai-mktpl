# Plugin: 1pass

**Purpose**: Install and manage [1Password CLI](https://developer.1password.com/docs/cli/) (op) and [op-exec](https://github.com/nsheaps/op-exec) in Claude Code sessions.

## Skills
- `op` — Use this skill when the user asks about 1Password, secrets management, retrieving credentials, using op CLI, service...
- `op-exec` — Use this skill when the user asks about op-exec, running commands with 1Password secrets injected, wrapping processes...

## Hooks
- `Setup` (`bash`) — Install 1Password CLI/op-exec, inject secrets on session start, and redact secrets from tool outputs
- `SessionStart` (`bash`) — Install 1Password CLI/op-exec, inject secrets on session start, and redact secrets from tool outputs
- `PostToolUse` (`bash`) — Install 1Password CLI/op-exec, inject secrets on session start, and redact secrets from tool outputs
