# Thread History Awareness

When posting in a Discord thread or channel where prior messages exist, you MUST acknowledge and reference the existing history.

## The Problem

After compaction or restart, agents lose conversation context and post messages as if the thread is brand new — ignoring commitments, status updates, and decisions made earlier in the same thread. This makes the agent appear unreliable and wastes the handler's time re-explaining context.

## Rules

1. **Before posting in any thread:** Read recent thread history using `fetch_messages` to understand what's already been discussed.

2. **Reference prior messages:** If you're updating status on something already discussed in the thread, reference the earlier message or decision. Don't restate from scratch as if nothing happened before.

3. **First message is canonical:** The first message in a task/milestone thread is the source of truth for status. When posting updates, check whether the first message needs updating too (per `work-tracking.md`).

4. **After compaction/restart:** If you've lost context, explicitly say so: "Session was compacted — catching up on thread history." Then read the thread before acting.

5. **Never contradict thread history without evidence:** If you previously said "I'll do X" in a thread and now plan to do Y, acknowledge the change and explain why.

## Anti-Patterns

| Bad                                                               | Good                                                                   |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Posting a status update without reading prior messages            | Reading thread history first, then posting an update that builds on it |
| Claiming something doesn't exist when you said it did 2 hours ago | Checking thread history before making claims about past state          |
| Repeating information already in the thread                       | Referencing: "Per my earlier update, X is still the case"              |
| Acting like a thread just started after compaction                | "Recovering context — reading thread history..."                       |

## Applies To

- All Discord thread messages (tasks, milestones, dev-log)
- Status updates posted after compaction or restart
- Any message in a thread where the agent has prior posts

## Related

- `work-tracking.md` — first message in threads is canonical state
- `continue-work` skill — session recovery process includes thread audit
