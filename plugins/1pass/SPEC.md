# Plugin: 1pass

**Purpose**: TODO: add description

## Skills

- `op-exec` — Use this skill when the user asks about op-exec, running commands with 1Password secrets injected, wrapping processes wi...
- `op` — Use this skill when the user asks about 1Password, secrets management, retrieving credentials, using op CLI, service acc...

## Hooks

- `PostToolUse` (`bash`) — Install 1Password CLI/op-exec, inject secrets on session start, and redact secrets from tool outputs
- `SessionStart` (`bash`) — Install 1Password CLI/op-exec, inject secrets on session start, and redact secrets from tool outputs
- `Setup` (`bash`) — Install 1Password CLI/op-exec, inject secrets on session start, and redact secrets from tool outputs

