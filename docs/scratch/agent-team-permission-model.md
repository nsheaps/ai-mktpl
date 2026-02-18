## Agent Team Permission Model

To enforce correct parallelization patterns:

- **Orchestrators** should be granted ONLY team-creation tools (TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskGet, TaskList). They coordinate via the team system, not by doing work directly.
- **Teammate agents** should be denied team-creation tools entirely. They parallelize work using background sub-agents (Task tool with `run_in_background: true`), NOT by spawning new teammate agents.

This separation ensures teammates can't accidentally create new team members, and forces them to use background sub-agents for parallel work — which keeps them responsive to messages and avoids context bloat from synchronous task execution.

## Orchestrator Launch Scripts

[Gist: run-claude-team-ephemeral.sh / run-claude-team-persistent.sh](https://gist.github.com/nsheaps/ab446da50834d239a440bad651599c28)

Two shell scripts for launching Claude Code as an agent team orchestrator, appending a system prompt that enforces the permission model above and other team coordination patterns.

- **`run-claude-team-ephemeral.sh`** — Spins teammates up and down per-task. Each task gets its own teammate instance; teammates are disposed of when done. Best for parallelizing independent, short-lived work items.
- **`run-claude-team-persistent.sh`** — Keeps teammates alive for the session. Each role has a single long-lived instance that handles multiple tasks via internal sub-agents. Best for ongoing collaboration where teammates build context over time.

Both scripts:
- Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to enable the teams feature.
- Launch with `--permission-mode=delegate` and `--dangerously-skip-permissions` so the orchestrator can freely spawn and coordinate teammates.
- Enforce that the orchestrator only coordinates — it does not perform tasks directly.
- Require teammates to do work in worktrees (unless the work must happen on main) and to use `run_in_background: true` for sub-agents.
- Encourage skill capture and agent prompt maintenance for reusable team roles.
