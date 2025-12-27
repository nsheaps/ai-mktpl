This is supposed to be a skill for CLAUDE to use when a /slashcommand is typed as a message instead of executed. This is important because slash commands take up space in the context, and the window can be saved if dynamically loaded. The critical thing is to use the slash command as a prompt for the general-purpose agent.

##### BELOW BE VIBES

# Command Help Skill Plugin

Intelligent skill that helps users understand and discover slash commands when they accidentally type them as messages instead of executing them, enabling shared knowledge between agent and user for how to perform tasks.

## Overview

The Command Help Skill is an agent skill that automatically activates when Claude detects that a user has typed a slash command as a regular message, or when they're looking for the right command to accomplish a task. It bridges the gap between user intent and command execution, making slash commands more discoverable and easier to use.

## Problem It Solves

Users often:

- Type `/command` as a message instead of executing it
- Don't know what commands are available
- Can't find the right command for their task
- Need help understanding how to use a specific command
- Want to discover new commands and capabilities

This skill automatically helps with all of these scenarios.

## Features

✅ **Automatic Detection**: Recognizes when users type slash commands as messages
✅ **Command Discovery**: Helps users find the right command for their task
✅ **Comprehensive Search**: Searches workspace, plugin, and user command directories
✅ **Usage Guidance**: Explains how to use commands with examples
✅ **Smart Suggestions**: Recommends relevant commands based on user intent
✅ **Documentation**: Provides detailed command information and best practices
✅ **Custom Command Support**: Helps users create their own commands

## Installation

### Via Claude Code Plugin Manager

1. Open Claude Code
2. Run `/plugin marketplace add nsheaps/.ai`
3. Find "Command Help Skill" plugin
4. Click "Install now"
5. Restart Claude Code

### Manual Installation

```bash
# Navigate to skills directory
cd ~/.claude/skills

# Copy the skill
cp -r /path/to/marketplace/plugins/command-help-skill ~/.claude/skills/

# Restart Claude Code
```

## How It Works

The skill operates transparently in your workflow:

### Automatic Activation

Claude activates this skill when:

- User types a message starting with `/` (e.g., "/commit", "/help")
- User asks "what commands are available?"
- User asks "is there a command for X?"
- User says "how do I use /command?"
- User needs help discovering or understanding commands

### What Claude Does

1. **Detects Command Intent**: Recognizes slash commands typed as messages
2. **Searches for Commands**: Looks in `.claude/commands/`, plugin directories, and user directories
3. **Parses Metadata**: Extracts command names, descriptions, arguments, and allowed tools
4. **Matches Intent**: Finds commands that match what the user wants to do
5. **Provides Guidance**: Explains how to use commands with practical examples
6. **Enables Discovery**: Helps users explore available commands and capabilities

## Usage Examples

### Example 1: User Types Command as Message

```
User: "/commit"

Claude:
"I notice you typed '/commit' as a message. This looks like a slash command!

The /commit command analyzes your git changes and creates an intelligent commit
with an AI-generated message that matches your repository's style.

To execute slash commands in Claude Code, you run them as commands rather than
sending them as messages. Would you like me to help you create a commit now?"
```

### Example 2: User Wants to Discover Commands

```
User: "What commands do I have available?"

Claude:
"Let me search for available slash commands in your workspace...

**Git & Version Control:**
- /commit [prefix] - Analyze changes and create intelligent commits

**Available in Workspace:**
[Lists commands from .claude/commands/]

**From Installed Plugins:**
[Lists commands from plugins/*/commands/]

Would you like more details about any specific command?"
```

### Example 3: Finding the Right Command

```
User: "Is there a command to help me write commit messages?"

Claude:
"Yes! The /commit command is perfect for this:

**Command:** /commit
**Purpose:** Analyzes git changes and creates commits with AI-generated messages

**Usage:**
- /commit                  # Auto-generate message
- /commit feat:            # Feature addition
- /commit fix: bug desc    # Bug fix

**How it works:**
1. Examines your changes
2. Studies your commit history
3. Generates semantic message
4. Creates the commit

Would you like to run this now?"
```

### Example 4: Understanding a Specific Command

```
User: "How does the /commit command work?"

Claude:
[Reads command documentation and explains]

"The /commit command automates git commit creation:

**What it analyzes:**
- Staged and unstaged changes
- Your commit message patterns
- Type of changes (feat, fix, refactor, etc.)

**What it generates:**
- Semantic commit messages
- Following your repo's conventions
- With appropriate prefixes and scope

**Requirements:**
- Git repository
- Git configured
- At least one existing commit

Try it with: /commit"
```

### Example 5: User Needs Help with Arguments

```
User: "What arguments can I pass to /commit?"

Claude:
"The /commit command accepts an optional argument for message prefix:

**No arguments:**
/commit
→ Fully auto-generated message

**With prefix:**
/commit feat:
→ Ensures message starts with 'feat:'

/commit fix: resolve login bug
→ Uses 'fix: resolve login bug' as prefix

**With ticket reference:**
/commit [TICKET-123]
→ Includes ticket number in message

The argument helps guide the AI to generate the commit message in your
preferred format."
```

## Command Discovery Process

### Search Locations

The skill searches for commands in:

1. **Workspace Commands**: `.claude/commands/*.md`
   - Project-specific commands
   - Shared with team via git

2. **Plugin Commands**: `plugins/*/commands/*.md`
   - Installed from plugin marketplace
   - Custom plugins

3. **User Commands**: `~/.claude/commands/*.md`
   - Personal global commands
   - Available in all workspaces

### Command Metadata Extraction

For each command, extracts:

- **Name**: Command identifier
- **Description**: What it does
- **Arguments**: Required/optional parameters
- **Allowed Tools**: What tools it can use
- **Usage Examples**: How to use it
- **Requirements**: Prerequisites

### Intent Matching

Matches user intent to commands based on:

- Command names
- Descriptions
- Keywords
- Common task patterns
- Usage context

## Capabilities

### Command Type Recognition

Recognizes common command patterns:

- Git/version control commands
- Code review commands
- Testing commands
- Deployment commands
- Documentation commands
- Custom workflow commands

### Usage Explanation

Provides:

- Syntax and argument format
- Practical examples
- Common use cases
- Best practices
- Prerequisites and requirements

### Error Guidance

Helps troubleshoot:

- "Command not found" errors
- Missing prerequisites
- Incorrect argument format
- Permission issues
- Configuration problems

### Custom Command Creation

Guides users on:

- Command file format
- Frontmatter structure
- File location
- Metadata fields
- Testing commands

## Command File Format Guide

When helping users create commands, explains this format:

```markdown
---
name: my-command
description: Brief description of what it does
argument-hint: "[optional hint text]"
allowed-tools: Tool1, Tool2, Tool3
---

# Command Title

Detailed documentation about what the command does...

## Usage

Examples and usage instructions...

## Arguments

**$ARGUMENTS** (optional): Description of arguments...
```

## Best Practices

### For Users

**Discovering Commands:**

```
✅ Ask "What commands are available?"
✅ Ask "Is there a command for X?"
✅ Ask "How do I use /command?"
```

**Using Commands:**

```
✅ Execute commands directly (not as messages)
✅ Read command descriptions first
✅ Check required arguments
✅ Review examples before running
```

**Creating Commands:**

```
✅ Put in .claude/commands/ for workspace
✅ Use clear, descriptive names
✅ Write detailed documentation
✅ Include usage examples
✅ Specify allowed tools
```

### For Command Authors

**Good Command Design:**

- Single, focused purpose
- Clear, intuitive name
- Helpful argument hints
- Comprehensive documentation
- Practical examples
- Specified tool permissions

**Documentation:**

- Explain what it does
- Show how to use it
- List requirements
- Provide examples
- Note limitations

## Integration with Claude Code

### Slash Command vs. Direct Request

The skill helps explain when to use each:

**Use Slash Commands For:**

- Repeatable workflows
- Consistent behavior
- Team-shared processes
- Specialized tool access

**Use Direct Requests For:**

- One-time tasks
- Exploratory work
- Complex, multi-step tasks
- Situations needing full AI flexibility

### Plugin Ecosystem

The skill integrates with:

- Plugin marketplace discovery
- Plugin command auto-detection
- Plugin documentation access
- Custom plugin support

## Configuration

### No Setup Required

The skill works automatically:

- No configuration files
- No manual setup
- Auto-discovers commands
- Adapts to your workspace

### Command Priority

When multiple commands have the same name:

1. Workspace commands (`.claude/commands/`)
2. Plugin commands (`plugins/*/commands/`)
3. User commands (`~/.claude/commands/`)

## Troubleshooting

### Skill Not Activating

**Problem**: Skill doesn't recognize command messages

**Solutions**:

- Verify installation in `~/.claude/skills/command-help-skill/`
- Ensure message starts with `/`
- Check Claude Code supports skills
- Restart Claude Code

### Commands Not Found

**Problem**: Skill can't find expected commands

**Solutions**:

- Check command file location
- Verify proper frontmatter format
- Ensure `.md` file extension
- Check file permissions

### Incomplete Information

**Problem**: Command info seems incomplete

**Solutions**:

- Check command file has proper metadata
- Verify frontmatter is valid YAML
- Ensure description field exists
- Add more documentation to command file

## Advanced Features

### Cross-Reference Commands

Suggests related commands:

```
"Looking for /commit? You might also like:
- /review - Code review automation
- /test - Run tests
```

### Task-Based Discovery

Matches tasks to commands:

```
User: "I need to run tests"
Claude: "The /test command can help with that..."
```

### Plugin Recommendations

Suggests plugins for tasks:

```
User: "Is there a command for deployment?"
Claude: "Not in your workspace, but the 'deploy-command'
plugin in the marketplace provides this. Would you like
to install it?"
```

## Workflow Integration

### With Development Tasks

```
User: Working on feature
User: Types "/commit" as message
Claude: Recognizes intent, explains /commit command
User: Executes /commit properly
```

### With Learning

```
User: "What can Claude Code commands do?"
Claude: Lists and explains all available commands
User: Discovers new capabilities
User: Tries commands for their workflows
```

### With Team Sharing

```
Team creates custom commands in .claude/commands/
New team member asks "What commands exist?"
Claude explains all team commands
Team member becomes productive faster
```

## Requirements

- **Claude Code**: Latest version with skills support
- **Command Files**: At least one command file (optional)
- **File Access**: Read access to command directories

## Allowed Tools

The skill uses:

- `Glob` - Find command files
- `Read` - Read command documentation
- `Grep` - Search command content

## Performance

- **Fast**: Caches command locations
- **Efficient**: Only activates when needed
- **Lightweight**: No performance impact
- **Transparent**: Seamless integration

## Limitations

- Cannot execute commands (only explains them)
- Relies on command file documentation quality
- Cannot modify command behavior
- Doesn't create commands automatically

## Related Plugins

- **[Commit Command](../commit-command)**: Smart git commit automation
- **[Commit Skill](../commit-skill)**: Automatic commit during development

## Use Cases

### For Individual Developers

- Learn available commands quickly
- Understand how to use commands
- Discover new capabilities
- Create custom commands

### For Teams

- Onboard new members faster
- Share custom workflows via commands
- Document common tasks
- Standardize development processes

### For Plugin Authors

- Help users discover plugin commands
- Provide better command documentation
- Improve command usability
- Reduce support questions

## Example Session

```
User: "/commit"

Claude (via Command Help Skill):
"I notice you typed '/commit' as a message. This is a slash command
that should be executed directly in Claude Code!

**What /commit does:**
Analyzes your git changes and creates intelligent commits with AI-generated
messages that match your repository's commit conventions.

**How to use it:**
/commit                    # Auto-generate full message
/commit feat:              # Feature addition
/commit fix: bug description

**What happens:**
1. Analyzes your code changes
2. Studies your commit history
3. Generates semantic message
4. Creates the commit

Would you like me to help you create a commit now using this
functionality?"

User: "Yes, let's commit my changes"

Claude: [Proceeds to analyze changes and create commit]
```

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Documentation**: [Main README](../../README.md)
- **Claude Code Docs**: [https://code.claude.com/docs](https://code.claude.com/docs)

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Changelog

### Version 1.0.0

- Initial release
- Automatic command detection
- Command discovery system
- Usage explanation
- Multi-location search
- Intent-based matching
- Documentation extraction

---

**Made with Claude Code** | Part of the [Claude Code Plugin Marketplace](../../README.md)
