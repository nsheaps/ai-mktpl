#!/usr/bin/env node
// collect-insights-data.mjs — standalone re-implementation of the deterministic
// half of Claude Code's built-in `/insights` report, reverse-engineered from the
// CLI binary.
//
// Scans session transcript JSONL under ~/.claude/projects/<encoded-cwd>/*.jsonl
// (plus each session's subagents/**/*.jsonl) and computes every number the
// report needs WITHOUT an LLM: message / line / file / day counts, top tools,
// tool-error categories, languages, user-response-time distribution, the
// 24-bucket UTC time-of-day histogram, and multi-clauding (overlapping session)
// detection.
//
// It ALSO emits a compact per-session summary array. The `/insights` skill feeds
// those summaries through the LLM prompts in ../assets/prompts/ (facets.md +
// the seven section prompts); render-insights.mjs then merges this JSON with the
// LLM output into ../assets/insights-template.html.
//
// Usage:
//   node collect-insights-data.mjs [options]
//     --all                scan ALL projects (default)
//     --project-dir <dir>  scan a single project transcript dir
//     --session <id>       only this sessionId
//     --file <path>        parse a single transcript file
//     --days <n>           only messages from the last <n> days (default 30)
//     --all-time           no day limit
//     --max-sessions <n>   cap the per-session summary array (default 60)
//     --json               (default) emit the JSON blob on stdout
//
// Output: a single JSON object on stdout; a short human summary on stderr.

import { basename } from "node:path";
import { createInterface } from "node:readline";
import { createReadStream } from "node:fs";
import {
  resolveProjectDir,
  transcriptFilesIn,
  allTranscriptFiles,
  categorizeToolError,
  bump,
  mapToSortedList,
} from "./lib/transcripts.mjs";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const DEFAULT_DAYS = 30;
const DEFAULT_MAX_SESSIONS = 60;
const PROMPT_TRUNC = 240; // per-message char cap in session summaries
const MAX_PROMPTS_PER_SESSION = 18;

// Response-time buckets (seconds). Upper-exclusive; last is a catch-all.
const RESPONSE_BUCKETS = [
  { label: "<5s", max: 5 },
  { label: "5-15s", max: 15 },
  { label: "15-30s", max: 30 },
  { label: "30-60s", max: 60 },
  { label: "1-2m", max: 120 },
  { label: "2-5m", max: 300 },
  { label: "5-15m", max: 900 },
  { label: ">15m", max: Infinity },
];

// File-extension → language label.
const LANG_BY_EXT = {
  ts: "typescript",
  tsx: "typescript",
  mts: "typescript",
  cts: "typescript",
  js: "javascript",
  jsx: "javascript",
  mjs: "javascript",
  cjs: "javascript",
  py: "python",
  rb: "ruby",
  go: "go",
  rs: "rust",
  java: "java",
  kt: "kotlin",
  c: "c",
  h: "c",
  cc: "cpp",
  cpp: "cpp",
  cxx: "cpp",
  hpp: "cpp",
  cs: "csharp",
  swift: "swift",
  m: "objective-c",
  scala: "scala",
  php: "php",
  pl: "perl",
  lua: "lua",
  r: "r",
  jl: "julia",
  dart: "dart",
  sh: "shell",
  bash: "shell",
  zsh: "shell",
  fish: "shell",
  sql: "sql",
  html: "html",
  css: "css",
  scss: "scss",
  sass: "scss",
  less: "less",
  vue: "vue",
  svelte: "svelte",
  ex: "elixir",
  exs: "elixir",
  erl: "erlang",
  clj: "clojure",
  hs: "haskell",
  ml: "ocaml",
  nim: "nim",
  zig: "zig",
  json: "json",
  yaml: "yaml",
  yml: "yaml",
  toml: "toml",
  xml: "xml",
  md: "markdown",
  tf: "terraform",
  dockerfile: "docker",
  gradle: "gradle",
};

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const opts = {
    all: false,
    projectDir: null,
    session: null,
    file: null,
    days: DEFAULT_DAYS,
    allTime: false,
    maxSessions: DEFAULT_MAX_SESSIONS,
  };
  let scopeGiven = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--all") {
      opts.all = true;
      scopeGiven = true;
    } else if (a === "--project-dir") {
      opts.projectDir = argv[++i];
      scopeGiven = true;
    } else if (a === "--session") {
      opts.session = argv[++i];
      scopeGiven = true;
    } else if (a === "--file") {
      opts.file = argv[++i];
      scopeGiven = true;
    } else if (a === "--days") opts.days = Number(argv[++i]);
    else if (a === "--all-time") opts.allTime = true;
    else if (a === "--max-sessions") opts.maxSessions = Number(argv[++i]);
    else if (a === "--json") {
      /* default */
    }
  }
  if (!scopeGiven) opts.all = true;
  return opts;
}

// ---------------------------------------------------------------------------
// Helpers
//
// resolveProjectDir / transcriptFilesIn / allTranscriptFiles / bump /
// categorizeToolError / mapToSortedList live in ./lib/transcripts.mjs — every
// collector walks the same tree and counts the same way.
// ---------------------------------------------------------------------------

function countNewlines(s) {
  if (typeof s !== "string" || s.length === 0) return 0;
  let n = 1; // a non-empty string is at least one line
  for (let i = 0; i < s.length; i++) if (s.charCodeAt(i) === 10) n++;
  return n;
}

function extOf(path) {
  const base = basename(String(path)).toLowerCase();
  if (base === "dockerfile") return "dockerfile";
  const dot = base.lastIndexOf(".");
  return dot > 0 ? base.slice(dot + 1) : "";
}

/** Flatten a message.content into plain text. */
function textOf(content) {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((b) => {
        if (typeof b === "string") return b;
        if (b && b.type === "text") return b.text ?? "";
        return "";
      })
      .join(" ")
      .trim();
  }
  return "";
}

function isSlashOrMeta(text) {
  const t = text.trim();
  // Skip local command echoes and system-injected wrappers.
  return (
    t.startsWith("<command-") ||
    t.startsWith("<local-command") ||
    t.startsWith("Caveat:") ||
    t.startsWith("[Request interrupted")
  );
}

// ---------------------------------------------------------------------------
// Per-file parse
// ---------------------------------------------------------------------------

/**
 * Parse one transcript file, folding events into `sessions` (a Map keyed by
 * sessionId) and global counters. `sinceMs` filters by timestamp.
 */
async function parseFile(path, { sinceMs, sessionFilter, sessions, global }) {
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
    const sessionId = obj.sessionId ?? "";
    if (!sessionId) continue;
    if (sessionFilter && sessionId !== sessionFilter) continue;

    const ts = obj.timestamp ? Date.parse(obj.timestamp) : NaN;
    if (!Number.isNaN(ts) && sinceMs && ts < sinceMs) continue;

    const msg = obj.message;
    if (!msg) continue;

    let s = sessions.get(sessionId);
    if (!s) {
      s = {
        sessionId,
        cwd: obj.cwd ?? "",
        firstTs: Infinity,
        lastTs: -Infinity,
        userMessages: 0,
        assistantMessages: 0,
        tools: new Map(),
        files: new Set(),
        prompts: [],
        // transient: timestamp of the assistant turn most recently finished,
        // used to measure the user's response latency.
        pendingAssistantEndTs: null,
      };
      sessions.set(sessionId, s);
    }
    if (!Number.isNaN(ts)) {
      if (ts < s.firstTs) s.firstTs = ts;
      if (ts > s.lastTs) s.lastTs = ts;
    }

    // ---- User messages ----
    if (msg.role === "user") {
      // A user message is either a real prompt (text) or automated tool_result(s).
      const hasToolResult =
        Array.isArray(msg.content) && msg.content.some((b) => b && b.type === "tool_result");

      if (hasToolResult) {
        for (const block of msg.content) {
          if (block && block.type === "tool_result" && block.is_error) {
            bump(global.toolErrors, categorizeToolError(block.content));
          }
        }
      } else {
        const text = textOf(msg.content);
        if (text && !isSlashOrMeta(text)) {
          s.userMessages++;
          global.userMessages++;
          if (!Number.isNaN(ts)) {
            const hour = new Date(ts).getUTCHours();
            global.timeOfDayUTC[hour]++;
            // Response latency: gap since the assistant last finished a turn.
            if (s.pendingAssistantEndTs != null) {
              const secs = (ts - s.pendingAssistantEndTs) / 1000;
              if (secs >= 0 && secs < 6 * 3600) global.responseTimes.push(secs);
              s.pendingAssistantEndTs = null;
            }
          }
          if (s.prompts.length < MAX_PROMPTS_PER_SESSION) {
            s.prompts.push(text.replace(/\s+/g, " ").slice(0, PROMPT_TRUNC));
          }
        }
      }
      continue;
    }

    // ---- Assistant messages ----
    if (msg.role === "assistant") {
      s.assistantMessages++;
      global.assistantMessages++;
      if (!Number.isNaN(ts)) s.pendingAssistantEndTs = ts;

      if (Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (!block || block.type !== "tool_use" || !block.name) continue;
          bump(s.tools, block.name);
          bump(global.tools, block.name);
          const inp = block.input || {};

          // File attribution + line counting.
          const fp = inp.file_path || inp.notebook_path;
          if (fp) {
            s.files.add(fp);
            global.files.add(fp);
            const ext = extOf(fp);
            const lang = LANG_BY_EXT[ext];
            if (lang) bump(global.languages, lang);
          }
          if (block.name === "Write" && typeof inp.content === "string") {
            global.linesAdded += countNewlines(inp.content);
          } else if (block.name === "Edit" && typeof inp.new_string === "string") {
            global.linesAdded += Math.max(
              0,
              countNewlines(inp.new_string) - countNewlines(inp.old_string),
            );
          } else if (block.name === "MultiEdit" && Array.isArray(inp.edits)) {
            for (const ed of inp.edits) {
              global.linesAdded += Math.max(
                0,
                countNewlines(ed?.new_string) - countNewlines(ed?.old_string),
              );
            }
          }
        }
      }
      continue;
    }
  }
}

// ---------------------------------------------------------------------------
// Aggregation
// ---------------------------------------------------------------------------

function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
}

function responseTimeStats(times) {
  const sorted = [...times].sort((a, b) => a - b);
  const median = percentile(sorted, 50);
  const average = sorted.length ? sorted.reduce((a, b) => a + b, 0) / sorted.length : 0;
  const buckets = RESPONSE_BUCKETS.map((b) => ({ label: b.label, count: 0 }));
  for (const t of sorted) {
    for (let i = 0; i < RESPONSE_BUCKETS.length; i++) {
      if (t < RESPONSE_BUCKETS[i].max) {
        buckets[i].count++;
        break;
      }
    }
  }
  return {
    count: sorted.length,
    median: Math.round(median * 10) / 10,
    average: Math.round(average * 10) / 10,
    buckets,
  };
}

/**
 * Multi-clauding: how often sessions overlapped in time (parallel Claudes).
 * Sweep-line over [start,end] intervals to find the max concurrency and the
 * number of sessions that overlapped at least one other.
 */
function multiClauding(sessions) {
  const intervals = [];
  for (const s of sessions) {
    if (Number.isFinite(s.firstTs) && Number.isFinite(s.lastTs) && s.lastTs > s.firstTs) {
      intervals.push([s.firstTs, s.lastTs]);
    }
  }
  const events = [];
  for (const [a, b] of intervals) {
    events.push([a, 1]);
    events.push([b, -1]);
  }
  events.sort((x, y) => x[0] - y[0] || x[1] - y[1]);
  let cur = 0;
  let max = 0;
  for (const [, d] of events) {
    cur += d;
    if (cur > max) max = cur;
  }
  // Count sessions that overlap at least one other.
  let overlapping = 0;
  for (let i = 0; i < intervals.length; i++) {
    for (let j = 0; j < intervals.length; j++) {
      if (i === j) continue;
      if (intervals[i][0] < intervals[j][1] && intervals[j][0] < intervals[i][1]) {
        overlapping++;
        break;
      }
    }
  }
  return {
    sessionsWithTiming: intervals.length,
    maxConcurrent: max,
    overlappingSessions: overlapping,
    everParallel: max > 1,
  };
}

function distinctDays(sessions) {
  const days = new Set();
  for (const s of sessions) {
    if (!Number.isFinite(s.firstTs)) continue;
    const d = new Date(s.firstTs);
    days.add(`${d.getUTCFullYear()}-${d.getUTCMonth()}-${d.getUTCDate()}`);
    if (Number.isFinite(s.lastTs)) {
      const d2 = new Date(s.lastTs);
      days.add(`${d2.getUTCFullYear()}-${d2.getUTCMonth()}-${d2.getUTCDate()}`);
    }
  }
  return days.size;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  let sinceMs = null;
  if (!opts.allTime && typeof opts.days === "number" && !Number.isNaN(opts.days)) {
    sinceMs = Date.now() - opts.days * 86400000;
  }

  let files = [];
  let scope;
  if (opts.file) {
    files = [opts.file];
    scope = `file:${basename(opts.file)}`;
  } else if (opts.projectDir) {
    files = await transcriptFilesIn(opts.projectDir);
    scope = `project:${basename(opts.projectDir)}`;
  } else if (opts.session) {
    files = await allTranscriptFiles();
    scope = `session:${opts.session}`;
  } else {
    files = await allTranscriptFiles();
    scope = opts.allTime ? "all-projects-all-time" : `all-projects-${opts.days}d`;
  }

  if (files.length === 0) {
    const projectDir = resolveProjectDir(process.cwd());
    if (projectDir) {
      files = await transcriptFilesIn(projectDir);
      scope = `current-project:${basename(projectDir)}`;
    }
  }

  const sessions = new Map();
  const global = {
    userMessages: 0,
    assistantMessages: 0,
    linesAdded: 0,
    tools: new Map(),
    files: new Set(),
    languages: new Map(),
    toolErrors: new Map(),
    timeOfDayUTC: new Array(24).fill(0),
    responseTimes: [],
  };

  for (const f of files) {
    try {
      await parseFile(f, { sinceMs, sessionFilter: opts.session, sessions, global });
    } catch {
      /* skip unreadable file */
    }
  }

  const sessionArr = [...sessions.values()];

  if (sessionArr.length === 0) {
    const empty = {
      scope,
      generatedAt: new Date().toISOString(),
      error: "no_sessions",
      note: "No transcripts matched the requested scope/window.",
      deterministic: {
        messages: 0,
        userMessages: 0,
        assistantMessages: 0,
        linesAdded: 0,
        filesTouched: 0,
        days: 0,
        msgsPerDay: 0,
        sessionCount: 0,
        topTools: [],
        toolErrors: [],
        languages: [],
        timeOfDayUTC: global.timeOfDayUTC,
        responseTimes: responseTimeStats([]),
        multiClauding: multiClauding([]),
      },
      sessions: [],
    };
    process.stdout.write(JSON.stringify(empty, null, 2) + "\n");
    process.stderr.write(`insights: no sessions found for scope ${scope}\n`);
    return;
  }

  const days = Math.max(1, distinctDays(sessionArr));
  const totalMessages = global.userMessages + global.assistantMessages;

  // Compact per-session summaries for the LLM passes, most-recent first.
  const summaries = sessionArr
    .filter((s) => s.userMessages > 0)
    .sort((a, b) => (b.lastTs || 0) - (a.lastTs || 0))
    .slice(0, opts.maxSessions)
    .map((s) => ({
      session_id: s.sessionId,
      cwd: s.cwd,
      started: Number.isFinite(s.firstTs) ? new Date(s.firstTs).toISOString() : null,
      ended: Number.isFinite(s.lastTs) ? new Date(s.lastTs).toISOString() : null,
      durationMinutes:
        Number.isFinite(s.firstTs) && Number.isFinite(s.lastTs)
          ? Math.round((s.lastTs - s.firstTs) / 60000)
          : 0,
      userMessageCount: s.userMessages,
      assistantMessageCount: s.assistantMessages,
      topTools: mapToSortedList(s.tools, 8),
      filesTouched: [...s.files].slice(0, 25),
      prompts: s.prompts,
    }));

  const result = {
    scope,
    generatedAt: new Date().toISOString(),
    note:
      "Deterministic half of the /insights report. Facet/section fields are filled " +
      "by the LLM passes in ../assets/prompts and merged by render-insights.mjs.",
    deterministic: {
      messages: totalMessages,
      userMessages: global.userMessages,
      assistantMessages: global.assistantMessages,
      linesAdded: global.linesAdded,
      filesTouched: global.files.size,
      days,
      msgsPerDay: Math.round(totalMessages / days),
      sessionCount: sessionArr.length,
      topTools: mapToSortedList(global.tools, 12),
      toolErrors: mapToSortedList(global.toolErrors),
      languages: mapToSortedList(global.languages, 10),
      timeOfDayUTC: global.timeOfDayUTC,
      responseTimes: responseTimeStats(global.responseTimes),
      multiClauding: multiClauding(sessionArr),
    },
    sessions: summaries,
  };

  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
  process.stderr.write(
    `insights: ${scope} — ${sessionArr.length} sessions, ${totalMessages} messages, ` +
      `${global.files.size} files, ${global.linesAdded} lines, ${days} days ` +
      `(${summaries.length} session summaries emitted)\n`,
  );
}

main().catch((err) => {
  process.stderr.write(`collect-insights-data failed: ${err?.stack ?? err}\n`);
  process.exitCode = 1;
});
