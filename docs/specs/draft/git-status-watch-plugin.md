# Git Status Watch Plugin

## Overview

A Claude Code hook-based plugin that prevents unintended tool execution when the git working directory has changed unexpectedly. This helps catch external modifications (user edits, other tools, file system changes) before the agent proceeds with operations that might conflict or produce unexpected results.

## Problem Statement

When an AI agent is working on a task, external changes to the repository can cause:

- Merge conflicts or overwritten changes
- Stale assumptions about file contents
- Unintended side effects from operating on modified files
- Confusion about what the agent vs. user changed

The agent should be aware when the repo state has changed since its last action.

## Solution

Use Claude Code hooks to track git status between tool executions:

1. **PostToolUse hook**: After each tool use, compute and store a hash of `git status --porcelain`
2. **PreToolUse hook**: Before each tool use, compare current hash to stored hash
3. **If changed**: Block tool execution, show current status, require explicit re-run

## Technical Design

### Hook Implementation

```bash
# Location: plugins/git-status-watch/.claude/hooks/

# File: PostToolUse/update-status-hash.sh
#!/bin/bash
# Compute and store git status hash after each tool use
STATUS_HASH=$(git status --porcelain 2>/dev/null | sha256sum | cut -d' ' -f1)
HASH_FILE="${CLAUDE_PROJECT_DIR:-.}/.git/.claude-status-hash"
echo "$STATUS_HASH" > "$HASH_FILE"

# File: PreToolUse/check-status-hash.sh
#!/bin/bash
# Compare current git status hash to stored hash
HASH_FILE="${CLAUDE_PROJECT_DIR:-.}/.git/.claude-status-hash"

# If no stored hash, allow (first run)
if [[ ! -f "$HASH_FILE" ]]; then
    exit 0
fi

STORED_HASH=$(cat "$HASH_FILE")
CURRENT_HASH=$(git status --porcelain 2>/dev/null | sha256sum | cut -d' ' -f1)

if [[ "$STORED_HASH" != "$CURRENT_HASH" ]]; then
    echo "⚠️  Repository state has changed since last tool use!"
    echo ""
    echo "Current git status:"
    git status --short
    echo ""
    echo "This could be due to:"
    echo "  - User edits outside the agent"
    echo "  - Another tool or process modifying files"
    echo "  - File system changes"
    echo ""
    echo "Run the command again to acknowledge and continue."

    # Update the hash so re-running works
    echo "$CURRENT_HASH" > "$HASH_FILE"

    exit 1
fi
```

### Plugin Structure

```
plugins/git-status-watch/
├── .claude-plugin/
│   └── plugin.json
├── .claude/
│   └── hooks/
│       ├── PostToolUse/
│       │   └── update-status-hash.sh
│       └── PreToolUse/
│           └── check-status-hash.sh
└── README.md
```

### plugin.json

```json
{
  "name": "git-status-watch",
  "version": "1.0.0",
  "description": "Watches for repository changes between tool uses and alerts the agent",
  "author": {
    "name": "nsheaps"
  },
  "hooks": {
    "PostToolUse": ["update-status-hash.sh"],
    "PreToolUse": ["check-status-hash.sh"]
  }
}
```

## Behavior

### Normal Flow (no external changes)

1. Agent runs tool A
2. PostToolUse: Store hash of `git status`
3. Agent runs tool B
4. PreToolUse: Compare hash - matches, proceed
5. Tool B executes normally

### External Change Detected

1. Agent runs tool A
2. PostToolUse: Store hash
3. **User edits a file**
4. Agent tries to run tool B
5. PreToolUse: Compare hash - differs!
6. Output:

   ```
   ⚠️  Repository state has changed since last tool use!

   Current git status:
    M src/file.ts

   This could be due to:
     - User edits outside the agent
     - Another tool or process modifying files
     - File system changes

   Run the command again to acknowledge and continue.
   ```

7. Tool B is blocked (exit 1)
8. Hash is updated for next run
9. Agent must explicitly re-run tool B to proceed

## Edge Cases

### First Run

No stored hash exists. The PostToolUse hook will create the initial hash file after the first tool completes. PreToolUse allows execution when no hash file exists.

### Non-Git Directories

If `git status` fails (not a git repo), the hooks should gracefully allow execution without blocking.

### Hash File Location

Store in `.git/.claude-status-hash` to:

- Keep it out of the working tree
- Automatically clean up if `.git` is removed
- Avoid committing it accidentally

### Tool-Specific Exceptions

Some tools shouldn't trigger the check (e.g., Read, Glob, Grep). Consider adding a tool name filter:

```bash
# Skip check for read-only tools
case "$CLAUDE_TOOL_NAME" in
    Read|Glob|Grep|WebSearch|WebFetch)
        exit 0
        ;;
esac
```

## Configuration Options (Future)

- `ignore_patterns`: Glob patterns for files to ignore in status comparison
- `exclude_tools`: Tools that shouldn't trigger the check
- `severity`: "warn" vs "block" mode
- `auto_acknowledge`: Auto-continue after showing diff (less strict mode)

## Installation

```bash
# Clone or symlink to ~/.claude/plugins/
ln -s /path/to/git-status-watch ~/.claude/plugins/git-status-watch

# Or install from marketplace (once published)
claude plugins install git-status-watch
```

## Related Rules

This plugin works well with:

- `code-quality.md#Clean Working Directory Before Starting Tasks`
- `todo-management.md` - Helps catch when external changes disrupt tracked work

## Open Questions

1. Should the hash include untracked files? (`git status --porcelain` does by default)
2. Should there be a "force continue" flag to skip the check for a single run?
3. How should this interact with stashed changes?
4. Should the plugin also show a diff of what changed?
