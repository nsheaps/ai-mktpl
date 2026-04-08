# Shared Libraries for Plugins

## Overview

Reusable bash libraries live in `shared/lib/` and are symlinked into each plugin's `lib/` directory. Plugins reference them via `${CLAUDE_PLUGIN_ROOT}/lib/<lib>.sh`.

## Available Libraries

### log.sh

Lightweight general-purpose stderr logging for any bash script. Works in any context — plugin hooks, session-start scripts, utility scripts, bin scripts.

```bash
LOG_PREFIX="my-script"               # Optional: defaults to PLUGIN_NAME or "script"
source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"

log_info "Installing tool v1.2.3"    # my-script: Installing tool v1.2.3
log_warn "Fallback to default"       # my-script: [warn] Fallback to default
log_error "File not found"           # my-script: [error] File not found
log_step "download" "Downloading..." # my-script: [download] Downloading...
```

Prefix resolution: `LOG_PREFIX` > `PLUGIN_NAME` > `"script"`.

All output goes to stderr. Never interferes with stdout.

### hook-output.sh

Shared JSON output helper for hooks that return `{additionalContext, systemMessage}`. Replaces the duplicated `_json_msg()` pattern.

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-output.sh"

hook_msg "statusline: configured"    # stderr + JSON stdout
hook_msg_only "quiet message"        # JSON stdout only
```

Use for simple SessionStart hooks that output a single status message. For hooks with steps and error reporting, use `hook-logging.sh` instead.

### plugin-config-read.sh

3-tier config resolution for plugin settings. Supports both YAML and JSON formats.

```bash
PLUGIN_NAME="my-plugin"  # MUST be set before sourcing
source "${CLAUDE_PLUGIN_ROOT}/lib/plugin-config-read.sh"

plugin_is_enabled                              # returns 0/1
plugin_get_config "key" "default"              # single value
plugin_get_config_array "key"                  # one value per line
```

Resolution order (at each tier, checks `.yaml` then `.yml` then `.json`):

1. `${CLAUDE_PROJECT_DIR}/.claude/plugins.settings.{yaml,yml,json}` → `my-plugin.key`
2. `~/.claude/plugins.settings.{yaml,yml,json}` → `my-plugin.key`
3. `${CLAUDE_PLUGIN_ROOT}/my-plugin.settings.{yaml,yml,json}` → `my-plugin.key`

YAML files are read via `yq` (with grep fallback), JSON files via `jq`.

### tool-install.sh

Project-local binary installation pattern. Requires `plugin-config-read.sh`.

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/tool-install.sh"

tool_is_web_session                            # checks CLAUDE_CODE_REMOTE
tool_resolve_install_dir                       # sets INSTALL_DIR global
tool_ensure_path "$INSTALL_DIR"                # adds to PATH via CLAUDE_ENV_FILE
tool_is_available "mytool"                     # checks command -v
tool_resolve_github_version "owner/repo" "1.0" # latest release tag
tool_run_install do_install                    # bg/fg per config
```

### add-permission.sh

Idempotent permission injection into `settings.local.json`. Requires `safe-settings-write.sh`.

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/add-permission.sh"

add_permission_to_allow "mcp__my-server__*"           # project-level
add_permission_to_allow "Bash(tool:*)" "user"          # user-level
```

### hook-logging.sh

Full hook lifecycle logging. Depends on `log.sh` (auto-sourced). Messages are printed to stderr (user sees via Ctrl+O) and accumulated for plain text output on stdout (user sees via `systemMessage`, agent sees via `additionalContext`). On failure, a structured error block is also printed to stderr.

```bash
PLUGIN_NAME="my-plugin"  # MUST be set before sourcing
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

hook_log "Installing tool v1.2.3"              # stderr + accumulate for stdout
hook_log_always "Tool v1.2.3 ready"            # alias for hook_log
hook_log_step "download" "Downloading binary"  # start a named step
hook_fail "curl" "404 not found" "Check URL"   # structured error to stderr (returns 0)
hook_run my_main_function                      # wrap function, auto-fail on non-zero exit
hook_log_cleanup                               # remove log file on success
hook_respond                                   # MUST be last — outputs plain text to stdout
```

**IMPORTANT:** `hook_respond` MUST be called exactly once, as the last thing before exit. It outputs accumulated messages as plain text to stdout. Hooks MUST always exit 0.

On failure, `hook_fail` prints:

```
==== Plugin Setup Failed ====
  Plugin:    my-plugin
  Component: curl
  Step:      download
  Error:     404 not found
  Logs:      /tmp/claude-plugin-logs/my-plugin-20260311-153022-12345.log
  Fix:       Check URL
=============================
```

`hook_session_message` is an alias for `hook_log`. `hook_log_always` is also an alias for `hook_log`.

### safe-settings-write.sh

Simple jq-based settings writer.

```bash
SETTINGS_FILE="/path/to/settings.local.json"
source "${CLAUDE_PLUGIN_ROOT}/lib/safe-settings-write.sh"

safe_write_settings '.some.key = "value"'  # jq filter applied to file
```

## Adding a New Shared Library

1. Create the library in `shared/lib/`
2. Add double-source guard: `if [ "${_MY_LIB_LOADED:-}" = "true" ]; then return 0; fi`
3. Symlink into each plugin that needs it: `ln -s ../../../shared/lib/my-lib.sh plugins/*/lib/`
4. Document it in this file

## Conventions

- Libraries use `_UPPERCASE_LOADED` guards to prevent double-sourcing
- Functions are prefixed by domain (`plugin_`, `tool_`, `add_permission_`, `log_`, `hook_`)
- All libraries are idempotent and safe to source multiple times
- Symlinked content is resolved and copied on plugin install (not symlinked at runtime)
- Set `PLUGIN_NAME` before sourcing any library that needs it
- **Never use raw `echo` for logging** — use `log.sh`, `hook-output.sh`, or `hook-logging.sh`
- When `hook-logging.sh` is symlinked, `log.sh` must also be symlinked (it's a dependency)

## Choosing the Right Logging Library

- **Any script** → `log.sh` (basic stderr logging)
- **Simple hook with JSON response** → `hook-output.sh` (replaces `_json_msg`)
- **Complex hook with lifecycle** → `hook-logging.sh` (steps, errors, log files)

See [docs/shared-logging.md](../../docs/shared-logging.md) for detailed usage guide and anti-patterns.
