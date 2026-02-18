# Bash Command Rejection Plugin

A Claude Code plugin that enforces single-command execution by rejecting bash commands that use chaining operators (`&&`, `|`, `;`).

## Why?

Chained commands are impossible to properly handle permissions for:

- **Permission blind spots**: The approval system can only evaluate the first command in a chain
- **Conditional execution**: `cmd1 && cmd2` means cmd2 only runs if cmd1 succeeds - you can't review conditional behavior
- **Hidden data flow**: `cmd1 | cmd2` streams data to cmd2 with no visibility into what cmd2 does with it
- **Security risk**: A chain could contain a benign first command followed by something dangerous

## What Gets Blocked

| Pattern | Example                    | Reason               |
| ------- | -------------------------- | -------------------- |
| `&&`    | `npm install && npm build` | Conditional chaining |
| `\|`    | `cat file \| grep pattern` | Output piping        |
| `;`     | `cmd1; cmd2`               | Sequential execution |

## What's Allowed

| Pattern         | Example                   | Reason                         |
| --------------- | ------------------------- | ------------------------------ |
| `\|\|`          | `cmd1 \|\| echo "failed"` | Error handling/fallback        |
| Single commands | `npm install`             | Can be properly reviewed       |
| Redirects       | `cmd > file.txt`          | Output goes to reviewable file |

## Installation

This plugin is part of the nsheaps/.ai plugin marketplace. Add it to your Claude Code configuration:

```json
{
  "plugins": ["nsheaps/.ai/plugins/bash-command-rejection"]
}
```

## Bypass Mechanism

If chaining is truly necessary, add an acknowledgment comment:

```bash
# CHAINED: Explanation of why this is safe/necessary
command1 && command2
```

**Use sparingly** - the comment should explain why the chain is safe and necessary.

## Alternatives to Chaining

See the [bash-chaining-alternatives skill](./skills/bash-chaining-alternatives/SKILL.md) for detailed guidance on:

1. Running commands separately
2. Redirecting output to files
3. Using Claude Code's built-in tools (Grep, Glob, Read, Edit)
4. Writing reviewable shell scripts

## How It Works

The plugin installs a `PreToolUse` hook that:

1. Intercepts all `Bash` tool calls before execution
2. Checks the command for chaining operators
3. Rejects the command with a helpful message explaining alternatives
4. Allows commands with the `# CHAINED:` acknowledgment pattern

## Configuration

No configuration required. The plugin works automatically once installed.

## License

MIT
