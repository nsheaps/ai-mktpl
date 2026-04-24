---
name: task-utils
status: draft
description: Unified task management plugin consolidating todo-plus-plus, todo-sync, and task-parallelization into a single cohesive plugin with provider-based task sync.
---

# task-utils Plugin Spec

## Problem Statement

Task management is currently fragmented across three separate plugins:

- **todo-plus-plus** (v0.1.5): lifecycle hooks (commit check, session restore, stop guard)
- **todo-sync** (v0.2.4): syncs TodoWrite output to GitHub issues and initializes `.gitignore`
- **task-parallelization** (v0.2.25): skill for running tasks in parallel

These overlap in concern, share no config namespace, and require three separate install/update cycles. Agents must install all three to get complete task management behavior, and there is no single place to configure task-related settings.

## Goals

1. Single `task-utils` plugin replacing all three
2. Provider-based task sync — pluggable backends (filesystem, GitHub issues, extensible to others)
3. Complete task lifecycle management (session restore, commit guard, stop guard)
4. Parallelization skill migrated in
5. Clean migration path with no behavior regression

## Non-Goals

- Task storage backend (tasks remain in Claude Code's native task store)
- Multi-agent task coordination (out of scope for v1)
- Custom task types or fields beyond what TaskCreate/TaskUpdate support

## Provider Architecture

Task sync is handled by a configurable list of **providers**. Each provider implements a standard interface and is invoked on task lifecycle events.

### Provider Interface

```typescript
interface TaskProvider {
  onTaskCreate(task: Task): Promise<void>;
  onTaskUpdate(task: Task): Promise<void>;
  onTaskComplete(task: Task): Promise<void>;
}
```

### Built-in Providers

#### `FilesystemProvider`

Writes task state to `$CLAUDE_PROJECT_DIR/.claude/tasks/` as JSON files.

- Source: migrated from todo-sync's filesystem output
- Purpose: provides local task persistence for environments where file access is available
- Status: **enabled by default in v1**, expected to be deprecated as agent environments become ephemeral (no persistent filesystem)
- Config key: `providers.filesystem`

#### `GitHubIssuesProvider`

Syncs task state to GitHub issues on the agent's configured repo.

- Source: adapted from todo-sync (redesigned)
- **Sync behavior**: uses a haiku sub-agent to find existing issues matching the task (by title/ID) before creating new ones. Updates existing issues rather than creating duplicates.
- On `onTaskCreate`: search for existing issue → update if found, create if not
- On `onTaskUpdate`: update issue labels/status to match task state
- On `onTaskComplete`: close issue (or add "done" label, per config)
- Config key: `providers.githubIssues`

### Design for Extensibility

The provider list is open — future providers (e.g., Linear, Jira, Slack) can be added by implementing the `TaskProvider` interface and registering in config. No plugin changes required for new providers.

### Provider Configuration

```yaml
task-utils:
  providers:
    filesystem:
      enabled: true # writes to $CLAUDE_PROJECT_DIR/.claude/tasks/
    githubIssues:
      enabled: false # set true to enable GitHub issue sync
      repo: "owner/repo" # required if enabled: true
      labels: # optional labels to apply to created/updated issues
        - "agent-task"
      closeOnComplete: true # close issue when task completes
```

## Hooks (7 total)

### 1. `TaskCompleted` — Commit Check

**Source**: todo-plus-plus `TaskCompleted` hook  
**Behavior**: Block task completion if uncommitted changes exist in the working directory. Forces agents to commit before marking a task done.  
**Configurable**: `commitCheck.enabled` (default: `true`)  
**Advisory**: No — blocks when enabled

### 2. `SessionStart` — Task Awareness + Restore

**Source**: todo-plus-plus `SessionStart` hook  
**Behavior**:

- Injects task-awareness context into the session (reminder to use TaskCreate on every action request)
- Restores any `in_progress` tasks from the previous session, prompting the agent to resume or triage them

**Advisory**: No — always runs

### 3. `PreToolUse` (advisory) — No Active Task Warning

**Source**: New (fills gap in todo-plus-plus)  
**Behavior**: When a non-conversational tool is invoked and no task is `in_progress`, emit an advisory warning reminding the agent to create/activate a task.  
**Advisory**: Yes — warns, does not block  
**Configurable**: `activeTaskGuard.enabled` (default: `true`)

### 4. `Stop` (advisory) — In-Progress Task Warning

**Source**: todo-plus-plus `Stop` hook — **migrated from agent repo to plugin**  
**Behavior**: When the session is about to end, warn if any tasks remain `in_progress`. Reminds the agent to complete or hand off work.  
**Advisory**: Yes — warns, does not block  
**Status**: Migrated in but **commented out initially** pending validation in plugin context  
**Configurable**: `stopGuard.enabled` (default: `true`)

### 5. `PostToolUse:TaskCreate` — Sync New Task to Providers

**Source**: todo-sync (redesigned)  
**Behavior**: After `TaskCreate` succeeds, invoke each enabled provider's `onTaskCreate`. The `GitHubIssuesProvider` uses a haiku sub-agent to find existing matching issues and update them, or create a new issue only if none exists.  
**Configurable**: per-provider `enabled` flags  
**Advisory**: No (when enabled) — failure emits warning but does not block

### 6. `PostToolUse:TaskUpdate` — Sync Task Update to Providers

**Source**: New  
**Behavior**: After `TaskUpdate` changes task status, invoke each enabled provider's `onTaskUpdate`. GitHub issues receive label and status updates.  
**Configurable**: per-provider `enabled` flags  
**Advisory**: No (when enabled) — failure emits warning but does not block

### 7. `PostToolUse:TodoWrite` — Sync Todo JSON _(deferred post-MVP)_

**Source**: todo-sync  
**Behavior**: After `TodoWrite`, sync the todo list to a GitHub issue or comment for visibility.  
**Status**: **Deferred** — included in plugin structure but disabled by default. Will be enabled in v1.1 once TodoWrite→Task interop is better understood.

## Skills

### `task-parallelization` (migrated)

Migrated verbatim from task-parallelization v0.2.25. No functional changes in v1.  
Documents how to run multiple tasks in parallel using background agents.

### `task-management` (new)

New skill covering:

- When and how to use TaskCreate, TaskUpdate, TaskList, TaskGet
- Task naming conventions (include ID and ticket number)
- The full task lifecycle (created → in_progress → completed/cancelled)
- When to delegate tasks to sub-agents vs. execute directly

## Configuration

Full configuration reference via `plugins.settings.yaml` in the consuming agent's repo:

```yaml
task-utils:
  providers:
    filesystem:
      enabled: true # writes task state to $CLAUDE_PROJECT_DIR/.claude/tasks/
    githubIssues:
      enabled: false # set true to enable GitHub issue sync
      repo: "owner/repo" # required if enabled: true
      labels:
        - "agent-task"
      closeOnComplete: true
  commitCheck:
    enabled: true # block TaskCompleted if uncommitted changes exist
  stopGuard:
    enabled: true # warn on Stop if in_progress tasks remain (commented out initially)
  activeTaskGuard:
    enabled: true # warn on tool use if no active task
```

## Migration Path

For agents currently using the three separate plugins:

1. Install `task-utils` (adds this plugin to `enabledPlugins`)
2. Remove `todo-plus-plus`, `todo-sync`, `task-parallelization` from `enabledPlugins`
3. Copy any custom config from old plugins into `task-utils` config block
4. Configure `providers.githubIssues.enabled` if you previously used todo-sync's GitHub sync (was previously always-on in todo-sync)

No data migration required — task state lives in Claude Code's native store.

**Note**: TodoWrite gitignore initialization (from todo-sync's `SessionStart`) is deferred post-MVP. If you relied on this, keep `todo-sync` installed until v1.1.

## MVP Scope (v1)

| Feature                                                   | Status       |
| --------------------------------------------------------- | ------------ |
| TaskCompleted commit check                                | In scope     |
| SessionStart restore + awareness                          | In scope     |
| PreToolUse active-task guard                              | In scope     |
| Stop guard (migrated, commented out initially)            | In scope     |
| FilesystemProvider                                        | In scope     |
| GitHubIssuesProvider (find-or-create via haiku sub-agent) | In scope     |
| task-parallelization skill (migrated)                     | In scope     |
| task-management skill (new)                               | In scope     |
| PostToolUse:TodoWrite sync                                | **Deferred** |
| TodoWrite gitignore init                                  | **Deferred** |

## Deferred Items (post-MVP)

- **TodoWrite sync** (`PostToolUse:TodoWrite`): sync todo JSON state to GitHub. Needs clearer spec for what "syncing" means at the issue level.
- **GitIgnore init** (from todo-sync `SessionStart`): auto-add `.claude/todos/` to `.gitignore`. Low priority; agents can do this manually.
- **Task→PR linking**: automatically link tasks to open PRs when a TaskCreate happens on a feature branch.
- **FilesystemProvider deprecation**: once agent environments are consistently ephemeral, filesystem provider will be removed. For now it stays enabled by default.
- **Additional providers**: Linear, Jira, Slack, etc. — implementing the provider interface is sufficient to add new backends.

## References

- [#64](https://github.com/nsheaps/ai-mktpl/issues/64) — original todo-plus-plus issue
- [#65](https://github.com/nsheaps/ai-mktpl/issues/65) — todo-sync issue
- [#138](https://github.com/nsheaps/ai-mktpl/issues/138) — task-parallelization issue
- [#319](https://github.com/nsheaps/ai-mktpl/issues/319) — consolidation tracking
- [#320](https://github.com/nsheaps/ai-mktpl/issues/320) — GitHub sync design
- [#330](https://github.com/nsheaps/ai-mktpl/issues/330) — config namespace design
- [#370](https://github.com/nsheaps/ai-mktpl/issues/370) — migration path
- [Discord design thread](https://discord.com/channels/1490863845252665415/1497254984696205445)
