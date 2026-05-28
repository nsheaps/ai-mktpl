# github

GitHub CLI installation, authentication, and PR state tracking for Claude Code sessions.

Consolidates the former `gh-tool` and `github-auth-skill` plugins into a single plugin.

## Features

- **Auto-install on web sessions**: Installs gh to `$project/bin/.local/` on web sessions
- **Auto-update**: Checks for and installs updates when version is "latest"
- **Auth verification**: Optionally runs `gh auth status` after install
- **Background install**: Optional non-blocking installation
- **PR state tracking**: Monitors comments, reviews, CI status, merge status across all session projects
- **Multi-project support**: Discovers PRs across sibling project directories in multi-repo sessions
- **GitHub CLI skill**: Full gh CLI reference (PRs, issues, releases, actions, API)
- **Authentication skill**: Covers device code flow, PATs, fine-grained tokens, and GitHub App auth

## How It Works

### GitHub CLI Installation

On session start (web sessions only):

1. Checks if gh is already available on PATH
2. If not, downloads the release tarball from GitHub
3. Extracts the binary to `$CLAUDE_PROJECT_DIR/bin/.local/gh`
4. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`
5. Verifies authentication status

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

### PR State Tracking

The plugin includes async hooks that monitor PR state changes across all projects in the session:

**SessionStart**: Discovers all active PRs for the session's projects and establishes a baseline snapshot of their state (comments, reviews, CI checks, body, merge status).

**PostToolUse**: Periodically re-fetches PR state (throttled to once per `prStateCheckInterval` seconds, default 60s) and compares against the cached snapshot. When changes are detected (e.g., a new review was submitted, CI completed, a comment was added), the agent is notified with details about what changed.

**Stop**: Performs a final state check before session end.

#### Multi-Project Discovery

In multi-repo sessions (e.g., sessions launched with ai-mktpl, github-actions, and claude-utils), the plugin scans the parent directory of `CLAUDE_PROJECT_DIR` for sibling git repositories. Each repo's current branch is checked for an open PR, and all discovered PRs are tracked.

#### State Cache

PR state snapshots are stored as JSON files in the cache directory:

```
~/.claude/plugin-cache/github/<project-slug>/pr-state/<owner>_<repo>_<pr>.json
```

Each snapshot includes:

- PR metadata (title, body, state, draft status, labels)
- Reviews (user, state, body)
- Comments (issue comments and inline review comments)
- CI check runs (name, status, conclusion)
- Merge status (mergeable, mergeable_state)

#### Change Detection

The following changes are detected and reported:

| Change             | Example                                          |
| ------------------ | ------------------------------------------------ |
| New review         | "nsheaps APPROVED"                               |
| New comment        | "bot: CI passed"                                 |
| New review comment | "nsheaps on src/main.ts: Consider using..."      |
| CI status change   | "lint: in_progress/pending -> completed/success" |
| PR body updated    | Body content changed                             |
| PR title changed   | Old title -> new title                           |
| Draft status       | Converted to draft / marked ready                |
| State change       | open -> closed, merged                           |
| Merge status       | mergeable changed, conflicts detected            |
| Label changes      | Labels added/removed                             |

### Future: Claude Code Channels

> **Planned feature**: When Claude Code adds support for channels (the ability to
> programmatically kick off or resume an idle session), the PR state tracking hooks
> could be extended to automatically wake a sleeping session when significant PR
> changes are detected. For example:
>
> - A review with "request changes" could trigger the session to resume and address feedback
> - CI failure could trigger auto-investigation and fix attempts
> - A merge conflict could trigger automatic rebase
>
> This would transform the current "check and report" pattern into a fully
> autonomous "detect and respond" workflow. The cache infrastructure built here
> provides the foundation — state diffs would become channel triggers instead of
> advisory messages.

## Skills

### gh (GitHub CLI Reference)

Full reference for `gh` CLI commands: pull requests, issues, repos, actions, releases, gists, and API access. Includes authentication methods (device code flow, PATs, fine-grained tokens, GitHub App auth).

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

github:
  enabled: true
  autoInstall: true
  installToProject: true
  backgroundInstall: false
  version: "latest"
  autoAuthCheck: true

  # PR state tracking
  prStateTracking: true
  prStateCheckInterval: 60 # seconds between PostToolUse checks
  # prStateCacheDir: "~/.claude/plugin-cache/github"
```

### Cache Directory

The default cache location is `~/.claude/plugin-cache/github`. The plugin appends `/<project-slug>/pr-state/` to create project-specific cache directories.

For project-specific overrides:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
github:
  prStateCacheDir: "~/.claude/plugin-cache/github/my-project"
  prStateCheckInterval: 120 # check less frequently
```

Both `~` and `$HOME` are supported in `prStateCacheDir` paths.

When installed at the user level, the plugin handles multiple projects automatically by using the project directory name as a cache key. Each project's PRs are tracked independently.

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), the install hook does nothing. It assumes gh is already installed locally via Homebrew, mise, or another method. PR state tracking runs on all sessions (local and web) as long as `gh` and `jq` are available on PATH.

## Related Plugins

- **[github-app](../github-app)** — GitHub App token refresh for long-running agent sessions
- **[scm-utils](../scm-utils)** — Source control management utilities (commit, rebase, PR workflows)
