# Simplicity Review: PR #302 — Add pr-feedback skill to github plugin

**Score: 42 / 100**

## Summary

The pr-feedback skill at 378 lines is moderately verbose for the procedural knowledge it conveys. Its core problem is systematic duplication: every API call is shown twice (MCP tool and `gh` CLI fallback), inflating the file by roughly 40%. The "Quick Reference" table at the end recapitulates tool names already demonstrated in the body. A workflow summary section restates the step headings. While the information is individually useful, the skill would deliver the same value at approximately 200-220 lines with tighter editing.

## Detailed Findings

### 1. Dual MCP/CLI Pattern Doubles Every Code Block (Lines 30-97)

Every data-fetching step is shown in two forms: MCP tool call, then `gh` CLI fallback. This is the single largest source of bloat. For example, "Fetch Reviews and Review Comments" (lines 30-56) contains six code examples — three MCP calls and three CLI equivalents — for what is conceptually one operation ("get the reviews").

Compare to the `daily-report` skill (314 lines), which covers a far more complex data-gathering workflow using only `gh` CLI. It demonstrates one way to do each thing and moves on. The pr-feedback skill could adopt a similar approach: pick the primary interface (MCP tools, since the description says "preferred") and relegate CLI fallbacks to a single collapsed reference section or omit them entirely, trusting that an agent with `gh` available can translate tool names to CLI calls.

**Lines affected:** 30-56 (Step 1a), 66-87 (Step 1b), 89-97 (Step 1c).

### 2. Quick Reference Table Repeats the Body (Lines 349-365)

The table at lines 349-365 lists every MCP tool and method already shown with code examples in Steps 1-4. Every row is information the agent has already seen. For instance, `mcp__github__pull_request_read` with `method="get_reviews"` appears at line 34 and again at line 354. The table adds no new information — it is a pure recap.

By contrast, neither `memory-manager` (234 lines) nor `slash-command-writing` (398 lines) include summary tables that duplicate their own body content.

### 3. Workflow Summary Restates the Headings (Lines 367-378)

The numbered workflow summary at lines 369-378 ("1. GATHER -> 2. INVENTORY -> 3. TRIAGE -> ...") mirrors the step structure already established by the `## Step N` headings (lines 22, 116, 237, 281). An agent reading the skill sequentially already absorbed this structure. This section could be removed without loss.

### 4. Triage Categories Are Well-Structured but Verbose (Lines 116-236)

The four-category triage framework (A: Don't Understand, B: Disagree, C: Defer, D: Address) is the skill's strongest contribution and is genuinely useful. However, each category includes both a prose explanation and an extended example response, making this section 120 lines. The example responses (e.g., lines 159-160, a 3-line quoted block about `structuredClone`) are realistic but long. Trimming each example to 1-2 sentences would save ~20 lines without losing the pedagogical value.

### 5. "Key Distinctions" Block Is Helpful but Partially Redundant (Lines 59-62)

Lines 59-62 explain the difference between reviews, review comments, and issue comments. This is genuinely clarifying. However, the same three concepts were already implicitly distinguished by the code examples and their inline comments on lines 33-40. Making the distinction explicit is arguably worth the 4 lines, but it sits in a section that is already heavy with parallel code blocks.

### 6. Efficient Querying Patterns Section Adds Marginal Value (Lines 311-347)

The "Batch Fetch" example (lines 317-326) re-lists the same seven MCP calls from Step 1, now annotated with "fire these simultaneously." The pagination section (lines 328-338) and filtering section (lines 340-347) contain advice that is either obvious to an agent (always paginate) or already stated in Step 1d (lines 109-114, which says to skip resolved threads, outdated comments, etc.). This entire section could be folded into Step 1 as a brief note: "Make all read calls in parallel. Paginate with `perPage=100`. Filter to unresolved, non-outdated items."

### 7. Length in Context of Other Skills

| Skill | Lines | Scope |
|---|---|---|
| `slash-command-writing` | 398 | Reference guide for an entire feature surface |
| **`pr-feedback`** | **378** | Procedural workflow for one task |
| `daily-report` | 314 | Complex multi-step data gathering + report template |
| `memory-manager` | 234 | Detection logic + file management + examples |

The pr-feedback skill is comparable in length to `slash-command-writing`, which is a comprehensive reference document covering syntax, arguments, bash execution, file references, namespacing, troubleshooting, and multiple example commands. The pr-feedback skill covers a narrower domain (respond to PR feedback) but achieves similar length primarily through duplication rather than breadth.

### 8. Structure Is Flat and Scannable (Positive)

Despite the verbosity, the skill's heading hierarchy is clean: four top-level steps, lettered sub-steps, and named triage categories. An agent can skip to the relevant section quickly. The nesting never exceeds three levels. This is a genuine strength.

### 9. Frontmatter Description Is Appropriately Detailed (Lines 2-16)

The seven `<example>` trigger phrases (lines 9-15) are well-chosen and cover the realistic ways a user would invoke this skill. This matches the pattern used by other skills in the repo.

## Recommendations

1. **Remove the dual MCP/CLI pattern.** Show MCP tools inline. Add a single "CLI Fallback Reference" collapsed section at the end if CLI equivalents are deemed necessary.
2. **Delete the Quick Reference table** (lines 349-365). It is entirely redundant with the body.
3. **Delete the Workflow Summary** (lines 367-378). The step headings serve this purpose.
4. **Merge "Efficient Querying Patterns" into Step 1** as a 3-4 line note about parallelism, pagination, and filtering.
5. **Trim example responses** in triage categories to 1-2 sentences each.

These changes would bring the skill to approximately 200-220 lines with no loss of actionable content.
