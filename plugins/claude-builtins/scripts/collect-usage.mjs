#!/usr/bin/env node
// collect-usage.mjs — LOCAL, APPROXIMATE analyzer of your own Claude Code
// transcripts. This is NOT a reproduction of the built-in `/usage`.
//
// The real `/usage` is an Ink TUI (server-backed): its headline numbers — plan
// and rate-limit utilization %, reset times, and session USD cost — come from
// Claude's servers (`GET /api/oauth/usage`) and Claude's internal per-model
// price accounting. None of that can be recomputed by a plugin, so none of it
// is reproduced here.
//
// What this script DOES reproduce is the *relative weighting* the binary uses
// internally for only one part of `/usage` — the "What's contributing to your
// limits usage?" section — computed over your local transcripts. It parses
// session transcript JSONL under $CLAUDE_CONFIG_DIR/projects/<encoded-cwd>/*.jsonl
// (~/.claude/projects/ by default; plus each session's subagents/**/*.jsonl),
// then reports token totals and where the
// weighted usage went: by model, by tool, by sub-agent / skill / plugin / MCP
// server, and main-vs-subagent.
//
// The weight is the binary's own internal relative unit (fns nNb × rNb), and is
// NEVER dollars and never the number `/usage` shows as a headline:
//   weight = (cache_read + input*10 + cache_creation*12.5 + output*50) * modelTier
//   modelTier: fable=10, opus=5, haiku=1, default=3
// Requests are de-duplicated by requestId/uuid, matching the binary's local scan.
//
// Coverage note: the binary's local section reports five behaviors —
// cache_miss, long_context, subagent_heavy, high_parallel, and cron. This script
// currently computes only cache_miss (>100k input) and long_context (>150k
// total); subagent_heavy, high_parallel, and cron are NOT computed here.
//
// Usage:
//   node collect-usage.mjs [options]
//     --session <id>       only messages with this sessionId (across all projects)
//     --file <path>        parse a single transcript file
//     --project-dir <dir>  project transcript dir to scan (default: derived from $PWD)
//     --all                scan ALL projects (defaults the window to 7 days)
//     --days <n>           only include messages from the last <n> days
//     --current            analyze the most-recent session in the project dir (default)
//     --json               emit only the JSON blob (no human summary)
//
// Output: a human-readable summary on stderr and a single JSON object on stdout.

import { readdir, stat } from "node:fs/promises";
import { join, extname, basename } from "node:path";
import { createInterface } from "node:readline";
import { createReadStream } from "node:fs";
import {
  PROJECTS_DIR,
  resolveProjectDir,
  transcriptFilesIn,
  allTranscriptFiles,
  projectsDirExists,
  categorizeToolError,
  bump,
  mergeCounts,
  mapToSortedList,
} from "./lib/transcripts.mjs";

// ---------------------------------------------------------------------------
// Relative-weight model (verbatim from the binary: nNb / rNb). This is the
// binary's INTERNAL weighting for the local "contributing factors" section —
// a relative unit, never USD, never the `/usage` headline number.
// ---------------------------------------------------------------------------

/** modelTier: fable=10, opus=5, haiku=1, default=3 (binary: rNb) */
function modelTier(model) {
  if (!model) return 3;
  const t = model.toLowerCase();
  if (t.includes("fable")) return 10;
  if (t.includes("opus")) return 5;
  if (t.includes("haiku")) return 1;
  return 3;
}

/** relative weight units (binary: nNb) */
function weightOf(u) {
  return (u.cached + u.uncached * 10 + u.cacheCreate * 12.5 + u.output * 50) * u.modelTier;
}

// Behavior thresholds (binary constants)
const WINDOW_7D_MS = 604800000; // XDp
const CACHE_MISS_TOKENS = 1e5; // x1b
const LONG_CTX_TOKENS = 150000; // I1b

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const opts = {
    session: null,
    file: null,
    projectDir: null,
    all: false,
    days: null,
    current: false,
    jsonOnly: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--session") opts.session = argv[++i];
    else if (a === "--file") opts.file = argv[++i];
    else if (a === "--project-dir") opts.projectDir = argv[++i];
    else if (a === "--all") opts.all = true;
    else if (a === "--days") opts.days = Number(argv[++i]);
    else if (a === "--current") opts.current = true;
    else if (a === "--json") opts.jsonOnly = true;
  }
  return opts;
}

// ---------------------------------------------------------------------------
// Transcript discovery
//
// PROJECTS_DIR / resolveProjectDir / transcriptFilesIn / allTranscriptFiles all
// live in ./lib/transcripts.mjs — every collector walks the same tree.
// ---------------------------------------------------------------------------

/** Most-recently-modified top-level session file in a project dir. */
async function mostRecentSessionFile(dir) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return null;
  }
  let best = null;
  let bestMtime = -1;
  for (const e of entries) {
    if (e.isFile() && extname(e.name) === ".jsonl") {
      const p = join(dir, e.name);
      const s = await stat(p);
      if (s.mtimeMs > bestMtime) {
        bestMtime = s.mtimeMs;
        best = p;
      }
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

/**
 * Parse one JSONL transcript file. Returns { usages: [...], toolUses: Map,
 * toolErrors: Map }. usages carry per-request token + attribution data.
 */
async function parseFile(path, { sinceMs, sessionFilter }) {
  const usages = [];
  const toolUses = new Map(); // tool name -> count
  const toolErrors = new Map(); // category -> count
  const rl = createInterface({
    input: createReadStream(path, { encoding: "utf8" }),
    crlfDelay: Infinity,
  });
  for await (const line of rl) {
    if (!line) continue;
    let obj;
    try {
      obj = JSON.parse(line);
    } catch {
      continue;
    }
    const ts = obj.timestamp ? Date.parse(obj.timestamp) : NaN;
    const sessionId = obj.sessionId ?? "";
    if (sessionFilter && sessionId !== sessionFilter) continue;
    // Apply the --days/--all window before any aggregation, so the tool and
    // error breakdowns cover the same time range as the token totals.
    // Records with an unparseable timestamp are kept rather than dropped.
    if (!Number.isNaN(ts) && sinceMs && ts < sinceMs) continue;

    const msg = obj.message;
    // Count tool_use blocks in assistant messages.
    if (msg && msg.role === "assistant" && Array.isArray(msg.content)) {
      for (const block of msg.content) {
        if (block && block.type === "tool_use" && block.name) {
          toolUses.set(block.name, (toolUses.get(block.name) ?? 0) + 1);
        }
      }
    }
    // Count tool_result errors in user messages.
    if (msg && msg.role === "user" && Array.isArray(msg.content)) {
      for (const block of msg.content) {
        if (block && block.type === "tool_result" && block.is_error) {
          const cat = categorizeToolError(block.content);
          toolErrors.set(cat, (toolErrors.get(cat) ?? 0) + 1);
        }
      }
    }

    // Usage records: assistant messages with a usage object.
    const usage = msg && msg.usage;
    if (!usage || obj.type !== "assistant") continue;

    const input = usage.input_tokens ?? 0;
    const output = usage.output_tokens ?? 0;
    const cacheCreate = usage.cache_creation_input_tokens ?? 0;
    const cacheRead = usage.cache_read_input_tokens ?? 0;
    if (input + output + cacheCreate + cacheRead === 0) continue;

    const model = msg.model ?? obj.model ?? "";
    const rec = {
      ts: Number.isNaN(ts) ? 0 : ts,
      sessionId,
      cached: cacheRead,
      uncached: input,
      cacheCreate,
      output,
      isSubagent: obj.isSidechain === true,
      modelTier: modelTier(model),
      model: normalizeModel(model),
      uuid: obj.requestId ?? msg.id ?? obj.uuid ?? "",
      attributionAgent: obj.attributionAgent,
      attributionSkill: obj.attributionSkill,
      attributionPlugin: obj.attributionPlugin,
      attributionMcpServer: obj.attributionMcpServer,
    };
    usages.push(rec);
  }
  return { usages, toolUses, toolErrors };
}

/** Collapse a model id to a friendly family label. */
function normalizeModel(model) {
  if (!model) return "unknown";
  const t = model.toLowerCase();
  if (t.includes("opus")) return "opus";
  if (t.includes("sonnet")) return "sonnet";
  if (t.includes("haiku")) return "haiku";
  if (t.includes("fable")) return "fable";
  return model;
}

// ---------------------------------------------------------------------------
// Aggregation
// ---------------------------------------------------------------------------

function aggregate(records) {
  const seen = new Set();
  let totalWeight = 0;
  let requestCount = 0;
  let cacheMissWeight = 0;
  let cacheMissCount = 0;
  let longCtxWeight = 0;
  let longCtxCount = 0;

  const tokens = { input: 0, output: 0, cacheCreate: 0, cacheRead: 0 };
  const byModel = new Map();
  const byAgent = new Map();
  const bySkill = new Map();
  const byPlugin = new Map();
  const byMcpServer = new Map();
  const sessions = new Map();
  const hours = new Map(); // hour-of-day (0-23) -> request count
  let mainWeight = 0;
  let subWeight = 0;
  let subCount = 0;
  let attributedRecords = 0;

  for (const r of records) {
    if (r.uuid) {
      if (seen.has(r.uuid)) continue;
      seen.add(r.uuid);
    }
    const w = weightOf(r);
    totalWeight += w;
    requestCount++;

    tokens.input += r.uncached;
    tokens.output += r.output;
    tokens.cacheCreate += r.cacheCreate;
    tokens.cacheRead += r.cached;

    bump(byModel, r.model, w);

    // Attribution (binary: fXd). The four attribution* fields were recovered
    // from the binary's strings; older transcripts predate them and carry none,
    // which is why `attributionAvailable` is reported below.
    //
    // The agent/skill split reproduces fXd: a request made *inside* a subagent
    // is keyed by the skill that agent was running when one is known, falling
    // back to the agent name — so the "by agent" breakdown reads as "which skill
    // did this agent spend its budget on". Requests outside a subagent are keyed
    // by skill alone. Plugin and MCP-server attribution are independent of both.
    if (r.attributionAgent || r.attributionSkill || r.attributionPlugin || r.attributionMcpServer) {
      attributedRecords++;
    }
    if (r.attributionAgent) bump(byAgent, r.attributionSkill ?? r.attributionAgent, w);
    else bump(bySkill, r.attributionSkill, w);
    bump(byPlugin, r.attributionPlugin, w);
    bump(byMcpServer, r.attributionMcpServer, w);

    const totalToks = r.cached + r.cacheCreate + r.uncached;
    if (r.uncached > CACHE_MISS_TOKENS) {
      cacheMissWeight += w;
      cacheMissCount++;
    }
    if (totalToks > LONG_CTX_TOKENS) {
      longCtxWeight += w;
      longCtxCount++;
    }

    if (r.isSubagent) {
      subWeight += w;
      subCount++;
    } else {
      mainWeight += w;
    }

    let s = sessions.get(r.sessionId);
    if (!s) {
      s = { weight: 0, requests: 0, subWeight: 0, subCount: 0 };
      sessions.set(r.sessionId, s);
    }
    s.weight += w;
    s.requests++;
    if (r.isSubagent) {
      s.subWeight += w;
      s.subCount++;
    }

    if (r.ts) {
      const hod = new Date(r.ts).getHours();
      hours.set(hod, (hours.get(hod) ?? 0) + 1);
    }
  }

  return {
    totalWeight,
    requestCount,
    sessionCount: sessions.size,
    tokens,
    cacheMiss: { weight: cacheMissWeight, count: cacheMissCount },
    longContext: { weight: longCtxWeight, count: longCtxCount },
    mainWeight,
    subagent: { weight: subWeight, count: subCount },
    byModel: pctList(byModel, totalWeight),
    byAgent: pctList(byAgent, totalWeight),
    bySkill: pctList(bySkill, totalWeight),
    byPlugin: pctList(byPlugin, totalWeight),
    byMcpServer: pctList(byMcpServer, totalWeight),
    // Distinguishes "no attribution data in these transcripts" (all pre-fXd)
    // from "attribution data exists but nothing was attributed".
    attributedRequests: attributedRecords,
    attributionAvailable: attributedRecords > 0,
    sessions,
    hours,
  };
}

/** Sort a name->weight map descending, attach integer percentages. */
function pctList(map, total) {
  if (map.size === 0 || total === 0) return [];
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([name, weight]) => ({
      name,
      weight: Math.round(weight),
      pct: Math.round((weight / total) * 100),
    }))
    .filter((r) => r.weight > 0);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  let sinceMs = null;
  if (typeof opts.days === "number" && !Number.isNaN(opts.days)) {
    sinceMs = Date.now() - opts.days * 86400000;
  } else if (opts.all && !opts.current) {
    sinceMs = Date.now() - WINDOW_7D_MS;
  }

  let files = [];
  let sessionFilter = opts.session;
  let scope = "current-session";

  // `--current` is also the no-flag default, so it only *narrows*: it must win
  // over --all/--session, otherwise `--current --all` silently reports --all.
  if (opts.file) {
    files = [opts.file];
    scope = `file:${basename(opts.file)}`;
  } else if (opts.all && !opts.current) {
    files = await allTranscriptFiles();
    // Label the window actually in effect: --days overrides the 7-day default.
    const windowDays =
      typeof opts.days === "number" && !Number.isNaN(opts.days)
        ? opts.days
        : WINDOW_7D_MS / 86400000;
    scope = `all-projects-${windowDays}d`;
  } else if (opts.session && !opts.current) {
    files = await allTranscriptFiles();
    scope = `session:${opts.session}`;
  } else {
    // `--current`, or no scope flag at all: the most-recent session in the
    // cwd's project dir.
    const projectDir = opts.projectDir ?? resolveProjectDir(process.cwd());
    if (!projectDir) {
      process.stderr.write(
        `No project transcript dir found for ${process.cwd()}.\n` +
          `Looked in ${PROJECTS_DIR}. Try --all, --session <id>, or --file <path>.\n`,
      );
      process.stdout.write(JSON.stringify({ error: "no_project_dir", scope }, null, 2) + "\n");
      return;
    }
    const recent = await mostRecentSessionFile(projectDir);
    if (!recent) {
      process.stderr.write(`No .jsonl transcripts in ${projectDir}.\n`);
      process.stdout.write(JSON.stringify({ error: "no_transcripts", scope }, null, 2) + "\n");
      return;
    }
    // Derive the sessionId from the filename (Claude names files <sessionId>.jsonl),
    // then scan the whole project dir so this session's subagents are included.
    sessionFilter = basename(recent, ".jsonl");
    files = await transcriptFilesIn(projectDir);
    scope = `current-session:${sessionFilter}`;
  }

  if (files.length === 0 && (opts.all || opts.session) && !opts.file) {
    // Unlike the no_project_dir/no_transcripts early-returns above, this path
    // still emits a well-formed, complete, zero-everything report below (by
    // design — --all across zero real sessions is a valid answer). Without
    // this note that's indistinguishable on stdout from "you've used Claude
    // Code zero times" even when PROJECTS_DIR itself doesn't exist.
    process.stderr.write(
      projectsDirExists()
        ? `usage: no transcripts found for scope ${scope}\n`
        : `usage: no transcripts found for scope ${scope} — ${PROJECTS_DIR} does not exist ` +
            `(check $CLAUDE_CONFIG_DIR if you expected it elsewhere)\n`,
    );
  }

  const allUsages = [];
  const toolUses = new Map();
  const toolErrors = new Map();
  for (const f of files) {
    const {
      usages,
      toolUses: tu,
      toolErrors: te,
    } = await parseFile(f, {
      sinceMs,
      sessionFilter,
    });
    allUsages.push(...usages);
    mergeCounts(toolUses, tu);
    mergeCounts(toolErrors, te);
  }

  const agg = aggregate(allUsages);

  const hourList = [...agg.hours.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([hour, count]) => ({ hour, count }));

  const sessionList = [...agg.sessions.entries()]
    .sort((a, b) => b[1].weight - a[1].weight)
    .slice(0, 20)
    .map(([id, s]) => ({
      sessionId: id,
      weight: Math.round(s.weight),
      requests: s.requests,
      subagentWeight: Math.round(s.subWeight),
      subagentRequests: s.subCount,
    }));

  const result = {
    scope,
    generatedAt: new Date().toISOString(),
    note:
      "LOCAL APPROXIMATION — not the built-in /usage. `weight` is the binary's " +
      "INTERNAL relative unit (matches nNb×rNb) used only for the local " +
      '"What\'s contributing to your limits usage?" section. It is NOT USD and ' +
      "NOT the utilization/cost numbers /usage shows (those come from Claude's " +
      "servers and cannot be reproduced here). Model tiers: fable=10, opus=5, " +
      "haiku=1, default=3. Weighting: cache_read×1, input×10, cache_creation×12.5, " +
      "output×50. Behaviors computed here: cache_miss, long_context only " +
      "(subagent_heavy, high_parallel, cron are NOT computed).",
    totals: {
      requestCount: agg.requestCount,
      sessionCount: agg.sessionCount,
      weight: Math.round(agg.totalWeight),
      tokens: agg.tokens,
      totalTokens:
        agg.tokens.input + agg.tokens.output + agg.tokens.cacheCreate + agg.tokens.cacheRead,
    },
    split: {
      mainWeight: Math.round(agg.mainWeight),
      subagentWeight: Math.round(agg.subagent.weight),
      subagentRequests: agg.subagent.count,
      mainPct: agg.totalWeight ? Math.round((agg.mainWeight / agg.totalWeight) * 100) : 0,
      subagentPct: agg.totalWeight ? Math.round((agg.subagent.weight / agg.totalWeight) * 100) : 0,
    },
    behaviors: {
      cacheMiss: { weight: Math.round(agg.cacheMiss.weight), count: agg.cacheMiss.count },
      longContext: { weight: Math.round(agg.longContext.weight), count: agg.longContext.count },
    },
    byModel: agg.byModel,
    byTool: mapToSortedList(toolUses),
    toolErrors: mapToSortedList(toolErrors),
    // When `available` is false, the empty byAgent/bySkill/byPlugin/byMcpServer
    // lists mean "these transcripts predate attribution", not "nothing ran".
    attribution: {
      available: agg.attributionAvailable,
      attributedRequests: agg.attributedRequests,
    },
    byAgent: agg.byAgent,
    bySkill: agg.bySkill,
    byPlugin: agg.byPlugin,
    byMcpServer: agg.byMcpServer,
    byHourOfDay: hourList,
    topSessions: sessionList,
  };

  if (!opts.jsonOnly) {
    process.stderr.write(renderSummary(result));
  }
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
}

function bar(pct, width = 24) {
  const filled = Math.round((pct / 100) * width);
  return "█".repeat(filled) + "░".repeat(Math.max(0, width - filled));
}

function renderSummary(r) {
  const L = [];
  L.push("");
  L.push("═══ Claude Code local usage (approximate) ═══");
  L.push(`scope: ${r.scope}`);
  L.push("(relative weight, not USD — see note; the real /usage numbers come from Claude)");
  L.push("");
  L.push(
    `Requests: ${r.totals.requestCount}   Sessions: ${r.totals.sessionCount}   Weight (relative): ${r.totals.weight.toLocaleString()}`,
  );
  const t = r.totals.tokens;
  L.push(
    `Tokens: input ${t.input.toLocaleString()} · output ${t.output.toLocaleString()} · cacheCreate ${t.cacheCreate.toLocaleString()} · cacheRead ${t.cacheRead.toLocaleString()}`,
  );
  L.push(
    `Main vs subagent: ${r.split.mainPct}% main / ${r.split.subagentPct}% subagent (${r.split.subagentRequests} subagent reqs)`,
  );
  L.push("");
  if (r.byModel.length) {
    L.push("By model (share of weight):");
    for (const m of r.byModel) L.push(`  ${bar(m.pct)} ${String(m.pct).padStart(3)}%  ${m.name}`);
    L.push("");
  }
  if (r.byTool.length) {
    L.push("Top tools (by invocation):");
    for (const tt of r.byTool.slice(0, 12)) L.push(`  ${String(tt.count).padStart(5)}  ${tt.name}`);
    L.push("");
  }
  if (r.byAgent.length) {
    L.push("By sub-agent (share of weight):");
    for (const a of r.byAgent) L.push(`  ${String(a.pct).padStart(3)}%  ${a.name}`);
    L.push("");
  }
  if (r.bySkill.length) {
    L.push("By skill (share of weight):");
    for (const s of r.bySkill) L.push(`  ${String(s.pct).padStart(3)}%  ${s.name}`);
    L.push("");
  }
  if (r.byMcpServer.length) {
    L.push("By MCP server (share of weight):");
    for (const s of r.byMcpServer) L.push(`  ${String(s.pct).padStart(3)}%  ${s.name}`);
    L.push("");
  }
  if (r.toolErrors.length) {
    L.push("Tool errors:");
    for (const e of r.toolErrors) L.push(`  ${String(e.count).padStart(5)}  ${e.name}`);
    L.push("");
  }
  return L.join("\n") + "\n";
}

main().catch((err) => {
  process.stderr.write(`collect-usage failed: ${err?.stack ?? err}\n`);
  process.exitCode = 1;
});
