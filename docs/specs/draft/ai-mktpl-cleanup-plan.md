# ai-mktpl Cleanup Plan

**Status**: Draft — for user review before execution
**Author**: Tweety Bird (docs-writer), looney-tunes team
**Date**: 2026-02-18

## Summary

This document catalogs cleanup work needed in the ai-mktpl repo (`nsheaps/ai`). Items are grouped by category and prioritized. Each item includes a clear action and estimated effort.

---

## Priority 1: Broken or Incomplete Plugins

### P1-1: `fix-pr` plugin has no plugin.json

- **Path**: `plugins/fix-pr/.claude-plugin/` (empty directory)
- **Issue**: Plugin directory exists with `commands/` and `skills/` but `.claude-plugin/plugin.json` is missing. Claude Code cannot load it.
- **Action**: Either create a valid `plugin.json` or remove the plugin if it was abandoned.
- **Effort**: Small

### P1-2: `context-bloat-prevention` plugin is untracked

- **Path**: `plugins/context-bloat-prevention/`
- **Issue**: Fully formed plugin (plugin.json, hooks, scripts, README) but never committed to git.
- **Action**: Review and commit. It was created during this session by Wile E. (task #80).
- **Effort**: Small

### P1-3: `fix-pr` and `review-changes` plugins missing READMEs

- **Paths**: `plugins/fix-pr/README.md`, `plugins/review-changes/README.md`
- **Issue**: Every other plugin has a README. These two don't.
- **Action**: Write READMEs following the pattern of other plugins.
- **Effort**: Small

---

## Priority 2: Uncommitted Changes from Teammates

### P2-1: 60+ modified files not staged or committed

- **Issue**: `git status` shows modifications across many files — rules, plugin.json files, READMEs, scripts, docs. These appear to be from multiple teammates working concurrently.
- **Key modified files**:
  - `.ai/rules/mantras-and-incremental-development.md` (rule update)
  - `docs/specs/draft/transcript-monitor-plugin.md` (spec edit)
  - `plugins/statusline/bin/statusline.sh`, `hooks/configure-statusline.sh` (statusline changes)
  - Many `plugin.json` and `README.md` files across plugins (likely Foghorn's rename updates)
- **Action**: Review each change, commit in logical groups (formatting, content, config).
- **Effort**: Medium — needs careful review to avoid committing unintended changes

### P2-2: Untracked spec: `docs/specs/draft/agent-representation.md`

- **Issue**: New spec file not yet committed.
- **Action**: Review and commit (likely from Bugs's task #94).
- **Effort**: Small

---

## Priority 3: Documentation Gaps

### P3-1: No top-level LICENSE file

- **Issue**: The README says "Proprietary. All rights reserved." but there's no LICENSE file.
- **Action**: Add a LICENSE file matching the intended license, or add a more explicit proprietary notice.
- **Effort**: Small

### P3-2: `prompts/` directory is undocumented

- **Path**: `prompts/`
- **Contents**: `CLAUDE.md`, `claude/kentwilliam/_CLAUDE.md`, `claude/plan-the-plan.md`, `copilot/nsheaps/_PERSONAL.md`
- **Issue**: This directory holds shared prompt configurations but isn't mentioned in the README or documented. Purpose unclear — is it a community prompt library? Personal config? Upstream defaults?
- **Action**: Document purpose, or move contents to more appropriate locations (e.g., `.ai/prompts/`).
- **Effort**: Small

### P3-3: `docs/` has loose files that may be stale

- **Files**:
  - `docs/claude-agent-workflow.md` — purpose unclear
  - `docs/glossary.md` — may be outdated
  - `docs/wishlist.md` — feature wishlist, may overlap with `docs/specs/draft/plugin-ideas.md`
  - `docs/plugins-depending-on-another.md` — design doc, may need updating
  - `docs/PLUGIN_SCHEMA.md` — schema reference, needs freshness check
- **Action**: Audit each file. Archive stale ones, update current ones, merge duplicates.
- **Effort**: Medium

### P3-4: 12 draft specs with no reviewed/in-progress/live lifecycle

- **Path**: `docs/specs/draft/`
- **Issue**: All 12 specs sit in `draft/` with no promotion workflow. The `docs/specs/` directory has no `reviewed/`, `in-progress/`, `live/`, or `archive/` subdirectories per the project's spec lifecycle convention.
- **Specs**:
  - `agent-config-typescript-cli.md`
  - `agent-representation.md` (untracked)
  - `ai-content-separation.md`
  - `cicd-enhancements.md`
  - `developer-experience.md`
  - `documentation-improvements.md`
  - `enterprise-brew-formula.md`
  - `git-status-watch-plugin.md`
  - `marketplace-features.md`
  - `plugin-ideas.md`
  - `plugin-update-checker.md`
  - `transcript-monitor-plugin.md`
- **Action**: Create lifecycle directories. Triage each spec — archive abandoned ones, promote active ones.
- **Effort**: Medium

---

## Priority 4: Structural Inconsistencies

### P4-1: `.claude-plugin/` at repo root doesn't exist

- **Issue**: The README describes this as a "plugin marketplace" but the repo root itself doesn't have a `.claude-plugin/plugin.json`. It's not clear if the repo itself is meant to be installable as a plugin, or if it's just a collection.
- **Action**: Decide: Is the repo itself a plugin? If yes, add root plugin.json. If no, document that it's a collection only.
- **Effort**: Small — decision needed

### P4-2: `.ai/plugins/` vs `plugins/` split

- **Path**: `.ai/plugins/agent-teams-skills/` vs `plugins/` (27 plugins)
- **Issue**: One plugin lives under `.ai/plugins/` while 27 live under `plugins/`. The `.ai/plugins/` location is for organization-wide config (synced to `~/.claude/`), while `plugins/` is the marketplace. This split is intentional but undocumented.
- **Action**: Document the distinction in README or a CONTRIBUTING guide.
- **Effort**: Small

### P4-3: `bin/` scripts purpose unclear

- **Path**: `bin/agent-config`, `bin/claude-diagnostics`, `bin/clean-duplicate-changelogs.sh`, `bin/op-exec`, `bin/lib/`
- **Issue**: These scripts aren't documented anywhere. What is `agent-config`? What is `op-exec`? Are they for development, CI, or user consumption?
- **Action**: Document each script's purpose, or move dev-only scripts to a `scripts/` directory.
- **Effort**: Small

### P4-4: `rc.d/` directory purpose unclear

- **Path**: `rc.d/00_direnv-helpers.sh`, `rc.d/01_mise-activate.sh`, `rc.d/05_add-bin-to-path.sh`
- **Issue**: Shell init scripts for direnv/mise. Not documented. Presumably for development environment setup but this is unusual for a plugin marketplace.
- **Action**: Document in README's Development section, or move to a standard location.
- **Effort**: Small

---

## Priority 5: Potential Duplication

### P5-1: `.ai/commands/` duplicates `plugins/` commands

- **Commands in `.ai/commands/`**: `correct-behavior.md`, `create-command.md`, `review-changes.md`, `relentlessly-fix.md`
- **Same commands in plugins**: `plugins/correct-behavior/`, `plugins/create-command/`, `plugins/review-changes/`
- **Issue**: Commands exist both in `.ai/commands/` (synced to user `~/.claude/commands/`) and as plugin commands. Users who install the plugins AND have the org-wide sync get duplicates.
- **Action**: Decide on canonical location. Either remove from `.ai/commands/` (prefer plugins) or document the intentional overlap.
- **Effort**: Small — decision needed

### P5-2: `.ai/rules/preferences.md` and `.ai/rules/tool-preferences.md` overlap

- **Issue**: Both files cover tool preferences, package manager preferences, and general workflow patterns. The `preferences.md` file even has a TODO comment saying `<!-- TODO combine with tool-preferences.md -->`.
- **Action**: Merge into a single file as the TODO suggests.
- **Effort**: Small

### P5-3: `docs/wishlist.md` may overlap with `docs/specs/draft/plugin-ideas.md`

- **Issue**: Both appear to track feature ideas. May have redundant content.
- **Action**: Compare and consolidate.
- **Effort**: Small

---

## Priority 6: Config and Tooling Cleanup

### P6-1: `.claude/plans/.DS_Store` tracked in git

- **Path**: `.claude/plans/.DS_Store`
- **Issue**: macOS artifact tracked in git. Should be in `.gitignore`.
- **Action**: Remove from git, add to `.gitignore`.
- **Effort**: Trivial

### P6-2: `.gitignore` completeness check

- **Issue**: Should verify `.DS_Store`, `.claude/memory.jsonl`, `.claude/settings.local.json`, `.claude/todos/` are all properly gitignored.
- **Action**: Audit `.gitignore` and add missing patterns.
- **Effort**: Small

### P6-3: `docs/scratch/` has only one file

- **Path**: `docs/scratch/readme-installation-updates-summary.md`
- **Issue**: Single scratch file. Is this directory needed, or should the file be moved?
- **Action**: Either add `.gitkeep` and document as a scratch pad, or move the file to `docs/` and remove the directory.
- **Effort**: Trivial

---

## Execution Order

Recommended order for tackling these items:

1. **Quick wins first** (P6-1, P1-2, P1-1, P1-3) — trivial fixes that improve repo hygiene
2. **Decisions needed** (P4-1, P5-1) — require user input before proceeding
3. **Uncommitted changes** (P2-1, P2-2) — review and commit the backlog
4. **Documentation** (P3-2, P3-3, P4-2, P4-3, P4-4) — fill gaps
5. **Consolidation** (P5-2, P5-3, P3-4) — merge duplicates, triage specs
6. **Structural** (P3-1, P3-4) — add LICENSE, create spec lifecycle dirs

---

## Open Questions for User

1. **Is `fix-pr` plugin intentional or abandoned?** It has no plugin.json and no README. Should we flesh it out or remove it?
2. **Should the repo root be a plugin?** Currently no `.claude-plugin/plugin.json` at root. Is the repo just a collection, or should it be installable as a meta-plugin?
3. **Where should commands live canonically?** `.ai/commands/` (org-wide) or `plugins/*/commands/` (per-plugin)? Having both causes duplication.
4. **What license applies?** README says "Proprietary" but no LICENSE file exists.
5. **What's the `prompts/` directory for?** It has content from multiple users (kentwilliam, nsheaps). Is this a community contribution area?
