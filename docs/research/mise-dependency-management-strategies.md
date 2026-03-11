# Mise Dependency Management Strategies: Research Report

**Date**: 2026-03-11
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
9. [Appendix: Binary Analysis Evidence](#appendix-binary-analysis-evidence)
10. [Appendix: Test Results](#appendix-test-results)

---

## Executive Summary

This report analyzes three strategies for managing tool dependencies in Claude Code plugins, with particular attention to the **SessionStart hook race condition** — the fundamental timing problem where multiple hooks run concurrently and may depend on tools being installed by other hooks.

**Key findings from binary reverse-engineering:**

1. **All SessionStart hooks run in PARALLEL** (not sequentially). The binary uses `Promise.race` semantics via a concurrent async iterator merger with `q = Infinity`.
2. **`CLAUDE_ENV_FILE` is per-hook, per-session**: Each hook gets a uniquely-indexed file (`sessionstart-hook-{N}.sh`) that is composed with others in sorted order.
3. **The session env cache is only invalidated after async hooks complete**, meaning env changes from background hooks are not visible until the hook finishes AND the next Bash tool call occurs.
4. **Default hook timeout is 600 seconds (10 minutes)**, not the 60s configured in most plugins' hooks.json.

**Recommendation**: A **hybrid approach** — centralized mise for version declaration + a mise plugin for bootstrapping + plugins detecting mise availability at use-time with graceful fallback.

---

## Background: How Claude Code Executes Hooks

### Hook Execution Model (Verified via Binary Analysis)

The Claude Code binary (`/opt/claude-code/bin/claude`) is a Node.js Single Executable Application (SEA). Analysis of the embedded `cli.js` bundle (11.5MB) reveals the following hook execution architecture:

#### Parallel Execution

All hooks for the same event type run **concurrently**:

```javascript
// From cli.js (decompiled, variable names reconstructed)
W = hooks.map(async function*({hook, pluginRoot, skillRoot}, index) {
    // Each hook spawns its own shell process
    let timeout = hook.timeout ? hook.timeout * 1000 : DEFAULT_TIMEOUT; // 600000ms
    let process = spawn(command, [], {env, cwd, shell: true});
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

| Advantage | Detail |
|-----------|--------|
| **Single source of truth** | `mise.toml` declares all tool versions in one file |
| **Version pinning** | `mise.toml` supports exact, range, and `latest` version specs |
| **Reproducibility** | Every session gets the same tool versions |
| **Shim availability** | After `mise install`, shims exist for all tools immediately |
| **Minimal per-plugin code** | Plugins don't need download/install/version-check logic |
| **Ecosystem breadth** | mise supports 600+ tools via plugins, npm, cargo, go, etc. |
| **Self-updating** | `mise self-update` keeps mise itself current |

### Cons

| Disadvantage | Detail |
|--------------|--------|
| **Single point of failure** | If mise install fails (network, rate limit), ALL tools are missing |
| **Long install time** | `mise install -y` for 15+ tools takes 30-90 seconds |
| **Rate limit vulnerability** | GitHub API rate limits can block tool resolution (observed: jq install failed with 403) |
| **Timeout pressure** | 60-second hook timeout vs. potentially 90+ second install |
| **All-or-nothing** | Partial failures leave an inconsistent state |
| **Web-only guard** | Currently skips local sessions entirely (`tool_is_web_session` guard) |
| **Activation timing** | `eval "$(mise activate bash)"` in CLAUDE_ENV_FILE only affects Bash calls, not MCP servers |

### Edge Cases

**Rate limiting (observed):**
```
mise ERROR Failed to install aqua:jqlang/jq@latest: GitHub artifact attestations
verification failed: API rate limit exceeded for 35.188.35.214
```
In web sessions, all instances share egress IPs, causing collective rate limiting.

**Partial install:**
If mise installs 12/15 tools before timeout, the 3 remaining tools are missing. No retry mechanism exists. The shims for missing tools exist but return errors.

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

| Advantage | Detail |
|-----------|--------|
| **Independent failure domains** | gh install failure doesn't affect op install |
| **Plugin-specific logic** | Can handle non-GitHub release patterns (1Password uses custom CDN) |
| **No external dependencies** | Only needs `curl` and standard tools |
| **Targeted timeouts** | Each plugin gets its own 60-120s timeout |
| **Custom version resolution** | Can use vendor-specific APIs (1Password update endpoint) |
| **Background install option** | `tool_run_install` supports `backgroundInstall: true` |

### Cons

| Disadvantage | Detail |
|--------------|--------|
| **Duplicated logic** | Each plugin reimplements download, version check, PATH management |
| **No version coordination** | Two plugins could install different versions of the same tool |
| **Parallel race** | If plugin B needs tool X that plugin A installs, B may start before A finishes |
| **Larger plugin size** | Each plugin carries ~100 lines of install boilerplate |
| **Platform detection** | Each plugin must handle Linux/Darwin/x86_64/arm64 |
| **No centralized inventory** | Hard to audit what tools are installed and at what versions |
| **Multiple network calls** | Each plugin hits GitHub API independently (rate limit amplification) |

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

| Advantage | Detail |
|-----------|--------|
| **Best of both worlds** | Uses mise when available, self-installs when not |
| **Graceful degradation** | Works even without mise plugin enabled |
| **Consistent versions** | When using mise, respects `mise.toml` versions |
| **Reduced duplication** | Plugins defer install logic to mise |
| **Portability** | Works in repos without mise.toml |

### Cons

| Disadvantage | Detail |
|--------------|--------|
| **Complexity** | Most complex strategy: detection, polling, fallback paths |
| **Polling overhead** | Checking for mise availability adds latency |
| **Uncertain timing** | No guaranteed SLA for when mise becomes available |
| **Double PATH** | mise shims + direct install PATH entries can conflict |
| **Testing burden** | Must test both "with mise" and "without mise" paths |
| **Coordination required** | Needs a protocol (sentinel file, lock) for signaling |

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
 CLAUDE_ENV_FILE was empty per GH #15840)
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

| Approach | PATH modification | Tool resolution |
|----------|------------------|-----------------|
| `mise activate bash` | Adds actual install dirs: `~/.local/share/mise/installs/gh/2.88.0/.../bin` | Direct binary access, no shim overhead |
| Shims | Adds `~/.local/share/mise/shims` | Symlink → mise → looks up version → exec |
| Neither | No change | System tools only |

`mise activate` adds **real binary paths** to PATH, bypassing shims entirely. This is faster (no shim lookup) but requires mise to be active in the shell.

### The CLAUDE_ENV_FILE Reliability Problem (GH #15840)

The `CLAUDE_ENV_FILE` variable can sometimes be empty in Claude Code web sessions. This is a **known issue** documented in this repository. When empty:

- `tool_ensure_path` silently fails to persist PATH changes
- `mise activate bash` is not persisted
- Tools installed during SessionStart are not on PATH for subsequent Bash calls
- The `export PATH="$dir:$PATH"` immediate effect works only within the hook script itself

**Impact**: This affects ALL strategies that rely on CLAUDE_ENV_FILE for persistence.

---

## Comparative Analysis

### Decision Matrix

| Criterion | A: Centralized Mise | B: Plugin-Self-Install | C: Deferred Detection |
|-----------|:---:|:---:|:---:|
| **Setup complexity** | Low | Medium | High |
| **Failure isolation** | Poor (SPOF) | Good | Good |
| **Version consistency** | Excellent | Poor | Good (when mise available) |
| **Network efficiency** | Good (one install) | Poor (N downloads) | Good |
| **Race condition risk** | N/A (self-contained) | High (inter-plugin) | Medium |
| **Timeout risk** | High (long install) | Low (per-tool) | Medium |
| **Portability** | Requires mise.toml | Standalone | Both paths |
| **Code duplication** | Minimal | High | Medium |
| **Debugging** | Easy (one place) | Hard (N places) | Hardest |
| **Partial failure handling** | Poor | Good | Medium |

### Timing Analysis

| Phase | Centralized Mise | Plugin-Self-Install | Deferred Detection |
|-------|:---:|:---:|:---:|
| Mise bootstrap | 5-15s | N/A | 0s (if available) / 5-15s (fallback) |
| Tool install | 30-90s (all at once) | 5-15s each (parallel) | 5-15s each |
| PATH activation | Instant (via eval) | Instant (via export) | Varies |
| **Total** | **35-105s** | **5-15s** (parallel) | **5-30s** |

The centralized approach is **slowest** because `mise install -y` is sequential within the mise process. Plugin-self-install is fastest because downloads happen in parallel across plugins.

### Reliability Under Failure

| Failure Mode | A: Centralized | B: Self-Install | C: Deferred |
|-------------|:---:|:---:|:---:|
| Network timeout | All tools missing | Only affected tool missing | Graceful fallback |
| Rate limit | All tools missing | Only affected tool missing | Graceful fallback |
| Disk full | All tools missing | Partial success possible | Partial success possible |
| Hook timeout (60s) | Likely hit | Unlikely | Unlikely |
| CLAUDE_ENV_FILE empty | PATH broken for all | PATH broken per-plugin | PATH broken per-plugin |
| Container pre-installs | Redundant work | Detects & skips | Detects & skips |

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

## Appendix: Binary Analysis Evidence

### Source: `/opt/claude-code/bin/claude` (v2.1.42)

**Method**: `strings` extraction + pattern matching on the embedded cli.js bundle

#### Hook Timeout Default
```javascript
var G0 = 600000;  // 10 minutes default
```
Plugin hooks.json can override: `"timeout": 60` → 60000ms

#### Parallel Hook Execution
```javascript
// From the hook runner (rx function)
let T = Y.map(async function*({hook, pluginRoot, skillRoot}, R) {
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
path.join(sessionEnvDir, `${hookType.toLowerCase()}-hook-${index}.sh`)
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
if (isSessionStart)
    log("Invalidating session env cache after SessionStart hook completed");
    invalidateSessionEnvCache();  // sets cache = undefined
```

### Key String Evidence

| String | Location | Significance |
|--------|----------|--------------|
| `"Invalidating session environment cache"` | `$yL()` function | Cache invalidation trigger |
| `"Session environment loaded from CLAUDE_ENV_FILE"` | `AyL()` function | Env file read confirmation |
| `"Hooks: Detected async hook, backgrounding process"` | Hook runner | Async hook detection |
| `"Hooks: Detected async hook but forceSyncExecution is true"` | Hook runner | Sync override |
| `"Skipping ${P} hook execution - workspace trust not accepted"` | Hook runner | Trust gate |

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
**Result**: No hook env files were created, confirming the CLAUDE_ENV_FILE reliability issue (GH #15840) was active in this session.

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

### Test 6: Hook Deduplication

From binary analysis, hooks are deduplicated by command string before parallel execution. If two plugins register the exact same `bash install-mise.sh` command, it runs only once. However, this is an unlikely scenario since each plugin uses distinct commands.

---

## Related Files

| File | Role |
|------|------|
| `mise.toml` | Central tool version declarations |
| `plugins/mise/hooks/scripts/install-mise.sh` | Mise plugin SessionStart hook |
| `plugins/github/hooks/scripts/install-gh.sh` | GitHub CLI self-install hook |
| `plugins/1pass/hooks/scripts/install-op.sh` | 1Password CLI self-install hook |
| `shared/lib/tool-install.sh` | Shared installation library |
| `shared/lib/plugin-config-read.sh` | 3-tier config resolution |
| `.claude/skills/how-this-repo-works/references/plugin-env-vars-tradeoff.md` | ENV_FILE vs settings.local.json tradeoff |
| `.claude/rules/environment-setup-and-maintenance.md` | Setup conventions |
