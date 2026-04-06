---
name: incident
description: Track behavioral incidents, document corrections, and maintain learned rules
argument-hint: "<description of the behavioral correction>"
---

# /incident

Track behavioral incidents, document corrections, and maintain learned rules.

## Usage

```
/incident <description>
```

When the user corrects your behavior, use this command to:

1. Document what happened
2. Analyze why it was wrong
3. Derive a reusable rule
4. Update the rules file with footnote references

## Workflow

When given a behavioral correction:

### 1. STOP IMMEDIATELY

Do not continue with the previous task. Acknowledge the correction first.

### 2. GATHER CONTEXT

- What did the user ask you to do?
- What did you actually do?
- What did the user say was wrong?

### 3. CREATE INCIDENT FILE

Create a file in `incidents/behavioral/` with this naming pattern:

```
YYYY-MM-DD--short-description.md
```

Use this template:

```markdown
---
date: YYYY-MM-DD
time: "HH:MM TZ"
severity: low | medium | high
tags: [tag1, tag2]
status: documented
---

# Incident: <Short Title>

## What the User Asked

<What the user originally requested>

## What I Did

<What you actually did>

## What the User Said Was Wrong

> "<Exact quote if available>"

## Why It Was Wrong

<Analysis of why the behavior was incorrect>

## What I Should Have Done Instead

<Correct behavior>

## Corrective Actions Taken

<What you did to fix it>

## Corrective Actions Chosen Not to Take

<What you deliberately didn't do and why>

## Additional References

- Links to related docs, previous incidents, etc.

## Derived Rules

N. **<Rule title>** — <Rule description>. [^rule-N]
```

### 4. UPDATE RULES FILE

Add the derived rule to `AGENTS.md` under `## Learned Behaviors`:

```markdown
N. **<Rule title>** — <Rule description>. [^rule-N]

[^rule-N]: [YYYY-MM-DD -- Incident Title](incidents/behavioral/YYYY-MM-DD--short-description.md)
```

### 5. CONFIRM WITH USER

Before continuing, confirm:

- What you documented
- The derived rule
- That the user agrees with the characterization

## Example

User says: "You just restarted yourself without asking"

You respond:

1. Stop
2. Create `incidents/behavioral/2026-03-21--restarted-without-permission.md`
3. Add rule to AGENTS.md: "Always confirm before restarting the gateway"
4. Tell user: "Documented. Added Rule #6 about gateway restarts. Continue?"

## Severity Levels

| Level  | When to Use                                            |
| ------ | ------------------------------------------------------ |
| low    | Minor inconvenience, no lasting impact                 |
| medium | Affected user workflow, required correction            |
| high   | Data loss, security issue, or significant trust impact |

## Notes

- Every incident must derive at least one rule
- Rules should be actionable and specific
- Footnote references link rules back to incidents
- Never skip the confirmation step
