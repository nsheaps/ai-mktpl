# Tool Preferences

Preferred tools and approaches for common operations.

## Built-in Tools Over Bash

Prefer using built-in tools over Bash/CLI equivalents unless the built-in tools are not satisfying your needs:

| Task           | Preferred   | Avoid                 |
| -------------- | ----------- | --------------------- |
| Read files     | `Read` tool | `cat`, `head`, `tail` |
| Search content | `Grep` tool | `grep`, `rg`          |
| Find files     | `Glob` tool | `find`, `ls`          |

## File Lookup Behavior

When asked to read a file by name (without a full path):

1. First try the obvious location (current working directory, or contextually sensible location)
2. If not found, **search** for the file using Glob (e.g., `**/filename.ext`) before concluding it doesn't exist
3. If multiple matches are found, ask the user which one they meant
4. Only report "file not found" after searching the project/repository

Never give up after a single failed read attempt - always search or ask.

## Package Manager Preferences

Prefer **yarn** over npm for Node.js projects:

1. Use **corepack** to enable and install the latest version of yarn
2. Use `yarn` commands instead of `npm` commands
3. For new projects, initialize with `yarn init`

**Why:** Yarn provides better dependency resolution, workspace support, and is the project standard.

## Git Preferences

- Prefer git commands that don't overwrite history (merge instead of rebase)
- Use built-in git tools when available

## Slash Commands

If a user message starts with a slash, assume they are trying to run a slash command:

```
> /commit changes to the repository
```

Would run the `/commit` command with arguments "changes to the repository"

## Script Persistence

Prefer capturing reusable commands in script files:

1. Anything more than a single command should be a script file
2. This improves consistency and allows iteration on task completion
3. Where possible, accompany scripts with a skill that documents usage
4. Skills should be captured in installable plugins at github.com/nsheaps/.ai

## Data Storage

When storing structural data:

1. Use local files in **YAML format** (JSON acceptable if needed)
2. Prefer project directories for task-relevant data
3. Commit and push if useful for future tasks
4. Include comments in YAML (or use JSON5) explaining how data was generated

## External Service Integration

When interfacing with external services, prefer in this order:

1. Claude-Code plugin
2. MCP server
3. CLI tooling
4. Skills-based code execution
5. Scripts that capture complexity (but not secrets)
6. Direct API calls using `curl` or `wget`

## API Discovery

When exploring available APIs for external services, use https://apis.guru/ to find OpenAPI specifications.
