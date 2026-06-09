# Workflow Self-Improvement

## Rule: Fix the System, Not Just the Symptom

When you encounter a recurring problem and discover a workaround, **you MUST update the relevant skills, rules, or documentation** so future sessions don't hit the same issue. Working around a problem without improving the system is a missed opportunity.

## When This Applies

This applies whenever you:

1. **Discover a command doesn't work as documented** — update the skill/docs to show the correct approach
2. **Find a workaround for an environment issue** — add it to the troubleshooting section of the relevant skill or rule
3. **Repeatedly do the same manual steps** — capture them in a skill or hook
4. **Notice missing context in a skill** — add the context that would have saved you time
5. **Hit a known limitation not documented** — document it where it will be found

## What to Update

| Problem Type                        | Where to Fix                                                        |
| ----------------------------------- | ------------------------------------------------------------------- |
| CLI command doesn't work in context | Skill for that tool (e.g., `plugins/github/skills/gh/SKILL.md`)     |
| Environment-specific behavior       | Rule file (e.g., `.claude/rules/`) or skill troubleshooting section |
| Repeated manual workflow            | Create or update a skill in the appropriate plugin                  |
| Missing project convention          | Rule file in `.claude/rules/`                                       |
| Recurring bug or gotcha             | `ongoing-issues.md` + GitHub issue                                  |

## How to Apply

1. **Identify the root cause** — why did the workaround become necessary?
2. **Find the right file** — where would you have looked for this information?
3. **Add the fix** — update that file with the correct guidance, prominently placed
4. **Make it discoverable** — put critical information at the top, not buried at the bottom
5. **Include the version bump** — plugin changes require a version bump per `versioning.md`

## Anti-Patterns

- Working around an issue 3+ times without updating docs
- Adding a workaround in a rule file when it belongs in a skill (rules say _what_, skills say _how_)
- Documenting the workaround only in a commit message where future sessions won't see it
- Fixing the symptom in one place while the incorrect guidance remains in another
