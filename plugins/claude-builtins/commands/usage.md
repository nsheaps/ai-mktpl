---
name: usage
description: Local approximate analysis of your session transcripts (token counts + the binary's relative weight) — NOT the built-in /usage's server-side utilization/cost
argument-hint: "[--all] [--session <id>] [--file <path>] [--current] [--days <n>]"
allowed-tools: Task, Read, Bash(node:*), Bash(mkdir:*), Write
---

# Usage

Local, approximate usage analysis. **This does not reproduce the built-in
`/usage`.** The real `/usage` is an interactive TUI backed by server-side plan
and limit data (utilization %, reset times, cost) that a plugin cannot fetch or
recompute.

What this provides is a stand-in for the built-in's **"What's contributing to
your limits usage?"** section: it computes token counts and the binary's
internal **relative weight** from your local session transcripts, then analyzes
where the API calls and weight went (models, tools, subagents, skills, plugins,
MCP servers, time of day).

Invoke the **`usage`** skill and follow it end to end. The user's arguments
select the scope.

## Arguments

**Format:** `[--all] [--session <id>] [--file <path>] [--current] [--days <n>]`

| Argument         | Meaning                                                                        |
| ---------------- | ------------------------------------------------------------------------------ |
| (none)           | The current/most-recent session in this project (same as `--current`).         |
| `--all`          | All projects (default window becomes 7 days).                                  |
| `--session <id>` | A single session id, across all projects.                                      |
| `--file <path>`  | A single transcript file.                                                      |
| `--current`      | The current/most-recent session only. Narrows — wins over `--all`/`--session`. |
| `--days <n>`     | Restrict to the last `n` days.                                                 |

**Examples:**

- `/usage` — this session (the most recent one in the current project)
- `/usage --current` — the same thing, stated explicitly
- `/usage --all --days 30` — everything from the last 30 days

## What to do

1. Recall and follow the **`usage`** skill (`skills/usage/SKILL.md`).
2. Run `scripts/collect-usage.mjs` with the scope flags above (`--json`) to
   get the deterministic breakdown.
3. Analyze where the weight concentrated (models, tools, subagents, skills,
   plugins, MCP servers, time of day) per the skill's Step 3.
4. Present the headline totals — stated as a **relative weight, not USD, and
   not the utilization/cost the built-in `/usage` shows** — the breakdown, and
   the analysis.

$ARGUMENTS
