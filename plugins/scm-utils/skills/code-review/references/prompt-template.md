REPO: ${REPO}
PR_NUMBER: ${PR_NUMBER}

Please review this PR and provide inline feedback using the GitHub review system.
You must provide feedback on:

- Code quality and best practices
- Potential bugs or issues
- Performance considerations
- Security concerns
- Overall maintainability
  You should also consider these aspects when reviewing:
- Test coverage
- Accuracy of comments and documentation
- Accuracy of PR description vs code changes
- Simplicity of the code changes
- Adherence to repository style and conventions

Use your built in MCP tools and associated `gh` tools to evaluate the changes in the context of the PR title/body, commit messages, other user's reviews, and comments and reviews left on the PR.
Use `mcp__github__github_support_docs_search` to find relevant documentation on GitHub's docs site if you need clarification on how GitHub's systems work.

Questions you leave in past reviews may be answered in the PR body or comments. Do not duplicate questions asked previously, be sure to respond to any engagement on comments you've left (if necessary, else consider resolving them).

## To review the PR, follow these steps:

1. **Get diff information**: Use `mcp__github__*` tools from MCP, and `gh *` cli tools to understand the code changes, previous reviews, and line numbers.

2. **Review previous reviews** including your own. Your previous reviews may be hidden and will be hidden in the future, so it's important that your new review captures all necessary information (or references PR threads from previous reviews). The review you will post will contain all relevant details, including those from your previous reviews that still need resolution.
   Use `gh` to view comments and reviews on the PR. Remember you can't see reviews by viewing comments or vice versa.

3. **Start a local doc to track your review findings and notes** including:
   - Summary of your review findings
   - Specific comments for inline feedback
   - Any questions or clarifications needed from the author
   - Links to relevant documentation or style guides
   - Reference links for your final review (workflow run, PR, external sources)
     CRITICAL: This doc must be updated after every piece you review, since your memory is very short and volatile. Do not trust your memory or built in knowledge. Use the doc to track everything.
4. **Use `gh api ...` to manage previous comments and threads**. This step prepares the PR for your new review.
   You must use the GraphQL API to minimize comments and resolve threads.
   See more info about the graphql API here: https://docs.github.com/en/graphql/mutations/

   ### 4a. Minimizing your previous comments (NOT review threads)

   CRITICAL: Only minimize your own PR comments (general comments), not review threads on specific lines.
   CRITICAL: Never minimize or hide comments from other users.
   - Get your comment IDs using: `gh pr view <PR_NUMBER> --json comments`
   - Minimize using graphql API with OUTDATED classifier:
     ```bash
     gh api graphql -f query='
       mutation {
         minimizeComment(input: {
           subjectId: "<COMMENT_NODE_ID>"
           classifier: OUTDATED
         }) {
           minimizedComment {
             isMinimized
             minimizedReason
           }
         }
       }'
     ```

   ### 4b. Resolving review threads

   Review threads (inline comments on specific lines) should be RESOLVED, not minimized/hidden.
   Use `gh pr-review review view "$(gh pr view --json url --jq .url)"` to list review threads.

   **WHEN TO RESOLVE your own threads:**
   - The issue has been fixed in new commits
   - The author addressed the feedback in code or clarified adequately
   - The comment is no longer applicable due to code changes

   **WHEN NOT TO RESOLVE threads (even your own):**
   - Comments praising good design choices (leave visible as positive feedback)
   - Ongoing conversations that haven't reached conclusion
   - Issues that still need to be addressed
   - Comments noting things that could be follow-up improvements (these should stay visible)

   **Handling OTHER users' threads:**
   CRITICAL: Never resolve threads started by other users.
   If you believe another user's thread has been addressed:
   1. Comment on that thread explaining WHY it's addressed with specific links to code sections
   2. Let the original commenter decide whether to resolve it
   3. Include references like: "This was addressed in [commit SHA] at [file:line]" or "See the updated code at [permalink]"
      If another user's feedback is a valid concern but could be a follow-up:
   4. Comment acknowledging the concern
   5. Suggest it could be handled in a follow-up PR
   6. Do NOT resolve the thread

   **Resolve using graphql API:**

   ```bash
   gh api graphql -f query='
     mutation {
       resolveReviewThread(input: {
         threadId: "<THREAD_NODE_ID>"
       }) {
         thread {
           isResolved
         }
       }
     }'
   ```

   ### 4c. Updating existing comments (not reposting)

   If you previously left a comment that needs updating (e.g., partial feedback that's been addressed):
   - Use `gh api` to UPDATE the comment body rather than posting a new comment
   - Add an "**Edit:**" section at the bottom of the comment describing the current state

5. **Start a review**: Use `mcp__github__create_pending_pull_request_review` to begin a pending review
6. **Add inline comments**: Use `mcp__github__add_comment_to_pending_review` for each specific piece of feedback on particular lines. The add_comment_to_pending_review does not return the new thread ID, so you will need to fetch the review comments again after adding all comments to get the URLs for your review comments.
   CRITICAL: Use inline comments including detail about the issue and link to it from your review, rather than putting all the detail in the review.
   CRITICAL: Review comments and PR comments on specific lines of code should NEVER be minimized. ALWAYS resolve them (or leave them open if still relevant).
7. **Fetch review comments again** in order to get the URL of your new and existing PR comments. Update your local doc to include links to your review comments for reference.
8. **Draft your review summary**: Summarize your overall findings in your local doc, including:
   - High-level assessment of the code changes
   - Key strengths and areas for improvement
   - Any critical issues that must be addressed
   - Overall recommendation (approve, request changes, comment)
   - Key formatting for github flavored markdown including details/summary blocks, emojis, and shields.io badges.
   - Critical review of findings to ensure accuracy and confidence of your assessment.
   - **Follow-up recommendations** (if any): Items that don't need to block this PR but should be addressed in future PRs.
     These MUST be explicitly called out in a dedicated section of your review summary (outside the details block).
9. **Hide your previous reviews** just before submitting your new review.
   CRITICAL: This ensures only your latest review is visible, preventing clutter and confusion.
   CRITICAL: Only hide YOUR OWN previous reviews, never reviews from other users.
10. **Submit the review**: Use `mcp__github__submit_pending_pull_request_review` to post your review.
    CRITICAL: If there are security, performance, or correctness issues that MUST be addressed before merging, use "REQUEST_CHANGES".
    CRITICAL: If there are no other changes to make, and the PR is ready to merge, use "APPROVE".
    Use event type "COMMENT" (not "REQUEST_CHANGES") to publish all comments as a non-blocking review if you think there should be changes, but the system won't break if the changes are merged.

11. **Post-review verification**: After submitting your review, re-read the PR and all comments to ensure correct state.

## Review formatting guidelines:

Use these emoji to help convey your summary.
✅ Something you checked that is correct
❔ When you're confused about something that requires clarification
⚠️ For something that you think might be a problem
❌ For something that is definitely a problem

### Using shields.io badges for high level metrics

Use shields.io badges to convey high level metrics for your review:
`https://img.shields.io/badge/<RESULT>-%20?style=for-the-badge&label=<LABEL>&labelColor=%23444&color=<COLOR>`

Required badges: Code quality (0-100%), Security (0-100% or N/A), Simplicity (0-100%), Confidence (0-100%)
Colors: Green `#60A060` (85+), Yellow `#C0C040` (65-84), Red `#D07070` (<65), Gray `#444444` (N/A)

## The final review format

```
<details>
<summary>
### <statement of approval or disapproval>
![](badge1) ![](badge2) ![](badge3) ![](badge4)

<summary list of findings>
_🖱️ Click to expand for full details_
</summary>

<detailed review sections with L3+ headings>
</details>

**Recommended follow-ups** (non-blocking):
- Item 1
- Item 2

Notes:[^1][^2]
[^1]: Workflow Run: [URL]
[^2]: PR: [URL]
```

## Design principles

Code changes should follow: KISS, YAGNI, DRY, WET, TDA, SOLID.

## Restrictions

- Ignore stylistic suggestions (deterministic automation validates that)
- Only suggest code changes when there's a clear benefit
- Use ```suggestion blocks so authors can apply changes directly
- Do not use CI output to base your review — review the code itself
- Do not post "test" or "review in progress" comments
- Your review MUST contain `<details>` and `<summary>` HTML tags

## Extra info to help you

<job-context>
${JOB_CONTEXT}
</job-context>
