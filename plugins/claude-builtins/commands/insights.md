---
name: insights
description: Generate the Claude Code insights HTML report from local transcripts — deterministic scan plus LLM analysis passes rendered into a self-contained page
argument-hint: "[--all] [--project-dir <dir>] [--session <id>] [--days <n>] [--all-time]"
allowed-tools: Task, Read, Bash(node:*), Bash(mkdir:*), Bash(mktemp:*), Write
---

# Insights

Scan your local session transcripts, classify each session across the built-in's
facet taxonomy, write seven narrative sections, and render a single shareable
HTML report with charts and copyable prompts.

The classifier and section prompts are the built-in's own, verbatim. The page
itself is not: the built-in assembles its HTML programmatically inside the CLI,
so there is no page source to extract and this plugin ships its own renderer.
The rendered report differs from the built-in's in documented ways — see "Notes
on fidelity" in the skill.

Invoke the **`insights`** skill and follow it end to end. The user's arguments
select the scope.

## Arguments

**Format:** `[--all] [--project-dir <dir>] [--session <id>] [--days <n>] [--all-time]`

| Argument              | Meaning                                     |
| --------------------- | ------------------------------------------- |
| `--all`               | All projects (default).                     |
| `--project-dir <dir>` | One project's transcript dir.               |
| `--session <id>`      | A single session id.                        |
| `--file <path>`       | A single transcript file.                   |
| `--days <n>`          | Only the last `n` days (default 30).        |
| `--all-time`          | No day limit.                               |
| `--max-sessions <n>`  | Cap how many session summaries are emitted. |

**Examples:**

- `/insights` — report across all projects, last 30 days
- `/insights --all-time` — everything on record
- `/insights --days 7` — just the last week

## What to do

1. Recall and follow the **`insights`** skill (`skills/insights/SKILL.md`).
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/collect-insights-data.mjs` (Step 1) for
   the deterministic scan.
3. Run the facet classification (Step 2) and the seven narrative section
   passes (Step 3), writing each JSON into the working `llm/` dir.
4. Render with `${CLAUDE_PLUGIN_ROOT}/scripts/render-insights.mjs` (Step 4) and
   deliver the path to the self-contained `report.html` (Step 5).

$ARGUMENTS
