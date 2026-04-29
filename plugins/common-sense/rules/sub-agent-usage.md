# Sub-Agent Usage

## Reports Must Be Saved to Files

**CRITICAL:** When using sub-agents to produce reports or analyses:

1. The sub-agent MUST save its output to a file
2. The main agent reads that file to access the results
3. NEVER have sub-agents return extensive output directly in conversation

**Why:** Returning large responses in conversation creates extreme risk - the conversation becomes unusable and unable to compact properly.

## Pseudo-Plan Before Executing

**CRITICAL:** Whenever you spawn a sub-agent, the FIRST prompt must ask it to print its understanding of the task and proposed approach — WITHOUT doing any actual work yet. You review the pseudo-plan, send corrections via `SendMessage` until the plan is right, and THEN send one final message telling the sub-agent to execute.

### Why

- Catches misunderstandings before the agent wastes effort on the wrong thing
- Sub-agents can't converse with you mid-execution, but they can be iterated on via `SendMessage` between runs
- Aligning on the plan upfront is cheaper than re-doing the work after the fact
- You as the orchestrator are responsible for the output quality — the pseudo-plan is your chance to spot gaps before commitment

### Pattern

```
1. Initial sub-agent prompt:
   "Before doing any work, print your understanding of the task and your
    proposed approach. Do NOT make any changes or run any destructive
    commands yet — just describe what you plan to do."

2. Read the sub-agent's pseudo-plan.

3. If corrections needed:
   SendMessage → "Your plan has these issues: <X>. Revise and re-print."
   Iterate until the plan is correct.

4. When plan is correct:
   SendMessage → "Your plan looks correct. Proceed with execution."

5. If the sub-agent pauses mid-execution (error, ambiguity, question):
   SendMessage with answers/guidance. Continue iterating until the task
   is complete.
```

### Exceptions

Trivial single-command sub-agents where the plan is obvious from the prompt (e.g., "run `mise run lint` and report the exit code") may skip the pseudo-plan step. When in doubt, ask for the plan — the cost of an extra round-trip is small compared to the cost of wrong work.

### Applies To

- ALL sub-agents, regardless of purpose (implementation, research, review, etc.)
- Background agents dispatched via the Agent tool
- Any spawned execution where the parent agent won't see intermediate progress before the work is complete
