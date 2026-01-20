# Statusline iTerm Plugin - Development Guide

Instructions for modifying the statusline script in this plugin.

## Script Location

`bin/statusline.sh` - The main statusline script with iTerm2 badge integration

## How the Statusline Works

The statusline script:

1. Receives JSON input from Claude Code via stdin
2. Extracts session info, workspace paths, and git status
3. Outputs formatted lines to display in the Claude Code UI
4. Each `echo` statement creates one line in the status display
5. **Additionally**: Sets iTerm2 `user.badge` variable for badge display

## iTerm2 Badge Integration

This plugin extends the base statusline by emitting an iTerm2 escape sequence:

```bash
printf "\033]1337;SetUserVar=%s=%s\007" "badge" "$(echo -n "$badge_text" | base64)" >&2
```

Key points:

- Output goes to stderr (`>&2`) to not interfere with statusline output
- Only runs when `$TERM_PROGRAM` is `iTerm.app`
- Badge shows: repo name, branch, ahead/behind counts, clean/dirty status

### Modifying the Badge

To change what the badge displays, edit `bin/statusline.sh`:

1. Find the section starting with `# Build iTerm badge text`
2. Modify the `badge_text` variable construction
3. Test with: `echo '{}' | ./bin/statusline.sh` (in iTerm2)

## Input Format

The script receives JSON via stdin with this structure:

```json
{
  "session_id": "abc-123",
  "workspace": {
    "project_dir": "/Users/you/project",
    "current_dir": "/Users/you/project/src"
  }
}
```

**Available fields:**

- `session_id` - Current session UUID
- `workspace.project_dir` - Project root path
- `workspace.current_dir` - Current working directory

**Environment variables also available:**

- `$CLAUDE_PROJECT_DIR` - Project root
- `$MISE_ORIGINAL_CWD` - Original working directory
- `$PWD` - Current directory

## Modifying the Script

### Adding a New Status Line

Add an `echo` statement to output a new line:

```bash
# Example: Show current time
echo "Time: $(date +%H:%M:%S)"

# Example: Show mise environment
if command -v mise >/dev/null 2>&1; then
  mise_env=$(mise current 2>/dev/null | head -1 || echo "none")
  echo "Mise: $mise_env"
fi
```

### Removing an Existing Line

Comment out or delete the corresponding `echo` statement:

```bash
# Remove session ID display
# if [ -n "$session_id" ]; then
#   echo "Session: $session_id"
# fi
```

### Conditional Display

Use bash conditionals to show lines only when relevant:

```bash
# Only show if in git worktree
if [ -f "$project_dir/.git" ]; then
  worktree_name=$(basename "$project_dir")
  echo "Worktree: $worktree_name"
fi
```

### Formatting Guidelines

**Keep lines concise:**

- Use abbreviations where clear (e.g., "In:" instead of "Project:")
- Limit to 80 characters when possible
- Use `|` to separate multiple values on one line

**Use consistent prefixes:**

- Current pattern: `Session:`, `In:`, `On:`
- Add new prefixes as needed: `Env:`, `Time:`, `Status:`

## Common Customizations

### Show Different Git Info

```bash
# Show commit hash
commit_hash=$(git -C "$project_dir" rev-parse --short HEAD 2>/dev/null || echo "")
if [ -n "$commit_hash" ]; then
  echo "Commit: $commit_hash"
fi

# Show upstream tracking
upstream=$(git -C "$project_dir" rev-parse --abbrev-ref @{u} 2>/dev/null || echo "")
if [ -n "$upstream" ]; then
  echo "Tracking: $upstream"
fi
```

### Add Environment Detection

```bash
# Detect if in Docker
if [ -f "/.dockerenv" ]; then
  echo "Env: Docker"
fi

# Detect if in remote session
if [ -n "$CLAUDE_CODE_REMOTE" ]; then
  echo "Env: Remote"
fi
```

### Integrate External Tools

```bash
# Show Python venv
if [ -n "$VIRTUAL_ENV" ]; then
  venv_name=$(basename "$VIRTUAL_ENV")
  echo "Venv: $venv_name"
fi

# Show Node version from mise/nvm
if command -v node >/dev/null 2>&1; then
  node_version=$(node --version)
  echo "Node: $node_version"
fi
```

## Testing Changes

After modifying `bin/statusline.sh`:

### Test Locally

```bash
# Test with sample input
echo '{"session_id": "test-123", "workspace": {"project_dir": "/Users/you/project"}}' | \
  ./plugins/statusline/bin/statusline.sh
```

### Test in Claude Code

1. Restart Claude Code to reload the plugin
2. Check the status line display
3. Verify all lines appear correctly

## Performance Considerations

The statusline script runs frequently (on every prompt). Keep it fast:

**DO:**

- ✅ Use simple bash commands
- ✅ Cache expensive operations
- ✅ Fail gracefully (|| true)
- ✅ Suppress errors (2>/dev/null)

**DON'T:**

- ❌ Make network requests
- ❌ Run slow commands
- ❌ Process large files
- ❌ Use heavy tools (unless cached)

## Error Handling

Always handle errors gracefully:

```bash
# BAD: Uncaught error crashes statusline
branch=$(git rev-parse --abbrev-ref HEAD)

# GOOD: Graceful fallback
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
```

## Debugging

Enable bash debugging in the script header:

```bash
#!/usr/bin/env bash
set -x  # Show commands as they execute
set -e  # Exit on error (remove for debugging)
```

Check stderr output when running Claude Code:

```bash
claude 2>&1 | tee claude-output.log
# Check log for statusline errors
```

## Dependencies

The statusline script uses these tools:

- `bash` - Required
- `jq` - Required for JSON parsing
- `git` - Required for git status
- `uvx` and `par-cc-usage` - Optional for usage tracking

Ensure these are installed for full functionality.

## Examples

See `bin/statusline.sh` for the current implementation with inline comments.

## Related Files

- `bin/statusline.sh` - Main statusline script
- `hooks/configure-statusline.sh` - Hook that configures settings.json
- `hooks/hooks.json` - Hook configuration
