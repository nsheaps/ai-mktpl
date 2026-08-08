# claude-builtins

Standalone re-implementations of Claude Code's faithfully-reproducible built-in
slash commands, reverse-engineered from the CLI binary (**v2.1.220**) so they run
**without** the built-in tooling. Everything they need — collector scripts, LLM
prompts, and the HTML template — ships inside this plugin.

- **`/usage`** programmatically computes session token usage and a synthetic
  cost from your local transcripts, then has an agent analyze _where_ the API
  calls and cost actually went (models, tools, subagents, skills, plugins, MCP
  servers, time of day).
- **`/insights`** scans your session transcripts, classifies each session across
  a fixed facet taxonomy, writes seven narrative sections, and renders the full
  shareable HTML report — stat cards, facet charts, a time-of-day chart, wins,
  friction analysis, CLAUDE.md suggestions, and "on the horizon" prompts.
- **`/init`** generates a `CLAUDE.md` for the current repo, reproducing the
  built-in's classic and newer skills/hooks-aware variants (the variant toggles
  on `CLAUDE_CODE_NEW_INIT`).
- **`/review`** fetches a GitHub pull request's context and diff with `gh` and
  produces a thorough, structured code review. (For your uncommitted working
  diff, that's the separate built-in `/code-review`.)
- **`/team-onboarding`** scans how you've used Claude Code in this repo, classifies
  your work into task types, and co-authors an `ONBOARDING.md` guide new teammates
  can paste into Claude Code for a guided setup tour.

## Which built-ins are reproduced (and which can't be)

Not every built-in can be honestly rebuilt outside the running client. Commands
that only toggle terminal UI, or that talk to the Anthropic account/billing
backend or a native host, have no artifact to compute standalone and are **not
faked**. The full cross-reference — every built-in slash command, its binary
`type`, and its reproducibility tier — lives in
[`docs/command-inventory.md`](docs/command-inventory.md). This plugin builds the
Tier 1 (`type:"prompt"`) commands above plus `/usage` from Tier 2; the remaining
Tier 2 computational commands are candidates for future passes.

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
claude plugin install claude-builtins@nsheaps-claude-plugins
```

### Local Development

```bash
claude --plugin-dir /path/to/claude-builtins
```

## A note on shadowing the built-ins

The command names here (`/usage`, `/insights`, `/init`, `/review`,
`/team-onboarding`) are deliberately the **same** as the built-ins they
reproduce, so this plugin is a drop-in when the built-in isn't available. That
means when both exist, typing the bare name is ambiguous and you can't tell from
the output which implementation ran. To force this plugin's version, use the
plugin-qualified form:

```bash
/claude-builtins:usage
/claude-builtins:insights
/claude-builtins:init
/claude-builtins:review
/claude-builtins:team-onboarding
```

Skill names avoid the collision entirely — the PR-review skill is named
`pr-review`, not `review`, so it does not clash with the `review` skill in this
marketplace's `sdlc-utils` plugin.

## Usage

### `/usage` — where did my API calls go?

```bash
/usage                     # this session (most recent in the current project)
/usage --current           # the same thing, stated explicitly
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

### `/init` — generate a CLAUDE.md

```bash
/init                      # analyze the repo, write CLAUDE.md
```

Reproduces the built-in's two prompt variants. The classic prompt
(`prompts/init-classic.md`) and the newer skills/hooks-aware prompt
(`prompts/init-new.md`) both ship verbatim; the skill selects between them the
same way the binary does — on the `CLAUDE_CODE_NEW_INIT` flag.

Neither variant blindly appends to an existing `CLAUDE.md`. The classic prompt
suggests improvements to it. The new prompt checks for one in Phase 0 and asks
what to do — "Review and improve it", "Leave it, set up other things", or
"Start fresh (replace it)" — so replacement happens only on explicit choice,
and the improve path prints proposed diffs and confirms before writing.

### `/review` — review a pull request

```bash
/review <pr-number>        # e.g. /review 123
/review <pr-url>
```

Fetches the PR's metadata and diff with `gh` (`gh pr view --json …` + `gh pr
diff`), then produces a structured review across five focus areas with four
required sections. It **reads only** — nothing is posted back to GitHub. For a
review of your uncommitted working tree, that's the separate built-in
`/code-review`, which this plugin does not reproduce.

### `/team-onboarding` — build an ONBOARDING.md for teammates

```bash
/team-onboarding           # scan the last 30 days, co-author the guide
/team-onboarding --days 90 # widen the scan window
```

Runs `scripts/collect-onboarding-data.mjs` to scan how you've used Claude Code
in this repo (slash commands, MCP servers, session topics), classifies the work
into task types, and co-authors an `ONBOARDING.md`. The guide doubles as an
interactive tour: a new teammate pastes it into Claude Code and gets a guided
setup. The one piece that can't run standalone is the built-in's internal
share tool — the guide is saved to `ONBOARDING.md` for you to distribute.

All five commands simply invoke the matching skill; the skills contain the full
step-by-step procedure. You can also trigger the skills conversationally:

> "Show me my Claude Code usage for this session."
>
> "Generate an insights report from my sessions this month."
>
> "Create an onboarding guide for my team from how I use Claude Code."

## Scripts

| Script                                | Role                                                                                                |
| ------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `scripts/collect-usage.mjs`           | Deterministic token/cost breakdown for `/usage` (JSON on stdout).                                   |
| `scripts/collect-insights-data.mjs`   | Deterministic scan for `/insights` (counts, charts, session summaries).                             |
| `scripts/render-insights.mjs`         | Fills the HTML template from the collector data + LLM outputs.                                      |
| `scripts/collect-onboarding-data.mjs` | Deterministic usage scan for `/team-onboarding` (slash commands, MCP servers, session descriptors). |
| `scripts/lib/transcripts.mjs`         | Shared transcript discovery + counting helpers imported by all three collectors.                    |

`/init` and `/review` are prompt-only reproductions — they have no collector
script; their skills read the shipped prompts and call `gh` (for `/review`)
directly.

All scripts are plain `.mjs` — run with `node` (or `bun`). They read from
`~/.claude/projects/` and take scope flags documented in each skill.

## File Structure

```
claude-builtins/
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest
├── commands/
│   ├── usage.md                    # /usage command
│   ├── insights.md                 # /insights command
│   ├── init.md                     # /init command
│   ├── review.md                   # /review command
│   └── team-onboarding.md          # /team-onboarding command
├── skills/
│   ├── usage/SKILL.md              # /usage procedure
│   ├── insights/SKILL.md           # /insights procedure
│   ├── init/SKILL.md               # /init procedure
│   ├── pr-review/SKILL.md          # /review procedure
│   ├── team-onboarding/SKILL.md    # /team-onboarding procedure
│   └── extract-builtins/           # how the built-ins were recovered from the binary
│       ├── SKILL.md
│       └── scripts/                # binary-version.sh, slice-binary.mjs
├── scripts/
│   ├── lib/
│   │   └── transcripts.mjs         # shared transcript discovery + counting
│   ├── collect-usage.mjs
│   ├── collect-insights-data.mjs
│   ├── render-insights.mjs
│   └── collect-onboarding-data.mjs
├── assets/
│   ├── insights-template.html      # 35-token HTML template
│   └── prompts/                    # insights facets + 7 sections, init (classic/new),
│                                   #   review, team-onboarding + guide template
├── docs/
│   ├── command-inventory.md        # every built-in slash command + reproducibility tier
│   └── reload-mechanisms.md        # worked extraction: the /reload-plugins & /reload-skills triggers
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
