# QA/Engineering Review — PR #304

**Score: 30/100**

## Explanation

This PR introduces significant architectural changes to the review system (shared skills, symlinks, prompt restructuring, new documentation) but has **no automated tests, no prompt validation, and no structural verification** covering any of the new or modified content. The repository has zero test files (`*.test.*`, `*.spec.*`), and the existing CI pipeline (lint + validate) only checks plugin manifest structure, hook file references, and formatting — it does not validate prompt template content, skill file format, symlink correctness, scoring rule consistency, or markdown structure of review output templates.

The changes are primarily prompt/markdown files and symlinks, which are inherently difficult to test, but the review system is a critical operational component (it gates PR merges). The lack of any validation means regressions in prompt instructions, broken symlinks after plugin install, or scoring rule inconsistencies can only be caught by manual observation of review outputs.

Specific QA concerns:

1. **No test coverage at all.** The repository contains zero test files. There are no unit tests, integration tests, or smoke tests for any component, including the review system.

2. **Scoring threshold inconsistency between emoji and badge colors.** In `shared/skills/self-review/SKILL.md`, the emoji thresholds define red as "below 70%" while the badge color thresholds on line 112 define red as "<65". A score of 66 would render as a yellow badge but get a red emoji. The same mismatch exists in the CI prompt (`claude-code-review.md` line 273: "65+ yellow" vs the self-review skill's "below 70%" for red). This is a concrete edge case that could produce visually contradictory review output.

3. **No automated validation of prompt template format.** The PR adds a CDATA prohibition and restructures verdict criteria, but there is no CI step that validates the prompt markdown is well-formed, that `<details>/<summary>` blocks are balanced, that shields.io badge URL patterns are valid, or that CDATA wrappers are absent. The analysis document (`docs/review-system-analysis.md` section 3.3) explicitly identifies this gap but the PR does not address it.

4. **Symlinks are valid but not CI-verified.** The two new symlinks (`plugins/scm-utils/skills/self-review/SKILL.md` and `plugins/scm-utils/skills/parallel-review/SKILL.md`) resolve correctly to their targets in `shared/skills/`. However, the `validate-claude-config` task and `validate-plugin` task do not check symlink integrity. If the shared directory structure changes, symlinks would break silently.

5. **CI prompt and plugin template are manually synced.** Both `.github/prompts/claude-code-review.md` and `plugins/scm-utils/skills/code-review/references/prompt-template.md` received parallel edits for the verdict criteria and CDATA fix, but there is no automated check that these two files stay in sync. The analysis document acknowledges this (section 3.5) but the PR does not add any validation.

6. **Edge case in overall scoring rule.** The self-review skill states: "If any category has a warning, the overall score should reflect that no category achieved green level." This is vague — it does not define a maximum overall score when warnings exist. The old deleted skill had a concrete rule ("maximum overall score is 94%") which was reportedly removed per PR feedback, but no replacement ceiling was defined. This could lead to an overall score of 96% (triggering the ">95% minimal detail" rule) even when individual categories have warnings.

7. **No validation that the PR's test plan items were executed.** The PR body contains a 5-item test plan (all unchecked), suggesting manual verification was planned but not completed at the time of review.

8. **The `claude-review` check was skipped.** The CI run shows `claude-review` with conclusion "skipped" because the PR is in draft state. This means the review prompt changes themselves were not exercised by the system they modify.

## References

- Symlink verification: `plugins/scm-utils/skills/self-review/SKILL.md` -> `../../../../shared/skills/self-review/SKILL.md` (valid, resolves to `/home/user/ai-mktpl/shared/skills/self-review/SKILL.md`)
- Symlink verification: `plugins/scm-utils/skills/parallel-review/SKILL.md` -> `../../../../shared/skills/parallel-review/SKILL.md` (valid, resolves to `/home/user/ai-mktpl/shared/skills/parallel-review/SKILL.md`)
- CI check runs: lint (success), validate (success), claude-review (skipped), auto-version-bump (success) — [CI run](https://github.com/nsheaps/ai-mktpl/actions/runs/23518602431)
- Scoring threshold mismatch: `shared/skills/self-review/SKILL.md` lines 61-63 (emoji: 70/85) vs line 112 (badge: 65/85)
- CI prompt badge thresholds: `.github/prompts/claude-code-review.md` line 273 ("85+ green, 65+ yellow")
- Plugin validation task: `mise/tasks/validate-plugin` (uses `claude plugin validate`, does not check symlinks or prompt content)
- Config validation task: `mise/tasks/validate-claude-config` (checks enabledPlugins, hook refs, plugin names — not skills or prompts)
- Old scoring cap removal: deleted `.claude/skills/code-review/SKILL.md` had "maximum overall score is 94%" rule; replacement in `shared/skills/self-review/SKILL.md` line 64 uses vaguer language
- Analysis document gap acknowledgment: `docs/review-system-analysis.md` sections 3.3 (no output validation), 3.5 (template sync problem)
- PR test plan: PR body contains 5 unchecked items at time of review
