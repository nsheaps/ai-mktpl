# Tool Preferences

Preferred tools and approaches for common operations.

## Background Execution

When running Bash commands or Task agents, prefer `run_in_background: true`.

**Why:**

- Output is captured to a file that you can analyze after completion
- NEVER pipe to other tools to narrow the output with `| head` or `| grep`. You will lose the full output and won't be able to analyze it further without re-running the command, which is NOT ALLOWED.
- Allows you to continue working while waiting for long-running tasks
- Makes it easier to analyze different parts of the response without re-running

**Example:**

```typescript
// Good: Run in background, analyze file after
Bash({ command: "npm test", run_in_background: true });
// Then use TaskOutput to get results when ready

// NEVER: Trying to filter output inline
Bash({ command: "npm test | head -50" }); // Loses full output
```

## External Service Data Handling

When interacting with external services (APIs, CLIs, web fetches) for searching, querying, or fetching data:

1. **Always save output to a file** for analysis after the tool completes
2. **Prefer JSON** over plain text or markdown when requesting data
3. **Query the data AFTER saving** rather than parsing via pipes or streaming

**Why:**

- Prevents multiple calls to the same endpoint when analyzing different parts
- JSON is easier to parse with `jq` or programmatic tools
- Large or complex data is easier to navigate in a file
- You can re-analyze without re-fetching

**Example workflow:**

```bash
# Save API response to file
curl -s api.example.com/data > /tmp/api-response.json

# Then analyze specific parts without re-calling
jq '.items[] | select(.status == "active")' /tmp/api-response.json
jq '.metadata' /tmp/api-response.json
```

## Built-in Tools Over Bash

Prefer using built-in tools over Bash/CLI equivalents unless the built-in tools are not satisfying your needs.

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

Would run the `SlashCommand:/commit` tool with arguments "changes to the repository"

Prefer to look for slash commands that match that name before a skill that matches that name.

## Bash commands

If a user message starts with a !`command string`, assume they're trying to run a bash command. The output from this command may help you. If it seems like something might be wrong, ask the user what to do next.

```
> !ls -la
```

Would run the `Bash(ls -la)` tool.

## Script Persistence

Prefer capturing reusable commands in script files:

1. Anything more than a single command should be a script file
2. This improves consistency and allows iteration on task completion
3. Where possible, accompany scripts with a skill that documents usage
4. Skills should be captured in installable plugins at github.com/nsheaps/ai-mktpl

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
