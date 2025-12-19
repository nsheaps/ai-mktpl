# Correct Behavior Plugin

A Claude Code command for correcting AI behavior mistakes and updating rules to prevent recurrence.

## Installation

### Quick Install (Symlink)

```bash
ln -sf ~/src/nsheaps/ai/plugins/correct-behavior/commands/correct-behavior.md ~/.claude/commands/correct-behavior.md
```

### Plugin Install (Future)

Once the plugin system supports installation:
```bash
claude plugin install ./plugins/correct-behavior
```

## Usage

```bash
/correct-behavior [USER|PROJECT] <description of what went wrong>
```

### Arguments

- **Scope** (optional): `USER` or `PROJECT`
  - `USER`: Applies correction to `~/.claude/` (affects all projects)
  - `PROJECT`: Applies correction to project's `.claude/` (committed to repo)
  - If omitted, you'll be asked which scope applies

- **Description**: What the AI did wrong that should be corrected

### Examples

```bash
# User-level correction
/correct-behavior USER don't commit unless I tell you

# Project-level correction
/correct-behavior PROJECT always use the ApiClient class for API calls

# Let Claude ask about scope
/correct-behavior stop adding unnecessary comments
```

## What It Does

When you invoke this command, Claude will:

1. **Reflect** on the recent task and identify what went wrong
2. **Understand** your correction in context of the work done
3. **Review** both user and project rules for conflicts or existing guidance
4. **Update** the appropriate rules file to prevent the behavior
5. **Correct** the original work that was done incorrectly

## File Locations

The command modifies rules based on scope:

| Scope | Location |
|-------|----------|
| USER | `~/.claude/CLAUDE.md` or `~/.claude/rules/*.md` |
| PROJECT | `<git-root>/CLAUDE.md` or `<git-root>/.claude/rules/*.md` |

## Notes

- Never modifies `*.local.md` files (personal, not saved)
- Asks before modifying slash commands or skills
- Offers to create PRs for changes to `~/src/nsheaps/ai/...`
- Reminds you to commit PROJECT-level changes

## Related

- [Claude Code Memory Documentation](https://code.claude.com/docs/en/memory)
- [Claude Code Slash Commands](https://code.claude.com/docs/en/slash-commands)
