# Worktree Switcher Plugin

Interactive TUI for git worktree management with rich branch status display.

## Installation

This plugin is part of the nsheaps/.ai marketplace. The binaries are automatically symlinked to your PATH via the SessionStart hook.

## Binaries

### worktree-switcher

Interactive worktree selection and creation tool using [gum](https://github.com/charmbracelet/gum).

```bash
worktree-switcher [OPTIONS]
```

**Options:**

- `--no-status` - Skip fetching branch status (faster startup)
- `-h, --help` - Show help message

**Behavior:**

1. If already in a worktree: Shows banner with main checkout location
2. If in main git repo: Shows interactive menu to:
   - Create new worktree with new branch
   - Select existing worktree
   - Select from branches (sorted by priority)
   - Create worktree from remote branch

**Branch Priority (in menu order):**

1. Your open PRs
2. Your draft PRs
3. Your other branches (matching `username/` prefix)
4. Other local branches
5. Remote branches

**Worktree Location:**
Worktrees are created at: `../${repo_name}.worktrees/${branch_name}`

- Branch name slashes (`/`) are converted to dashes (`-`)
- Example: `feature/cool-thing` → `../my-repo.worktrees/feature-cool-thing`

### branch-status

Utility to display rich status information for git branches.

```bash
branch-status [OPTIONS] <branch>
```

**Options:**

- `--emoji` - Output as emoji string (default)
- `--json` - Output as JSON object
- `-h, --help` - Show help message

**Status Indicators (emoji mode):**

| Position | Indicator         | Meaning                                                             |
| -------- | ----------------- | ------------------------------------------------------------------- |
| 1        | 🟢/❌             | Remote: exists / doesn't exist                                      |
| 2        | 🟢/🔘/❓          | PR: open / draft / none                                             |
| 3        | ❌/🟡/🟢/❓       | CI: fail / running / pass / no CI                                   |
| 4        | ✅/🟢/🔴/🟡/🔵/🔘 | Review: satisfied / approved / rejected / comments / pending / none |
| 5        | ✅/❌/⚠️/🟢       | Merge: ready / conflicts / outdated / clean                         |

**Example output:**

```bash
$ branch-status --emoji feature/my-branch
🟢🟢🟢🟢✅

$ branch-status --json feature/my-branch
{
  "branch": "feature/my-branch",
  "remote_exists": true,
  "pr_status": "open",
  "pr_number": 42,
  "ci_status": "pass",
  "review_status": "approved",
  "mergeable": "ready"
}
```

## Dependencies

| Tool  | Purpose             | Installation          |
| ----- | ------------------- | --------------------- |
| `gum` | Interactive prompts | `brew install gum`    |
| `gh`  | GitHub CLI          | `brew install gh`     |
| `jq`  | JSON processing     | `brew install jq`     |
| `git` | Version control     | Usually pre-installed |

## Examples

```bash
# Start interactive worktree switcher
worktree-switcher

# Quick mode without status checks
worktree-switcher --no-status

# Check status of a specific branch
branch-status main

# Get JSON status for scripting
branch-status --json feature/api-update
```

## Integration with claude-worktree

This plugin is designed to work with the `claude-worktree` plugin, which combines worktree management with Claude session handling.
