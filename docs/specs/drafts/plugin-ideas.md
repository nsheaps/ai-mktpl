# Additional Plugin Ideas

**Priority:** Medium
**Status:** Draft

## Overview

Ideas for new plugins to add to the marketplace.

## Proposed Plugins

### auto-test-runner

Automatically run relevant tests when files change.

**Features:**

- Watch for file changes
- Map files to their test suites
- Run affected tests automatically
- Report results inline

### pr-description-generator

Generate PR descriptions from commits.

**Features:**

- Analyze commit messages in branch
- Generate structured PR description
- Follow PR template format
- Include relevant context

### semantic-release

Automated semantic versioning and changelog generation.

**Features:**

- Parse conventional commits
- Determine version bump type
- Generate changelog entries
- Update version files

### code-coverage-tracker

Track and report code coverage changes in PRs.

**Features:**

- Run coverage on PR changes
- Compare to base branch
- Report coverage delta
- Warn on coverage decrease

### rules-sync-plugin

Automate syncing of `.ai/rules/` to user's `~/.claude/rules/` directory.

**Features:**

- MCP server for automation tasks
- Hooks to guide when to use skills or reference rules
- Symlink management (create, update, cleanup orphaned)
- Cross-device sync support

**Context:** Rules cannot be included as plugins directly. An MCP server could perform this automation, while hooks guide behavior application.
