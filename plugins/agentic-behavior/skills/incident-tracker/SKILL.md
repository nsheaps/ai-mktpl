---
name: incident-tracker
description: >-
  Use this skill when the user wants to log a behavioral incident, document a
  correction in a structured incident report, or maintain learned rules with
  footnote references back to source incidents. Trigger phrases include "log
  an incident", "log this incident", "track an incident", "behavioral
  incident", "document this correction as an incident", "create incident
  report", "file an incident", or when the user explicitly asks for a
  structured incident record with severity classification and rule derivation.
argument-hint: "<short description of the behavioral correction>"
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(mkdir:*), Bash(ls:*), Bash(date:*), Bash(pwd:*), Bash(git status:*), Bash(git rev-parse:*), AskUserQuestion
---

# incident-tracker

Track behavioral incidents with structured incident files, derive reusable
rules, and maintain footnote references between rules and the incidents that
produced them.

## When to use this skill vs. `correct-behavior`

Both skills handle behavior corrections. They are complementary:

- **`agentic-behavior:correct-behavior`** — broader corrective workflow
  (reflect, scope, search, derive rule, edit rules/skills/plugins/hooks). Use
  when the goal is fixing the behavior across the system.
- **`agentic-behavior:incident-tracker`** — structured incident log format
  (severity, tags, footnoted rules). Use when the goal is producing a durable
  audit trail of *what happened*, in addition to or instead of fixing the
  behavior in code.

When in doubt, prefer `correct-behavior` for active fixes and add an incident
record via this skill if the handler asks for one explicitly or if the
incident is significant enough to deserve a permanent record.

## Workflow

When given a behavioral correction:

### 1. Stop the current task

Do not continue with the previous task. Acknowledge the correction first.

### 2. Gather context

Capture, in your own words:

- What did the user ask you to do?
- What did you actually do?
- What did the user say was wrong?
- Quote the user's exact phrasing if available — their words matter.

### 3. Discover the workspace rules file

The rules file is where derived rules get appended (with footnote references
back to the incident file). Discover it in this order:

1. If `CLAUDE.md` exists at the repo root, use that.
2. Else if `AGENTS.md` exists at the repo root, use that.
3. Else if a settings entry `agentic-behavior.rulesFile` is configured in
   `~/.claude/plugins.settings.yaml` or project-level
   `.claude/plugins.settings.yaml`, use that.
4. Else create `AGENTS.md` at the repo root and use that. **Tell the user**
   you created it so they aren't surprised.

Do not silently overwrite an existing rules file you didn't discover — ask
the handler before clobbering anything unexpected.

### 4. Create the incident file

Place it under `incidents/behavioral/` at the repo root. Naming pattern:

```
YYYY-MM-DD--short-description.md
```

Use the structured template at
`references/incident-template.md` — copy it as the starting point, then fill
in every section. Do not leave placeholder text in the file.

### 5. Append a derived rule to the rules file

Under a `## Learned Behaviors` section in the rules file (create the section
if it doesn't exist), add the rule using this format:

```markdown
N. **<Rule title>** — <Rule description>. [^rule-N]

[^rule-N]: [YYYY-MM-DD -- Incident Title](incidents/behavioral/YYYY-MM-DD--short-description.md)
```

Number rules sequentially within the file. Footnote IDs (`^rule-N`) must be
unique within the file. The footnote definition can live at the bottom of
the file with the other footnote definitions.

### 6. Confirm with the user

Before resuming any other work, confirm:

- Where the incident file lives (path)
- The derived rule (text and number)
- Which rules file you wrote to
- That the user agrees with your characterization

If the user disagrees, edit the incident file and rule before continuing.

## Severity Levels

| Level    | When to Use                                                |
| -------- | ---------------------------------------------------------- |
| `low`    | Minor inconvenience, no lasting impact                     |
| `medium` | Affected user workflow, required correction                |
| `high`   | Data loss, security issue, or significant trust impact     |

Pick the most accurate severity based on impact, not on how badly you feel
about the mistake. If the user explicitly classifies it differently, use
their classification.

## Notes

- **Every incident must derive at least one rule.** If you can't articulate
  a rule, the incident isn't done — keep working with the user until the
  rule is clear.
- **Rules should be actionable and specific.** "Be more careful" is not a
  rule. "Always confirm before running `git push --force`" is a rule.
- **Footnote references link rules back to incidents.** Future maintainers
  (and future you) need to know *why* a rule exists.
- **Never skip the confirmation step.** A mischaracterized incident is
  worse than no incident — it teaches the wrong lesson.

## References

- `references/incident-template.md` — structured template for incident files
- `agentic-behavior:correct-behavior` — broader behavior-correction skill
  for fixing the behavior in rules/skills/plugins/hooks
