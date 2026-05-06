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

## Verify Sub-Agent Output Against the ORIGINAL Ask

**CRITICAL:** A sub-agent's "PASS" / "DONE" report only proves the work it built passes the assertions IT wrote. It does NOT prove the work matches what the user originally asked for. You as the orchestrator are responsible for that match — the sub-agent cannot be, because it never sees the user's original message, only the prompt you gave it (your interpretation).

### The Failure Mode

You delegate Task X to a sub-agent. The sub-agent (correctly, on its own scope) builds a subset of X, writes assertions for that subset, and reports PASS. You forward that PASS to the user as "Task X done." The user — who has the original spec in their head — points out the delivered work doesn't match. The sub-agent didn't lie; you skipped the comparison.

### Required Verification Step

Before reporting any delegated task as done, EVERY TIME:

1. Re-read the user's ORIGINAL ask verbatim (not your interpretation, not the sub-agent's prompt, not the plan)
2. Enumerate its concrete requirements as a checklist
3. For each requirement, point to specific evidence in the sub-agent's deliverable that satisfies it (file path + line, log line, test name, commit hash)
4. If ANY requirement isn't met or isn't verifiable from the deliverable, the task is NOT done. Either iterate the sub-agent on the gap or take the work back over yourself.

### Why "PASS" Doesn't Mean "Done"

- Sub-agents assert against their own understood scope — by default narrower than the original ask
- Sub-agents are optimistic: they want to report success and will define success in terms they can prove
- Sub-agents never see the user's original message — only the prompt you gave them
- A passing test suite is necessary but not sufficient

### Anti-Pattern

```
Sub-agent: "PASS — 15/15 assertions green, commit abc1234"
You → user: "Task #N done."
```

### Correct Pattern

```
Sub-agent: "PASS — 15/15 assertions green, commit abc1234"
You: [re-read original ask] → [build checklist] → [verify each item against deliverable]
You → user: "Original ask required A, B, C, D, E. Verified:
  - A ✓ (assert 3 in test file)
  - B ✓ (commit abc1234 lines 50-70)
  - C ✗ (sub-agent didn't implement)
  - D, E ✓
C is missing — task is not done. Continuing on it."
```

### Applies To

- All sub-agent-delegated tasks before reporting completion to the user
- Especially when the task originated from a user request (vs. internal planning)
- The handoff from sub-agent back to you is the highest-risk moment for false-completion claims
