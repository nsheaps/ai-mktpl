# Artifact Linking in Completion Reports

**CRITICAL:** Every task completion report to the user MUST include links to all produced artifacts.

## Rule

When reporting that a task is complete, you MUST include **every applicable** item from this checklist:

| Artifact Type         | Format                                                                                                                             |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| GitHub Issue          | `[org/repo#123](https://github.com/org/repo/issues/123)`                                                                           |
| Pull Request          | `[org/repo#456](https://github.com/org/repo/pull/456)`                                                                             |
| Commit                | `[org/repo@abc1234](https://github.com/org/repo/commit/abc1234)`                                                                   |
| File created/modified | `[path/file.md](https://github.com/org/repo/blob/<ref>/path/file.md)` (push first — never link a local-only path)                  |
| External URL          | Full URL as markdown link                                                                                                          |
| Branch                | `[org/repo@main](https://github.com/org/repo/tree/main/)`                                                                          |
| Discord Message       | `[Nate: do a thing...but make it green](https://discord.com/channels/1490863845252665415/1497431286661517353/1499108530622431375)` |
| Discord Thread        | `[chore: the thread title](https://discord.com/channels/1490863845252665415/1497431286661517353/1497431286661517353)`              |
| Discord Channel       | `[#agent-human-resources](https://discord.com/channels/1490863845252665415/1497019970851442808)`                                   |

**Discord-specific formatting tips:**

- **Messages**: feel free to truncate the link text to only include the relevant excerpt of the message
- **Threads**: use the same URL pattern as messages, but link to the first message of the thread (where the message ID equals the thread ID); use the thread or forum-post title as the link text
- **Channels**: always use the human-readable channel name (e.g. `#agent-human-resources`), not the channel ID

> [!NOTE]
> Future direction: MCP servers may expose channels and other GitHub/Discord
> objects as resources, so the format above could collapse to scheme-prefixed
> URIs like `github://org/repo/pull/456` or
> `discord://server@1490863845252665415/channel/1497431286661517353/thread/1499108530622431375`.
> Open question: should the MCP servers handle `https://` URLs natively (so
> agents stop hand-rolling them), or should we standardize on the scheme prefix
> and route everything through MCP resources?

## Why This Matters

- Users should never have to ask "where is it?" after a completion report
- Links make reports actionable — the user can click/navigate immediately
- Omitting links forces unnecessary back-and-forth

## Examples

**Bad:**

> "I created the spec and opened a GitHub issue for tracking."

**Good:**

> "I created the spec at [`docs/specs/draft/feature-x.md`](https://github.com/nsheaps/ai-mktpl/blob/main/docs/specs/draft/feature-x.md) and opened [#42](https://github.com/org/repo/issues/42) for tracking. Commit: `a1b2c3d`."

**Bad (team lead reporting sub-agent work):**

> "Road Runner completed the research on teammate launch behavior. Key findings: spawn is not customizable, delegate mode has a bug."

**Good (team lead reporting sub-agent work):**

> "Road Runner completed the research on teammate launch behavior. Report saved to [`docs/research/teammate-launch-research.md`](https://github.com/nsheaps/ai-mktpl/blob/main/docs/research/teammate-launch-research.md) (research belongs in `docs/research/` per `file-placement.md`, not `.claude/tmp/`). Key findings: spawn is not customizable, delegate mode has a bug ([#25037](https://github.com/anthropics/claude-code/issues/25037))."

## Links Must Be Reachable — No Local Paths, No `file://` URLs

**CRITICAL:** When you reference a file any reader of the message might want to open (the handler, a teammate agent, a reviewer reading the PR, your future self re-reading the message) — a plan, research note, draft spec, generated doc, transcript, anything in a local repo — commit and push it FIRST, then link to the **GitHub URL**. Readers of the message are typically not on the host running the agent (Discord/Telegram users, GitHub PR reviewers, other agents in different sessions/repos), so paths that only exist locally are not actionable.

### Acceptable link formats

- `https://github.com/<owner>/<repo>/blob/main/<path>` — file on the default branch (latest)
- `https://github.com/<owner>/<repo>/blob/<branch>/<path>` — file on a feature branch
- `https://github.com/<owner>/<repo>/blob/<sha>/<path>` — commit-pinned (preferred when referencing a snapshot in time)
- `https://github.com/<owner>/<repo>/pull/<n>/files` — when the file is part of an in-flight PR
- `https://github.com/<owner>/<repo>/pull/<n>` — for PR-level references

### Unacceptable references

- Local paths like `.claude/tasks/31/plan.md`, `~/src/foo/bar.md`, `docs/research/x.md` (without a link)
- `file://` URLs of any kind (`file:///tmp/...`, `file:///home/...`)
- `/tmp/...` or `.claude/tmp/...` paths handed to any reader off the agent's host
- Output-file paths produced by background sub-agents — those are local to the agent's runtime and invisible to anyone reading the message elsewhere

### When you can't push yet

If the file is mid-stream (active sub-agent editing it, in-flight rebase, secrets need to be scrubbed), say so explicitly and link the latest pushed version, then describe the local-only delta. Do NOT silently fall back to a local path.

### Trigger: any reader-facing path mention without a GitHub link

Any time you mention a file path **a reader of the message is expected to open** — and the same message does NOT already include a corresponding `https://github.com/...` link to that file — STOP. Watch especially for `~/`, `/tmp/`, `file://`, `.claude/...`, and any repo-relative path you're handing to a reader as an artifact reference. If you generated the file, you have time to push it. Do that first, then link.

This rule is about **reader-facing artifact references** (plans, research, specs, transcripts, generated docs that anyone consuming the message — handler, teammate agent, reviewer, future maintainer — might want to navigate to) — not incidental code-edit references inside a PR description that already links to the diff, or pointers to known docs by filename. The test: would a reader want to _open_ this path right now? If yes, it must be a GitHub link.

### Why

Readers' surfaces (Discord/Telegram, GitHub PR threads, other agents' sessions) render GitHub links inline and they're clickable. Local paths and `file://` URLs are unreachable from those surfaces — they look like text the reader has to translate, and most of the time they can't (the agent's host filesystem is invisible to them). Pushed-and-linked is the only artifact surface readers off the host can actually act on.

## Applies To

- Direct task completions reported to the user
- Sub-agent work summarized by the orchestrator/team lead
- Status updates that reference completed work
- Any message that says "done", "complete", "finished", or equivalent
- Inline file references in milestone updates, PR-thread comments, or chat messages — **every** path mention to a reader off the agent's host needs a reachable link, not just "completion" reports
