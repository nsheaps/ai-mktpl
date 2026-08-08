#!/usr/bin/env node
// probe-agent-messaging.mjs — read-only inspector for Claude Code's teammate
// mailbox, the file-backed transport used between agent-team sessions.
//
// Extracted from the CLI binary (v2.1.226). The path is built by:
//
//   function MWt(e, t) {                        // getInboxPath(agent, team)
//     let r = t || qm() || "default",           // team ?? currentTeam() ?? "default"
//         i = join(VOt(), slug(r), "inboxes"),
//         s = join(i, `${slug(e)}.json`);
//     return s
//   }
//   function VOt(){ return join(homeClaudeDir(), "teams") }
//
// => ~/.claude/teams/<team>/inboxes/<agent>.json
//
// IMPORTANT — what this is NOT for. Writing into these files does NOT reach an
// in-process subagent (one spawned via the Agent tool). That was tested: a
// schema-valid message written to the path above was never delivered and its
// `read` flag stayed false, while the same message sent with the SendMessage
// tool arrived and resumed the idle agent. SendMessage to a subagent never
// touches the filesystem at all. See skills/agent-messaging/SKILL.md.
//
// This script only reports state. It does not write, and deliberately offers no
// send mode: the supported way to message an agent is the SendMessage tool, and
// the supported way to message a session is the Claude Code Remote MCP tools.
//
// Usage:
//   node probe-agent-messaging.mjs              # inspect every team + inbox
//   node probe-agent-messaging.mjs --team <name>
//   node probe-agent-messaging.mjs --json
//
// Exit codes: 0 always (absence of a mailbox is a normal state, not an error).

import { homedir } from "node:os";
import { join } from "node:path";
import { readdir, readFile, stat } from "node:fs/promises";

// Required keys on a mailbox entry, per the binary's schema. A message missing
// any of these is refused on write and dropped (and pruned) on read.
const REQUIRED = ["from", "text", "timestamp"];

function teamsRoot() {
  return join(process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude"), "teams");
}

function parseArgs(argv) {
  const opts = { team: null, json: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--team") opts.team = argv[++i];
    else if (argv[i] === "--json") opts.json = true;
  }
  return opts;
}

async function listDirs(dir) {
  try {
    const entries = await readdir(dir, { withFileTypes: true });
    return entries.filter((e) => e.isDirectory()).map((e) => e.name);
  } catch {
    return [];
  }
}

/** Classify one entry against the schema the runtime enforces. */
function inspectMessage(msg) {
  const missing = REQUIRED.filter((k) => typeof msg?.[k] !== "string" || msg[k] === "");
  return {
    type: msg?.type ?? "message", // absent type is read as "message"
    from: msg?.from ?? null,
    read: msg?.read === true,
    msg_id: msg?.msg_id ?? null,
    valid: missing.length === 0,
    missing,
  };
}

async function inspectInbox(path) {
  let raw;
  try {
    raw = await readFile(path, "utf8");
  } catch (err) {
    return { path, error: `unreadable: ${err.code || err.message}` };
  }
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    // The runtime treats an unparseable inbox as empty rather than crashing.
    return { path, error: `unparseable JSON (runtime treats as empty): ${err.message}` };
  }
  if (!Array.isArray(parsed)) {
    return { path, error: "not a JSON array — the runtime expects []" };
  }
  const messages = parsed.map(inspectMessage);
  let lockPresent = false;
  try {
    await stat(`${path}.lock`);
    lockPresent = true;
  } catch {
    /* no lock held, which is the normal resting state */
  }
  return {
    path,
    total: messages.length,
    unread: messages.filter((m) => !m.read).length,
    invalid: messages.filter((m) => !m.valid).length,
    lockPresent,
    messages,
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const root = teamsRoot();
  const teams = opts.team ? [opts.team] : await listDirs(root);

  const report = { teamsRoot: root, teams: [] };
  for (const team of teams) {
    const inboxDir = join(root, team, "inboxes");
    let files = [];
    try {
      files = (await readdir(inboxDir)).filter((f) => f.endsWith(".json"));
    } catch {
      continue; // team dir without an inboxes/ subdir
    }
    const inboxes = [];
    for (const file of files) {
      const info = await inspectInbox(join(inboxDir, file));
      inboxes.push({ agent: file.replace(/\.json$/, ""), ...info });
    }
    report.teams.push({ team, inboxDir, inboxes });
  }

  if (opts.json) {
    process.stdout.write(JSON.stringify(report, null, 2) + "\n");
    return;
  }

  console.log(`teams root: ${report.teamsRoot}`);
  if (report.teams.length === 0) {
    console.log("\nNo teams found. That is the normal state when you have never");
    console.log("started an agent team — in-process subagents do not use this");
    console.log("transport, so nothing here is required for SendMessage to work.");
    return;
  }
  for (const t of report.teams) {
    console.log(`\nteam: ${t.team}  (${t.inboxDir})`);
    if (t.inboxes.length === 0) console.log("  (no inboxes)");
    for (const ib of t.inboxes) {
      if (ib.error) {
        console.log(`  ${ib.agent}: ${ib.error}`);
        continue;
      }
      const lock = ib.lockPresent ? "  [LOCK HELD]" : "";
      console.log(
        `  ${ib.agent}: ${ib.total} message(s), ${ib.unread} unread, ` +
          `${ib.invalid} schema-invalid${lock}`,
      );
      for (const m of ib.messages) {
        const flag = m.valid ? (m.read ? "read" : "UNREAD") : `INVALID(${m.missing.join(",")})`;
        console.log(`      - [${m.type}] from=${m.from} ${flag}`);
      }
    }
  }
}

main().catch((err) => {
  console.error(`probe-agent-messaging: ${err.stack || err}`);
  process.exit(0); // never fail a diagnostic run
});
