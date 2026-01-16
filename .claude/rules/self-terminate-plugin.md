# Self-Terminate Plugin Usage

## When Making Changes to Session Management

When working on any of the following areas, use the `self-terminate` plugin and its associated skills:

- Session lifecycle management
- Process termination or restart logic
- Stop hooks or shutdown validation
- Git state validation before termination
- Claude Code Web session handling

## Plugin Location

`plugins/self-terminate/` contains:
- PreToolUse hook for git validation
- Self-terminate skill with comprehensive documentation
- Executable script for graceful termination

## Using the Plugin

The self-terminate plugin provides:

1. **Automatic validation** via PreToolUse hook - ensures clean git state before termination
2. **Skill documentation** for both local and web sessions
3. **Executable script** at `${CLAUDE_PLUGIN_ROOT}/bin/self-terminate.sh`

## When to Terminate

Use self-termination when:
- Configuration changes require a restart
- User explicitly requests exit
- Session needs fresh start
- Testing process management

The plugin's hook automatically enforces:
- No uncommitted changes
- No unpushed commits
- No untracked files

## Development Guidelines

When modifying the plugin:
1. Update skill documentation to reflect hook behavior
2. Test hook enforcement programmatically
3. Ensure compatibility with both local CLI and Claude Code Web
4. Keep signal choice to SIGINT (graceful interrupt)
