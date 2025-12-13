---
argument-hint: [THIS SHOULD NEVER BE USED]
description: THIS COMMAND SHOULD NEVER BE USED. THIS IS NOT A COMMAND. IF A USER RUNS THIS IT IS A MISTAKE. YOU SHOULD STOP IMMEDIATELY AND SAY "/CLAUDE is not a valid command, it is because there is a CLAUDE.md in the commands directory. I can't run this. Please pick a different command"
---

# THIS COMMAND SHOULD NEVER BE USED. THIS IS NOT A COMMAND. IF A USER RUNS THIS IT IS A MISTAKE.
**CRITICAL** YOU SHOULD STOP IMMEDIATELY AND SAY "/CLAUDE is not a valid command, it is because there is a CLAUDE.md in the commands directory. I can't run this. Please pick a different command"

This is actually `Slash Commands Implementation Guide`

## Overview

Slash commands are implemented as Markdown files in `.claude/commands/` that define custom behaviors for the Claude Code CLI.

## Command Structure

### Frontmatter
Commands use YAML frontmatter to define metadata:

```markdown
---
argument-hint: [optional arguments]
description: Brief description of what the command does
allowed-tools: Bash(git add:*), Bash(git status:*)  # Optional: restrict tools
model: claude-3-5-haiku-20241022                    # Optional: specify model
---
```

### Required Fields
- `description`: Brief explanation of command purpose

### Optional Fields
- `argument-hint`: Shows argument syntax in CLI (e.g., `[optional hint]`, `<required-arg>`)
- `allowed-tools`: Restricts which tools the command can use
- `model`: Specifies which Claude model to use for this command

### Command Content
- Use `$ARGUMENTS` placeholder to reference user-provided arguments
- Document expected behavior, workflow, and examples
- Include critical requirements and constraints

## Implementation Requirements

**CRITICAL**: Before implementing any slash command:

1. **Research First**: Check https://docs.anthropic.com/en/docs/claude-code/slash-commands for current syntax
2. **Validate Syntax**: Ensure frontmatter fields match official documentation
3. **Test Arguments**: Verify `$ARGUMENTS` placeholder works as expected
4. **Document Patterns**: Update this guide when learning new patterns

## Examples

### Simple Command (No Arguments)
```markdown
---
description: Show git status
---

Run `git status` to display current repository state.
```

### Command with Optional Arguments  
```markdown
---
argument-hint: [optional hint]
description: Commit changes with optional guidance
---

Commit outstanding changes. Optional hint ($ARGUMENTS) guides commit strategy.
```

### Command with Required Arguments
```markdown
---
argument-hint: <issue-number>
description: Fix specific GitHub issue
---

Fix issue #$ARGUMENTS following coding standards.
```

## Best Practices

1. **Clear Documentation**: Explain command purpose and behavior
2. **Argument Handling**: Use `$ARGUMENTS` correctly and document expected format
3. **Error Handling**: Include validation and clarification requests
4. **Tool Restrictions**: Use `allowed-tools` to limit scope when appropriate
5. **Research First**: Always check official docs before assuming implementation details