---
name: code-review
description: >
  Use this skill when setting up, configuring, or troubleshooting the automated
  Claude Code review bot in GitHub CI. Covers the workflow, prompt template,
  labels, GitHub App auth, and review behavior. Use when the user asks about
  "review bot", "code review CI", "automated PR review", "claude review workflow",
  or wants to add automated code review to a repository.
---

# Code Review Bot — Claude Code Action

An automated PR review system powered by [claude-code-action](https://github.com/anthropics/claude-code-action) running in GitHub Actions. It reviews PRs for code quality, security, performance, and maintainability, posting structured inline feedback via GitHub's review API.

## How It Works

1. A GitHub Actions workflow triggers on PR events (open, sync, ready_for_review, labeled)
2. The workflow authenticates as a GitHub App for posting reviews
3. A prompt template is interpolated with PR context (repo, PR number, job metadata)
4. `claude-code-action` runs with the prompt, using MCP tools to read the PR and post review comments
5. The bot creates a pending review, adds inline comments, then submits the review

## Trigger Conditions

| Condition | Behavior |
|-----------|----------|
| Non-draft PR opened/updated | Automatic review |
| `request-review` label added | One-time review (label auto-removed) |
| `always-review` label on PR | Review on every push, even drafts |
| Draft PR (no label) | Skipped |

## Required Secrets

| Secret | Purpose |
|--------|---------|
| `REVIEW_GITHUB_APP_ID` | GitHub App ID for posting reviews |
| `REVIEW_GITHUB_APP_PRIVATE_KEY` | GitHub App private key |
| `REVIEW_ANTHROPIC_API_KEY` or `ANTHROPIC_API_KEY` | Anthropic API key for Claude |
| `CLAUDE_CODE_OAUTH_TOKEN` | Alternative: Claude Code OAuth token (used if no API key) |

## Required GitHub App Permissions

The GitHub App needs:
- **Contents**: Write (checkout, read files)
- **Pull requests**: Write (post reviews, manage labels)
- **Issues**: Write (comment management)
- **Actions**: Read (job context)

## Setup in a New Repository

1. **Create a GitHub App** (or reuse an existing one) with the permissions above
2. **Add secrets** to the repository (see Required Secrets)
3. **Copy the workflow** from `references/workflow-template.yaml` to `.github/workflows/claude-code-review.yaml`
4. **Copy the prompt** from `references/prompt-template.md` to `.github/prompts/claude-code-review.md`
5. **Copy the labels** from `references/labels.yaml` and apply them (or merge into existing `.github/labels.yaml`)
6. **Copy the actions** — the workflow depends on:
   - `.github/actions/github-app-auth/` — authenticates as a GitHub App
   - `.github/actions/interpolate-prompt/` — reads a prompt template and interpolates env vars with `envsubst`

## Review Behavior

The bot follows a structured review process:

1. **Get PR context** — diff, files, previous reviews, comments
2. **Review previous reviews** — track what was addressed, what's still open
3. **Track findings in a local doc** — prevents memory loss during long reviews
4. **Manage previous comments** — minimize outdated comments, resolve addressed threads
5. **Create pending review** — add inline comments on specific lines
6. **Submit review** — with structured summary including shields.io badges

### Review Verdicts

| Verdict | When |
|---------|------|
| `APPROVE` | No outstanding issues, ready to merge |
| `COMMENT` | Suggestions but not blocking (won't break if merged) |
| `REQUEST_CHANGES` | Must fix before merge (security, correctness, breaking changes) |

### Review Summary Format

Reviews use a collapsible `<details>/<summary>` format with:
- Shields.io badges for quality, security, simplicity, and confidence scores
- Emoji indicators: `✅` checked, `❔` question, `⚠️` warning, `❌` problem
- Footnotes with workflow run link and external references
- Follow-up recommendations section (always visible, outside details block)

## Concurrency

The workflow uses concurrency groups to prevent overlapping reviews on the same PR:

```yaml
concurrency:
  group: claude-review-{PR_NUMBER}
  cancel-in-progress: false
```

`cancel-in-progress: false` ensures a running review finishes before a new one starts.

## Customization

### Modifying the prompt

Edit `.github/prompts/claude-code-review.md`. Environment variables available for interpolation:
- `${REPO}` — repository full name (owner/repo)
- `${PR_NUMBER}` — pull request number
- `${JOB_CONTEXT}` — JSON with job metadata (run URL, etc.)

### Adjusting permissions

The workflow's `settings` JSON controls which tools the bot can use. Key sections:
- `permissions.allow` — tools and bash commands the bot can use
- `permissions.deny` — explicitly blocked tools (e.g., CI status checks, git push)
- `env` — environment variables for the claude-code session

### Adding allowed bots

The `allowed_bots` input controls which bot accounts the review bot recognizes when managing previous comments. Add bot names as comma-separated values.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Bot doesn't review draft PRs | Add `request-review` label, or use `always-review` label |
| Bot can't post reviews | Check GitHub App permissions and secrets |
| Reviews are too verbose | Adjust the prompt template in `.github/prompts/claude-code-review.md` |
| Bot reviews its own workflow changes | This is by design for security — consider using copilot instructions to handle this case |

## Reference Files

- **`references/workflow-template.yaml`** — Complete GitHub Actions workflow
- **`references/prompt-template.md`** — Review prompt with interpolation variables
- **`references/labels.yaml`** — GitHub labels for controlling review triggers
- **`references/copilot-instructions.md`** — Fallback instructions for when the review workflow itself is modified

## External References

- [claude-code-action](https://github.com/anthropics/claude-code-action) — The GitHub Action that runs Claude Code
- [claude-code-action docs](https://github.com/anthropics/claude-code-action/blob/main/docs/usage.md) — Usage documentation
- [Claude Code settings](https://code.claude.com/docs/en/settings) — Settings JSON reference
- [GitHub MCP tools](https://github.com/anthropics/claude-code-action#mcp-tools) — Available MCP tools for GitHub
