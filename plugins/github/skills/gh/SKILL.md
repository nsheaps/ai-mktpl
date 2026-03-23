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

## Web Session Proxy — CRITICAL

**In Claude Code web sessions, the git remote is a local proxy, NOT github.com.** This means `gh` subcommands that infer the repo from the git remote (`gh pr create`, `gh pr list`, `gh issue list`, `gh pr view`, etc.) **will fail or target the wrong host**.

### What Works and What Doesn't

| Approach                                            | Web Session                      | Local Session |
| --------------------------------------------------- | -------------------------------- | ------------- |
| `gh api --hostname github.com repos/OWNER/REPO/...` | **Works**                        | Works         |
| `gh pr create`, `gh pr list`, `gh issue list`, etc. | **Fails** (proxy remote)         | Works         |
| `gh api repos/OWNER/REPO/...` (no --hostname)       | **May fail** (resolves to proxy) | Works         |

### Always-Safe Pattern

**Always use `gh api` with `--hostname github.com` and explicit `repos/OWNER/REPO` paths.** This works in both web and local sessions:

```bash
# Instead of: gh pr list
gh api "repos/OWNER/REPO/pulls?state=open" --hostname github.com --jq '.[].title'

# Instead of: gh pr create --title "..." --body "..."
gh api repos/OWNER/REPO/pulls --hostname github.com \
  --method POST \
  --field title="Title" \
  --field head="branch-name" \
  --field base="main" \
  --field draft=true \
  --field body="Description"

# Instead of: gh issue list
gh api "repos/OWNER/REPO/issues?state=open" --hostname github.com --jq '.[].title'

# Instead of: gh issue create --title "..." --body "..."
gh api repos/OWNER/REPO/issues --hostname github.com \
  --method POST \
  --field title="Title" \
  --field body="Description"

# Instead of: gh pr view 123
gh api repos/OWNER/REPO/pulls/123 --hostname github.com

# Instead of: gh pr merge 123 --squash
gh api repos/OWNER/REPO/pulls/123/merge --hostname github.com \
  --method PUT \
  --field merge_method="squash"
```

### Detecting Web Sessions

```bash
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  echo "Web session — use gh api --hostname github.com"
fi
```

### Why This Happens

Claude Code web sessions route git operations through a local proxy for security. The `gh` CLI reads the git remote to determine the GitHub host, so it resolves to the proxy instead of `github.com`. Using `--hostname github.com` explicitly overrides this.

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

> **Reminder:** In web sessions, use `gh api --hostname github.com` instead of `gh pr` subcommands. See [Web Session Proxy](#web-session-proxy--critical) above.

### Creating PRs

```bash
# Via gh api (works in all sessions)
gh api repos/OWNER/REPO/pulls --hostname github.com \
  --method POST \
  --field title="Add feature X" \
  --field head="branch-name" \
  --field base="main" \
  --field draft=true \
  --field body="$(cat <<'EOF'
## Summary
- Fixed the thing

## Test plan
- [ ] Unit tests pass
EOF
)"

# Add labels after creation
gh api repos/OWNER/REPO/issues/PR_NUMBER/labels --hostname github.com \
  --method POST --field 'labels[]=bug'

# Local-only alternatives (won't work in web sessions):
# gh pr create --title "Add feature X" --body "Description here"
# gh pr create --draft --title "WIP: Feature Z"
# gh pr create --base develop --title "Feature for develop"
```

### Reviewing PRs

```bash
# View PR details
gh api repos/OWNER/REPO/pulls/123 --hostname github.com

# View PR files
gh api repos/OWNER/REPO/pulls/123/files --hostname github.com \
  --jq '.[].filename'

# Check PR status (CI checks)
gh api repos/OWNER/REPO/commits/SHA/check-runs --hostname github.com \
  --jq '.check_runs[] | {name, status, conclusion}'

# View PR comments
gh api repos/OWNER/REPO/pulls/123/comments --hostname github.com

# View PR review comments
gh api repos/OWNER/REPO/pulls/123/reviews --hostname github.com

# Create a review
gh api repos/OWNER/REPO/pulls/123/reviews --hostname github.com \
  --method POST \
  --field event="COMMENT" \
  --field body="LGTM!"

# Local-only alternatives:
# gh pr view 123
# gh pr diff 123
# gh pr checks 123
```

### Managing PRs

```bash
# List open PRs
gh api "repos/OWNER/REPO/pulls?state=open" --hostname github.com \
  --jq '.[] | {number, title, user: .user.login}'

# List PRs by author
gh api "repos/OWNER/REPO/pulls?state=open" --hostname github.com \
  --jq '[.[] | select(.user.login == "USERNAME")] | .[] | {number, title}'

# Update PR (title, body, etc.)
gh api repos/OWNER/REPO/pulls/123 --hostname github.com \
  --method PATCH \
  --field title="Updated title" \
  --field body="Updated body"

# Merge a PR (squash)
gh api repos/OWNER/REPO/pulls/123/merge --hostname github.com \
  --method PUT \
  --field merge_method="squash"

# Close without merging
gh api repos/OWNER/REPO/pulls/123 --hostname github.com \
  --method PATCH \
  --field state="closed"

# Local-only alternatives:
# gh pr list
# gh pr merge 123 --squash
# gh pr close 123
```

## Issue Workflows

> **Reminder:** In web sessions, use `gh api --hostname github.com` instead of `gh issue` subcommands.

### Creating Issues

```bash
# Via gh api (works in all sessions)
gh api repos/OWNER/REPO/issues --hostname github.com \
  --method POST \
  --field title="Bug: X crashes" \
  --field body="Steps to reproduce..." \
  --field 'labels[]=bug' \
  --field 'labels[]=priority:high'

# Local-only alternatives:
# gh issue create --title "Bug: X crashes" --body "Steps to reproduce..."
# gh issue create --title "Feature request" --label "enhancement"
```

### Managing Issues

```bash
# List open issues
gh api "repos/OWNER/REPO/issues?state=open" --hostname github.com \
  --jq '.[] | {number, title}'

# List issues with label
gh api "repos/OWNER/REPO/issues?labels=bug&state=open" --hostname github.com \
  --jq '.[] | {number, title}'

# View issue details
gh api repos/OWNER/REPO/issues/42 --hostname github.com

# Close issue with comment
gh api repos/OWNER/REPO/issues/42/comments --hostname github.com \
  --method POST --field body="Fixed in #123"
gh api repos/OWNER/REPO/issues/42 --hostname github.com \
  --method PATCH --field state="closed"

# Add/remove labels
gh api repos/OWNER/REPO/issues/42/labels --hostname github.com \
  --method POST --field 'labels[]=status:in-progress'

# Add comment
gh api repos/OWNER/REPO/issues/42/comments --hostname github.com \
  --method POST --field body="Working on this"

# Local-only alternatives:
# gh issue list --label "bug"
# gh issue view 42
# gh issue close 42 --comment "Fixed in #123"
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

> **Reminder:** In web sessions, use `gh api --hostname github.com` instead of `gh run`/`gh workflow` subcommands.

```bash
# List recent workflow runs
gh api repos/OWNER/REPO/actions/runs --hostname github.com \
  --jq '.workflow_runs[:10] | .[] | {id, name: .name, status, conclusion}'

# View a specific run
gh api repos/OWNER/REPO/actions/runs/12345 --hostname github.com

# View run jobs
gh api repos/OWNER/REPO/actions/runs/12345/jobs --hostname github.com \
  --jq '.jobs[] | {name, status, conclusion}'

# View job logs
gh api repos/OWNER/REPO/actions/jobs/JOB_ID/logs --hostname github.com

# Re-run a failed workflow
gh api repos/OWNER/REPO/actions/runs/12345/rerun --hostname github.com \
  --method POST

# Re-run only failed jobs
gh api repos/OWNER/REPO/actions/runs/12345/rerun-failed-jobs --hostname github.com \
  --method POST

# Trigger a workflow dispatch
gh api repos/OWNER/REPO/actions/workflows/ci.yaml/dispatches --hostname github.com \
  --method POST --field ref="main"

# List workflows
gh api repos/OWNER/REPO/actions/workflows --hostname github.com \
  --jq '.workflows[] | {name, state}'

# Local-only alternatives:
# gh run list
# gh run view 12345 --log
# gh workflow run ci.yaml --ref main
```

## GitHub API Access

The `gh api` command provides authenticated access to any GitHub API endpoint. **Always include `--hostname github.com`** to ensure correct routing in web sessions.

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

This is the most common issue. The git remote points to a local proxy, so `gh` subcommands that infer the repo from the remote will fail. **Use `gh api --hostname github.com` with explicit repo paths instead.** See [Web Session Proxy](#web-session-proxy--critical) at the top of this document.

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
