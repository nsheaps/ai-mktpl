---
name: agent-teams
description: Comprehensive reference for Claude Code agent teams. Use when creating agent teams, spawning teammates, configuring teammate mode (tmux/in-process), setting up multi-agent orchestration, enabling agent teams, starting a swarm, or working with team hooks (TeammateIdle, TaskCompleted).
---

# Claude Code Agent Teams

Agent teams orchestrate multiple independent Claude Code sessions working in parallel. One session acts as the "lead" that spawns and coordinates "teammates" -- each a full Claude Code instance with its own context window.

**Status**: Experimental (released February 2026 with Opus 4.6)

## Enabling Agent Teams

Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `1` in environment or settings.json:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Or via the `claude-team` / `ct` helper scripts from claude-utils:

```bash
claude-team                    # Interactive mode picker
ct --mode tmux                 # Direct tmux mode
```

## Teammate Display Modes

| Mode | Description | Requirements |
|:-----|:------------|:-------------|
| `auto` | Auto-detect best backend | Default |
| `in-process` | Hidden sessions, Shift+Up/Down to switch | None |
| `tmux` | Visible split panes, survives leader exit | tmux or iTerm2 + `it2` CLI |

Configure in `settings.json` or per-session:

```json
{ "teammateMode": "in-process" }
```

```bash
claude --teammate-mode tmux
```

### Gotcha: Use settings.json, Not Just the CLI Flag

**Always set `teammateMode` in `settings.json`** rather than relying solely on `--teammate-mode`:

```json
{ "teammateMode": "tmux" }
```

The `--teammate-mode` CLI flag is a hidden flag (not shown in `--help`) that sets a per-session "snapshot" of the mode. However, internally Claude Code's BackendRegistry may reset its cached backend detection between teammate spawns via `resetBackendDetection`. When this happens without `teammateMode` in settings.json, re-detection can trigger the **iTerm2 Split Pane Setup dialog** on every spawn — prompting you to "Install it2 now", "Use tmux instead", or "Cancel" repeatedly.

Setting `teammateMode: "tmux"` in settings.json causes the BackendRegistry to skip iTerm2 detection entirely ("User prefers tmux over iTerm2"), preventing the prompt. The CLI flag alone does not reliably signal this preference to the backend selection logic.

**Note**: Spawned teammates do NOT receive `--teammate-mode` in their spawn command — they are non-interactive sessions that use in-process mode internally by design. The `teammateMode` setting only affects the **lead session's** backend selection for creating panes.

Sources: Binary analysis of Claude Code v2.1.39, [GitHub #24301](https://github.com/anthropics/claude-code/issues/24301)

### tmux -CC and iTerm2 Integration

The `"tmux"` setting uses tmux as the backend in **all cases** -- including when iTerm2 is the terminal. The difference is presentation:

| Scenario | What Happens |
|:---------|:-------------|
| Inside tmux session | Standard tmux split panes (green status bar, prefix keys) |
| iTerm2 (not in tmux) | `tmux -CC` control mode -- teammates appear as native iTerm2 tabs/panes |
| Other terminal | Falls back to in-process mode |

**tmux -CC (control mode)** is a text-based protocol where tmux sends structured messages instead of rendering a terminal UI. iTerm2 intercepts these and renders native macOS windows/tabs. Benefits over raw tmux:
- Native trackpad scrolling, Cmd+C/V, Cmd+F search
- Click-to-interact with teammate panes
- No tmux keybinding learning curve
- Session persistence (tmux keeps running if iTerm2 quits; reconnect with `tmux -CC attach`)

The `claude-team` helper auto-launches `tmux -CC` when tmux mode is selected outside a tmux session, so users don't need to manually start tmux first.

Sources: [tmux Control Mode Wiki](https://github.com/tmux/tmux/wiki/Control-Mode), [iTerm2 tmux Integration](https://iterm2.com/documentation-tmux-integration.html), [Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)

## Creating a Team

Describe the task and team structure in natural language. Claude will propose the team composition and wait for approval before proceeding.

## Keyboard Controls

| Control | Function |
|:--------|:---------|
| Shift+Up/Down | Cycle through teammates (in-process) |
| Ctrl+T | Toggle task list |
| Ctrl+O | Toggle verbose transcript (shows detailed tool usage and execution) |
| Shift+Tab | Toggle delegate mode (lead coordination only) |
| Escape | Interrupt teammate's turn |

## Core Architecture

Seven internal primitives power the system:

1. **TeamCreate** -- Initialize team namespace and config
2. **TaskCreate** -- Define discrete work units
3. **TaskUpdate** -- Claim tasks, update status
4. **TaskList** -- List available work for self-claiming
5. **Task (with team_name)** -- Spawn a teammate session
6. **SendMessage** -- Peer-to-peer communication between any teammates
7. **TeamDelete** -- Clean up team resources

## Communication

Teammates communicate via a shared mailbox system with direct peer-to-peer messaging. Message types include: `message`, `broadcast`, `shutdown_request/response`, `idle_notification`, `task_completed`, `plan_approval_request/response`.

The shared task list supports dependency tracking with automatic unblocking. File locking prevents race conditions on task claiming.

## Environment Variables (Set Automatically for Teammates)

| Variable | Description |
|:---------|:------------|
| `CLAUDE_CODE_TEAM_NAME` | Team name |
| `CLAUDE_CODE_AGENT_ID` | Unique agent ID |
| `CLAUDE_CODE_AGENT_NAME` | Display name |
| `CLAUDE_CODE_AGENT_TYPE` | Agent type |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | Whether plan approval is required |
| `CLAUDE_CODE_PARENT_SESSION_ID` | Parent session ID |

## File Storage

```
~/.claude/teams/{team-name}/
  config.json            # Team metadata, members array
  inboxes/{agent}.json   # Per-agent message inbox

~/.claude/tasks/{team-name}/
  1.json, 2.json, ...    # Individual task files
```

## Team Hooks

### TeammateIdle

Fires when a teammate finishes its turn. Exit code 2 sends stderr as feedback and keeps the teammate working. Does not support matchers or prompt-based hooks.

### TaskCompleted

Fires when a task is marked complete (via TaskUpdate or when a teammate finishes with in-progress tasks). Exit code 2 prevents completion and sends stderr as feedback.

For working examples and hook configuration patterns, consult `references/hooks-and-config.md`.

## Best Practices

1. **Give teammates enough context** in spawn prompts -- conversation history does not carry over
2. **Size 5-6 tasks per teammate** -- the optimal sweet spot
3. **Avoid same-file edits** -- break work so each teammate owns different files
4. **Use delegate mode** (Shift+Tab) for complex orchestration
5. **Require plan approval** for risky or architectural work
6. **Use meaningful agent names** -- `security-reviewer` beats `worker-1`
7. **Pre-approve common operations** to reduce permission prompt interruptions

## When to Use vs Avoid

**Strong use cases**: Research/review, independent modules, debugging with competing hypotheses, cross-layer coordination, parallel code review.

**Avoid for**: Sequential dependent tasks, same-file edits, simple/routine tasks, cost-sensitive work (~7x token usage).

## Limitations

- No session resumption for in-process teammates
- One team per session; clean up before starting a new one
- No nested teams (teammates cannot spawn their own teams)
- Lead is fixed for the session's lifetime
- Split panes require tmux or iTerm2 (`claude-team` auto-launches `tmux -CC` if needed)
- Teammates start with lead's permission mode

## Additional Resources

### Reference Files

For detailed configuration, hooks, and advanced patterns:
- **`references/hooks-and-config.md`** -- Hook examples, settings.json config, spawn backends, env vars

### Official Documentation

- [Agent Teams](https://code.claude.com/docs/en/agent-teams) -- Complete official reference
- [Hooks Reference](https://code.claude.com/docs/en/hooks) -- TeammateIdle, TaskCompleted hooks
