# Claude Code: On-Disk Folder Structure

This doc maps where Claude Code keeps state on disk. Paths verified against a
running install on Linux as of 2026-04-29; macOS is the same modulo the home
prefix. Windows uses `%USERPROFILE%\.claude\` but the structure is otherwise
identical.

## Two scopes

| Scope | Location | Purpose | Shared? |
| ----- | -------- | ------- | ------- |
| **User** | `~/.claude/` | Cross-project state for the current OS user | Shared across all projects this user opens |
| **Project** | `<repo>/.claude/` | State and config specific to one repo | Committed to the repo (or gitignored as appropriate) |

A project repo can also have `.claude/settings.local.json` for personal
overrides; that file is conventionally gitignored.

## User scope: `~/.claude/`

Top-level files and dirs you'll actually encounter:

| Path | Purpose |
| ---- | ------- |
| `CLAUDE.md` | Personal instructions loaded into every session |
| `settings.json` | User-scope settings (committed-equivalent) |
| `settings.local.json` (rare at user scope) | Personal overrides; **may contain secrets at the root** — never `cat` it, always read specific keys |
| `history.jsonl` | Append-only log of all prompts (one JSON per line). The `conversation-history-search` agent reads this. |
| `.credentials.json` | Anthropic OAuth credentials. Do not read or print. |
| `projects/` | Per-project session transcripts. Subdir name is the project's absolute path with `/` and `.` both replaced by `-` (see "Project path encoding" below). |
| `sessions/` | Active session metadata |
| `session-env/<session-id>/` | **Per-session env propagation files** — see "Session env" below |
| `plugins/` | Plugin marketplaces, cache, and bookkeeping (see "Plugins" below) |
| `agents/` | User-scope subagents (`<name>.md`). May not exist if you've only ever used plugin-bundled agents. |
| `commands/` | User-scope slash commands (deprecated; use skills instead) |
| `skills/<name>/SKILL.md` | User-scope skills. Auto-recalled when their description matches. |
| `hooks/` | User-scope hook scripts (referenced from `settings.json`) |
| `debug/` | Debug logs from recent sessions |
| `tmp/` | Ephemeral scratch (Claude itself uses this; do not confuse with project `.claude/tmp/`) |
| `todos/`, `tasks/` | Task tracking persistence |
| `shell-snapshots/` | Captured shell state for Bash tool calls |
| `paste-cache/` | Cached pasted content |
| `statsig/`, `telemetry/`, `usage-data/`, `stats-cache.json` | Anonymous telemetry buckets |
| `state/`, `cache/` | Misc internal state |
| `channels/` | Used by the `discord` and `telegram` plugins for chat-channel access state |
| `ide/` | IDE integration sockets / state |

### Project path encoding

`~/.claude/projects/` contains one subdir per repo Claude has been opened in.
The encoding rule is: **replace every `/` and `.` in the absolute path with
`-`**. Both characters map to the same `-`, so encoded names with consecutive
dashes mark a `.` boundary or a repeated separator.

Examples (from a real install):

```
/home/nsheaps                              → -home-nsheaps
/home/nsheaps/src                          → -home-nsheaps-src
/home/nsheaps/src/nsheaps/.ai-agent-jack   → -home-nsheaps-src-nsheaps--ai-agent-jack
/home/nsheaps/src/nsheaps/ai-mktpl         → -home-nsheaps-src-nsheaps-ai-mktpl
```

Note the **double dash** in `nsheaps--ai-agent-jack` — that's the `/.` boundary
between `nsheaps/` and `.ai-agent-jack`. The encoding is lossy in principle
(you can't always uniquely reverse it), but in practice it's fine because the
real path is also stored in the session metadata.

### Session env: `~/.claude/session-env/<session-id>/`

This directory is created **per session** and is the mechanism by which
`SessionStart` (and a few other) hooks propagate environment exports into
every subsequent `Bash` tool call within that session.

**Mechanism**:

1. When a session starts, Claude Code sets the env var `CLAUDE_ENV_FILE` to a
   path under `~/.claude/session-env/<session-id>/` (e.g.
   `~/.claude/session-env/<id>/sessionstart-hook-N.sh`).
2. A `SessionStart` hook writes shell exports — or `source` lines pointing at
   another file — to `$CLAUDE_ENV_FILE`.
3. Claude Code arranges for that file (and prior session-env files for the
   same session) to be sourced into the shell of every subsequent `Bash` tool
   call in the session. That's how an export written by a startup hook
   becomes visible to a `Bash(echo $X)` ten turns later.
4. `CwdChanged`, `FileChanged`, and `Setup` hooks also receive a writable
   `CLAUDE_ENV_FILE`.

**Real example**: The `github-app` plugin's
`hooks/scripts/github-token-init.sh` (v0.3.5) writes
`source "$ENV_RUNTIME_FILE"` into `$CLAUDE_ENV_FILE`. The runtime file lives
under the agent config dir and gets refreshed by a `PreToolUse` hook before
each Bash call so `GH_TOKEN` is always fresh. That layering — SessionStart
sources a runtime file, PreToolUse refreshes the runtime file — is the
canonical pattern for "an env var that needs to stay current across a long
session."

**Important: secrets in `session-env/` are EXPECTED, not a leak.**

If you find files under `~/.claude/session-env/<id>/` containing
`export GH_TOKEN=...`, `export OP_SERVICE_ACCOUNT_TOKEN=...`,
`source /path/to/.../github-app-env`, etc. — that is **how the system is
designed to work**. Do NOT:

- Treat it as a credential leak
- Rotate the tokens because you saw them there
- Try to "clean" the directory mid-session — you'll break the running session

Do:

- Treat the directory as part of the running session's lifecycle
- Clean **stale** entries (from old/dead sessions) on session restart, not
  during a session. The `bin/agent` launcher in `nsheaps/.ai-agent-jack`
  performs that cleanup at startup as part of the BUG-18 fix
  (commit `11d2493`); other agent launchers should do the same.
- Apply the standard "never `cat` files that may contain secrets" rule —
  inspect filenames and existence (`ls`, `wc -l`), not contents.

The directory is cheap (typically a handful of small shell snippets per
session); leaving stale dirs around past their session is a hygiene issue,
not a security one — but the contamination from stale entries into a new
session **is** a correctness issue, which is why launchers clean them up.

### Plugins: `~/.claude/plugins/`

| Path | Purpose |
| ---- | ------- |
| `marketplaces/<name>/` | Cloned marketplace repos (e.g. `ai-mktpl/`, `claude-plugins-official/`). The source-of-truth checkout for installable plugins. |
| `cache/<marketplace>/<plugin>/<version>/` | Materialized plugin contents at the version currently enabled. **This is the path your hook scripts and `${CLAUDE_PLUGIN_ROOT}` resolve to at runtime.** |
| `installed_plugins.json` | Which plugins are enabled, at which version, from which marketplace |
| `known_marketplaces.json` | Registered marketplaces |
| `install-counts-cache.json` | Telemetry |
| `blocklist.json` | User-blocked plugins |
| `data/<plugin>/` | Per-plugin persistent data (`${CLAUDE_PLUGIN_DATA}` resolves here) |

So a plugin file at
`plugins/agentic-behavior/skills/claude-code/SKILL.md` in the
`nsheaps/ai-mktpl` repo is materialized at runtime as
`~/.claude/plugins/cache/ai-mktpl/agentic-behavior/<version>/skills/claude-code/SKILL.md`.

`${CLAUDE_PLUGIN_ROOT}` inside any plugin script resolves to
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` — never to the
source repo. If you're editing a plugin and want changes picked up, you must
either bump the version (which the marketplace CD does on merge) or refresh
the cache.

## Project scope: `<repo>/.claude/`

Mirrors the user-scope structure but for a single repo. Common entries:

| Path | Purpose |
| ---- | ------- |
| `CLAUDE.md` | Project instructions |
| `settings.json` | Project settings (committed) |
| `settings.local.json` | Personal overrides (gitignored). **May contain secrets at root** — same `jq 'keys'` discipline as user scope. |
| `rules/*.md` | Project rules, loaded into every session in this repo |
| `skills/<name>/SKILL.md` | Project-scope skills |
| `agents/*.md` | Project-scope subagents |
| `commands/` | Project slash commands (deprecated; prefer skills) |
| `hooks/` | Project hook scripts referenced from `.claude/settings.json` |
| `plans/` | Implementation plans (this repo's convention) |
| `scratch/` | Working notes |
| `tmp/` | Ephemeral scratch — DO use this, do NOT use system `/tmp` (shared between agents) |
| `MEMORY.md`, `memory/*.md` | File-based memory (Jack uses this pattern) |

Project-scope skills, agents, commands, and hooks **stack** with user-scope
ones — both are loaded. Plugin-scope versions also stack on top.

## Settings precedence (high to low)

1. Managed policy settings (org-admin, can't be overridden by user/project)
2. `<repo>/.claude/settings.local.json` (personal, gitignored)
3. `<repo>/.claude/settings.json` (project, committed)
4. `~/.claude/settings.json` (user)
5. Plugin-bundled settings (from each enabled plugin)

`disableAllHooks: true` at any layer (except managed) disables all hooks at
that scope and below.

## See also

- [hooks.md](hooks.md) — full hook lifecycle and event reference
- Official docs: <https://code.claude.com/docs/en/settings>
- Official docs: <https://code.claude.com/docs/en/hooks>
