# Documentation and Comments (Discoverability) Review

**PR:** nsheaps/ai-mktpl#302 "Add pr-feedback skill to github plugin"
**Score: 82 / 100**

## Summary

The `pr-feedback` skill is well-structured and largely self-documenting, with accurate frontmatter, comprehensive example triggers, and a thorough Quick Reference table. The PR title, body, and commit messages all follow conventions. The plugin.json tags are appropriate and complete. The primary documentation gap is a lack of introductory explanation for the MCP tool naming convention (`pull_request_read(method=...)` pattern vs. flat names), which has already caused real confusion in code review -- two review rounds incorrectly flagged the tool names as fictional. A brief upfront explanation of the method-dispatch pattern would prevent future misunderstandings. The label fix (`follow-up` to `enhancement`) was addressed promptly, and the note about MCP prefix variability (line 43) is a good addition.

## Detailed Findings

### Frontmatter Description (Lines 2-16) -- Strong

The YAML frontmatter `description` field (lines 3-8) accurately captures what the skill does: address PR feedback systematically, covering reviews, comments, and CI failures. It describes the full lifecycle (gather, triage, act, commit, re-review), which matches the actual skill content. The description is detailed enough for an agent to decide whether to invoke the skill without being overly verbose.

The seven `<example>` triggers (lines 9-15) cover a good range of natural phrasings: "address the PR feedback", "fix the CI failures on my PR", "respond to the review comments", "handle the PR review", "address inline comments on PR #42", "the reviewer left feedback, can you fix it", and "CI is failing on the PR". These mix imperative and conversational forms and cover both review comments and CI failure scenarios. One gap: there is no example for the "disagree with reviewer" or "defer feedback" sub-workflows, though these are arguably sub-actions rather than top-level triggers.

### MCP Tool Name Convention -- Needs Clarification (Lines 30-43)

The skill correctly uses the `mcp__github__pull_request_read(method="get_reviews", ...)` pattern, which matches the actual GitHub MCP server tool schema. I verified this against the live tool definitions available in the current session: `mcp__github__pull_request_read` exists with a `method` enum parameter accepting `get`, `get_diff`, `get_status`, `get_files`, `get_review_comments`, `get_reviews`, `get_comments`, `get_check_runs`. Similarly, `mcp__github__resolve_review_thread`, `mcp__github__add_reply_to_pull_request_comment`, and `mcp__github__pull_request_review_write` all exist as documented.

However, the reviewer (henry-nsheaps bot) flagged these names as fictional across two review rounds, claiming the tools use a flat naming convention like `mcp__github__get_pull_request_reviews`. The reviewer was incorrect, but the confusion is understandable -- the method-dispatch pattern is unusual compared to most MCP tool conventions.

The note on line 43 ("The `mcp__github__` prefix is the standard prefix for the GitHub MCP server. Tool names may vary by MCP server configuration") partially addresses this, but the skill would benefit from a more explicit explanation that the GitHub MCP server uses a method-dispatch pattern (one tool with a `method` enum) rather than individual tool names per operation. This would prevent future confusion for both human reviewers and agents encountering this pattern for the first time. This is the primary deduction.

### Quick Reference Table (Lines 349-365) -- Accurate

The Quick Reference table at the end of the skill lists all relevant MCP tools with their method parameters and corresponding actions. Every entry is accurate:

- `mcp__github__pull_request_read` with each method variant (lines 352-359)
- `mcp__github__add_reply_to_pull_request_comment` (line 361)
- `mcp__github__add_issue_comment` (line 362)
- `mcp__github__resolve_review_thread` (line 363)
- `mcp__github__update_pull_request` (line 364)
- `mcp__github__pull_request_review_write` (line 365)

The table format is clean and scannable. The "Task" column uses plain-language descriptions, making it easy to find the right tool for a given goal.

### PR Title and Body -- Clear and Informative

The PR title "Add pr-feedback skill to github plugin" is concise (43 characters), starts with a verb, and follows the repository's naming conventions.

The PR body contains three well-organized sections:

1. **Summary** -- Six bullet points covering what was added, the feedback loop structure, MCP/CLI dual-path approach, decision framework categories, cross-skill references, and version bump.
2. **Review feedback addressed** -- Three bullet points documenting how each piece of review feedback was handled, including the label fix, the MCP prefix addition, and the reasoned disagreement about tool names. This section is particularly good for traceability.
3. **Test plan** -- Three checkbox items for verification.

The session link at the bottom (`https://claude.ai/code/session_01NzMS61FnfjGDki7113ARRF`) follows repository conventions.

### Commit Messages -- Follow Conventional Commits

The two authored commits use proper conventional commit format:

1. `feat(github): add pr-feedback skill for addressing PR reviews and CI failures` (commit `0be1e10`) -- Uses the `feat` type with a scope, has a multi-line body explaining what was added and why. Well-structured.
2. `fix: add mcp__github__ prefix to tool names and fix label reference` (commit `eb1d804`) -- Uses the `fix` type, body explains the three specific changes and ties them to review feedback. Clear and traceable.

The remaining three commits are automated (`chore: auto-bump plugin versions and update marketplace` and `chore: \`mise run lint\``), which is expected from the CD pipeline.

### Plugin.json Tags (Lines 12-29) -- Appropriate for Discoverability

The `keywords` array in `plugin.json` includes 14 tags. The four new tags relevant to this PR are: `pr-feedback`, `code-review`, `ci-failures`, `review-comments`. These directly map to the skill's functionality and would help users discover the plugin when searching for PR feedback tooling. The existing tags (`github`, `gh`, `cli`, `authentication`, `pull-requests`, `issues`, etc.) remain appropriate for the plugin's broader scope.

### Terminology and Concepts -- Well-Explained

The skill introduces several domain concepts and explains each:

- **Reviews vs. review comments vs. issue comments** (lines 60-62): The "Key distinctions" section clearly differentiates these three API concepts, which is essential since GitHub's API treats them separately.
- **A/B/C/D triage categories** (lines 116-233): Each category has a name, description, action steps, code examples, and a natural-language example response. The framework is self-documenting.
- **CI failure types** (lines 260-268): The diagnostic table maps failure types to diagnosis approaches and fixes.
- **`scm-utils:commit`** (line 204): Referenced as a cross-skill dependency for committing. The reference is clear but assumes the reader knows this is another skill in the marketplace -- a brief parenthetical like "(from the scm-utils plugin)" could help.
- **`request-review` label** (line 297): Referenced for triggering AI re-review. The context explains its purpose, though new users might not know this is a repo-specific convention.

### Minor Observations

- The Workflow Summary (lines 369-378) uses an ASCII flowchart format that is compact and scannable. Each step maps to a section in the skill, making navigation easy.
- The "Efficient Querying Patterns" section (lines 311-347) correctly identifies that the batch fetch calls have no dependencies and can be parallelized. This is a practical optimization tip.
- The pagination note (lines 329-338) documents both MCP `perPage` parameters and `gh --paginate`, covering both paths.

## Score Breakdown

| Criterion | Score | Notes |
|---|---|---|
| Self-documenting skill | 18/20 | Thorough, well-structured. Minor gap: cross-skill references could include plugin names. |
| Frontmatter description accuracy | 18/20 | Accurate and detailed. Could add an example for the disagree/defer sub-workflows. |
| Example triggers | 10/10 | Seven diverse, natural triggers covering reviews and CI. |
| PR title and body | 10/10 | Clear, structured, includes feedback traceability section. |
| Commit messages | 10/10 | Proper conventional commits with scopes and explanatory bodies. |
| Plugin.json tags | 8/10 | Four relevant new tags added. Could consider `triage` or `feedback-loop` for the methodology aspect. |
| Quick Reference accuracy | 8/10 | All tool names verified correct. Missing brief note about the method-dispatch pattern to prevent confusion. |
| Terms/concepts explained | Deducted above | MCP naming convention needs upfront explanation to prevent reviewer confusion (already caused two rounds of incorrect feedback). |

**Total: 82/100**
