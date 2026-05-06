# 1pass opExec targets — spec

Status: draft (this PR introduces the `projectEnvLocal` target and changes defaults)

## Problem

The 1pass plugin's `opExec` SessionStart hook resolves whole 1Password items to env vars and writes them somewhere the agent can pick up. Historically that was either `$CLAUDE_ENV_FILE` (session-bash-only) or the `env` block of `~/.claude/settings.local.json` (user-global JSON consumed by Claude Code itself).

That second destination is user-global, not per-repo. On a shared machine running multiple agents (alex, henry, jack), each writing into the same `~/.claude/settings.local.json` is the wrong scope — and processes outside Claude Code (direnv-loaded shells, non-Bash tools invoked from the repo) cannot see those vars at all without extra plumbing.

Per [handler directive 2026-05-06](https://discord.com/channels/1490863845252665415/1497431286661517353/1501375706158862527), the dumped env should live at `<agent-repo>/.env.local` instead.

## Contract

The 1pass plugin's `opExec` flow accepts a `targets` array. Available targets:

| Target | Destination | Format | Consumer | Lifecycle |
| - | - | - | - | - |
| `sessionStartBashEnv` | `$CLAUDE_ENV_FILE` | `export K=v` shell lines | Claude Code Bash tool | Session-scoped (file is fresh per session) |
| `projectEnvLocal` | `$CLAUDE_PROJECT_DIR/.env.local` | `export K=v` shell lines | direnv (`dotenv_if_exists .env.local`) and any tool that sources the file | Truncated on each session start; gitignored at the repo level |
| `userSettings` (DEPRECATED for opExec) | `~/.claude/settings.local.json` `.env` block | JSON | Claude Code (all tools) | Persistent across sessions, user-global |

## Default targets

When `opExec.targets` is unset, default to `[sessionStartBashEnv, projectEnvLocal]`.

## File handling for `projectEnvLocal`

- The plugin truncates `$CLAUDE_PROJECT_DIR/.env.local` at the start of each SessionStart op-exec resolution if `projectEnvLocal` is in the targets list. This prevents stale entries from prior sessions accumulating after secrets are removed from the source 1Password item.
- If `CLAUDE_PROJECT_DIR` is unset, the plugin logs a warning and skips this target (it cannot guess the right path).
- The agent repo MUST list `.env.local` in `.gitignore`. (Consumer responsibility.)
- The agent repo's direnv configuration MUST source `.env.local` (e.g. `dotenv_if_exists .env.local` in `.envrc`) if it expects these vars to be available outside Claude Code's Bash tool. (Consumer responsibility.)

## Backwards compatibility

- `userSettings` continues to work when explicitly listed in `targets`. No silent breakage.
- The `userSettings` target is documented as deprecated for `opExec` usage; new configurations should use `projectEnvLocal`.
- Anyone NOT specifying `targets` (relying on the default) will get the new behavior on next session: env dumps to `<repo>/.env.local` instead of the user-global JSON. Consumer repos updating to the new plugin version need to:
  1. Add `.env.local` to `.gitignore`.
  2. Add `dotenv_if_exists .env.local` to `.envrc` (so non-Bash processes also see the env).
  3. (Optional) explicitly pin `targets: [sessionStartBashEnv, userSettings]` to keep the old behavior.

## References

- Handler directive: [Discord 2026-05-06 00:11Z](https://discord.com/channels/1490863845252665415/1497431286661517353/1501375706158862527) and [follow-up](https://discord.com/channels/1490863845252665415/1497431286661517353/1501375892478496809) — "should be done, not ticketed".
- Plugin source: `plugins/1pass/hooks/scripts/op-exec-env.sh`, `plugins/1pass/1pass.settings.yaml`.
- Skill docs: `plugins/1pass/skills/op-exec/SKILL.md`, `plugins/1pass/skills/op/SKILL.md`.
