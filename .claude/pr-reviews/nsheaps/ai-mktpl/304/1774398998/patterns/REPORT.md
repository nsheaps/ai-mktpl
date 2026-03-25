# Patterns Review — PR #304

**Score: 88 / 100**

## Explanation

This PR demonstrates strong adherence to established repo patterns and introduces the `shared/skills/` directory pattern in a way that is consistent with existing precedent. The `shared/` directory already existed prior to this PR with `shared/lib/` (documented in `.claude/rules/shared-libs.md`) and `shared/skills/github-auth/` (symlinked into both `plugins/github-app/` and `plugins/github/`). The new `shared/skills/self-review/` and `shared/skills/parallel-review/` directories follow this exact same convention: canonical content lives in `shared/skills/<name>/SKILL.md`, and plugins consume it via relative symlinks using the `../../../../shared/skills/<name>/SKILL.md` path pattern. The symlink depth and structure are identical to the existing `github-auth` symlinks, which shows the author understood and replicated the established approach rather than inventing something new.

The SKILL.md frontmatter for both new shared skills (`self-review` and `parallel-review`) follows the conventions used by other scm-utils skills: `name`, `description` (using YAML `>` block scalar for multi-line), and `argument-hint`. This matches the pattern seen in `code-review`, `commit`, `rebase`, and other scm-utils skills. The `description` field includes trigger phrases, consistent with skills like `sequential-thinking` and `code-simplifier`.

The version bump from 0.1.14 to 0.2.0 is appropriate per the repo's versioning rules in `.claude/rules/versioning.md`, which specifies minor bumps (x.Y.0) for "new features, backwards compatible." This PR introduces two new skills (`self-review` and `parallel-review`) and removes a project-level skill, which constitutes a new feature with a breaking change for the removed skill. A minor bump is the correct choice; arguably, the removal of `.claude/skills/code-review/SKILL.md` could be considered a breaking change warranting a major bump, but since it was a project-level skill (not distributed via plugin) and is replaced by the shared equivalent, minor is reasonable. The version is updated consistently in both `plugin.json` and `marketplace.json`.

The new docs (`docs/review-system-analysis.md` and `docs/review-system-v2-migration-guide.md`) are placed in the existing `docs/` directory, consistent with other documentation files like `docs/shared-logging.md`, `docs/glossary.md`, and `docs/installation.md`. The documentation style (markdown with tables, code blocks, and flow diagrams) matches the existing docs pattern.

Points deducted:

1. **Prompt template sync concern (minor, -4):** The CI prompt (`.github/prompts/claude-code-review.md`) and the plugin prompt template (`plugins/scm-utils/skills/code-review/references/prompt-template.md`) receive identical changes but remain separate files. The PR's own analysis document acknowledges this as a weakness ("The CI prompt and plugin template still need to be kept in sync manually"), yet does not address it with the same shared/symlink pattern applied to skills. This is an inconsistency in the application of the PR's own introduced pattern.

2. **No shared skill documentation in rules (minor, -4):** The existing `shared/lib/` pattern is thoroughly documented in `.claude/rules/shared-libs.md`, including conventions for adding new shared libraries. The analogous `shared/skills/` pattern has no equivalent rule file documenting conventions for shared skills (when to use shared vs. plugin-local skills, symlink conventions, naming). This omission departs from the documentation-forward pattern established by `shared-libs.md`.

3. **Removed project-level skill without redirect (minor, -4):** The project-level `.claude/skills/code-review/SKILL.md` is deleted outright. Other cross-cutting concerns in this repo (like the `github-auth` shared skill) are made available at both the shared and plugin level. There is no project-level skill or redirect that would help users who previously invoked `/code-review` from the project skill discover that it has moved. The plugin's `code-review` skill now references `self-review`, but this depends on the scm-utils plugin being installed.

## References

- **Existing shared skills pattern (precedent):** `shared/skills/github-auth/SKILL.md` symlinked from `plugins/github-app/skills/github-auth/SKILL.md` and `plugins/github/skills/github-auth/SKILL.md`
- **Existing shared libs documentation:** `.claude/rules/shared-libs.md` — documents the `shared/lib/` convention and how to add new shared libraries
- **Versioning rules:** `.claude/rules/versioning.md` — defines patch/minor/major bump criteria
- **Plugin development guidelines:** `.claude/rules/plugin-development.md` — defines plugin structure requirements and skills conventions
- **SKILL.md frontmatter convention:** `plugins/scm-utils/skills/code-review/SKILL.md`, `plugins/scm-utils/skills/commit/SKILL.md`, `plugins/sequential-thinking/skills/sequential-thinking/SKILL.md` — examples of `name`, `description`, `argument-hint` frontmatter
- **Existing docs directory:** `docs/shared-logging.md`, `docs/glossary.md`, `docs/installation.md` — established documentation location and style
- **Marketplace version entry:** `.claude-plugin/marketplace.json` line 457 — scm-utils version updated from 0.1.14 to 0.2.0
- **Plugin version entry:** `plugins/scm-utils/.claude-plugin/plugin.json` — version updated consistently
