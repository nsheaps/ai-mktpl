# direnv

Install and manage [direnv](https://direnv.net) (per-directory environment loader) in Claude Code sessions.

direnv loads project-scoped environment variables from an `.envrc` file when
you `cd` into a directory. This plugin makes those variables available to
every `Bash` tool call in a Claude Code session — **without** installing
direnv's interactive shell hook.

## Features

- **Auto-install**: Downloads the direnv binary to `$CLAUDE_PROJECT_DIR/bin/.local/` when not already on PATH
- **Auto-allow**: Runs `direnv allow` for the project's `.envrc` (and any git worktrees) so the export step doesn't get silently blocked
- **One-shot export, not a shell hook**: Computes the `.envrc` diff via `direnv export bash` and writes it as static `export`/`unset` statements — see [Why not `direnv hook bash`?](#why-not-direnv-hook-bash) below
- **Change-aware PreToolUse hook**: Re-computes the diff before `Bash` calls, but only when the `.envrc` fingerprint (path + mtime + size) has actually changed, debounced to avoid re-checking on every single call
- **claude-utils integration (enhancement, not required)**: uses [nsheaps/claude-utils](https://github.com/nsheaps/claude-utils)' `agent-plugin`/`agent-hook` binaries when they're on PATH — see [claude-utils integration](#claude-utils-integration-agent-plugin--agent-hook) below

## How It Works

1. **Session starts**: installs direnv if needed, runs `direnv allow` on `.envrc`, then runs `direnv export bash` once and writes the result to `$CLAUDE_PLUGIN_DATA/direnv-env`
2. **`CLAUDE_ENV_FILE` wiring**: a single `source "$CLAUDE_PLUGIN_DATA/direnv-env"` line is added to `CLAUDE_ENV_FILE` (idempotent — added once), so every subsequent `Bash` call picks up the current snapshot
3. **Before each `Bash` call**: the `PreToolUse` hook checks (debounced) whether the nearest `.envrc` has changed. If so, it re-runs `direnv export bash` and **overwrites** `direnv-env` in place, so vars removed from `.envrc` are correctly dropped, not just left stale
4. **Directory awareness**: the `PreToolUse` hook makes a best-effort attempt to detect a `cd <dir> &&` prefix in the Bash command to resolve the "current" directory before looking for `.envrc`; if none is found it falls back to `$CLAUDE_PROJECT_DIR`

## Why not `direnv hook bash`?

direnv's own documented shell integration (`eval "$(direnv hook bash)"`) installs a `PROMPT_COMMAND`-style hook that re-runs on **every** shell command. That pattern causes the same problems this repo's `mise` plugin avoids (see `plugins/mise/hooks/scripts/install-mise.sh`):

1. direnv can write status/error text to stderr (and in some configurations, stdout) on every command — polluting command output
2. If that output were ever `eval`'d, it becomes an eval-injection risk
3. It overrides `cd`/`pushd`/`popd`, adding overhead that's unnecessary in a non-interactive agent shell that already gets `CLAUDE_ENV_FILE` re-sourced by the harness

Instead, this plugin runs `direnv export bash` **directly** (never via `eval` inside `CLAUDE_ENV_FILE`), captures its output once, and writes it as a static snapshot. The snapshot is only regenerated when the `PreToolUse` hook detects the `.envrc` state actually changed.

## claude-utils integration (`agent-plugin` / `agent-hook`)

[nsheaps/claude-utils](https://github.com/nsheaps/claude-utils) ships two native binaries meant for exactly this kind of plugin: `agent-plugin` (logging, per-plugin settings, `ensure-dependency`) and `agent-hook` (parses a hook's JSON stdin, emits its decision). This plugin uses both **opportunistically, not as a hard dependency** — install with `brew install nsheaps/devsetup/claude-utils` to opt in; everything below still works without it.

- **Install** (`install-direnv.sh`): when `agent-plugin` is on PATH, tries `agent-plugin ensure-dependency direnv "direnv@latest"` first (installs via `mise use -g direnv@latest` — the mise registry resolves the bare name `direnv` to the `aqua:direnv/direnv` backend). On **any** failure — `agent-plugin` absent, its own `autoInstall` setting declined, no `mise`, or the mise install itself failing — falls back to the direct GitHub-release download that has always been this plugin's install mechanism.
- **Logging**: when `agent-plugin` is on PATH, routes log messages through `agent-plugin log-*` (level-filterable via `$AGENT_PLUGIN_LOG_LEVEL`) in addition to this repo's own `hook-logging.sh` lifecycle (which SessionStart's summary output and failure diagnostics still depend on either way).
- **PreToolUse input parsing** (`direnv-check.sh`): when `agent-hook` is on PATH, uses `agent-hook export-input` instead of hand-rolled `jq` parsing to read `tool_name`/`tool_input.command` from the hook payload. Falls back to `jq` otherwise. This hook never calls `agent-hook allow`/`deny` for its "nothing changed" case — per this repo's [hook-output-patterns.md](../../.claude/rules/hook-output-patterns.md), a PreToolUse hook with no opinion must emit nothing at all, not an explicit `allow` (which would bypass the normal permission system for every `Bash` call).

### Why an enhancement, not a hard dependency

`agent-plugin`'s settings (`.claude/settings.direnv.yaml`, one file per plugin) are a **different file** from this plugin's own `direnv.settings.yaml`/`plugins.settings.yaml` convention (read via `shared-lib`'s `plugin-config-read.sh`, the convention every other ai-mktpl plugin uses). Requiring both to be configured to get auto-install working would be a regression for the plugin's existing settings story, and no other ai-mktpl plugin depends on claude-utils yet. So `direnv.settings.yaml`'s own `autoInstall` remains the single source of truth for _whether_ to install at all; `agent-plugin`/`mise` is only an alternate _mechanism_, tried first when available, with the original curl-based download as the unconditional fallback.

### Debounce/throttle — pending upstream extraction

The `PreToolUse` hook's debounce (`should_check`/`record_check` in `direnv-check.sh`) is a local `DEBOUNCE_FILE` + elapsed-seconds implementation, the same pattern originally written inline in the `github-app` plugin. [nsheaps/claude-utils#436](https://github.com/nsheaps/claude-utils/pull/436) (branch `feature/agent-hook-throttle`) generalizes this into a reusable `bin/lib/agent-hook-throttle.sh` (`throttle_should_run`/`throttle_record`). Once that PR merges and ships in a release, `direnv-check.sh` should swap to sourcing it — the local functions are deliberately isolated so that swap is a one-function change, not a rewrite.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

direnv:
  enabled: true # Enable/disable the plugin
  autoInstall: true # Download direnv if not on PATH
  installToProject: true # Install to $project/bin/.local (vs ~/.local/bin)
  backgroundInstall: false # Run install in background
  version: "latest" # Pin a specific version or use "latest"
  autoAllow: true # Run `direnv allow` for .envrc on session start
  checkIntervalSeconds: 2 # Debounce interval for the PreToolUse .envrc check
```

## On-disk Layout

All files are written under `$CLAUDE_PLUGIN_DATA/` (per-agent isolated):

```
$CLAUDE_PLUGIN_DATA/
├── direnv-env            # Runtime env file (static export/unset statements), sourced via CLAUDE_ENV_FILE
├── direnv-fingerprint     # path:mtime:size of the last-exported .envrc
└── direnv-last-check      # Debounce timestamp for the PreToolUse check
```

## Plugin Structure

```
plugins/direnv/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── install-direnv.sh   # SessionStart: install, allow, initial export
│       └── direnv-check.sh     # PreToolUse (Bash): debounced re-export on .envrc change
├── lib/
│   └── direnv-export.sh        # Shared: platform detection, fingerprinting, export+write
├── skills/
│   └── direnv/SKILL.md         # Manual-operation reference
└── README.md
```

## Limitations

- The `PreToolUse` hook cannot see the persistent Bash shell's actual current directory — it makes a best-effort guess by parsing a leading `cd <dir> &&`/`cd <dir>;` from the command, falling back to `$CLAUDE_PROJECT_DIR`. Deeply nested `cd`s inside a script, or directory changes via other means, are not tracked.
- direnv must have already been `allow`ed for a given `.envrc` (handled automatically for the project dir and worktrees at session start when `autoAllow: true`). A brand-new `.envrc` created mid-session in a directory the plugin hasn't seen before will need an explicit `direnv allow` — see the `direnv` skill for the manual procedure.

## Related

- **[mise](../mise)** — tool version manager; follows the same "static export, no shell hook" discipline
- **[shared-lib](../shared-lib)** — bash helper libraries this plugin depends on
