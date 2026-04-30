# shared-lib

Internal infrastructure plugin: bundles bash helper libraries used by other
plugins in this marketplace.

## Why this plugin exists

Many plugins in `nsheaps/ai-mktpl` share the same bash helpers
(`logging.sh`, `hook-logging.sh`, `plugin-config-read.sh`, etc.). Historically
these were file-level symlinks from each plugin's `lib/` to the repo's
`shared/lib/`. After Claude Code v2.1.117 ([upstream
issue](https://github.com/anthropics/claude-code/issues/53948)), symlinks are
no longer preserved when plugins are copied to the cache, so every plugin's
`source "$CLAUDE_PLUGIN_ROOT/lib/foo.sh"` started failing.

This plugin is the fix:

1. The libraries live here, in `plugins/shared-lib/lib/*.sh`.
2. A `SessionStart` hook copies them from the plugin root to
   `${CLAUDE_PLUGIN_DATA}/lib/` once per session (with a manifest-hash check
   so we only re-copy when content changes).
3. Other plugins declare a dependency on `shared-lib` in their
   `plugin.json`, then source the libs out of the shared-lib data
   directory.

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

## Bundled libraries

| File                     | Purpose                                                      |
| :----------------------- | :----------------------------------------------------------- |
| `add-permission.sh`      | Helpers for adding permissions to settings files             |
| `hook-logging.sh`        | Full hook lifecycle logging (start/respond/cleanup/fail)     |
| `hook-output.sh`         | Lightweight JSON `additionalContext` output for simple hooks |
| `log.sh`                 | Generic stderr logger with configurable prefix               |
| `plugin-config-read.sh`  | 3-tier YAML/JSON plugin config resolver                      |
| `safe-settings-write.sh` | Atomic JSON edits to `settings.json`                         |
| `tool-install.sh`        | Helpers for installing tools to project-local install dirs   |

## Hook ordering caveat

Hooks across plugins run in parallel and the docs do not guarantee
ordering. The wait-loop in dependents handles the case where a dependent's
hook fires before this plugin's `sync-lib.sh` finishes the copy. After the
first session, the libs persist in `${CLAUDE_PLUGIN_DATA}` across
restarts, so the wait is normally a no-op.

## Releasing

Tag with:

```bash
cd plugins/shared-lib
claude plugin tag --push
```

This creates `shared-lib--v1.0.0` (or whatever `plugin.json` declares),
which dependent plugins resolve via their `^1.0` constraint.
