# Communication Discipline

Rules for keeping handler-facing communication concise and plan-doc-first.

Source: [Handler directive 2026-04-29T20:29Z](https://discord.com/channels/1490863845252665415/1497431286661517353/1499145606155862178)

## 1. Plan-Doc-First Communication

> **Plan doc** = a markdown file at `.claude/tasks/<task-id>/plan.md` that captures the task's goal, scope, decisions, and progress. Discussion about a task lives in the plan doc, not in chat threads.

When working on a task that has a plan document:

- **All discussion belongs in the plan doc** — design decisions, open questions, blockers, trade-offs. Not in the channel.
- **Ping the channel only when handler input is required.** Format: "I have a question in `<plan-doc-path>` — please review §N." Do not paste the question into the channel.
- **Updates that don't need handler approval go directly into the plan doc** — no channel message needed.

### Good

```
🤖 Question in [.claude/tasks/34/plan.md §3](https://github.com/nsheaps/ai-mktpl/blob/main/.claude/tasks/34/plan.md) — please review and answer there.
```

### Bad

```
🤖 I have three open questions before I can proceed:
1. Should the per-platform reference be a standalone plugin or fold into agentic-behavior?
2. Should handler-axis rules migrate to a shared plugin?
3. What's the audit scope — just memory/ or also rules/ and shared plugins?
```

The bad example belongs in the plan doc. The channel message should be at most a link to the plan doc.

## 2. Status Update Brevity

Status updates posted to channels (Discord, Telegram, etc.) MUST be ≤ 3 sentences + links.

- Include links to artifacts (PR, commit, plan doc) — no inline re-narration of their content.
- No bullet-list recaps of "what I did, why I did it, what I'm doing next."
- Progress details live in the plan doc. The channel gets the headline only.

### Good

```
🤖 [PR #472](url) ready — glossary restructured as per-term files. CI review requested via `request-review` label.
```

### Bad

```
🤖 PR #472 restructure complete — commit 2408cb5.
- docs/glossary.md → 13 per-term snake_case files under docs/glossary/
- docs/glossary/INDEX.md = plain-markdown TOC, no @-references
- plugins/agentic-behavior/rules/glossary is now a folder symlink → ../../../docs/glossary/
- Old file symlink + docs/glossary.md removed
Comment posted: issuecomment-4347023692. request-review cycled — claude-review running.
```

The bad example is a content dump. The good example gives the handler what they need to act (link to PR, one-line summary, current state).

## 3. Sub-Agent Dispatch Defaults

**ALWAYS** use `run_in_background: true` when dispatching sub-agents whose output is not needed for the next step in the main loop. Dispatch in the background by default; use the foreground only when you genuinely need the result before you can proceed (e.g., a lookup whose output is the next tool call's input, or a research agent whose findings inform the next decision).

- Backgrounding work that does not block the next step keeps the main session responsive so handler messages are seen promptly.
- "I dispatched a sub-agent and am waiting" is not a valid reason to block when the main loop has other work it could be doing — dispatch in background and acknowledge the handler immediately.

### Good

```python
Agent(prompt="Fix the trailing comma in labels.yaml", run_in_background=True)
```

### Bad

```python
Agent(prompt="Fix the trailing comma in labels.yaml")  # blocks until done
```

## 4. Sub-Agent Model Selection

Default to **sonnet** for all sub-agent work. Reserve opus only for tasks that genuinely require deep multi-step reasoning or complex tradeoff analysis.

**Use sonnet for:**

- PR creation and updates
- Single-file edits
- Label/issue management
- Git operations
- Status lookups and audits
- Routine execution of a known procedure

**Use opus only for:**

- Complex architectural planning with many interdependencies
- Tasks where the wrong judgment call has large downstream consequences

Setting `model: sonnet` in the sub-agent call or frontmatter is the correct default. Do not default to opus out of caution — sonnet handles the vast majority of agentic work correctly.

- **When dispatching to sonnet, use `sequential-thinking` heavily.** Sonnet's reasoning quality is significantly better when paired with explicit step-by-step thinking; without it, sonnet sub-agents tend to skip context and produce shallow work.
