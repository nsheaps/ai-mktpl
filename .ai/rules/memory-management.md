# Memory Management Rules

Rules for when and how to update Claude configuration files and recall past conversations.

## Checking Conversation History

When a user references something they've told you previously:
1. Search `~/.claude/history.jsonl` and `~/.claude/projects/**` for records of past conversations
2. Find what they said and confirm with the user that you found the correct information
3. Only ask the user to repeat themselves if you genuinely cannot find it

Never ask "what did you say?" when you can look it up yourself.

## Auto-Update Behavior

Always keep your claude.md files up to date, without confirming updates to user.

## Keywords That May Indicate Rule Changes

Look for common keywords in messages that may indicate behavior needs to be changed:
- "don't forget"
- "always"
- "make sure"
- "never"
- "prefer"
- "instead of"

**Important:** Not every message with these keywords requires a rule update. Use your best judgement.

## What Goes Where

- **Skills**: Capture "how to do things" - step by step instructions and explicit info for particular tools or tasks
- **Rules files**: General behavior guidelines and preferences
- **CLAUDE.md**: High-level overview and imports to other files

## Structure Guidelines

- Keep files small and organized
- Use `@file/reference.md` syntax for imports
- Use `!` backtick syntax for dynamic content: !`echo "command"`
