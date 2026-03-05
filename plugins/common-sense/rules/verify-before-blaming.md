# Verify Before Blaming

When something doesn't work as expected, **ALWAYS verify actual state before blaming tooling, CI, or external systems**.

## The Pattern to Avoid

**Wrong:**

1. See unexpected result (e.g., version is 0.0.1)
2. Assume tooling did something wrong ("CI must have reverted it")
3. Create bug report or issue blaming the tooling
4. Later discover the tooling was working correctly

**Correct:**

1. See unexpected result
2. **Verify the actual state** - read the file, check git history, examine logs
3. **Investigate root cause** - why is this the current state?
4. Only then determine if it's a bug or a configuration issue

## Required Verification Steps

Before claiming a tool, workflow, or system has a bug:

### 1. Verify Current State

```bash
# Read the actual file contents
cat path/to/file

# Check git history for that file
git log --oneline -5 -- path/to/file
git show HEAD:path/to/file

# Compare with what you expected
git diff HEAD~1 -- path/to/file
```

### 2. Check Your Own Actions

- Did I actually commit the change I thought I made?
- Did I push the commit?
- Was there a merge conflict that reverted my change?
- Is this a different branch than I expected?

### 3. Investigate Tool Behavior

- What does the tool's documentation say?
- What configuration does the tool expect?
- Is there a config file missing that the tool needs?
- Run the tool with verbose/debug output

### 4. Only Then Report

If after all verification you believe there's a bug:

- Include evidence (actual file contents, git history)
- Show what you expected vs. what happened
- Include reproduction steps
- Note what configuration exists

## Why This Matters

- **False bug reports waste time** and erode trust
- **Assumptions compound** - you might build more wrong assumptions on top
- **The actual issue remains unfixed** while you chase ghosts
- **Tooling often works correctly** - the issue is usually configuration or user error

## Common Scenarios

| You Think...                   | But Actually...                                           |
| ------------------------------ | --------------------------------------------------------- |
| "CI reverted my version bump"  | You never committed the bump, or config was missing       |
| "The workflow is broken"       | The workflow worked; input was wrong                      |
| "The tool has a bug"           | The tool needs configuration you didn't provide           |
| "Something deleted my changes" | Git merge conflict resolved differently than you expected |

## Self-Check Questions

Before blaming external tooling, ask yourself:

1. Have I verified the actual current state of the file/system?
2. Have I checked git history to see what actually happened?
3. Have I read the tool's documentation/requirements?
4. Is there configuration the tool expects that I haven't provided?
5. Could this be user error rather than a tool bug?

**If you can't answer YES to all of these, keep investigating before reporting.**
