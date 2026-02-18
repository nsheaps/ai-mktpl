# code-review

Automated code review bot using [Claude Code Action](https://github.com/anthropics/claude-code-action) in GitHub Actions. Reviews PRs for code quality, security, performance, and maintainability with structured inline feedback.

## Commands

### /code-review

Trigger a code review on a pull request.

```
/code-review [PR number | URL | branch]
```

If the repository has the review bot CI workflow, adds the `request-review` label to trigger it. Otherwise, performs a local review.

## Skills

### code-review

Explains how the review bot works, how to set it up in a new repository, and how to customize it.

**Triggers on:**

- "set up review bot"
- "configure code review CI"
- "how does the review bot work"
- "add automated PR review"

**Reference files included:**

- `references/workflow-template.yaml` — Complete GitHub Actions workflow
- `references/prompt-template.md` — Review prompt with interpolation variables
- `references/labels.yaml` — GitHub labels for review triggers
- `references/copilot-instructions.md` — Fallback instructions for Copilot when the review workflow itself is modified

## Installation

```bash
claude plugin add /path/to/code-review
```

## Requirements

- GitHub App with appropriate permissions (see skill for details)
- Repository secrets for API keys
- `gh` CLI with `gh-pr-review` extension (installed automatically in CI)
