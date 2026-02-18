# Agent Teams: Hooks and Configuration Reference

Detailed reference for configuring agent teams, team-specific hooks, spawn backends, and environment variables.

## Settings.json Configuration

### Enabling Agent Teams

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "auto"
}
```

### teammateMode Values

| Value | Behavior |
|:------|:---------|
| `"auto"` | Auto-detect: uses tmux if available, otherwise in-process |
| `"in-process"` | Hidden sessions within the same process. Navigate with Shift+Up/Down |
| `"tmux"` | Visible split panes. Requires tmux session or iTerm2 with `it2` CLI |

### CLI Override

```bash
claude --teammate-mode in-process
claude --teammate-mode tmux
```

### Environment Variables for Enabling

| Variable | Description |
|:---------|:------------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Set to `1` to enable |
| `CLAUDE_CODE_SPAWN_BACKEND` | Force spawn backend: `in-process`, `tmux` |

## Spawn Backend Details

### in-process (Default)

- Teammates run as hidden sessions within the leader process
- Navigate with Shift+Up/Down, Enter to view
- Teammates die when the leader exits
- No external dependencies

### tmux

- Each teammate gets a visible split pane
- Teammates survive leader exit (tmux keeps them alive)
- Requires: `$TMUX` set (inside a tmux session) or tmux available
- For iTerm2: Install [`it2` CLI](https://github.com/mkusaka/it2), enable Python API in iTerm2 Settings > General > Magic
- Not supported in: VS Code integrated terminal, Windows Terminal, Ghostty
- Note: `tmux -CC` in iTerm2 is the suggested entrypoint for tmux on macOS

## Team Configuration File

Stored at `~/.claude/teams/{team-name}/config.json`:

```json
{
  "name": "my-project",
  "description": "Working on feature X",
  "leadAgentId": "team-lead@my-project",
  "createdAt": 1706000000000,
  "members": [
    {
      "agentId": "worker-1@my-project",
      "name": "worker-1",
      "agentType": "general-purpose",
      "color": "#4A90D9",
      "model": "sonnet",
      "prompt": "...",
      "planModeRequired": false,
      "backendType": "in-process",
      "tmuxPaneId": null
    }
  ]
}
```

## Task File Structure

Stored at `~/.claude/tasks/{team-name}/{id}.json`:

```json
{
  "id": "1",
  "subject": "Review authentication module",
  "description": "...",
  "status": "in_progress",
  "owner": "security-reviewer",
  "activeForm": "Reviewing auth module...",
  "blockedBy": [],
  "blocks": ["3"],
  "createdAt": 1706000000000,
  "updatedAt": 1706000001000
}
```

## TeammateIdle Hook

Fires when a teammate finishes its turn and is about to go idle. Use to enforce quality gates.

### Configuration

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/check-idle.sh"
          }
        ]
      }
    ]
  }
}
```

### Input (stdin JSON)

```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../session.jsonl",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "TeammateIdle",
  "teammate_name": "researcher",
  "team_name": "my-project"
}
```

### Behavior

- Exit code 0: Allow teammate to go idle
- Exit code 2: Send stderr as feedback, keep teammate working
- Does NOT support matchers (fires on every occurrence)
- Does NOT support prompt-based or agent-based hooks

### Example: Require Build Artifact

```bash
#!/bin/bash
if [ ! -f "./dist/output.js" ]; then
  echo "Build artifact missing. Run the build before stopping." >&2
  exit 2
fi
exit 0
```

## TaskCompleted Hook

Fires when a task is marked as completed (via TaskUpdate or when a teammate finishes with in-progress tasks).

### Configuration

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/check-completion.sh"
          }
        ]
      }
    ]
  }
}
```

### Input (stdin JSON)

```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../session.jsonl",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "TaskCompleted",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "my-project"
}
```

### Behavior

- Exit code 0: Allow task completion
- Exit code 2: Prevent completion, send stderr as feedback
- Does NOT support matchers (fires on every occurrence)

### Example: Require Tests to Pass

```bash
#!/bin/bash
INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject')

if ! npm test 2>&1; then
  echo "Tests not passing. Fix failing tests before completing: $TASK_SUBJECT" >&2
  exit 2
fi
exit 0
```

## Message Types

Communication between teammates uses these message types:

| Type | Purpose | Typical Sender |
|:-----|:--------|:---------------|
| `message` | Direct peer-to-peer | Any teammate |
| `broadcast` | Send to all teammates | Lead |
| `shutdown_request` | Initiate exit | Lead |
| `shutdown_approved` | Confirm termination | Teammate |
| `shutdown_response` | Response to shutdown | Teammate |
| `idle_notification` | Report going idle | Teammate |
| `task_completed` | Notify of completion | Teammate |
| `plan_approval_request` | Request strategy review | Teammate |
| `plan_approval_response` | Approve/reject plan | Lead |
| `join_request` | Request team membership | Potential member |
| `permission_request` | Request tool auth | Teammate |

## Permissions

- Teammates start with the lead's permission settings
- If lead uses `--dangerously-skip-permissions`, all teammates do too
- Individual teammate modes can be changed after spawning
- Per-teammate permission modes cannot be set at spawn time

## Context Loading for Teammates

Teammates load the same project context as a regular session:
- CLAUDE.md files from their working directory
- MCP servers
- Skills
- The spawn prompt from the lead

The lead's conversation history does NOT carry over.

## Token Usage

Agent teams use significantly more tokens than solo sessions:
- Solo session: ~200k tokens
- Three subagents: ~440k tokens
- Three-person team: ~800k tokens

Approximate cost: ~7x standard session when teammates run in plan mode.

## Known Issues

- [tmux pane-base-index non-zero causes failures](https://github.com/anthropics/claude-code/issues/23527)
- [tmux split panes open but teammates disconnected](https://github.com/anthropics/claude-code/issues/24771)
- [iTerm2 split panes not created despite prerequisites](https://github.com/anthropics/claude-code/issues/24292)

## Sources

- [Official Docs: Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Official Docs: Hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code v2.1.33 Release](https://github.com/anthropics/claude-code/releases/tag/v2.1.33)
- [Addy Osmani: Claude Code Swarms](https://addyosmani.com/blog/claude-code-agent-teams/)
- [alexop.dev: From Tasks to Swarms](https://alexop.dev/posts/from-tasks-to-swarms-agent-teams-in-claude-code/)
- [Swarm Orchestration Skill (Gist)](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
