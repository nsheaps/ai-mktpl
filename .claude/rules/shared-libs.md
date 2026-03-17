# Shared Libraries for Plugins

## Overview

Reusable bash libraries live in `shared/lib/` and are symlinked into each plugin's `lib/` directory. Plugins reference them via `${CLAUDE_PLUGIN_ROOT}/lib/<lib>.sh`.

## Available Libraries

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

Hook logging with structured error reporting. All output prints directly to stdout (success) or stderr (errors). On failure, prints a structured error message to stderr with plugin name, failed component, log file path, and remediation suggestions. A log file is also maintained for failure diagnostics.

```bash
PLUGIN_NAME="my-plugin"  # MUST be set before sourcing
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"

hook_log "Installing tool v1.2.3"              # print to stdout + stderr
hook_log_always "Tool v1.2.3 ready"            # alias for hook_log
hook_log_step "download" "Downloading binary"  # start a named step
hook_fail "curl" "404 not found" "Check URL"   # structured error to stderr (returns 0)
hook_run my_main_function                      # wrap function, auto-fail on non-zero exit
hook_log_cleanup                               # remove log file on success
```

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

`hook_respond` and `hook_session_message` are kept as no-ops/aliases for backwards compatibility but are no longer needed in new code.

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
- Functions are prefixed by domain (`plugin_`, `tool_`, `add_permission_`)
- All libraries are idempotent and safe to source multiple times
- Symlinked content is resolved and copied on plugin install (not symlinked at runtime)
- Set `PLUGIN_NAME` before sourcing any library that needs it
