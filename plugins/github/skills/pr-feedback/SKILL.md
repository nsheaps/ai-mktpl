---
name: pr-feedback
description: >
  Address PR feedback (review comments, inline suggestions, CI failures) systematically.
  Use when you need to fetch, triage, and respond to pull request reviews, comments,
  or failing CI checks. Covers the full feedback loop: gather context, evaluate each
  item, take action (fix, disagree, defer, or clarify), commit with attribution, and
  request re-review.
  <example>address the PR feedback</example>
  <example>fix the CI failures on my PR</example>
  <example>respond to the review comments</example>
  <example>handle the PR review</example>
  <example>address inline comments on PR #42</example>
  <example>the reviewer left feedback, can you fix it</example>
  <example>CI is failing on the PR</example>
---

# Addressing PR Feedback & CI Failures

This skill provides a systematic process for gathering, triaging, and resolving all feedback on a pull request — review comments, inline suggestions, and CI failures — then communicating what was done and requesting re-review.

## Step 1: Gather All Feedback

Collect everything in one pass before taking action. Use the GitHub MCP tools when available, falling back to `gh` CLI.

### 1a. Fetch Reviews and Review Comments

Reviews and review comments (inline) are separate API concepts. You need both.

**Using GitHub MCP tools (preferred):**

```
# Get the reviews themselves (APPROVE, REQUEST_CHANGES, COMMENT)
pull_request_read(method="get_reviews", owner, repo, pullNumber)

# Get inline review comment threads (includes resolved/unresolved status)
pull_request_read(method="get_review_comments", owner, repo, pullNumber)

# Get general PR comments (non-review, conversation-level)
pull_request_read(method="get_comments", owner, repo, pullNumber)
```

**Using `gh` CLI fallback:**

```bash
# Reviews (verdicts)
gh api repos/{owner}/{repo}/pulls/{pr}/reviews

# Inline review comments (with diff context)
gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate

# General issue-style comments
gh api repos/{owner}/{repo}/issues/{pr}/comments --paginate
```

**Key distinctions:**
- **Reviews** (`get_reviews` / `/pulls/{pr}/reviews`): The top-level review objects with a verdict (APPROVE, REQUEST_CHANGES, COMMENT) and an optional body.
- **Review comments** (`get_review_comments` / `/pulls/{pr}/comments`): Inline comments attached to specific lines in the diff. These are grouped into threads with `isResolved` / `isOutdated` metadata.
- **Issue comments** (`get_comments` / `/issues/{pr}/comments`): Conversation-level comments on the PR (not tied to specific code lines).

### 1b. Check CI Status

**Using GitHub MCP tools (preferred):**

```
# Get check runs (individual CI jobs) for the PR's head commit
pull_request_read(method="get_check_runs", owner, repo, pullNumber)

# Get combined commit status (status API integrations)
pull_request_read(method="get_status", owner, repo, pullNumber)
```

**Using `gh` CLI fallback:**

```bash
# List all checks on the PR
gh pr checks {pr} --repo {owner}/{repo}

# Detailed check run info (includes output, annotations)
gh api repos/{owner}/{repo}/commits/{head_sha}/check-runs --jq '.check_runs[] | select(.conclusion == "failure") | {name, output: .output.summary, details_url}'

# Combined status (for status API integrations like external CI)
gh api repos/{owner}/{repo}/commits/{head_sha}/status
```

### 1c. Fetch the PR Diff for Context

```
# Full diff to understand what changed
pull_request_read(method="get_diff", owner, repo, pullNumber)

# Files changed (for scoping)
pull_request_read(method="get_files", owner, repo, pullNumber)
```

### 1d. Build a Feedback Inventory

Before acting, compile a single list of all actionable items:

1. **Unresolved review threads** — inline comments not yet marked resolved
2. **Top-level review body comments** — from REQUEST_CHANGES or COMMENT reviews
3. **General PR comments** — conversation items needing response
4. **CI failures** — failing check runs or status checks
5. **CI annotations** — specific file/line warnings or errors from check output

Skip items that are:
- Already resolved threads
- Outdated comments on code that no longer exists in the diff
- Passing checks
- Comments from yourself / the current bot identity

## Step 2: Triage Each Feedback Item

For every item in the inventory, classify it into one of four categories:

### Category A: Don't Understand

The feedback is unclear, ambiguous, or references something you can't locate.

**Action:**
- Reply to the comment asking for clarification
- Be specific about what you don't understand
- Do NOT guess or make assumptions

```
# Reply to a review comment thread
add_reply_to_pull_request_comment(owner, repo, pullNumber, commentId, body)

# Or for general comments
add_issue_comment(owner, repo, issue_number, body)
```

Example response:
> I'm not sure I understand this feedback — could you clarify what you mean by "the abstraction is leaky here"? Are you referring to the error handling in `parse()` or the public API surface?

### Category B: Disagree — Feedback is Incorrect

You believe the feedback is wrong or based on a misunderstanding. This requires **evidence**.

**Action:**
- Reply with a clear, respectful explanation of why you disagree
- **MUST include references and sources** to support your position:
  - Links to official documentation
  - Links to relevant source code in the repo (use GitHub permalinks)
  - Links to language/framework specifications
  - Links to established best practices or style guides
  - Cite specific line numbers and file paths
- State your confidence level (e.g., "I'm fairly confident" vs "I'm certain")
- Acknowledge if there's nuance or if the reviewer might have a valid sub-point

Example response:
> I respectfully disagree with this suggestion. The current approach uses `structuredClone()` which is [supported in all target environments](https://developer.mozilla.org/en-US/docs/Web/API/structuredClone#browser_compatibility) per our browserslist config in [`package.json:L12`](https://github.com/owner/repo/blob/abc123/package.json#L12). Using `JSON.parse(JSON.stringify(...))` would silently drop `undefined` values and `Date` objects, which our data model relies on ([see `types.ts:L45-L52`](https://github.com/owner/repo/blob/abc123/src/types.ts#L45-L52)). I'm confident this is the correct choice here.

**Important:** If you cannot find strong evidence to back your disagreement, do NOT disagree. Re-evaluate whether the feedback is actually valid.

### Category C: Valid but Defer — Ticket for Follow-Up

The feedback is valid but addressing it now would be:
- Out of scope for the current PR
- A significant refactor that risks the current changeset
- Better handled as a separate, focused change

**This should be rare.** Most valid feedback should be addressed immediately (Category D). Only defer when there's a clear, articulable reason.

**Action:**
- Acknowledge the feedback is valid
- Explain concisely why it should be deferred
- Create a GitHub issue to track the follow-up
- Reply to the comment with the issue link

```bash
# Create a tracking issue
gh issue create --title "Follow-up: {description}" \
  --body "From PR #{pr} review by @{reviewer}: {feedback summary}\n\nOriginal comment: {permalink}" \
  --label "follow-up"
```

Example response:
> Good catch — this validation should be tightened. However, the input sanitization refactor is out of scope for this PR (which focuses on the auth flow). I've created #187 to track this. I'll address it in a dedicated PR to keep this change focused.

### Category D: Address the Feedback (Most Common)

The feedback is valid and should be fixed now.

**Process:**

1. **Acknowledge the feedback** — reply to confirm you understand and agree:

   > Valid point — the error message here doesn't include the actual status code, which makes debugging harder. Fixing this now.

2. **Make the code change** — fix the issue in your working tree

3. **Commit the fix in isolation** — each piece of feedback should get its own commit (or group tightly related fixes). Use the `scm-utils:commit` skill for committing.

   The commit message should reference what feedback prompted the change:

   ```
   fix: include HTTP status code in auth error messages

   Addresses review feedback on error message clarity.
   ```

   **CRITICAL:** Keep feedback-addressing commits focused. Do not bundle unrelated changes. The commit should contain ONLY the changes that address the specific feedback item. This makes it easy to link a permalink to exactly what changed.

4. **Push the commit(s)**

5. **Reply to the comment with what you did**, including a **GitHub permalink to the commit**:

   > Fixed — the error message now includes the HTTP status code and response body summary. See commit: https://github.com/{owner}/{repo}/commit/{sha}

   To get the commit permalink after pushing:
   ```bash
   # Get the SHA of your most recent commit
   git rev-parse HEAD

   # The permalink format is:
   # https://github.com/{owner}/{repo}/commit/{full_sha}
   ```

6. **Resolve the thread** if you have permission:
   ```
   resolve_review_thread(threadId)
   ```

## Step 3: Address CI Failures

CI failures follow a similar but distinct process:

### 3a. Identify the Failure

```
# Get check runs with failure details
pull_request_read(method="get_check_runs", owner, repo, pullNumber)
```

For each failing check:
1. Note the check name, conclusion, and details URL
2. Read the output summary and annotations (file/line-level errors)
3. If the summary is insufficient, fetch full logs:
   ```bash
   gh run view {run_id} --log-failed --repo {owner}/{repo}
   ```

### 3b. Diagnose and Fix

Common CI failure categories:

| Failure Type | Diagnosis | Fix |
|---|---|---|
| **Lint errors** | Read annotations for file:line | Fix the specific lint violations |
| **Type errors** | Read compiler output | Fix type mismatches |
| **Test failures** | Read test output for assertion details | Fix the code or update the test |
| **Build failures** | Read build log for the error | Fix compilation/bundling issues |
| **Flaky tests** | Check if the test passes locally and in recent CI runs | Re-run if flaky; fix if genuine |
| **Security/audit** | Read advisory details | Update dependencies or add exceptions |

### 3c. Commit and Push

Same rules as Category D above — commit the CI fix in isolation, push, and the CI will re-run automatically.

If a CI failure was caused by a **flaky test** (not related to your changes):
```bash
# Re-run just the failed jobs
gh run rerun {run_id} --failed --repo {owner}/{repo}
```

## Step 4: Request Re-Review

After addressing all feedback:

1. **Verify CI is passing** — wait for checks to complete after your fix commits:
   ```
   pull_request_read(method="get_check_runs", owner, repo, pullNumber)
   ```

2. **Self-review your changes** — read the updated diff to make sure fixes are correct:
   ```
   pull_request_read(method="get_diff", owner, repo, pullNumber)
   ```

3. **Request re-review** — use the `request-review` label to trigger the AI review bot (if configured in the repo):
   ```bash
   gh pr edit {pr} --add-label "request-review" --repo {owner}/{repo}
   ```

   Or using MCP tools:
   ```
   update_pull_request(owner, repo, pullNumber, reviewers=["original-reviewer"])
   ```

4. **Update the PR description** if your changes materially altered the approach or scope.

## Efficient Querying Patterns

### Batch Fetch (Recommended)

Make all read calls in parallel at the start to minimize round-trips:

```
# Fire these simultaneously — they have no dependencies on each other
pull_request_read(method="get", ...)           # PR metadata
pull_request_read(method="get_reviews", ...)    # Review verdicts
pull_request_read(method="get_review_comments", ...)  # Inline threads
pull_request_read(method="get_comments", ...)   # General comments
pull_request_read(method="get_check_runs", ...) # CI status
pull_request_read(method="get_diff", ...)       # The diff itself
pull_request_read(method="get_files", ...)      # Changed file list
```

### Pagination

Review comments and CI checks can be paginated. Always check for pagination and fetch all pages:

```
# MCP tools support perPage and page parameters
pull_request_read(method="get_review_comments", owner, repo, pullNumber, perPage=100)

# gh CLI with --paginate
gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate
```

### Filtering What Matters

After fetching, filter down to actionable items:
- **Review comments**: Only unresolved, non-outdated threads
- **Reviews**: Most recent review per reviewer (earlier ones are superseded)
- **CI checks**: Only `conclusion: "failure"` or `conclusion: "cancelled"`
- **Comments**: Skip bot comments and your own replies

## Quick Reference: MCP Tools for PR Feedback

| Task | MCP Tool | Method/Parameters |
|---|---|---|
| PR metadata | `pull_request_read` | `method="get"` |
| Review verdicts | `pull_request_read` | `method="get_reviews"` |
| Inline comment threads | `pull_request_read` | `method="get_review_comments"` |
| General comments | `pull_request_read` | `method="get_comments"` |
| CI check runs | `pull_request_read` | `method="get_check_runs"` |
| Combined commit status | `pull_request_read` | `method="get_status"` |
| PR diff | `pull_request_read` | `method="get_diff"` |
| Changed files | `pull_request_read` | `method="get_files"` |
| Reply to review comment | `add_reply_to_pull_request_comment` | `commentId`, `body` |
| Add general comment | `add_issue_comment` | `issue_number`, `body` |
| Resolve a thread | `resolve_review_thread` | `threadId` |
| Request reviewers | `update_pull_request` | `reviewers=[...]` |
| Submit a review | `pull_request_review_write` | `method="create"`, `event` |

## Workflow Summary

```
1. GATHER  →  Batch-fetch reviews, comments, inline threads, CI status, diff
2. INVENTORY  →  List all unresolved, non-outdated, actionable items
3. TRIAGE  →  Classify each: (A) unclear, (B) disagree, (C) defer, (D) address
4. ACT  →  For each item, take the appropriate action per its category
5. COMMIT  →  Isolated, focused commits per feedback item (use scm-utils:commit)
6. RESPOND  →  Reply to each comment with what you did + commit permalink
7. VERIFY  →  Confirm CI passes after fixes
8. RE-REVIEW  →  Add `request-review` label or request reviewers
```
