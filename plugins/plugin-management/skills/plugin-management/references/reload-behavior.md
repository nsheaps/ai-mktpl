# Plugin Reload Behavior — Detailed Reference

Detailed breakdown of what hot-reloads and what requires a restart in Claude Code,
with source code references and upstream issue links.

## Core Architecture

Claude Code uses two distinct mechanisms for configuration management:

1. **Chokidar file watcher** — Only for `settings.json` files. Changes detected immediately
   via filesystem events, propagated through an internal event bus (`zZ` subscribers).

2. **Lodash `memoize` with manual cache clearing** — For everything else (plugins, skills,
   CLAUDE.md, rules, hooks). Cached on first access, cleared at lifecycle boundaries
   (`/clear`, `/compact`, plugin install/uninstall operations).

This means the vast majority of Claude Code's configuration is **not** file-watched. Changes
take effect only when the memoization cache is explicitly cleared.

Source: Binary analysis of Claude Code v2.1.39–2.1.45
([plugin-install-research-source.md](../../../docs/research/plugin-install-research-source.md))

## Component-by-Component Breakdown

### Immediate Hot-Reload (File-Watched)

#### settings.json

- **Mechanism**: Chokidar file watcher monitors all settings files
- **Propagation**: Changes trigger event bus subscribers (`zZ`)
- **Scope**: `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`
- **What changes**: Any key in settings takes effect immediately
- **Exception**: Hook configurations in settings.json may NOT hot-reload correctly
  ([#22679](https://github.com/anthropics/claude-code/issues/22679))

#### Plugin Install/Uninstall (v2.1.45+)

- **Mechanism**: Cache invalidation via `Qq()` function on install/enable/disable
- **Source**: Plugin loading via memoized `n$()` function (line ~223352 in binary)
- **Effect**: New plugin commands, agents, skills, and hooks become available immediately
- **Note**: This is a relatively recent improvement; older versions required restart

### Lifecycle-Boundary Reload (Memoized)

These components are cached and only refreshed on `/clear`, `/compact`, or plugin operations.

#### Skills (SKILL.md)

- **Mechanism**: Memoized loader, cache cleared on `/clear` or `/compact`
- **Official docs**: Described as "hot-reload" since v2.1.0, but source shows memoization
- **Practical effect**: Edit a SKILL.md → run `/clear` → skill reflects new content
- **Source**: Skills loaded via memoized function, cache cleared by `Mo()` at lifecycle points

#### CLAUDE.md and Rules Files

- **Mechanism**: Same memoization pattern as skills
- **Cache cleared**: On `/clear`, `/compact`
- **Known issue**: CLAUDE.md may not reload after compaction
  ([#22085](https://github.com/anthropics/claude-code/issues/22085))

#### Hook Configurations

- **Mechanism**: Cleared when plugin cache is invalidated
- **Practical effect**: Adding a new hook event to `hooks.json` requires plugin reload
- **Note**: The hook *script itself* runs fresh each invocation (it's a file on disk).
  Only the *configuration* (which events trigger which hooks) is cached.

### Restart Required

These components are loaded once at startup and not refreshed during a session.

#### MCP Server Configurations

- **Reason**: Server connections are established at startup and persist
- **Files**: `.mcp.json`, MCP entries in `settings.json`
- **Upstream request**: [#24057](https://github.com/anthropics/claude-code/issues/24057) —
  no timeline for hot-reload support

#### Plugin Code and Manifest

- **Reason**: Plugin code is cached at install time in `~/.claude/plugins/cache/`
- **Files**: `plugin.json`, hook scripts, command files, agent definitions
- **Effect**: Code changes to an installed plugin require reinstall + restart

#### `--plugin-dir` Code Changes

- **Reason**: Explicitly documented — dev plugins loaded once at session start
- **Workaround**: Restart Claude Code to pick up changes

#### Standalone Agent Files

- **Reason**: Not watched by any mechanism
- **Effect**: Changes to `.claude/agents/*.md` require restart

## Summary Matrix

| Component | Mechanism | Refresh Trigger | Upstream Issue |
|-----------|-----------|----------------|---------------|
| `settings.json` | Chokidar watcher | Immediate | — |
| Plugin install/uninstall | `Qq()` cache clear | Immediate | — |
| Plugin enable/disable | Settings change | Immediate | — |
| Skills (SKILL.md) | Memoized | `/clear` or `/compact` | — |
| CLAUDE.md / rules | Memoized | `/clear` or `/compact` | [#22085](https://github.com/anthropics/claude-code/issues/22085) |
| Hook configs | Plugin cache | Plugin reload | [#22679](https://github.com/anthropics/claude-code/issues/22679) |
| MCP servers | Startup only | **Restart** | [#24057](https://github.com/anthropics/claude-code/issues/24057) |
| Plugin code/manifest | Install-time cache | **Reinstall + restart** | — |
| `--plugin-dir` code | Session start | **Restart** | — |
| Agent files | Not watched | **Restart** | — |
