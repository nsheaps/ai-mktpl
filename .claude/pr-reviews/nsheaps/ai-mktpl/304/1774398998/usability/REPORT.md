# Usability Review — PR #304

**Score: 78/100**

## Explanation

This PR makes meaningful progress on usability by consolidating scattered review logic into shared skills, providing a migration guide, and standardizing scoring criteria. However, several usability gaps remain that would impede smooth adoption by both human developers and implementing agents.

**Strengths:**

- The `self-review` SKILL.md frontmatter includes a rich set of trigger phrases ("self-review", "review my changes", "check my code", "quality check"), making auto-invocation reasonably discoverable. The `parallel-review` skill similarly covers "team review", "fan-out review", "swarm review" -- good coverage for natural language triggers.
- The migration guide (`docs/review-system-v2-migration-guide.md`) is well-structured with numbered steps, before/after architecture diagrams, a breaking changes table, and rollback instructions. This is genuinely actionable for someone migrating another repo.
- The scoring dimensions table in `self-review` SKILL.md is clean and easy to parse. Each dimension has a one-line description of what it evaluates.
- The "When to Use This vs. Self-Review" comparison table in `parallel-review` is a practical decision aid.

**Weaknesses:**

- **Ambiguity in scoring guidance for sub-agents.** The self-review skill says each agent produces "a score from 0-100" and "a short paragraph explaining the score" but provides no calibration rubric. What does a 40 mean versus a 70? The CI prompt has color thresholds (85+ green, 65-84 yellow, <65 red) but the self-review skill does not connect scores to these thresholds in the agent instructions. An implementing agent would have to infer calibration from the synthesis step's emoji indicators, which is indirect.
- **Inconsistent verdict criteria between documents.** The `self-review` SKILL.md has its own "Review Verdict Criteria" section, and the CI prompt (`claude-code-review.md`) and the plugin template (`prompt-template.md`) each have their own verdict sections. While the content is now more aligned than v1, the three-location split means a consumer must know which document governs their context. The `code-review` SKILL.md's verdict table still uses the softer v1 phrasing for COMMENT ("Suggestions but not blocking (won't break if merged)") without the v2 justification requirement.
- **The `parallel-review` skill's "How to Use / Programmatic" section is pseudo-code, not executable.** The `TeamCreate`, `Shift+Tab` delegate mode, and teammate spawning instructions assume familiarity with Agent Teams internals that are not documented here or linked. An agent trying to implement this would lack the concrete tool calls or API shape needed.
- **Missing `argument-hint` documentation.** Both new skills use `argument-hint: [PR number | branch name | --staged]` but nowhere explain what `--staged` means or how the skill should interpret each argument type. This is a discoverability gap for agents that receive the skill metadata.
- **The `code-review` entry point SKILL.md does not mention `parallel-review` at all.** A user who discovers `code-review` and wants deeper review would not know `parallel-review` exists unless they browse the skills directory. The routing logic only mentions CI trigger or self-review fallback.
- **Token cost information is useful but not actionable.** The parallel-review skill states "~800k-1.2M tokens" but does not explain how to estimate cost before invoking, or how to abort if the cost threshold is exceeded.
- **The prompt template (`prompt-template.md`) was significantly restructured and simplified compared to the CI prompt, but they still diverge.** The template omits several sections present in the CI prompt (e.g., the detailed step 4a/4b/4c comment management, the full example reviews). A new repo using the template gets a materially different review experience than ai-mktpl itself, which is a DX inconsistency.

## References

- `shared/skills/self-review/SKILL.md` -- Shared review procedure with scoring dimensions and verdict criteria (lines 1-123)
- `shared/skills/parallel-review/SKILL.md` -- Agent Teams fan-out skill with architecture diagram and cost comparison (lines 1-168)
- `plugins/scm-utils/skills/code-review/SKILL.md` -- Entry point skill with CI trigger routing (lines 1-172); verdict table at line 99-106 uses softer v1 phrasing
- `.github/prompts/claude-code-review.md` -- Active CI prompt with full 11-step review process (lines 1-465)
- `plugins/scm-utils/skills/code-review/references/prompt-template.md` -- Simplified prompt template for other repos (lines 1-213); diverges from CI prompt
- `docs/review-system-v2-migration-guide.md` -- Migration guide with architecture diagrams and rollback instructions (lines 1-246)
- `docs/review-system-analysis.md` -- System analysis documenting strengths/weaknesses (lines 1-237)
- `plugins/scm-utils/skills/self-review/SKILL.md` -- Symlink to `shared/skills/self-review/SKILL.md`
- `plugins/scm-utils/skills/parallel-review/SKILL.md` -- Symlink to `shared/skills/parallel-review/SKILL.md`
- PR: [nsheaps/ai-mktpl#304](https://github.com/nsheaps/ai-mktpl/pull/304)
