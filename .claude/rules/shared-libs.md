# Shared Libraries for Plugins

## Overview

Reusable bash libraries are bundled in the dedicated `shared-lib` plugin (`plugins/shared-lib/lib/*.sh`). Other plugins declare it as a dependency in their `plugin.json` and source the libs from `shared-lib`'s persistent data directory at runtime.

This replaces the older `shared/lib/` + per-plugin symlink layout, which broke after Claude Code v2.1.117 dropped symlink preservation in plugin caches ([#53948](https://github.com/anthropics/claude-code/issues/53948)).

## How dependent plugins consume the libs

In `.claude-plugin/plugin.json`:

```json
{
  "name": "your-plugin",
  "version": "x.y.z",
  "dependencies": [{ "name": "shared-lib", "version": "^1.0" }]
}
```

In each hook script that needs the libs:

```bash
PLUGIN_NAME="your-plugin"

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  SHARED_LIB_DIR="${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib"
else
  # Fallback for invocations outside a Claude Code hook (eg user runs bin/ script).
  SHARED_LIB_DIR="${HOME}/.claude/plugins/data/shared-lib-ai-mktpl/lib"
fi

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
# shellcheck source=/dev/null
source "$SHARED_LIB_DIR/log.sh"
```

The path expression `${CLAUDE_PLUGIN_DATA%/*}/shared-lib-ai-mktpl/lib` strips the dependent plugin's own data-dir name and rebuilds the path to `shared-lib`'s data dir. Plugin data-dir IDs are deterministic (`{plugin-name}-{marketplace-name}`) per the [plugins reference](https://code.claude.com/docs/en/plugins-reference#persistent-data-directory).

The wait loop handles parallel hook ordering: SessionStart hooks across plugins run in parallel, so `shared-lib`'s copy may not have finished when a dependent's hook fires. After the first run, the libs persist in `${CLAUDE_PLUGIN_DATA}` across sessions, so the wait is normally a no-op.

## Available libraries

The libs themselves are unchanged from the prior layout — only how they get loaded has changed. See `plugins/shared-lib/lib/` for source.

### log.sh

Lightweight stderr logging.

```bash
LOG_PREFIX="my-script"
source "$SHARED_LIB_DIR/log.sh"

log_info "..."   # my-script: ...
log_warn "..."   # my-script: [warn] ...
log_error "..."  # my-script: [error] ...
log_step "id" "..."  # my-script: [id] ...
```

Prefix resolution: `LOG_PREFIX` > `PLUGIN_NAME` > `"script"`. **CRITICAL:** Set `LOG_PREFIX` (or `PLUGIN_NAME`) BEFORE sourcing — `log.sh` resolves the prefix at source time.

### hook-output.sh

JSON `additionalContext`/`systemMessage` output for simple hooks.

```bash
source "$SHARED_LIB_DIR/hook-output.sh"
hook_msg "statusline: configured"   # stderr + JSON stdout
hook_msg_only "quiet message"       # JSON stdout only
```

### plugin-config-read.sh

3-tier config resolution (project > user > plugin) for YAML/JSON settings.

```bash
PLUGIN_NAME="my-plugin"   # required
source "$SHARED_LIB_DIR/plugin-config-read.sh"
plugin_is_enabled
plugin_get_config "key" "default"
plugin_get_config_array "key"
```

### tool-install.sh

Project-local binary install helpers.

```bash
source "$SHARED_LIB_DIR/tool-install.sh"
tool_resolve_install_dir
tool_ensure_path "$INSTALL_DIR"
tool_is_available mytool
tool_resolve_github_version "owner/repo" "1.0"
tool_run_install do_install
```

### add-permission.sh

Idempotent permission injection. Requires `safe-settings-write.sh`.

```bash
source "$SHARED_LIB_DIR/safe-settings-write.sh"
source "$SHARED_LIB_DIR/add-permission.sh"
add_permission_to_allow "mcp__my-server__*"
add_permission_to_allow "Bash(tool:*)" "user"
```

### hook-logging.sh

Full hook lifecycle logging with step tracking and structured errors.

```bash
PLUGIN_NAME="my-plugin"  # required
source "$SHARED_LIB_DIR/hook-logging.sh"

hook_log "..."
hook_log_step "download" "..."
hook_fail "curl" "404" "Check URL"
hook_run main_fn
hook_log_cleanup
hook_respond  # MUST be last
```

### safe-settings-write.sh

`jq`-based settings writer.

```bash
SETTINGS_FILE="/path/to/settings.local.json"
source "$SHARED_LIB_DIR/safe-settings-write.sh"
safe_write_settings '.some.key = "value"'
```

## Adding a new shared library

1. Add the file to `plugins/shared-lib/lib/<my-lib>.sh`
2. Include a double-source guard: `if [ "${_MY_LIB_LOADED:-}" = "true" ]; then return 0; fi`
3. Document it in this file (and `plugins/shared-lib/README.md`)
4. Bump `plugins/shared-lib/.claude-plugin/plugin.json` `version`
5. Tag the release: `cd plugins/shared-lib && claude plugin tag --push`
6. Each dependent plugin that uses the new lib: bump its own version, add the new `_wait_for_shared_lib` call, source the lib

## Conventions

- Each lib uses an `_UPPERCASE_LOADED` guard to prevent double-sourcing
- Functions are prefixed by domain (`plugin_`, `tool_`, `add_permission_`, `log_`, `hook_`)
- All libs are idempotent and safe to source multiple times
- Set `PLUGIN_NAME` (and any `LOG_PREFIX` override) BEFORE sourcing any logging lib
- **Never use raw `echo` for logging** — use `log.sh`, `hook-output.sh`, or `hook-logging.sh`
- When sourcing `hook-logging.sh`, no need to wait for/source `log.sh` separately — `hook-logging.sh` handles its own dependencies internally

## Choosing the right logging library

- **Any script** → `log.sh` (basic stderr logging)
- **Simple hook with JSON response** → `hook-output.sh` (replaces `_json_msg`)
- **Complex hook with lifecycle** → `hook-logging.sh` (steps, errors, log files)

See `docs/shared-logging.md` for detailed usage and anti-patterns.
