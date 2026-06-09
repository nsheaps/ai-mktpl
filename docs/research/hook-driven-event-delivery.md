# Hook-driven GitHub event delivery — design notes

Design for the github-app "deliver GitHub events via hooks" feature (replaces the
plugin-monitor approach, in scope for nsheaps/ai-mktpl#585). Hook-API facts from the
claude-code-guide agent against code.claude.com/docs, 2026-06-09. Items marked **[VERIFY]**
must be re-confirmed before building — the async-push design hinges on them.

## Hook capabilities (as reported)

| Mechanism                                              | To Claude                   | To user | Notes                                  |
| ------------------------------------------------------ | --------------------------- | ------- | -------------------------------------- |
| `hookSpecificOutput.additionalContext` (exit 0 + JSON) | yes                         | —       | SessionStart / UserPromptSubmit / Stop |
| `systemMessage` (exit 0 + JSON)                        | —                           | yes     | universal, user-facing                 |
| plain stdout (exit 0)                                  | yes (UserPromptSubmit only) | —       | silenced on most events                |
| exit 2 + stderr                                        | yes (as warning)            | yes     | blocks on decision events              |
| `suppressOutput: true`                                 | —                           | —       | hides stdout from transcript           |

- **UserPromptSubmit**: inject `additionalContext` for the turn; `systemMessage` to user. Exit 2 blocks the prompt.
- **Stop**: `decision: "block"` + `reason` -> Claude re-wakes with `reason` as context. **[VERIFY]** report claims no `stop_hook_active` input and no built-in timeout — doubt the first; confirm before relying on it for loop-prevention.
- **SessionStart matchers**: `startup` (new), `resume` (`--resume`/`--continue`), `clear`, `compact`. Inject `additionalContext`.
- **Async push**: **[VERIFY]** `async: true` + `asyncRewake: true` on a command hook = run in background, then wake the session on exit 2 with stdout/stderr shown to Claude as a system reminder. Linchpin for UserPromptSubmit/Stop "fetch then push one message."
- **Plugin hooks.json**: SessionStart, UserPromptSubmit, Stop all fire from a plugin's `hooks/hooks.json`.

## Design (decisions locked with handler 2026-06-09)

- **"user" target = `systemMessage`** (CLI transcript). Channel-push (Discord/Telegram) explicitly out of scope for v1.
- **In scope for #585**: drop the `experimental.monitors` auto-start; refactor the fetch/cursor/token logic into a shared core reused by the hooks. `events-monitor.sh` may remain as a manual/CLI watcher.
- Claude-facing message **always includes**: `"not every event may be related to your current working task"`.

**Shared fetch core** (`events-fetch.sh`, refactored from `events-monitor.sh`): one-shot "events since
last fetch"; auth via `token-check.sh`; chronological cursor (newest-event-id stop-marker, since GitHub
ids are not monotonic across types); state file = last-seen id + last-fetch timestamp.

**Hooks** (plugin `hooks/hooks.json`):

- `SessionStart`/`startup` -> show last **10** events; set cursor.
- `SessionStart`/`resume` -> all since last fetch.
- `UserPromptSubmit` (`async`+`asyncRewake`) -> fetch since last fetch -> one message.
- `Stop` (`async`+`asyncRewake`) -> poll up to **10m**; one message when events arrive; at **8m** with none ->
  `"no github events received in the last <X>"`; allow stop at 10m. Re-wake only when cursor advanced (loop guard).

**Config — `eventsDelivery` enum** (+ `eventsRepo`, `eventsStopTimeoutSeconds`=600, `eventsStopNoticeSeconds`=480):

| mode           | file | user (`systemMessage`)          | Claude (`additionalContext`) |
| -------------- | ---- | ------------------------------- | ---------------------------- |
| `disabled` (a) | —    | —                               | —                            |
| `file` (b)     | yes  | —                               | —                            |
| `user` (c)     | —    | full                            | —                            |
| `both` (d)     | —    | full                            | full                         |
| `summary` (e)  | —    | `"events received from github"` | full                         |

## Pre-build verification

- `async` / `asyncRewake` exact field names + semantics.
- `stop_hook_active` existence (Stop loop-prevention).

## Related: task-utils write-gate (separate fix, nsheaps/agents)

The `task-utils` plugin (v0.3.0) `require-task-in-progress.sh` PreToolUse hook gates
`Write|Edit|MultiEdit|NotebookEdit` and **defaults to ON** (`requireInProgress` default `true`).
Handler wants it **opt-in** (default off). Fix: flip the in-code default in the hook + docs + version bump.
