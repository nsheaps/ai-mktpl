# Mega-Merge: Consolidate All Feature Branches

## Summary

This PR consolidates **25 feature branches** into a single cohesive megabranch, establishing solid patterns for the Claude Code Plugin Marketplace. The goal is to merge all outstanding work, clean it up, and solidify the repository structure for future iteration.

## Branches Merged

### Infrastructure (y79Ck series)
- `claude/cicd-workflows-y79Ck` - GitHub Actions CI/CD workflows
- `claude/mise-devenv-y79Ck` - mise development environment configuration
- `claude/linting-config-y79Ck` - Markdownlint configuration
- `claude/docs-templates-y79Ck` - Documentation and templates
- `claude/plugin-updates-y79Ck` - Plugin updates

### Plugins
- `feat/memory-manager-plugin` - Intelligent CLAUDE.md management
- `claude/linear-mcp-sync-plugin-V76SD` - Linear MCP integration with hash validation
- `claude/safety-evaluation-plugin-HKHTY` - Pre-tool-call safety evaluation
- `claude/sync-settings-plugin-kqBLT` - Settings synchronization
- `claude/task-parallelization-plugin-W5hnu` - Task parallelization skill
- `claude/command-help-skill-01EEWVXxTWN9yhCXoVeVihB8` - Slash command discovery
- `claude/github-auth-skill-bJHbO` - GitHub authentication skill

### GitHub Actions
- `add-claude-github-actions-1765868355538` - Claude PR assistant & review
- `claude/add-claude-code-action-0FkAG` - Claude Code action for PRs
- `claude/github-action-auth-01B9MmVjB43VJVjvyzYqJAtW` - Reusable auth action
- `claude/github-action-debug-0156D9BSdgbLpaY66vnNhG7f` - Reusable debug action
- `claude/github-actions-ci-workflow-01DeuSewT8Bh7rHxDFwdCaHV` - Comprehensive CI/CD
- `claude/github-actions-ci-workflow-01JMn2mzQfTaebebDrow2vKv` - CI/CD fixes

### Features/Rules
- `feat/todo-management-rule` - Todo management requirements
- `feat/conversation-history-lookup` - Conversation history search
- `fix/file-lookup-behavior` - File lookup guidelines
- `nate/politely-correct` - Engineering assumption correction guidelines

### Exploration
- `claude/explore-transport-flag-asDBb` - Remote environment snapshot
- `claude/explore-transport-flag-oyB1R` - Sessions API documentation

## Key Changes

### Plugins (13 total)
| Plugin | Category | Description |
|--------|----------|-------------|
| `commit-command` | git | AI-generated commit messages |
| `commit-skill` | git | Intelligent commit skill |
| `skills-maintenance` | productivity | Skill maintenance workflow |
| `correct-behavior` | productivity | Behavior correction command |
| `memory-manager` | productivity | Intelligent CLAUDE.md management |
| `linear-mcp-sync` | integration | Linear MCP with hash validation |
| `safety-evaluation-prompt` | security | Pre-tool-call safety (prompt) |
| `safety-evaluation-script` | security | Pre-tool-call safety (script) |
| `sync-settings` | productivity | Settings synchronization |
| `task-parallelization` | performance | Parallel Task execution |
| `command-help-skill` | productivity | Slash command discovery |
| `github-auth-skill` | integration | GitHub authentication |
| `og-image` | generation | OpenGraph image generation |

### CI/CD Infrastructure
- **GitHub Actions Workflows:**
  - `ci.yaml` - Comprehensive CI with linting and validation
  - `cd.yaml` - Continuous deployment pipeline
  - `claude.yml` - On-demand Claude assistance via `@claude` mentions
  - `claude-code-review.yml` - Automated PR review with badges

- **Reusable Actions:**
  - `check-version-bump` - Validates plugin version bumps
  - `claude-auth` - Authentication setup
  - `claude-debug` - Debug action for troubleshooting
  - `lint-files` - File linting
  - `update-marketplace` - Marketplace JSON updates
  - `validate-plugins` - Plugin validation

### Documentation Restructuring
- **Distributed rules:** AGENTS.md content moved to `.claude/rules/`:
  - `plugin-development.md` - KISS/YAGNI principles, Bun+TypeScript preferences
  - `versioning.md` - Semantic versioning rules
  - `ci-cd/conventions.md` - Workflow conventions
- **Simplified AGENTS.md:** Now an index pointing to distributed rules
- **Short CLAUDE.md:** Created `.claude/CLAUDE.md` for quick reference
- **Spec files:** TODOs moved to individual `docs/specs/drafts/*.md` files

### Development Environment
- **mise** integration for tool management (`.mise.toml`)
- **SessionStart hooks** for environment setup
- **Markdownlint** configuration (`.markdownlint-cli2.jsonc`)
- **justfile** for local development commands

### Standards
- Added `$schema` references to all plugin.json files
- Removed duplicate review.yaml (use claude-code-review.yml instead)

## Files Changed

- **110 files changed**
- **19,909 insertions(+)**, **17 deletions(-)**

## Testing

- [ ] GitHub Actions workflows run successfully
- [ ] Linting passes locally (`just lint`)
- [ ] Plugin validation passes (`just validate`)
- [ ] Version bump detection works

## Notes

- Plugins don't need to work yet, but GitHub Actions infrastructure should be functional
- Version bumps should be posted as comments (update if exists, never duplicate)
- This establishes patterns for future plugin development

## Continuation Prompt

To continue work on this branch:

```
@claude, please read MERGE_TASK_PROMPT.md and continue the work on this branch. Review your previous changes, evaluate the current state, and continue iterating until the merge is complete and clean.
```

## Side-Quest: Externalize CI Prompts

Document but don't solve here: Move prompts shared between CI workflows into external files with templating support for things like `!bash command` syntax.
