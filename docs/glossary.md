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

## Drilldown Skill

**Definition:** A basic skill used as an index for finding other skills. Used when you want a skill to be recallable by a generic concept (e.g. "format a message") but execution to be specific by output mechanism (e.g. format-for-discord, format-for-github, format-for-slack each behaving differently).

**Relationship to "Drill-Down Documentation":** Both share the "drill from generic to specific" pattern, but the documentation pattern is for human readers navigating reference docs, while the skill pattern is for agents looking up the right execution path at runtime.

**Structure:**

A drilldown skill's `SKILL.md` typically:
- Has a generic name (e.g. `message-formatting`)
- Lists or auto-discovers child skills (e.g. via `!`bash`` directory listing)
- @-references shared excerpts on how to consume drilldown skills
- Does NOT contain the per-platform/per-mechanism execution details — those live in supplementary skills it points to

**Example:**

```
agentic-behavior/skills/
├── message-formatting/SKILL.md         # drilldown — generic concept
├── message-formatting-discord/SKILL.md # supplementary — Discord-specific
├── message-formatting-github/SKILL.md  # supplementary — GitHub-specific
└── message-formatting-slack/SKILL.md   # supplementary — Slack-specific
```

**See also:** Supplementary Skill, Supplementary Documentation.

---

## Supplementary Skill

**Definition:** A document in the exact same format as a skill (with frontmatter and `SKILL.md` body), referenced by other skills or drilldown skills, that should be executed the same way as a skill (loaded via `Skill(...)`).

**Distinction from a regular skill:** Supplementary skills are typically not surfaced to the agent's auto-listing of available skills — they're invoked from a parent (drilldown) skill rather than directly. The visibility mechanism (frontmatter toggle vs. directory placement) is documented separately — see the relevant research note.

**Example:** `message-formatting-discord` is a supplementary skill that the `message-formatting` drilldown skill points to. The agent doesn't directly choose `message-formatting-discord` — it invokes the drilldown, which then routes to the right supplementary based on input.

**See also:** Drilldown Skill, Supplementary Documentation.

---

## Supplementary Documentation

**Definition:** A document referenced by a skill (or by another doc) but NOT `@`-referenced (i.e. not auto-loaded). The agent CHOOSES whether to read the additional info based on whether the current task requires it.

**Distinction from regular documentation:** Regular docs that are `@`-referenced get pulled into context automatically. Supplementary documentation requires an explicit `Read` action by the agent — costs more time but doesn't bloat context for tasks that don't need it.

**When to use:** For deep-dive references, edge-case workarounds, troubleshooting guides, or other content that's only relevant to a subset of the agent's work and would otherwise consume context unproductively.

**See also:** Drilldown Skill, Supplementary Skill.

---

## Doc Excerpt

**Definition:** A small reusable chunk of documentation that's included via reference (e.g. `@-reference` or include-syntax) into multiple host documents. Excerpts let multiple docs share canonical wording for the same concept without duplicating it.

**Naming choice (excerpt vs. partial):** This codebase uses **"excerpt"** consistently. "Partial" is a common alternative (especially in templating systems), but excerpt better conveys "a piece extracted from a larger thing for inclusion elsewhere" — partials sometimes imply a fragment that's incomplete on its own. Apply "excerpt" across all skill/rule/doc cross-references going forward.

**Example use:** A drilldown skill `@-references` an excerpt about how to use drilldown skills, so each drilldown skill stays terse but the explanation lives in one place.

**See also:** Supplementary Documentation.

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

---

## Agent Trigger Context

**Definition:** The information available to an AI agent at the moment of invocation that helps it understand what to do and why.

**Components:**

- **Event metadata**: What triggered the agent (PR comment, issue, cron, manual)
- **Source context**: The full content of the trigger (PR diff, issue body, commit message)
- **Environment context**: Repository state, branch, available tools
- **Historical context**: Previous interactions, related issues, conversation history

**Problem:** In GitHub Actions, agents often receive only the trigger event without surrounding context, requiring additional API calls to understand the situation.

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

---

## Task (capital T)

**Definition:** A Claude Code Task created via `TaskCreate`, tracked with `TaskUpdate`, `TaskList`, and `TaskGet`. Used to break down work, track progress, and give the user visibility into what you're doing.

**Distinction:** Not to be confused with a generic work item, ticket, or to-do. Capital T = `Task`-tool-managed Claude Code task. Lowercase t = generic task/work item.

**Reference:** [Claude Code Tools Reference](https://code.claude.com/docs/en/tools-reference)

---
