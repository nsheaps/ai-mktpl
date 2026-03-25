# Best Practices Review — PR #304

**Score: 72 / 100**

---

## Explanation

This PR makes a genuine and meaningful architectural improvement by extracting review logic from a project-level skill (`.claude/skills/code-review/SKILL.md`) into shared skills (`shared/skills/self-review/` and `shared/skills/parallel-review/`), then symlinking them into the scm-utils plugin. This follows the DRY principle and aligns with the repository's established shared-library pattern (see `shared/lib/` and the symlink conventions in `.claude/rules/shared-libs.md`). The extraction eliminates the duplication that existed between the old project-level code-review skill and the plugin's review system, which is a clear win for maintainability.

However, the PR introduces a significant new DRY violation: the verdict criteria, design principles, and formatting instructions are now duplicated across three locations — the CI prompt (`.github/prompts/claude-code-review.md`), the plugin prompt template (`plugins/scm-utils/skills/code-review/references/prompt-template.md`), and the shared self-review skill (`shared/skills/self-review/SKILL.md`). The second commit (`f97c75f`) explicitly synchronizes verdict criteria between the CI prompt and the template, which is the hallmark of a WET (Write Everything Twice) anti-pattern: when you need a "sync" commit to keep two files aligned, the duplication is the root problem. The design principles section appears in all three files with only superficial formatting differences (verbose vs. terse). This is technical debt that undermines the PR's own stated goal of DRY improvement.

The version bump from 0.1.14 to 0.2.0 is semantically correct. The PR removes a project-level skill (`.claude/skills/code-review/SKILL.md`) and replaces it with shared skills exposed through symlinks — this is a breaking change for consumers who relied on the old skill path, justifying a minor version bump. The commit messages are well-structured, follow conventional commit format (`feat:`, `fix:`, `chore:`), and include detailed bodies that explain the "why" alongside the "what." The session link convention is consistently followed.

The shared skill definitions themselves are well-structured — they use YAML frontmatter with clear trigger descriptions and argument hints, follow the repo's skill conventions, and the parallel-review skill properly documents its prerequisites and cost trade-offs. The self-review skill cleanly separates concerns (gather context, launch agents, synthesize, post review) following Single Responsibility at the procedure level.

The error handling story is thin. Neither the self-review nor parallel-review skills address failure modes: what happens when a sub-agent fails to produce a report, when the epoch timestamp directory already exists from a previous run, or when the GitHub API rate-limits inline comment creation. The skills are procedural documents rather than executable code, so this is partially expected, but best practices would include at least a "Failure Handling" section describing expected behavior when things go wrong.

There are no tests in this PR, which is consistent with the nature of the changes (markdown prompt files and symlinks), but the test plan in the PR description is entirely manual checkboxes with none checked. For a system that orchestrates multi-agent reviews, some form of validation — even a simple shell script that verifies symlinks resolve correctly — would demonstrate engineering rigor.

---

## References

| Item | Location |
|------|----------|
| Shared self-review skill (new) | `shared/skills/self-review/SKILL.md` |
| Shared parallel-review skill (new) | `shared/skills/parallel-review/SKILL.md` |
| Removed project-level skill | `.claude/skills/code-review/SKILL.md` (deleted) |
| Symlink: self-review in scm-utils | `plugins/scm-utils/skills/self-review/SKILL.md` -> `../../../../shared/skills/self-review/SKILL.md` |
| Symlink: parallel-review in scm-utils | `plugins/scm-utils/skills/parallel-review/SKILL.md` -> `../../../../shared/skills/parallel-review/SKILL.md` |
| CI prompt (verdict criteria duplicated here) | `.github/prompts/claude-code-review.md` (lines 172-194) |
| Plugin prompt template (verdict criteria duplicated here) | `plugins/scm-utils/skills/code-review/references/prompt-template.md` (lines 130-151) |
| Self-review skill (verdict criteria also here) | `shared/skills/self-review/SKILL.md` (lines 79-95) |
| Design principles in CI prompt | `.github/prompts/claude-code-review.md` (lines 223-246) |
| Design principles in template | `plugins/scm-utils/skills/code-review/references/prompt-template.md` (line 196) |
| Design principles in self-review | `shared/skills/self-review/SKILL.md` (lines 116-122) |
| Version bump 0.1.14 -> 0.2.0 | `.claude-plugin/marketplace.json`, `plugins/scm-utils/.claude-plugin/plugin.json` |
| Commit: main feature | [`a5bb23c`](https://github.com/nsheaps/ai-mktpl/commit/a5bb23c2dc4fd7f8538a074e4e776016bb4330f7) — conventional `feat:` with detailed body |
| Commit: review feedback | [`f97c75f`](https://github.com/nsheaps/ai-mktpl/commit/f97c75fbb23143db325347188babf22b8459ea6d) — conventional `fix:` addressing review sync |
| Shared lib symlink pattern (precedent) | `.claude/rules/shared-libs.md` |
| Versioning rules | `.claude/rules/versioning.md` |

---

## Key Findings Summary

| Aspect | Assessment |
|--------|-----------|
| DRY improvement (shared skills extraction) | Positive — eliminates project-vs-plugin skill duplication |
| DRY violation (verdict criteria x3) | Negative — three locations must stay synchronized manually |
| DRY violation (design principles x3) | Negative — same principles listed in three files with formatting drift |
| Commit message quality | Strong — conventional format, detailed bodies, session links |
| Semver correctness (0.1.14 -> 0.2.0) | Correct — breaking change (removed project skill) justifies minor bump |
| Skill definition quality | Good — clear frontmatter, separation of concerns, documented tradeoffs |
| Error handling in skills | Weak — no failure mode documentation for sub-agent or API failures |
| Testing | Absent — manual test plan only, no automated validation of symlinks or structure |
