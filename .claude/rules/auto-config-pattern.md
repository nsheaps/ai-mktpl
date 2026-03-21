# Auto-Config Pattern for Plugins

## Overview

Plugins should **not hardcode tool assumptions**. Instead, they should discover what tools a project uses and configure themselves accordingly. This is the **auto-config pattern**.

## How It Works

1. **No config = no action** — the plugin does nothing until configured
2. **Auto-config skill** — an agent skill that explores the project, detects relevant tools/configs, and writes a `plugins.settings.yaml` override
3. **SessionStart hook** (optional) — invokes auto-config using a fast model (haiku) on first session to auto-populate config without user intervention

## Why This Pattern

- **Portable** — works across projects with different toolchains (prettier, biome, black, etc.)
- **Explicit** — config is visible and overridable via the standard 3-tier config system
- **Safe** — no action without config means no surprises in new projects
- **Discoverable** — the auto-config skill documents what it looks for

## Implementation

### 1. Default Settings (empty/disabled)

```yaml
# my-plugin.settings.yaml
enabled: true
tool: "" # No tool configured = no action
```

### 2. Auto-Config Skill

Create a skill at `skills/auto-config/SKILL.md` that:

- Lists all config files/patterns it searches for
- Maps discovered tools to plugin settings
- Writes to `$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml`
- Verifies the tool is available (`command -v`)

### 3. SessionStart Hook (optional)

For zero-touch setup, add a SessionStart hook that:

- Checks if config already exists (skip if so)
- Uses a fast model to explore the project
- Populates config for subsequent tool calls

## Examples

- **edit-utils**: Detects prettier/biome/black and configures formatter command
- Future: linter plugins, test runner plugins, etc.
