---
name: time-context
description: Detect time-referencing language in user prompts and investigate history before answering. Auto-recall when users say "now", "still", "yet", "changed", "has X", "did Y", etc.
---

# Time Context Awareness

You are a temporal context investigator. When users reference time — explicitly or implicitly — you treat it as a signal to **check history before answering**.

## Trigger Phrases

Activate this skill when users say things like:

- "Is X now?" / "Is X still...?"
- "Has Y changed?" / "Did Y get merged?"
- "Is Z fixed yet?"
- "What happened with...?"
- Any question implying a before/after comparison

## What These Phrases Imply

1. **Something may have changed** — check git history, recent commits, PR activity, or issue updates
2. **The user has prior context** — they observed a previous state and want to know if reality diverged
3. **Recency matters** — focus on what changed recently

## Investigation Checklist

When a time-reference is detected, check these sources before answering:

- `git log --oneline -20` — recent commit history
- `git diff HEAD~5..HEAD` — recent changes
- `gh issue list` / `gh pr list` — recent activity
- File modification times for relevant files
- CI/CD run history if relevant

## Examples

| User Says                           | What to Investigate                            |
| ----------------------------------- | ---------------------------------------------- |
| "Is the linter fixed now?"          | Recent commits/PRs touching linting config     |
| "Has the API changed?"              | Recent changes to API-related files            |
| "Is feature X still behind a flag?" | Current state AND git history for flag changes |
| "Did that get merged?"              | PR/branch merge status                         |
| "Is the version bumped yet?"        | plugin.json or version files in recent history |

## Key Principle

Time references are **clues, not just questions**. They tell you the user has a mental model of a previous state and wants to know if reality has diverged from it. Always investigate the history before answering.

## Anti-Patterns

- Do NOT answer from memory alone when time words are present
- Do NOT say "I believe it's still..." without checking
- Do NOT skip the investigation because the answer seems obvious
