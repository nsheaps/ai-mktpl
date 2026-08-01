---
name: review
description: Review a GitHub pull request — fetch its context and diff with gh and produce a thorough, structured code review. For your working diff use /code-review.
argument-hint: "[pr number or url]"
allowed-tools: Read, Bash(gh:*), Bash(mise:*)
---

# Review

Reproduce Claude Code's built-in `/review` **without** the built-in tooling:
fetch a GitHub pull request's context and diff with the `gh` CLI and produce a
thorough, structured code review.

Invoke the **`pr-review`** skill and follow it end to end. The first argument is the
PR reference; any remaining text is passed to the review as extra instructions.

## Arguments

**Format:** `[pr number or url]`

| Argument          | Meaning                                            |
| ----------------- | -------------------------------------------------- |
| `<pr number/url>` | The pull request to review (required).             |
| trailing text     | Additional instructions for the review (optional). |

**Examples:**

- `/review 123` — review PR #123
- `/review 123 focus on the auth changes` — review PR #123 with a focus hint

For reviewing your own uncommitted working diff, use `/code-review` instead.

## What to do

1. Recall and follow the **`pr-review`** skill (`skills/pr-review/SKILL.md`).
2. Take the PR reference (a bare number or a full PR URL) from the first
   argument; treat the rest as extra instructions. If no PR reference is given,
   ask for one.
3. Load `${CLAUDE_PLUGIN_ROOT}/assets/prompts/review.md`, gather context with
   `gh pr view` and `gh pr diff`, and write the review.
4. Deliver the review with clear sections and bullet points. Do not post to
   GitHub unless explicitly asked.

$ARGUMENTS
