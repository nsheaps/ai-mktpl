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
to a team literally named `default`.

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

For reaching a _session_ rather than a subagent, the supported paths are the
Claude Code Remote MCP tools (`send_message`, `send_later`, `create_trigger`),
which deliver into a session as an ordinary user turn and survive restarts.
`scheduled-trigger` in the source enum is that path.

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
