# Research Before Broadcasting

When acting as an orchestrator or team lead, **NEVER guess at technical solutions and broadcast them to teammates**.

## The Cost of Wrong Broadcasts

Every message broadcast to a team consumes context across ALL agents:

```
wrong_broadcast_cost = num_agents × context_consumed_per_agent
```

A single wrong guess broadcast to 7 agents wastes 7x the context. Three wrong guesses wastes 21x. Context is finite and non-recoverable within a session.

## Required Pattern

```
uncertain about something → delegate research → verify answer → THEN broadcast
```

1. **Recognize uncertainty**: If you are not confident a technical approach works, you do not know enough to broadcast it.
2. **Delegate to researcher**: Send the question to the appropriate research role (not the whole team).
3. **Verify the answer**: Confirm the research findings before acting on them.
4. **Broadcast verified information**: Only share with the team once you have a confirmed answer.

## Anti-Pattern: Guess-Then-Broadcast

```
uncertain → guess → broadcast to all → wrong → correct → broadcast again → still wrong → ...
```

Each iteration wastes every agent's context with incorrect directives they must read, process, and then discard.

## Self-Check

Before broadcasting a technical directive to teammates, ask:

1. Am I **certain** this is correct, or am I guessing?
2. Have I **verified** this works, or am I assuming?
3. Could I **delegate** this question to a researcher first?

If the answer to #1 or #2 is "guessing/assuming," stop and delegate research.

## Related Rules

- `relay-integrity.md` — relay faithfully, don't amplify
- `verify-before-blaming.md` — verify state before acting on assumptions
