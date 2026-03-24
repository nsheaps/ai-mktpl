---
name: gh
description: >
  Use this skill when the user asks about GitHub operations, pull requests,
  issues, releases, actions, gists, repos, or any task involving the GitHub
  CLI (gh). Also use when needing to interact with GitHub APIs, check CI
  status, review PRs, manage labels, create releases, or automate GitHub
  workflows from the command line.
---

# gh - GitHub CLI

The GitHub CLI (`gh`) brings GitHub workflows to the terminal. It provides
commands for pull requests, issues, repos, actions, and direct API access.

## Web Sessions

In Claude Code web sessions, the git remote is a local proxy, not github.com. The `gh` CLI infers the host and repo from the remote, so subcommands like `gh pr create` would fail without configuration.

### Solution: GH_HOST and GH_REPO Environment Variables

The github plugin's SessionStart hook **automatically sets** `GH_HOST` and `GH_REPO` in web sessions. Once set, all standard `gh` subcommands work normally:

```bash
# These all work in web sessions when GH_HOST and GH_REPO are set:
gh pr create --draft --title "Add feature X" --body "Description"
gh pr list
gh pr view 123
gh issue create --title "Bug: X" --body "Details"
gh issue list --label "bug"
gh run list
gh run view 12345 --log
```

If for some reason the env vars are not set (e.g., hook didn't run), set them manually:

```bash
export GH_HOST="github.com"
export GH_REPO="owner/repo"  # inferred from git remote by the hook
```

Reference: https://cli.github.com/manual/gh_help_environment

### Fallback: gh api

For edge cases or direct API access, `gh api` with `--hostname github.com` always works:

```bash
gh api repos/OWNER/REPO/pulls --hostname github.com --jq '.[].title'
```

## Quick Reference

### Authentication

```bash
# Check auth status
gh auth status

# Login with token (CI/web sessions)
# GH_TOKEN env var is preferred — gh respects it automatically
export GH_TOKEN="ghp_..."

# Login interactively (local only)
gh auth login

# Switch between accounts
gh auth switch
```

### Git Identity Setup

After authenticating with `gh`, configure git user identity from the GitHub profile:

```bash
# Set git user.name and user.email from the authenticated GitHub account
gh auth setup-git
gh api user --jq '.name'  | xargs git config user.name
gh api user --jq '.email // .login + "@users.noreply.github.com"' | xargs git config user.email
```

For GitHub App bot accounts (automated/CI), the identity follows the convention:

```bash
# App bot identity: <app-name>[bot] with ID-based noreply email
git config user.name "my-app[bot]"
git config user.email "12345+my-app[bot]@users.noreply.github.com"
```

To find the App's bot user ID:

```bash
gh api users/my-app[bot] --jq '.id'
```

### Core Commands

| Command           | Description                  |
| ----------------- | ---------------------------- |
| `gh pr create`    | Create a pull request        |
| `gh pr view`      | View PR details              |
| `gh pr list`      | List pull requests           |
| `gh pr merge`     | Merge a pull request         |
| `gh pr checkout`  | Checkout a PR branch         |
| `gh issue create` | Create an issue              |
| `gh issue list`   | List issues                  |
| `gh issue view`   | View issue details           |
| `gh repo clone`   | Clone a repository           |
| `gh run list`     | List workflow runs           |
| `gh run view`     | View workflow run details    |
| `gh api`          | Make authenticated API calls |

## Pull Request Workflows

> **Note:** In web sessions, `GH_HOST` and `GH_REPO` are set automatically by the github plugin. All `gh pr` subcommands work normally.

### Creating PRs

```bash
# Create a PR
gh pr create --title "Add feature X" --body "Description here"

# Create as draft
gh pr create --draft --title "WIP: Feature Z"

# Target a specific base branch
gh pr create --base develop --title "Feature for develop"

# Create with labels
gh pr create --draft --title "Fix bug" --label "bug"

# Multi-line body
gh pr create --draft --title "Add feature X" --body "$(cat <<'EOF'
## Summary
- Fixed the thing

## Test plan
- [ ] Unit tests pass
EOF
)"
```

### Reviewing PRs

```bash
# View PR details
gh pr view 123

# View PR diff
gh pr diff 123

# Check CI status
gh pr checks 123

# View PR as JSON
gh pr view 123 --json title,state,reviews,statusCheckRollup

# Create a review comment
gh pr review 123 --comment --body "LGTM!"
```

### Managing PRs

```bash
# List open PRs
gh pr list

# List PRs by author
gh pr list --author USERNAME

# Edit PR title/body
gh pr edit 123 --title "Updated title" --body "Updated body"

# Add labels
gh pr edit 123 --add-label "bug,priority:high"

# Merge (squash)
gh pr merge 123 --squash

# Close without merging
gh pr close 123
```

## Issue Workflows

> **Note:** In web sessions, `GH_HOST` and `GH_REPO` are set automatically by the github plugin. All `gh issue` subcommands work normally.

### Creating Issues

```bash
# Create an issue
gh issue create --title "Bug: X crashes" --body "Steps to reproduce..."

# Create with labels
gh issue create --title "Bug: X crashes" --label "bug" --label "priority:high"
```

### Managing Issues

```bash
# List open issues
gh issue list

# List issues with label
gh issue list --label "bug"

# View issue details
gh issue view 42

# Close issue with comment
gh issue close 42 --comment "Fixed in #123"

# Add/remove labels
gh issue edit 42 --add-label "status:in-progress"
gh issue edit 42 --remove-label "status:in-progress"

# Add comment
gh issue comment 42 --body "Working on this"
```

## Repository Operations

```bash
# Clone a repo
gh repo clone owner/repo

# Create a new repo
gh repo create my-project --public --clone

# Fork a repo
gh repo fork owner/repo --clone

# View repo info
gh repo view owner/repo

# List repos
gh repo list owner --limit 20

# Set repo settings
gh repo edit --enable-auto-merge --delete-branch-on-merge
```

## GitHub Actions

> **Note:** In web sessions, `GH_HOST` and `GH_REPO` are set automatically by the github plugin. All `gh run`/`gh workflow` subcommands work normally.

```bash
# List recent workflow runs
gh run list --limit 10

# View a specific run
gh run view 12345

# View run logs
gh run view 12345 --log

# Re-run a failed workflow
gh run rerun 12345

# Re-run only failed jobs
gh run rerun 12345 --failed

# Trigger a workflow dispatch
gh workflow run ci.yaml --ref main

# List workflows
gh workflow list
```

## GitHub API Access

The `gh api` command provides authenticated access to any GitHub API endpoint. When `GH_HOST` is set (automatic in web sessions), `--hostname` is not required. Include `--hostname github.com` as a fallback if env vars aren't set.

### Common API Patterns

```bash
# GET request
gh api repos/owner/repo --hostname github.com

# GET with jq filtering
gh api repos/owner/repo --hostname github.com --jq '.description'

# POST request (create)
gh api repos/owner/repo/labels --hostname github.com \
  -f name="priority:critical" -f color="FF0000"

# PATCH request (update)
gh api repos/owner/repo/issues/42 --hostname github.com \
  -X PATCH -f state="closed"

# DELETE request
gh api repos/owner/repo/labels/old-label --hostname github.com -X DELETE

# Paginated results
gh api repos/owner/repo/issues --hostname github.com --paginate --jq '.[].title'

# GraphQL query
gh api graphql --hostname github.com -f query='
  query {
    repository(owner: "owner", name: "repo") {
      pullRequests(first: 10, states: OPEN) {
        nodes { title number }
      }
    }
  }
'
```

### Useful API Endpoints

```bash
# Get file contents from a repo
gh api repos/owner/repo/contents/path/to/file --hostname github.com \
  --jq '.content' | base64 -d

# List PR review comments
gh api repos/owner/repo/pulls/123/comments --hostname github.com

# Get commit status
gh api repos/owner/repo/commits/SHA/status --hostname github.com

# List repository topics
gh api repos/owner/repo/topics --hostname github.com --jq '.names[]'

# Search code
gh api search/code --hostname github.com \
  -f q="pattern repo:owner/repo" --jq '.items[].path'

# Create a repository dispatch event
gh api repos/owner/repo/dispatches --hostname github.com \
  -f event_type="deploy" -f client_payload='{"env":"prod"}'
```

## Releases

```bash
# Create a release
gh release create v1.0.0 --title "Version 1.0.0" --notes "Release notes"

# Create release from tag with auto-generated notes
gh release create v1.0.0 --generate-notes

# Create draft release
gh release create v1.0.0 --draft

# Upload assets to a release
gh release upload v1.0.0 ./dist/app-linux-x64.tar.gz

# List releases
gh release list

# Download release assets
gh release download v1.0.0 --pattern "*.tar.gz"

# Delete a release
gh release delete v1.0.0 --yes
```

## Gists

```bash
# Create a gist
gh gist create file.txt --public --desc "My gist"

# Create from stdin
echo "content" | gh gist create --filename notes.md

# List gists
gh gist list

# View gist
gh gist view GIST_ID

# Edit gist
gh gist edit GIST_ID
```

## Configuration and Aliases

```bash
# Set default editor
gh config set editor vim

# Set default browser behavior
gh config set browser false

# Create aliases
gh alias set co 'pr checkout'
gh alias set mine 'issue list --assignee @me'

# List aliases
gh alias list
```

## Output Formatting

```bash
# JSON output
gh pr list --json number,title,author

# JSON with jq
gh pr list --json number,title --jq '.[].title'

# Table format (default for most commands)
gh pr list

# Web browser
gh pr view 123 --web
gh issue view 42 --web
```

## Plugin Settings

This plugin supports configuration via `plugins.settings.yaml`:

```yaml
github:
  enabled: true
  autoInstall: true # Download and install gh if not on PATH
  installToProject: true # Install to $project/bin/.local
  backgroundInstall: false # Install in background
  version: "latest" # Specific version or "latest"
  autoAuthCheck: true # Check auth on session start
```

Place in:

- `$CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml` (project-level)
- `~/.claude/plugins.settings.yaml` (user-level)

## Environment Variables

| Variable     | Description                                      |
| ------------ | ------------------------------------------------ |
| `GH_TOKEN`   | Authentication token (overrides `gh auth login`) |
| `GH_HOST`    | GitHub hostname (for GitHub Enterprise)          |
| `GH_REPO`    | Default repo in `owner/repo` format              |
| `GH_EDITOR`  | Editor for interactive commands                  |
| `GH_BROWSER` | Browser for `--web` commands                     |
| `GH_DEBUG`   | Set to enable debug logging                      |
| `NO_COLOR`   | Disable color output                             |

## Troubleshooting

### `gh pr create` / `gh issue list` fails in web sessions

The git remote points to a local proxy in web sessions. The github plugin's SessionStart hook sets `GH_HOST` and `GH_REPO` automatically to fix this. If the hook hasn't run yet, set them manually:

```bash
export GH_HOST="github.com"
export GH_REPO="owner/repo"
```

As a fallback, `gh api --hostname github.com` with explicit repo paths always works.

### Authentication issues

```bash
# Verify auth
gh auth status

# Check if GH_TOKEN is set (preferred in web sessions)
echo "${GH_TOKEN:+set}" || echo "not set"

# Check token scopes
gh auth status -t

# Re-authenticate (local only)
gh auth login
```

### "gh: command not found" in web sessions

This plugin auto-installs gh to `$CLAUDE_PROJECT_DIR/bin/.local/gh`.
Check that the session start hook ran successfully.

### Rate limiting

Use authenticated requests (default with `gh`) to get 5,000 req/hour
instead of 60. For heavy API usage, check remaining:

```bash
gh api rate_limit --hostname github.com --jq '.rate'
```

### Working with GitHub Enterprise

```bash
GH_HOST=github.mycompany.com gh auth login
```
