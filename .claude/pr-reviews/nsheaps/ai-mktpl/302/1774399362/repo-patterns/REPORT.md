# Repo Patterns Review: PR #302

**Score: 82/100**

## Summary

The new `pr-feedback` skill follows most established repo patterns well. The file location, frontmatter format, plugin.json keyword additions, and cross-skill references are all correct. The main issues are a missing `argument-hint` frontmatter field (which many comparable skills include), a version jump from 0.1.12 to 0.1.14 that skips 0.1.13 in the github plugin, and numerous unrelated plugin version bumps from CD automation that inflate the diff. The skill content itself is structurally consistent with sibling skills in the github plugin.

## Detailed Findings

### File Location (PASS)

The skill is placed at `plugins/github/skills/pr-feedback/SKILL.md`, which follows the standard `plugins/{plugin-name}/skills/{skill-name}/SKILL.md` convention documented in `.claude/rules/plugin-development.md`. This matches the pattern used by all other skills in the repo (e.g., `plugins/github/skills/gh/SKILL.md`, `plugins/scm-utils/skills/commit/SKILL.md`).

### Frontmatter Format (MINOR ISSUE)

The frontmatter contains the required `name` and `description` fields with proper YAML block scalar syntax (`>`), matching the pattern in `plugins/github/skills/github-auth/SKILL.md`. The `<example>` tags embedded in the description field also match the pattern used by `github-auth` (5 examples) -- `pr-feedback` uses 7 examples, which is reasonable.

**Missing `argument-hint`:** Many comparable skills include an `argument-hint` field in their frontmatter. For example:
- `plugins/scm-utils/skills/code-review/SKILL.md`: `argument-hint: [PR number | PR URL | branch name]`
- `plugins/scm-utils/skills/commit/SKILL.md`: `argument-hint: [optional hint]`
- `plugins/scm-utils/skills/rebase/SKILL.md`: `argument-hint: [PR number | PR URL | branch name | directory]`

Since `pr-feedback` can accept a PR number or URL as context, an `argument-hint` like `[PR number | PR URL]` would be consistent with sibling skills. However, not all skills use this field (e.g., `plugins/github/skills/gh/SKILL.md` and `plugins/scm-utils/skills/auto-pr/SKILL.md` omit it), so this is not a hard requirement -- it is a pattern that would improve consistency with the most closely analogous skills.

### Plugin.json Keywords (PASS)

The `plugins/github/.claude-plugin/plugin.json` correctly adds four new keywords: `"pr-feedback"`, `"code-review"`, `"ci-failures"`, `"review-comments"`. These are descriptive of the new skill's capabilities and follow the lowercase-hyphenated naming convention used by existing keywords in the file.

### Version Bump (MINOR ISSUE)

The github plugin version jumps from `0.1.12` to `0.1.14`, skipping `0.1.13`. Per `.claude/rules/versioning.md`, the CD workflow's `auto-version-bump` job handles patch increments automatically, and manual bumps to higher versions are preserved. The skip from .12 to .14 suggests either a manual bump that overshot, or an intermediate version existed in a prior PR cycle. This is not a blocking issue since the CD system will accept it, but it breaks the sequential patch-version convention and could cause confusion when tracing version history.

### Unrelated Version Bumps (OBSERVATION)

The PR includes patch version bumps for 9 unrelated plugins (1pass, common-sense, git-spice, github-app, google-workspace-cli, mise, permissions-sync, scm-utils, sequential-thinking) plus the `marketplace.json` regeneration. Per `.claude/rules/versioning.md`, these are produced by the CD `auto-version-bump` job and are expected behavior -- they do not represent manual changes by the PR author. The `marketplace.json` changes are auto-generated. This is normal for the repo but inflates the diff significantly.

### Cross-Skill References (PASS)

The skill correctly references `scm-utils:commit` in two places (Step 2 Category D and the Workflow Summary), using the `{plugin}:{skill}` notation convention. This matches how other skills reference cross-plugin dependencies (e.g., `scm-utils/skills/code-review/SKILL.md` references `pr-review-toolkit:review-pr`).

### Skill Structure (PASS)

The skill follows the structural conventions observed in comparable skills:
- Starts with a clear title and purpose statement
- Uses numbered steps with sub-sections
- Provides both MCP tool and `gh` CLI fallback approaches (matching the dual-approach pattern in `plugins/github/skills/gh/SKILL.md`)
- Includes tables for quick reference (matching `github-auth` and `code-review` patterns)
- Ends with a summary workflow

### Naming Conventions (PASS)

- Skill name `pr-feedback` uses lowercase-hyphenated format, consistent with `github-auth`, `auto-pr`, `code-review`, etc.
- Directory name matches the `name` field in frontmatter
- No casing violations detected

### Content vs. Rules Boundary (PASS)

Per `.claude/rules/plugin-development.md`, skills capture "how" (procedures, code snippets, implementation steps) while rules capture "when" and "what". This skill appropriately contains procedural how-to content with code examples, not behavioral policy. It belongs in a skill, not a rule.

## Files Referenced

- `plugins/github/skills/pr-feedback/SKILL.md` -- the new skill (378 lines)
- `plugins/github/.claude-plugin/plugin.json` -- keywords and version bump
- `plugins/github/skills/gh/SKILL.md` -- existing github skill (comparison)
- `plugins/github/skills/github-auth/SKILL.md` -- existing github skill with `<example>` tags (comparison)
- `plugins/scm-utils/skills/commit/SKILL.md` -- cross-referenced skill with `argument-hint` (comparison)
- `plugins/scm-utils/skills/code-review/SKILL.md` -- similar domain skill (comparison)
- `.claude/rules/plugin-development.md` -- plugin structure requirements
- `.claude/rules/versioning.md` -- version bump conventions
- `.claude-plugin/marketplace.json` -- auto-generated marketplace listing
