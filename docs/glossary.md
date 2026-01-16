# Glossary

Definitions of terms used throughout this repository and in AI/agent development contexts.

---

## Drill-Down Documentation

**Definition:** A documentation pattern where high-level overviews link to progressively more detailed documents, allowing readers to "drill down" to the specificity they need.

**Structure:**

```
README.md                    # High-level overview, quick start
├── docs/usage.md            # Detailed usage patterns
├── docs/configuration.md    # All configuration options
└── docs/troubleshooting.md  # Common issues and solutions
```

**Benefits:**

- Keeps top-level docs concise and scannable
- Allows deep-dive without cluttering main documentation
- Supports different reader needs (quick reference vs. comprehensive)

**Example in this repo:** The `code-simplifier` plugin uses drill-down docs:

- `README.md` - Quick installation and usage
- `commands/simplify.md` - Command implementation with dependency flow
- `skills/code-simplifier/SKILL.md` - Full troubleshooting and CLI reference

---

## One-Shot Execution

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

**See also:** [One-Shot Executions as Jobs](research/one-shot-executions-as-jobs.md)

---

## Agent Trigger Context

**Definition:** The information available to an AI agent at the moment of invocation that helps it understand what to do and why.

**Components:**

- **Event metadata**: What triggered the agent (PR comment, issue, cron, manual)
- **Source context**: The full content of the trigger (PR diff, issue body, commit message)
- **Environment context**: Repository state, branch, available tools
- **Historical context**: Previous interactions, related issues, conversation history

**Problem:** In GitHub Actions, agents often receive only the trigger event without surrounding context, requiring additional API calls to understand the situation.

**See also:** [Agentic Workflow Context Patterns](research/agentic-workflow-context.md)

---

## Plugin Wrapper Pattern

**Definition:** A plugin that provides a simplified interface to an existing agent or tool, handling dependency management, configuration, and user guidance.

**Structure:**

```
wrapper-plugin/
├── .claude-plugin/plugin.json  # Declares wrapper, not new agent
├── commands/command.md         # User-facing command
├── skills/*/SKILL.md           # Usage documentation
└── README.md                   # Installation guide
```

**Benefits:**

- Improves discoverability of existing capabilities
- Centralizes dependency management logic
- Provides consistent UX across different underlying agents
- Reduces duplication of agent code

**Example:** The `code-simplifier` plugin wraps `pr-review-toolkit:code-simplifier`.

---

## MCP (Model Context Protocol)

**Definition:** A protocol for AI models to interact with external tools and services in a standardized way.

**Key Concepts:**

- **MCP Server**: A service that exposes tools via the protocol
- **MCP Tool**: A specific capability provided by a server (e.g., `mcp__github__create_issue`)
- **MCP Configuration**: JSON specifying which servers are available and how to invoke them

**Permission Model:**

- Tools must be explicitly allowed via `permissions.allow` in settings
- `enableAllProjectMcpServers` makes project-defined servers discoverable
- CLI args (`--mcp-config`) specify servers but don't grant permissions

**See also:** [Claude Code Action MCP Configuration](research/claude-code-action-mcp-configuration.md)

---

## Settings Scope

**Definition:** The level at which a configuration option applies, determining visibility and override behavior.

**Claude Code Scopes:**

| Scope   | Location                      | Visibility                 | Git Tracked     |
| ------- | ----------------------------- | -------------------------- | --------------- |
| User    | `~/.claude/settings.json`     | All projects for user      | No              |
| Project | `.claude/settings.json`       | All users of project       | Yes             |
| Local   | `.claude/settings.local.json` | Current user, this project | No (gitignored) |

**Precedence (highest to lowest):**

1. Managed settings (system-level)
2. Command line arguments
3. Local project settings
4. Shared project settings
5. User settings

**See also:** [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)

---

## Permission Mode

**Definition:** How Claude Code handles tool invocation requests when no explicit allow/deny rule matches.

**Modes:**

| Mode          | Behavior                                    | Use Case                |
| ------------- | ------------------------------------------- | ----------------------- |
| `default`     | Prompts user for permission                 | Interactive development |
| `allowlist`   | Auto-denies unless explicitly allowed       | CI/CD, automation       |
| `acceptEdits` | Auto-accepts file edits, prompts for others | Trusted development     |

**CI/CD Consideration:** Always use `allowlist` mode in GitHub Actions since prompts cannot be answered.

---

## Skill vs Command

**Definition (Skill):** Documentation that Claude reads to understand how to perform a task. Triggered by natural language matching the skill's description.

**Definition (Command):** A slash-prefixed instruction (`/simplify`) that invokes a specific workflow. User-initiated.

**Key Differences:**

| Aspect    | Skill                     | Command             |
| --------- | ------------------------- | ------------------- |
| Trigger   | Natural language          | Explicit `/command` |
| Discovery | Automatic via description | Listed in `/help`   |
| Location  | `skills/*/SKILL.md`       | `commands/*.md`     |
| Control   | Contextual                | Explicit            |

**Relationship:** Commands often reference skills for detailed documentation, while skills provide the "how" and commands provide the "what".
