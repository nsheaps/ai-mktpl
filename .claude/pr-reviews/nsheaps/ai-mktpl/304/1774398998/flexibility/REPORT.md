# Flexibility Review - PR #304

**Score: 82/100**

![Flexibility](https://img.shields.io/badge/82%25-%20?style=for-the-badge&label=Flexibility&labelColor=%23444&color=%23C0C040)

## Explanation

This PR makes a strong structural move toward the Open/Closed principle by extracting review logic from a project-level skill into `shared/skills/` and distributing it to plugins via symlinks. The shared skills pattern (`shared/skills/self-review/` and `shared/skills/parallel-review/`) follows a convention already well-established in this repo for shared libraries (`shared/lib/`), as evidenced by dozens of existing symlinks from 15+ plugins into `shared/lib/`. Extending the same pattern to skills is a natural, proven progression. New review dimensions can be added to the self-review skill's dimension table without modifying any plugin code, and new shared skills can be created in `shared/skills/` and symlinked into any plugin that needs them. The `code-review` entry point skill delegates cleanly to either CI or the self-review fallback, keeping routing logic separate from review logic. The parallel-review skill is purely additive and optional, gated behind an environment variable.

However, several flexibility concerns prevent a higher score. The CI prompt template (`plugins/scm-utils/skills/code-review/references/prompt-template.md`) and the shared self-review skill (`shared/skills/self-review/SKILL.md`) encode overlapping review criteria that must be kept in sync manually. The analysis document itself identifies this as the "Template Synchronization Problem" (Section 3.5 of `docs/review-system-analysis.md`, lines 163-168) but this PR does not resolve it. Adding or modifying a review dimension (e.g., adding "Accessibility" or "Performance" as a 9th dimension) requires changes in at least two files: the shared self-review skill and the CI prompt template. Similarly, the parallel-review skill hardcodes 8 teammate slots that mirror the self-review dimensions, meaning a dimension change requires updating both skills. The review dimensions are defined as a markdown table rather than as data that could be programmatically consumed, which limits machine-extensibility. Finally, other repos adopting this system must copy the prompt template and workflow template rather than referencing them, meaning upstream improvements require manual re-synchronization.

## Strengths

- **Proven symlink pattern extended to skills**: The `shared/ -> plugins/` symlink convention is already used by `shared/lib/` across 15+ plugins (e.g., `plugins/github/lib/log.sh -> ../../../shared/lib/log.sh`, `plugins/github-app/skills/github-auth/SKILL.md -> ../../../../shared/skills/github-auth/SKILL.md`). Extending this to review skills is consistent and zero-friction for existing contributors.
- **New dimensions addable without modifying routing**: The `code-review` skill in `plugins/scm-utils/skills/code-review/SKILL.md` (lines 30-32) routes to self-review without knowledge of which dimensions exist. Adding a 9th dimension only requires editing the self-review skill, not the entry point.
- **Parallel-review is purely additive**: `shared/skills/parallel-review/SKILL.md` is an opt-in skill gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (line 19). Repos that don't enable Agent Teams are completely unaffected.
- **Migration guide provides rollback path**: `docs/review-system-v2-migration-guide.md` (lines 240-246) documents how to revert to v1, which is important for a system where extensibility might introduce regressions.
- **Clear skill responsibility separation**: The Skill Responsibility Matrix in the migration guide (lines 170-174) cleanly separates "trigger routing" (code-review), "review procedure" (self-review), and "parallel orchestration" (parallel-review).

## Weaknesses

- **Dual-maintenance for review criteria**: The CI prompt template at `plugins/scm-utils/skills/code-review/references/prompt-template.md` (lines 130-151) and the self-review skill at `shared/skills/self-review/SKILL.md` (lines 79-95) both define verdict criteria. These must be manually synchronized. The analysis identifies this (Section 3.5, `docs/review-system-analysis.md` lines 163-168) but the PR does not introduce any mechanism (e.g., a shared partial, or generation from a single source) to enforce consistency.
- **Hardcoded dimension list in parallel-review**: `shared/skills/parallel-review/SKILL.md` lines 46-53 hardcode 8 specific teammate names. Adding a dimension requires editing both the self-review dimension table and the parallel-review teammate list. A data-driven approach (e.g., a shared `dimensions.yaml` consumed by both skills) would improve extensibility.
- **No plugin interface contract for dimensions**: Review dimensions are defined in prose markdown tables. There is no schema or interface that a new dimension must implement, making it unclear what a well-formed dimension plugin would look like. This contrasts with the more structured `shared/lib/` pattern which has documented conventions (double-source guards, function prefixes) in `.claude/rules/shared-libs.md`.
- **Template adoption requires copy, not reference**: External repos must copy `prompt-template.md` and `workflow-template.yaml` into their own repos (per `plugins/scm-utils/skills/code-review/SKILL.md` lines 81-84). There is no mechanism to pull upstream updates automatically, meaning the system forks rather than extends for external consumers.
- **marketplace.json version still shows 0.1.14 on main**: The PR updates `plugin.json` to 0.2.0 but `marketplace.json` still lists 0.1.14 (line 457 of `.claude-plugin/marketplace.json`). While the CD workflow handles this on merge, during the PR lifecycle this creates a visible inconsistency that could confuse tooling or consumers checking compatibility.

## References

| File | Relevance |
|------|-----------|
| `shared/skills/self-review/SKILL.md` | Core shared review procedure; dimension table at lines 17-28 |
| `shared/skills/parallel-review/SKILL.md` | Agent Teams fan-out; hardcoded teammates at lines 46-53 |
| `plugins/scm-utils/skills/code-review/SKILL.md` | Entry point routing; CI-or-fallback logic at lines 17-31 |
| `plugins/scm-utils/skills/code-review/references/prompt-template.md` | CI prompt template; verdict criteria at lines 130-151 |
| `docs/review-system-analysis.md` | Self-identified template sync problem at Section 3.5, lines 163-168 |
| `docs/review-system-v2-migration-guide.md` | Architecture diagrams at lines 134-164; rollback at lines 240-246 |
| `.claude/rules/shared-libs.md` | Established shared library conventions (prior art for symlink pattern) |
| `plugins/github-app/skills/github-auth/SKILL.md` | Pre-existing shared skill symlink (prior art) |
| `.claude-plugin/marketplace.json` | Version listing at line 457 |
