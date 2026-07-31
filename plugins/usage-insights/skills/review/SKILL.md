---
name: review
description: >
  Use this skill when the user runs /review or asks to "review a pull request",
  "review PR #123", "do a code review of this PR", or "give feedback on this
  GitHub pull request". Reproduces Claude Code's built-in /review WITHOUT the
  built-in tooling: it fetches a GitHub pull request's context and diff with the
  gh CLI and produces a thorough, structured code review. For reviewing your own
  uncommitted working diff instead, use /code-review (a separate built-in).
---

# Review

Standalone re-implementation of Claude Code's built-in `/review`. Given a GitHub
pull request number, it fetches the PR's metadata and diff with the `gh` CLI and
writes a thorough, well-structured code review — the same review the built-in
command produces, driven by the same prompt text.

Nothing here calls the built-in command. The review prompt ships verbatim in
this plugin at `assets/prompts/review.md`.

## Architecture

```
/review <pr-number> [instructions]
        │
        ├─ gh pr view  <pr> --json title,body,author,base/head,state,+/-,files,labels
        ├─ gh pr diff  <pr>
        │
        └─ review-prompt (assets/prompts/review.md)  ──▶  structured review
```

## Prerequisites

- The `gh` CLI, authenticated for the target repository (`gh auth status`). In
  this marketplace's sessions `gh` is on `PATH` and `GH_TOKEN`/`GH_HOST`/`GH_REPO`
  are set by the github plugin; elsewhere the user must have `gh` configured.
- A PR number to review. The PR must live in the repository `gh` resolves to
  (`GH_REPO`, or the current checkout's origin).

## Procedure

### Step 1 — Resolve the target

Take the PR number from `$ARGUMENTS` (the first bare token, e.g. `123`). Any
remaining text is the user's additional instructions. If no PR number is given,
ask for one — this command reviews a *pull request*, not the working tree (for
the local diff, direct the user to `/code-review`).

### Step 2 — Load the review prompt

Read `${CLAUDE_PLUGIN_ROOT}/assets/prompts/review.md` and follow it as your own
instructions. Substitute:

- `${PR}` → the PR number from Step 1
- `${ARGS}` → the user's additional instructions (empty string if none)

### Step 3 — Gather context and diff

Run exactly what the prompt directs, using `gh` (not a local `git diff`):

1. `gh pr view <pr> --json title,body,author,baseRefName,headRefName,state,additions,deletions,changedFiles,labels`
2. `gh pr diff <pr>`

### Step 4 — Produce the review

Analyze the changes and write a review covering: an overview of what the PR
does, code quality and style, specific improvement suggestions, and potential
issues or risks. Keep it concise but thorough, focused on correctness, project
conventions, performance, test coverage, and security. Format with clear
sections and bullet points.

Deliver the review in your reply. Do **not** post it to GitHub unless the user
explicitly asks — the built-in `/review` only prints the review.

## Notes on fidelity

- The review criteria and structure are reproduced **verbatim** from the CLI
  binary (v2.1.220): the six focus areas (correctness, conventions, performance,
  test coverage, security) and the four required sections (overview, quality,
  suggestions, risks) match the built-in prompt exactly.
- The built-in command's description distinguishes it from `/code-review`:
  "Review a GitHub pull request; for your working diff use /code-review." This
  skill preserves that split — it reviews PRs by number, not local changes.
- `gh` is the intended diff source. Using a local `git diff` would review the
  wrong thing (your checkout, not the PR head against its base).

## Troubleshooting

| Symptom                                    | Fix                                                                       |
| ------------------------------------------ | ------------------------------------------------------------------------- |
| `gh: command not found`                    | Install/activate `gh`; in web sessions `eval "$(mise activate bash)"`.    |
| `gh` can't find the PR                     | Confirm `GH_REPO`/origin points at the right repo; pass a valid PR number. |
| User wants their uncommitted diff reviewed | That's `/code-review`, not `/review` — this command targets a PR number.  |
| No PR number supplied                      | Ask for one; there is no sensible default for a PR review.                |
