# Tmux Sub-Agent Plugin

Launch independent Claude sub-agents in tmux sessions with isolated configurations, custom tool permissions, and real-time monitoring.

## Features

- **Parallel Execution**: Run multiple Claude instances simultaneously
- **Tool Isolation**: Configure allowed/denied tools per sub-agent
- **Plugin Isolation**: Install plugins without affecting your main session
- **Configuration Inheritance**: Sub-agents inherit your project's `.claude/` config
- **iTerm Integration**: Automatically opens macOS iTerm tabs attached to sessions
- **Real-time Monitoring**: View output, send messages, and manage sessions

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/tmux-subagent

# Or locally for testing
cc --plugin-dir /path/to/plugins/tmux-subagent
```

## Requirements

- **tmux**: Must be installed (`brew install tmux` on macOS)
- **jq**: Recommended for config file parsing (`brew install jq`)
- **iTerm2**: Optional, for automatic tab attachment on macOS

## Quick Start

### Using the Slash Command

```
/subagent Refactor the authentication module to use async/await
/subagent Review src/api/ for security issues --readonly
/subagent --list
/subagent --output my-session
/subagent --kill my-session
```

### Using the Launch Script

```bash
# Basic launch
./scripts/launch-subagent.sh --name "my-task" --prompt "Your task here"

# With tool restrictions
./scripts/launch-subagent.sh \
  --name "read-only-review" \
  --denied-tools "Write,Edit,Bash" \
  --prompt "Review the codebase for issues"

# With additional plugins
./scripts/launch-subagent.sh \
  --name "with-plugins" \
  --plugins "/path/to/plugin1,/path/to/plugin2" \
  --prompt "Use custom plugins for this task"
```

## How It Works

1. **Workspace Creation**: Creates `/tmp/claude-subagent/<session-name>/`
2. **Config Copy**: Copies your project's `.claude/` configuration
3. **Permission Setup**: Adds original project as allowed directory
4. **Tool Config**: Applies specified tool restrictions
5. **Plugin Install**: Symlinks additional plugins to temp workspace
6. **Session Launch**: Starts Claude in detached tmux session
7. **iTerm Tab**: Opens attached iTerm tab (macOS only)

## Configuration Options

| Option              | Description                   | Default                |
| ------------------- | ----------------------------- | ---------------------- |
| `--name`            | Session name                  | `subagent-<timestamp>` |
| `--work-dir`        | Working directory             | Current directory      |
| `--prompt`          | Initial prompt                | None                   |
| `--prompt-file`     | File containing prompt        | None                   |
| `--allowed-tools`   | Comma-separated allowed tools | All standard tools     |
| `--denied-tools`    | Comma-separated denied tools  | None                   |
| `--plugins`         | Comma-separated plugin paths  | None                   |
| `--permission-mode` | `allowedTools` or `dontAsk`   | `allowedTools`         |
| `--model`           | Model to use                  | Inherited              |
| `--no-iterm`        | Don't open iTerm tab          | Opens tab              |
| `--attach`          | Attach after creation         | Detached               |
| `--config`          | JSON config file              | None                   |

## Monitoring Sessions

### Using Helper Functions

```bash
# Source helpers
source ./scripts/tmux-helpers.sh

# List sessions
subagent_list

# View output
subagent_output my-session 50

# Send message
subagent_send my-session "Please also update the tests"

# Kill session
subagent_kill my-session
```

### Direct Tmux Commands

```bash
# List all sessions
tmux list-sessions

# View pane content
tmux capture-pane -t my-session -p

# Attach interactively
tmux attach -t my-session

# Send keys
tmux send-keys -t my-session "message" Enter
```

## File Structure

```
tmux-subagent/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata
├── commands/
│   └── subagent.md           # /subagent slash command
├── skills/
│   └── tmux-subagent/
│       └── SKILL.md          # Comprehensive skill docs
├── scripts/
│   ├── launch-subagent.sh    # Main launch script
│   ├── attach-iterm.applescript  # iTerm integration
│   └── tmux-helpers.sh       # Management utilities
└── README.md
```

## Use Cases

### Parallel Refactoring

```bash
for module in auth api database; do
  ./scripts/launch-subagent.sh \
    --name "refactor-$module" \
    --prompt "Refactor src/$module/ to use TypeScript strict mode" \
    --no-iterm
done
```

### Isolated Code Review

```bash
./scripts/launch-subagent.sh \
  --name "security-review" \
  --denied-tools "Write,Edit,Bash" \
  --prompt "Review all files for security vulnerabilities"
```

### Plugin Testing

```bash
./scripts/launch-subagent.sh \
  --name "test-new-plugin" \
  --work-dir /tmp/test-project \
  --plugins "/path/to/experimental-plugin" \
  --prompt "Test the new plugin features"
```

## Security Notes

- **Permission Mode**: Use `dontAsk` only for trusted, well-defined tasks
- **Tool Restrictions**: Always limit tools to what's actually needed
- **Work Directory**: Sub-agents only access the specified directory
- **Workspace**: Each session has isolated config in `/tmp/`
- **Cleanup**: Kill sessions and remove workspaces when done

## Troubleshooting

### tmux not found

```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux
```

### iTerm tab doesn't open

1. Check iTerm2 is running
2. Verify AppleScript permissions in System Preferences > Security > Privacy > Automation
3. Use `--no-iterm` and attach manually: `tmux attach -t session-name`

### Sub-agent can't access files

Check the workspace settings:

```bash
cat /tmp/claude-subagent/session-name/.claude/settings.json | jq '.permissions'
```

### Session name conflicts

```bash
# Check existing sessions
tmux list-sessions

# Use unique name
./scripts/launch-subagent.sh --name "unique-name-$(date +%s)" --prompt "..."
```

## License

MIT
