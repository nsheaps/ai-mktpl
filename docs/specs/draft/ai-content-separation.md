# AI Content Separation Proposal

## Overview

This document proposes how to separate content in `.ai/` between:
- **Repo-specific**: Stays in project's `.claude/` directory
- **User-level**: Synced to `~/.claude/` for use across all projects

## Proposed Separation

### User-Level Content (sync to ~/.claude/)

These are general behaviors that apply across all projects:

#### Rules (.ai/rules/ → ~/.claude/rules/)

| File | Reason |
|------|--------|
| bash-scripting.md | General shell scripting practices |
| claude-code-config.md | General Claude Code configuration guidance |
| code-quality.md | Universal code quality standards |
| how-to-politely-correct-someone.md | General interaction behavior |
| mantras-and-incremental-development.md | Universal development principles |
| memory-management.md | General memory/rules management |
| preferences.md | General tool preferences |
| todo-management.md | Universal task tracking behavior |
| tool-preferences.md | General tool usage preferences |
| when-something-doesnt-work.md | Universal error handling behavior |
| writing-rules.md | General guidance on writing rules |

#### Agents (.ai/agents/ → ~/.claude/agents/)

| File | Reason |
|------|--------|
| conversation-history-search.md | Searches user's conversation history (user-level data) |

#### Commands (.ai/commands/ → ~/.claude/commands/)

| File | Reason |
|------|--------|
| correct-behavior.md | General behavior correction (applies everywhere) |

### Repo-Specific Content (stays in .claude/)

These are specific to this marketplace repository:

#### Rules

| File | Reason |
|------|--------|
| ci-cd/conventions.md | This repo's CI/CD workflows |
| environment-setup-and-maintenance.md | This repo's hooks and setup |
| plugin-development.md | Marketplace plugin structure |
| versioning.md | This repo's versioning requirements |

## Implementation

### Directory Structure After Sync

```
~/.claude/
├── rules/
│   └── upstream--nsheaps-ai/
│       ├── bash-scripting.md
│       ├── claude-code-config.md
│       ├── code-quality.md
│       └── ...
├── agents/
│   └── upstream--nsheaps-ai/
│       └── conversation-history-search.md
└── commands/
    └── upstream--nsheaps-ai/
        └── correct-behavior.md

.claude/
├── rules/
│   └── upstream--nsheaps-ai/  (when syncing to project level)
│       └── ...
└── ...
```

### Naming Convention

- Upstream folder: `upstream--{repo-name}/`
- This clearly identifies synced content vs local content
- Allows multiple upstream sources without conflict

## Migration Steps

1. Create `bin/sync-ai.sh` script
2. Add manifest file `.ai/sync-manifest.yaml` to define what syncs where
3. Run sync script to populate target directories
4. Remove duplicates from project `.claude/rules/` if they're now user-level

## Open Questions

1. Should we use symlinks or copies?
   - **Symlinks**: Always up-to-date, but break if source moves
   - **Copies**: Independent, but can drift out of sync
   - **Recommendation**: Symlinks for local dev, with CI validation

2. Should preferences.md and tool-preferences.md be merged?
   - They appear to have overlapping content
   - Consider consolidating before sync
