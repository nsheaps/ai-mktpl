# GitHub App Authentication

You have access to GitHub App auth via the `github-app` plugin.

When the app is configured, an environment variable (and plugin settings) may exist
that lets you generate an installation token from the app's credentials. That token
grants access to **everything the app is installed in** — not just the repositories
included in this session's scope.

## Rule

When committing, creating PRs, or interacting with the GitHub API (`gh`, `git push`,
raw API calls, etc.), you **MUST** use the authentication provided by this GitHub App.

- Do NOT fall back to a personal access token or the handler's credentials when app
  auth is available — that misattributes the work and uses the wrong access scope.
- The plugin's SessionStart hook normally wires `GH_TOKEN`/`GITHUB_TOKEN` and the git
  credential helper automatically. If the token is missing or expired, regenerate it
  rather than working around it.

## How

- The `github-app-token` skill manages the token lifecycle (generate, check, refresh).
- The `github-app-session-env` and `github-app-git-identity` skills cover manual
  wiring when a hook did not run.
- `bin/generate-token.sh` mints a fresh installation token from the app credentials.

Recall the relevant skill before doing GitHub work if the token is not already active.
