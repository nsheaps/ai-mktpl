# Usability Review: PR #302 — Add pr-feedback skill to github plugin

**Score: 82 / 100**

## Summary

This skill is one of the most thorough and well-structured agent-facing procedure documents in the repo. The four-step workflow (Gather, Triage, Act, Re-review) is logical and the triage framework with categories A-D is genuinely intuitive. An AI agent reading this top-to-bottom would know what to do in the vast majority of scenarios. The deductions come from a handful of gaps that could cause an agent to stall or make wrong assumptions: ambiguity around how to obtain the `threadId` needed for resolving threads, a missing instruction on how to determine the PR number when not provided by the user, inconsistent code-block language annotations, and the Workflow Summary conflating steps that are interleaved in practice (triage then act, vs. the document's own Category D which has act-commit-respond as sub-steps).

## Detailed Findings

### Strengths

**1. Trigger examples are comprehensive (lines 9-15)**
Seven `<example>` tags cover the major phrasings an agent would encounter: explicit "address the PR feedback," CI-focused "fix the CI failures on my PR," vague "the reviewer left feedback, can you fix it." This is stronger than the sibling `gh` skill which has zero trigger examples. The variety makes it very likely the skill will be matched when needed.

**2. Triage framework is clear and actionable (lines 118-235)**
Categories A through D each have a definition, an action block, tool invocations, and a worked example response. The progression from "don't understand" to "disagree with evidence" to "defer with issue" to "address now" is intuitive and well-ordered. The explicit instruction at line 162 ("If you cannot find strong evidence to back your disagreement, do NOT disagree") is a strong guardrail against agent overconfidence.

**3. Batch-fetch pattern is excellent (lines 313-326)**
Explicitly telling the agent to fire all read calls in parallel at the start is a concrete performance optimization. The comment "they have no dependencies on each other" removes any doubt about ordering.

**4. Filtering guidance is specific (lines 340-347)**
The "Filtering What Matters" section gives concrete criteria (unresolved, non-outdated, most recent review per reviewer, failure/cancelled conclusions). An agent does not have to guess what "actionable" means.

**5. Quick reference table is copy-paste ready (lines 349-365)**
Every MCP tool name and method value is correct relative to the actual GitHub MCP server schema visible in the system environment. The table covers all read and write operations needed for this workflow.

### Issues

**6. Missing guidance on obtaining `threadId` for `resolve_review_thread` (line 233-235)**
The skill instructs the agent to call `mcp__github__resolve_review_thread(threadId)` but never explains where `threadId` comes from. It is a GraphQL node ID returned in the `get_review_comments` response, but the skill does not state this. An agent unfamiliar with the response schema would not know which field to extract. The quick reference table at line 363 also just says `threadId` without sourcing it. This is the most likely point where an agent would stall.

**7. No instruction for determining owner/repo/pullNumber when not provided (lines 30-41)**
Every MCP call uses `owner, repo, pullNumber` as bare parameters. The skill never explains how to resolve these when the user says something vague like "address the PR feedback" without specifying a PR number. The `gh` sibling skill similarly assumes these are known, but a brief note such as "use `gh pr view --json number` or check the current branch" would prevent confusion. This is particularly relevant because trigger example at line 14 ("the reviewer left feedback, can you fix it") contains no PR identifier at all.

**8. Workflow Summary step ordering is slightly misleading (lines 369-378)**
Steps 4 (ACT), 5 (COMMIT), and 6 (RESPOND) are listed as sequential top-level steps, but in the body of the document (Category D, lines 196-235), these are sub-steps within triaging each individual item. The summary implies you triage everything first, then act on everything, then commit everything -- but the actual workflow is: triage item, act+commit+respond for that item, then move to the next. An agent following the summary literally would batch all fixes into one commit, contradicting the "isolated, focused commits per feedback item" instruction at line 214.

**9. Inconsistent code block language annotations (lines 30-41 vs 47-56 vs 89-97)**
MCP tool invocations use bare ` ``` ` fences with no language tag (lines 33, 69, 92, 131, 234, 244, etc.), while CLI fallbacks use ` ```bash ` (lines 47, 80, 181, 224, 253, 277, 299). This is a minor consistency issue, but some agents use the language annotation to decide whether to execute a block in a shell or treat it as pseudocode. Adding a language hint like `python` or a custom `tool-call` annotation to the MCP blocks would remove ambiguity.

**10. Step 3 (CI Failures) partially duplicates Step 2 triage (lines 237-279)**
CI failures appear in the feedback inventory at line 106 (item 4) and are subject to triage in Step 2, but then Step 3 presents a separate parallel workflow for CI failures specifically. The skill does not clarify how these interact. Should an agent triage CI failures in Step 2 and then skip Step 3? Or skip CI items in Step 2 and handle them all in Step 3? The implicit answer is the latter, but it is not stated. Adding a sentence like "CI failures are triaged separately in Step 3 -- skip them during Step 2 triage" at line 118 would resolve this.

**11. `scm-utils:commit` cross-reference is opaque (lines 204, 374)**
The skill references "Use the `scm-utils:commit` skill for committing" but does not explain what that skill provides or why it should be preferred over a direct `git commit`. An agent without the `scm-utils` plugin installed would not know what to do. A one-line explanation (e.g., "which handles attribution, conventional commit formatting, and hook compliance") would help the agent decide whether to fall back to manual git commit.

**12. Re-review step mixes two different mechanisms (lines 297-307)**
Line 300 says to use `--add-label "request-review"` for AI review bots, and line 306 says to use `update_pull_request(reviewers=["original-reviewer"])` for human reviewers. But the skill does not tell the agent which to use when, or whether to do both. The parenthetical "(if configured in the repo)" at line 297 is the only hint, and it is insufficient for an agent to make a decision.

### Minor Observations

**13. Note about MCP prefix variability (line 43)**
The disclaimer "Tool names may vary by MCP server configuration" is technically accurate but could cause an agent to second-guess every tool name in the document. Since the tool names are correct for the standard GitHub MCP server, this note might introduce unnecessary hesitation.

**14. Category C issue creation uses `gh` CLI only (lines 181-186)**
All other categories show both MCP tools and CLI fallback, but Category C (defer with tracking issue) only shows the `gh issue create` CLI command. For consistency, it should also show the MCP equivalent (`mcp__github__issue_write` with `method="create"`).

## Scoring Breakdown

| Criterion | Score | Notes |
|---|---|---|
| Agent can follow step-by-step | 16/20 | Clear overall, but threadId gap and CI/triage overlap cause confusion |
| Trigger examples comprehensive | 18/20 | Seven good examples covering varied phrasings |
| Workflow clarity and ordering | 14/20 | Summary contradicts body on per-item vs batched processing |
| Code examples correct and complete | 16/20 | MCP calls match actual schema; missing threadId source; no language tags on MCP blocks |
| Triage framework intuitive | 18/20 | Categories A-D are well-defined with strong examples and guardrails |
