---
name: subagent
description: Launch an independent Claude sub-agent in a tmux session
argument-hint: "<task description> [--name NAME] [--readonly] [--no-bash]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*), Bash(tmux*), Bash(source*), Read, Write, Glob
---

# Sub-Agent Command

Launch an independent Claude sub-agent to work on a task in parallel.

## Usage

```
/subagent <task description>
/subagent <task description> --name <session-name>
/subagent <task description> --readonly
/subagent <task description> --no-bash
/subagent --list
/subagent --status <session-name>
/subagent --output <session-name>
/subagent --kill <session-name>
```

## Arguments

- `<task description>`: The task for the sub-agent to perform
- `--name NAME`: Custom session name (default: auto-generated)
- `--readonly`: Launch with read-only permissions (no Write, Edit, Bash)
- `--no-bash`: Launch without Bash access
- `--list`: List all active sub-agent sessions
- `--status NAME`: Get status of a session
- `--output NAME`: Get recent output from a session
- `--kill NAME`: Kill a session

## Behavior

When this command is invoked, you should:

### For Launching (no special flags like --list, --status, etc.)

1. **Parse the task description** from the arguments
2. **Determine restrictions** based on flags (--readonly, --no-bash)
3. **Generate a session name** if not provided (use task keywords)
4. **Launch the sub-agent** using the launch script:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "<session-name>" \
  --prompt "<task description>" \
  [--denied-tools "Write,Edit,Bash"] \  # if --readonly
  [--denied-tools "Bash"] \              # if --no-bash
```

5. **Report the session name** to the user
6. **Explain how to monitor** the session

### For Management Commands

- `--list`: Run `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_list`
- `--status NAME`: Run `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_status NAME`
- `--output NAME`: Run `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_output NAME 50`
- `--kill NAME`: Run `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_kill NAME`

## Examples

### Basic Task Delegation

```
User: /subagent Update all the JSDoc comments in src/utils/
```

You should:

1. Launch: `${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh --name "jsdoc-update" --prompt "Update all the JSDoc comments in src/utils/"`
2. Report: "Launched sub-agent 'jsdoc-update' to update JSDoc comments. An iTerm tab should open with the session. You can monitor with: `/subagent --output jsdoc-update`"

### Read-Only Code Review

```
User: /subagent Review src/api/ for security issues --readonly
```

You should:

1. Launch with restrictions:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "security-review" \
  --denied-tools "Write,Edit,Bash" \
  --prompt "Review src/api/ for security issues and create a detailed report"
```

2. Report: "Launched read-only sub-agent 'security-review'. It can read and analyze but cannot modify files."

### Managing Sessions

```
User: /subagent --list
```

Run: `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_list`

```
User: /subagent --output security-review
```

Run: `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_output security-review 50`

```
User: /subagent --kill security-review
```

Run: `source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh && subagent_kill security-review`

## Advanced Usage

For more complex configurations, use the launch script directly or create a config file:

```bash
# Custom configuration
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "complex-task" \
  --work-dir /path/to/project \
  --allowed-tools "Read,Write,Edit,Glob,Grep" \
  --plugins "/path/to/plugin1,/path/to/plugin2" \
  --prompt "Complete the task described in task.md"
```

Or with a JSON config file:

```json
{
  "name": "complex-task",
  "workDir": "/path/to/project",
  "prompt": "Your detailed task here",
  "allowedTools": "Read,Write,Edit",
  "deniedTools": "Bash"
}
```

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh --config task-config.json
```

## Notes

- Sub-agents run in isolated tmux sessions
- Each sub-agent has its own configuration workspace in `/tmp/claude-subagent/<name>/`
- The sub-agent can access the original project directory
- On macOS, an iTerm tab opens automatically attached to the session
- Use `tmux attach -t <name>` to attach manually
- Sub-agents inherit your project's `.claude/` configuration
