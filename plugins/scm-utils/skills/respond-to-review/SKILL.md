---
name: respond-to-review
description: >
  Respond to review comments on a PR. Use when asked to "respond to review",
  "reply to reviewer", "address review comments", "respond to PR feedback",
  or when crafting responses to reviewer questions and suggestions.
argument-hint: "[PR number]"
---

# Respond to Review

Craft appropriate responses to review comments on a pull request.

## Process

1. **Fetch all review comments**: `gh api repos/{owner}/{repo}/pulls/{number}/reviews`
2. **Read each comment thread** and understand what the reviewer is asking
3. **For each comment**, determine the appropriate response:
   - Agreement + action: "Good catch, fixed in [commit]"
   - Explanation: "This is intentional because [reason]"
   - Discussion: "I see your point, but [counterargument]. What do you think?"
   - Question: "Could you clarify what you mean by [X]?"
4. **Post responses** using `scm-utils:post-review` or inline replies
5. **Resolve threads** that have been addressed with code changes

## Response Guidelines

- Be concise and direct
- Reference specific commits when you've made a fix
- Never dismiss feedback without explanation
- If you disagree, explain why with evidence
- Mark resolved threads as resolved after fixing

## Anti-Patterns

| Bad                           | Good                                        |
| ----------------------------- | ------------------------------------------- |
| "Done" with no context        | "Fixed in abc1234 -- moved the check to..." |
| Ignoring comments             | Respond to every comment, even if briefly   |
| Arguing without evidence      | Explain with code references or docs        |
| Bulk "addressed all" response | Respond to each thread individually         |
