---
name: tmux-subagent
description: Launch and manage independent Claude sub-agents in tmux sessions with isolated configurations, custom tool permissions, and real-time monitoring capabilities
allowed-tools: Bash(tmux*), Bash(*subagent*), Bash(osascript*), Read, Glob
---

# Tmux Sub-Agent Skill

Launch independent Claude sub-agents that run in parallel tmux sessions with their own configurations, tool permissions, and plugin environments.

## When to Use This Skill

Use tmux sub-agents when you need:

- **Parallel work**: Multiple Claude instances working on different aspects of a task
- **Isolation**: Sub-agents with restricted tools (e.g., read-only, no Bash)
- **Delegation**: Hand off a well-defined task to run autonomously
- **Plugin isolation**: Test plugins without affecting your current session
- **Long-running tasks**: Background tasks that continue while you work

## How It Works

1. **Workspace Creation**: Creates a temporary workspace at `/tmp/claude-subagent/<session-name>/`
2. **Config Inheritance**: Copies your project's `.claude/` configuration
3. **Permission Setup**: Adds the original project as an allowed directory
4. **Tool Configuration**: Applies your specified tool restrictions/additions
5. **Plugin Installation**: Installs additional plugins (in temp workspace only)
6. **Session Launch**: Starts Claude in a tmux session
7. **iTerm Integration**: Opens an iTerm tab attached to the session (macOS)

## Launching a Sub-Agent

### Basic Launch

```bash
# Launch with a prompt
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "refactor-task" \
  --prompt "Refactor the authentication module in src/auth/ to use async/await"

# Launch with prompt from file
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "docs-update" \
  --prompt-file /path/to/task-description.md
```

### With Tool Restrictions

```bash
# Read-only sub-agent (no Write, Edit, or Bash)
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "code-review" \
  --denied-tools "Write,Edit,Bash" \
  --prompt "Review src/api/ for security issues and report findings"

# Limited tools
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "analyzer" \
  --allowed-tools "Read,Grep,Glob" \
  --prompt "Analyze the codebase structure and create a report"
```

### With Custom Configuration

```bash
# Different working directory
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "other-project" \
  --work-dir /path/to/other/project \
  --prompt "Update dependencies in this project"

# With additional plugins
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "with-plugins" \
  --plugins "/path/to/plugin1,/path/to/plugin2" \
  --prompt "Use the custom plugins to complete this task"

# Skip permission prompts (dangerous!)
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "autonomous" \
  --permission-mode dontAsk \
  --prompt "Complete this task without asking for permissions"
```

### Using a Config File

```json
{
  "name": "complex-task",
  "workDir": "/path/to/project",
  "prompt": "Implement the feature described in docs/spec.md",
  "allowedTools": "Read,Write,Edit,Glob,Grep",
  "deniedTools": "Bash",
  "plugins": "/path/to/plugin1,/path/to/plugin2",
  "permissionMode": "allowedTools"
}
```

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh --config task-config.json
```

## Monitoring Sub-Agents

### Using the Helper Script

```bash
# Source helpers for function access
source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh

# List all active sub-agent sessions
subagent_list

# Get session status
subagent_status refactor-task

# View recent output (last 50 lines)
subagent_output refactor-task 50

# View full scrollback history
subagent_history refactor-task

# Send a message to the sub-agent
subagent_send refactor-task "Also update the tests please"

# Send interrupt (Ctrl-C)
subagent_interrupt refactor-task
```

### Direct Tmux Commands

```bash
# List sessions
tmux list-sessions

# View current pane content
tmux capture-pane -t refactor-task -p

# View last 100 lines
tmux capture-pane -t refactor-task -p -S -100

# Attach to session interactively
tmux attach -t refactor-task

# Send keys to session (C-m sends Enter key)
tmux send-keys -t refactor-task "your message here" C-m

# Alternative: separate Enter argument
tmux send-keys -t refactor-task 'your message here'
tmux send-keys -t refactor-task Enter
```

## Managing Sub-Agents

### Killing Sessions

```bash
# Kill a specific session
source ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-helpers.sh
subagent_kill refactor-task

# Kill all sub-agent sessions
subagent_kill_all

# Or directly with tmux
tmux kill-session -t refactor-task
```

### Waiting for Completion

```bash
# Wait for session to complete (blocks)
subagent_wait refactor-task

# Wait with timeout (seconds)
subagent_wait refactor-task 1800  # 30 minute timeout
```

### Getting Workspace Info

```bash
# Get workspace path
subagent_workspace refactor-task
# Output: /tmp/claude-subagent/refactor-task

# Check workspace settings
cat /tmp/claude-subagent/refactor-task/.claude/settings.json
```

## Best Practices

### 1. Clear Task Definition

Give sub-agents well-defined, scoped tasks:

```bash
# Good: Specific, bounded task
--prompt "Refactor the UserService class in src/services/user.ts to use dependency injection. Update tests accordingly."

# Bad: Vague, unbounded
--prompt "Make the code better"
```

### 2. Appropriate Tool Restrictions

Match tools to the task:

```bash
# Code review: Read-only
--denied-tools "Write,Edit,Bash"

# Documentation: Write but no execute
--denied-tools "Bash"

# Analysis: Read + search only
--allowed-tools "Read,Grep,Glob"
```

### 3. Monitor Long-Running Tasks

For autonomous tasks, periodically check progress:

```bash
# Quick status check
tmux capture-pane -t session-name -p | tail -20

# Full output to file for analysis
tmux capture-pane -t session-name -p -S - > /tmp/session-output.txt
```

### 4. Clean Up After Completion

```bash
# Kill and clean up
subagent_kill session-name

# Or manually clean workspace
rm -rf /tmp/claude-subagent/session-name
```

## Troubleshooting

### Session Won't Start

```bash
# Check if tmux is installed
which tmux

# Check for existing session with same name
tmux has-session -t session-name && echo "exists"

# Check workspace creation
ls -la /tmp/claude-subagent/
```

### iTerm Tab Not Opening

```bash
# Check if iTerm is running
pgrep -x iTerm2

# Try manual attachment
tmux attach -t session-name

# Check AppleScript permissions in System Preferences > Security > Privacy > Automation
```

### Teammate Agent Unresponsive (Stuck Mid-Turn)

If a teammate agent is stuck mid-turn and not processing messages, send the ESC key via tmux to interrupt its current turn and allow pending messages to propagate:

```bash
tmux send-keys -t <pane-id> Escape
```

This is equivalent to pressing Escape in the teammate's pane, which interrupts the current turn without killing the session.

### Sub-Agent Can't Access Files

```bash
# Check settings.json has correct allowed directories
cat /tmp/claude-subagent/session-name/.claude/settings.json | jq '.permissions'

# Verify work directory exists
ls -la $(jq -r '._workDir' /tmp/claude-subagent/session-name/.claude/settings.local.json)
```

### Sub-Agent Has Wrong Permissions

```bash
# Check applied tool restrictions
cat /tmp/claude-subagent/session-name/.claude/settings.json | jq '.permissions.allow.tools'
cat /tmp/claude-subagent/session-name/.claude/settings.json | jq '.permissions.deny.tools'
```

## Example Workflows

### Parallel Refactoring

```bash
# Launch multiple sub-agents for different modules
for module in auth api database; do
  ${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
    --name "refactor-$module" \
    --prompt "Refactor src/$module/ to use TypeScript strict mode" \
    --no-iterm
done

# Monitor all
for session in $(tmux list-sessions -F "#{session_name}" | grep "^refactor-"); do
  echo "=== $session ==="
  tmux capture-pane -t "$session" -p | tail -5
done
```

### Code Review Pipeline

```bash
# Read-only review agent
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "security-review" \
  --denied-tools "Write,Edit,Bash" \
  --prompt "Review all files in src/ for security vulnerabilities. Write findings to /tmp/security-review.md using the allowed Read tool to read files."
```

### Testing in Isolation

```bash
# Agent with test plugins, no access to modify production code
${CLAUDE_PLUGIN_ROOT}/scripts/launch-subagent.sh \
  --name "plugin-test" \
  --work-dir /tmp/test-workspace \
  --plugins "/path/to/experimental-plugin" \
  --prompt "Test the experimental plugin features"
```

## Security Considerations

1. **Permission Mode**: Use `--permission-mode dontAsk` only for trusted, well-defined tasks
2. **Tool Restrictions**: Limit tools to what's actually needed
3. **Work Directory**: Sub-agents can only access the specified work directory
4. **Workspace Isolation**: Each sub-agent has its own config in `/tmp/`
5. **Clean Up**: Always kill sessions and clean workspaces when done

## iTerm Integration (macOS)

The plugin automatically opens an iTerm tab attached to the tmux session. This allows you to:

- Visually monitor the sub-agent's progress
- Interact directly when needed
- Keep track of multiple sub-agents in different tabs

To disable: `--no-iterm`

## Session Naming

Session names are sanitized (dots, colons, slashes become dashes). If no name is provided, a timestamp-based name is generated: `subagent-<timestamp>`
