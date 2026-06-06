# One-Shot Execution

**Definition:** An agent or job that runs once to completion without maintaining persistent state or waiting for further input. Receives input, performs work, returns output, terminates.

**Characteristics:**

- No interactive prompts during execution
- Deterministic start and end points
- Suitable for CI/CD pipelines and scheduled jobs
- Context provided entirely at invocation time

**Contrasted with:**

- **Interactive sessions**: Maintain dialogue, wait for user input
- **Long-running agents**: Persist across multiple invocations

**Examples:**

- GitHub Actions jobs using `claude-code-action`
- Kubernetes Jobs running AI analysis
- Cron-triggered code review bots
