---
name: usage
description: >
  Use this skill when the user runs /usage or asks to "show my usage",
  "how much have I used this session", "break down my token usage", "where did
  my API calls go", or "analyze my Claude Code usage". IMPORTANT: this does NOT
  reproduce the built-in /usage — that is an Ink TUI backed by server-side
  plan/limit data (utilization %, reset times, real cost) that a plugin cannot
  recompute. What this skill provides is a LOCAL, APPROXIMATE analysis of your
  own session transcripts: token counts plus the binary's internal relative
  weight, broken down by model, tool, subagent, skill, plugin, MCP server, and
  time of day — a stand-in for the built-in's "What's contributing to your
  limits usage?" section only.
---

# Usage

Local, approximate usage analysis. **This is not a reproduction of the built-in
`/usage`.**

The real `/usage` is an interactive Ink TUI (`local`/`local-jsx` command,
aliases `cost`/`stats`) that fetches your plan and limit **utilization** from the
server (`GET /api/oauth/usage`) and renders reset times, percentages, and cost.
None of that server data — the numbers users actually go to `/usage` for — is
available to a plugin, so none of it is reproduced here.

**This was investigated, not assumed** (checked against binary **v2.1.226**).
The binary does cache its last fetch of
that endpoint locally, under `cachedUsageUtilization` in `~/.claude.json`
(`fetchedAtMs`, `accountUuid`, and the raw response — percent/reset-time per
rate-limit bucket, keyed roughly `five_hour`/`seven_day`/`seven_day_opus`/
`seven_day_sonnet`), refreshed on a 5-minute TTL (binary constant `fe_`). A
sibling field, `cachedExtraUsageDisabledReason`, records whether overage is
currently disabled and why. This skill deliberately does **not** read either
one: `~/.claude.json` sits alongside real OAuth account state
(`oauthAccount`, per-model cost overrides) in the same file, its schema is
undocumented and unversioned, and a plugin script silently parsing it is a
different trust boundary than parsing your own session transcripts — which is
why this repo's own permission classifier pushes back on touching that file
at all. Calling `GET /api/oauth/usage` directly has the same shape of problem
one layer up: it needs the CLI's own OAuth access token, which isn't reliably
readable as a portable, refreshable credential from outside the CLI process.
If you want the real numbers, run the built-in `/usage` — that's what it's
for.

What this skill _can_ stand in for is one section of that TUI: **"What's
contributing to your limits usage?"** The built-in ranks contributors using an
internal relative weight computed from local token counts. This skill computes
that same weight from your local transcripts and analyzes where it concentrated.

Two halves:

1. **Deterministic computation** (`scripts/collect-usage.mjs`) — parses session
   transcripts, dedupes by request/message id, and computes exact token totals
   plus the relative weight, broken down every way the local section slices it.
2. **Agent analysis** — you read that structured breakdown and explain, in
   plain language, where the calls and weight went and what's driving them.

## The relative-weight unit (not cost, not USD)

The built-in's local "contributing factors" section does **not** rank by USD. It
ranks by an internal relative weight derived from token counts. That weight
formula is extracted verbatim from the binary — a per-request weight function
(binary symbol `nNb`) applied to a per-model-tier multiplier (binary symbol
`rNb`):

```
weight = (cache_read + input*10 + cache_creation*12.5 + output*50) * modelTier
modelTier:  fable = 10,  opus = 5,  haiku = 1,  sonnet (default) = 3
```

Every model that isn't fable/opus/haiku — sonnet included — falls under
`default`; the binary has no separate sonnet-specific tier.

**This is also not the same thing as real dollar cost**, and the binary
confirms why: a similarly-named binary field, `additionalModelCostsCache`
(server-provided per-model overrides, function `Ims`/binary default table
`_mt`), turns out to hold the _same_ relative-weight rates shown above
(`{inputTokens:10, outputTokens:50, promptCacheWriteTokens:12.5,
promptCacheReadTokens:1, ...}`) — not USD. The real per-account dollar figure
lives only in the `GET /api/oauth/usage` response (which carries a `currency`
field this weight table doesn't), so there is no local, token-count-only path
to a genuine cost number. This skill's weight breakdown is the closest local
stand-in for "where did the cost go" that can be computed offline.

This is a **relative unit only** — it is meaningful for comparing contributors
against each other, not as an absolute cost. It is **not dollars**, and it is
**not** the utilization/percentage/cost figures the real `/usage` shows (those
come from the server). Requests are deduped by `requestId` / message `uuid` so
retried or streamed duplicates are not double-counted. When you present these
numbers, say explicitly that they are a **relative weight, not USD, and not the
figures the built-in `/usage` reports**.

### Behavior coverage

The binary's local section flags five behavior patterns (`cache_miss`,
`long_context`, `subagent_heavy`, `high_parallel`, `cron`). This script computes
only the two that are derivable from token counts alone — **`cacheMiss`**
(input > 100k tokens) and **`longContext`** (> 150k total tokens). The other
three (`subagent_heavy`, `high_parallel`, `cron`) are **not** computed here; do
not report them as zero — report them as not analyzed.

## Prerequisites

- `node` on PATH (Bun works too).
- Local transcripts under `$CLAUDE_CONFIG_DIR/projects/` (`~/.claude/projects/`
  by default).

## Procedure

Let `ROOT="${CLAUDE_PLUGIN_ROOT}"` and pick a scratch directory for the JSON: a
fresh `mktemp -d`, not a path inside the repo — writing into the repo leaves
untracked files behind, which is exactly what Step 1 below warns against.
**Note the concrete path** — each Bash call is a fresh shell, so the shell
variable does not survive Step 1; Steps 2-4 read the JSON back and need the
real directory, and a `mktemp -d` path is random rather than guessable.

### Step 1 — Compute the breakdown

Default scope is the **current session** — the most recent transcript in the
cwd's project dir, plus that session's subagents. The JSON breakdown always goes
to stdout; a human-readable summary is printed to stderr alongside it. Pass
`--json` to suppress that stderr summary when you only want the JSON.

Write it to a scratch dir, never the user's repo — this runs from whatever
project the user invoked `/usage` in, so a bare `> usage.json` would leave an
untracked file behind in their working tree.

```bash
WORK="$(mktemp -d)"
node "$ROOT/scripts/collect-usage.mjs" --json > "$WORK/usage.json"
echo "$WORK" # record this — Steps 2-4 read the JSON back and the shell is gone
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
| `--json`         | Suppress the human summary on stderr (JSON goes to stdout either way).         |

If no transcripts match, the script emits a small `{ error, scope }` object and
exits 0 — tell the user nothing matched and suggest a wider scope.

### Step 2 — What the JSON contains

Every ranked breakdown reports the relative **weight** (see above), never USD.
Top-level keys of `$WORK/usage.json`:

| Key           | What it holds                                                                          |
| ------------- | -------------------------------------------------------------------------------------- |
| `note`        | The standing caveat: local approximation, relative weight not USD, not the built-in.   |
| `totals`      | `requestCount`, `sessionCount`, `weight` (relative units), `tokens`.                   |
| `split`       | Weight split between main thread and subagents (`mainWeight`, `subagentWeight`, pcts). |
| `behaviors`   | `cacheMiss` (input > 100k) and `longContext` (> 150k) — each `{weight, count}`.        |
| `byModel`     | `{name, weight, pct}` per model family.                                                |
| `byTool`      | Call counts per tool.                                                                  |
| `toolErrors`  | Counts per error _category_ (e.g. `User Rejected`, `File Not Found`).                  |
| `attribution` | `available` (false ⇒ these transcripts predate attribution) and `attributedRequests`.  |
| `byAgent`     | `{name, weight, pct}` per subagent type.                                               |
| `bySkill`     | Attribution per skill.                                                                 |
| `byPlugin`    | Attribution per plugin.                                                                |
| `byMcpServer` | Attribution per MCP server.                                                            |
| `byHourOfDay` | Request-count histogram across 24 hours (**local** time).                              |
| `topSessions` | The heaviest sessions by weight (`{..., weight, subagentWeight}`, top 20).             |

### Step 3 — Analyze where it went (the agent pass)

This is the part that makes the analysis more than a number. Read `$WORK/usage.json`
and produce a concise, evidence-based analysis. For a large or multi-session
scope, dispatch a Task (`general-purpose`) agent with the JSON and the
instructions below; for a small scope, do it in-context.

Cover, at minimum:

1. **Headline** — total relative weight, request count, session count, total
   tokens. State plainly that the weight is a relative unit, not USD, and not
   the utilization/cost the built-in `/usage` shows.
2. **Where the weight concentrated** — the top 2–3 contributors across `byModel`,
   `byTool`, `byAgent`, `bySkill`, `byPlugin`, `byMcpServer`. Name the single
   biggest driver. If `attribution.available` is false, say the attribution
   breakdowns are unavailable for these transcripts rather than reporting them
   as zero.
3. **Main thread vs subagents** — use `split` to say how much went to delegated
   work.
4. **Token shape** — cache_read vs input vs cache_creation vs output; a high
   cache_read share usually means good prompt caching, high output share means
   generation-heavy work.
5. **Friction signals** — `toolErrors` and `behaviors` worth flagging (repeated
   tool failures, retry storms). Note that `subagent_heavy`, `high_parallel`,
   and `cron` are not computed here.
6. **When** — any concentration in `byHourOfDay`.
7. **Heaviest sessions** — call out `topSessions` if one dominates.
8. **One or two actionable takeaways** — e.g. "MCP server X drove 40% of the
   weight; consider narrowing its tool use," grounded in the numbers.

Keep it faithful to the data (see the relay-integrity principle): report what
the numbers show, frame inferences as inferences, and don't inflate.

### Step 4 — Deliver

Present the headline totals, then the breakdown and the analysis. Lead with the
caveat that this is a local approximation and that the real utilization/cost
figures live in the built-in `/usage` (which this does not reproduce). If the
user wants the raw numbers, share `$WORK/usage.json`. Attach or reference the JSON so
the figures are auditable.

## Notes on fidelity

- The **weight formula** (per-request weight function `nNb` × per-model-tier
  multiplier `rNb`) is verbatim from the binary (v2.1.225) and is the genuine
  relative unit the local "contributing factors" section ranks by. It is
  distinct from `additionalModelCostsCache`/`_mt` (function `Ims`; checked
  against v2.1.226), which looked like a real cost table on first read but
  turns out to hold the same relative-weight rates, not USD — see "The
  relative-weight unit" above.
  Everything the built-in `/usage` shows that genuinely is dollar-denominated
  — plan/limit utilization %, reset windows, real cost — is server-fetched
  (`GET /api/oauth/usage`, response schema includes a `currency` field) and
  **cannot** be reproduced by a plugin. Do not present this skill's output as
  the built-in's output.
- Only `cacheMiss` and `longContext` behaviors are computed;
  `subagent_heavy`, `high_parallel`, and `cron` are not.

## Troubleshooting

| Symptom                           | Fix                                                                       |
| --------------------------------- | ------------------------------------------------------------------------- |
| `{ error, scope }` returned       | No transcripts in scope — try `--all` or `--session <id>`.                |
| Weight looks implausibly large    | It is a relative unit, not dollars — confirm you said so.                 |
| Numbers differ from built-in      | Expected — the built-in reports server-side utilization/cost, not this.   |
| User wants their plan/limit usage | That lives in the real `/usage` TUI; this skill cannot fetch server data. |
