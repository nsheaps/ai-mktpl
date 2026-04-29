# Claude Code: Hooks Reference

The full hook lifecycle for Claude Code. Hooks are event-driven callbacks the
harness invokes at specific points — before/after tool calls, on session
transitions, on user input, etc. They can observe, add context, modify input,
or block actions.

**Source of truth**: <https://code.claude.com/docs/en/hooks>. When this doc
disagrees with the live page, the live page wins. Last verified against the
live docs on 2026-04-29.

For where hooks are configured on disk and how they layer with project /
plugin scope, see [folder-structure.md](folder-structure.md). For
session-env propagation specifically, jump to
[CLAUDE_ENV_FILE](#claude_env_file-propagating-env-into-bash-tool-calls).

## Where hooks live

Hooks are declared under a top-level `hooks` key in any settings layer:

- `~/.claude/settings.json` (user)
- `<repo>/.claude/settings.json` (project, committed)
- `<repo>/.claude/settings.local.json` (personal, gitignored)
- Plugin-bundled at `<plugin>/hooks/hooks.json` (wrapped under a `hooks` key)

All matching hooks across all layers run **in parallel** for a single event;
they don't see each other's output. `disableAllHooks: true` in any layer
(except managed) disables all hooks at that scope and below.

Settings-layer shape (direct):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "/path/to/script.sh" }]
      }
    ]
  }
}
```

Plugin-layer shape (wrapped):

```json
{
  "description": "optional human-readable summary",
  "hooks": {
    "PreToolUse": [ /* same shape as above */ ]
  }
}
```

## Hook types (the `type` field)

Five types. `prompt` and `agent` are LLM-driven; the rest are deterministic.

| Type | What it does | Stdin | Stdout / response | Where you'd use it |
| ---- | ------------ | ----- | ----------------- | ------------------ |
| `command` | Runs a shell command | Event JSON | JSON on stdout (or none) | Fast deterministic checks, env propagation |
| `http` | POSTs event JSON to a URL | — | JSON response body | External policy service, audit sink |
| `mcp_tool` | Invokes an MCP tool with given input | — | Tool result | Delegate to a custom MCP service |
| `prompt` | Asks an LLM to evaluate the event | — | Model returns the JSON response | Context-aware validation, "should I block this?" |
| `agent` | Runs a sub-agent with full tool access | — | Sub-agent's structured output | Complex multi-step decisions |

Common config fields across types:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `timeout` | number (seconds) | Defaults: command 600, http 30, mcp_tool 60, prompt 30, agent 60 |
| `if` | string | Permission-rule syntax — extra gate beyond the matcher |
| `statusMessage` | string | Shown in the UI while the hook runs |
| `once` | bool | For skills/agents only; runs the hook at most once per session |

`command`-only:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `command` | string | Full command line; required |
| `shell` | `"bash"` \| `"powershell"` | Default `bash` |
| `async` | bool | Fire-and-forget; output is ignored |
| `asyncRewake` | bool | If `async`, wake Claude when the hook completes |

`http`-only:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `url` | string | Required |
| `headers` | object | Optional request headers |
| `allowedEnvVars` | string[] | Env vars whose names+values get sent to the URL |

`mcp_tool`-only:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `server` | string | MCP server name |
| `tool` | string | Tool name on that server |
| `input` | object | Arguments to pass |

`prompt` / `agent`-only:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `prompt` | string | Required. The prompt the model evaluates |
| `model` | string | Optional model override |

## Matcher syntax

Most tool/permission events take a `matcher` field. Stop / SessionStart /
SessionEnd / CwdChanged / etc. either don't have a matcher or use a fixed
enum (see each event below).

| Pattern | Treated as | Examples |
| ------- | ---------- | -------- |
| `"*"`, `""`, or omitted | Match all | Fires on every occurrence |
| Letters/digits/`_`/`\|` only | Exact name or `\|`-separated list | `Bash`, `Read\|Write\|Edit` |
| Anything else | JavaScript regex | `^Notebook`, `mcp__memory__.*`, `mcp__.*__delete.*` |

Matchers are case-sensitive. MCP tool names follow `mcp__<server>__<tool>`.

## Common input fields

Every hook receives JSON on stdin (or as the request body for `http` hooks)
with these baseline fields:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/dir",
  "permission_mode": "default" | "plan" | "acceptEdits" | "auto" | "dontAsk" | "bypassPermissions",
  "hook_event_name": "PreToolUse"
}
```

Event-specific fields are listed per event below.

## Common output fields

A hook can return JSON on stdout (command), as the HTTP response body, or as
the model's structured output (prompt/agent). All of these are optional —
returning nothing is the same as `{}`.

| Field | Type | Effect |
| ----- | ---- | ------ |
| `continue` | bool, default `true` | If `false`, halts Claude entirely (with `stopReason`) |
| `stopReason` | string | Reason shown to the user when `continue: false` |
| `suppressOutput` | bool, default `false` | Hide the hook's stdout from the transcript |
| `systemMessage` | string | Warning/info shown to the user (and seen by Claude) |
| `decision` | `"block"` or absent | Event-specific. Blocks the action when supported |
| `reason` | string | Why the decision was made |
| `hookSpecificOutput` | object | Event-specific shape (see each event) |

`hookSpecificOutput.hookEventName` is required when you populate
`hookSpecificOutput`, and must match the event you're handling.

### Exit codes (command hooks)

| Code | Behavior |
| ---- | -------- |
| `0` | Success. Stdout is parsed as JSON; for `UserPromptSubmit` / `UserPromptExpansion` / `SessionStart`, stdout is also added to context Claude can see |
| `2` | Blocking error. Stdout/JSON ignored; stderr fed to Claude. Blocks the action if the event supports blocking |
| other | Non-blocking error. First line of stderr in transcript, full stderr in debug log; execution continues |

Exception: `WorktreeCreate` aborts on any non-zero exit code.

---

# Events

## SessionStart

Fires when a session starts or resumes. Matcher: `startup` | `resume` |
`clear` | `compact`. Supports `CLAUDE_ENV_FILE`.

Input adds `source` (matches the matcher), `model`, optional `agent_type`.

Output:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "injected as system context"
  }
}
```

`additionalContext` is the canonical "inject startup state for Claude to
see" mechanism — project state, restored crons, etc. The project's
`bin/hooks/session-start-restore-crons.sh` uses this to re-arm scheduled
tasks on every session start.

## SessionEnd

Fires when a session terminates. Matcher: `clear` | `resume` | `logout` |
`prompt_input_exit` | `bypass_permissions_disabled` | `other`. No decision
control — side effects (cleanup, logging) only.

## Setup

Fires only under `claude --init-only` or `claude -p --init / --maintenance`.
Matcher: `init` | `maintenance`. Supports `CLAUDE_ENV_FILE`. Input adds
`trigger`. Output shape matches SessionStart.

## UserPromptSubmit

Fires when the user submits a prompt, before Claude processes it. No
matcher (always fires). Input adds `prompt`.

Output:

```json
{
  "decision": "block",
  "reason": "shown to user; prompt is dropped",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "appended as system context before Claude sees prompt",
    "sessionTitle": "rename the session"
  }
}
```

`decision: "block"` drops the prompt entirely. `additionalContext` lets you
inject extra context (e.g. "recent CI failures") before Claude responds.

## UserPromptExpansion

Fires when a slash command (or MCP prompt) expands into a prompt. Matcher:
command name, or empty for all. Input adds `expansion_type`
(`slash_command` | `mcp_prompt`), `command_name`, `command_args`,
`command_source`, and the expanded `prompt`. Output as UserPromptSubmit
minus `sessionTitle`.

## PreToolUse

Fires before a tool call executes. Use this to allow / deny / modify the
call, or to inject extra context.

| | |
| --- | --- |
| Matcher values | tool names: `Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `Agent`, `WebFetch`, `WebSearch`, `AskUserQuestion`, `ExitPlanMode`, MCP tools (`mcp__<server>__<tool>`) |

Input:

```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "permission_mode": "...",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "git status", "description": "..." },
  "tool_use_id": "..."
}
```

Output:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny" | "ask" | "defer",
    "permissionDecisionReason": "...",
    "updatedInput": { "command": "git status --porcelain" },
    "additionalContext": "..."
  },
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "..."
}
```

- `permissionDecision: "allow"` — run without prompting the user
- `"deny"` — refuse; the reason is shown to Claude
- `"ask"` — fall through to the user permission prompt
- `"defer"` — don't decide; let other hooks / the default flow handle it
- `updatedInput` rewrites the tool's arguments before it runs (e.g.
  refreshing a GH token by re-sourcing an env file before `Bash`)

## PostToolUse

Fires after a tool call succeeds. Matcher: same as PreToolUse. Input adds
`tool_result` (string).

Output:

```json
{
  "decision": "block",
  "reason": "injected back to Claude as system message",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "..."
  }
}
```

`decision: "block"` injects `reason` back into the conversation so Claude
can react (e.g. "your edit broke a test"). It does **not** undo the tool —
the side effect already happened.

## PostToolUseFailure

Same matcher as PreToolUse. Input has `tool_error` instead of `tool_result`.
Output shape identical to PostToolUse.

## PostToolBatch

Fires after a full batch of parallel tool calls resolves. No matcher. Input
includes `tool_calls: [...]` — an array of `{tool_name, tool_input,
tool_use_id, tool_result}` for the whole batch. Output: standard
`decision`/`reason`/`continue`/etc., no `hookSpecificOutput`.

## PermissionRequest

Fires when the harness is about to show the user a permission dialog. A
hook can short-circuit the dialog. Matcher: tool names. Input adds the
tool call plus `permission_suggestions: [...]` — the addRules the harness
was going to offer.

Output:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow" | "deny",
      "updatedInput": { /* override tool input */ },
      "updatedPermissions": [
        {
          "type": "addRule" | "updatePermissionMode",
          "rules": [{ "toolName": "Bash", "ruleContent": "git status:*" }],
          "behavior": "allow" | "deny" | "ask",
          "destination": "localSettings" | "projectSettings" | "userSettings"
        }
      ],
      "message": "shown to user",
      "interrupt": false
    }
  }
}
```

## PermissionDenied

Fires when the auto-mode classifier denies a tool call. Matcher: tool names.
Output adds `hookSpecificOutput.retry: bool` — if `true`, Claude is told the
call was denied and may retry differently.

## Stop

Fires when Claude finishes responding. No matcher. Output supports
`decision: "block"` with `reason` — the canonical "you said you're done
but X is still incomplete" mechanism (tests not run, PR not pushed, etc.).

## StopFailure

Fires when the turn ends due to an API error. Matcher: `rate_limit` |
`authentication_failed` | `billing_error` | `invalid_request` |
`server_error` | `max_output_tokens` | `unknown`. Input adds `error_type`.
No decision control.

## SubagentStart

Fires on **any** `Agent` tool invocation — this is general-purpose, not
agent-team-specific. Matcher: `general-purpose` | `Explore` | `Plan` |
custom agent name. Input adds `agent_type`, `agent_id`, `prompt`. No
decision control.

## SubagentStop

Fires when **any** sub-agent finishes (general-purpose, not
agent-team-only — symmetric with SubagentStart). Matcher: same as
SubagentStart. Output supports `decision: "block"` to force it to keep
working — symmetric with top-level Stop.

## TaskCreated / TaskCompleted

Agent-teams only — most single-agent sessions never see these. Fire when a
task is being created / marked complete via `TaskCreate`. No matcher.
Input adds `task_id`, `task_title`, `task_description`. Output supports
`decision: "block"` to refuse the create/complete.

## TeammateIdle

Agent-teams only — most single-agent sessions never see this. Fires when
an agent-team teammate is about to go idle. No matcher. Input adds
`teammate_id`. Output supports `decision: "block"` to keep them working.

## InstructionsLoaded

Fires every time a CLAUDE.md or rules file is loaded. Matcher:
`session_start` | `nested_traversal` | `path_glob_match` | `include` |
`compact`. Input adds `file_path`, `memory_type`
(`User`/`Project`/`Local`/`Managed`), `load_reason`, optionally `globs`,
`trigger_file_path`, `parent_file_path`. No decision control — audit
logging.

## ConfigChange

Fires when a settings file changes mid-session. Matcher: `user_settings` |
`project_settings` | `local_settings` | `policy_settings` | `skills`.
Input adds `config_source`. Output supports `decision: "block"` to refuse
the change.

## FileChanged

Fires when a watched file changes on disk. Matcher: literal filenames /
patterns (e.g. `.envrc|.env`). Supports `CLAUDE_ENV_FILE`. Input adds
`file_path`, `change_type`. No decision control — used for reactive env
management (re-source `.envrc` on change).

## CwdChanged

Fires when the working directory changes. No matcher. Supports
`CLAUDE_ENV_FILE`. Input adds `old_cwd`, `new_cwd`. No decision control.
Useful for re-loading direnv-style env when crossing repo boundaries.

## WorktreeCreate

Fires when a worktree is being created. No matcher. Input adds
`isolation_mode: "worktree" | "docker"`. Command hooks print the worktree
path on stdout; HTTP hooks return `hookSpecificOutput.worktreePath`.
**Any non-zero exit aborts worktree creation** — the only event with this
behavior.

## WorktreeRemove

Fires when a worktree is being removed. Failures are logged in debug mode
only — no decision control.

## PreCompact

Fires before context compaction. Matcher: `manual` | `auto`. Input adds
`compaction_trigger`. Output supports `decision: "block"` — useful for
"don't compact mid-task".

## PostCompact

Fires after compaction. Same matcher values. Input includes the summary
text the model produced. No decision control — observability / refresh
state derived from pre-compact context.

## Notification

Fires when Claude Code sends a notification. Matcher:
`permission_prompt` | `idle_prompt` | `auth_success` |
`elicitation_dialog` | `elicitation_complete` | `elicitation_response`.
Input adds `notification_type`. No decision control — typically used to
forward notifications to Discord, Telegram, or desktop.

## Elicitation / ElicitationResult

Fire when an MCP server requests user input mid-tool, and after the user
responds. Matcher: MCP server names. `Elicitation` output supports
`hookSpecificOutput.action: "accept" | "decline" | "cancel"` and
`content: { ... }` to auto-fill the form on the user's behalf.

---

# `CLAUDE_ENV_FILE`: propagating env into Bash tool calls

This is the mechanism that makes `export` from a `SessionStart` hook visible
in every later `Bash` tool call. See
[folder-structure.md → Session env](folder-structure.md#session-env-claudesession-envsession-id)
for where the file lives on disk and the broader lifecycle context.

**Supported by**: `SessionStart`, `Setup`, `CwdChanged`, `FileChanged`.

**How it works**:

1. The harness sets `CLAUDE_ENV_FILE` before invoking a supporting hook.
   The value is a path under `~/.claude/session-env/<session-id>/`.
2. The hook script appends shell statements to that file —
   `export FOO=bar`, `source /path/to/other-env`, etc.
3. The harness sources every file in the session's session-env dir into
   the shell of every subsequent `Bash` tool call. The exports become
   visible immediately and persist for the rest of the session.

**Minimal example**:

```bash
#!/bin/bash
# SessionStart hook: set a couple of static exports
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export PROJECT_TYPE=nodejs' >> "$CLAUDE_ENV_FILE"
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
fi
```

**Capture-everything pattern** — useful when a setup command (nvm, asdf,
direnv) mutates many vars and you don't want to enumerate them:

```bash
#!/bin/bash
ENV_BEFORE=$(export -p | sort)
source ~/.nvm/nvm.sh
nvm use 20

if [ -n "$CLAUDE_ENV_FILE" ]; then
  ENV_AFTER=$(export -p | sort)
  comm -13 <(echo "$ENV_BEFORE") <(echo "$ENV_AFTER") >> "$CLAUDE_ENV_FILE"
fi
```

**Indirection pattern (recommended for tokens)** — write a `source` line
into `$CLAUDE_ENV_FILE` that points at a runtime file you can refresh
later from a `PreToolUse` hook. The `github-app` plugin uses this so
`GH_TOKEN` is always fresh: SessionStart writes `source <runtime-file>`
into `$CLAUDE_ENV_FILE`; a PreToolUse(`Bash`) hook regenerates the
runtime-file before each Bash call. See
[folder-structure.md → Session env](folder-structure.md#session-env-claudesession-envsession-id)
for the full pattern.

**Don't**:

- Treat the contents of `~/.claude/session-env/<id>/` as a credential leak —
  see folder-structure.md. They are by design.
- Try to `cat` your own session's env file to "verify" it during runtime —
  it likely contains tokens. Inspect existence and line counts only.

---

# See also

- [folder-structure.md](folder-structure.md) — where hooks and session-env
  files live on disk
- Official docs: <https://code.claude.com/docs/en/hooks>
- Official docs: <https://code.claude.com/docs/en/settings>
- `plugin-dev:hook-development` skill — patterns and examples for authoring
  hooks inside a plugin
