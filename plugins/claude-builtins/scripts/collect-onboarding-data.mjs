#!/usr/bin/env node
// collect-onboarding-data.mjs — the data-collection half of Claude Code's
// built-in `/team-onboarding`, extracted from the CLI binary (v2.1.225).
//
// Scans session transcript JSONL under ~/.claude/projects/<encoded-cwd>/*.jsonl
// for the current repo and summarizes HOW the user has worked in Claude Code
// over a recent window: which slash commands they run, which MCP servers they
// call, and a set of "session descriptors" (title, linked PRs, first user
// message) that a model can classify into work-type buckets.
//
// NOTE: descriptors are *not* redacted or scrubbed for secrets. The first user
// message is only truncated (to FIRST_MSG_SLICE chars) and the descriptor list
// is capped (at MAX_DESCRIPTORS) — whatever you typed is what gets emitted, so
// review the output before pasting it anywhere public.
//
// The output feeds assets/prompts/team-onboarding.md, which turns it into an
// ONBOARDING.md guide for teammates new to Claude Code.
//
// Usage:
//   node collect-onboarding-data.mjs [options]
//     --days <n> / --window <n>   window in days to scan (default: 30)
//     --project-dir <dir>         project transcript dir (default: derived from $PWD)
//     --json                      emit only the JSON blob (no human summary)
//
// Output: a human-readable summary on stderr and a single `usageData` JSON
// object on stdout (2-space indented), matching the built-in's shape.

import { readdir, stat, readFile } from "node:fs/promises";
import { join, basename } from "node:path";
import { execFileSync } from "node:child_process";
import { PROJECTS_DIR, resolveProjectDir } from "./lib/transcripts.mjs";

// Behavior constants (verbatim from the binary).
const DEFAULT_WINDOW_DAYS = 30; // default scan window
const MAX_FILE_BYTES = 52428800; // 50 MiB — skip transcript files larger than this
const FIRST_MSG_SLICE = 200; // truncate first user message to this many chars
const MAX_DESCRIPTORS = 60; // cap on retained session descriptors

// Line-scan markers (cheap substring guards before the regexes run).
const MARK_SLASH_NAME = '"content":"<command-name>/';
const MARK_SLASH_MSG = '"content":"<command-message>';
const MARK_TOOL_USE = '"type":"tool_use"';
const MARK_MCP_NAME = '"name":"mcp__';
const MARK_CUSTOM_TITLE = '"type":"custom-title"';
const MARK_PR_LINK = '"type":"pr-link"';
const MARK_USER_ROLE = '"role":"user"';
const MARK_CONTENT_ARRAY = '"content":[';

// Extraction regexes (binary: CP_/xP_/DP_/PP_/MP_).
const RE_SLASH_CMD = /<command-name>\/([\w:-]+)<\/command-name>/g;
const RE_MCP_CALL = /"name":"mcp__([^"]+?)__([^"]+)"/g;
const RE_CUSTOM_TITLE = /"customTitle":"([^"]+)"/;
const RE_PR_NUMBER = /"prNumber":(\d+)/;
const RE_FIRST_MSG = /"role":"user"[^}]*"content":"([^"]+)"/;

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const opts = { windowDays: DEFAULT_WINDOW_DAYS, projectDir: null, jsonOnly: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--days" || a === "--window") {
      const n = Number(argv[++i]);
      if (!Number.isNaN(n) && n > 0) opts.windowDays = n;
    } else if (a === "--project-dir") opts.projectDir = argv[++i];
    else if (a === "--json") opts.jsonOnly = true;
  }
  return opts;
}

// ---------------------------------------------------------------------------
// Session scanner (binary: lep)
//
// PROJECTS_DIR / resolveProjectDir live in ./lib/transcripts.mjs — every
// collector resolves the same tree. This one keeps its own scanner because it
// reads whole files and only walks the top level (no subagents/**).
// ---------------------------------------------------------------------------

/**
 * Scan every top-level transcript file in `dir` modified within `windowDays`,
 * accumulating slash-command counts, MCP-server call counts, and one descriptor
 * per session (title / linked PRs / first user message). Returns
 * { slashCounts: Map, mcpCounts: Map, sessionDescriptors: [...], sessionFileCount }.
 */
async function scanSessions(dir, windowDays) {
  const cutoff = Date.now() - windowDays * 86400000;
  const slashCounts = new Map();
  const mcpCounts = new Map();
  const sessionDescriptors = [];
  let sessionFileCount = 0;

  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return { slashCounts, mcpCounts, sessionDescriptors, sessionFileCount };
  }

  for (const e of entries) {
    if (!e.isFile() || !e.name.endsWith(".jsonl")) continue;
    const path = join(dir, e.name);

    let st;
    try {
      st = await stat(path);
    } catch {
      continue;
    }
    if (!st.isFile() || st.mtimeMs < cutoff || st.size > MAX_FILE_BYTES) continue;

    let text;
    try {
      text = await readFile(path, "utf8");
    } catch {
      continue;
    }
    sessionFileCount++;

    const c = { prNumbers: [] };
    for (const line of text.split("\n")) {
      if (line.length < 10) continue;

      // Slash commands.
      if (line.includes(MARK_SLASH_NAME) || line.includes(MARK_SLASH_MSG)) {
        for (const m of line.matchAll(RE_SLASH_CMD)) {
          const name = m[1];
          slashCounts.set(name, (slashCounts.get(name) ?? 0) + 1);
        }
      }

      // MCP tool calls.
      if (line.includes(MARK_TOOL_USE) && line.includes(MARK_MCP_NAME)) {
        for (const m of line.matchAll(RE_MCP_CALL)) {
          const server = m[1];
          mcpCounts.set(server, (mcpCounts.get(server) ?? 0) + 1);
        }
      }

      // Custom session title.
      if (line.includes(MARK_CUSTOM_TITLE)) {
        const m = line.match(RE_CUSTOM_TITLE);
        if (m) c.title = m[1];
      }

      // PR link.
      if (line.includes(MARK_PR_LINK)) {
        const m = line.match(RE_PR_NUMBER);
        if (m) {
          const n = Number(m[1]);
          if (!c.prNumbers.includes(n)) c.prNumbers.push(n);
        }
      }

      // First user message (not a slash command, not a structured content array).
      if (
        !c.firstMessage &&
        line.includes(MARK_USER_ROLE) &&
        !line.includes(MARK_SLASH_NAME) &&
        !line.includes(MARK_CONTENT_ARRAY)
      ) {
        const m = line.match(RE_FIRST_MSG);
        if (m) {
          const raw = m[1].replace(/\\n/g, " ").replace(/\\"/g, '"');
          if (raw.length > 3 && !raw.startsWith("<")) {
            c.firstMessage = raw.slice(0, FIRST_MSG_SLICE);
          }
        }
      }
    }

    if (c.title || c.prNumbers.length || c.firstMessage) sessionDescriptors.push(c);
  }

  // Keep the most informative descriptors if there are too many.
  if (sessionDescriptors.length > MAX_DESCRIPTORS) {
    sessionDescriptors.sort(
      (a, b) =>
        (b.title ? 2 : 0) +
        (b.prNumbers.length ? 1 : 0) -
        ((a.title ? 2 : 0) + (a.prNumbers.length ? 1 : 0)),
    );
    sessionDescriptors.length = MAX_DESCRIPTORS;
  }

  return { slashCounts, mcpCounts, sessionDescriptors, sessionFileCount };
}

// ---------------------------------------------------------------------------
// Helpers (binary: $P_ / NP_)
// ---------------------------------------------------------------------------

/** Origin of a URL, or undefined if it doesn't parse. */
function originOf(url) {
  try {
    return new URL(url).origin;
  } catch {
    return undefined;
  }
}

/** Read `.mcp.json` in `dir` and return its mcpServers map (or {}). */
async function readMcpServers(dir) {
  try {
    const raw = await readFile(join(dir, ".mcp.json"), "utf8");
    const parsed = JSON.parse(raw);
    return parsed.mcpServers ?? {};
  } catch (err) {
    if (err && err.code !== "ENOENT") {
      process.stderr.write(`collect-onboarding-data: failed to read .mcp.json: ${err.message}\n`);
    }
    return {};
  }
}

/** Best-effort `git config` / `git remote` read; returns "" on any failure. */
function gitRead(args, cwd) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8" }).trim();
  } catch {
    return "";
  }
}

/** Derive an "owner/repo" slug from a git remote URL. */
function repoSlug(remote) {
  if (!remote) return undefined;
  const m = remote.match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?\/?$/);
  return m ? m[1] : undefined;
}

// ---------------------------------------------------------------------------
// Main (binary: FP_)
// ---------------------------------------------------------------------------

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const cwd = process.cwd();
  const windowDays = opts.windowDays;

  const projectDir = opts.projectDir ?? resolveProjectDir(cwd);
  if (!projectDir) {
    process.stderr.write(
      `No project transcript dir found for ${cwd}.\n` +
        `Looked in ${PROJECTS_DIR}. Run this from a directory you've used with Claude Code.\n`,
    );
    process.stdout.write(JSON.stringify({ error: "no_project_dir" }, null, 2) + "\n");
    return;
  }

  const { slashCounts, mcpCounts, sessionDescriptors, sessionFileCount } = await scanSessions(
    projectDir,
    windowDays,
  );

  const slashCommands = [...slashCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([cmd, count]) => ({ name: "/" + cmd, count }));

  const mcpConfig = await readMcpServers(cwd);
  const mcpServers = [...mcpCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([name, callCount]) => {
      const cfg = mcpConfig[name];
      const urlOrigin = cfg && typeof cfg.url === "string" ? originOf(cfg.url) : undefined;
      return { name, callCount, urlOrigin };
    });

  const generatedBy = gitRead(["config", "user.name"], cwd) || undefined;
  const originUrl = gitRead(["remote", "get-url", "origin"], cwd);
  const currentRepo = repoSlug(originUrl) ?? basename(cwd);

  const usageData = {
    generatedBy,
    currentRepo,
    windowDays,
    sessionCount: sessionFileCount,
    slashCommands,
    mcpServers,
    sessionDescriptors,
  };

  if (!opts.jsonOnly) {
    process.stderr.write(renderSummary(usageData));
  }
  process.stdout.write(JSON.stringify(usageData, null, 2) + "\n");
}

function renderSummary(u) {
  const L = [];
  L.push("");
  L.push("═══ Team Onboarding — usage scan ═══");
  L.push(`repo: ${u.currentRepo}${u.generatedBy ? `   by: ${u.generatedBy}` : ""}`);
  L.push(`window: last ${u.windowDays} days   sessions scanned: ${u.sessionCount}`);
  L.push("");
  if (u.slashCommands.length) {
    L.push("Top slash commands:");
    for (const s of u.slashCommands.slice(0, 12)) {
      L.push(`  ${String(s.count).padStart(5)}  ${s.name}`);
    }
    L.push("");
  }
  if (u.mcpServers.length) {
    L.push("MCP servers called:");
    for (const s of u.mcpServers.slice(0, 12)) {
      L.push(
        `  ${String(s.callCount).padStart(5)}  ${s.name}${s.urlOrigin ? `  (${s.urlOrigin})` : ""}`,
      );
    }
    L.push("");
  }
  L.push(`Session descriptors retained: ${u.sessionDescriptors.length}`);
  L.push("");
  return L.join("\n") + "\n";
}

main().catch((err) => {
  process.stderr.write(`collect-onboarding-data failed: ${err?.stack ?? err}\n`);
  process.exitCode = 1;
});
