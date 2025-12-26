# Environment Setup and Maintenance

## Overview

This repository uses **mise** for tool version management and **Claude Code hooks** for automatic session setup. The configuration ensures consistent development environments across local machines and Claude Code web sessions.

CRITICAL: The hooks are a last-ditch effort to ensure a consistent environment between executions of the agent. Always try to pre-emptively install software in an earlier layer, especially one that can be re-used, such as a container layer.

## Key Resources

- [Claude Code on the Web - Dependency Management](https://code.claude.com/docs/en/claude-code-on-the-web#dependency-management)
- [claude-code-guide](https://github.com/anthropics/claude-code) - Official Claude Code documentation

## Configuration Files

### `.mise.toml`

Defines tool versions for the project:

```toml
[tools]
gh = "latest"      # GitHub CLI
node = "22"        # Node.js
python = "3.12"    # Python
bun = "latest"     # Bun runtime
```

### `.claude/hooks/SessionStart/hook.sh`

Runs automatically when a Claude Code session starts:

1. Fetches git updates and shows status
2. Installs mise if not available (web sessions only)
3. Installs tools from `.mise.toml`

## Adding New Tools

1. Add the tool to `.mise.toml`:
   ```toml
   [tools]
   your-tool = "version"
   ```

2. Tools will be installed automatically on next session start

## Preserving Environment Variables

Use `CLAUDE_ENV_FILE` to persist environment changes across tool calls:

```bash
# In a hook script
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export MY_VAR=value" >> "$CLAUDE_ENV_FILE"
fi
```

### Common Patterns

**Modifying PATH:**
```bash
if [ -n "$PATHMOD" ]; then
  echo "export PATH=\"$PATHMOD:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
```

**Activating mise:**
```bash
eval "$(mise activate bash)"
echo 'eval "$(mise activate bash)"' >> "$CLAUDE_ENV_FILE"
```

## Web Session vs Local

The hook detects web sessions via `CLAUDE_CODE_REMOTE`:

- **Web sessions**: Full setup (mise install, tool installation)
- **Local sessions**: Light setup (git fetch/status only)

## Troubleshooting

### mise installation fails

Web environments may have network restrictions. The hook gracefully handles this:
```
⚠️  mise installation failed (network restricted)
   Tools from .mise.toml will not be available
```

### Tools not available

1. Check if mise is installed: `command -v mise`
2. Trust the config: `mise trust`
3. Install tools: `mise install -y`
