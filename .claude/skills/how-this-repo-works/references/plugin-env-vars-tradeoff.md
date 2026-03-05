# Plugin Environment Variables: `settings.local.json` vs `CLAUDE_ENV_FILE`

Research into the tradeoffs between two approaches for setting environment variables in plugins during session start.

## The Two Mechanisms

### Approach A: Writing to `settings.local.json` `.env` key

Used by: `datadog-otel-setup`

A SessionStart hook uses `jq` (via `safe-settings-write.sh`) to write env vars into `~/.claude/settings.local.json` under the `.env` key. Claude Code reads this file and applies those env vars to its own process and spawned subprocesses.

```json
{ "env": { "OTEL_EXPORTER_OTLP_ENDPOINT": "https://..." } }
```

### Approach B: Writing to `CLAUDE_ENV_FILE`

Used by: `mise`, `gh-tool`

A SessionStart hook appends `export` statements to the file at `$CLAUDE_ENV_FILE`. Claude Code sources this file before each Bash tool invocation.

```bash
echo 'export PATH="$INSTALL_DIR:$PATH"' >> "$CLAUDE_ENV_FILE"
echo 'eval "$(mise activate bash)"' >> "$CLAUDE_ENV_FILE"
```

## Dynamic Reloading Context

Understanding what Claude Code hot-reloads mid-session is critical to choosing the right mechanism.

| Config type                       | Hot-reloaded mid-session?                                     |
| --------------------------------- | ------------------------------------------------------------- |
| `settings.local.json` (incl. env) | **Yes** — hot-reloaded on file change (v1.0.90+)              |
| `CLAUDE.md` / `.claude/rules/`    | **No** — cached at session start (re-injected on `/compact`)  |
| Skills (`SKILL.md`)               | **No** — cached at session start                              |
| Plugins (`plugin.json`, hooks)    | **No** — tool list locked at startup for cache preservation   |
| `CLAUDE_ENV_FILE`                 | **N/A** — written at session start, sourced before Bash calls |

Settings files are the **only** hot-reloadable config in Claude Code. Everything else (rules, skills, plugins) is frozen at session start.

## Detailed Tradeoff

| Dimension              | `settings.local.json` `.env`                                   | `CLAUDE_ENV_FILE`                                    |
| ---------------------- | -------------------------------------------------------------- | ---------------------------------------------------- |
| **Scope**              | Claude process + all tool calls (Bash, MCP, etc.)              | Bash tool calls only                                 |
| **Hot-reload**         | **Yes** — changes picked up mid-session                        | **No** — written once at session start               |
| **Persistence**        | Permanent on disk, survives across sessions                    | Session-scoped temp file, auto-cleaned               |
| **Shell expressions**  | No — static string values only                                 | Yes — `eval`, conditional PATH, etc.                 |
| **Conflict risk**      | Higher — multiple plugins writing same file need atomic writes | Low — append-only (`>>`)                             |
| **Cleanup**            | Manual — values persist until explicitly removed               | Automatic with session                               |
| **Security (secrets)** | Secrets persist on disk permanently                            | Secrets scoped to session lifetime                   |
| **Reliability**        | Solid                                                          | `CLAUDE_ENV_FILE` can sometimes be empty (GH #15840) |
| **Appropriate for**    | Config Claude itself needs (telemetry, OTEL, feature flags)    | PATH mods, shell tool activation                     |

## When to Use Which

### Use `settings.local.json` `.env` when

- The env var must affect Claude's own process (e.g., `CLAUDE_CODE_ENABLE_TELEMETRY`, OTEL config)
- Non-Bash tools need it (MCP servers, etc.)
- You want mid-session configurability via hot-reload
- The value should persist across sessions

### Use `CLAUDE_ENV_FILE` when

- You're modifying `PATH` or activating shell tools (`eval "$(mise activate)"`)
- You need shell expressions, not just static values
- The value is session-scoped and shouldn't leak to future sessions
- Secrets that shouldn't persist on disk
- You only need the value available in Bash tool calls

## Key Concerns

### The Cleanup Problem with `settings.local.json`

There is no session-end cleanup mechanism. If a plugin writes `OTEL_EXPORTER_OTLP_HEADERS=<api-key>` into `settings.local.json`, that key sits on disk permanently. `CLAUDE_ENV_FILE` avoids this entirely — the temp file is cleaned up with the session. For secrets, this matters significantly.

### Ownership and Coordination

Multiple plugins writing to `settings.local.json` need coordination via `safe-settings-write.sh` to avoid clobbering each other's keys or leaving stale config. `CLAUDE_ENV_FILE` is append-only and doesn't have this problem — multiple hooks can safely `>>` without coordination.

### Scope Differences Matter

If a plugin sets an env var via `CLAUDE_ENV_FILE`, MCP servers and other non-Bash tools will **not** see it. This is why `datadog-otel-setup` uses `settings.local.json` — OTEL config needs to reach Claude's telemetry subsystem, not just Bash calls.

## Recommendation

Default to `CLAUDE_ENV_FILE` for most plugin env vars. Only use `settings.local.json` when you specifically need:

- **Broader scope** — non-Bash tools (MCP servers) need the value
- **Persistence** — the value should survive across sessions
- **Hot-reload** — mid-session changes must be picked up

The cleanup and conflict concerns make the settings file approach the higher-risk choice.

## Examples in This Repository

| Plugin               | Mechanism             | Why                                                     |
| -------------------- | --------------------- | ------------------------------------------------------- |
| `datadog-otel-setup` | `settings.local.json` | OTEL config must reach Claude's own telemetry process   |
| `mise`               | `CLAUDE_ENV_FILE`     | PATH manipulation and `mise activate` shell expressions |
| `github`             | `CLAUDE_ENV_FILE`     | PATH manipulation for project-local binary install      |

## Related

- `shared/lib/safe-settings-write.sh` — atomic jq-based settings writer
- `shared/lib/tool-install.sh` — `tool_ensure_path()` uses `CLAUDE_ENV_FILE`
- `.claude/rules/environment-setup-and-maintenance.md` — session setup conventions
- `.claude/rules/shared-libs.md` — shared library documentation
