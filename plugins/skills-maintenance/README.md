# Skills Maintenance Plugin

Agent skill for systematically maintaining, updating, and improving existing Claude Code agent skills.

## Overview

The **Skills Maintenance** plugin provides Claude with structured guidance for updating and improving existing skills. This skill activates when you need to modify, enhance, or fix skills that already exist—not for creating new skills from scratch.

## Features

✅ **Systematic Maintenance Workflow**

- Step-by-step process for understanding and updating skills
- Comprehensive checklists for validation
- Best practices for backward compatibility

✅ **Documentation References**

- Links to official Claude Code documentation
- Claude Code SDK and GitHub Action resources
- Anthropic documentation and cookbook examples

✅ **Common Patterns**

- Adding new activation triggers
- Enhancing capabilities
- Improving documentation
- Fixing activation issues

✅ **Troubleshooting Guidance**

- Diagnosing activation problems
- Resolving conflicts with other skills
- Handling edge cases and special situations

## When This Skill Activates

The skill-maintenance skill activates when:

- User asks to "update the X skill"
- User wants to "improve" or "refactor" an existing skill
- User requests to fix issues with a skill
- User wants to add features to an existing skill
- User wants to update skill documentation

**Does NOT activate when:**

- Creating new skills from scratch
- Asking general questions about skills
- Deleting or removing skills

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/.ai/plugins/skills-maintenance

# Or locally for testing
cc --plugin-dir /path/to/plugins/skills-maintenance
```

## Usage

Once installed, the skill activates automatically when you request skill maintenance tasks:

### Example 1: Updating a Skill

```
You: "Update the smart-commit skill to handle merge commits better"

Claude: [Activates skill-maintenance]
1. Reads the current smart-commit skill file
2. Identifies merge commit handling gaps
3. References best practices from documentation
4. Updates skill with new merge commit behavior
5. Updates plugin.json version
6. Updates README.md
7. Tests activation triggers
```

### Example 2: Improving Documentation

```
You: "The commit-skill examples are unclear, can you improve them?"

Claude: [Activates skill-maintenance]
1. Reviews current examples
2. Identifies areas of confusion
3. Adds concrete, realistic examples
4. Clarifies activation conditions
5. Updates version and documentation
```

### Example 3: Fixing Activation Issues

```
You: "The auto-test skill activates too often"

Claude: [Activates skill-maintenance]
1. Analyzes current activation description
2. Identifies overly broad triggers
3. Narrows activation conditions
4. Adds negative examples
5. Tests with various phrases
6. Updates and validates
```

## Maintenance Workflow

The skill guides Claude through a systematic 5-step process:

### Step 1: Understand the Current Skill

- Read skill file and metadata
- Analyze frontmatter and content
- Review related files and documentation

### Step 2: Identify What Needs Updating

- Documentation improvements
- Behavioral enhancements
- Structure refinements
- Version updates

### Step 3: Make Changes Systematically

- Maintain backward compatibility
- Follow Claude Code best practices
- Reference official documentation

### Step 4: Test Your Changes

- Validate syntax and formatting
- Test activation triggers
- Verify behavior and integration

### Step 5: Update Version and Documentation

- Bump version following semver
- Update README.md
- Update marketplace metadata

## Documentation References

The skill includes references to all major Claude Code and Anthropic documentation sources:

- **Claude Code Documentation**: https://code.claude.com/docs
- **Claude Code on the Web**: https://code.claude.com/docs/en/claude-code-on-the-web
- **Anthropic Documentation**: https://docs.anthropic.com
- **Claude Code SDK**: https://github.com/anthropics/claude-code-sdk
- **Claude Code GitHub Action**: https://github.com/anthropics/claude-code-action
- **Claude Cookbook**: https://github.com/anthropics/anthropic-cookbook

## Best Practices Included

The skill teaches Claude to:

1. **Keep Skills Focused**: One clear purpose per skill
2. **Write for Claude**: Instructions, not user docs
3. **Be Specific About Tools**: Explicit tool permissions
4. **Include Negative Examples**: When NOT to activate
5. **Document Edge Cases**: Special situations and handling
6. **Reference Related Skills**: Show ecosystem connections
7. **Keep Documentation Current**: Regular reviews and updates

## Troubleshooting Guide

Built-in troubleshooting for common issues:

- Skill never activates (description too specific)
- Skill activates too often (description too broad)
- Skill behavior inconsistent (ambiguous instructions)
- Skill conflicts with others (overlapping triggers)

Each issue includes diagnosis steps and fixes.

## Maintenance Checklist

Complete checklist for validating skill updates:

- Frontmatter YAML validity
- Clear activation description
- Concrete examples
- Tool permissions specified
- Related skills referenced
- Negative examples included
- Edge cases documented
- Version bumped correctly
- README updated
- Activation tested
- No conflicts
- Documentation references current
- Markdown formatting correct
- Backward compatibility maintained

## Version History

### 1.0.0 (2025-12-13)

- Initial release
- Comprehensive skill maintenance workflow
- Documentation references to all major sources
- Common patterns and examples
- Troubleshooting guidance
- Maintenance checklist

## Requirements

- **Claude Code**: Latest version
- **Existing Skills**: This skill maintains existing skills, doesn't create new ones

## Related Plugins

- **commit-command**: Example of a well-maintained slash command
- **commit-skill**: Example of a well-maintained agent skill
- Use this skill to maintain both of those plugins

## Contributing

Improvements to this skill are welcome! To contribute:

1. Fork this repository
2. Make changes to the skill
3. Test thoroughly
4. Submit a pull request

Follow the same maintenance workflow described in the skill itself!

## Support

- **Documentation**: [Claude Code Docs](https://code.claude.com/docs)
- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Discussions**: [GitHub Discussions](https://github.com/nsheaps/.ai/discussions)

## License

See repository LICENSE file

---

**Made by [Nathan Heaps](https://github.com/nsheaps)** | **Star the repo** ⭐ if you find this useful!
