# Claude Tools Plugin

A collection of CLI tools for Claude Code workflow management including diagnostics, worktree management, session handling, and process supervision.

## Installation

The binaries are now distributed via Homebrew. To install:

```bash
brew tap nsheaps/devsetup
brew install claude-utils
```

This will install all the CLI tools:
- `branch-status` - Display rich status for git branches
- `claude-diagnostics` - Diagnostic tool for troubleshooting
- `claude-simple-cli` - Simplified one-shot text interface
- `claude-worktree` - Combined git worktree + Claude session handling
- `claude-wrapper` - Process supervisor for interactive Claude CLI
- `worktree-switcher` - Interactive TUI for git worktree management

For documentation on each tool, see the [claude-utils repository](https://github.com/nsheaps/claude-utils).

## Dependencies

| Tool     | Purpose             | Installation          |
| -------- | ------------------- | --------------------- |
| `gum`    | Interactive prompts | `brew install gum`    |
| `gh`     | GitHub CLI          | `brew install gh`     |
| `jq`     | JSON processing     | `brew install jq`     |
| `git`    | Version control     | Usually pre-installed |
| `claude` | Claude CLI          | Pre-installed         |
| `fzf`    | Fuzzy finder        | `brew install fzf`    |

## Security Note

When using `claude-diagnostics`, always review the archive contents before sharing, as it may contain:

- API keys or tokens in settings files
- Personal paths and usernames
- Project-specific configuration

Use the exclusion options to filter sensitive data.
