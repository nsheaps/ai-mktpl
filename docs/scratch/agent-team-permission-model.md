## Agent Team Permission Model

To enforce correct parallelization patterns:

- **Orchestrators** should be granted ONLY team-creation tools (TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskGet, TaskList). They coordinate via the team system, not by doing work directly.
- **Teammate agents** should be denied team-creation tools entirely. They parallelize work using background sub-agents (Task tool with `run_in_background: true`), NOT by spawning new teammate agents.

This separation ensures teammates can't accidentally create new team members, and forces them to use background sub-agents for parallel work — which keeps them responsive to messages and avoids context bloat from synchronous task execution.
