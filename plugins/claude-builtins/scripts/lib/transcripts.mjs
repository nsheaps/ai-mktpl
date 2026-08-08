// ---------------------------------------------------------------------------
// Shared transcript-discovery and counting helpers.
//
// Claude Code writes one JSONL transcript per session under
// $CLAUDE_CONFIG_DIR/projects/<encoded-cwd>/ (default ~/.claude/projects/),
// plus nested subagent transcripts under <session-id>/subagents/**. Every
// collector in this plugin walks the same tree, so the walk lives here
// rather than being copy-pasted three times.
//
// Plain ESM, no dependencies — run with `node` or `bun`.
// ---------------------------------------------------------------------------

import { readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, extname } from "node:path";
import { homedir } from "node:os";

/** Root of Claude Code's per-project transcript storage. */
// Mirrors the binary's `S2() = join(Ln(), "projects")`, where
// `Ln() = $CLAUDE_CONFIG_DIR ?? ~/.claude` (v2.1.226 @267685164/@267687171) —
// the same accessor probe-agent-messaging.mjs:44 uses for `teams/`. Getting
// this wrong doesn't error: a missing root hits the "no transcripts" empty
// state below, so every collector would silently emit a complete,
// zero-everything report instead of telling the user why.
export const PROJECTS_DIR = join(
  process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude"),
  "projects",
);

/**
 * Claude encodes a cwd into a project-dir name by replacing non-alnum with '-'.
 *
 * KNOWN GAP: this is the binary's inner `bes()`. The dir name actually comes
 * from `gA()` (v2.1.226 @268529082), which truncates at 200 chars and appends
 * `-<base36 hash>` past that — so a cwd whose sanitized form exceeds 200 chars
 * resolves to null here. Port `gA`/`Idt` on the next extraction pass.
 */
export function encodeCwd(cwd) {
  return cwd.replace(/[^a-zA-Z0-9]/g, "-");
}

/** Resolve the project transcript dir for a cwd, or null when there is none. */
export function resolveProjectDir(cwd) {
  const direct = join(PROJECTS_DIR, encodeCwd(cwd));
  return existsSync(direct) ? direct : null;
}

/**
 * Distinguish "no transcripts to scan" from "misconfigured": the first is a
 * real answer (this machine/config has none), the second — PROJECTS_DIR
 * itself doesn't exist — usually means CLAUDE_CONFIG_DIR points somewhere
 * unexpected. Both collectors report zero results the same way otherwise, so
 * this is what lets the stderr note tell them apart.
 */
export function projectsDirExists() {
  return existsSync(PROJECTS_DIR);
}

/**
 * All *.jsonl files in a project dir, including per-session subagents/**.
 * Unreadable dirs yield [] rather than throwing — a missing or permission-denied
 * project dir is a normal empty state, not an error.
 */
export async function transcriptFilesIn(dir) {
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
export async function allTranscriptFiles() {
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

/**
 * Bucket a tool_result error into one of the built-in report's error
 * categories. `content` is a raw transcript content field: a string, or an
 * array of content blocks, or something else entirely.
 */
export function categorizeToolError(content) {
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

/** Add `amt` to `map[key]`, ignoring empty/absent keys. */
export function bump(map, key, amt = 1) {
  if (key === undefined || key === null || key === "") return;
  map.set(key, (map.get(key) ?? 0) + amt);
}

/** Fold `source` counts into `target` in place. */
export function mergeCounts(target, source) {
  for (const [k, v] of source) target.set(k, (target.get(k) ?? 0) + v);
}

/** Map -> [{ name, count }] sorted by count desc, optionally capped. */
export function mapToSortedList(map, limit = Infinity) {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([name, count]) => ({ name, count }));
}
