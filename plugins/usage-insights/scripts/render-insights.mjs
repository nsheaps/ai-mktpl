#!/usr/bin/env node
// render-insights.mjs
//
// Fills the {{TOKEN}} placeholders in assets/insights-template.html from:
//   1. the deterministic transcript scan produced by collect-insights-data.mjs
//   2. the LLM analysis passes (per-session facet classifier + 7 section prompts)
//
// Deterministic tokens (stats, tool/language/error charts, response-time
// buckets, multi-clauding, time-of-day array) come straight from the collect
// JSON. Facet-driven charts (what you wanted, session types, capabilities,
// outcomes, friction types, satisfaction) are aggregated here from the facet
// classifier output. Narrative sections come from the 7 section prompts.
//
// Every LLM/user-derived string is HTML-escaped before it reaches markup.
// Any missing input degrades to an empty state rather than throwing, so the
// script is safe to run before the LLM passes exist (useful for smoke tests).
//
// Usage:
//   node render-insights.mjs --data collect.json [options] > report.html
//
// Options:
//   --data <path>       Required. collect-insights-data.mjs JSON output.
//   --llm-dir <dir>     Directory of <name>.json LLM outputs (see NAMES below).
//   --sections <path>   Single bundle JSON keyed by the same NAMES.
//   --facets <path>     Override just the facet classifier output.
//   --<name> <path>     Override a single section (e.g. --project_areas x.json).
//   --template <path>   Template override (defaults to bundled asset).
//   --subtitle <text>   Subtitle override.
//   --out <path>        Write HTML here instead of stdout.

import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_TEMPLATE = join(__dirname, "..", "assets", "insights-template.html");

// Section names -> filenames looked up under --llm-dir, and keys in a bundle.
const SECTION_NAMES = [
  "facets",
  "project_areas",
  "interaction_style",
  "what_works",
  "friction_analysis",
  "suggestions",
  "on_the_horizon",
  "fun_ending",
];

// Chart palette (mirrors the built-in report).
const COLOR = {
  whatYouWanted: "#2563eb",
  topTools: "#0891b2",
  languages: "#10b981",
  sessionTypes: "#8b5cf6",
  whatHelped: "#16a34a",
  outcomes: "#14b8a6",
  frictionTypes: "#ef4444",
  satisfaction: "#eab308",
  toolErrors: "#dc2626",
  responseTime: "#6366f1",
};

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { overrides: {} };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    switch (a) {
      case "--data":
        args.data = next();
        break;
      case "--llm-dir":
        args.llmDir = next();
        break;
      case "--sections":
        args.sections = next();
        break;
      case "--facets":
        args.overrides.facets = next();
        break;
      case "--template":
        args.template = next();
        break;
      case "--subtitle":
        args.subtitle = next();
        break;
      case "--out":
        args.out = next();
        break;
      default:
        if (a.startsWith("--")) {
          const key = a.slice(2);
          if (SECTION_NAMES.includes(key)) args.overrides[key] = next();
        }
    }
  }
  return args;
}

// ---------------------------------------------------------------------------
// IO helpers
// ---------------------------------------------------------------------------

async function readJsonLoose(path) {
  if (!path || !existsSync(path)) return null;
  let text;
  try {
    text = await readFile(path, "utf8");
  } catch {
    return null;
  }
  return parseLoose(text);
}

// Parse JSON that may be wrapped in prose or ```json fences (LLM output).
function parseLoose(text) {
  if (text == null) return null;
  const trimmed = String(text).trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    // Fall through to brace extraction.
  }
  const first = trimmed.indexOf("{");
  const last = trimmed.lastIndexOf("}");
  if (first !== -1 && last > first) {
    try {
      return JSON.parse(trimmed.slice(first, last + 1));
    } catch {
      return null;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

function esc(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Escape, then promote **bold** markdown to <strong>. For short narrative text.
function escInline(s) {
  const escaped = esc(s);
  return escaped.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
}

// Escape into multiple <p> paragraphs split on blank lines. Bold supported.
function escParagraphs(s) {
  const parts = String(s == null ? "" : s)
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean);
  if (!parts.length) return "";
  return parts.map((p) => `<p>${escInline(p)}</p>`).join("");
}

function fmt(n) {
  const num = Number(n);
  if (!isFinite(num)) return "0";
  return num.toLocaleString("en-US");
}

// Humanize an enum token: snake_case -> "snake case".
function humanize(s) {
  return String(s == null ? "" : s)
    .replace(/_/g, " ")
    .trim();
}

function emptyState(msg) {
  return `<p class="empty">${esc(msg)}</p>`;
}

// ---------------------------------------------------------------------------
// Chart rendering
// ---------------------------------------------------------------------------

// items: [{ label, count }]. Produces the bar-row markup the template CSS
// expects. Returns an empty state when there is nothing to show.
function barChart(items, color, emptyMsg) {
  const rows = (items || []).filter((it) => it && Number(it.count) > 0);
  if (!rows.length) return emptyState(emptyMsg || "No data yet");
  const max = Math.max(1, ...rows.map((it) => Number(it.count) || 0));
  return rows
    .map((it) => {
      const pct = Math.round((Number(it.count) / max) * 100);
      return (
        `<div class="bar-row">` +
        `<div class="bar-label">${esc(it.label)}</div>` +
        `<div class="bar-track"><div class="bar-fill" style="width:${pct}%;background:${color};"></div></div>` +
        `<div class="bar-value">${fmt(it.count)}</div>` +
        `</div>`
      );
    })
    .join("");
}

// Aggregate a per-session facet field into ranked [{label,count}].
// `spread` true when the field is an array (request_types, capabilities, etc.).
function tallyFacet(sessions, field, { spread = false, limit = 10 } = {}) {
  const counts = new Map();
  for (const s of sessions) {
    if (!s) continue;
    const raw = s[field];
    const values = spread ? (Array.isArray(raw) ? raw : []) : raw ? [raw] : [];
    for (const v of values) {
      if (v == null || v === "") continue;
      const key = String(v);
      counts.set(key, (counts.get(key) || 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([k, count]) => ({ label: humanize(k), count }))
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))
    .slice(0, limit);
}

// ---------------------------------------------------------------------------
// Section renderers (LLM-driven)
// ---------------------------------------------------------------------------

function renderProjectAreas(pa) {
  const areas = (pa && Array.isArray(pa.areas) ? pa.areas : []).filter(Boolean);
  if (!areas.length) return emptyState("Project areas will appear once analysis has run.");
  return areas
    .map((a) => {
      const count = Number(a.session_count) || 0;
      const countLabel = count ? `${fmt(count)} session${count === 1 ? "" : "s"}` : "";
      return (
        `<div class="project-area">` +
        `<div class="area-header">` +
        `<div class="area-name">${esc(a.name)}</div>` +
        (countLabel ? `<div class="area-count">${esc(countLabel)}</div>` : "") +
        `</div>` +
        `<div class="area-desc">${escInline(a.description)}</div>` +
        `</div>`
      );
    })
    .join("");
}

function renderNarrative(is) {
  if (!is || (!is.narrative && !is.key_pattern)) {
    return emptyState("Interaction analysis will appear once analysis has run.");
  }
  let html = escParagraphs(is.narrative);
  if (is.key_pattern) {
    html += `<div class="key-insight">${escInline(is.key_pattern)}</div>`;
  }
  return html;
}

function renderBigWins(ww) {
  const wins = (ww && Array.isArray(ww.impressive_workflows) ? ww.impressive_workflows : []).filter(
    Boolean,
  );
  if (!wins.length) return emptyState("Standout workflows will appear once analysis has run.");
  return wins
    .map(
      (w) =>
        `<div class="big-win">` +
        `<div class="big-win-title">${esc(w.title)}</div>` +
        `<div class="big-win-desc">${escInline(w.description)}</div>` +
        `</div>`,
    )
    .join("");
}

function renderFrictionCategories(fa) {
  const cats = (fa && Array.isArray(fa.categories) ? fa.categories : []).filter(Boolean);
  if (!cats.length) return emptyState("Friction analysis will appear once analysis has run.");
  return cats
    .map((c) => {
      const examples = (Array.isArray(c.examples) ? c.examples : []).filter(Boolean);
      const exHtml = examples.length
        ? `<ul class="friction-examples">${examples.map((e) => `<li>${escInline(e)}</li>`).join("")}</ul>`
        : "";
      return (
        `<div class="friction-category">` +
        `<div class="friction-title">${esc(c.category)}</div>` +
        `<div class="friction-desc">${escInline(c.description)}</div>` +
        exHtml +
        `</div>`
      );
    })
    .join("");
}

function renderClaudeMdAdditions(sug) {
  const items = (
    sug && Array.isArray(sug.claude_md_additions) ? sug.claude_md_additions : []
  ).filter(Boolean);
  if (!items.length) return emptyState("CLAUDE.md suggestions will appear once analysis has run.");
  return items
    .map((it) => {
      const addition = it.addition || "";
      return (
        `<div class="claude-md-item">` +
        `<input type="checkbox" class="cmd-checkbox">` +
        `<code class="cmd-code" data-copy-group="claude-md">${esc(addition)}</code>` +
        `<button class="copy-btn" data-copy="${esc(addition)}">Copy</button>` +
        (it.why ? `<div class="cmd-why">${escInline(it.why)}</div>` : "") +
        `</div>`
      );
    })
    .join("");
}

function renderFeatures(sug) {
  const feats = (sug && Array.isArray(sug.features_to_try) ? sug.features_to_try : []).filter(
    Boolean,
  );
  if (!feats.length) return emptyState("Feature suggestions will appear once analysis has run.");
  return feats
    .map((f) => {
      let code = "";
      if (f.example_code) {
        code =
          `<div class="feature-code">` +
          `<code>${esc(f.example_code)}</code>` +
          `<button class="copy-btn" data-copy="${esc(f.example_code)}">Copy</button>` +
          `</div>`;
      }
      return (
        `<div class="feature-card">` +
        `<div class="feature-title">${esc(f.feature)}</div>` +
        (f.one_liner ? `<div class="feature-oneliner">${escInline(f.one_liner)}</div>` : "") +
        (f.why_for_you ? `<div class="feature-why">${escInline(f.why_for_you)}</div>` : "") +
        code +
        `</div>`
      );
    })
    .join("");
}

function renderUsagePatterns(sug) {
  const pats = (sug && Array.isArray(sug.usage_patterns) ? sug.usage_patterns : []).filter(Boolean);
  if (!pats.length)
    return emptyState("Usage-pattern suggestions will appear once analysis has run.");
  return pats
    .map((p) => {
      let prompt = "";
      if (p.copyable_prompt) {
        prompt =
          `<div class="pattern-prompt">` +
          `<div class="prompt-label">Try this prompt</div>` +
          `<code>${esc(p.copyable_prompt)}</code>` +
          `<button class="copy-btn" data-copy="${esc(p.copyable_prompt)}">Copy</button>` +
          `</div>`;
      }
      return (
        `<div class="pattern-card">` +
        `<div class="pattern-title">${esc(p.title)}</div>` +
        (p.suggestion ? `<div class="pattern-summary">${escInline(p.suggestion)}</div>` : "") +
        (p.detail ? `<div class="pattern-detail">${escInline(p.detail)}</div>` : "") +
        prompt +
        `</div>`
      );
    })
    .join("");
}

function renderHorizon(hz) {
  const opps = (hz && Array.isArray(hz.opportunities) ? hz.opportunities : []).filter(Boolean);
  if (!opps.length) return emptyState("Future opportunities will appear once analysis has run.");
  return opps
    .map((o) => {
      let prompt = "";
      if (o.copyable_prompt) {
        prompt =
          `<div class="copyable-prompt-section">` +
          `<div class="prompt-label">Prompt to try</div>` +
          `<div class="copyable-prompt-row">` +
          `<code class="copyable-prompt">${esc(o.copyable_prompt)}</code>` +
          `<button class="copy-btn" data-copy="${esc(o.copyable_prompt)}">Copy</button>` +
          `</div></div>`;
      }
      return (
        `<div class="horizon-card">` +
        `<div class="horizon-title">${esc(o.title)}</div>` +
        (o.whats_possible
          ? `<div class="horizon-possible">${escInline(o.whats_possible)}</div>`
          : "") +
        (o.how_to_try ? `<div class="horizon-tip">${escInline(o.how_to_try)}</div>` : "") +
        prompt +
        `</div>`
      );
    })
    .join("");
}

// Multi-clauding text block from deterministic timing data.
function renderMultiClauding(mc) {
  if (!mc || !mc.sessionsWithTiming) {
    return emptyState("Not enough session timing data to detect parallel sessions.");
  }
  if (!mc.everParallel) {
    return (
      `<p style="font-size:13px;color:#475569;">` +
      `Across ${fmt(mc.sessionsWithTiming)} timed session${mc.sessionsWithTiming === 1 ? "" : "s"}, ` +
      `no overlapping (parallel) sessions were detected — you tend to run one Claude Code session at a time.` +
      `</p>`
    );
  }
  return (
    `<p style="font-size:13px;color:#475569;">` +
    `You ran up to <strong style="color:${COLOR.sessionTypes};">${fmt(mc.maxConcurrent)}</strong> ` +
    `Claude Code session${mc.maxConcurrent === 1 ? "" : "s"} in parallel. ` +
    `<strong>${fmt(mc.overlappingSessions)}</strong> of your ${fmt(mc.sessionsWithTiming)} timed ` +
    `session${mc.sessionsWithTiming === 1 ? "" : "s"} overlapped with at least one other.` +
    `</p>`
  );
}

// ---------------------------------------------------------------------------
// Synthesized sections (At a Glance, Team Feedback)
// ---------------------------------------------------------------------------

function renderAtAGlance({ projectAreas, interaction, whatWorks, friction }) {
  const rows = [];
  const areas =
    projectAreas && Array.isArray(projectAreas.areas) ? projectAreas.areas.filter(Boolean) : [];
  if (areas.length) {
    const names = areas
      .slice(0, 3)
      .map((a) => a.name)
      .filter(Boolean)
      .map(esc)
      .join(", ");
    rows.push(
      `<div class="glance-section"><strong>What you work on:</strong> ${names} ` +
        `<a class="see-more" href="#section-work">see more &rarr;</a></div>`,
    );
  }
  if (interaction && interaction.key_pattern) {
    rows.push(
      `<div class="glance-section"><strong>How you use Claude Code:</strong> ${escInline(interaction.key_pattern)} ` +
        `<a class="see-more" href="#section-usage">see more &rarr;</a></div>`,
    );
  }
  const wins =
    whatWorks && Array.isArray(whatWorks.impressive_workflows)
      ? whatWorks.impressive_workflows.filter(Boolean)
      : [];
  if (wins.length) {
    rows.push(
      `<div class="glance-section"><strong>Impressive things:</strong> ${esc(wins[0].title)} ` +
        `<a class="see-more" href="#section-wins">see more &rarr;</a></div>`,
    );
  }
  const cats =
    friction && Array.isArray(friction.categories) ? friction.categories.filter(Boolean) : [];
  if (cats.length) {
    rows.push(
      `<div class="glance-section"><strong>Where things go wrong:</strong> ${esc(cats[0].category)} ` +
        `<a class="see-more" href="#section-friction">see more &rarr;</a></div>`,
    );
  }
  if (!rows.length) return emptyState("A summary will appear once analysis has run.");
  return rows.join("");
}

// Team Feedback cards synthesized from the facet aggregation (model-estimated).
function renderFeedback(sessions) {
  if (!sessions.length) {
    return emptyState("Model-estimated feedback will appear once analysis has run.");
  }
  const cards = [];
  const total = sessions.length;

  const outcomes = tallyFacet(sessions, "outcome", { limit: 5 });
  const satisfaction = tallyFacet(sessions, "satisfaction", { limit: 5 });
  const helpfulness = tallyFacet(sessions, "helpfulness", { limit: 5 });

  if (outcomes.length || satisfaction.length) {
    const topOutcome = outcomes[0];
    const topSat = satisfaction[0];
    const detailParts = [];
    if (topOutcome) {
      detailParts.push(
        `Most sessions ended <strong>${esc(topOutcome.label)}</strong> ` +
          `(${fmt(topOutcome.count)} of ${fmt(total)}).`,
      );
    }
    if (topSat) {
      detailParts.push(
        `Inferred satisfaction most often read as <strong>${esc(topSat.label)}</strong>.`,
      );
    }
    cards.push(
      `<div class="feedback-card team-card">` +
        `<div class="feedback-title">How Claude Code is landing for you</div>` +
        `<div class="feedback-detail">${detailParts.join(" ")}</div>` +
        `<div class="feedback-evidence">Based on model-estimated signals across ${fmt(total)} session${total === 1 ? "" : "s"}.</div>` +
        `</div>`,
    );
  }

  if (helpfulness.length) {
    const topHelp = helpfulness[0];
    cards.push(
      `<div class="feedback-card model-card">` +
        `<div class="feedback-title">Model performance signal</div>` +
        `<div class="feedback-detail">Claude was most often judged <strong>${esc(topHelp.label)}</strong> ` +
        `(${fmt(topHelp.count)} of ${fmt(total)} sessions).</div>` +
        `<div class="feedback-evidence">Helpfulness is a per-session inference, not a verified rating.</div>` +
        `</div>`,
    );
  }

  return cards.length
    ? cards.join("")
    : emptyState("Model-estimated feedback will appear once analysis has run.");
}

// ---------------------------------------------------------------------------
// Subtitle
// ---------------------------------------------------------------------------

function buildSubtitle(data, override) {
  if (override) return override;
  const det = data.deterministic || {};
  const count =
    Number(det.sessionCount) || (Array.isArray(data.sessions) ? data.sessions.length : 0);
  const days = Number(det.days) || 0;
  const scope = data.scope ? String(data.scope) : "all projects";
  const parts = [`Analysis of ${fmt(count)} session${count === 1 ? "" : "s"}`];
  if (days) parts.push(`over ${fmt(days)} day${days === 1 ? "" : "s"}`);
  parts.push(`· ${esc(scope)}`);
  let sub = parts.join(" ");
  if (data.generatedAt) {
    const d = String(data.generatedAt).slice(0, 10);
    sub += ` · generated ${d}`;
  }
  return sub;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.data) {
    process.stderr.write("render-insights: --data <collect.json> is required\n");
    process.exit(2);
  }

  const data = await readJsonLoose(args.data);
  if (!data) {
    process.stderr.write(`render-insights: could not read/parse --data ${args.data}\n`);
    process.exit(2);
  }

  // Assemble LLM section inputs: bundle < llm-dir < explicit overrides.
  const sections = {};
  if (args.sections) {
    const bundle = await readJsonLoose(args.sections);
    if (bundle && typeof bundle === "object") Object.assign(sections, bundle);
  }
  if (args.llmDir) {
    for (const name of SECTION_NAMES) {
      if (sections[name] == null) {
        const s = await readJsonLoose(join(args.llmDir, `${name}.json`));
        if (s != null) sections[name] = s;
      }
    }
  }
  for (const [name, path] of Object.entries(args.overrides)) {
    const s = await readJsonLoose(path);
    if (s != null) sections[name] = s;
  }

  const det = data.deterministic || {};
  const facetSessions =
    sections.facets && Array.isArray(sections.facets.sessions)
      ? sections.facets.sessions.filter(Boolean)
      : [];

  const projectAreas = sections.project_areas || null;
  const interaction = sections.interaction_style || null;
  const whatWorks = sections.what_works || null;
  const friction = sections.friction_analysis || null;
  const suggestions = sections.suggestions || null;
  const horizon = sections.on_the_horizon || null;
  const funEnding = sections.fun_ending || null;

  // Template values.
  const values = {
    SUBTITLE: buildSubtitle(data, args.subtitle),

    // Deterministic stats.
    STAT_MESSAGES: fmt(det.messages || 0),
    STAT_LINES: fmt(det.linesAdded || 0),
    STAT_FILES: fmt(det.filesTouched || 0),
    STAT_DAYS: fmt(det.days || 0),
    STAT_MSGS_PER_DAY: fmt(det.msgsPerDay || 0),

    // Synthesized summary + narrative sections.
    AT_A_GLANCE: renderAtAGlance({ projectAreas, interaction, whatWorks, friction }),
    PROJECT_AREAS: renderProjectAreas(projectAreas),
    INTERACTION_NARRATIVE: renderNarrative(interaction),

    // Facet-driven charts.
    CHART_WHAT_YOU_WANTED: barChart(
      tallyFacet(facetSessions, "request_types", { spread: true }),
      COLOR.whatYouWanted,
      "No request data yet",
    ),
    CHART_SESSION_TYPES: barChart(
      tallyFacet(facetSessions, "session_type"),
      COLOR.sessionTypes,
      "No session-type data yet",
    ),
    CHART_WHAT_HELPED: barChart(
      tallyFacet(facetSessions, "capabilities_that_helped", { spread: true }),
      COLOR.whatHelped,
      "No capability data yet",
    ),
    CHART_OUTCOMES: barChart(
      tallyFacet(facetSessions, "outcome"),
      COLOR.outcomes,
      "No outcome data yet",
    ),
    CHART_FRICTION_TYPES: barChart(
      tallyFacet(facetSessions, "friction_types", { spread: true }),
      COLOR.frictionTypes,
      "No friction recorded",
    ),
    CHART_SATISFACTION: barChart(
      tallyFacet(facetSessions, "satisfaction"),
      COLOR.satisfaction,
      "No satisfaction data yet",
    ),

    // Deterministic charts.
    CHART_TOP_TOOLS: barChart(
      (det.topTools || []).map((t) => ({ label: t.name, count: t.count })),
      COLOR.topTools,
      "No tool usage recorded",
    ),
    CHART_LANGUAGES: barChart(
      (det.languages || []).map((l) => ({ label: l.name, count: l.count })),
      COLOR.languages,
      "No language data recorded",
    ),
    CHART_TOOL_ERRORS: barChart(
      (det.toolErrors || []).map((e) => ({ label: e.name, count: e.count })),
      COLOR.toolErrors,
      "No tool errors — nice!",
    ),
    CHART_RESPONSE_TIME: barChart(
      (det.responseTimes && det.responseTimes.buckets ? det.responseTimes.buckets : []).map(
        (b) => ({
          label: b.label,
          count: b.count,
        }),
      ),
      COLOR.responseTime,
      "No response-time data yet",
    ),
    RESPONSE_MEDIAN: fmt(det.responseTimes ? det.responseTimes.median || 0 : 0),
    RESPONSE_AVERAGE: fmt(det.responseTimes ? det.responseTimes.average || 0 : 0),
    MULTI_CLAUDING: renderMultiClauding(det.multiClauding),
    TIMEOFDAY_DATA: JSON.stringify(
      Array.isArray(det.timeOfDayUTC) && det.timeOfDayUTC.length === 24
        ? det.timeOfDayUTC.map((n) => Number(n) || 0)
        : new Array(24).fill(0),
    ),

    // Wins / friction narrative.
    WINS_INTRO: whatWorks && whatWorks.intro ? escInline(whatWorks.intro) : "",
    BIG_WINS: renderBigWins(whatWorks),
    FRICTION_INTRO: friction && friction.intro ? escInline(friction.intro) : "",
    FRICTION_CATEGORIES: renderFrictionCategories(friction),

    // Suggestions.
    CLAUDE_MD_ADDITIONS: renderClaudeMdAdditions(suggestions),
    FEATURES: renderFeatures(suggestions),
    USAGE_PATTERNS: renderUsagePatterns(suggestions),

    // Horizon.
    HORIZON_INTRO: horizon && horizon.intro ? escInline(horizon.intro) : "",
    HORIZON: renderHorizon(horizon),

    // Feedback + fun ending.
    FEEDBACK: renderFeedback(facetSessions),
    FUN_HEADLINE: funEnding && funEnding.headline ? esc(funEnding.headline) : "That's a wrap",
    FUN_DETAIL: funEnding && funEnding.detail ? escInline(funEnding.detail) : "",
  };

  let template = await readFile(args.template || DEFAULT_TEMPLATE, "utf8");
  for (const [token, value] of Object.entries(values)) {
    template = template.split(`{{${token}}}`).join(value);
  }

  // Surface any tokens we failed to fill (defensive; should be none).
  const leftover = template.match(/\{\{[A-Z_]+\}\}/g);
  if (leftover && leftover.length) {
    process.stderr.write(
      `render-insights: warning — unfilled tokens: ${[...new Set(leftover)].join(", ")}\n`,
    );
  }

  if (args.out) {
    await writeFile(args.out, template, "utf8");
    process.stderr.write(`render-insights: wrote ${args.out}\n`);
  } else {
    process.stdout.write(template);
  }
}

main().catch((err) => {
  process.stderr.write(`render-insights: ${err && err.stack ? err.stack : err}\n`);
  process.exit(1);
});
