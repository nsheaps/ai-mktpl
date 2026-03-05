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

## Quick Reference

### Authentication

```bash
# Check auth status
gh auth status

# Login interactively
gh auth login

# Login with token (CI/web sessions)
echo "$GH_TOKEN" | gh auth login --with-token

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

### Creating PRs

```bash
# Create PR with title and body
gh pr create --title "Add feature X" --body "Description here"

# Create PR with body from heredoc
gh pr create --title "Fix bug Y" --body "$(cat <<'EOF'
## Summary
- Fixed the thing

## Test plan
- [ ] Unit tests pass
EOF
)"

# Create draft PR
gh pr create --draft --title "WIP: Feature Z"

# Create PR targeting specific base branch
gh pr create --base develop --title "Feature for develop"

# Create PR and fill from commits
gh pr create --fill

# Create PR with labels and reviewers
gh pr create --title "Fix" --label "bug" --reviewer "username"
```

### Reviewing PRs

```bash
# View PR details
gh pr view 123
gh pr view 123 --json title,body,reviews,mergeable

# View PR diff
gh pr diff 123

# List PR files
gh pr view 123 --json files --jq '.files[].path'

# Check PR status (CI checks)
gh pr checks 123

# View PR comments
gh api repos/{owner}/{repo}/pulls/123/comments

# Add a review comment
gh pr review 123 --comment --body "LGTM!"

# Approve a PR
gh pr review 123 --approve

# Request changes
gh pr review 123 --request-changes --body "Please fix X"
```

### Managing PRs

```bash
# List open PRs
gh pr list

# List PRs by author
gh pr list --author "@me"

# List PRs with specific label
gh pr list --label "needs-review"

# Merge a PR (merge commit)
gh pr merge 123

# Squash merge
gh pr merge 123 --squash

# Rebase merge
gh pr merge 123 --rebase

# Auto-merge when checks pass
gh pr merge 123 --auto --squash

# Close without merging
gh pr close 123

# Checkout PR branch locally
gh pr checkout 123
```

## Issue Workflows

### Creating Issues

```bash
# Create issue interactively
gh issue create

# Create with title and body
gh issue create --title "Bug: X crashes" --body "Steps to reproduce..."

# Create with labels
gh issue create --title "Feature request" --label "enhancement" --label "priority:high"

# Create with assignee
gh issue create --title "Fix Y" --assignee "@me"
```

### Managing Issues

```bash
# List open issues
gh issue list

# List issues with label
gh issue list --label "bug"

# List issues assigned to me
gh issue list --assignee "@me"

# View issue details
gh issue view 42

# Close issue with comment
gh issue close 42 --comment "Fixed in #123"

# Edit issue
gh issue edit 42 --title "New title" --add-label "status:in-progress"

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

```bash
# List recent workflow runs
gh run list

# View a specific run
gh run view 12345

# View run logs
gh run view 12345 --log

# Watch a running workflow
gh run watch 12345

# Re-run a failed workflow
gh run rerun 12345

# Re-run only failed jobs
gh run rerun 12345 --failed

# Trigger a workflow dispatch
gh workflow run ci.yaml --ref main

# List workflows
gh workflow list

# View workflow details
gh workflow view ci.yaml
```

## GitHub API Access

The `gh api` command provides authenticated access to any GitHub API endpoint.

### Common API Patterns

```bash
# GET request
gh api repos/owner/repo

# GET with jq filtering
gh api repos/owner/repo --jq '.description'

# POST request (create)
gh api repos/owner/repo/labels -f name="priority:critical" -f color="FF0000"

# PATCH request (update)
gh api repos/owner/repo/issues/42 -X PATCH -f state="closed"

# DELETE request
gh api repos/owner/repo/labels/old-label -X DELETE

# Paginated results
gh api repos/owner/repo/issues --paginate --jq '.[].title'

# GraphQL query
gh api graphql -f query='
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
gh api repos/owner/repo/contents/path/to/file --jq '.content' | base64 -d

# List PR review comments
gh api repos/owner/repo/pulls/123/comments

# Get commit status
gh api repos/owner/repo/commits/SHA/status

# List repository topics
gh api repos/owner/repo/topics --jq '.names[]'

# Search code
gh api search/code -f q="pattern repo:owner/repo" --jq '.items[].path'

# Create a repository dispatch event
gh api repos/owner/repo/dispatches -f event_type="deploy" -f client_payload='{"env":"prod"}'
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
  install_to_project: true # Install to $project/bin/.local
  background_install: false # Install in background
  version: "latest" # Specific version or "latest"
  auto_auth_check: true # Check auth on session start
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

### Authentication issues

```bash
# Verify auth
gh auth status

# Re-authenticate
gh auth login

# Check token scopes
gh auth status -t
```

### "gh: command not found" in web sessions

This plugin auto-installs gh to `$CLAUDE_PROJECT_DIR/bin/.local/gh`.
Check that the session start hook ran successfully.

### Rate limiting

Use authenticated requests (default with `gh`) to get 5,000 req/hour
instead of 60. For heavy API usage, check remaining:

```bash
gh api rate_limit --jq '.rate'
```

### Working with GitHub Enterprise

```bash
GH_HOST=github.mycompany.com gh auth login
```
