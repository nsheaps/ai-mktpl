#!/usr/bin/env node
// collect-usage.mjs — standalone re-implementation of Claude Code's built-in
// `/usage` data collection, reverse-engineered from the CLI binary.
//
// Parses session transcript JSONL under ~/.claude/projects/<encoded-cwd>/*.jsonl
// (plus each session's subagents/**/*.jsonl) and computes token totals, a
// synthetic cost figure, and a breakdown of WHERE the API calls went: by model,
// by tool, by sub-agent / skill / plugin / MCP server, and main-vs-subagent.
//
// The cost model is the binary's own (synthetic "units", NOT USD):
//   cost = (cache_read + input*10 + cache_creation*12.5 + output*50) * modelTier
//   modelTier: fable=10, opus=5, haiku=1, default=3
// Requests are de-duplicated by requestId/uuid, exactly like the built-in.
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
import { existsSync } from "node:fs";
import { join, extname, basename } from "node:path";
import { homedir } from "node:os";
import { createInterface } from "node:readline";
import { createReadStream } from "node:fs";

// ---------------------------------------------------------------------------
// Cost model (verbatim from the binary: sL_ / iL_)
// ---------------------------------------------------------------------------

/** modelTier: fable=10, opus=5, haiku=1, default=3 (binary: iL_) */
function modelTier(model) {
  if (!model) return 3;
  const t = model.toLowerCase();
  if (t.includes("fable")) return 10;
  if (t.includes("opus")) return 5;
  if (t.includes("haiku")) return 1;
  return 3;
}

/** synthetic cost units (binary: sL_) */
function costOf(u) {
  return (u.cached + u.uncached * 10 + u.cacheCreate * 12.5 + u.output * 50) * u.modelTier;
}

// Behavior thresholds (binary constants)
const WINDOW_7D_MS = 604800000; // hXd
const CACHE_MISS_TOKENS = 1e5; // RR_
const LONG_CTX_TOKENS = 150000; // LR_

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
// ---------------------------------------------------------------------------

const PROJECTS_DIR = join(homedir(), ".claude", "projects");

/** Claude encodes a cwd into a project-dir name by replacing non-alnum with '-'. */
function encodeCwd(cwd) {
  return cwd.replace(/[^a-zA-Z0-9]/g, "-");
}

/** Resolve the project transcript dir for a cwd, tolerating minor encoding drift. */
function resolveProjectDir(cwd) {
  const encoded = encodeCwd(cwd);
  const direct = join(PROJECTS_DIR, encoded);
  if (existsSync(direct)) return direct;
  return null;
}

/** All *.jsonl files in a project dir, including per-session subagents/**. */
async function transcriptFilesIn(dir) {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return [];
  }
  const files = [];
  const subdirs = [];
  for (const e of entries) {
    if (e.isFile() && extname(e.name) === ".jsonl") files.push(join(dir, e.name));
    else if (e.isDirectory()) subdirs.push(e.name);
  }
  for (const sub of subdirs) {
    const subagentsDir = join(dir, sub, "subagents");
    try {
      const nested = await readdir(subagentsDir, { recursive: true });
      for (const n of nested) {
        if (extname(n) === ".jsonl") files.push(join(subagentsDir, n));
      }
    } catch {
      /* no subagents dir */
    }
  }
  return files;
}

/** All transcript files across every project dir. */
async function allTranscriptFiles() {
  let projectDirs;
  try {
    projectDirs = await readdir(PROJECTS_DIR, { withFileTypes: true });
  } catch {
    return [];
  }
  const out = [];
  for (const d of projectDirs) {
    if (d.isDirectory()) {
      out.push(...(await transcriptFilesIn(join(PROJECTS_DIR, d.name))));
    }
  }
  return out;
}

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

/** Map a tool_result error body to one of the binary's error categories. */
function categorizeToolError(content) {
  const text =
    typeof content === "string"
      ? content
      : Array.isArray(content)
        ? content.map((c) => (typeof c === "string" ? c : (c?.text ?? ""))).join(" ")
        : "";
  const t = text.toLowerCase();
  if (t.includes("user rejected") || t.includes("user doesn't want")) return "User Rejected";
  if (
    t.includes("has been modified") ||
    t.includes("file has changed") ||
    t.includes("changed since")
  )
    return "File Changed";
  if (t.includes("too large") || t.includes("exceeds")) return "File Too Large";
  if (t.includes("no such file") || t.includes("not found") || t.includes("does not exist"))
    return "File Not Found";
  if (t.includes("string to replace") || t.includes("old_string") || t.includes("edit"))
    return "Edit Failed";
  return "Command Failed";
}

// ---------------------------------------------------------------------------
// Aggregation
// ---------------------------------------------------------------------------

function bump(map, key, amt) {
  if (key) map.set(key, (map.get(key) ?? 0) + amt);
}

function aggregate(records) {
  const seen = new Set();
  let totalCost = 0;
  let requestCount = 0;
  let cacheMissCost = 0;
  let cacheMissCount = 0;
  let longCtxCost = 0;
  let longCtxCount = 0;

  const tokens = { input: 0, output: 0, cacheCreate: 0, cacheRead: 0 };
  const byModel = new Map();
  const byAgent = new Map();
  const bySkill = new Map();
  const byPlugin = new Map();
  const byMcpServer = new Map();
  const sessions = new Map();
  const hours = new Map(); // hour-of-day (0-23) -> request count
  let mainCost = 0;
  let subCost = 0;
  let subCount = 0;

  for (const r of records) {
    if (r.uuid) {
      if (seen.has(r.uuid)) continue;
      seen.add(r.uuid);
    }
    const c = costOf(r);
    totalCost += c;
    requestCount++;

    tokens.input += r.uncached;
    tokens.output += r.output;
    tokens.cacheCreate += r.cacheCreate;
    tokens.cacheRead += r.cached;

    bump(byModel, r.model, c);

    // Attribution (binary: fXd)
    if (r.attributionAgent) bump(byAgent, r.attributionSkill ?? r.attributionAgent, c);
    else bump(bySkill, r.attributionSkill, c);
    bump(byPlugin, r.attributionPlugin, c);
    bump(byMcpServer, r.attributionMcpServer, c);

    const totalToks = r.cached + r.cacheCreate + r.uncached;
    if (r.uncached > CACHE_MISS_TOKENS) {
      cacheMissCost += c;
      cacheMissCount++;
    }
    if (totalToks > LONG_CTX_TOKENS) {
      longCtxCost += c;
      longCtxCount++;
    }

    if (r.isSubagent) {
      subCost += c;
      subCount++;
    } else {
      mainCost += c;
    }

    let s = sessions.get(r.sessionId);
    if (!s) {
      s = { cost: 0, requests: 0, subCost: 0, subCount: 0 };
      sessions.set(r.sessionId, s);
    }
    s.cost += c;
    s.requests++;
    if (r.isSubagent) {
      s.subCost += c;
      s.subCount++;
    }

    if (r.ts) {
      const hod = new Date(r.ts).getHours();
      hours.set(hod, (hours.get(hod) ?? 0) + 1);
    }
  }

  return {
    totalCost,
    requestCount,
    sessionCount: sessions.size,
    tokens,
    cacheMiss: { cost: cacheMissCost, count: cacheMissCount },
    longContext: { cost: longCtxCost, count: longCtxCount },
    mainCost,
    subagent: { cost: subCost, count: subCount },
    byModel: pctList(byModel, totalCost),
    byAgent: pctList(byAgent, totalCost),
    bySkill: pctList(bySkill, totalCost),
    byPlugin: pctList(byPlugin, totalCost),
    byMcpServer: pctList(byMcpServer, totalCost),
    sessions,
    hours,
  };
}

/** Sort a name->cost map descending, attach integer percentages. */
function pctList(map, total) {
  if (map.size === 0 || total === 0) return [];
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([name, cost]) => ({
      name,
      cost: Math.round(cost),
      pct: Math.round((cost / total) * 100),
    }))
    .filter((r) => r.pct > 0);
}

function mergeCounts(target, source) {
  for (const [k, v] of source) target.set(k, (target.get(k) ?? 0) + v);
}

function mapToSortedList(map) {
  return [...map.entries()].sort((a, b) => b[1] - a[1]).map(([name, count]) => ({ name, count }));
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
    .sort((a, b) => b[1].cost - a[1].cost)
    .slice(0, 20)
    .map(([id, s]) => ({
      sessionId: id,
      cost: Math.round(s.cost),
      requests: s.requests,
      subagentCost: Math.round(s.subCost),
      subagentRequests: s.subCount,
    }));

  const result = {
    scope,
    generatedAt: new Date().toISOString(),
    note: "Cost is in the binary's synthetic units, NOT USD. Model tiers: fable=10, opus=5, haiku=1, default=3. Weighting: cache_read×1, input×10, cache_creation×12.5, output×50.",
    totals: {
      requestCount: agg.requestCount,
      sessionCount: agg.sessionCount,
      cost: Math.round(agg.totalCost),
      tokens: agg.tokens,
      totalTokens:
        agg.tokens.input + agg.tokens.output + agg.tokens.cacheCreate + agg.tokens.cacheRead,
    },
    split: {
      mainCost: Math.round(agg.mainCost),
      subagentCost: Math.round(agg.subagent.cost),
      subagentRequests: agg.subagent.count,
      mainPct: agg.totalCost ? Math.round((agg.mainCost / agg.totalCost) * 100) : 0,
      subagentPct: agg.totalCost ? Math.round((agg.subagent.cost / agg.totalCost) * 100) : 0,
    },
    behaviors: {
      cacheMiss: { cost: Math.round(agg.cacheMiss.cost), count: agg.cacheMiss.count },
      longContext: { cost: Math.round(agg.longContext.cost), count: agg.longContext.count },
    },
    byModel: agg.byModel,
    byTool: mapToSortedList(toolUses),
    toolErrors: mapToSortedList(toolErrors),
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
  L.push("═══ Claude Code Usage ═══");
  L.push(`scope: ${r.scope}`);
  L.push("");
  L.push(
    `Requests: ${r.totals.requestCount}   Sessions: ${r.totals.sessionCount}   Cost (units): ${r.totals.cost.toLocaleString()}`,
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
    L.push("By model (share of cost):");
    for (const m of r.byModel) L.push(`  ${bar(m.pct)} ${String(m.pct).padStart(3)}%  ${m.name}`);
    L.push("");
  }
  if (r.byTool.length) {
    L.push("Top tools (by invocation):");
    for (const tt of r.byTool.slice(0, 12)) L.push(`  ${String(tt.count).padStart(5)}  ${tt.name}`);
    L.push("");
  }
  if (r.byAgent.length) {
    L.push("By sub-agent (share of cost):");
    for (const a of r.byAgent) L.push(`  ${String(a.pct).padStart(3)}%  ${a.name}`);
    L.push("");
  }
  if (r.bySkill.length) {
    L.push("By skill (share of cost):");
    for (const s of r.bySkill) L.push(`  ${String(s.pct).padStart(3)}%  ${s.name}`);
    L.push("");
  }
  if (r.byMcpServer.length) {
    L.push("By MCP server (share of cost):");
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
