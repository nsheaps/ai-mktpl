---
name: claude-team
description: >
  Operational patterns and pitfalls for Claude Code agent teams.
  Covers silent failures, communication anti-patterns, reconnection,
  and coordination strategies learned from real multi-agent sessions.
---

# Working with Claude Code Agent Teams

Operational knowledge for running effective multi-agent sessions. This is not tool documentation -- assumes you already know the tools (TaskCreate, SendMessage, TeamCreate, etc.). Focus: patterns, pitfalls, and hard-won lessons.

## Silent Failures

These are the most dangerous issues because they produce NO error:

1. **SendMessage to non-existent recipients succeeds silently.** The tool returns success even if the recipient name doesn't match any active teammate. Always verify teammates exist by reading `~/.claude/teams/{team-name}/config.json` before sending messages. Default to messaging the team lead if unsure.

2. **Wrong team name creates a new empty team instead of erroring.** Claude Code doesn't validate `--team-name` against existing configs. A typo like `my-team-2026-0223` vs `my-team-20260223` silently creates a new empty context -- no task list, no teammates, no error. Always copy team names from config files.

3. **Task list appears empty after reconnection.** The task directory is `~/.claude/tasks/{team-name}/`. If the team name is wrong (see above), you're pointed at an empty directory. No error -- just empty results.

## Session Reconnection

When an orchestrator session crashes, teammates keep running in tmux. To reconnect:

1. Read the team config: `~/.claude/teams/{team-name}/config.json`
2. Extract: `leadSessionId`, lead member `name`, and the team `name`
3. Reconnect with ALL parameters matching exactly:
   ```bash
   CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude \
     --resume {leadSessionId} \
     --team-name {exact-team-name} \
     --agent-name {exact-agent-name} \
     --dangerously-skip-permissions
   ```
4. Verify: Run `TaskList` (should show existing tasks), send a test message to a teammate

Common mistakes:

- Launching without `--resume` starts a fresh session with no history
- Using `--agent-name main` instead of the actual lead name from config (e.g., `team-lead`)
- Teammate processes die if the tmux session itself crashed -- they must be re-spawned (context lost)

Reference: For the full reconnection procedure with a helper script, see [Session Reconnection Research](https://github.com/nsheaps/agent-team/blob/main/docs/research/session-reconnection.md)

## Communication Patterns

**Broadcasts are expensive.** Each broadcast sends one message per teammate. With 7 teammates, that's 7x context consumption. Use direct messages for most communication. Reserve broadcasts for critical blocking issues only.

**Idle is normal, not broken.** Teammates go idle after every turn -- this is the expected behavior. An idle teammate is waiting for input, not stuck. Sending a message to an idle teammate wakes them up.

**Save reports to files, not messages.** Messages are ephemeral and consume context. Large reports should be saved to `.claude/tmp/` (NOT `/tmp/`) with a summary message containing the file path.

**Verify before sending.** Before messaging a teammate, confirm they exist in the team config. Wrong names silently drop messages into orphaned inbox files that nobody reads.

## Coordination Anti-Patterns

1. **Guess-then-broadcast**: Don't guess at a technical solution and broadcast it to the team. Wrong guesses waste context across ALL agents. Instead: delegate research to the appropriate role, verify the answer, THEN share.

2. **Orchestrator bottleneck**: Teammates can and should message each other directly for peer coordination. Don't route everything through the orchestrator -- it creates a bottleneck and wastes the orchestrator's context.

3. **Over-engineering team structure**: Start with fewer roles and add as needed. Not every session needs 8 agents. Context cost scales linearly with team size.

## File Placement in Teams

All teammates share the filesystem. Use these conventions:

- `.claude/tmp/` -- Working files shared between teammates (NOT `/tmp/`)
- `docs/research/` -- Research findings (permanent)
- `docs/specs/` -- Specifications (permanent)
- `.claude/plans/` -- Implementation plans

Completed work never goes to `.claude/tmp/` -- that's for intermediate/disposable artifacts only.

## Git Workflow with Teams

Multiple teammates may work on different branches simultaneously. Use git worktrees to avoid conflicts:

- Each teammate works in its own worktree
- Never have two teammates on the same branch
- Use git-spice (`gs`) for stacked branch management when PRs depend on each other
- Run `bun run fmt` (or equivalent) before pushing -- lint failures block the whole team

## References

- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [Session Reconnection Research](https://github.com/nsheaps/agent-team/blob/main/docs/research/session-reconnection.md)
- [GitHub: agent-team repo](https://github.com/nsheaps/agent-team)
