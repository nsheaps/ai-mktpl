# Bash & Scripting Rules

Guidelines for shell commands and script handling.

## Command Chaining in Bash Tool

When using the Bash tool directly, do NOT chain commands with `&&` or `||`.

**Why:** The user sets granular permissions for individual commands. Chaining prevents them from approving safe commands while rejecting unsafe ones.

**Bad:**
```bash
which bun && bun --version
ls file1 2>/dev/null || ls file2
```

**Good:**
```bash
# Make separate Bash tool calls
which bun
# Then in another call:
bun --version
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

Avoid creating inline scripts. Always:
1. Write the script to a file with appropriate extension
2. Include shebang if necessary (e.g., `#!/bin/bash`)
3. This improves code clarity and code quality tool functioning

Common cases where this applies:
- GitHub Actions using bash scripts
- `actions/script` steps

## Structured Data

NEVER write structured data to a file by manually formatting it with `echo` or heredoc unless absolutely necessary.

Use proper serialization tools or libraries instead.
