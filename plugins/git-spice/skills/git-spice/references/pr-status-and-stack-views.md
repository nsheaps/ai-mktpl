# PR Status and Stack Views

How to list, inspect, and combine PR information for git-spice stacks using `gs` and `gh` CLI tools.

> Sources:
> - [git-spice CLI Reference](https://abhinav.github.io/git-spice/cli/reference/) -- `gs log short`, `gs log long`
> - [GitHub CLI Manual: gh pr list](https://cli.github.com/manual/gh_pr_list)
> - [GitHub CLI Manual: gh pr view](https://cli.github.com/manual/gh_pr_view)

---

## Listing Branches in a Stack

### gs ls (short view)

Shows branch names, parent-child relationships, and CR (Change Request) status.

```bash
# Current stack only
gs ls

# All stacks in the repo
gs ls -a
# or
gs ls --all

# JSON output (current stack)
gs ls --json

# JSON output (all stacks)
gs ls --json -a
```

### gs ls --json Output Format

Each line is a separate JSON object (one per branch). Fields:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Branch name |
| `current` | boolean | Whether this is the currently checked-out branch (only present if true) |
| `down` | object | Downstack (parent) branch: `{ "name": "...", "needsRestack": bool }` |
| `ups` | array | Upstack (child) branches: `[{ "name": "..." }, ...]` |
| `change` | object | CR info: `{ "id": "#123", "url": "https://...", "status": "open" }` |
| `push` | object | Push status: `{ "ahead": 0, "behind": 0 }` |

Example output (single line, formatted for readability):

```json
{
  "name": "feat/auth-middleware",
  "current": true,
  "down": { "name": "main" },
  "ups": [{ "name": "feat/auth-tests" }],
  "change": {
    "id": "#142",
    "url": "https://github.com/org/repo/pull/142",
    "status": "open"
  },
  "push": { "ahead": 0, "behind": 0 }
}
```

The trunk branch appears first with no `down` field and an `ups` array listing its direct children.

### gs ll (long view)

Same as `gs ls` but includes individual commits per branch. Supports `--json` and `--all` flags.

---

## Listing PRs with gh CLI

### gh pr list

List all open PRs for the current repo:

```bash
# All open PRs by current user
gh pr list --author @me --state open

# JSON output with specific fields
gh pr list --author @me --state open \
  --json number,title,url,isDraft,reviewDecision,headRefName,state

# All open PRs (not just yours)
gh pr list --state open --json number,title,url,headRefName,isDraft,reviewDecision
```

Key JSON fields available for `gh pr list`:

| Field | Type | Description |
|-------|------|-------------|
| `number` | int | PR number |
| `title` | string | PR title |
| `url` | string | Full PR URL |
| `headRefName` | string | Branch name |
| `isDraft` | boolean | Whether the PR is a draft |
| `state` | string | `OPEN`, `CLOSED`, `MERGED` |
| `reviewDecision` | string | `APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or empty |
| `labels` | array | Label objects with `name` field |
| `reviewRequests` | array | Pending reviewer objects |

### gh pr view

Get detailed information for a specific PR:

```bash
# By PR number
gh pr view 142 --json number,title,url,isDraft,reviewDecision,state,statusCheckRollup,reviewRequests,reviews

# By branch name
gh pr view feat/auth-middleware --json number,title,url,isDraft,reviewDecision,state,statusCheckRollup
```

Additional fields available in `gh pr view` (beyond `gh pr list`):

| Field | Type | Description |
|-------|------|-------------|
| `statusCheckRollup` | array | CI check results (see below) |
| `reviews` | array | Review objects with author, state, body |
| `reviewRequests` | array | Pending reviewer requests |
| `commits` | array | Commit objects |
| `additions` | int | Lines added |
| `deletions` | int | Lines deleted |
| `changedFiles` | int | Number of files changed |

### CI Status via statusCheckRollup

Each entry in `statusCheckRollup` is a check run:

```json
{
  "__typename": "CheckRun",
  "name": "Lint",
  "status": "COMPLETED",
  "conclusion": "SUCCESS",
  "workflowName": "CI",
  "startedAt": "2026-02-13T17:33:28Z",
  "completedAt": "2026-02-13T17:33:50Z",
  "detailsUrl": "https://github.com/org/repo/actions/runs/..."
}
```

Common `conclusion` values: `SUCCESS`, `FAILURE`, `CANCELLED`, `SKIPPED`, `NEUTRAL`, `TIMED_OUT`.
Common `status` values: `QUEUED`, `IN_PROGRESS`, `COMPLETED`.

### Review Status via reviews

Each entry in `reviews`:

```json
{
  "author": { "login": "alice" },
  "state": "APPROVED",
  "submittedAt": "2026-02-13T02:43:44Z"
}
```

Common `state` values: `APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`, `PENDING`, `DISMISSED`.

---

## Combining gs ls with gh pr view

To build a rich stack view, combine `gs ls --json` (for stack structure and PR numbers) with `gh pr view` (for review status, CI checks, and metadata).

### Strategy

1. Run `gs ls --json -a` to get all branches with their CR numbers and stack structure
2. For each branch with a `change.id`, extract the PR number
3. Run `gh pr view <number> --json ...` to get review/CI details
4. Merge the data

### Example: Batch Fetch PR Details

```bash
# Step 1: Get stack data with PR numbers
gs ls --json -a > /tmp/gs-stack.json

# Step 2: Extract PR numbers (one per line)
# Each line is a JSON object; filter those with a change field
jq -r 'select(.change) | .change.id | ltrimstr("#")' /tmp/gs-stack.json > /tmp/pr-numbers.txt

# Step 3: Fetch details for each PR
while read -r pr_num; do
  gh pr view "$pr_num" \
    --json number,title,url,isDraft,reviewDecision,state,statusCheckRollup,reviewRequests \
    >> /tmp/pr-details.jsonl
done < /tmp/pr-numbers.txt
```

### Example: Single Command for Current Stack

```bash
# Get PR numbers from current stack and fetch details
gs ls --json | jq -r 'select(.change) | .change.id | ltrimstr("#")' | while read -r num; do
  gh pr view "$num" --json number,title,headRefName,isDraft,reviewDecision,statusCheckRollup
done
```

### Efficient Batch Fetch with gh api

For large stacks (10+ branches), individual `gh pr view` calls can be slow. Use the GraphQL API for batch queries:

```bash
# Fetch multiple PRs in one API call using GraphQL
gh api graphql -f query='
query($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    pullRequests(first: 50, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number
        title
        url
        isDraft
        reviewDecision
        headRefName
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup {
                contexts(first: 50) {
                  nodes {
                    ... on CheckRun {
                      name
                      conclusion
                      status
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}' -f owner='OWNER' -f repo='REPO'
```

---

## Interpreting Review Status

| reviewDecision | Meaning |
|----------------|---------|
| `APPROVED` | All required reviewers approved |
| `CHANGES_REQUESTED` | At least one reviewer requested changes |
| `REVIEW_REQUIRED` | Awaiting required reviews |
| `""` (empty) | No required review policy, or no reviews yet |

### Mapping to Display Indicators

| Status | Emoji | Text |
|--------|-------|------|
| Approved | `✅` | `approved` |
| Changes requested | `💬` | `changes_requested` |
| Review pending | `⏳` | `pending` |
| Draft | `📝` | `draft` |

### CI Rollup Summary

To summarize CI status from `statusCheckRollup`:

| Overall State | Condition |
|---------------|-----------|
| Passing | All checks have `conclusion: SUCCESS` or `SKIPPED` |
| Failing | Any check has `conclusion: FAILURE` |
| Pending | Any check has `status: IN_PROGRESS` or `QUEUED` |
| Cancelled | All non-skipped checks are `CANCELLED` |

---

## References

- [git-spice Official Docs](https://abhinav.github.io/git-spice/)
- [git-spice CLI Reference](https://abhinav.github.io/git-spice/cli/reference/)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [GitHub GraphQL API: Pull Requests](https://docs.github.com/en/graphql/reference/objects#pullrequest)
- [no-color.org](https://no-color.org) - Color output standard
