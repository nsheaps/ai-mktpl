---
argument-hint: [what the new command should do]
description: |-
  Use this to create new /slash-commands that help users perform tasks without repetitive prompting. Use /create-agent if you want claude to be able to run the command instead of the user.
---


Docs for reference:
- https://docs.anthropic.com/en/docs/claude-code/slash-commands


Using @CLAUDE.md in @~/src/gathertown-ai/.claude/commands/, create a new command based off of the user's input. Be sure to ask any clarifying questions, especially about what might belong in the frontmatter (see docs and below for example).

Frontmatter:
| Frontmatter | Purpose | Default |
| --- | --- | --- |
| `allowed-tools` | List of tools the command can use | Inherits from the conversation |
| `argument-hint` | The arguments expected for the slash command. Example: argument-hint: add [tagId] \| remove [tagId] \| list. This hint is shown to the user when auto-completing the slash command. | None |
| `description` | Brief description of the command | Uses the first line from the prompt |
| `model` | Specific model string (see Models overview) | Inherits from the conversation |

Examples:

```markdown
---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
argument-hint: [message]
description: Create a git commit
model: claude-3-5-haiku-20241022
---

An example command
```