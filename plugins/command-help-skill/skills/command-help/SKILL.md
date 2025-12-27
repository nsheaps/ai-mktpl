


This is supposed to be a skill for CLAUDE to use when a /slashcommand is typed as a message instead of executed. This is important because slash commands take up space in the context, and the window can be saved if dynamically loaded. The critical thing is to use the slash command as a prompt for the general-purpose agent.



##### BELOW BE VIBES
---
name: command-help
description: >
  Help users understand and discover slash commands when they accidentally type them as messages instead of executing them
  For example if they type:
  /commit a thing
  /correct-behavior blah blah
  /assist with something
  /review bleh
---

# Command Help Skill

This skill enables Claude to recognize when a user has accidentally typed a slash command as a message instead of executing it, and helps them understand how to properly use slash commands and discover the right command for their task.

## When Claude Activates This Skill

Claude will automatically use this skill when:

- **User Types a Slash Command as Text**: User sends a message starting with `/` that looks like a command (e.g., "/commit", "/help", "/review")
- **User Asks About Commands**: User asks "what commands are available?" or "how do I use slash commands?"
- **User Wants to Discover Commands**: User asks "is there a command for X?" or "how do I do Y with a command?"
- **User Mentions Command Execution**: User says something like "I tried to run /command but it didn't work"
- **User Needs Command Documentation**: User asks "what does /command do?" or "how does /command work?"

## What This Skill Enables

### 1. Detect Accidental Command Messages

When a user sends a message like `/commit` or `/help` as regular text instead of executing it, Claude recognizes this and explains:
- That this looks like a slash command
- How to properly execute slash commands in Claude Code
- What the command does and how to use it

### 2. Command Discovery

Help users find the right command for their task:
- List all available slash commands in the workspace
- Search for commands by functionality
- Explain what each command does
- Show usage examples and arguments

### 3. Command Documentation

Provide detailed information about specific commands:
- Command description and purpose
- Required and optional arguments
- Usage examples
- Allowed tools and permissions
- Best practices

## How Claude Uses This Skill

### Scenario 1: Accidental Command Message

```
User: "/commit"

Claude's response with this skill:
"I notice you typed '/commit' as a message. This looks like a slash command!

To execute slash commands in Claude Code, you need to run them as commands rather than sending them as messages. The /commit command analyzes your git changes and creates an intelligent commit with an AI-generated message.

Would you like me to:
1. Execute the /commit command for you now, or
2. Explain more about how it works first?"
```

### Scenario 2: Finding the Right Command

```
User: "Is there a command to help me commit my changes?"

Claude's workflow:
1. Searches for available commands in .claude/commands/
2. Looks for user-installed plugins with relevant commands
3. Identifies the /commit command
4. Explains what it does and how to use it
```

### Scenario 3: Command Discovery

```
User: "What commands do I have available?"

Claude's workflow:
1. Lists all commands in .claude/commands/
2. Checks for plugin commands in installed plugins
3. Provides descriptions for each command
4. Categorizes them by functionality
5. Shows usage examples
```

## Skill Capabilities

### Command Detection

Claude can identify when text looks like a command:
- Starts with `/`
- Followed by a valid command name
- May include arguments
- Common command patterns: `/commit`, `/help`, `/review`, `/test`, etc.

### Command Discovery Process

To help users find commands, Claude will:

1. **Check .claude/commands/ Directory**
   - Search for all `.md` files
   - Read command metadata (name, description, arguments)
   - Extract usage information

2. **Check Installed Plugins**
   - Look in `plugins/*/commands/` directories
   - Find plugin-provided commands
   - Read plugin command documentation

3. **Search by Functionality**
   - Match user's intent to command descriptions
   - Suggest relevant commands
   - Explain differences between similar commands

4. **Provide Usage Guidance**
   - Show command syntax
   - Explain arguments and options
   - Give practical examples
   - Mention any prerequisites

### Command Information Extraction

For each command, Claude extracts:
- **Name**: The command name (e.g., "commit")
- **Description**: What the command does
- **Arguments**: Required and optional parameters
- **Argument Hints**: Help text for arguments
- **Allowed Tools**: What tools the command can use
- **Usage Examples**: How to use the command

## Usage Examples

### Example 1: User Types Command as Message

```
User: "/commit fix: resolve login bug"

Claude:
"I see you've typed '/commit fix: resolve login bug' as a message. This is a slash command that should be executed directly!

The /commit command analyzes your git changes and creates a commit. The argument 'fix: resolve login bug' will be used as a prefix for the commit message.

To execute this command properly, you would run it as a slash command in Claude Code. Would you like me to help you create this commit now?"
```

### Example 2: User Asks About Available Commands

```
User: "What commands can I use?"

Claude:
"Let me search for available slash commands in your workspace..."

[Searches .claude/commands/ and plugin directories]

"Here are the available slash commands:

**Git & Version Control:**
- /commit [prefix] - Analyze changes and create intelligent commit messages

**Custom Commands:**
[Lists any custom commands found in .claude/commands/]

**Plugin Commands:**
[Lists commands from installed plugins]

Would you like more details about any specific command?"
```

### Example 3: Finding the Right Command for a Task

```
User: "Is there a command to help me write better commit messages?"

Claude:
"Yes! The /commit command is perfect for this. Let me explain:

**Command:** /commit
**Purpose:** Analyzes your git changes and creates commits with AI-generated messages that match your repository's style

**Usage:**
- /commit                      # Auto-generate commit message
- /commit feat:                # Start with 'feat:' prefix
- /commit fix: bug description # Custom message prefix

**How it works:**
1. Analyzes staged and unstaged changes
2. Studies your commit history for style patterns
3. Generates a semantic commit message
4. Creates the commit

Would you like to run this command now?"
```

### Example 4: User Asks How to Use a Specific Command

```
User: "How do I use the /commit command?"

Claude:
[Reads the command documentation from .claude/commands/commit.md or plugins/*/commands/commit.md]

"The /commit command analyzes your changes and creates intelligent commits. Here's how to use it:

**Basic Usage:**
/commit

**With Arguments:**
/commit feat:              # For new features
/commit fix:               # For bug fixes
/commit [TICKET-123]       # Include ticket reference

**What it does:**
1. Examines your git diff
2. Learns from your commit history
3. Generates a semantic message
4. Creates the commit

**Requirements:**
- Must be in a git repository
- Git must be configured
- At least one existing commit for style learning

Try running /commit now to see it in action!"
```

## Command Discovery Algorithm

When helping users find commands, Claude follows this process:

### Step 1: Locate Command Files

```
Search locations:
1. .claude/commands/*.md
2. plugins/*/commands/*.md
3. ~/.claude/commands/*.md (user-level commands)
```

### Step 2: Parse Command Metadata

Extract from frontmatter:
```yaml
---
name: command-name
description: What the command does
argument-hint: "[optional arguments]"
allowed-tools: Tool1, Tool2, Tool3
---
```

### Step 3: Match User Intent

Compare user's request against:
- Command names
- Command descriptions
- Command keywords
- Common tasks

### Step 4: Present Results

Show:
- Matching commands
- Brief descriptions
- Usage syntax
- Relevant examples

## Best Practices for Command Guidance

### Clear Explanation

When explaining commands:
- State what the command does clearly
- Explain when to use it
- Provide concrete examples
- Mention any prerequisites or requirements

### Contextual Help

- If user typed a command as text, explain the difference between messages and commands
- If user asks about commands, provide a comprehensive list
- If user has a task, suggest the most relevant command
- If no command exists, explain how to create custom commands

### Encourage Exploration

- Suggest related commands
- Explain how to create custom commands
- Mention plugin marketplace for more commands
- Show how to view command documentation

### Handle Edge Cases

- Command doesn't exist: Suggest similar commands or explain how to create it
- Multiple commands match: Explain differences and help user choose
- Command requires setup: Guide through prerequisites
- Command has complex usage: Provide step-by-step guidance

## Command File Format Reference

For users who want to create custom commands, explain the format:

```markdown
---
name: my-command
description: Brief description of what it does
argument-hint: "[optional hint text]"
allowed-tools: Tool1, Tool2
---

# Command Title

Detailed documentation about the command...

## Usage

Examples and usage instructions...
```

## Technical Details

### Command File Locations

1. **Workspace Commands**: `.claude/commands/*.md`
   - Project-specific commands
   - Committed to repository
   - Shared with team

2. **Plugin Commands**: `plugins/*/commands/*.md`
   - Provided by installed plugins
   - Marketplace or custom plugins
   - Auto-discovered when plugin installed

3. **User Commands**: `~/.claude/commands/*.md`
   - Personal global commands
   - Available in all workspaces
   - User-specific preferences

### File Discovery Strategy

```
Priority order:
1. Workspace commands (.claude/commands/)
2. Plugin commands (plugins/*/commands/)
3. User commands (~/.claude/commands/)

Shadowing: Workspace commands override plugin/user commands with same name
```

### Metadata Parsing

Required fields:
- `name`: Command identifier
- `description`: Brief explanation

Optional fields:
- `argument-hint`: Help text for arguments
- `allowed-tools`: Tools the command can use
- `requires`: Prerequisites or dependencies

## Integration with Claude Code

### Command Execution

This skill helps users understand that:
- Slash commands are executed, not sent as messages
- Commands have special syntax and capabilities
- Commands can be customized and extended
- Plugins provide additional commands

### Command vs. Direct Request

Explain when to use commands vs. direct requests:

**Use Slash Commands When:**
- Repeating a common workflow
- Need consistent behavior
- Want to share with team
- Command provides specialized tools

**Use Direct Requests When:**
- One-time task
- Exploratory work
- Need full AI flexibility
- Task doesn't fit command pattern

## Troubleshooting Guidance

### "Command not found"

Help users:
1. Check command name spelling
2. Verify command file exists
3. Check file is in correct location
4. Ensure proper frontmatter format

### "Command doesn't work as expected"

Guide users to:
1. Read command documentation
2. Check required arguments
3. Verify prerequisites met
4. Review allowed-tools permissions

### "How do I create a custom command?"

Provide steps:
1. Create `.claude/commands/` directory
2. Create `command-name.md` file
3. Add frontmatter with metadata
4. Write command instructions
5. Test the command

## Plugin Marketplace Integration

When users ask about more commands:
- Mention the Claude Code plugin marketplace
- Explain how to browse available plugins
- Show how to install command plugins
- Suggest relevant plugins for their task

Example plugins that provide commands:
- commit-command: Smart git commits
- review-command: Code review automation
- test-command: Test generation and running
- deploy-command: Deployment workflows

## Learning Resources

Point users to:
- Claude Code documentation on commands
- Command creation tutorials
- Plugin development guides
- Community command libraries
- Best practices for command design

## Requirements

- Claude Code with commands support
- Workspace with .claude/commands/ directory (optional)
- Read access to command files
- Understanding of slash command syntax

## Limitations

- Cannot execute commands directly (only explain them)
- Relies on command file documentation
- May not find commands with non-standard locations
- Cannot modify command behavior

## Success Indicators

The skill is working well when:
- Users understand how to execute commands
- Users can discover relevant commands for their tasks
- Users know how to view command documentation
- Users can differentiate between commands and direct requests
- Users feel empowered to create custom commands
