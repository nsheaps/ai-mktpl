# Artifact Linking in Completion Reports

**CRITICAL:** Every task completion report to the user MUST include links to all produced artifacts.

## Rule

When reporting that a task is complete, you MUST include **every applicable** item from this checklist:

| Artifact Type | Format |
|---|---|
| GitHub Issue | `[#123](https://github.com/org/repo/issues/123)` |
| Pull Request | `[PR #456](https://github.com/org/repo/pull/456)` |
| Commit | `abc1234` (short hash) |
| File created/modified | Absolute path: `/path/to/file.md` |
| External URL | Full URL as markdown link |
| Branch | Branch name |

## Why This Matters

- Users should never have to ask "where is it?" after a completion report
- Links make reports actionable — the user can click/navigate immediately
- Omitting links forces unnecessary back-and-forth

## Examples

**Bad:**

> "I created the spec and opened a GitHub issue for tracking."

**Good:**

> "I created the spec at `/repo/docs/specs/draft/feature-x.md` and opened [#42](https://github.com/org/repo/issues/42) for tracking. Commit: `a1b2c3d`."

**Bad (team lead reporting sub-agent work):**

> "Road Runner completed the research on teammate launch behavior. Key findings: spawn is not customizable, delegate mode has a bug."

**Good (team lead reporting sub-agent work):**

> "Road Runner completed the research on teammate launch behavior. Report saved to `/repo/.claude/tmp/teammate-launch-research.md`. Key findings: spawn is not customizable, delegate mode has a bug ([#25037](https://github.com/anthropics/claude-code/issues/25037))."

## Applies To

- Direct task completions reported to the user
- Sub-agent work summarized by the orchestrator/team lead
- Status updates that reference completed work
- Any message that says "done", "complete", "finished", or equivalent
