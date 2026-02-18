# ai-mktpl

A curated collection of plugins, rules, agents, and commands for [Claude Code](https://code.claude.com).

## What is this?

This repo is a **plugin marketplace** for Claude Code — a central place for reusable plugins, organization-wide rules, custom agents, and slash commands. It serves two purposes:

1. **Plugin distribution**: 27 plugins covering git automation, safety evaluation, status lines, task management, and more
2. **Organization-wide AI configuration**: Rules, agents, and commands that get synced to `~/.claude/` for consistent behavior across all projects

## Installation

### Installing a plugin

Add the plugin path to your project's `.claude.json`:

```json
{
  "plugins": ["/path/to/this/repo/plugins/scm-utils", "/path/to/this/repo/plugins/statusline"]
}
```

### Installing organization-wide rules

The `.ai/rules/` directory is synced to `~/.claude/rules/` via automation (symlinks). This makes rules available across all projects without per-project configuration.

## Available Plugins

### Git & Source Control

| Plugin                                         | Description                                                         |
| :--------------------------------------------- | :------------------------------------------------------------------ |
| **[commit-command](./plugins/commit-command)** | `/commit` — AI-generated commit messages matching your repo's style |
| **[commit-skill](./plugins/commit-skill)**     | Auto-analyze changes and create semantic commits during development |
| **[scm-utils](./plugins/scm-utils)**           | `/commit`, `/update-branch` commands + auth-user skill              |
| **[git-spice](./plugins/git-spice)**           | Manage stacked Git branches with the `gs` CLI                       |

### Safety & Evaluation

| Plugin                                                             | Description                                                        |
| :----------------------------------------------------------------- | :----------------------------------------------------------------- |
| **[safety-evaluation-prompt](./plugins/safety-evaluation-prompt)** | Pre-tool-call safety via prompt-style hooks                        |
| **[safety-evaluation-script](./plugins/safety-evaluation-script)** | Pre-tool-call safety via script-style hooks (haiku CLI)            |
| **[context-bloat-prevention](./plugins/context-bloat-prevention)** | PostToolUse + PreToolUse hooks to detect and prevent context bloat |

### Status & Monitoring

| Plugin                                             | Description                                                                |
| :------------------------------------------------- | :------------------------------------------------------------------------- |
| **[statusline](./plugins/statusline)**             | Configurable status line showing session info, project context, git status |
| **[statusline-iterm](./plugins/statusline-iterm)** | Status line with iTerm2 badge integration                                  |

### Development Workflow

| Plugin                                                                     | Description                                                     |
| :------------------------------------------------------------------------- | :-------------------------------------------------------------- |
| **[review-changes](./plugins/review-changes)**                             | `/review-changes` — detailed code review feedback               |
| **[code-simplifier](./plugins/code-simplifier)**                           | `/simplify` — refine code for clarity and maintainability       |
| **[create-command](./plugins/create-command)**                             | `/create-command` — guided slash command creation               |
| **[correct-behavior](./plugins/correct-behavior)**                         | `/correct-behavior` — fix AI behavior mistakes and update rules |
| **[product-development-and-sdlc](./plugins/product-development-and-sdlc)** | Iterative PRD writing with structured SDLC workflows            |

### Task & Session Management

| Plugin                                                     | Description                                                    |
| :--------------------------------------------------------- | :------------------------------------------------------------- |
| **[task-parallelization](./plugins/task-parallelization)** | Intelligently parallelize Task tool calls for batch operations |
| **[todo-sync](./plugins/todo-sync)**                       | Auto-sync `~/.claude/` todos to project `.claude/` directory   |
| **[self-terminate](./plugins/self-terminate)**             | Graceful SIGINT termination for agents                         |

### Agent Teams & Orchestration

| Plugin                                                     | Description                                                    |
| :--------------------------------------------------------- | :------------------------------------------------------------- |
| **[tmux-subagent](./plugins/tmux-subagent)**               | `/subagent` — launch sub-agents in tmux with custom configs    |
| **[agent-teams-skills](./.ai/plugins/agent-teams-skills)** | Reference skill for agent teams: enabling, config, hooks, tmux |

### Integrations

| Plugin                                               | Description                                                   |
| :--------------------------------------------------- | :------------------------------------------------------------ |
| **[linear-mcp-sync](./plugins/linear-mcp-sync)**     | Linear MCP with hash validation hooks for safe ticket updates |
| **[github-auth-skill](./plugins/github-auth-skill)** | GitHub device authorization flow authentication               |
| **[sync-settings](./plugins/sync-settings)**         | Sync local Claude Code settings via `syncconfig.yaml` rules   |

### Data & Utilities

| Plugin                                                 | Description                                               |
| :----------------------------------------------------- | :-------------------------------------------------------- |
| **[data-serialization](./plugins/data-serialization)** | YAML/JSON/TOON/XML conversion; TOON reduces tokens 30-60% |
| **[memory-manager](./plugins/memory-manager)**         | Auto-detect and store user preferences in CLAUDE.md       |
| **[command-help-skill](./plugins/command-help-skill)** | Help discover and execute slash commands sent as messages |
| **[skills-maintenance](./plugins/skills-maintenance)** | Maintain, update, and improve existing Claude Code skills |
| **[opengraph-image](./plugins/opengraph-image)**       | Generate OpenGraph images via html2png.dev API            |

## Organization-Wide Rules

21 behavioral rules in `.ai/rules/` covering:

- **Code quality**: DRY, KISS, YAGNI, incremental development
- **Git workflow**: PR conventions, commit hygiene, branch management
- **Task management**: Todo tracking, task planning, sub-agent delegation
- **Communication**: Speech-to-text handling, intellectual honesty, polite correction
- **Safety**: Verify before blaming, never say done prematurely, error handling

Rules are symlinked to `~/.claude/rules/` by automation and apply across all projects.

## Custom Agents

6 custom agents in `.ai/agents/`:

| Agent                         | Purpose                                             |
| :---------------------------- | :-------------------------------------------------- |
| `conversation-history-search` | Search past Claude Code conversations (haiku model) |
| `github-issue-creator`        | Create GitHub issues for bugs and work items        |
| `internet-researcher`         | Deep web research with reference gathering          |
| `research-lead`               | Lead and coordinate multi-source research           |
| `research-subagent`           | Focused research sub-agent for deep dives           |
| `ui-ux-consultant`            | Desktop UI/UX and accessibility expert              |

## Slash Commands

4 commands in `.ai/commands/`:

| Command             | Purpose                                   |
| :------------------ | :---------------------------------------- |
| `/correct-behavior` | Fix AI behavior mistakes and update rules |
| `/create-command`   | Guided slash command creation             |
| `/review-changes`   | Detailed code change review               |
| `/relentlessly-fix` | Persistent fixing until resolved          |

## Development

```bash
just lint      # Run all linters
just validate  # Validate plugin structure
just check     # Run lint + validate
just plugins   # List all plugins
```

## Contributing

To add a plugin:

1. Create a directory in `plugins/your-plugin-name/`
2. Add `.claude-plugin/plugin.json` with name, version, description
3. Add your commands, skills, hooks, or agents
4. Submit a pull request

### Plugin Structure

```
plugins/your-plugin-name/
├── .claude-plugin/
│   └── plugin.json       # Required: name, version, description
├── commands/              # Slash commands (*.md)
├── skills/                # Agent skills (*/SKILL.md)
├── hooks/                 # Lifecycle hooks
├── agents/                # Agent definitions
└── README.md              # Optional
```

## Related Projects

- [claude-team](https://github.com/nsheaps/claude-team) — CLI tool for launching agent team sessions
- [claude-utils](https://github.com/nsheaps/claude-utils) — CLI helper scripts for Claude Code (Homebrew)
- [agent-team](https://github.com/nsheaps/agent-team) — POC for provider-agnostic agent orchestration

## References

- [Claude Code Documentation](https://code.claude.com)
- [Plugin Development Guide](https://code.claude.com/docs/en/plugins)
- [Agent Skills Standard](https://agentskills.io)
- [Conventional Commits](https://www.conventionalcommits.org/)

## License

Proprietary. All rights reserved.
