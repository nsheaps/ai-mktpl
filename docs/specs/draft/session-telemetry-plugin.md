# Session Telemetry Plugin

**Status:** Draft
**Priority:** Medium (observability / developer experience)

## 1. Problem & Requirements

### Problem

Claude Code sessions are opaque. When a session ends (or mid-session), there is no structured way to answer questions like:

- What directories did the agent work in?
- How many tool calls were made, and which tools were used most?
- What tasks were created, and what is their current status?
- How long did the session spend on each phase of work?

This information exists ephemerally in the conversation transcript, but extracting it requires parsing raw JSONL -- which is fragile, slow, and not designed for querying. There is no first-class way for the agent itself (or external tooling) to query session activity in real time.

### Why This Matters

1. **Debugging sessions**: When something goes wrong, understanding the sequence of directories visited and tools called is critical for reproducing and diagnosing issues.
2. **Agent self-awareness**: An MCP tool that exposes session history lets the agent reason about its own behavior (e.g., "I've already visited that directory" or "I've called Bash 47 times this session").
3. **Operational visibility**: For users running long sessions or agent teams, a CLI summary of session activity provides confidence that work is progressing as expected.
4. **Post-session review**: After a session completes, the telemetry files serve as a lightweight audit trail without parsing full transcripts.

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| R1 | Track every directory the agent visits, with timestamps | Must |
| R2 | Track every tool invocation with name, argument summary, timestamp, and success/failure | Must |
| R3 | Track task lifecycle (create, status changes) with timestamps | Must |
| R4 | Store all data as structured JSONL files on disk, one set per session | Must |
| R5 | Expose each data stream via an MCP tool queryable by the agent | Must |
| R6 | Provide a CLI script for human-readable display of session data | Must |
| R7 | CLI supports filtering by session ID, latest session, data stream, and raw JSON output | Must |
| R8 | Hooks must be fast (<100ms) to avoid impacting agent responsiveness | Must |
| R9 | Data files must not grow unboundedly for very long sessions (consider rotation or caps) | Should |
| R10 | Plugin must not interfere with other plugins' hooks | Must |

### Non-Goals

- This plugin does NOT modify agent behavior based on telemetry (no blocking, no warnings).
- This plugin does NOT send data to external services. All data stays on disk.
- This plugin does NOT replace or duplicate Claude Code's own debug logging. It captures a structured subset for querying.

## 2. Technical Design

### 2.1 Plugin Structure

```
plugins/session-telemetry/
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json
    scripts/
      track-directory.sh       # PostToolUse: capture directory changes
      track-tool-call.sh       # PostToolUse: capture tool invocations
      track-task.sh            # PostToolUse: capture task lifecycle events
      lib/
        telemetry-common.sh    # Shared functions (session dir, JSONL append, timestamps)
  mcp/
    server.js                  # MCP server exposing query tools
    package.json
  bin/
    session-telemetry          # CLI for human-readable display
  README.md
```

### 2.2 plugin.json

```json
{
  "name": "session-telemetry",
  "version": "0.1.0",
  "description": "Track agent activity (directories, tool calls, tasks) within a session and expose via MCP tools and CLI",
  "author": {
    "name": "Nathan Heaps",
    "email": "nsheaps@gmail.com",
    "url": "https://github.com/nsheaps"
  },
  "homepage": "https://github.com/nsheaps/ai-mktpl/tree/main/plugins/session-telemetry",
  "repository": "https://github.com/nsheaps/ai-mktpl",
  "keywords": ["telemetry", "session", "hooks", "mcp", "observability", "tool-tracking", "task-tracking"]
}
```

### 2.3 Hooks

All hooks fire on **PostToolUse**. Directory tracking may additionally use **PreToolUse** if needed to capture the working directory before a tool changes it, but PostToolUse is the primary event.

#### hooks.json

```json
{
  "description": "Track session activity: directories visited, tool calls made, and task lifecycle events",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-directory.sh",
            "timeout": 2
          },
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-tool-call.sh",
            "timeout": 2
          }
        ]
      },
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-tool-call.sh",
            "timeout": 2
          }
        ]
      },
      {
        "matcher": "TaskCreate|TaskUpdate|TodoWrite",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-task.sh",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

**Note on matcher overlap:** The `Bash` matcher fires both `track-directory.sh` and `track-tool-call.sh`. The `.*` matcher fires `track-tool-call.sh` for all tools. The deduplication concern here is that Bash tool calls would log twice to `track-tool-call.sh`. The implementation must either:
- Use the `Bash` matcher exclusively for Bash (and exclude it from `.*`), or
- Have `track-tool-call.sh` accept all matchers and let the `.*` entry handle everything, removing the duplicate Bash entry for tool-call tracking.

The cleaner approach is to separate concerns: `.*` handles all tool-call tracking, `Bash` handles directory tracking only, and `TaskCreate|TaskUpdate|TodoWrite` handles task tracking only.

**Revised hooks.json (preferred):**

```json
{
  "description": "Track session activity: directories visited, tool calls made, and task lifecycle events",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-tool-call.sh",
            "timeout": 2
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-directory.sh",
            "timeout": 2
          }
        ]
      },
      {
        "matcher": "TaskCreate|TaskUpdate|TodoWrite",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/track-task.sh",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

### 2.4 Storage

#### Location

```
~/.claude/telemetry/{session-id}/
  directories.jsonl
  tool-calls.jsonl
  tasks.jsonl
```

Session ID is obtained from the hook input JSON (`session_id` field) passed via stdin, consistent with how existing plugins (e.g., `todo-sync`) read it.

#### Schema: directories.jsonl

Each line is a JSON object:

```json
{
  "ts": "2026-02-18T12:34:56.789Z",
  "directory": "/Users/nathan.heaps/src/nsheaps/ai-mktpl",
  "tool": "Bash",
  "command_summary": "git status"
}
```

- `ts` -- ISO 8601 timestamp
- `directory` -- absolute path of the working directory after the tool executed
- `tool` -- always "Bash" (only Bash changes directories)
- `command_summary` -- first 120 chars of the command, for context

Only log a new entry when the directory differs from the previous entry (dedup consecutive duplicates).

#### Schema: tool-calls.jsonl

```json
{
  "ts": "2026-02-18T12:34:56.789Z",
  "tool": "Bash",
  "arguments_summary": "git status",
  "success": true,
  "duration_ms": 342
}
```

- `ts` -- ISO 8601 timestamp
- `tool` -- tool name (e.g., `Bash`, `Read`, `Edit`, `Grep`, `TaskCreate`)
- `arguments_summary` -- truncated summary of tool arguments (max 200 chars). For Bash: the command. For Read: the file path. For Edit: the file path. For Grep: the pattern. Etc.
- `success` -- boolean, derived from hook input if available (exit code or error field)
- `duration_ms` -- execution duration if available from hook input, otherwise omitted

#### Schema: tasks.jsonl

```json
{
  "ts": "2026-02-18T12:34:56.789Z",
  "event": "created",
  "task_id": "abc123",
  "subject": "#1: Implement login endpoint",
  "status": "in_progress",
  "raw_tool": "TaskCreate"
}
```

- `ts` -- ISO 8601 timestamp
- `event` -- one of: `created`, `updated`, `todo_written`
- `task_id` -- task identifier (from tool input)
- `subject` -- task subject/description
- `status` -- current status after this event
- `raw_tool` -- which tool triggered this (`TaskCreate`, `TaskUpdate`, `TodoWrite`)

### 2.5 Hook Scripts

#### telemetry-common.sh (shared library)

```bash
#!/usr/bin/env bash
# Shared functions for telemetry hooks

telemetry_dir() {
  local input="$1"
  local session_id
  session_id=$(echo "$input" | jq -r '.session_id // empty')
  if [ -z "$session_id" ]; then
    echo ""
    return 1
  fi
  local dir="$HOME/.claude/telemetry/$session_id"
  mkdir -p "$dir"
  echo "$dir"
}

iso_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%S.000Z"
}

append_jsonl() {
  local file="$1"
  local json="$2"
  echo "$json" >> "$file"
}
```

#### track-directory.sh

Reads hook input from stdin. Extracts the working directory from the Bash tool's context (the `cwd` or working directory field if present, otherwise falls back to `pwd` of the hook process). Compares against the last entry in `directories.jsonl` and appends only if different.

#### track-tool-call.sh

Reads hook input from stdin. Extracts tool name, arguments, and success/failure. Builds a summary string from arguments (truncated to 200 chars). Appends to `tool-calls.jsonl`.

#### track-task.sh

Reads hook input from stdin. Extracts task ID, subject, status from the tool input. Determines event type from tool name. Appends to `tasks.jsonl`.

### 2.6 MCP Server

A lightweight MCP server (Node.js, using `@modelcontextprotocol/sdk`) that exposes three tools for querying session telemetry.

#### Installation

The MCP server is registered via `claude mcp add` during plugin installation, or documented in a `settings-fragment.json` for manual setup:

```json
{
  "mcpServers": {
    "session-telemetry": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/server.js"]
    }
  }
}
```

#### Tools

##### get_session_directories

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| session_id | string | No | Session ID to query. Defaults to current session (from `CLAUDE_SESSION_ID` env var). |
| limit | number | No | Max entries to return. Default: all. |
| since | string | No | ISO timestamp; return only entries after this time. |

Returns: Array of directory entries from `directories.jsonl`.

##### get_session_tool_calls

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| session_id | string | No | Session ID to query. Defaults to current session. |
| tool_name | string | No | Filter by tool name (exact match or regex). |
| limit | number | No | Max entries to return. Default: all. |
| since | string | No | ISO timestamp; return only entries after this time. |
| success_only | boolean | No | If true, return only successful calls. |

Returns: Array of tool call entries from `tool-calls.jsonl`.

##### get_session_tasks

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| session_id | string | No | Session ID to query. Defaults to current session. |
| task_id | string | No | Filter by specific task ID. |
| status | string | No | Filter by current status. |

Returns: Array of task entries from `tasks.jsonl`. When `task_id` is provided, returns the full history for that task.

### 2.7 CLI Script

`bin/session-telemetry` -- a bash script that reads JSONL files and presents them in human-readable format.

#### Usage

```
session-telemetry [options]

Options:
  --session <id>    Query a specific session by ID
  --latest          Query the most recently modified session (default if no --session)
  --directories     Show only directory tracking data
  --tools           Show only tool call data
  --tasks           Show only task data
  --json            Output raw JSONL instead of formatted table
  --summary         Show aggregate summary (tool counts, unique dirs, task stats)
  --help            Show usage information

Examples:
  session-telemetry --latest --summary
  session-telemetry --session abc-123 --tools
  session-telemetry --latest --tasks --json
  session-telemetry --latest --directories
```

#### Default Behavior

When run with `--latest` (or no session flag), the script finds the most recently modified session directory under `~/.claude/telemetry/` and displays all three data streams.

#### Output Formats

**Summary view** (`--summary`):

```
Session: abc-123-def-456
Duration: 45m 23s (12:00:00 - 12:45:23)

Directories (7 unique):
  /Users/nathan.heaps/src/nsheaps/ai-mktpl          (visited 12x)
  /Users/nathan.heaps/src/nsheaps/claude-utils       (visited 3x)
  ...

Tool Calls (142 total):
  Bash       52  (36.6%)
  Read       34  (23.9%)
  Edit       22  (15.5%)
  Grep       18  (12.7%)
  Glob        8  ( 5.6%)
  Other       8  ( 5.6%)
  Failures:   3  ( 2.1%)

Tasks (5 total):
  completed   3
  in_progress 1
  pending     1
```

**Table view** (default, per data stream):

```
Directories:
  TIME      DIRECTORY                                    COMMAND
  12:00:01  /Users/nathan.heaps/src/nsheaps/ai-mktpl    git status
  12:02:15  /Users/nathan.heaps/src/nsheaps/claude-utils ls -la
  ...

Tool Calls:
  TIME      TOOL     OK  SUMMARY
  12:00:01  Bash     Y   git status
  12:00:02  Read     Y   /Users/nathan.heaps/src/.../plugin.json
  12:00:03  Edit     N   /Users/nathan.heaps/src/.../hooks.json
  ...

Tasks:
  TIME      EVENT    TASK ID  STATUS       SUBJECT
  12:01:00  created  abc123   in_progress  #1: Implement login endpoint
  12:15:00  updated  abc123   completed    #1: Implement login endpoint
  ...
```

### 2.8 Session ID Discovery

The hook scripts receive session ID from the hook input JSON on stdin. The MCP server receives it from:
1. The `CLAUDE_SESSION_ID` environment variable (if Claude Code sets this for MCP servers), or
2. An explicit `session_id` parameter on each tool call.

The CLI discovers sessions by listing directories under `~/.claude/telemetry/`.

**Open question:** Whether `CLAUDE_SESSION_ID` is reliably available to MCP server processes needs verification. If not, the MCP tools must require `session_id` as a parameter (the agent knows its own session ID).

### 2.9 Performance Considerations

- **Hook timeout: 2 seconds.** All hooks do minimal work: read stdin, extract fields with `jq`, append one line to a file. Expected execution: <50ms.
- **File I/O:** JSONL append is a single write syscall, no file locking needed (atomic for small writes on local filesystems).
- **No network calls** in hooks. All data stays local.
- **MCP server:** Reads JSONL files on demand. For very long sessions (>10K lines), consider streaming or pagination via the `limit` parameter.

### 2.10 Cleanup and Retention

Telemetry files accumulate over time. The plugin does not implement automatic cleanup in v0.1. Future versions should add:
- A `--clean` CLI flag to remove telemetry older than N days
- A `SessionStart` hook that prunes old session directories
- Configurable retention period (default: 30 days)

## 3. Open Questions

| # | Question | Impact | Notes |
|---|----------|--------|-------|
| 1 | Is `CLAUDE_SESSION_ID` available to MCP server processes as an env var? | MCP tool design | If not, agents must pass it explicitly. Either way works; just affects ergonomics. |
| 2 | What fields does the PostToolUse hook input JSON contain? | Hook script design | Need to verify: does it include tool arguments, exit code, duration, and working directory? The [hooks docs](https://code.claude.com/docs/en/hooks) should specify this. |
| 3 | Should the `.*` matcher on PostToolUse fire for MCP tool calls too? | Completeness | MCP tools have names like `mcp__server__tool`. The `.*` regex should match them, but verify. |
| 4 | Should telemetry data be queryable across sessions? | CLI scope | v0.1 queries one session at a time. Cross-session queries (e.g., "show all sessions for this project") could be a future enhancement. |
| 5 | Should the MCP server be stdio-based or HTTP? | MCP design | stdio is simpler and matches existing patterns (e.g., `linear-mcp-sync`). HTTP would allow external tool access but adds complexity. |
| 6 | File size cap for very long sessions? | Storage | A 10K-tool-call session produces ~2MB of JSONL. Probably fine, but consider log rotation for sessions lasting many hours. |
| 7 | Should `track-directory.sh` also fire on `Read`, `Edit`, `Write`, `Glob`, `Grep` to capture their target paths? | Directory tracking accuracy | These tools operate on specific file paths. Logging their target directory (dirname of the file path) would give richer directory data beyond just Bash `cd` commands. |

## 4. References

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks) -- PreToolUse, PostToolUse event schemas and hook configuration
- [Claude Code Plugins Documentation](https://code.claude.com/docs/en/plugins) -- Plugin structure, plugin.json, hooks.json format
- [Model Context Protocol SDK](https://github.com/modelcontextprotocol/typescript-sdk) -- MCP server implementation for Node.js
- [MCP Specification](https://spec.modelcontextprotocol.io/) -- Tool definition schema and transport protocols
- Existing plugin patterns in this repo:
  - `plugins/todo-sync/` -- PostToolUse hook with matcher, stdin parsing, JSONL awareness
  - `plugins/context-bloat-prevention/` -- PostToolUse with `.*` and tool-specific matchers
  - `plugins/linear-mcp-sync/` -- MCP server registration via settings-fragment.json
  - `plugins/statusline-iterm/` -- SessionStart hook, `${CLAUDE_PLUGIN_ROOT}` variable usage
