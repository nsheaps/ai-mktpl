# github

GitHub CLI installation, authentication, and workflow skill for Claude Code sessions.

Consolidates the former `gh-tool` and `github-auth-skill` plugins into a single plugin.

## Features

- **Auto-install on web sessions**: Installs gh to `$project/bin/.local/` on web sessions
- **Auto-update**: Checks for and installs updates when version is "latest"
- **Auth verification**: Optionally runs `gh auth status` after install
- **Background install**: Optional non-blocking installation
- **GitHub CLI skill**: Full gh CLI reference (PRs, issues, releases, actions, API)
- **Authentication skill**: Covers device code flow, PATs, fine-grained tokens, and GitHub App auth

## How It Works

On session start (web sessions only):

1. Checks if gh is already available on PATH
2. If not, downloads the release tarball from GitHub
3. Extracts the binary to `$CLAUDE_PROJECT_DIR/bin/.local/gh`
4. Adds `bin/.local/` to PATH via `CLAUDE_ENV_FILE`
5. Verifies authentication status

The `bin/.local/` directory is gitignored, so installed binaries don't pollute the repo.

## Skills

### gh (GitHub CLI Reference)

Full reference for `gh` CLI commands: pull requests, issues, repos, actions, releases, gists, and API access.

### github-auth (Authentication Methods)

Covers all GitHub authentication methods:

- **Device Code Flow** — interactive CLI sessions (`BROWSER=false gh auth login`)
- **Personal Access Tokens (classic)** — simple automation and CI
- **Fine-Grained PATs** — targeted repo access with granular permissions
- **GitHub App auth** — automated systems and bot identities (server-to-server and user-to-server)

The github-auth skill is shared with the `github-app` plugin to ensure consistent authentication guidance.

## Configuration

Create or update `plugins.settings.yaml` at project or user level:

```yaml
# In $CLAUDE_PROJECT_DIR/.claude/plugins.settings.yaml
# or ~/.claude/plugins.settings.yaml

github:
  enabled: true
  install_to_project: true
  background_install: false
  version: "latest"
  auto_auth_check: true
```

## Local Sessions

On local sessions (`CLAUDE_CODE_REMOTE` is not `true`), the install hook does nothing. It assumes gh is already installed locally via Homebrew, mise, or another method.

## Related Plugins

- **[github-app](../github-app)** — GitHub App token refresh for long-running agent sessions
