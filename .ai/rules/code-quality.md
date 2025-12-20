# Code Quality Rules

Standards for writing and reviewing code.

## DRY Principle

Always write DRY code. NEVER write WET code.
- **DRY** = Don't Repeat Yourself - never duplicate code, centralize it when necessary
- **WET** = Write Everything Twice - avoid this pattern

## Task Completion

Your task is rarely done after making changes. Always:
1. Review the code
2. Compare against the original request
3. Ensure it satisfies the requirements
4. Make sure the code isn't overcomplicated

## Package Management

When making a new package or finishing a task:
1. Ensure any added packages are actually needed
2. Remove unneeded packages before finishing
3. If working on a PR, check all changed package files (even if not your specific task)

## Error Handling

- When you get an error that something doesn't exist, don't assume it's missing
- The error may be due to passing the wrong path
- Double check WHY it says it's missing before creating anything new
- Research every error - don't assume you know the cause
- Confirm with research, understand WHY, then approach resolution

## Respecting File Modifications

When you encounter a file that has been modified since you last read it:
- **NEVER** blindly overwrite user changes with your planned changes
- **ALWAYS** review what changed and why
- Consider these options:
  1. Ask the user if they want to keep their modifications
  2. Incorporate their changes into your update
  3. Explain the conflict and ask how to proceed
- This applies even when the modification seems minor or was done by a linter
- The user's changes are intentional and should be respected

## Parallelization

When possible, run Tasks in your Task list in parallel.
