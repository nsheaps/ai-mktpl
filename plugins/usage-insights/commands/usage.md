---
name: usage
description: Compute this session's token usage and synthetic cost from local transcripts, then analyze where the API calls and cost actually went
argument-hint: "[--all] [--session <id>] [--file <path>] [--current] [--days <n>]"
allowed-tools: Task, Read, Bash(node:*), Bash(mkdir:*), Write
---

# Usage

Reproduce Claude Code's built-in `/usage` **without** the built-in tooling:
programmatically compute token counts and a synthetic cost from your local
session transcripts, then analyze where the API calls and cost went.

Invoke the **`usage`** skill and follow it end to end. The user's arguments
select the scope.

## Arguments

**Format:** `[--all] [--session <id>] [--file <path>] [--current] [--days <n>]`

| Argument           | Meaning                                                     |
| ------------------ | ----------------------------------------------------------- |
| (none)             | Current project's transcripts.                              |
| `--all`            | All projects (default window becomes 7 days).               |
| `--session <id>`   | A single session id, across all projects.                   |
| `--file <path>`    | A single transcript file.                                   |
| `--current`        | The current / most-recent session only.                     |
| `--days <n>`       | Restrict to the last `n` days.                              |

**Examples:**

- `/usage` — current project's usage
- `/usage --current` — just this session
- `/usage --all --days 30` — everything from the last 30 days

## What to do

1. Recall and follow the **`usage`** skill (`skills/usage/SKILL.md`).
2. Run `scripts/collect-usage.mjs` with the scope flags above (`--json`) to
   get the deterministic breakdown.
3. Analyze where the cost concentrated (models, tools, subagents, skills,
   plugins, MCP servers, time of day) per the skill's Step 3.
4. Present the headline totals — stated as **synthetic units, not USD** — the
   breakdown, and the analysis.

$ARGUMENTS
