# Simplicity Review — PR #304

**Score: 52/100**

![Simplicity](https://img.shields.io/badge/52%25-%20?style=for-the-badge&label=Simplicity&labelColor=%23444&color=%23D07070)

## Summary

This PR introduces more complexity than it removes. While the stated goal — DRYing review logic via shared skills and symlinks — is sound in principle, the execution adds 846 lines and 6 new files against only 66 deletions and 1 file removed. The result is a system that is harder to understand, not easier. Two documentation files totaling 481 lines describe an architecture that a developer must now read across 6+ files to comprehend, and the verdict criteria duplication the PR claims to address is actually still present in three separate locations. The parallel-review skill documents a speculative feature (Agent Teams) that is experimental and not usable in CI, violating YAGNI.

## Detailed Findings

### 1. Verdict Criteria Triplication (Not DRY)

The review verdict criteria (REQUEST_CHANGES / APPROVE / COMMENT decision tree) now exist in three places with slightly different formatting but identical intent:

- `.github/prompts/claude-code-review.md` (lines 130-151) — the active CI prompt
- `plugins/scm-utils/skills/code-review/references/prompt-template.md` (lines 130-151) — the distributable template
- `shared/skills/self-review/SKILL.md` (lines 79-95) — the shared skill

The analysis doc (`docs/review-system-analysis.md`, line 147) even acknowledges this: "The CI prompt and plugin template still need to be kept in sync manually." The PR identifies the problem but does not solve it. This is the opposite of simplification.

### 2. Documentation Over-Engineering (481 Lines of Docs for a Skill Refactor)

Two new documentation files were added:

- `docs/review-system-analysis.md` — 235 lines
- `docs/review-system-v2-migration-guide.md` — 246 lines

These documents describe the architecture in exhaustive detail including ASCII flow diagrams, component tables, future improvement roadmaps (sections 5.1-5.7 in the analysis), and speculative CI agent teams integration (migration guide lines 202-227). A migration guide is reasonable, but 246 lines for moving a skill from a project directory to a shared directory and adding symlinks is disproportionate. The analysis document reads like internal design documentation that will become stale quickly — it duplicates information already present in the skill files themselves.

A single, concise "what changed and why" section in the PR description or a short `CHANGELOG` entry would serve the same purpose with far less maintenance burden.

### 3. Parallel-Review Skill Is Speculative (YAGNI)

The `shared/skills/parallel-review/SKILL.md` (167 lines) documents a workflow that:

- Requires an experimental feature flag (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) — line 19
- Cannot be used in CI (the primary review context) — acknowledged at line 156
- Has 2x the token cost (~800k-1.2M vs ~440k) — lines 146-148
- Has no implementation code; it is purely instructional prose for an agent to follow

This skill is a design document masquerading as a feature. Including it in the same PR as the legitimate bugfixes and shared skill extraction makes the PR harder to review and inflates the change surface. It should be a separate PR when Agent Teams is no longer experimental.

### 4. Symlinks Add Hidden Complexity

The symlinks from `plugins/scm-utils/skills/{parallel-review,self-review}/SKILL.md` to `shared/skills/*/SKILL.md` introduce a layer of indirection:

```
plugins/scm-utils/skills/self-review/SKILL.md -> ../../../../shared/skills/self-review/SKILL.md
plugins/scm-utils/skills/parallel-review/SKILL.md -> ../../../../shared/skills/parallel-review/SKILL.md
```

While symlinks are used elsewhere in this repo (per the shared-libs rule in `.claude/rules/shared-libs.md`), the shared-libs rule notes: "Symlinked content is resolved and copied on plugin install (not symlinked at runtime)." It is unclear whether this same resolution applies to skill files. If not, the symlinks create a fragile dependency on directory structure that `../../../../` relative paths make worse. The simpler approach would be to just keep the skill content in the plugin directly, since the `shared/` directory adds a level of indirection without a second consumer.

### 5. The Actual Bugfixes Are Simple and Good

The concrete, non-speculative changes in this PR are straightforward and valuable:

- CDATA prohibition in `.github/prompts/claude-code-review.md` (line 206, line 286) — a single-line addition fixing a real bug
- Verdict criteria restructuring — clearer decision tree for COMMENT verdicts
- Removal of the project-level `.claude/skills/code-review/SKILL.md` — genuine simplification

These changes could have been a focused 50-line PR. Bundling them with 800+ lines of documentation and speculative features makes the valuable changes harder to identify and review.

### 6. Self-Review Skill Overlaps Heavily with CI Prompt

`shared/skills/self-review/SKILL.md` (122 lines) and the CI prompt template (212 lines) cover much of the same ground: review dimensions, scoring, verdict criteria, output formatting, and design principles. Rather than establishing a single source of truth, the PR creates a second authoritative document for interactive reviews that will inevitably diverge from the CI prompt — the exact problem described in section 3.1 of the analysis doc.

## Scoring Rationale

| Factor | Assessment |
|--------|-----------|
| KISS | The PR adds 6 files and 846 lines for what is fundamentally a skill relocation + 2 bugfixes. Not simple. |
| YAGNI | The parallel-review skill and future CI agent teams documentation are speculative. |
| DRY | Verdict criteria remain triplicated. The analysis doc duplicates content from skills. |
| Proportionality | 481 lines of documentation for moving a skill file is disproportionate. |
| Bugfix quality | The CDATA fix and verdict restructuring are clean and minimal. |

The bugfixes and skill extraction alone would score 75-80. The speculative features and excessive documentation pull the score down significantly.

## Suggested Inline Comments

**File: `shared/skills/parallel-review/SKILL.md`**
- This entire file documents an experimental feature that cannot be used in CI and has no implementation. Consider deferring to a separate PR when Agent Teams exits experimental status.

**File: `docs/review-system-analysis.md`, lines 203-235 (Section 5: Suggested Improvements)**
- A 7-item improvement roadmap belongs in GitHub issues, not in a committed doc that will become stale. Each suggestion should be an issue with a label.

**File: `docs/review-system-v2-migration-guide.md`, lines 202-227 (CI Agent Teams Integration)**
- This section documents a speculative future feature with blockers that haven't been resolved. It adds noise to a migration guide.

**File: `shared/skills/self-review/SKILL.md`, lines 79-95 (Review Verdict Criteria)**
- These criteria are duplicated from the CI prompt and template. Consider referencing a single canonical source rather than maintaining three copies.

**File: `plugins/scm-utils/skills/self-review/SKILL.md` (symlink)**
- The `../../../../` relative path is fragile. If this is the only consumer of the shared skill, the indirection may not be justified.
