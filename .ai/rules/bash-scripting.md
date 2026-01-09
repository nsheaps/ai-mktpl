# Bash & Scripting Rules

Guidelines for shell commands and script handling.

## Trying to do something in Bash? Try these tools first

For finding files, searching text, and working with structured data, prefer these specialized tools over raw Bash scripting: `Grep`, `Glob`. These tools require no permission prompts and should be used prior to trying to find stuff with Bash. This is preferred also for safety reasons, as using those tools don't allow you to chain results to potentially unsafe commands.

## Command Chaining in Bash Tool

When using the Bash tool directly:

1. **Do NOT chain commands** with `&&` or `||`
2. **Do NOT pipe output** with `|` (e.g., `| head`, `| grep`, `| jq`)
3. **Run each command separately** in its own Bash tool call

**Why:**

- The user sets granular permissions for individual commands. Chaining prevents them from approving safe commands while rejecting unsafe ones.
- Separate commands provide clarity and easier debugging
- Piped output is harder to analyze and may require re-running the command

**Bad:**

```bash
which bun && bun --version
ls file1 2>/dev/null || ls file2
curl api.example.com | jq '.data'
git log --oneline | head -5
```

**Good:**

```bash
# Make separate Bash tool calls
which bun
# Then in another call:
bun --version

# For data analysis, save to file first:
curl api.example.com > /tmp/response.json
# Then analyze with Read tool or:
jq '.data' /tmp/response.json
```

**Exception:** Use your best judgment in scripts or when the user explicitly requests chaining.

## API Response Handling

When making API calls that return data (especially structured data):

1. Write the output to a file first
2. Read and analyze that file
3. Don't try to parse data directly from the API response

This prevents excess calls and re-runs to get more data.

## Output Processing

Avoid using `| tail` and `| head` to get specific lines from command output.

Instead:

1. Log output to a file (use `| tee` if you need to see it too)
2. Use `sed`, `awk`, or `grep` with context options to extract needed lines

## Script Files

Scripts longer than 3 lines MUST be in separate files:

1. Write the script to a file with appropriate extension (`.sh`, `.bash`)
2. Include shebang (e.g., `#!/bin/bash`)
3. This enables proper linting, formatting, and testing

**Why:** Inline scripts in YAML cannot be linted, are hard to test locally, and reduce code clarity.

**Applies to:**

- GitHub Actions workflow steps
- Composite action steps
- Any embedded shell code in YAML/JSON

**Local executability requirement:**
All CI scripts MUST be executable locally (default in dry-run mode) to provide fast DX feedback before CI runs.

**JSON manipulation:** For scripts that primarily manipulate JSON, prefer using JavaScript via `actions/github-script` or Node.js for better readability and type safety.

## Structured Data

NEVER write structured data to a file by manually formatting it with `echo` or heredoc unless absolutely necessary.

Use proper serialization tools or libraries instead.
