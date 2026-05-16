# shared-lib

Internal infrastructure plugin: bundles bash helper libraries used by other
plugins in this marketplace.

## Why this plugin exists

Many plugins in `nsheaps/ai-mktpl` share the same bash helpers
(`log.sh`, `hook-logging.sh`, `plugin-config-read.sh`, etc.). Historically
these were file-level symlinks from each plugin's `lib/` to the repo's
`shared/lib/`. After Claude Code v2.1.117 ([upstream
issue](https://github.com/anthropics/claude-code/issues/53948)), symlinks are
no longer preserved when plugins are copied to the cache, so every plugin's
`source "$CLAUDE_PLUGIN_ROOT/lib/foo.sh"` started failing.

This plugin is the fix:

1. The libraries live here, in `plugins/shared-lib/lib/*.sh`.
2. A `SessionStart` hook (matcher `"*"`) copies them from the plugin root to
   `${CLAUDE_PLUGIN_DATA}/lib/` (with a manifest-hash check so we only
   re-copy when content changes). Running on every session start guarantees
   that updated files are picked up when the plugin is upgraded, not just
   when it is freshly installed.
3. Because the libs are written by a `SessionStart` hook, they are on disk
   before any dependent plugin's `SessionStart` hook body runs (hook
   ordering within a session is deterministic by registration order). The
   wait-loop in dependent plugins is retained as defense-in-depth for edge
   cases where session start hook ordering may vary.
4. Other plugins declare a dependency on `shared-lib` in their
   `plugin.json`, then source the libs out of the shared-lib data
   directory (with a wait-and-source guard as defense-in-depth).

See `docs/research/claude-maintenance-flag-verification.md` in the agent
repo for the historical launcher-contract analysis (why the original
`Setup{init}` approach used `--init-only` and what carries over between
a pre-pass and interactive launch). As of v1.0.2 this plugin uses a
`SessionStart` hook instead; that document is now background reading only.

## How dependent plugins consume it

In each dependent plugin's `.claude-plugin/plugin.json`:

```json
{
  "name": "your-plugin",
  "version": "x.y.z",
  "dependencies": [{ "name": "shared-lib", "version": "^1.0" }]
}
```

In each dependent hook script, replace any `source
"${CLAUDE_PLUGIN_ROOT}/lib/foo.sh"` with the wait-and-source pattern:

```bash
PLUGIN_NAME="your-plugin"

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  # Fallback for when this script is invoked outside a Claude Code hook.
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

# Wait up to ~10s for shared-lib's SessionStart copy.
_wait_for_shared_lib() {
  local lib="$1"
  local i=0
  while [ ! -f "$SHARED_LIB_DIR/$lib" ]; do
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      echo "[$PLUGIN_NAME] timed out waiting for $SHARED_LIB_DIR/$lib (shared-lib SessionStart copy)" >&2
      exit 1
    fi
    sleep 0.5
  done
}

_wait_for_shared_lib "log.sh"
source "$SHARED_LIB_DIR/log.sh"
```

The path expression `${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib`
strips the dependent plugin's own data-dir name and rebuilds the path to
`shared-lib`'s data dir. (Plugin data dir IDs are deterministic:
`{plugin-name}-{marketplace-name}` per the
[plugins reference](https://code.claude.com/docs/en/plugins-reference#persistent-data-directory).)

### Marketplace name constraint

The hardcoded `shared-lib-ai-mktpl` suffix in the path above means **this
marketplace must be installed under the canonical name `ai-mktpl`** for
dependent plugins to resolve `shared-lib`'s data dir.

Claude Code lets users alias a marketplace at install time:

```bash
# WRONG — aliasing breaks shared-lib resolution:
claude plugin marketplace add nsheaps/ai-mktpl --name nsheaps-ai

# CORRECT — keep the default name:
claude plugin marketplace add nsheaps/ai-mktpl
```

If you alias to anything other than `ai-mktpl`, every dependent plugin's
`_wait_for_shared_lib` guard will time out after 10s because the
hardcoded path expression won't resolve to the actual data dir.

This constraint is repeated in `.claude/rules/shared-libs.md` and in the
bootstrap stanza of every dependent plugin (23 sites today). A future
refactor (tracked as a follow-up) may derive the marketplace suffix from
`CLAUDE_PLUGIN_DATA` instead of hardcoding it.

## Bundled libraries

| File                     | Purpose                                                                                |
| :----------------------- | :------------------------------------------------------------------------------------- |
| `add-permission.sh`      | Helpers for adding permissions to settings files                                       |
| `env-file.sh`            | Idempotent upsert/remove of `export KEY=...` and `source ...` lines in bash env files  |
| `env-local-target.sh`    | Resolve "envLocal" target paths (`$AGENT_HOME_DIR/.env.local`) and source-chain wiring |
| `hook-logging.sh`        | Full hook lifecycle logging (start/respond/cleanup/fail)                               |
| `hook-output.sh`         | Lightweight JSON `additionalContext` output for simple hooks                           |
| `log.sh`                 | Generic stderr logger with configurable prefix                                         |
| `plugin-config-read.sh`  | 3-tier YAML/JSON plugin config resolver                                                |
| `safe-settings-write.sh` | Atomic JSON edits to `settings.json`                                                   |
| `tool-install.sh`        | Helpers for installing tools to project-local install dirs                             |

## Hook ordering

The `SessionStart` hook fires at the start of every session (fresh launch,
`--resume`, `--continue`, or post-`/compact` resume). The manifest-diff
check keeps the hot path fast: if the lib content hasn't changed since the
last sync, the script exits in milliseconds.

The wait-loop in dependent plugins is retained as defense-in-depth: it
handles edge cases where hook ordering may cause a race (e.g., a dependent
plugin's `SessionStart` hook is scheduled before shared-lib's), and is a
no-op on the hot path since the libs persist across sessions.

## Releasing

Tag with:

```bash
cd plugins/shared-lib
claude plugin tag --push
```

This creates `shared-lib--v1.0.0` (or whatever `plugin.json` declares),
which dependent plugins resolve via their `^1.0` constraint.
