---
name: configuring-claude-code
description: >-
  Use this skill when making changes to Claude Code configuration: settings.json,
  settings.local.json, CLAUDE.md, AGENTS.md, SKILL.md files, .claude folders,
  hooks, permissions, plugins, or environment setup. Auto-recall when configuring
  Claude Code behavior for local CLI, CI actions, or Claude Code Web sessions.
  Also covers plugin management (install, enable, disable, remove) and
  marketplace configuration.
---

# Configuring Claude Code

You are a Claude Code configuration specialist. Your role is to help users set up and manage Claude Code across all environments: local CLI, CI/CD GitHub Actions, and Claude Code Web.

## Environments

### Local CLI (`claude`)

The standard command-line interface. Configuration lives in:

- `~/.claude/settings.json` — user-level settings
- `<project>/.claude/settings.json` — project-level settings (checked into git)
- `<project>/.claude/settings.local.json` — local overrides (gitignored)

### Claude Code Web

Browser-based sessions on `code.claude.com`. Key differences:

- Ephemeral environments — tools must be installed each session
- Use `SessionStart` hooks for dependency management
- `CLAUDE_CODE_REMOTE=true` environment variable indicates a web session
- Use `CLAUDE_ENV_FILE` to persist environment variables across tool calls

### CI/CD GitHub Actions

Claude Code running in GitHub Actions workflows. Typically:

- Uses `anthropics/claude-code-action` or direct CLI invocation
- Requires `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`
- Project settings apply automatically from the repo's `.claude/` directory

## Settings Files

### Hierarchy (highest priority first)

1. `.claude/settings.local.json` — personal project overrides (gitignored)
2. `.claude/settings.json` — shared project settings (committed)
3. `~/.claude/settings.json` — user-level defaults

### Key Settings

| Key                      | Type                | Description                     |
| ------------------------ | ------------------- | ------------------------------- |
| `enabledPlugins`         | `{string: boolean}` | Plugin enable/disable map       |
| `permissions`            | `object`            | Tool permission rules           |
| `hooks`                  | `object`            | Hook definitions by event type  |
| `env`                    | `{string: string}`  | Environment variables           |
| `extraKnownMarketplaces` | `object`            | Shared marketplace declarations |

### Example Project Settings

```json
{
  "enabledPlugins": {
    "plugin-dev@claude-plugins-official": true,
    "common-sense@ai-mktpl": true,
    "mise@ai-mktpl": true
  },
  "extraKnownMarketplaces": {
    "ai-mktpl": {
      "source": { "source": "github", "repo": "nsheaps/ai-mktpl" }
    }
  },
  "permissions": {
    "allow": ["Bash(git:*)"],
    "deny": []
  }
}
```

## Plugin Management

See the full reference at: [Plugin Management Guide](./plugin-management.md)

### Quick Reference

```bash
# List installed plugins
claude plugins list
claude plugins list --json

# Browse available plugins (requires --json)
claude plugins list --available --json

# Install (default scope: user)
claude plugins install <name>@<marketplace>
claude plugins install <name>@<marketplace> --scope project

# Enable/disable (keeps plugin installed)
claude plugins disable <plugin-id>
claude plugins enable <plugin-id>

# Uninstall (removes from settings entirely)
claude plugins uninstall <plugin-id> --scope <scope>

# Marketplace management
claude plugins marketplace list
claude plugins marketplace add <github-org/repo>
claude plugins marketplace update
```

### Scopes

| Scope     | Settings File                 | Use When                                |
| --------- | ----------------------------- | --------------------------------------- |
| `user`    | `~/.claude/settings.json`     | Personal plugins for all projects       |
| `project` | `.claude/settings.json`       | Team-shared plugins (committed to git)  |
| `local`   | `.claude/settings.local.json` | Personal project overrides (gitignored) |

### Plugin ID Format

Always `<plugin-name>@<marketplace-name>`, e.g., `common-sense@ai-mktpl`.

## Rules and Memory

### CLAUDE.md Files

| File                                                   | Scope    | Committed? |
| ------------------------------------------------------ | -------- | ---------- |
| `~/.claude/CLAUDE.md`                                  | User     | N/A        |
| `<project>/CLAUDE.md` or `<project>/.claude/CLAUDE.md` | Project  | Yes        |
| `<project>/CLAUDE.local.md`                            | Personal | No         |

### Rules Directory

Modular rules can be placed in:

- `~/.claude/rules/*.md` — user rules
- `<project>/.claude/rules/*.md` — project rules

### AGENTS.md

For multi-agent setups, `AGENTS.md` files configure sub-agent behavior with:

- Agent-specific instructions
- Tool restrictions
- Context management rules

## Hooks

Hooks run shell commands in response to Claude Code lifecycle events.

### Event Types

| Event              | When It Fires               |
| ------------------ | --------------------------- |
| `SessionStart`     | Claude Code session begins  |
| `PreToolUse`       | Before a tool is executed   |
| `PostToolUse`      | After a tool completes      |
| `UserPromptSubmit` | When user sends a message   |
| `TaskCompleted`    | When Claude finishes a task |
| `Stop`             | When Claude stops           |

### Hook Definition (in settings.json)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/session-start/setup.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Plugin Hooks

Plugins define hooks in `hooks/hooks.json`, referenced from `plugin.json`:

```json
{ "hooks": "./hooks/hooks.json" }
```

## Skills

Skills extend Claude's capabilities and are user-invocable as `/skill-name`.

### Creating a Skill

```
plugins/<name>/skills/<skill-name>/
└── SKILL.md
```

### SKILL.md Frontmatter

```yaml
---
name: my-skill
description: When to auto-invoke this skill
argument-hint: "<what arguments to pass>"
allowed-tools: Read, Write, Bash(git:*)
---
```

### Key Fields

- `name` — kebab-case, matches the directory name
- `description` — triggers auto-invocation when Claude detects matching context
- `argument-hint` — shown in `/` command completion
- `allowed-tools` — restricts which tools the skill can use
- `disable-model-invocation` — set `true` to only allow manual `/skill-name` invocation

## Web Session Setup

For Claude Code Web, use a `SessionStart` hook to install dependencies:

```bash
#!/usr/bin/env bash
# .claude/hooks/session-start/setup.sh

# Only run in web sessions
if [ "${CLAUDE_CODE_REMOTE}" != "true" ]; then
  exit 0
fi

# Install mise for tool management
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
  eval "$(~/.local/bin/mise activate bash)"
  echo 'eval "$(~/.local/bin/mise activate bash)"' >> "$CLAUDE_ENV_FILE"
fi

# Install tools from mise.toml
mise trust
mise install -y
```

## When to Use This Skill

- Setting up a new project for Claude Code
- Adding or configuring plugins
- Creating hooks for automated behavior
- Writing rules or memory files
- Configuring permissions
- Setting up CI/CD integration
- Troubleshooting configuration issues
- Moving settings between scopes (user → project, etc.)
