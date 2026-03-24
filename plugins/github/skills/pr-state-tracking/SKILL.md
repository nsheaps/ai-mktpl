---
name: pr-state-tracking
description: >
  PR state tracking via async hooks. Monitors comments, reviews, CI status,
  merge readiness, and body changes across all projects in a multi-repo session.
  Automatically detects and reports changes between checks.
---

# PR State Tracking

The github plugin includes async hooks that silently monitor PR state changes across all projects in your session.

## What It Tracks

- **Reviews**: New approvals, change requests, comments from reviewers
- **Comments**: Issue comments and inline review comments on code
- **CI Status**: Check run status and conclusion changes (pass/fail/pending)
- **PR Body**: Content changes to the PR description
- **Merge Status**: Mergeable state, conflicts, merge readiness
- **Labels**: Label additions and removals
- **Draft Status**: Draft <-> ready for review transitions
- **PR State**: Open/closed/merged transitions

## How It Works

### Session Start

On session start, the plugin:

1. Discovers all sibling git repositories (multi-project support)
2. Finds open PRs for each repo's current branch
3. Fetches a full state snapshot for each PR
4. Caches the snapshot as the baseline

### Post Tool Use

After each tool use, the plugin:

1. Re-fetches state for all tracked PRs
2. Compares against the cached snapshot
3. If changes are detected, reports them via stdout (shown as additionalContext)
4. Updates the cache with the new state

### Stop

On session stop, performs a final state check for any last-minute changes.

## Configuration

```yaml
# In plugins.settings.yaml (project or user level)
github:
  prStateTracking: true # Enable/disable (default: true)
  prStateCacheDir: "" # Custom cache dir (default: ~/.claude/plugin-cache/github)
```

### Cache Structure

```
~/.claude/plugin-cache/github/
  <project-slug>/
    pr-state/
      <owner>_<repo>_<pr_number>.json
```

For multi-project sessions, the project slug is derived from the project directory name.

## Multi-Project Sessions

When a session spans multiple repositories (e.g., ai-mktpl + github-actions + claude-utils), the plugin discovers all sibling git repos by scanning the parent directory of `CLAUDE_PROJECT_DIR`. Each repo on a non-default branch with an open PR is tracked.

## Requirements

- `gh` CLI on PATH (installed by this plugin or externally)
- `jq` on PATH (for JSON processing)
- GitHub authentication configured (`gh auth status` passing)

## Future: Channels Integration

When Claude Code supports channels (programmatic session wake/resume), the state tracking infrastructure can be extended to automatically trigger sessions:

- **Review received**: Wake session to address reviewer feedback
- **CI failed**: Wake session to investigate and fix failures
- **Merge conflict**: Wake session to rebase automatically
- **Label change**: Wake session when "ready-to-merge" label is applied

The current cache-and-compare pattern provides the foundation. State diffs would become channel triggers, transforming passive monitoring into autonomous response.
