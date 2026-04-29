# Artifact Linking in Completion Reports

**CRITICAL:** Every task completion report to the user MUST include links to all produced artifacts.

## Rule

When reporting that a task is complete, you MUST include **every applicable** item from this checklist:

| Artifact Type         | Format                                                                  |
| --------------------- | ----------------------------------------------------------------------- |
| GitHub Issue          | `[#123](https://github.com/org/repo/issues/123)`                        |
| Pull Request          | `[PR #456](https://github.com/org/repo/pull/456)`                       |
| Commit                | `abc1234` (short hash)                                                  |
| File created/modified | GitHub blob URL: `https://github.com/org/repo/blob/<ref>/path/file.md`  |
| External URL          | Full URL as markdown link                                               |
| Branch                | Branch name                                                             |

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

## Links Must Be Reachable — No Local Paths, No `file://` URLs

**CRITICAL:** When you reference a file the handler may want to open (a plan, research note, draft spec, generated doc, transcript, anything in a local repo), commit and push it FIRST, then link to the **GitHub URL**. The handler is on Discord/Telegram and cannot open paths that only exist on the agent's host.

### Acceptable link formats

- `https://github.com/<owner>/<repo>/blob/main/<path>` — file on the default branch (latest)
- `https://github.com/<owner>/<repo>/blob/<branch>/<path>` — file on a feature branch
- `https://github.com/<owner>/<repo>/blob/<sha>/<path>` — commit-pinned (preferred when referencing a snapshot in time)
- `https://github.com/<owner>/<repo>/pull/<n>/files` — when the file is part of an in-flight PR
- `https://github.com/<owner>/<repo>/pull/<n>` — for PR-level references

### Unacceptable references

- Local paths like `.claude/tasks/31/plan.md`, `~/src/foo/bar.md`, `docs/research/x.md` (without a link)
- `file://` URLs of any kind (`file:///tmp/...`, `file:///home/...`)
- `/tmp/...` or `.claude/tmp/...` paths handed to the handler
- Output-file paths produced by background sub-agents — those are local to the agent's runtime and invisible to the handler

### When you can't push yet

If the file is mid-stream (active sub-agent editing it, in-flight rebase, secrets need to be scrubbed), say so explicitly and link the latest pushed version, then describe the local-only delta. Do NOT silently fall back to a local path.

### Trigger: any path mention without a GitHub link

Any time you would mention a file path in a handler-facing message — `~/`, `/tmp/`, `file://`, `.claude/...`, `docs/...` without a corresponding `https://github.com/...` link — STOP. If you generated the file, you have time to push it. Do that first, then link.

### Why

The handler's chat surface (Discord/Telegram) renders GitHub links inline and they're clickable. Local paths and `file://` URLs are unreachable — they look like text the handler has to translate, and most of the time they can't (the agent's host filesystem is invisible to them). Pushed-and-linked is the only artifact surface the handler can actually act on.

## Applies To

- Direct task completions reported to the user
- Sub-agent work summarized by the orchestrator/team lead
- Status updates that reference completed work
- Any message that says "done", "complete", "finished", or equivalent
- Inline file references in milestone updates, PR-thread comments, or chat messages — **every** path mention to the handler needs a reachable link, not just "completion" reports
