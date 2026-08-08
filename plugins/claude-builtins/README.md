# claude-builtins

Faithful extractions of Claude Code's built-in slash-command prompts, taken
verbatim from the CLI binary (**v2.1.225**) and driven from portable plugin
skills. Everything the skills need — collector scripts, the verbatim LLM
prompts, and the HTML template — ships inside this plugin.

- **`/security-review`** runs the built-in's verbatim prompt: a senior security
  engineer's review of the pending changes on the current branch (diffed against
  `origin/HEAD`), pulling the diff through inline `git` bang-commands. No
  arguments; reads only.
- **`/usage`** runs a **local, approximate** analysis of your transcripts — token
  counts plus the binary's own relative-weight unit — then has an agent analyze
  _where_ the weight went (models, tools, subagents, skills, plugins, MCP
  servers, time of day). This does **not** reproduce the built-in `/usage`, which
  is an Ink TUI backed by server-side plan/limit data a plugin can't recompute.
- **`/insights`** scans your session transcripts, classifies each session across
  the built-in's verbatim facet taxonomy, writes seven narrative sections, and
  renders a shareable HTML report — stat cards, facet charts, a time-of-day
  chart, wins, friction analysis, CLAUDE.md suggestions, and "on the horizon"
  prompts. (The built-in assembles its HTML programmatically; the plugin ships an
  equivalent renderer as a faithful stand-in.)
- **`/init`** generates a `CLAUDE.md` for the current repo from the built-in's
  verbatim classic and newer skills/hooks-aware prompts (the variant toggles on
  `CLAUDE_CODE_NEW_INIT`).
- **`/team-onboarding`** scans how you've used Claude Code in this repo, classifies
  your work into task types, and co-authors an `ONBOARDING.md` guide new teammates
  can paste into Claude Code for a guided setup tour.

## Which built-ins are extracted (and which can't be)

Not every built-in can be driven honestly outside the running client. Commands
that only toggle terminal UI, or that talk to the Anthropic account/billing
backend or a native host, have no prompt or computation to recover and are **not
faked**. The full cross-reference — every built-in slash command, its binary
`type`, and its extraction tier — lives in
[`docs/command-inventory.md`](docs/command-inventory.md). This plugin ships the
Tier 1 (`type:"prompt"`) commands above plus a local approximation of `/usage`
from Tier 2; the remaining Tier 2 computational commands are candidates for
future passes.

## Features

- **Runs outside the built-in** — the collectors parse
  `~/.claude/projects/**/*.jsonl` directly; nothing calls the built-in commands.
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

The command names here (`/security-review`, `/usage`, `/insights`, `/init`,
`/team-onboarding`) are deliberately the **same** as the built-ins they extract,
so this plugin is a drop-in when the built-in isn't available. That means when
both exist, typing the bare name is ambiguous and you can't tell from the output
which one ran. To force this plugin's version, use the plugin-qualified form:

```bash
/claude-builtins:security-review
/claude-builtins:usage
/claude-builtins:insights
/claude-builtins:init
/claude-builtins:team-onboarding
```

The same goes for skills: this plugin's `security-review` skill shares its name
with Claude Code's built-in `security-review` skill, so it too is an intentional
drop-in. When both are present, invoke this one explicitly as
`claude-builtins:security-review` to be unambiguous.

## Usage

### `/usage` — a local, approximate look at where the weight went

> **This does not reproduce the built-in `/usage`.** The built-in is an Ink TUI
> backed by server-side plan/limit and cost data that a plugin cannot recompute.
> What follows is a local, approximate analysis of your transcripts — an
> approximation of the built-in's "what's contributing to your limits usage?"
> section only, never a headline cost and never USD.

```bash
/usage                     # this session (most recent in the current project)
/usage --current           # the same thing, stated explicitly
/usage --all --days 30     # everything from the last 30 days
/usage --session <id>      # one session, across all projects
```

The command runs `scripts/collect-usage.mjs` for the deterministic breakdown,
then analyzes it. Weights are reported in the binary's **relative-weight unit —
not USD, and not the utilization/cost the built-in `/usage` shows**. The weight
formula, recovered verbatim from the binary:

```
weight = (cache_read + input*10 + cache_creation*12.5 + output*50) * modelTier
modelTier:  fable = 10,  opus = 5,  haiku = 1,  default = 3
```

Requests are deduped by `requestId` / message `uuid` so retries and streamed
duplicates are not double-counted. Only the `cacheMiss` (input > 100k) and
`longContext` (> 150k total) contributing factors are computed locally; the
built-in's other factors are not.

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

### `/security-review` — security-review the current branch

```bash
/security-review           # review the pending changes on the current branch
```

Runs the built-in's verbatim prompt: a senior security engineer's focused review
of the branch's changes against `origin/HEAD`, with the diff pulled in through
four inline `git` bang-commands (`git status`, `git diff --name-only
origin/HEAD...`, and the rest). It takes **no arguments** and **reads only** —
nothing is posted anywhere. For a general review of your uncommitted working
tree, that's the separate built-in `/code-review`, which this plugin does not
extract.

### `/team-onboarding` — build an ONBOARDING.md for teammates

```bash
/team-onboarding           # scan the last 30 days, co-author the guide
/team-onboarding --days 90 # widen the scan window
```

Runs `scripts/collect-onboarding-data.mjs` to scan how you've used Claude Code
in this repo (slash commands, MCP servers, session topics), classifies the work
into task types, and co-authors an `ONBOARDING.md`. The guide doubles as an
interactive tour: a new teammate pastes it into Claude Code and gets a guided
setup. The one piece that can't run outside the CLI is the built-in's
server-gated internal share tool — the guide is saved to `ONBOARDING.md` for you
to distribute.

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
| `scripts/collect-usage.mjs`           | Local token / relative-weight breakdown for `/usage` (JSON on stdout).                              |
| `scripts/collect-insights-data.mjs`   | Deterministic scan for `/insights` (counts, charts, session summaries).                             |
| `scripts/render-insights.mjs`         | Fills the HTML template from the collector data + LLM outputs.                                      |
| `scripts/collect-onboarding-data.mjs` | Deterministic usage scan for `/team-onboarding` (slash commands, MCP servers, session descriptors). |
| `scripts/lib/transcripts.mjs`         | Shared transcript discovery + counting helpers imported by all three collectors.                    |

`/init` and `/security-review` are prompt-only extractions — they have no
collector script; their skills read the shipped verbatim prompts and run those
directly (`/security-review` gathers its diff through the prompt's inline `git`
bang-commands).

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
│   ├── security-review.md          # /security-review command
│   └── team-onboarding.md          # /team-onboarding command
├── skills/
│   ├── usage/SKILL.md              # /usage procedure
│   ├── insights/SKILL.md           # /insights procedure
│   ├── init/SKILL.md               # /init procedure
│   ├── security-review/SKILL.md    # /security-review procedure
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
│                                   #   security-review, team-onboarding + guide template
├── docs/
│   ├── command-inventory.md        # every built-in slash command + extraction tier
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
- The six facet charts (what you wanted, session types, what helped, outcomes,
  friction types, satisfaction) are aggregated from `facets.json`, so their
  accuracy depends on the facet-classification pass. The verbatim classifier
  emits count maps (`goal_categories`, `friction_counts`,
  `user_satisfaction_counts`) and scalars (`claude_helpfulness`,
  `primary_success`) rather than the enum arrays/scalars an older renderer
  tallied. No reshaping is needed: each chart in `render-insights.mjs` is fed an
  **alias list** of accepted field names, and its `tallyFacet` helper understands
  all three shapes — a count map (`{category: n}`, whose values are summed as
  weights), an enum array, or a plain scalar. So the verbatim count-map fields
  feed the charts with their counts preserved, and the older enum-array/scalar
  names still tally too. "What Helped Most" reads `primary_success` (the
  classifier's Claude-capability enum).
- All user- and LLM-supplied strings are HTML-escaped before insertion; the only
  raw injection is the time-of-day integer array, emitted as a bare 24-element
  literal.
