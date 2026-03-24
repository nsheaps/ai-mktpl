# Review System v2 Migration Guide

**Date:** 2026-03-24
**From:** v1 (single-agent CI review, project-level skill)
**To:** v2 (shared skills, parallel agent teams, stricter quality bar)

---

## Overview of Changes

v2 of the review system introduces:

1. **Shared skills architecture** — self-review logic extracted from project-level skill into `shared/skills/`, symlinked into plugins
2. **Parallel review via Agent Teams** — new `parallel-review` skill for fan-out reviews using Claude Code's Agent Teams feature
3. **Stricter non-blocking feedback** — COMMENT verdicts now require justification for why each item shouldn't be addressed
4. **CDATA prevention** — explicit prohibition of `<![CDATA[...]]>` wrappers in all review output
5. **Unified prompt structure** — clear separation of "should include" vs "should not include" in footnote instructions

---

## Migration Steps

### Step 1: Remove Project-Level Code Review Skill

**What changed:** The project-level `.claude/skills/code-review/SKILL.md` has been removed. Its content has been refactored into the shared `self-review` skill.

**Action required:**
```bash
# If you have a project-level code-review skill, remove it
rm -rf .claude/skills/code-review/
```

**Why:** Project-level skills are harder to share across repos. The review logic now lives in `shared/skills/self-review/SKILL.md` and is distributed via the scm-utils plugin.

### Step 2: Update scm-utils Plugin

**What changed:** scm-utils v0.2.0 adds two new shared skills:
- `self-review` — the multi-agent review procedure (was the project-level `code-review` skill)
- `parallel-review` — Agent Teams-based fan-out review

**Action required:**
- Update scm-utils to v0.2.0 or later
- The `code-review` skill continues to work as before (triggers CI review or falls back to local review)
- The new `self-review` skill is used as the fallback when CI is unavailable
- The `parallel-review` skill is available when Agent Teams is enabled

### Step 3: Update Review Prompt Template

**What changed:** The prompt template has been significantly restructured:

1. **CDATA prohibition** — New CRITICAL instruction explicitly banning `<![CDATA[...]]>` wrappers
2. **Verdict criteria** — Restructured from flat CRITICAL lines into a clear decision tree
3. **Non-blocking bar** — COMMENT verdicts now require justification for each item
4. **Footnote structure** — "Must include" and "Must not include" are now separate clearly-labeled sections

**Action required for repos using the review workflow:**

Replace your `.github/prompts/claude-code-review.md` with the updated template from `plugins/scm-utils/skills/code-review/references/prompt-template.md`, then customize as needed.

Key sections to verify after replacement:

```markdown
## Formatting references and footnotes:

CRITICAL: NEVER wrap any part of your review output in `<![CDATA[...]]>` tags.
...

Your footnotes MUST NOT include:
- Links to your previous reviews
- Links to individual comments you made in the review
```

And the verdict section:

```markdown
Use **"COMMENT"** only when ALL of these are true:
- The code won't break if merged as-is
- The suggestions are genuinely optional improvements
- There is a clear, specific reason why each suggestion should NOT be addressed in this PR
```

### Step 4: Update Follow-Up Recommendation Format

**What changed:** Non-blocking follow-up items now MUST include a reason.

**Before (v1):**
```markdown
**Recommended follow-ups** (non-blocking):
- Consider adding unit tests for the new helper function
- The error message could be more descriptive
```

**After (v2):**
```markdown
**Recommended follow-ups** (non-blocking — each item MUST explain why it shouldn't be addressed in this PR):
- Consider adding unit tests — out of scope for this bugfix PR, tracked in #456
- The error message could be more descriptive — requires UX discussion on error messaging standards
```

### Step 5 (Optional): Enable Agent Teams for Parallel Review

**What changed:** The new `parallel-review` skill enables fan-out reviews using Claude Code's Agent Teams feature. This is not required for CI but provides deeper reviews interactively.

**To enable:**

1. Enable Agent Teams:
   ```json
   // .claude/settings.json or ~/.claude/settings.json
   {
     "env": {
       "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
     }
   }
   ```

2. Use tmux mode for visual monitoring:
   ```bash
   claude --teammate-mode tmux
   ```

3. Invoke:
   ```
   /parallel-review #42
   ```

This spawns 8 specialized reviewers (one per quality dimension) that work simultaneously, then synthesizes their findings into a single review.

**Token cost:** ~800k-1.2M tokens vs ~440k for sub-agent review. Use for large/complex PRs where thoroughness justifies the cost.

---

## Architecture: Shared Skills Model

### Before (v1)

```
.claude/skills/code-review/SKILL.md          ← Project-level (multi-agent)
plugins/scm-utils/skills/code-review/SKILL.md ← Plugin (CI setup + trigger)
plugins/scm-utils/.../prompt-template.md      ← Plugin (prompt template)
.github/prompts/claude-code-review.md         ← Project (active CI prompt)
```

Problems:
- Review logic duplicated between project and plugin
- Project skill not shareable
- Prompt templates diverge over time

### After (v2)

```
shared/skills/self-review/SKILL.md            ← Shared (review procedure)
shared/skills/parallel-review/SKILL.md        ← Shared (agent teams review)
plugins/scm-utils/skills/self-review/         ← Symlink → shared
plugins/scm-utils/skills/parallel-review/     ← Symlink → shared
plugins/scm-utils/skills/code-review/SKILL.md ← Plugin (CI setup + trigger, refs self-review)
plugins/scm-utils/.../prompt-template.md      ← Plugin (prompt template, updated)
.github/prompts/claude-code-review.md         ← Project (active CI prompt, updated)
```

Benefits:
- Single source of truth for review logic (shared skills)
- Plugin distributes via symlinks (no duplication)
- CI prompt and template kept in sync
- Parallel review available without code changes

---

## Skill Responsibility Matrix

| Skill | Purpose | Where It Lives | Used By |
|-------|---------|----------------|---------|
| `self-review` | Multi-agent review procedure (scoring, dimensions, output format) | `shared/skills/self-review/` | CI workflow, local fallback, any plugin |
| `parallel-review` | Agent Teams fan-out orchestration | `shared/skills/parallel-review/` | Interactive use with agent teams enabled |
| `code-review` | Trigger CI review or fall back to local review | `plugins/scm-utils/skills/code-review/` | User-facing entry point |

### How They Interact

```
User: "review this PR"
  │
  └─ code-review skill activates
       │
       ├─ CI workflow exists? → Add 'request-review' label → CI runs with prompt template
       │                         └─ Prompt template uses self-review concepts inline
       │
       └─ No CI workflow → self-review skill runs locally
                            └─ Launches sub-agents per dimension
```

```
User: "parallel review PR #42"
  │
  └─ parallel-review skill activates
       │
       ├─ Agent teams enabled? → Creates team, spawns 8 teammates
       │
       └─ Not enabled? → Falls back to self-review (sub-agents)
```

---

## CI Workflow: Future Agent Teams Integration

Currently, the CI workflow runs a single Claude session. A future v3 could adopt agent teams in CI:

```yaml
# Future: claude-code-review.yaml with agent teams
- name: Run Claude Code Review
  uses: anthropics/claude-code-action@v1
  env:
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: '1'
  with:
    prompt: ${{ steps.prompt.outputs.prompt }}
    settings: |
      {
        "teammateMode": "in-process",
        ...
      }
```

This would enable true parallel review in CI, reducing review time for large PRs from 15-20 minutes to 5-8 minutes.

**Blockers for CI agent teams:**
- `claude-code-action` needs to support `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable
- In-process teammate mode must work in GitHub Actions runners
- Token cost needs to be justified by review quality improvement

---

## Breaking Changes

| Change | Impact | Migration |
|--------|--------|-----------|
| Project-level `code-review` skill removed | Local `/review` commands may not trigger | Use scm-utils `code-review` or `self-review` skill instead |
| Non-blocking feedback requires justification | Reviews will have fewer COMMENT verdicts | Update prompt templates per Step 3 |
| Footnote structure changed | Existing prompt templates won't match new format | Replace prompt template per Step 3 |

---

## Rollback

If issues arise after migration:

1. **Restore project-level skill:** Copy `shared/skills/self-review/SKILL.md` to `.claude/skills/code-review/SKILL.md`
2. **Revert prompt changes:** `git checkout origin/main -- .github/prompts/claude-code-review.md`
3. **Downgrade scm-utils:** Pin to v0.1.x in plugin settings
