---
name: agent-messaging
description: >
  Use this skill when the user asks how agents send messages to each other, how
  SendMessage reaches an idle agent, what the teammate mailbox is, where inboxes
  live on disk, how channels relate to agent-to-agent messaging, or whether an
  agent can be messaged programmatically from outside Claude Code. Records what
  was extracted from the CLI binary (v2.1.226) and — importantly — which
  mechanisms were tested and found NOT to work.
---

# Agent Messaging Mechanics

How messages reach an agent in Claude Code, extracted from the CLI binary
(v2.1.226) and verified by experiment.

Read the "What does not work" section before building anything. The obvious
mechanism — writing to the on-disk inbox — was tested and **does not** reach an
in-process subagent.

## Message sources are siblings, not layers

The binary classifies every way content can enter an agent's turn as a
_source_. From the classifier enum:

```
attachment · queued_command · task-notification · slack_bot · teammate_mailbox
outcome · tool_result · scheduled-trigger · channel · observer · unclassified
assistant · tool_use · auto_mode_classifier
```

`channel` and `teammate_mailbox` sit side by side. **Channels are not the
transport for agent-to-agent `SendMessage`** — they are a separate ingress.
Answering "how do channels relate to SendMessage" with "SendMessage goes over
channels" is wrong.

## Two distinct transports

|                             | In-process subagent                  | Teammate (agent teams)                    |
| :-------------------------- | :----------------------------------- | :---------------------------------------- |
| Spawned by                  | `Agent` tool                         | team launcher, separate session/process   |
| Transport                   | in-memory, inside the parent process | file-backed inbox under `~/.claude/teams` |
| Touches disk on send        | **no**                               | yes                                       |
| Reachable by writing a file | **no**                               | yes (in principle)                        |

This split is the whole point. A subagent shares a process with its parent, so
there is nothing to serialise; teammates are separate sessions, so they need
shared state on disk.

## The teammate mailbox (verbatim from the binary)

Path construction:

```js
function MWt(e, t) {
  // getInboxPath(agent, team)
  let r = t || qm() || "default", // team ?? currentTeam() ?? "default"
    i = MGo.join(VOt(), QGe(r), "inboxes"),
    s = MGo.join(i, `${QGe(e)}.json`);
  return s;
}
function VOt() {
  return gwe.join(Ln(), "teams");
} // ~/.claude/teams
```

→ `~/.claude/teams/<team>/inboxes/<agent>.json`

Note the `|| "default"` fallback: with no current team the path still resolves,
to a team literally named `default`. `Ln()` is `$CLAUDE_CONFIG_DIR` when that
env var is set, falling back to `~/.claude` — `probe-agent-messaging.mjs`
honors the same override.

`writeToMailbox(recipient, message, team)`:

1. schema-validate the message (rejects and logs on failure)
2. `mkdir -p <teams>/<team>/inboxes`
3. `writeExclusive(path, "[]")` — create the array file, tolerating `EEXIST`
4. acquire a lock at `<path>.lock`
5. read the array, push the message, `atomicWrite(JSON.stringify(arr, null, 2))`
6. release the lock

So the file is a **pretty-printed JSON array**, guarded by a sibling lockfile.

Base message schema — `from`, `text`, `timestamp` required; `type`, `read`,
`color`, `summary` optional. The writer stamps `msgV: 1`, `msg_id`,
`type: "message"`, `read: false`. Readers treat a missing `type` as `"message"`,
and `readUnreadMessages` filters on `!read`.

The same inbox carries other typed frames — but **not** as top-level entries.
`writeToMailbox` stamps `type: "message"` on everything it writes, and every
entry is validated against the base schema above, which requires `text`. So a
frame is `JSON.stringify`'d **into `text`** and discriminated by parsing that
string:

```js
let f = vCr(i, { idleReason: "available", summary: CCr(d) }); // build the frame
await GD(u, { from: i, text: De(f), timestamp: ..., color: z$() }); // De = JSON.stringify
```

(`vCr`'s own body wasn't cleanly re-sliceable at this offset, but its output
must carry `type: "idle_notification"` — the frame's schema below requires
`type` as a literal, and `frameType()` matching it end-to-end is what the
probe verifies.)

The receiving side matches this: the in-process runner reads `c.text` and
parses it (`ACr(c.text)` for a plan-approval response, `TCr(c.text)` for a
mode-set request) rather than switching on the entry's own `type`.

Frame types present in the binary: `idle_notification`,
`plan_approval_request`, `plan_approval_response`, `shutdown_request`,
`shutdown_approved`, `shutdown_rejected`, `task_assignment`, `task_completed`,
`teammate_terminated`, `mode_set_request`. Each has its own schema with **no**
`text` field, so writing one as a top-level entry fails base-schema validation
— it is dropped on read and pruned from the file.

## What does not work

**Writing to `~/.claude/teams/default/inboxes/<agentId>.json` does not reach an
in-process subagent.** Tested directly:

1. spawned a background subagent that reports every message it receives
2. sent `CANARY-ALPHA` via the `SendMessage` tool → delivered, and the send
   **resumed the idle agent**
3. wrote a schema-valid `CANARY-BRAVO` entry into the mailbox path above
4. woke the agent and asked it to list everything it had received

Result: the agent reported **one** message (`CANARY-ALPHA`). The mailbox entry
was never delivered, and its `read` flag stayed `false` — the runtime never
opened the file.

Two things follow. `SendMessage` to a subagent never touches the filesystem —
`~/.claude/teams` did not even exist before the test and was not created by the
send. And the mailbox is reachable only by processes that are actually
participating in a team; creating the directory structure by hand does not
enrol an agent into it.

## Sending to an idle agent

`SendMessage` already handles this — that is the answer for subagents. The tool
result on an idle target reads:

> was stopped (completed); resumed it in the background with your message

and for one with no live task:

> had no active task; resumed from transcript in the background with your message

So "idle" is not a barrier: a send resumes the agent from its transcript. No
separate wake mechanism is needed, and none of the file-poking approaches are
necessary or sufficient.

`SendMessage` itself already reaches a _session_, not only a subagent — it is
not limited to in-process children. Any peer listed by `ListAgents` (another
local Claude Code session, or a Claude Code Remote session) can be addressed
the same way; the transport for that case is unrelated to the on-disk mailbox
above.

There is no tool literally named `send_message` — that would be conflating the
general `SendMessage` tool with the scheduling/remote-session toolset, which
covers different needs and has **two distinct surfaces depending on how the
session is running**:

- **The CLI binary's own native tool, when no Claude Code Remote MCP server is
  attached**, is a single tool named `RemoteTrigger` ("Manage scheduled remote
  Claude Code agents (routines) via the claude.ai CCR API") whose operations
  are one `action` parameter — `list`, `get`, `create`, `update`, `run`, and
  `create_webhook_trigger` (attaches an event source, e.g. a GitHub webhook, to
  an existing routine) — plus a separate, session-local trio for scheduling
  _into this session_: `CronCreate` (fires a prompt in the current session, or
  writes `.claude/scheduled_tasks.json`), `CronDelete`, `CronList`. Verified
  against the binary (v2.1.226): `send_later`/`create_trigger`/`fire_trigger`
  (and camelCase variants) have **zero** hits as literal strings — the action
  names live inside `RemoteTrigger`'s parameter schema, not as separate tool
  names.
- **A Claude Code Remote (CCR)-enabled session — such as the one used to write
  this skill — exposes a richer, separately-named tool surface instead**:
  `send_later`, `create_trigger`, `fire_trigger`, `list_triggers`,
  `update_trigger`, `delete_trigger`, `create_session`, `get_session`,
  `list_sessions`, `interrupt_session`, `archive_session`,
  `unarchive_session`, `set_session_title`, `set_session_tags`,
  `subscribe_pr_activity`, `unsubscribe_pr_activity`, `register_repo_root`,
  `list_environments`. This is **not** a binary-extraction claim — it rests on
  directly calling `send_later` and `subscribe_pr_activity` in a live CCR
  session and observing them work (this skill's own extraction session,
  2026-08-08). Grep is a **one-way** test for this surface: an MCP tool's name
  and schema are supplied by the server at connect time, so a miss proves
  nothing about whether the tool exists. It is not, however, a reason to
  expect a miss — checked against v2.1.226, `register_repo_root` resolves 27
  times and carries its own native handler strings
  (`register_repo_root: target is not a directory`, `@179239808`), and
  `subscribe_pr_activity` / `unsubscribe_pr_activity` resolve 8 / 4 times in a
  constants table at `@262045600`, while
  `send_later` / `create_trigger` / `fire_trigger` / `list_triggers` /
  `list_environments` have zero hits. Read that as: the CLI implements part of
  this surface natively and the CCR server names the rest — so grep the binary
  first, and fall back to live tool use only for the names it can't settle.

Both descriptions can be true at once: the CCR MCP server is very likely a
thin wrapper implemented on top of the same `RemoteTrigger` REST API the raw
binary calls directly, just split into one MCP tool per action for a nicer
call shape. `send_later` maps to local `CronCreate`-style scheduling into the
current session; `create_trigger`/`fire_trigger`/`list_triggers`/etc. map onto
`RemoteTrigger`'s `create`/`run`/`list` actions. That mapping is inferred, not
verified — re-check it against the CCR MCP server's own source if it becomes
load-bearing. `scheduled-trigger` in the message-source enum is this path,
under either surface.

## Remote Control and the approval gate

There is a setting described in the binary as:

> Require explicit approval before SendMessage can reach a peer session on
> another machine via Remote Control

This is a user-facing security control: it exists so an agent cannot reach a
session on a different machine without the owner knowing. Two things follow for
anything built on top of this skill.

The supported way to change it is to change the setting, in the user's own
configuration, as an explicit decision by the person who owns those machines.

Do **not** build a mechanism that routes around the gate while it is enabled.
Reaching a peer to do something the local session could not do is exactly the
cross-session permission laundering the `SendMessage` tool contract prohibits —
it converts a permission the user declined into one they never saw. If a send
is blocked, the correct move is to surface the block to the user, not to find
another door.

## Verification

Re-run the experiment with the probe (read-only; it inspects mailbox state and
reports what it finds, and has no send mode):

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/probe-agent-messaging.mjs"          # all teams
node "${CLAUDE_PLUGIN_ROOT}/scripts/probe-agent-messaging.mjs" --json   # machine-readable
node "${CLAUDE_PLUGIN_ROOT}/scripts/probe-agent-messaging.mjs" --team <name>
```

Re-derive the binary facts with the `extract-builtins` skill — the offsets move
between releases, so search by the log strings (`[TeammateMailbox]
getInboxPath`, `writeToMailbox`) rather than by offset.

## Troubleshooting

| Symptom                                      | Cause                                                                    |
| :------------------------------------------- | :----------------------------------------------------------------------- |
| Wrote to an inbox, agent never saw it        | Expected for in-process subagents — use `SendMessage`                    |
| `SendMessage` says "resumed from transcript" | Normal; the agent was idle and has been woken                            |
| Inbox file exists but `read` stays `false`   | Nothing is participating in that team; the file is inert                 |
| Message silently dropped from a real inbox   | Schema violation — `from`/`text`/`timestamp` must all be present strings |
