---
name: usage
description: >
  Use this skill when the user runs /usage or asks to "show my usage",
  "how much have I used this session", "break down my token usage", "where did
  my API calls go", "what's costing the most in this session", or "analyze my
  Claude Code usage". Reproduces Claude Code's built-in /usage WITHOUT the
  built-in tooling: it programmatically computes token counts and a synthetic
  cost from your local session transcripts, then has an agent analyze WHERE the
  API calls and cost actually went (models, tools, subagents, skills, plugins,
  MCP servers, time of day).
---

# Usage

Standalone re-implementation of Claude Code's built-in `/usage`. Two halves:

1. **Deterministic computation** (`scripts/collect-usage.mjs`) — parses session
   transcripts, dedupes by request/message id, and computes exact token totals
   and a synthetic cost, broken down every way the built-in report slices it.
2. **Agent analysis** — you read that structured breakdown and explain, in
   plain language, where the calls and cost went and what's driving them.

Nothing here calls the built-in command.

## The synthetic cost model

The built-in report does **not** show USD. It computes synthetic "cost units"
from token counts, reverse-engineered from the binary:

```
units = (cache_read + input*10 + cache_creation*12.5 + output*50) * modelTier
modelTier:  fable = 10,  opus = 5,  haiku = 1,  default = 3
```

Requests are deduped by `requestId` / message `uuid` so retried or streamed
duplicates are not double-counted. Report these as **synthetic units, not
dollars** — say so explicitly when you present them, exactly as the built-in
does.

## Prerequisites

- `node` on PATH (Bun works too).
- Local transcripts under `~/.claude/projects/`.

## Procedure

Let `ROOT="${CLAUDE_PLUGIN_ROOT}"`.

### Step 1 — Compute the breakdown

Default scope is the **current session** — the most recent transcript in the
cwd's project dir, plus that session's subagents. Pass `--json` to get just the
JSON blob (the human summary goes to stderr).

```bash
node "$ROOT/scripts/collect-usage.mjs" --json > usage.json
```

Scope flags:

| Flag             | Meaning                                                                        |
| ---------------- | ------------------------------------------------------------------------------ |
| (none)           | The current/most-recent session (same as `--current`).                         |
| `--all`          | All projects (default window becomes 7 days).                                  |
| `--session <id>` | A single session id, across all projects.                                      |
| `--file <path>`  | A single transcript file.                                                      |
| `--current`      | The current/most-recent session only. Narrows — wins over `--all`/`--session`. |
| `--days <n>`     | Only messages from the last `n` days.                                          |
| `--json`         | Emit only the JSON (no human summary on stdout).                               |

If no transcripts match, the script emits a small `{ error, scope }` object and
exits 0 — tell the user nothing matched and suggest a wider scope.

### Step 2 — What the JSON contains

Top-level keys of `usage.json`:

| Key           | What it holds                                                         |
| ------------- | --------------------------------------------------------------------- |
| `totals`      | `requestCount`, `sessionCount`, `cost` (synthetic units), `tokens`    |
| `split`       | Cost split between main thread and subagents (costs + percentages).   |
| `behaviors`   | `cacheMiss` (input > 100k tokens) and `longContext` (> 150k tokens).  |
| `byModel`     | `{name, cost, pct}` per model family.                                 |
| `byTool`      | Call counts per tool.                                                 |
| `toolErrors`  | Counts per error _category_ (e.g. `User Rejected`, `File Not Found`). |
| `byAgent`     | `{name, cost, pct}` per subagent type.                                |
| `bySkill`     | Attribution per skill.                                                |
| `byPlugin`    | Attribution per plugin.                                               |
| `byMcpServer` | Attribution per MCP server.                                           |
| `byHourOfDay` | Request-count histogram across 24 hours (**local** time).             |
| `topSessions` | The heaviest sessions by cost (top 20).                               |

### Step 3 — Analyze where it went (the agent pass)

This is the part that makes `/usage` more than a number. Read `usage.json` and
produce a concise, evidence-based analysis. For a large or multi-session scope,
dispatch a Task (`general-purpose`) agent with the JSON and the instructions
below; for a small scope, do it in-context.

Cover, at minimum:

1. **Headline** — total synthetic cost, request count, session count, total
   tokens. State plainly that cost is in synthetic units, not USD.
2. **Where the cost concentrated** — the top 2–3 contributors across `byModel`,
   `byTool`, `byAgent`, `bySkill`, `byPlugin`, `byMcpServer`. Name the single
   biggest driver.
3. **Main thread vs subagents** — use `split` to say how much went to delegated
   work.
4. **Token shape** — cache_read vs input vs cache_creation vs output; a high
   cache_read share usually means good prompt caching, high output share means
   generation-heavy work.
5. **Friction signals** — `toolErrors` and `behaviors` worth flagging (repeated
   tool failures, retry storms).
6. **When** — any concentration in `byHourOfDay`.
7. **Heaviest sessions** — call out `topSessions` if one dominates.
8. **One or two actionable takeaways** — e.g. "MCP server X drove 40% of cost;
   consider narrowing its tool use," grounded in the numbers.

Keep it faithful to the data (see the relay-integrity principle): report what
the numbers show, frame inferences as inferences, and don't inflate.

### Step 4 — Deliver

Present the headline totals, then the breakdown and the analysis. If the user
wants the raw numbers, share `usage.json`. Attach or reference the JSON so the
figures are auditable.

## Troubleshooting

| Symptom                      | Fix                                                               |
| ---------------------------- | ----------------------------------------------------------------- |
| `{ error, scope }` returned  | No transcripts in scope — try `--all` or `--session <id>`.        |
| Cost looks implausibly large | It is synthetic units, not dollars — confirm you said so.         |
| Numbers differ from built-in | Ensure the same scope/day-window; dedupe is by id, like built-in. |
