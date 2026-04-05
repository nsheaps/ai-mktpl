# Shared Logging Libraries

This document describes the shared logging libraries available in `shared/lib/` for use by plugins and project hooks.

## Overview

Three libraries form the logging stack, from simplest to most feature-rich:

| Library           | Purpose              | Output                                 | Use When                                                    |
| ----------------- | -------------------- | -------------------------------------- | ----------------------------------------------------------- |
| `log.sh`          | Basic stderr logging | stderr only                            | Any script needs consistent logging                         |
| `hook-output.sh`  | JSON hook responses  | stderr + JSON stdout                   | Simple hooks returning `{additionalContext, systemMessage}` |
| `hook-logging.sh` | Full hook lifecycle  | stderr + log file + accumulated stdout | Complex hooks with steps, error reporting, `hook_respond`   |

## log.sh

Lightweight general-purpose logging. Works in any context: hooks, session-start scripts, utility scripts, bin scripts.

### Setup

```bash
# Option A: In a plugin script (PLUGIN_NAME auto-detected as prefix)
PLUGIN_NAME="my-plugin"
source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"

# Option B: In a project hook or standalone script
LOG_PREFIX="my-script"
source "/path/to/log.sh"
```

### Functions

```bash
log_info "Installing tool v1.2.3"       # my-plugin: Installing tool v1.2.3
log_warn "Fallback to default"          # my-plugin: [warn] Fallback to default
log_error "File not found"              # my-plugin: [error] File not found
log_step "download" "Downloading..."    # my-plugin: [download] Downloading...
```

All output goes to stderr, so it never interferes with stdout (hook responses, return values, etc).

### Prefix Resolution

The prefix is resolved in this order:

1. `LOG_PREFIX` (if set explicitly)
2. `PLUGIN_NAME` (if set)
3. `"script"` (fallback)

## hook-output.sh

Provides the `{additionalContext, systemMessage}` JSON output pattern used by simple SessionStart hooks. Replaces the duplicated `_json_msg()` function found across many plugins.

### Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-output.sh"
```

### Functions

```bash
hook_msg "statusline: configured"      # Logs to stderr + outputs JSON to stdout
hook_msg_only "quiet message"          # JSON to stdout only (no stderr)
```

### When to Use

Use `hook-output.sh` for hooks that:

- Need to return a single status message to Claude Code
- Don't have a complex lifecycle (no steps, no error reporting)
- Output `{additionalContext, systemMessage}` JSON

For hooks with multiple steps, error handling, or log file management, use `hook-logging.sh` instead.

## hook-logging.sh

Full hook lifecycle management with log files, step tracking, error reporting, and accumulated output. Internally sources `log.sh` for stderr logging.

### Setup

```bash
PLUGIN_NAME="my-plugin"  # Required
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"
```

### Functions

```bash
hook_log "Installing tool v1.2.3"              # stderr + accumulate for stdout
hook_log_step "download" "Downloading binary"  # Start a named step
hook_fail "curl" "404 not found" "Check URL"   # Structured error to stderr
hook_run my_main_function                      # Wrap function, auto-fail on error
hook_log_cleanup                               # Remove log file on success
hook_respond                                   # MUST be last — outputs to stdout
```

### Lifecycle

1. Source the library (creates log file + message accumulator)
2. Use `hook_log` / `hook_log_step` for progress messages
3. Use `hook_fail` for structured error reporting
4. Call `hook_log_cleanup` on success paths
5. Call `hook_respond` exactly once, as the last statement before exit

### When to Use

Use `hook-logging.sh` for hooks that:

- Install tools or perform multi-step setup
- Need log file diagnostics on failure
- Use `hook_run` to wrap main functions
- Accumulate messages for a final `hook_respond` output

## Choosing the Right Library

```
Does your script need hook-specific output?
├── No → use log.sh
└── Yes → Does it need steps, error reporting, log files?
    ├── No → use hook-output.sh
    └── Yes → use hook-logging.sh
```

## Adding to a Plugin

1. Symlink the library into the plugin's `lib/` directory:

   ```bash
   mkdir -p plugins/my-plugin/lib
   ln -s ../../../shared/lib/log.sh plugins/my-plugin/lib/log.sh
   ```

2. Source it in your script:

   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/log.sh"
   ```

3. If using `hook-logging.sh`, also symlink `log.sh` (it's a dependency):
   ```bash
   ln -s ../../../shared/lib/log.sh plugins/my-plugin/lib/log.sh
   ln -s ../../../shared/lib/hook-logging.sh plugins/my-plugin/lib/hook-logging.sh
   ```

## Adding to a Project Hook

Project hooks (in `.claude/hooks/`) source the library using a relative path:

```bash
LOG_PREFIX="my-hook"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../shared/lib/log.sh"
```

## Anti-Patterns

### Don't use echo for logging

```bash
# Bad
echo "my-plugin: Installing tool..." >&2
echo "[my-hook] Starting setup"

# Good
log_info "Installing tool..."
```

### Don't duplicate \_json_msg

```bash
# Bad
_json_msg() {
  local msg="$1"
  if command -v jq &>/dev/null; then
    jq -n --arg msg "$msg" '{additionalContext: $msg, systemMessage: $msg}'
  else
    # ... manual escaping ...
  fi
}

# Good
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-output.sh"
hook_msg "my message"
```

### Don't mix echo logging with hook_log

```bash
# Bad — sources hook-logging.sh but uses echo for some messages
source "${CLAUDE_PLUGIN_ROOT}/lib/hook-logging.sh"
echo "${PLUGIN_NAME}: Downloading..." >&2   # bypasses log file + accumulator
hook_log "Done"

# Good — use hook_log consistently, or log_info (available via hook-logging.sh)
hook_log "Downloading..."
hook_log "Done"
```
