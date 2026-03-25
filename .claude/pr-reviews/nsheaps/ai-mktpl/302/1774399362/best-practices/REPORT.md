# Best Practices Review: PR #302 — Add pr-feedback skill to github plugin

**Score: 88/100**

## Summary

The pr-feedback skill is a well-structured, comprehensive guide for AI agents handling pull request feedback. It establishes a clear A/B/C/D triage framework, correctly documents the GitHub MCP tool API (including the disputed `pull_request_read(method=...)` pattern, which is verified correct), provides accurate `gh` CLI fallback commands, and follows sound commit isolation and attribution practices. The skill loses points for minor issues: the re-review step conflates two different mechanisms, the conventional commits guidance is slightly incomplete, and some edge cases in the triage framework could be tightened.

## Detailed Findings

### 1. MCP Tool Names Are Correct (Lines 30-41, 349-365)

**Verdict: The PR author is right; the reviewer is wrong.**

I verified against the live GitHub MCP server tool definitions available in my current session. The tools use exactly the pattern documented in the skill:

- `mcp__github__pull_request_read` with `method` enum: `get`, `get_diff`, `get_status`, `get_files`, `get_review_comments`, `get_reviews`, `get_comments`, `get_check_runs` -- **confirmed correct**
- `mcp__github__resolve_review_thread(threadId)` -- **confirmed exists** (reviewer claimed it doesn't)
- `mcp__github__add_reply_to_pull_request_comment(owner, repo, pullNumber, commentId, body)` -- **confirmed exists** (reviewer claimed it doesn't)
- `mcp__github__pull_request_review_write(method, ...)` -- **confirmed exists** with method-based dispatch

The flat naming pattern (`mcp__github__get_pull_request_reviews`) suggested by reviewer henry-nsheaps does **not** exist. The reviewer appears to have confused the GitHub MCP server's actual tool schema with a hypothetical naming convention. The skill's note on line 43 about prefix variability is also a thoughtful addition.

**Reference:** [github/github-mcp-server](https://github.com/github/github-mcp-server) -- the official MCP server implementation uses method-dispatch patterns, not flat tool names.

### 2. A/B/C/D Triage Framework (Lines 117-235)

**Rating: Excellent**

The four-category triage system is well-designed and follows established code review response patterns:

- **Category A (Don't Understand, L120-140):** Correctly prioritizes asking for clarification over guessing. The "do NOT guess or make assumptions" directive (L129) is sound agent guidance -- it prevents hallucinated fixes that waste reviewer time.
- **Category B (Disagree, L142-162):** The evidence requirement (L149-155) is a standout best practice. Requiring documentation links, source code permalinks, and confidence levels prevents unsupported pushback. The safety valve at L162 ("If you cannot find strong evidence... do NOT disagree") is critical for AI agents that might otherwise fabricate justifications.
- **Category C (Defer, L164-190):** Correctly marked as "rare" (L172). The requirement to create a tracking issue with a permalink back to the original comment (L183-186) maintains traceability. Using `--label "enhancement"` (L185) is correct after the review feedback fix -- this label exists in the default GitHub label set.
- **Category D (Address, L192-235):** The six-step process (acknowledge, fix, commit, push, reply with permalink, resolve thread) is thorough. The commit isolation emphasis at L214 ("ONLY the changes that address the specific feedback item") follows the single-responsibility principle for commits.

**Minor issue:** Category C's issue creation template (L183-186) uses `--label "enhancement"` which is appropriate for improvements but not all deferred items. A deferred bug fix should use `bug`, not `enhancement`. The skill could note that the label should match the nature of the feedback.

### 3. GitHub API Concepts (Lines 58-62)

**Rating: Excellent**

The three-way distinction between Reviews, Review Comments, and Issue Comments is correctly explained:

- **Reviews** (L60): Correctly described as top-level objects with verdicts (APPROVE, REQUEST_CHANGES, COMMENT).
- **Review comments** (L61): Correctly identified as inline, diff-attached, with `isResolved`/`isOutdated` metadata. The note about thread grouping is accurate -- the MCP tool's `get_review_comments` method returns threads, not flat comments.
- **Issue comments** (L62): Correctly distinguished as conversation-level, not tied to code lines.

This is a common source of confusion in the GitHub API. The [GitHub REST API documentation](https://docs.github.com/en/rest/pulls/reviews) confirms these are three separate endpoints with distinct semantics. The skill's mapping of MCP methods to REST endpoints (L48-56) is also correct.

### 4. `gh` CLI Commands (Lines 47-56, 79-87, 251-256, 277-279, 298-300)

**Rating: Very Good**

- `gh api repos/{owner}/{repo}/pulls/{pr}/reviews` (L49) -- correct REST endpoint
- `gh api repos/{owner}/{repo}/pulls/{pr}/comments --paginate` (L52) -- correct, and `--paginate` is best practice for potentially large result sets
- `gh api repos/{owner}/{repo}/issues/{pr}/comments --paginate` (L55) -- correct endpoint for issue-style comments on PRs
- `gh pr checks {pr} --repo {owner}/{repo}` (L80) -- correct high-level check summary
- `gh api repos/{owner}/{repo}/commits/{head_sha}/check-runs --jq '...'` (L83) -- correct with appropriate jq filter for failure extraction
- `gh run view {run_id} --log-failed --repo {owner}/{repo}` (L253) -- correct for fetching failed job logs
- `gh run rerun {run_id} --failed --repo {owner}/{repo}` (L278) -- correct for re-running only failed jobs
- `gh issue create --title "..." --body "..." --label "enhancement"` (L183-185) -- correct syntax

**Minor issue:** The `gh pr checks` command (L80) does not accept a bare `{pr}` number in all versions; some older versions require `--repo` to be specified before the PR number. The command as written works in current `gh` versions but could note the version dependency.

### 5. Conventional Commits Guidance (Lines 208-213)

**Rating: Good, with gaps**

The example commit message (L209-212) correctly uses the `fix:` prefix with a descriptive subject line and body referencing the review feedback. This aligns with the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/).

**Gaps:**

- The skill only shows a `fix:` example but doesn't mention that other prefixes (`refactor:`, `style:`, `docs:`, `test:`) may be appropriate depending on the nature of the feedback. The repo's own `versioning.md` rule lists `feat:`, `fix:`, `chore:`, and `docs:`.
- No mention of scope syntax (e.g., `fix(auth): ...`) which is common in larger projects.
- The body text "Addresses review feedback on error message clarity" is good practice for traceability but the skill could explicitly recommend including the reviewer's comment permalink in the commit body for full auditability.

### 6. Commit Isolation and Attribution (Lines 203-230)

**Rating: Excellent**

- L204: "each piece of feedback should get its own commit (or group tightly related fixes)" -- this is sound practice. Individual commits per feedback item makes `git blame` useful and simplifies review of the response.
- L214: "CRITICAL: Keep feedback-addressing commits focused" -- appropriately emphatic.
- L204: References `scm-utils:commit` skill, which follows the repo's pattern of cross-referencing skills for shared procedures (per `plugin-development.md` rules about skills capturing "how").
- L219-229: The permalink pattern (`https://github.com/{owner}/{repo}/commit/{sha}`) with the `git rev-parse HEAD` command is correct and practical.

### 7. Re-Review Step (Lines 281-309)

**Rating: Good, with a minor confusion**

The four-step re-review process (verify CI, self-review diff, request re-review, update PR description) is sound workflow practice.

**Issue on Lines 297-307:** The skill presents two different mechanisms for requesting re-review without clarifying when to use which:

1. `gh pr edit {pr} --add-label "request-review"` (L300) -- triggers an AI review bot specific to this repo
2. `mcp__github__update_pull_request(..., reviewers=["original-reviewer"])` (L306) -- requests re-review from a human reviewer via GitHub's native reviewer request feature

These serve different purposes and are not interchangeable. The skill should clarify: use the label for AI re-review, use the reviewers parameter for human re-review, and ideally do both. The "Or" framing on L304 implies they're alternatives when they're complementary.

### 8. Example Responses (Lines 139-140, 158-161, 189-190, 199-200, 220)

**Rating: Excellent**

All example responses are professional, specific, and model good communication practices:

- L140: The Category A example asks a targeted clarifying question ("the error handling in `parse()` or the public API surface?") rather than a vague "can you explain?"
- L160: The Category B example includes MDN documentation link, GitHub permalink with line numbers, and technical reasoning about `structuredClone()` vs `JSON.parse(JSON.stringify(...))`. This sets a high bar for evidence-backed disagreement.
- L190: The Category C example acknowledges validity, gives a clear scope reason, and provides the tracking issue number.
- L200: The Category D acknowledgment is concise and action-oriented.

### 9. Batch Fetch Pattern (Lines 311-326)

**Rating: Very Good**

The recommendation to fire all read calls simultaneously (L315) is excellent agent guidance. These seven MCP calls have no data dependencies and can be parallelized, reducing round-trip latency significantly. The comment on L314 ("they have no dependencies on each other") makes the rationale explicit.

### 10. Filtering Guidance (Lines 340-348)

**Rating: Very Good**

- "Most recent review per reviewer (earlier ones are superseded)" (L345) -- correct; GitHub shows all reviews but only the latest per reviewer matters for merge decisions.
- Filtering for `conclusion: "failure"` or `conclusion: "cancelled"` (L346) -- correct check run conclusions per the [GitHub Checks API](https://docs.github.com/en/rest/checks/runs).
- "Skip bot comments and your own replies" (L347) -- practical guidance that prevents feedback loops.

### 11. Skill Frontmatter (Lines 1-16)

**Rating: Very Good**

The YAML frontmatter follows the SKILL.md convention with a descriptive `description` field and seven `<example>` trigger phrases covering natural language variations. The examples cover the primary use cases: general PR feedback, CI failures, review comments, and numbered PR references.

**Minor note:** The description is somewhat long (6 lines). While comprehensive, shorter descriptions may perform better for skill matching in some agent frameworks.

### 12. Workflow Summary (Lines 367-378)

**Rating: Excellent**

The 8-step summary provides a clean mental model: GATHER, INVENTORY, TRIAGE, ACT, COMMIT, RESPOND, VERIFY, RE-REVIEW. This follows an established pattern in incident response and code review literature of separating assessment from action. The summary correctly mirrors the detailed steps above without introducing inconsistencies.

## Score Breakdown

| Criterion                        | Score | Weight   | Weighted       |
| -------------------------------- | ----- | -------- | -------------- |
| MCP tool accuracy                | 10/10 | 20%      | 20.0           |
| A/B/C/D triage framework design  | 9/10  | 15%      | 13.5           |
| GitHub API concepts explanation  | 10/10 | 10%      | 10.0           |
| `gh` CLI command correctness     | 9/10  | 10%      | 9.0            |
| Conventional commits guidance    | 7/10  | 10%      | 7.0            |
| Commit isolation and attribution | 10/10 | 10%      | 10.0           |
| Re-review workflow               | 7/10  | 10%      | 7.0            |
| Example response quality         | 10/10 | 5%       | 5.0            |
| Efficient querying patterns      | 9/10  | 5%       | 4.5            |
| Skill structure and frontmatter  | 9/10  | 5%       | 4.5            |
| **Total**                        |       | **100%** | **90.5 -> 88** |

**Final Score: 88/100**

## Recommendations

1. **Clarify re-review mechanisms** (L297-307): Distinguish AI re-review (label) from human re-review (reviewer request) and recommend both.
2. **Broaden conventional commit examples** (L208-213): Show `refactor:`, `style:`, `test:` prefixes alongside `fix:` to match the range of feedback types.
3. **Add label guidance to Category C** (L185): Note that the `--label` should match the feedback type (bug, enhancement, chore) rather than always defaulting to `enhancement`.
4. **Address the unresolved review threads**: The reviewer's claims about fictional tool names are factually incorrect. The PR author should reiterate the verification with a link to the GitHub MCP server source or a screenshot of the tool schema, then resolve the threads.
