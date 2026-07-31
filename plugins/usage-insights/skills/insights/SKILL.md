---
name: insights
description: >
  Use this skill when the user runs /insights or asks to "generate an insights
  report", "analyze my Claude Code usage", "show me insights about how I use
  Claude", "make the usage insights HTML report", or "what patterns are in my
  sessions". Reproduces Claude Code's built-in /insights end-to-end WITHOUT the
  built-in tooling: it scans your local session transcripts, classifies each
  session across a fixed facet taxonomy, writes seven narrative sections, and
  renders a single shareable HTML report with charts and copyable prompts.
---

# Insights

Standalone re-implementation of Claude Code's built-in `/insights`. It produces
the same HTML report — stat cards, at-a-glance summary, facet bar charts, a
time-of-day chart, big wins, friction analysis, CLAUDE.md suggestions, features
to try, and "on the horizon" prompts — by combining a **deterministic transcript
scan** with **LLM analysis passes**, then merging both into a bundled HTML
template.

Nothing here calls the built-in command. Every asset needed to run it ships in
this plugin under `assets/` and `scripts/`.

## Architecture

```
transcripts (~/.claude/projects/**/*.jsonl)
        │
        ▼
scripts/collect-insights-data.mjs   ← deterministic scan (no LLM)
        │  emits { deterministic:{…}, sessions:[{…session summaries…}] }
        ├────────────────────────────────────────────┐
        ▼                                             │
LLM passes (you, the agent):                          │  deterministic half
  • assets/prompts/facets.md   → facets.json          │  goes straight through
  • 7 section prompts          → <section>.json       │
        │  written into an --llm-dir                   │
        ▼                                             ▼
scripts/render-insights.mjs  --data collect.json --llm-dir <dir>
        │  fills every {{TOKEN}} in assets/insights-template.html
        ▼
   report.html   (self-contained, shareable)
```

The deterministic script is safe to re-run and never needs an LLM. The LLM
passes are where you (the agent) read the session summaries and produce
structured JSON. `render-insights.mjs` degrades gracefully: any missing LLM
output renders as a clean empty state, so you can smoke-test the pipeline before
running any passes.

## Prerequisites

- `node` on PATH (Bun also works — the scripts are plain `.mjs`).
- Local session transcripts under `~/.claude/projects/`. If none exist, the
  report renders with empty states rather than failing.

## Procedure

Let `ROOT="${CLAUDE_PLUGIN_ROOT}"` and pick a working directory, e.g.
`WORK="$(mktemp -d)/insights"` (or `.claude/tmp/insights`). Create
`WORK/llm/` for the LLM outputs.

### Step 1 — Deterministic scan

Run the collector. Default scope is all projects, last 30 days.

```bash
mkdir -p "$WORK/llm"
node "$ROOT/scripts/collect-insights-data.mjs" --all --days 30 > "$WORK/collect.json"
```

Scope flags (choose what the user asked for):

| Flag                  | Meaning                                     |
| --------------------- | ------------------------------------------- |
| `--all`               | All projects (default).                     |
| `--project-dir <dir>` | One project's transcript dir.               |
| `--session <id>`      | A single session id.                        |
| `--file <path>`       | A single transcript file.                   |
| `--days <n>`          | Only the last `n` days (default 30).        |
| `--all-time`          | No day limit.                               |
| `--max-sessions <n>`  | Cap how many session summaries are emitted. |

`collect.json` has two parts:

- `deterministic` — counts, top tools, languages, tool errors, time-of-day
  histogram, response-time buckets, multi-Clauding stats. These feed the stat
  cards and several charts directly; **no LLM needed** for them.
- `sessions[]` — one compact summary per session (id, cwd, timing, message
  counts, top tools, files touched, a sample of prompts). These are the **only**
  input the LLM passes need.

### Step 2 — Facet classification (one LLM pass)

Read the prompt at `assets/prompts/facets.md`. It classifies each session across
a fixed enum taxonomy (session type, request types, capabilities that helped,
friction types, satisfaction, outcome, helpfulness, languages). Feed it the
`sessions[]` array from `collect.json`.

- For a small number of sessions, do this yourself in-context.
- For many sessions, dispatch the Task tool (a `general-purpose` agent) with the
  prompt body + the sessions array; instruct it to **respond with only the JSON
  object**.

Write the result — the object `{ "sessions": [ … ] }` — to
`$WORK/llm/facets.json`. These facets drive six of the report's bar charts, so
this pass matters most for chart fidelity. Use ONLY the enum values in the
prompt; do not invent categories.

### Step 3 — Seven narrative sections (LLM passes)

Each prompt under `assets/prompts/` takes the session summaries (and, where
useful, the facets) and returns a JSON object. Every prompt ends with "RESPOND
WITH ONLY A VALID JSON OBJECT" — honor that exactly. Write each output to
`$WORK/llm/<name>.json` using these filenames (they are the names
`render-insights.mjs` looks up):

| File in `$WORK/llm/`     | Prompt                         | Fills report section                    |
| ------------------------ | ------------------------------ | --------------------------------------- |
| `project_areas.json`     | `prompts/project_areas.md`     | "What you worked on" area cards         |
| `interaction_style.json` | `prompts/interaction_style.md` | Interaction-style narrative             |
| `what_works.json`        | `prompts/what_works.md`        | "Biggest wins" cards                    |
| `friction_analysis.json` | `prompts/friction_analysis.md` | Friction categories + examples          |
| `suggestions.json`       | `prompts/suggestions.md`       | CLAUDE.md additions, features, patterns |
| `on_the_horizon.json`    | `prompts/on_the_horizon.md`    | "On the horizon" opportunity prompts    |
| `fun_ending.json`        | `prompts/fun_ending.md`        | Closing headline + detail               |

You may run these in parallel via multiple Task agents (one prompt each). Keep
each agent's output strictly to the JSON shape the prompt specifies — the
renderer parses these files and any prose outside the JSON object is discarded
by a loose-parse fallback, but clean JSON is best.

If the user asked for a fast/minimal report, you can skip Step 3 entirely: the
renderer will fill those sections with empty states and still produce a valid
report from the deterministic data + facets.

### Step 4 — Render the HTML

```bash
node "$ROOT/scripts/render-insights.mjs" \
  --data "$WORK/collect.json" \
  --llm-dir "$WORK/llm" \
  --out "$WORK/report.html"
```

Useful overrides:

- `--facets <path>` / `--<section_name> <path>` — override a single input file.
- `--sections <bundle.json>` — one JSON keyed by the section names instead of a
  directory of files.
- `--subtitle "<text>"` — replace the auto-generated subtitle.
- `--template <path>` — use a different template (defaults to the bundled
  `assets/insights-template.html`).

The renderer warns on stderr if any `{{TOKEN}}` was left unfilled — treat that
as a bug to fix, not a report to ship.

### Step 5 — Deliver

Give the user the path to `report.html` (and offer to open it). It is fully
self-contained: inline CSS/JS, no external assets, safe to share. The
time-of-day chart re-renders client-side for the viewer's timezone; the copy
buttons and "copy all CLAUDE.md" button work offline.

## Notes on fidelity

- The six facet charts (what you wanted, session types, what helped, outcomes,
  friction types, satisfaction) are aggregated from `facets.json` by the
  renderer — so the quality of Step 2 directly determines their accuracy.
- Stat cards, top tools, languages, tool-error, response-time, and time-of-day
  charts come **only** from the deterministic scan and are exact.
- "At a glance" and the team-feedback block are synthesized by the renderer from
  the facets; they need no dedicated prompt.
- All user- and LLM-supplied strings are HTML-escaped before insertion; the only
  raw injection is the time-of-day integer array, which the renderer emits as a
  bare 24-element literal.

## Troubleshooting

| Symptom                                   | Fix                                                         |
| ----------------------------------------- | ----------------------------------------------------------- |
| Report is all empty states                | No transcripts matched the scope — widen with `--all-time`. |
| A chart is empty but others render        | Its facet field was never produced — re-run Step 2.         |
| Renderer warns about leftover `{{TOKEN}}` | A template/renderer mismatch — do not ship; report it.      |
| Time-of-day chart blank                   | No message timing data in scope; expected for tiny scans.   |
