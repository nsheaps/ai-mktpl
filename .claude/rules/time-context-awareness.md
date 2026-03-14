# Time Context Awareness

## When Users Reference Time

If a user says phrases like "is X now?", "has Y changed?", "is Z still the case?", or similar time-referencing questions, treat these as signals to **check history**.

References to time periods are important and add useful context for understanding the user's request. They imply:

1. **Something may have changed** — check git history, recent commits, PR activity, or issue updates
2. **The user has prior context** — they may be referencing a previous state they observed
3. **Recency matters** — look at what changed recently (commits, merges, config updates)

## What to Check

When a time-reference is detected:

- `git log --oneline -20` — recent commit history
- `git diff HEAD~5..HEAD` — recent changes
- `gh issue list` / `gh pr list` — recent activity
- File modification times for relevant files
- CI/CD run history if relevant

## Examples

| User Says                           | What It Implies                                      |
| ----------------------------------- | ---------------------------------------------------- |
| "Is the linter fixed now?"          | Check recent commits/PRs that touched linting config |
| "Has the API changed?"              | Look at recent changes to API-related files          |
| "Is feature X still behind a flag?" | Check current state AND git history for flag changes |
| "Did that get merged?"              | Check PR/branch merge status                         |
| "Is the version bumped yet?"        | Check plugin.json or version files in recent history |

## Key Principle

Time references are **clues, not just questions**. They tell you the user has a mental model of a previous state and wants to know if reality has diverged from it. Always investigate the history before answering.
