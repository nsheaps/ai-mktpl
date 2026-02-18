# git-spice Plugin

Skill for managing stacked Git branches with [git-spice](https://github.com/abhinav/git-spice) (`gs` CLI tool).

## Overview

This plugin provides Claude with comprehensive knowledge of git-spice, a CLI tool for managing stacked Git branches. It enables Claude to help users create, navigate, restack, and submit stacked PRs using `gs` commands.

## Features

- Complete command reference with shorthands (`gs bc`, `gs ss`, `gs rs`, etc.)
- Stacked branch workflows (create, submit, sync, restack)
- Configuration guidance (`spice.*` git config keys)
- GitHub and GitLab integration (authentication, PR management)
- Conflict resolution and squash-merge reconciliation
- Worktree support considerations

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/ai-mktpl/plugins/git-spice

# Or locally for testing
cc --plugin-dir /path/to/plugins/git-spice
```

## Prerequisites

- **Git 2.38+**
- **git-spice** installed: `brew install git-spice`
- Repository initialized: `gs repo init`
- Authenticated: `gs auth login` (for PR operations)

## When This Skill Activates

The skill activates when users:

- Ask to create or manage stacked branches
- Want to submit stacked PRs
- Need to restack, sync, or navigate branch stacks
- Reference `gs` commands or git-spice
- Want to configure git-spice settings

## Skill Contents

### SKILL.md

Core workflow guidance including:

- Key concepts (trunk, stack, upstack, downstack, restacking)
- Essential command quick reference
- Standard workflows (create, submit, review, sync)
- Submit flags and configuration basics
- Claude Code integration notes

### references/cli-reference.md

Complete CLI reference including:

- All commands with full flag documentation
- Complete shorthand table (30+ shorthands)
- Full configuration key reference
- Advanced workflows (inserting, splitting, reorganizing)
- Tool comparison and limitations

### references/pr-status-and-stack-views.md

How to combine `gs ls` with `gh pr view` for enriched stack views:

- Listing PRs in a git-spice stack using `gs ls --json`
- Getting PR details (title, URL, review status, CI status) via `gh pr view`
- Batch-fetching PR data for large stacks
- Interpreting review decisions and CI rollup status
- Example commands and output formats

### docs/specs/gs-branch-viewer.md

Product requirements document for the gs-branch-viewer companion tool (`gsv`) that
provides enriched stack views with PR and CI status in a single command.

## Related Plugins

- [scm-utils](../scm-utils/) - Source control utilities for branch/PR management
- [commit-skill](../commit-skill/) - Intelligent commit creation

## External Resources

- [git-spice Official Documentation](https://abhinav.github.io/git-spice/)
- [git-spice GitHub Repository](https://github.com/abhinav/git-spice)
- [CLI Reference](https://abhinav.github.io/git-spice/cli/reference/)
- [Configuration](https://abhinav.github.io/git-spice/cli/config/)

## License

See repository LICENSE file
