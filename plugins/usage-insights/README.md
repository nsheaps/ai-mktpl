# usage-insights

Standalone re-implementations of Claude Code's built-in `/usage` and
`/insights`, reverse-engineered from the CLI binary so they run **without** the
built-in tooling. Everything they need — collector scripts, LLM prompts, and the
HTML template — ships inside this plugin.

- **`/usage`** programmatically computes session token usage and a synthetic
  cost from your local transcripts, then has an agent analyze _where_ the API
  calls and cost actually went (models, tools, subagents, skills, plugins, MCP
  servers, time of day).
- **`/insights`** scans your session transcripts, classifies each session across
  a fixed facet taxonomy, writes seven narrative sections, and renders the full
  shareable HTML report — stat cards, facet charts, a time-of-day chart, wins,
  friction analysis, CLAUDE.md suggestions, and "on the horizon" prompts.

## Features

- **No built-in dependency** — parses `~/.claude/projects/**/*.jsonl` directly;
  nothing calls the built-in commands.
- **Deterministic + agentic split** — exact counts come from plain scans; the
  narrative and facet classification come from LLM passes you (the agent) run.
- **Graceful degradation** — missing transcripts or skipped LLM passes render as
  clean empty states / a small `{ error, scope }` object, never a crash.
- **Self-contained report** — the `/insights` output is one HTML file with
  inline CSS/JS, safe to share; the time-of-day chart re-renders in the viewer's
  timezone and the copy buttons work offline.

## Installation

### From Marketplace

```bash
claude plugin install usage-insights@nsheaps-claude-plugins
```

### Local Development

```bash
claude --plugin-dir /path/to/usage-insights
```

## Usage

### `/usage` — where did my API calls go?

```bash
/usage                     # current project's usage
/usage --current           # just this session
/usage --all --days 30     # everything from the last 30 days
/usage --session <id>      # one session, across all projects
```

The command runs `scripts/collect-usage.mjs` for the deterministic breakdown,
then analyzes it. Costs are reported as **synthetic units, not USD** — the
built-in report does the same. The synthetic model, recovered from the binary:

```
units = (cache_read + input*10 + cache_creation*12.5 + output*50) * modelTier
modelTier:  fable = 10,  opus = 5,  haiku = 1,  default = 3
```

Requests are deduped by `requestId` / message `uuid` so retries and streamed
duplicates are not double-counted.

### `/insights` — generate the HTML report

```bash
/insights                  # all projects, last 30 days
/insights --all-time       # everything on record
/insights --days 7         # just the last week
/insights --project-dir <dir>
```

The pipeline:

```
transcripts (~/.claude/projects/**/*.jsonl)
        │
        ▼
scripts/collect-insights-data.mjs        ← deterministic scan (no LLM)
        │  emits { deterministic:{…}, sessions:[…] }
        ▼
LLM passes:  prompts/facets.md → facets.json
             7 section prompts  → <section>.json     (written into an llm/ dir)
        ▼
scripts/render-insights.mjs --data collect.json --llm-dir <dir>
        │  fills every {{TOKEN}} in assets/insights-template.html
        ▼
   report.html   (self-contained, shareable)
```

Both commands simply invoke the matching skill; the skills contain the full
step-by-step procedure. You can also trigger the skills conversationally:

> "Show me my Claude Code usage for this session."
>
> "Generate an insights report from my sessions this month."

## Scripts

| Script                              | Role                                                                    |
| ----------------------------------- | ----------------------------------------------------------------------- |
| `scripts/collect-usage.mjs`         | Deterministic token/cost breakdown for `/usage` (JSON on stdout).       |
| `scripts/collect-insights-data.mjs` | Deterministic scan for `/insights` (counts, charts, session summaries). |
| `scripts/render-insights.mjs`       | Fills the HTML template from the collector data + LLM outputs.          |

All scripts are plain `.mjs` — run with `node` (or `bun`). They read from
`~/.claude/projects/` and take scope flags documented in each skill.

## File Structure

```
usage-insights/
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest
├── commands/
│   ├── usage.md                    # /usage command
│   └── insights.md                 # /insights command
├── skills/
│   ├── usage/SKILL.md              # /usage procedure
│   └── insights/SKILL.md           # /insights procedure
├── scripts/
│   ├── collect-usage.mjs
│   ├── collect-insights-data.mjs
│   └── render-insights.mjs
├── assets/
│   ├── insights-template.html      # 34-token HTML template
│   └── prompts/                    # facets.md + 7 section prompts
└── README.md
```

## Prerequisites

- `node` on PATH (Bun works too — the scripts are plain `.mjs`).
- Local session transcripts under `~/.claude/projects/`. With none present, the
  scripts return empty states rather than failing.

## Fidelity notes

- Stat cards, top tools, languages, tool-error, response-time, and time-of-day
  charts come **only** from the deterministic scan and are exact.
- The six facet charts are aggregated from `facets.json`, so their accuracy
  depends on the facet-classification pass.
- All user- and LLM-supplied strings are HTML-escaped before insertion; the only
  raw injection is the time-of-day integer array, emitted as a bare 24-element
  literal.
