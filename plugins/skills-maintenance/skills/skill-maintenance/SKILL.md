---
name: skill-maintenance
description: Use this skill when updating, improving, or maintaining existing Claude Code agent skills. Activates when the user asks to update, refactor, improve, or fix an existing skill. Does NOT activate for creating new skills from scratch.
---

# Skill Maintenance Guide

This skill helps you systematically maintain, update, and improve existing Claude Code agent skills. Use this when modifying skills that already exist, not for creating new ones.

## When to Activate This Skill

✅ **Activate when:**

- User asks to "update the X skill"
- User wants to "improve the Y skill"
- User requests to "refactor" or "fix" an existing skill
- User wants to add features to an existing skill
- User reports issues with a skill's behavior
- User wants to update skill documentation
- User wants to optimize skill performance

❌ **Do NOT activate when:**

- User wants to create a brand new skill (use regular skill creation workflow)
- User is asking general questions about skills
- User wants to delete or remove a skill entirely

## Maintenance Workflow

### Step 1: Understand the Current Skill

Before making changes, thoroughly understand the existing skill:

1. **Read the skill file** (usually `skills/skill-name/SKILL.md`)
2. **Review the frontmatter metadata:**
   - `name`: Skill identifier
   - `description`: When and how the skill activates
   - `examples` (if present): Usage patterns

3. **Analyze the skill content:**
   - Activation conditions
   - Behavior and capabilities
   - Tool permissions
   - Examples and use cases

4. **Check related files:**
   - Plugin metadata (`.claude-plugin/plugin.json`)
   - README.md for user-facing documentation
   - Any supporting scripts or binaries

### Step 2: Identify What Needs Updating

Common maintenance tasks:

**Documentation Updates:**

- Clarify activation conditions
- Add or improve examples
- Update descriptions to match current behavior
- Fix typos or formatting issues

**Behavioral Improvements:**

- Enhance activation triggers to be more precise
- Add new capabilities while maintaining backward compatibility
- Improve error handling instructions
- Optimize skill performance

**Structure Refinements:**

- Reorganize content for clarity
- Split large skills into focused sub-sections
- Add cross-references to related skills or commands
- Update frontmatter metadata

**Version Updates:**

- Increment version in `plugin.json` following semver
- Update marketplace metadata if needed
- Document changes in README.md

### Step 3: Make Changes Systematically

Follow these principles when updating skills:

#### A. Maintain Backward Compatibility

- Don't change core activation behavior without good reason
- If changing behavior, document migration path
- Test that existing use cases still work

#### B. Follow Claude Code Skill Best Practices

**Frontmatter Rules:**

```yaml
---
name: skill-name # Lowercase, hyphen-separated, matches directory name
description: Clear description of when and how the skill activates (1-2 sentences)
examples: # Optional but recommended
  - "Example trigger phrase 1"
  - "Example trigger phrase 2"
---
```

**Content Structure:**

1. **Introduction**: Brief overview of skill purpose
2. **Activation Conditions**: When the skill should activate
3. **Capabilities**: What the skill can do
4. **Examples**: Concrete usage examples
5. **Limitations**: What the skill cannot or should not do
6. **Related Resources**: Links to docs, related skills

**Writing Style:**

- Use clear, imperative instructions for Claude
- Be specific about tool usage and permissions
- Include examples of both good and bad usage
- Document edge cases and error handling

#### C. Reference Official Documentation

When updating skills, refer to these authoritative sources:

📚 **Primary Documentation Sources:**

1. **Claude Code Documentation**: https://code.claude.com/docs
   - General Claude Code features and usage
   - Settings and configuration
   - Slash commands and skills reference

2. **Claude Code on the Web**: https://code.claude.com/docs/en/claude-code-on-the-web
   - Web-specific considerations
   - SessionStart hooks and setup
   - Remote environment differences

3. **Anthropic Documentation**: https://docs.anthropic.com
   - Claude API reference
   - Model capabilities and limitations
   - Best practices for prompt engineering

4. **Claude Code SDK Documentation**: https://github.com/anthropics/claude-code-sdk
   - Agent SDK architecture
   - Building custom agents
   - Tool development

5. **Claude Code GitHub Action**: https://github.com/anthropics/claude-code-action
   - CI/CD integration patterns
   - Automated workflows
   - Best practices for automated code review

6. **Claude Cookbook (Anthropic)**: https://github.com/anthropics/anthropic-cookbook
   - Practical examples and recipes
   - Advanced usage patterns
   - Integration examples

**When to Reference Each:**

- **Skill activation and behavior** → Claude Code Docs
- **Web session considerations** → Claude Code on the Web
- **Model capabilities** → Anthropic Documentation
- **SDK integration** → Claude Code SDK Docs
- **CI/CD workflows** → Claude Code GitHub Action
- **Advanced patterns** → Claude Cookbook

### Step 4: Test Your Changes

Before finalizing updates:

1. **Validate Syntax:**
   - YAML frontmatter is valid
   - Markdown formatting is correct
   - No broken links or references

2. **Test Activation:**
   - Skill activates on intended triggers
   - Doesn't activate on unintended triggers
   - Activation description is accurate

3. **Verify Behavior:**
   - Skill performs as documented
   - Examples work as shown
   - Edge cases are handled

4. **Check Integration:**
   - Works with related skills/commands
   - No conflicts with other plugins
   - Tool permissions are appropriate

### Step 5: Update Version and Documentation

After making changes:

1. **Update `plugin.json`:**

   ```json
   {
     "name": "skill-name",
     "version": "1.1.0", // Increment according to semver
     "description": "Updated description if needed"
   }
   ```

   **Versioning Rules:**
   - **Patch (1.0.X)**: Bug fixes, typos, minor documentation improvements
   - **Minor (1.X.0)**: New features, enhanced behavior, new examples
   - **Major (X.0.0)**: Breaking changes to activation or behavior

2. **Update README.md:**
   - Reflect new features or changes
   - Add new examples if applicable
   - Update version history section

3. **Update Marketplace Metadata:**
   - Will be auto-synced by CD workflow
   - Verify description is still accurate

## Common Maintenance Patterns

### Pattern 1: Adding New Activation Triggers

```markdown
## When to Use This Skill

**Original:**

- User asks to "commit changes"

**Updated:**

- User asks to "commit changes"
- User asks to "create a commit"
- User says "make a commit"
- Development task is complete and changes need committing
```

### Pattern 2: Enhancing Capabilities

```markdown
## What This Skill Does

**Original:**

Analyzes staged changes and creates a commit message.

**Updated:**

Analyzes staged and unstaged changes, suggests which files to stage, creates semantic commit messages following repository conventions, and handles multiple logical changes with atomic commits.
```

### Pattern 3: Improving Documentation

```markdown
## Examples

**Original:**

Use this skill to commit your changes.

**Updated:**

**Example 1: Simple Feature Commit**

User: "Commit these changes"

Claude:

- [Analyzes changes]
- [Creates commit: "feat: add user authentication"]

**Example 2: Multiple Changes**

User: "Commit my work on the API and tests"

Claude:

- [Analyzes changes]
- [Creates commits:]
  - "feat: add user API endpoints"
  - "test: add API endpoint tests"
```

### Pattern 4: Fixing Activation Issues

If a skill activates too broadly or too narrowly:

```markdown
## Activation Conditions

**Too Broad (activates on everything):**

description: Use this skill for git operations

**Too Narrow (never activates):**

description: Use this skill when user says exactly "please create git commit now"

**Just Right:**

description: Use this skill when the user requests to commit changes, create commits, or when a development task is complete and code changes are ready to be committed. Activate during git workflow discussions.
```

## Best Practices for Skill Maintenance

### 1. Keep Skills Focused

- Each skill should have a clear, single purpose
- If a skill does too many things, consider splitting it
- Avoid feature creep - stay true to the skill's core purpose

### 2. Write for Claude, Not Humans

Skills are instructions for Claude, not user documentation:

❌ **User-facing:** "This is a skill that helps you commit code."
✅ **Claude-facing:** "Activate when user requests to commit changes. Analyze staged files, generate semantic commit message, execute git commit."

### 3. Be Specific About Tools

Don't just say "use tools" - specify which ones:

❌ **Vague:** "Use the appropriate tools to complete the task."
✅ **Specific:** "Use the Bash tool to run `git status` and `git diff`. Use the Read tool to analyze changed files. Use the Edit tool if commit message preview is requested."

### 4. Include Negative Examples

Help Claude know when NOT to use the skill:

```markdown
## When NOT to Use This Skill

- User is just asking about git (use general knowledge instead)
- User wants to learn git commands (provide explanation, don't execute)
- No changes to commit (inform user, don't force empty commit)
- User is viewing history (use different skill or tools)
```

### 5. Document Edge Cases

```markdown
## Special Situations

**Large Changesets:**

- If more than 20 files changed, ask user which to commit
- Don't create massive commits without confirmation

**Sensitive Files:**

- Always exclude .env, credentials, secrets from commits
- Warn user if sensitive patterns detected

**Merge Conflicts:**

- Don't auto-commit during merge conflicts
- Guide user through resolution first
```

### 6. Reference Related Skills

Help Claude understand the ecosystem:

```markdown
## Related Skills

- `smart-commit` skill: Use for automatic committing during development
- `pr-description` skill: Use after committing to create PR descriptions
- `/commit` command: Alternative manual commit interface
```

### 7. Keep Documentation Current

- Review skills quarterly for accuracy
- Update examples to reflect current best practices
- Remove deprecated features or workflows
- Add new examples as usage patterns emerge

## Troubleshooting Skill Issues

### Issue: Skill Never Activates

**Diagnosis:**

- Description may be too specific or use unusual terminology
- Activation conditions may be hidden in the middle of the document
- Skill name might conflict with another skill

**Fix:**

1. Move activation conditions to the frontmatter description
2. Use common, natural language for triggers
3. Add explicit examples in frontmatter
4. Test with various phrasings

### Issue: Skill Activates Too Often

**Diagnosis:**

- Description is too broad or generic
- Missing negative activation conditions
- Conflicts with other skills

**Fix:**

1. Narrow the description to specific scenarios
2. Add "When NOT to Activate" section
3. Be more specific about required context
4. Review other skills for conflicts

### Issue: Skill Behavior Inconsistent

**Diagnosis:**

- Instructions are ambiguous
- Tool permissions unclear
- Examples don't match description

**Fix:**

1. Use imperative, step-by-step instructions
2. Explicitly list allowed tools
3. Provide clear decision trees for different scenarios
4. Align examples with instructions

### Issue: Skill Conflicts with Other Skills/Commands

**Diagnosis:**

- Overlapping activation triggers
- Similar names causing confusion
- Competing behaviors

**Fix:**

1. Differentiate clearly in descriptions
2. Add cross-references explaining when to use each
3. Consider consolidating if overlap is significant
4. Use different trigger phrases

## Skill Maintenance Checklist

Before finalizing skill updates, verify:

- [ ] Frontmatter YAML is valid and complete
- [ ] Description clearly states when to activate
- [ ] Examples are concrete and realistic
- [ ] Activation conditions are neither too broad nor too narrow
- [ ] Tool permissions are explicitly stated
- [ ] Related skills/commands are referenced
- [ ] Negative examples included (when NOT to use)
- [ ] Edge cases documented
- [ ] Version bumped in `plugin.json` according to semver
- [ ] README.md updated to reflect changes
- [ ] Tested activation with various trigger phrases
- [ ] No conflicts with existing skills/commands
- [ ] Documentation references are current and accurate
- [ ] Markdown formatting is correct (passes linting)
- [ ] Changes are backward compatible (or migration documented)

## Quick Reference: Documentation URLs

Keep these handy when maintaining skills:

```markdown
- Claude Code Docs: https://code.claude.com/docs
- Claude Code Web: https://code.claude.com/docs/en/claude-code-on-the-web
- Anthropic Docs: https://docs.anthropic.com
- Claude Code SDK: https://github.com/anthropics/claude-code-sdk
- GitHub Action: https://github.com/anthropics/claude-code-action
- Claude Cookbook: https://github.com/anthropics/anthropic-cookbook
- JSON Schema for settings: https://json.schemastore.org/claude-code-settings.json
```

## Example: Complete Skill Maintenance Session

**User Request:** "Update the smart-commit skill to handle merge commits better"

**Your Workflow:**

1. **Read** `plugins/commit-skill/skills/smart-commit/SKILL.md`
2. **Identify** current merge commit handling (or lack thereof)
3. **Research** merge commit best practices in Claude Cookbook
4. **Update** skill with new merge commit section:

   ```markdown
   ## Handling Merge Commits

   When changes include merge commits:

   - Detect merge commit by checking git status for merge branch
   - Ask user if they want to create merge commit or abort
   - Use `git commit --no-edit` for standard merge messages
   - Or allow custom merge message if user requests
   ```

5. **Add example** to documentation
6. **Update** `plugin.json` version from 1.0.0 to 1.1.0 (minor change)
7. **Update** README.md with merge commit feature
8. **Test** by simulating merge scenario
9. **Commit** changes with appropriate message

**Result:** Skill now handles merge commits gracefully, documentation is clear, version properly bumped.

---

## Remember

- **Maintain, don't rebuild**: Work with existing structure unless major refactor needed
- **Test thoroughly**: Changes to skills affect automation behavior
- **Document everything**: Future maintainers (and Claude) will thank you
- **Follow semver**: Version bumps communicate change significance
- **Reference official docs**: Don't guess - use authoritative sources
- **Think about activation**: Most skill issues are activation-related

Happy maintaining! 🛠️
