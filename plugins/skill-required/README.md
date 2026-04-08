# skill-required

Claude Code plugin that enforces skill loading before tool use.

## How It Works

1. **PostToolUse hook on Skill**: When a skill is loaded via the Skill tool, the plugin caches the read with a timestamp and resets a tool-use counter.

2. **PreToolUse hook on all tools**: Before any tool executes, the plugin checks if a required skill was recently loaded (within the configured tool-use count). If not, the tool call is denied with an instruction to load the skill first.

## Configuration

Copy `skill-required.settings.yaml` from the plugin root to `~/.claude/settings.skill-required.yaml` (user-level) or `${project}/.claude/settings.skill-required.yaml` (project-level) and customize:

```yaml
skill-required:
  enabled: true
  skills:
    - name: "git-spice"
      required_before:
        - "Bash"
      command_pattern:
        - "gs "
        - "git-spice"
      max_tool_uses_before_reset: 10
    - name: "scm-utils:commit"
      required_before:
        - "Bash"
      command_pattern:
        - "git commit"
        - "git push"
      max_tool_uses_before_reset: 5
```

### Config Fields

| Field                                 | Description                                         | Default             |
| ------------------------------------- | --------------------------------------------------- | ------------------- |
| `enabled`                             | Enable/disable enforcement                          | `true`              |
| `skills[].name`                       | Skill name to require (colons are supported)        | required            |
| `skills[].required_before`            | Tool name(s) to gate (YAML array)                   | required            |
| `skills[].command_pattern`            | Regex patterns for Bash commands (YAML array)       | none (all commands) |
| `skills[].max_tool_uses_before_reset` | Max tool uses before skill must be reloaded         | `10`                |

> **Note:** `required_before` and `command_pattern` accept YAML arrays (preferred) or legacy pipe-separated strings for backwards compatibility.

### Environment Override

Set `CLAUDE_PLUGIN_SKILL_REQUIRED_ENABLED=false` to disable enforcement.

## Dependencies

- `jq` — for JSON processing
- `yq` — Go version ([mikefarah/yq](https://github.com/mikefarah/yq)) for YAML config parsing (declared in `mise.toml`)

## Cache

Skill read state is cached at `~/.claude/cache/plugins/skill-required/<project-slug>/`.
