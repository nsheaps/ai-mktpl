# Claude Code Plugin Marketplace

A curated collection of high-quality plugins for [Claude Code](https://code.claude.com), focusing on git automation and intelligent development workflows.

## Available Plugins

### 🚀 [Commit Command Plugin](./plugins/commit-command)
**Type:** Slash Command
**Category:** Git Automation

Automate git commits with AI-generated messages that match your repository's commit style and conventions.

- **Usage:** `/commit [optional message prefix]`
- **Features:**
  - Analyzes staged and unstaged changes
  - Learns from your commit history
  - Generates semantic commit messages
  - Supports Conventional Commits
  - Excludes sensitive files
  - Smart file staging

**Installation:**
```bash
cd ~/.claude/plugins
git clone https://github.com/nsheaps/.ai commit-command
# Or install via Claude Code plugin manager
```

---

### 🧠 [Smart Commit Skill](./plugins/commit-skill)
**Type:** Agent Skill
**Category:** Git Automation

Enables Claude to automatically analyze git changes and create well-formatted commits during development tasks.

- **Auto-activates when:**
  - Completing development tasks
  - Multiple file changes detected
  - Working in repositories with commit conventions
  - Preparing code for pull requests

- **Features:**
  - Intelligent change analysis
  - Convention detection
  - Atomic commit strategy
  - Security-aware (excludes sensitive files)
  - Adapts to repository style

**Installation:**
```bash
cd ~/.claude/skills
git clone https://github.com/nsheaps/.ai commit-skill
# Or install via Claude Code plugin manager
```

## Installation

### Method 1: Claude Code Plugin Manager (Recommended)

1. Open Claude Code
2. Run `/plugin marketplace add nsheaps/.ai`
3. Browse available plugins
4. Click "Install now" on desired plugin
5. Restart Claude Code

### Method 2: Manual Installation

#### Installing the Commit Command

```bash
# Navigate to Claude Code plugins directory
cd ~/.claude/plugins

# Clone the commit-command plugin
git clone https://github.com/nsheaps/.ai commit-command
cd commit-command
git sparse-checkout init --cone
git sparse-checkout set plugins/commit-command

# Or copy the plugin directory
cp -r /path/to/this/repo/plugins/commit-command ~/.claude/plugins/

# Restart Claude Code
```

#### Installing the Smart Commit Skill

```bash
# Navigate to Claude Code skills directory
cd ~/.claude/skills

# Clone the commit-skill plugin
git clone https://github.com/nsheaps/.ai commit-skill
cd commit-skill
git sparse-checkout init --cone
git sparse-checkout set plugins/commit-skill

# Or copy the skill directory
cp -r /path/to/this/repo/plugins/commit-skill ~/.claude/skills/

# Restart Claude Code
```

### Method 3: Add to Team Configuration

For team-wide distribution, add to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": [
    "nsheaps/.ai"
  ]
}
```

## Usage Guide

### Using the Commit Command

After installation, use the `/commit` command in any git repository:

```bash
# Basic usage - analyzes all changes and creates a commit
/commit

# With a message prefix
/commit feat: add new feature

# For bug fixes
/commit fix:

# For documentation
/commit docs:

# With ticket reference
/commit [TASK-123]
```

### Using the Smart Commit Skill

The skill activates automatically during development:

```
You: "Add user authentication with JWT tokens"

Claude: [implements the feature]
Claude: [automatically creates commit: "feat: add JWT-based user authentication"]
```

You can also request commits explicitly:

```
You: "Commit these changes"
Claude: [analyzes changes and creates appropriate commit(s)]
```

## Plugin Categories

- **Git Automation**: Tools for streamlining git workflows
- **Development Workflow**: Enhance daily development tasks
- **Code Quality**: Maintain high code standards

## Features

### Commit Command (`/commit`)

✅ Intelligent commit message generation
✅ Learns from repository history
✅ Supports Conventional Commits
✅ Excludes sensitive files (.env, credentials, etc.)
✅ Smart file staging
✅ Issue reference detection
✅ Custom message prefixes

### Smart Commit Skill

✅ Auto-activates during development
✅ Semantic change analysis
✅ Atomic commit strategy
✅ Convention detection and adaptation
✅ Security-aware file handling
✅ Multi-commit organization
✅ Repository style learning

## Requirements

- **Claude Code**: Latest version
- **Git**: Installed and configured
- **Repository**: Must be a git repository
- **Permissions**: Write access to repository

## Configuration

Both plugins work out of the box, but you can customize behavior:

### Custom Commit Conventions

The plugins automatically detect your conventions, but you can guide them:

```
"Use Conventional Commits format"
"Include ticket numbers in commits"
"Keep messages under 50 characters"
"Use emoji prefixes"
```

### Sensitive File Patterns

By default, these files are excluded:
- `.env*`
- `credentials.json`
- `secrets.yml`
- `*.pem`, `*.key`
- Private certificates
- API keys

Add custom patterns via `.gitignore` or specify during commits.

## Examples

### Example 1: Feature Development

```bash
# Make changes to implement a feature
# ...

# Create commit
/commit feat:

# Result: "feat: add user profile page with avatar upload"
```

### Example 2: Bug Fix

```bash
# Fix a bug
# ...

# Create commit with issue reference
/commit fix: resolve #456

# Result: "fix: handle special characters in login (#456)"
```

### Example 3: Multiple Commits

```bash
# Make complex changes across multiple files
# ...

# Let the skill organize into atomic commits
/commit

# Results:
# - "feat: create authentication service"
# - "test: add auth service unit tests"
# - "docs: update API documentation"
```

## Best Practices

### For Commands
1. **Review changes** with `git diff` before committing
2. **Use argument hints** to guide message generation
3. **Keep commits atomic** - one logical change per commit
4. **Unstage unwanted files** before running `/commit`

### For Skills
1. **Let Claude commit naturally** during development
2. **Provide context** about commit conventions if needed
3. **Trust the skill** to organize commits logically
4. **Review commit history** to ensure skill learned your style

## Troubleshooting

### Command not found
- Ensure plugin is installed in `~/.claude/plugins/commit-command`
- Restart Claude Code
- Check plugin is enabled in settings

### Skill not activating
- Verify installation in `~/.claude/skills/commit-skill`
- Ensure you're in a git repository
- Check there are changes to commit

### Messages don't match style
- Make a few manual commits to establish patterns
- Provide explicit instructions about your conventions
- The plugins learn from history over time

### Sensitive files being committed
- Check `.gitignore` configuration
- Review staged files before commit
- The plugins automatically exclude common sensitive files

## Contributing

Contributions are welcome! To add a plugin to this marketplace:

1. Fork this repository
2. Create a new plugin in `plugins/your-plugin-name/`
3. Add plugin metadata to `.claude-plugin/marketplace.json`
4. Include comprehensive documentation
5. Submit a pull request

### Plugin Structure

```
plugins/your-plugin-name/
├── .claude-plugin/
│   └── plugin.json
├── commands/           # For slash commands
│   └── your-command.md
├── skills/            # For agent skills
│   └── your-skill/
│       └── SKILL.md
└── README.md
```

## Plugin Development

### Creating a Slash Command

```markdown
---
name: your-command
description: Brief description under 100 chars
argument-hint: "[optional args]"
allowed-tools: Bash, Read, Write
---

# Your Command

Documentation and usage instructions...
```

### Creating a Skill

```markdown
---
name: your-skill-name
description: When and how Claude should use this skill
---

# Your Skill

Documentation about activation and capabilities...
```

## Support

- **Documentation**: [Claude Code Docs](https://code.claude.com/docs)
- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nsheaps/.ai/discussions)

## Roadmap

- [ ] PR review command
- [ ] Branch management skill
- [ ] Merge conflict resolver
- [ ] Changelog generator
- [ ] Release automation skill
- [ ] Git history analyzer

## License

MIT License - see [LICENSE](./LICENSE) file for details

## Acknowledgments

Built for the Claude Code community with ❤️

- **Claude Code**: [https://code.claude.com](https://code.claude.com)
- **Anthropic**: [https://anthropic.com](https://anthropic.com)

## Related Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [Plugin Development Guide](https://code.claude.com/docs/en/plugins)
- [Slash Commands Guide](https://code.claude.com/docs/en/slash-commands)
- [Agent Skills Guide](https://code.claude.com/docs/en/skills)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

**Made with Claude Code** | **Star this repo** ⭐ if you find it useful!
