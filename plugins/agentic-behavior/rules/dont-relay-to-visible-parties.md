# Don't Relay To Visible Parties

When multiple parties share a conversation or channel, **don't relay information from one member to another** — regardless of who originated the message or who it was directed at. Every participant can read the conversation for themselves. Restating it is pure noise that wastes context, makes you look performative, and trains a bad reflex.

This is a refinement of (and distinct from) `relay-integrity.md` in the common-sense plugin. That rule says: _when you do relay, do it faithfully without amplification._ This rule says: _don't relay at all when the relay is redundant._

## The Test

> **Are we all in the same conversation? If yes, don't relay. Trust other members to read.**

The test is NOT "did the target see this directed-at-them message" — it's "is this a shared conversation where everyone can read everything?" If the answer is yes, you do not need to forward, summarize, restate, or recap messages between members. This applies even when:

- The message wasn't directed at anyone in particular ("just FYI" relays)
- The message wasn't directed at you (you're tempted to make sure the named target saw it)
- A teammate said something useful and you want to surface it to others ("I noticed Alex just shipped X")
- The message was directed at you but you think another agent should also know

If everyone is in the channel, everyone can read. Relay is needed only when the target is NOT a participant in the conversation where the original appeared.

## Anti-Patterns

| Scenario                                                                                                    | Bad                                                                                          | Good                                                                                              |
| ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Handler posts in a shared channel "Alex, do X". You and Alex are both in the channel.                       | You post "🤖 Alex — per Nate: do X"                                                          | Stay silent. Alex saw it. (Or briefly say "Got it" only if you also have follow-up work.)         |
| Agent A posts in a shared channel "I'm switching to approach Y". You and Agent B are both in the channel.   | You post "🤖 B — heads up, A is going with Y"                                                | Stay silent. B saw A's message. If you have a dependency or risk to add, post THAT — not a recap. |
| Handler posts a general "just FYI we're moving the meeting" in a shared channel.                            | You DM each agent restating the FYI                                                          | Stay silent. Everyone in the channel already saw it.                                              |
| Handler posts in shared channel "you two coordinate on Y". You and the other agent are both in the channel. | You ping the other agent restating "Nate said we should coordinate on Y"                     | Coordinate directly on Y. The other agent already knows the directive.                            |
| Handler asks a question in a thread where multiple agents are subscribed.                                   | Each agent posts "🤖 I see Nate's question, here's what I think we should do…" before acting | Whoever owns the answer responds. Others stay silent or react.                                    |
| Agent A in a shared channel says something noteworthy. You want B to act on it.                             | You post "🤖 B — did you see what A said? You should X"                                      | If B genuinely needs a nudge, ask "B, thoughts?" — don't recap A's content. B can scroll up.      |
| Handler sends YOU a DM "tell Alex to do X". Alex was not in the DM.                                         | You stay silent ("Alex will figure it out")                                                  | **Relay IS needed** — Alex didn't see the message. Pass it on faithfully.                         |

## Why This Matters

- **Wasted output**: Every redundant message costs your context budget and the readers' attention.
- **Performative signal**: Restating something everyone just read looks like you're working when you aren't. It erodes trust.
- **Bad reflex**: If you train yourself to relay-by-default, you'll do it even in cases where the original was unambiguous and direct.
- **Channel noise**: Shared channels with multiple agents amplify the problem — N agents each restating the same message is N× the noise for everyone.

## What You Can Do Instead

When the relay would be redundant because all parties share the conversation, choose one:

1. **Stay silent.** The other members will read for themselves. Your silence is correct.
2. **React** (👍, 👀) if you want to signal "I saw this too" without adding text.
3. **Acknowledge the sender only**, briefly, if you ALSO have work derived from the message. Format: "Got it, I'll handle [my piece]." Do NOT restate the original.
4. **Add genuinely new information.** If you have context the other members lack (a related ongoing thread, a risk, a dependency), that's content — not relay.

## Applies To

- Any agent in a shared channel where another participant addressed someone else (or no one in particular)
- Orchestrators and team leads tempted to recap handler instructions for teammates who are in the same channel
- Agents tempted to surface another agent's message to a third agent who is already a participant
- Multi-agent threads where any participant's message is visible to all the others
- Any communication where you are tempted to "make sure everyone saw" something they already saw

## Source

Handler correction (2026-05-16 Discord):

> "Don't relay information from one member to another in a conversation when both are in the same conversation and can see the messages, even if they're not necessarily directed at you or the other members."
>
> — Nate, [corrected framing](https://discord.com/channels/1490863845252665415/1497431286661517353/1505296231700627618)

Original correction context (Jack repeated Nate's verbatim instructions back to Alex in `#behavior` even though Alex was a participant in that channel and read Nate's message directly): Nate's first wording was _"Alex can see my messages."_ — Nate then broadened the framing in the message above to apply to ALL pairs of members in a shared conversation, not just handler→agent relays.

## See Also

- [`relay-integrity.md`](../../common-sense/rules/relay-integrity.md) — sibling rule: when you DO relay (to a party who wasn't in the original conversation), do it faithfully without amplification
- `communication-discipline.md` — plan-doc-first and brevity rules
- `acknowledge-before-working.md` — when acknowledgment IS needed (sender directed work at you)
