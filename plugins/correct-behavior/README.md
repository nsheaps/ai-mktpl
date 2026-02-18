# Correct Behavior Plugin

A Claude Code command for correcting AI behavior mistakes and updating rules to prevent recurrence.

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/ai-mktpl/plugins/correct-behavior

# Or locally for testing
cc --plugin-dir /path/to/plugins/correct-behavior
```

## Usage

```bash
/correct-behavior [SCOPE] <description of what went wrong>
```

### Scope Options

| Scope                         | Description                     | Location                                        |
| ----------------------------- | ------------------------------- | ----------------------------------------------- |
| `user`                        | Personal rules for all projects | `~/.claude/CLAUDE.md` or `~/.claude/rules/*.md` |
| `project`                     | Rules for the current project   | `<git-root>/.claude/...`                        |
| `slash-commands` / `commands` | User's slash commands           | `~/.claude/commands/*.md`                       |
| `skills`                      | User's skills                   | `~/.claude/skills/*/SKILL.md`                   |
| `plugins`                     | Plugin source code              | `~/src/nsheaps/ai/plugins/...`                  |
| `marketplace`                 | The AI config marketplace repo  | `~/src/nsheaps/ai/...`                          |

If scope is obvious from context (e.g., correcting a slash command), it will be inferred. Otherwise, you'll be asked.

### Examples

```bash
# User-level correction
/correct-behavior user don't commit unless I tell you

# Project-level correction
/correct-behavior project always use the ApiClient class for API calls

# Slash command fix (scope inferred)
/correct-behavior the commit command should always show a preview first

# Let Claude ask about scope
/correct-behavior stop adding unnecessary comments
```

## What It Does

When you invoke this command, Claude will:

1. **Reflect** on the recent task and identify what went wrong
2. **Understand** your correction in context of the work done
3. **Review** both user and project rules for conflicts or existing guidance
4. **Update** the appropriate rules file to prevent the behavior
5. **Ensure changes are committed** - either locally or via PR to the marketplace
6. **Correct** the original work that was done incorrectly

## Directory Structure

The command understands the following directory structure:

### User Config (`~/.claude/`)

- `CLAUDE.md` - Main user rules
- `rules/*.md` - Modular user rules
- `commands/*.md` - User slash commands
- `skills/*/SKILL.md` - User skills

### Project Config (`<git-root>/.claude/`)

- `CLAUDE.md` - Project rules (committed to repo)
- `rules/*.md` - Modular project rules
- `CLAUDE.local.md` - Personal project overrides (not modified)

### Marketplace Repo (`~/src/nsheaps/ai/`)

- `.claude/rules/` - Rules for working on this repo (Claude-specific)
- `.ai/rules/` - User behavior rules (AI-agnostic, syncs to user config)
- `plugins/*/commands/*.md` - Plugin command source files

## Commit Strategy

All changes must end up committed somewhere:

| Scope                       | What Happens                                                                            |
| --------------------------- | --------------------------------------------------------------------------------------- |
| `user`                      | Changes go to `~/.claude/...`. Offered to sync to `~/src/nsheaps/ai/.ai/rules/` via PR. |
| `project`                   | Reminder to commit changes to project repo                                              |
| `slash-commands` / `skills` | If in user config, offered to sync to marketplace                                       |
| `plugins` / `marketplace`   | PR created automatically and assigned to you                                            |

## Notes

- Never modifies `*.local.md` files (personal, not saved)
- Asks before modifying slash commands or skills
- Creates PRs for marketplace changes automatically
- Reminds you to commit PROJECT-level changes

## Related

- [Claude Code Memory Documentation](https://code.claude.com/docs/en/memory)
- [Claude Code Slash Commands](https://code.claude.com/docs/en/slash-commands)
