# File Operations

## Directory Creation

**IMPORTANT:** Do NOT use `mkdir` commands directly. The `mkdir` command is blocked via permissions.

Directories are automatically created by a PreToolUse hook when using the Write tool. The hook:

1. Intercepts Write tool calls before execution
2. Extracts the target file path
3. Creates any missing parent directories with `mkdir -p`
4. Allows the Write to proceed

### Why This Approach?

- **Simplicity**: No need to check if directories exist before writing
- **Consistency**: All file writes automatically have their directories created
- **Error Prevention**: Eliminates "directory does not exist" errors

### What to Do Instead

Simply use the Write tool to create files. The hook handles directory creation:

```
# Just write the file - directory will be created automatically
Write tool: /path/to/new/dir/file.txt
```

### Hook Location

- Script: `.claude/hooks/PreToolUse/ensure-write-dir.sh`
- Config: `.claude/settings.json` (PreToolUse hooks section)

## See Also

- [Environment Setup](environment-setup-and-maintenance.md) - Session hooks and environment
