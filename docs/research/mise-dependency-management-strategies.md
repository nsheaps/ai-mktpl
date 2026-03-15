# Mise Dependency Management Strategies: Research Report

**Date**: 2026-03-11
**Claude Code Version**: v2.1.42 (findings may need re-validation when Claude Code is updated)
**Scope**: Claude Code plugin dependency installation — centralized (mise plugin) vs. plugin-self-install vs. deferred mise detection
**Methodology**: Binary reverse-engineering, live environment testing, codebase analysis, online documentation review

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Background: How Claude Code Executes Hooks](#background-how-claude-code-executes-hooks)
3. [Strategy A: Centralized Mise Plugin](#strategy-a-centralized-mise-plugin)
4. [Strategy B: Plugin-Self-Install](#strategy-b-plugin-self-install)
5. [Strategy C: Deferred Mise Detection](#strategy-c-deferred-mise-detection)
6. [The Race Condition Problem](#the-race-condition-problem)
7. [Comparative Analysis](#comparative-analysis)
8. [Recommendations](#recommendations)
9. [Strategy D: Async Mise Bootstrap + Shim-Based Lazy Install](#strategy-d-async-mise-bootstrap--shim-based-lazy-install-proposed)
   - [Lazy Loaded Tool Pass-Throughs (Non-Mise Tools)](#lazy-loaded-tool-pass-throughs-non-mise-tools)
10. [Appendix: Binary Analysis Evidence](#appendix-binary-analysis-evidence)
11. [Appendix: Test Results](#appendix-test-results)

---

## Executive Summary

This report analyzes three strategies for managing tool dependencies in Claude Code plugins, with particular attention to the **SessionStart hook race condition** — the fundamental timing problem where multiple hooks run concurrently and may depend on tools being installed by other hooks.

**Key findings from binary reverse-engineering:**

1. **All SessionStart hooks run in PARALLEL** (not sequentially). The binary uses `Promise.race` semantics via a concurrent async iterator merger with `q = Infinity`.
2. **`CLAUDE_ENV_FILE` is per-hook, per-session**: Each hook gets a uniquely-indexed file (`sessionstart-hook-{N}.sh`) that is composed with others in sorted order.
3. **The session env cache is only invalidated after async hooks complete**, meaning env changes from background hooks are not visible until the hook finishes AND the next Bash tool call occurs.
4. **Default hook timeout is 600 seconds (10 minutes)**, not the 60s configured in most plugins' hooks.json.

**Recommendation**: **Strategy D: Async mise bootstrap + shim-based lazy install** — the mise plugin installs mise synchronously (fast), adds shims to PATH, then runs `mise install -y` asynchronously. Other plugins detect mise via `enabledPlugins` in `settings.json`, wait for mise if needed, or fall back to direct download. The agent starts immediately thanks to `async: true` hooks, and is notified when tools become available via `additionalContext` system message injection.

---

## Background: How Claude Code Executes Hooks

### Hook Execution Model (Verified via Binary Analysis)

The Claude Code binary (`/opt/claude-code/bin/claude`) is a Node.js Single Executable Application (SEA). Analysis of the embedded `cli.js` bundle (11.5MB) reveals the following hook execution architecture:

#### Parallel Execution

All hooks for the same event type run **concurrently**:

```javascript
// From cli.js (decompiled, variable names reconstructed)
W = hooks.map(async function* ({ hook, pluginRoot, skillRoot }, index) {
  // Each hook spawns its own shell process
  let timeout = hook.timeout ? hook.timeout * 1000 : DEFAULT_TIMEOUT; // 600000ms
  let process = spawn(command, [], { env, cwd, shell: true });
  // ...
});

// Merge results concurrently (q=Infinity means all parallel)
async function* mergeAsyncIterators(iterators, q = Infinity) {
  // Uses Promise.race on active generators
  // Yields values as they arrive from ANY generator
}
```

This means: **If plugin A installs mise and plugin B needs mise, there is NO guarantee plugin A completes first.** Both hooks launch simultaneously.

#### CLAUDE_ENV_FILE Lifecycle

Each SessionStart hook gets its own env file:

```
~/.claude/session-env/<session-uuid>/
├── setup-hook-0.sh          # Setup hooks sort first
├── setup-hook-1.sh
├── sessionstart-hook-0.sh   # Then SessionStart hooks by index
├── sessionstart-hook-1.sh
└── sessionstart-hook-2.sh
```

**File naming**: `{hooktype}-hook-{index}.sh` where index is the hook's position in the array.

**Read order** (verified from binary):

1. Files matching `^(setup|sessionstart)-hook-\d+\.sh$` only
2. `setup` files sort before `sessionstart` files
3. Within each type, sorted numerically by index
4. All contents concatenated and **sourced before every Bash tool call**

**Cache behavior**:

- Session env is cached after first read (`_a` variable in binary)
- Cache is invalidated ONLY when an async SessionStart hook completes
- This means: **env changes from sync hooks are immediately available, but only after the session starts and the first Bash tool call occurs**

#### Bash Tool Execution

Every `Bash()` tool call constructs:

```bash
source <shell-snapshot> && <session-env-script> && eval '<user-command>' && pwd -P >| <cwd-file>
```

The `<session-env-script>` is the concatenated contents of all session-env files, re-sourced on every call (unless cached).

---

## Strategy A: Centralized Mise Plugin

**Current implementation**: `plugins/mise/` with a SessionStart hook that installs mise, trusts the project, and runs `mise install -y`.

### How It Works

1. SessionStart hook (`install-mise.sh`) fires
2. Downloads mise binary to `$CLAUDE_PROJECT_DIR/bin/.local/` (web sessions only)
3. Runs `mise trust` on the project
4. Runs `mise install -y` to install all tools from `mise.toml`
5. Writes `eval "$(mise activate bash)"` to `CLAUDE_ENV_FILE`

### Pros

| Advantage                   | Detail                                                        |
| --------------------------- | ------------------------------------------------------------- |
| **Single source of truth**  | `mise.toml` declares all tool versions in one file            |
| **Version pinning**         | `mise.toml` supports exact, range, and `latest` version specs |
| **Reproducibility**         | Every session gets the same tool versions                     |
| **Shim availability**       | After `mise install`, shims exist for all tools immediately   |
| **Minimal per-plugin code** | Plugins don't need download/install/version-check logic       |
| **Ecosystem breadth**       | mise supports 600+ tools via plugins, npm, cargo, go, etc.    |
| **Self-updating**           | `mise self-update` keeps mise itself current                  |

### Cons

| Disadvantage                 | Detail                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------ |
| **Single point of failure**  | If mise install fails (network, rate limit), ALL tools are missing                         |
| **Long install time**        | `mise install -y` for 15+ tools takes 30-90 seconds                                        |
| **Rate limit vulnerability** | GitHub API rate limits can block tool resolution (observed: jq install failed with 403)    |
| **Timeout pressure**         | 60-second hook timeout vs. potentially 90+ second install                                  |
| **All-or-nothing**           | Partial failures leave an inconsistent state                                               |
| **Web-only guard**           | Currently skips local sessions entirely (`tool_is_web_session` guard)                      |
| **Activation timing**        | `eval "$(mise activate bash)"` in CLAUDE_ENV_FILE only affects Bash calls, not MCP servers |

### Edge Cases

**Rate limiting (observed):**

```
mise ERROR Failed to install aqua:jqlang/jq@latest: GitHub artifact attestations
verification failed: API rate limit exceeded for 35.188.35.214
```

In web sessions, all instances share egress IPs, causing collective rate limiting.

**Partial install:**
If mise installs 12/15 tools before timeout, the 3 remaining tools are missing. No retry mechanism exists. Missing tools have no shims, so `command -v` correctly reports them as unavailable.

---

## Strategy B: Plugin-Self-Install

**Current implementations**: `plugins/github/` (installs gh), `plugins/1pass/` (installs op, op-exec)

### How It Works

1. Each plugin's SessionStart hook independently:
   - Checks if tool exists on PATH (`command -v`)
   - Downloads binary from release page (GitHub, vendor CDN)
   - Installs to `$CLAUDE_PROJECT_DIR/bin/.local/` or `$HOME/.local/bin`
   - Adds to PATH via `CLAUDE_ENV_FILE`

### Pros

| Advantage                       | Detail                                                             |
| ------------------------------- | ------------------------------------------------------------------ |
| **Independent failure domains** | gh install failure doesn't affect op install                       |
| **Plugin-specific logic**       | Can handle non-GitHub release patterns (1Password uses custom CDN) |
| **No external dependencies**    | Only needs `curl` and standard tools                               |
| **Targeted timeouts**           | Each plugin gets its own 60-120s timeout                           |
| **Custom version resolution**   | Can use vendor-specific APIs (1Password update endpoint)           |
| **Background install option**   | `tool_run_install` supports `backgroundInstall: true`              |

### Cons

| Disadvantage                 | Detail                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------ |
| **Duplicated logic**         | Each plugin reimplements download, version check, PATH management              |
| **No version coordination**  | Two plugins could install different versions of the same tool                  |
| **Parallel race**            | If plugin B needs tool X that plugin A installs, B may start before A finishes |
| **Larger plugin size**       | Each plugin carries ~100 lines of install boilerplate                          |
| **Platform detection**       | Each plugin must handle Linux/Darwin/x86_64/arm64                              |
| **No centralized inventory** | Hard to audit what tools are installed and at what versions                    |
| **Multiple network calls**   | Each plugin hits GitHub API independently (rate limit amplification)           |

### Edge Cases

**Shared tool conflict:**
If both the `mise` plugin and `github` plugin try to install `gh`:

- mise installs `gh` via `mise install` → shim at `~/.local/share/mise/shims/gh`
- github plugin installs `gh` via direct download → binary at `bin/.local/gh`
- PATH order determines which `gh` is used
- Different versions may be installed

**Background install race:**

```bash
# Plugin A (backgroundInstall: true)
tool_run_install do_install  # Returns immediately, install runs in background

# Plugin B (needs tool from A)
if ! command -v tool_from_a; then  # Fails! A hasn't finished yet
    echo "tool_from_a not found"
fi
```

---

## Strategy C: Deferred Mise Detection

**Not yet implemented in this repo.** This strategy has each plugin detect whether mise is or will become available, and defer to mise for installation when possible.

### How It Would Work

1. Plugin SessionStart hook checks for mise:
   - Is mise on PATH right now? → Use `mise install <tool>`
   - Is mise.toml present in project? → mise plugin will likely install it soon
   - Neither? → Fall back to direct download
2. For deferred case: poll for mise availability or use a sentinel file
3. Once mise available: `mise install <specific-tool>` instead of full download

### Pros

| Advantage                | Detail                                           |
| ------------------------ | ------------------------------------------------ |
| **Best of both worlds**  | Uses mise when available, self-installs when not |
| **Graceful degradation** | Works even without mise plugin enabled           |
| **Consistent versions**  | When using mise, respects `mise.toml` versions   |
| **Reduced duplication**  | Plugins defer install logic to mise              |
| **Portability**          | Works in repos without mise.toml                 |

### Cons

| Disadvantage              | Detail                                                    |
| ------------------------- | --------------------------------------------------------- |
| **Complexity**            | Most complex strategy: detection, polling, fallback paths |
| **Polling overhead**      | Checking for mise availability adds latency               |
| **Uncertain timing**      | No guaranteed SLA for when mise becomes available         |
| **Double PATH**           | mise shims + direct install PATH entries can conflict     |
| **Testing burden**        | Must test both "with mise" and "without mise" paths       |
| **Coordination required** | Needs a protocol (sentinel file, lock) for signaling      |

### Design Challenges

**The Polling Problem:**

```bash
# How long do we wait for mise?
for i in $(seq 1 30); do
    if command -v mise &>/dev/null; then
        mise install gh
        break
    fi
    sleep 1  # 30 seconds of polling = wasted time if mise isn't coming
done
```

**The Sentinel Approach:**

```bash
MISE_SENTINEL="/tmp/claude-mise-ready-${CLAUDE_CODE_SESSION_ID}"
if [ -f "$MISE_SENTINEL" ]; then
    eval "$(mise activate bash)"
    mise install <tool>
else
    # Direct download fallback
fi
```

The mise plugin would touch this sentinel after completing. But since hooks run in parallel, the sentinel might not exist when other plugins check.

---

## The Race Condition Problem

### The Fundamental Issue

All SessionStart hooks run **concurrently** (parallel execution via `Promise.race`). This creates a race condition when:

1. **Plugin A** (mise) installs a tool manager
2. **Plugin B** (github) needs that tool manager or a tool it manages
3. Both start at the same time → Plugin B cannot use mise

### Observed Timeline (from binary analysis)

```
T=0ms    Claude Code starts session
T=10ms   All SessionStart hooks spawned in parallel
         ├── mise plugin: curl mise binary, install, trust, install tools...
         ├── github plugin: check for gh, download if missing...
         ├── 1pass plugin: check for op, download if missing...
         └── other plugins...
T=100ms  github plugin: command -v gh → found (pre-installed in container)
T=200ms  github plugin: exits (gh was already available)
T=500ms  1pass plugin: curl download completes, installs op
T=15s    mise plugin: mise binary downloaded
T=20s    mise plugin: mise trust completes
T=45s    mise plugin: mise install -y completes (all tools installed)
T=45s    mise plugin: writes eval to CLAUDE_ENV_FILE, exits
T=50s    Session env cache invalidated, mise activation available
```

### Verified Behaviors

**Test 1: CLAUDE_ENV_FILE is empty in Bash tool calls**

```bash
$ echo "CLAUDE_ENV_FILE=$CLAUDE_ENV_FILE"
CLAUDE_ENV_FILE=
```

Confirmed: `CLAUDE_ENV_FILE` is ONLY set for SessionStart/Setup hook processes, not for regular Bash tool calls. The env file contents are sourced inline instead.

**Test 2: Session env directory structure**

```
~/.claude/session-env/1dcf8390-b08f-4aed-8260-ece3d90748db/
(empty - no SessionStart hooks wrote to it in this session because
 CLAUDE_ENV_FILE was empty per [GH #15840](https://github.com/anthropics/claude-code/issues/15840))
```

**Test 3: Shims appear immediately after mise install**

```bash
$ ls ~/.local/share/mise/shims/
bun → mise, bunx → mise, claude → mise, gh → mise, just → mise, ...
```

Shims are symlinks to mise itself. They exist for ALL tools in mise.toml, even if the tool isn't yet installed. The shim delegates to mise at runtime to find the right version.

**Test 4: Missing tool through shim**

```bash
$ mise ls jq
jq  1.8.1 (missing)  /home/user/ai-mktpl/mise.toml  latest
```

When a tool is `(missing)`, the shim either fails or falls through to a system-installed version.

**Test 5: mise activate vs shims PATH behavior**

| Approach             | PATH modification                                                          | Tool resolution                          |
| -------------------- | -------------------------------------------------------------------------- | ---------------------------------------- |
| `mise activate bash` | Adds actual install dirs: `~/.local/share/mise/installs/gh/2.88.0/.../bin` | Direct binary access, no shim overhead   |
| Shims                | Adds `~/.local/share/mise/shims`                                           | Symlink → mise → looks up version → exec |
| Neither              | No change                                                                  | System tools only                        |

`mise activate` adds **real binary paths** to PATH, bypassing shims entirely. This is faster (no shim lookup) but requires mise to be active in the shell.

### The CLAUDE_ENV_FILE Reliability Problem ([GH #15840](https://github.com/anthropics/claude-code/issues/15840))

The `CLAUDE_ENV_FILE` variable can sometimes be empty in Claude Code web sessions. This is a **known issue** documented in this repository. When empty:

- `tool_ensure_path` silently fails to persist PATH changes
- `mise activate bash` is not persisted
- Tools installed during SessionStart are not on PATH for subsequent Bash calls
- The `export PATH="$dir:$PATH"` immediate effect works only within the hook script itself

**Impact**: This affects ALL strategies that rely on CLAUDE_ENV_FILE for persistence.

---

## Comparative Analysis

### Decision Matrix

| Criterion                    | A: Centralized Mise  | B: Plugin-Self-Install |   C: Deferred Detection    |
| ---------------------------- | :------------------: | :--------------------: | :------------------------: |
| **Setup complexity**         |         Low          |         Medium         |            High            |
| **Failure isolation**        |     Poor (SPOF)      |          Good          |            Good            |
| **Version consistency**      |      Excellent       |          Poor          | Good (when mise available) |
| **Network efficiency**       |  Good (one install)  |   Poor (N downloads)   |            Good            |
| **Race condition risk**      | N/A (self-contained) |  High (inter-plugin)   |           Medium           |
| **Timeout risk**             | High (long install)  |     Low (per-tool)     |           Medium           |
| **Portability**              |  Requires mise.toml  |       Standalone       |         Both paths         |
| **Code duplication**         |       Minimal        |          High          |           Medium           |
| **Debugging**                |   Easy (one place)   |    Hard (N places)     |          Hardest           |
| **Partial failure handling** |         Poor         |          Good          |           Medium           |

### Timing Analysis

| Phase           |   Centralized Mise   |  Plugin-Self-Install  |          Deferred Detection          |
| --------------- | :------------------: | :-------------------: | :----------------------------------: |
| Mise bootstrap  |        5-15s         |          N/A          | 0s (if available) / 5-15s (fallback) |
| Tool install    | 30-90s (all at once) | 5-15s each (parallel) |              5-15s each              |
| PATH activation |  Instant (via eval)  | Instant (via export)  |                Varies                |
| **Total**       |     **35-105s**      | **5-15s** (parallel)  |              **5-30s**               |

The centralized approach is **slowest** because `mise install -y` is sequential within the mise process. Plugin-self-install is fastest because downloads happen in parallel across plugins.

### Reliability Under Failure

| Failure Mode           |   A: Centralized    |      B: Self-Install       |       C: Deferred        |
| ---------------------- | :-----------------: | :------------------------: | :----------------------: |
| Network timeout        |  All tools missing  | Only affected tool missing |    Graceful fallback     |
| Rate limit             |  All tools missing  | Only affected tool missing |    Graceful fallback     |
| Disk full              |  All tools missing  |  Partial success possible  | Partial success possible |
| Hook timeout (60s)     |     Likely hit      |          Unlikely          |         Unlikely         |
| CLAUDE_ENV_FILE empty  | PATH broken for all |   PATH broken per-plugin   |  PATH broken per-plugin  |
| Container pre-installs |   Redundant work    |      Detects & skips       |     Detects & skips      |

---

## Recommendations

### Short-term: Keep Current Hybrid (Strategies A + B)

The current architecture is already a reasonable hybrid:

1. **mise plugin** handles mise itself + bulk tool installation
2. **Individual plugins** (github, 1pass) handle their own tools with `tool_is_available` checks
3. Plugins check `command -v` first, only download if tool is missing
4. The `tool_is_web_session` guard prevents unnecessary work on local machines

**Improvements to current approach:**

1. **Increase mise plugin timeout to 120s** — the current 60s is insufficient for `mise install -y` with 15+ tools
2. **Add GITHUB_TOKEN to mise install** — the install-mise.sh already does this but ensure it's propagated to avoid rate limits
3. **Add retry logic to tool_resolve_github_version** — one API failure shouldn't block version resolution

### Medium-term: Implement Strategy C Selectively

For plugins that install tools already in `mise.toml`:

```bash
# Proposed pattern for plugin hooks
install_tool() {
  local tool="$1"

  # 1. Already available? Skip.
  if command -v "$tool" &>/dev/null; then
    return 0
  fi

  # 2. Mise available? Use it.
  if command -v mise &>/dev/null; then
    mise install "$tool" -y 2>/dev/null && return 0
  fi

  # 3. Mise shim exists? Tool may install soon.
  if [ -x "$HOME/.local/share/mise/shims/$tool" ]; then
    # Try the shim — mise will install on demand
    "$HOME/.local/share/mise/shims/$tool" --version &>/dev/null && return 0
  fi

  # 4. Fallback: direct download
  download_tool_directly "$tool"
}
```

This avoids the race condition by not depending on mise being ready, while still benefiting from mise when it is available.

### Long-term: Container-Layer Pre-installation

Per the project's own documentation:

> "The hooks are a last-ditch effort to ensure a consistent environment. Always try to pre-emptively install software in an earlier layer, especially one that can be re-used, such as a container layer."

The ideal solution is:

1. **Container image** includes mise + all tools from mise.toml
2. **SessionStart hooks** verify tools exist and update if needed (fast path)
3. **Fallback** to full install only in environments without pre-installed tools

This eliminates the race condition entirely — tools are available before any hook runs.

### Architectural Principles

1. **Never depend on hook ordering** — hooks run in parallel, any hook might run first
2. **Always check before install** — `command -v` is fast and avoids redundant work
3. **Fail gracefully** — a missing tool should degrade the plugin, not crash the session
4. **Prefer shims over PATH activation** — shims are available immediately after `mise install`, activation requires shell eval
5. **Keep CLAUDE_ENV_FILE writes defensive** — always check `[ -n "${CLAUDE_ENV_FILE:-}" ]` before writing
6. **Use blocking installs** — `backgroundInstall: false` prevents race conditions at the cost of startup time

---

## Strategy D: Async Mise Bootstrap + Shim-Based Lazy Install (Proposed)

This strategy emerged from combining three discoveries:

1. **`not_found_auto_install = true`** — mise auto-installs tools on first shim invocation
2. **`async: true` hooks** — SessionStart hooks can run in the background without blocking the session
3. **`additionalContext` injection** — async hooks notify the model when they complete

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ SessionStart (SYNC phase — blocks session start, ~10-20s)       │
│                                                                 │
│  mise plugin:                                                   │
│    1. Install mise binary (5-15s)                               │
│    2. mise trust (1s)                                           │
│    3. mise reshim (1s) — creates shims for ALL tools            │
│    4. Write shim PATH + mise activate to CLAUDE_ENV_FILE        │
│    5. Output: {"async": true} — go async for bulk install       │
│                                                                 │
│  other plugins (parallel):                                      │
│    - Read settings.json → is mise@nsheaps-claude-plugins enabled?│
│    - If yes: skip install, mise shims handle it                 │
│    - If no: self-install via direct download (current behavior) │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Agent starts working immediately                                │
│                                                                 │
│  Background (ASYNC phase):                                      │
│    mise plugin: mise install -y (30-90s)                        │
│    gh-review plugin: wait for gh → install extension            │
│                                                                 │
│  When agent needs a tool:                                       │
│    1. Shim intercepts the call                                  │
│    2. mise checks if tool is installed                          │
│    3. If installed → exec real binary                           │
│    4. If not → auto-install (not_found_auto_install=true)       │
│       then exec real binary                                     │
│                                                                 │
│  When async hooks complete:                                     │
│    → additionalContext injected: "Tools available: gh, just..." │
│    → Session env cache invalidated (PATH changes take effect)   │
└─────────────────────────────────────────────────────────────────┘
```

### Inter-Plugin Awareness

Plugins can detect each other via `settings.json`:

```bash
# Check if mise plugin is enabled
_mise_plugin_enabled() {
  local settings_file="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.json"
  if [ -f "$settings_file" ] && command -v jq &>/dev/null; then
    jq -e '.enabledPlugins["mise@nsheaps-claude-plugins"] == true' "$settings_file" &>/dev/null
    return $?
  fi
  # Fallback: check if mise is on PATH or shims exist
  command -v mise &>/dev/null || [ -d "$HOME/.local/share/mise/shims" ]
}
```

This is a **read-only, zero-coordination** approach — plugins check the settings file, no sentinel or lock needed.

### The `not_found_auto_install` Discovery

mise has a built-in setting (default: `true`) that **auto-installs tools when accessed through shims**:

```bash
$ mise settings get not_found_auto_install
true
```

This means mise shims are ALREADY the "lazy install on first call" mechanism. No custom passthrough scripts needed.

**How it works:**

1. `mise reshim` creates shims for all tools in `mise.toml`
2. Each shim is a symlink to the mise binary itself
3. When invoked, mise checks if the requested tool version is installed
4. If installed → exec the real binary (fast path)
5. If NOT installed → download, install, then exec (transparent to caller)

**Timing implications:**

- Shim creation: instant (just symlinks)
- First use of uninstalled tool: 5-30s download delay (one-time)
- Subsequent uses: ~50ms shim overhead

### Async Hook Response Format

When the mise plugin's async hook completes, it outputs:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "mise: All tools installed successfully. Available: gh 2.88.0, just 1.46.0, node 24.14.0, python 3.14.2, bun 1.3.10"
  },
  "systemMessage": "Development tools are now available via mise."
}
```

This is injected as a **system attachment** into the model's next turn (verified from binary):

```javascript
case "async_hook_response": {
    let response = attachment.response;
    let messages = [];
    if (response.systemMessage)
        messages.push(systemMessage(response.systemMessage));
    if (response.hookSpecificOutput?.additionalContext)
        messages.push(systemMessage(response.hookSpecificOutput.additionalContext));
    return messages;
}
```

### The `asyncRewake` Option

For critical tools, hooks can use `asyncRewake: true`:

```json
{
  "type": "command",
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/install-mise.sh",
  "asyncRewake": true,
  "timeout": 120
}
```

- Implies `async: true` (runs in background)
- On **exit code 2**: injects a **blocking task-notification** to alert the model that something failed
- On exit code 0: normal async completion with `additionalContext`
- Exit code 1: error logged but no model notification

### Dependency Chains

For plugins that depend on other plugins' tools (e.g., gh-review depends on gh):

```bash
# gh-review plugin SessionStart hook (async: true)
#!/usr/bin/env bash
set -euo pipefail

# Output async signal immediately — don't block session
echo '{"async": true}'

# Wait for gh to become available (mise shim or direct install)
MAX_WAIT=90
WAITED=0
while ! command -v gh &>/dev/null; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"gh-review: gh not available after 90s, extension not installed"}}' >&2
    exit 0
  fi
  sleep 2
  WAITED=$((WAITED + 2))
done

# gh is available — install extension
gh extension install owner/review-extension 2>/dev/null || true
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"gh-review extension installed successfully"}}'
```

Since this hook declares `async: true` in hooks.json, it goes background immediately after the first JSON output. The agent starts working. When gh becomes available (via mise shim auto-install or github plugin), the extension installs and the model is notified.

### Sync vs Async Decision Framework

| Hook Type    |          Sync (default)           |               `async: true`               |           `asyncRewake: true`            |
| ------------ | :-------------------------------: | :---------------------------------------: | :--------------------------------------: |
| **Behavior** |       Blocks session start        | Background, no notification on completion | Background, notifies on failure (exit 2) |
| **Use case** | Tools that MUST exist pre-session |            Nice-to-have tools             |   Critical tools where failure matters   |
| **Examples** |  mise binary install, PATH setup  |      `mise install -y`, npm install       |            Auth token refresh            |

**Recommended split for mise architecture:**

```
SYNC (blocks session start, ~15s total):
  ✓ mise binary install
  ✓ mise trust + reshim
  ✓ PATH activation (shims dir + mise activate)

ASYNC (background, agent starts immediately):
  ✓ mise install -y (bulk tool install)
  ✓ gh extension install
  ✓ npm install / yarn install
  ✓ Any long-running setup
```

### Comparison: Passthrough Scripts vs Mise Shims vs PreToolUse Hooks

| Approach                       |         Transparency          |   First-use latency    |       Maintenance        |           Reliability            |
| ------------------------------ | :---------------------------: | :--------------------: | :----------------------: | :------------------------------: |
| **Custom passthrough scripts** | High (looks like real binary) |  Blocks until install  | Each tool needs a script |     Fragile (PATH conflicts)     |
| **Mise shims**                 |    High (symlinks to mise)    |  Auto-installs on use  | Zero (reshim handles it) |      Built-in, well-tested       |
| **PreToolUse hooks**           |   Low (intercepts all Bash)   | Hook overhead per call |  Regex command parsing   | Fragile (parsing arbitrary bash) |

**Mise shims win decisively** — they provide the exact "lazy install on first call" behavior with zero custom code. The `not_found_auto_install` setting makes this work out of the box.

### Open Questions

1. **Should plugins add their tool to `mise.toml` programmatically?** If a plugin needs `gh` and it's not in `mise.toml`, should the plugin run `mise use gh@latest`? This modifies the project file, which may not be desirable.

2. **What if `not_found_auto_install` is disabled?** Some users may disable this setting. Plugins should handle this gracefully — check `mise settings get not_found_auto_install` before relying on shim auto-install.

3. **Rate limiting with auto-install**: If 5 tools auto-install simultaneously on first use, they all hit GitHub API in parallel. This could trigger rate limits. The mise plugin's bulk `mise install -y` (with `GITHUB_TOKEN`) is more rate-limit-friendly.

4. **Shim overhead in tight loops**: Each shim invocation adds ~50ms overhead as mise resolves the version. For tools called thousands of times (e.g., in CI), `mise activate` (adding real binary paths) is preferred over shims.

### Lazy Loaded Tool Pass-Throughs (Non-Mise Tools)

Mise shims handle tools in the mise registry, but some tools can't be managed by mise — custom binaries, tools installed via `npm`/`pip`, GitHub CLI extensions, or proprietary tools with non-standard installation. For these, a **lazy pass-through** pattern provides the same "install on first use" behavior without mise.

#### Pattern: Self-Replacing Pass-Through Script

```bash
#!/usr/bin/env bash
# Lazy pass-through for <tool-name>
# Installs the real tool on first invocation, then execs it.
set -euo pipefail

TOOL_NAME="<tool-name>"
PASSTHROUGH_DIR="${HOME}/.local/share/claude-plugins/bin"
REAL_INSTALL_DIR="${HOME}/.local/share/claude-plugins/tools"

# Remove this pass-through script so the real binary takes precedence
_self_remove() {
  rm -f "${PASSTHROUGH_DIR}/${TOOL_NAME}"
}

# Install the real tool
_install() {
  mkdir -p "${REAL_INSTALL_DIR}"
  # Plugin-specific install logic here:
  # e.g., curl, gh extension install, npm install -g, pip install, etc.
  echo "Installing ${TOOL_NAME}..." >&2
  # ... install commands ...
}

# Main: install, self-remove, exec with original args
_install
_self_remove
exec "${REAL_INSTALL_DIR}/${TOOL_NAME}" "$@"
```

#### How It Works

1. **At session start** (sync phase): Plugin creates lightweight pass-through scripts in a `bin/` directory on PATH. This is instant — just writing small shell scripts.
2. **Agent starts immediately** — no tool installation has happened yet.
3. **On first tool invocation**: The pass-through script installs the real tool, removes itself from PATH priority, then `exec`s the real binary with the original arguments. The agent sees no difference from calling a pre-installed tool (aside from the one-time latency).
4. **Subsequent invocations**: The real binary is called directly — the pass-through is gone.

#### When to Use Pass-Throughs vs Mise Shims

| Scenario                                              | Use Mise Shims | Use Pass-Through |
| ----------------------------------------------------- | :------------: | :--------------: |
| Tool has a mise plugin (gh, node, python, jq, etc.)   |    **Yes**     |        No        |
| GitHub CLI extension (gh-copilot, gh-dash, etc.)      |       No       |     **Yes**      |
| npm global tool (prettier, eslint, etc.)              |  Prefer mise   |   **Fallback**   |
| pip tool (pre-commit, black, etc.)                    |  Prefer mise   |   **Fallback**   |
| Custom binary from private registry                   |       No       |     **Yes**      |
| Tool with complex install (multi-step, auth required) |       No       |     **Yes**      |

#### Integration with Strategy D

Pass-throughs complement the async mise bootstrap:

```
SYNC phase (~15s):
  ✓ mise binary install + reshim (handles mise-managed tools)
  ✓ Create pass-through scripts for non-mise tools (instant)
  ✓ Ensure both shim dir and pass-through dir are on PATH

ASYNC phase (background):
  ✓ mise install -y (bulk install mise tools)
  ✓ Optionally pre-install pass-through tools in background
    (so first invocation is fast even if agent calls them early)
```

#### Shared Library Support

The `tool-install.sh` shared library could be extended with a pass-through helper:

```bash
# In shared/lib/tool-install.sh

# Create a lazy pass-through script for a tool
# Usage: tool_create_passthrough "mytool" "install_function_name"
tool_create_passthrough() {
  local tool_name="$1"
  local install_fn="$2"
  local passthrough_dir="${HOME}/.local/share/claude-plugins/bin"

  # Skip if tool already available
  if command -v "$tool_name" &>/dev/null; then
    return 0
  fi

  mkdir -p "$passthrough_dir"
  cat > "${passthrough_dir}/${tool_name}" <<PASSTHROUGH
#!/usr/bin/env bash
set -euo pipefail
# Auto-generated lazy pass-through for ${tool_name}
# Source the plugin's install logic and run it
source "\${CLAUDE_PLUGIN_ROOT}/hooks/scripts/install-${tool_name}.sh"
${install_fn}
rm -f "${passthrough_dir}/${tool_name}"
exec "\$(command -v ${tool_name})" "\$@"
PASSTHROUGH
  chmod +x "${passthrough_dir}/${tool_name}"
  tool_ensure_path "$passthrough_dir"
}
```

#### Caveats

1. **PATH ordering matters** — the pass-through directory must be on PATH _after_ directories where real binaries get installed, so that once the real tool is installed, it takes precedence.
2. **Concurrent invocations** — if two parallel calls hit the pass-through simultaneously, both may try to install. Use a lockfile or atomic rename to prevent double-install.
3. **Error handling** — if installation fails, the pass-through should leave itself in place (don't self-remove) and return a clear error message rather than silently failing.
4. **Cleanup** — pass-through scripts are ephemeral per-session. They should be cleaned up on session end or overwritten on next session start.

---

## Appendix: Binary Analysis Evidence

### Source: `/opt/claude-code/bin/claude` (v2.1.42)

**Method**: `strings` extraction + pattern matching on the embedded cli.js bundle

#### Hook Timeout Default

```javascript
var G0 = 600000; // 10 minutes default
```

Plugin hooks.json can override: `"timeout": 60` → 60000ms

#### Parallel Hook Execution

```javascript
// From the hook runner (rx function)
let T = Y.map(async function* ({ hook, pluginRoot, skillRoot }, R) {
  // Each hook gets its own async generator
  let g = hook.timeout ? hook.timeout * 1000 : G0;
  // Spawn shell process...
});

// Merged via concurrent iterator with q=Infinity
async function* mergeAsyncIterators(iterators, q = Infinity) {
  // Promise.race semantics
}
```

#### CLAUDE_ENV_FILE Assignment (Only for SessionStart/Setup)

```javascript
if ((hookEvent === "SessionStart" || hookEvent === "Setup") && hookIndex !== void 0)
  env.CLAUDE_ENV_FILE = createHookEnvFile(hookEvent, hookIndex);
```

#### Session Env File Pattern

```javascript
// createHookEnvFile returns:
path.join(sessionEnvDir, `${hookType.toLowerCase()}-hook-${index}.sh`);
// e.g., sessionstart-hook-0.sh
```

#### Session Env Loading (before every Bash call)

```javascript
async function loadSessionEnv() {
  // Cache check
  if (cache !== undefined) return cache;

  let scripts = [];
  // 1. Read CLAUDE_ENV_FILE if set
  // 2. Read all (setup|sessionstart)-hook-*.sh files from session-env dir
  // 3. Sort: setup before sessionstart, then by numeric index
  // 4. Concatenate all contents
  cache = scripts.join("\n");
  return cache;
}
```

#### Cache Invalidation

```javascript
if (isSessionStart) log("Invalidating session env cache after SessionStart hook completed");
invalidateSessionEnvCache(); // sets cache = undefined
```

#### Hook Config Schema (async/asyncRewake)

```javascript
// Command hook config fields (from Zod schema in binary)
{
  type: "command",
  command: "string",           // Shell command to execute
  timeout: "number (optional)", // Timeout in seconds
  statusMessage: "string (optional)", // Spinner message
  once: "boolean (optional)",   // Run once then remove
  async: "boolean (optional)",  // Run in background without blocking
  asyncRewake: "boolean (optional)" // Background + notify model on exit code 2
}
```

#### Hook Response Schema (hookSpecificOutput)

```javascript
// Sync hook response (xPM schema in binary)
{
  continue: "boolean (optional)",        // Whether to continue (default: true)
  suppressOutput: "boolean (optional)",  // Hide stdout from transcript
  stopReason: "string (optional)",       // Message when continue=false
  decision: "'approve' | 'block'",       // Legacy permission decision
  reason: "string (optional)",           // Explanation for decision
  systemMessage: "string (optional)",    // Warning/info shown to model
  hookSpecificOutput: {
    // For SessionStart:
    hookEventName: "SessionStart",
    additionalContext: "string (optional)"  // Injected as system message

    // For PreToolUse:
    hookEventName: "PreToolUse",
    permissionDecision: "'allow' | 'deny' | 'ask'",
    updatedInput: "object (optional)",     // Modify tool input!
    additionalContext: "string (optional)"
  }
}

// Async hook response
{ async: true, asyncTimeout: "number (optional)" }
```

#### Async Hook Response Delivery to Model

```javascript
// When async hook completes, response becomes a system attachment:
case "async_hook_response": {
    if (response.systemMessage)
        messages.push(systemMessage(response.systemMessage, isMeta: true));
    if (response.hookSpecificOutput?.additionalContext)
        messages.push(systemMessage(additionalContext, isMeta: true));
    return messages;
}
```

### Key String Evidence

| String                                                          | Location         | Significance               |
| --------------------------------------------------------------- | ---------------- | -------------------------- |
| `"Invalidating session environment cache"`                      | `$yL()` function | Cache invalidation trigger |
| `"Session environment loaded from CLAUDE_ENV_FILE"`             | `AyL()` function | Env file read confirmation |
| `"Hooks: Detected async hook, backgrounding process"`           | Hook runner      | Async hook detection       |
| `"Hooks: Detected async hook but forceSyncExecution is true"`   | Hook runner      | Sync override              |
| `"Skipping ${P} hook execution - workspace trust not accepted"` | Hook runner      | Trust gate                 |

---

## Appendix: Test Results

### Test Environment

- **Platform**: Claude Code Web (remote session)
- **Container**: Firecracker VM, Linux 6.18.5
- **Node.js**: v22.22.0
- **Claude Code**: v2.1.42
- **mise**: 2026.3.7 (installed during testing)

### Test 1: CLAUDE_ENV_FILE Availability

```bash
$ echo "CLAUDE_ENV_FILE=$CLAUDE_ENV_FILE"
CLAUDE_ENV_FILE=
```

**Result**: CLAUDE_ENV_FILE is NOT set in regular Bash tool calls. It is only set within SessionStart/Setup hook processes. The env file contents are sourced inline via the session-env mechanism instead.

### Test 2: Session Env Directory

```bash
$ ls -laR ~/.claude/session-env/
~/.claude/session-env/1dcf8390-.../
  (empty directory)
```

**Result**: No hook env files were created, confirming the CLAUDE_ENV_FILE reliability issue ([GH #15840](https://github.com/anthropics/claude-code/issues/15840)) was active in this session.

### Test 3: mise Shim Behavior

```bash
$ mise install -y
# Installed: bun, gh, just, node, python, eslint, prettier, yarn, etc.
# Failed: jq (GitHub rate limit 403)

$ ls ~/.local/share/mise/shims/
bun → mise, gh → mise, just → mise, node → mise, ...
# Shims created for ALL configured tools

$ mise ls jq
jq  1.8.1 (missing)  /home/user/ai-mktpl/mise.toml  latest
# jq shim was NOT created (no shim for missing tools after reshim)
```

**Result**: Shims are created only for successfully installed tools. Missing tools get no shim, meaning `command -v` correctly reports them as unavailable.

### Test 4: mise activate vs Shims PATH

```bash
# With shims:
$ export PATH="~/.local/share/mise/shims:$PATH"
$ which gh → ~/.local/share/mise/shims/gh  # Symlink to mise binary

# With activate:
$ eval "$(mise activate bash)"
$ echo $PATH | tr ':' '\n' | grep mise
~/.local/share/mise/installs/gh/2.88.0/gh_2.88.0_linux_amd64/bin
~/.local/share/mise/installs/node/24.14.0/bin
~/.local/share/mise/installs/python/3.14.2/bin
~/.local/share/mise/installs/bun/1.3.10/bin
~/.local/share/mise/installs/just/1.46.0
```

**Result**: `mise activate` adds actual binary directories to PATH (faster, no shim overhead). Shims add a single directory with symlinks that delegate to mise at runtime (slower but immediate availability).

### Test 5: Rate Limit Impact

```
mise ERROR Failed to install aqua:jqlang/jq@latest:
  GitHub artifact attestations verification failed for aqua:jqlang/jq@1.8.1:
  API error: GitHub API returned 403 Forbidden:
  "API rate limit exceeded for 35.188.35.214"
```

**Result**: Web sessions share egress IPs, causing collective GitHub API rate limiting. This affects both mise-based installation and direct `tool_resolve_github_version` calls. Providing `GITHUB_TOKEN` helps but doesn't eliminate the issue when multiple concurrent sessions are active.

### Test 6: mise `not_found_auto_install` Setting

```bash
$ mise settings get not_found_auto_install
true
```

**Result**: mise's `not_found_auto_install` is enabled by default. When a tool is accessed through a shim but not yet installed, mise will automatically download and install it before executing. This is the built-in "lazy install on first call" mechanism — no custom passthrough scripts needed.

### Test 7: Inter-Plugin Awareness via settings.json

```bash
$ jq '.enabledPlugins' .claude/settings.json
{
  "mise@nsheaps-claude-plugins": true,
  "github@nsheaps-claude-plugins": true,
  ...
}
```

**Result**: Hook scripts can read `.claude/settings.json` to discover which plugins are enabled. This provides a zero-coordination mechanism for inter-plugin awareness — no sentinel files or locks needed.

### Test 8: Hook Deduplication

From binary analysis, hooks are deduplicated by command string before parallel execution. If two plugins register the exact same `bash install-mise.sh` command, it runs only once. However, this is an unlikely scenario since each plugin uses distinct commands.

---

## Related Files

| File                                                                        | Role                                     |
| --------------------------------------------------------------------------- | ---------------------------------------- |
| `mise.toml`                                                                 | Central tool version declarations        |
| `plugins/mise/hooks/scripts/install-mise.sh`                                | Mise plugin SessionStart hook            |
| `plugins/github/hooks/scripts/install-gh.sh`                                | GitHub CLI self-install hook             |
| `plugins/1pass/hooks/scripts/install-op.sh`                                 | 1Password CLI self-install hook          |
| `shared/lib/tool-install.sh`                                                | Shared installation library              |
| `shared/lib/plugin-config-read.sh`                                          | 3-tier config resolution                 |
| `.claude/skills/how-this-repo-works/references/plugin-env-vars-tradeoff.md` | ENV_FILE vs settings.local.json tradeoff |
| `.claude/rules/environment-setup-and-maintenance.md`                        | Setup conventions                        |
