---
name: insights
description: >
  Use this skill when the user runs /insights or asks to "generate an insights
  report", "analyze my Claude Code usage", "show me insights about how I use
  Claude", "make the usage insights HTML report", or "what patterns are in my
  sessions". Drives Claude Code's built-in `/insights` facet-classification and
  narrative prompts, verbatim, against your local session transcripts, then
  renders a shareable HTML report. The prompts and facet taxonomy are verbatim;
  the HTML assembly is this plugin's own
  renderer (the built-in builds its page programmatically inside the CLI, so
  there is no page source to extract), and the rendered page differs from the
  built-in's in the ways listed under "Notes on fidelity".
---

# Insights

Produce an HTML report — stat cards, at-a-glance summary, facet bar charts, a
time-of-day chart, big wins, friction analysis, CLAUDE.md suggestions, features
to try, and "on the horizon" prompts — by combining a **deterministic transcript
scan** with **LLM analysis passes that run the built-in's verbatim prompts**,
then merging both into a bundled HTML template.

The classifier and section prompts under `assets/prompts/` are extracted verbatim
from the CLI binary (v2.1.225). The HTML page, which the built-in assembles
programmatically inside the CLI, is produced here by an equivalent bundled
renderer. Every asset needed to run it ships in this plugin under `assets/` and
`scripts/`.

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
`WORK/llm/` for the LLM outputs. **Note the concrete path** — each Bash call is
a fresh shell, so the shell variable does not survive Step 1; Steps 2-5 read
`$WORK` back and a `mktemp -d` path is random rather than guessable.

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

Read the prompt at `assets/prompts/facets.md` — it is the built-in's **verbatim**
classifier. The built-in runs it **once per session** (a small/fast model), so
feed it **one** session's summary from the `sessions[]` array at a time and
collect the results. Its verbatim schema emits, per session: `underlying_goal`,
`goal_categories` (a `{category: count}` map), `outcome`, `user_satisfaction_counts`
(a `{level: count}` map), `claude_helpfulness`, `session_type`, `friction_counts`
(a `{friction_type: count}` map), `friction_detail`, `primary_success`, and
`brief_summary`. Use ONLY the enum values named in the prompt; do not invent
categories.

- For a small number of sessions, do this yourself in-context.
- For many sessions, dispatch the Task tool (a `general-purpose` agent) per
  session (or per batch) with the prompt body + the session summary; instruct it
  to **respond with only the JSON object**.

Assemble the per-session objects into `{ "sessions": [ … ] }` and write it to
`$WORK/llm/facets.json`.

Write the verbatim classifier's output straight through — no reshaping. The
verbatim schema emits count maps (`goal_categories`, `friction_counts`,
`user_satisfaction_counts`) and scalars (`claude_helpfulness`,
`primary_success`). `render-insights.mjs` tallies these directly: each facet
chart is fed an **alias list** of accepted field names, and its `tallyFacet`
helper understands all three shapes — a count map (`{category: n}`, whose values
are summed as weights), an enum array, or a plain scalar. So the verbatim
count-map fields feed the charts with their counts preserved, and the older
enum-array/scalar field names (`request_types`, `friction_types`,
`satisfaction`, `helpfulness`, `capabilities_that_helped`) still tally too — no
reshaping in this pass, and no chart depends on the classifier changing its
output. All six facet charts populate from the verbatim schema, including "What
Helped Most", which reads `primary_success` — excluding its `none` member, which
marks the _absence_ of a primary success rather than a capability. If every
session classifies as `none`, that chart correctly shows its empty state; that is
expected output, not a malformed classification to retry.

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
- All user- and LLM-supplied strings are HTML-escaped before insertion; the only
  raw injection is the time-of-day integer array, which the renderer emits as a
  bare 24-element literal.

### Where the rendered page differs from the built-in

The prompts, the facet taxonomy, and the enum values are verbatim. The page
around them is this plugin's renderer — the built-in builds its HTML
programmatically inside the CLI, so there is no page source to extract. These
are the known differences, kept here so a later extraction pass can close them:

- **"At a glance" is deterministic here.** The built-in synthesizes it with a
  dedicated LLM prompt (binary symbol `Zqb`); this renderer composes it from the
  already-collected facets and stats instead. That prompt _is_ extractable — a
  later pass can ship it and switch this section to an LLM pass
  ([#733](https://github.com/nsheaps/ai-mktpl/issues/733)).
- **The team-feedback block is extra.** The built-in has the markup but
  suppresses it in the rendered report; this renderer emits it. Treat it as an
  addition, not a reproduction.
- **Response-time buckets differ** — 8 here (`<5s … >15m`) versus 7 in the
  built-in, so bar counts are not comparable bucket-for-bucket even though the
  underlying samples are the same.
- **The time-of-day chart is 24 hourly UTC bars**; the built-in buckets into 4
  named periods on Pacific time. The chart preselects the viewer's own UTC
  offset on load (falling back to the custom-offset input for zones with no
  preset) and re-labels client-side, which the built-in does not do.
- **Facet labels are humanized generically** (`_` → space) rather than through
  the built-in's per-key Title-Case map (binary symbol `Nqb`). That map is
  extractable and should be ported on the next pass — this is a reproduction
  gap, not an assumption ([#733](https://github.com/nsheaps/ai-mktpl/issues/733)).
- Two chart colors, a few top-N cutoffs, and some number rounding/formatting
  choices differ; the "Lines" stat counts added lines only.
- **HTML only.** The built-in can also emit a Markdown version of the report;
  this plugin renders the HTML page only.

Three inputs the renderer consumes rest on assumptions that could not be proven
from the extracted code — the transcript timezone, the response-time floor/cap,
and the multi-Clauding overlap computation. Each is commented at its source in
`scripts/collect-insights-data.mjs`, with what to re-check on the next
extraction pass.

## Troubleshooting

| Symptom                                   | Fix                                                         |
| ----------------------------------------- | ----------------------------------------------------------- |
| Report is all empty states                | No transcripts matched the scope — widen with `--all-time`. |
| A chart is empty but others render        | Its facet field was never produced — re-run Step 2.         |
| Renderer warns about leftover `{{TOKEN}}` | A template/renderer mismatch — do not ship; report it.      |
| Time-of-day chart blank                   | No message timing data in scope; expected for tiny scans.   |
