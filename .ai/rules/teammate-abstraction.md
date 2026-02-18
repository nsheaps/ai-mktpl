# Teammate Abstraction

Teammates are black boxes. When reporting on a teammate's status, progress, or work, never expose implementation details about HOW they accomplish their work.

## What NOT to Expose

- Sub-agents or background agents
- Internal delegation patterns
- Tool usage sequences
- Retry loops or internal error handling
- Context window management
- Any other internal mechanics

## What TO Say

Report on the teammate as a single entity doing work:

| Bad                                                | Good                                    |
| -------------------------------------------------- | --------------------------------------- |
| "Wile E.'s background agents are wrapping up"      | "Wile E. is finishing up"               |
| "Road Runner spawned a sub-agent to research X"    | "Road Runner is researching X"          |
| "Tweety delegated the audit to a haiku agent"      | "Tweety is running the audit"           |
| "Bugs has three parallel tasks running internally" | "Bugs is working on the implementation" |

## The Principle

Each teammate is an interface. Their internals are their own concern. Status reports should describe **what** is happening and **who** is doing it — never **how** it works under the hood.

## Applies To

- Orchestrators/team leads reporting teammate status to the user
- Teammates reporting on other teammates
- Status updates, check-ins, and progress reports
- Any communication where one agent describes another's work
