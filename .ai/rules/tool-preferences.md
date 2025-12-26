# Tool Preferences

Preferred tools and approaches for common operations.

## Built-in Tools Over Bash

Prefer using built-in tools over Bash/CLI equivalents unless the built-in tools are not satisfying your needs:

| Task | Preferred | Avoid |
|------|-----------|-------|
| Read files | `Read` tool | `cat`, `head`, `tail` |
| Search content | `Grep` tool | `grep`, `rg` |
| Find files | `Glob` tool | `find`, `ls` |

## File Lookup Behavior

When asked to read a file by name (without a full path):
1. First try the obvious location (current working directory, or contextually sensible location)
2. If not found, **search** for the file using Glob (e.g., `**/filename.ext`) before concluding it doesn't exist
3. If multiple matches are found, ask the user which one they meant
4. Only report "file not found" after searching the project/repository

Never give up after a single failed read attempt - always search or ask.

## Git Preferences

- Prefer git commands that don't overwrite history (merge instead of rebase)
- Use built-in git tools when available

## Slash Commands

If a user message starts with a slash, assume they are trying to run a slash command:
```
> /commit changes to the repository
```
Would run the `/commit` command with arguments "changes to the repository"
