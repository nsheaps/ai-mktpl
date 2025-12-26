---
name: task-parallelization
description: Automatically identify opportunities to parallelize Task tool calls when working on batch operations, repetitive changes, or research tasks. Use this skill when asked to make the same change across multiple files/items, perform bulk operations, or conduct research across multiple sources.
---

# Task Parallelization Skill

This skill helps you identify when and how to parallelize Task tool calls for maximum efficiency when working on batch or repetitive operations.

## When to Use Parallelization

### High Parallelization Candidates (parallelize aggressively)
- **Research tasks**: Searching documentation, exploring codebases, gathering information
- **Read-only operations**: Analyzing files, checking status, validating configurations
- **Independent file changes**: Same change across unrelated files (no dependencies)
- **Bulk lookups**: Fetching information from multiple sources
- **Code review**: Reviewing multiple files or PRs independently

### Medium Parallelization Candidates (parallelize with caution)
- **File modifications**: Editing multiple files with the same pattern
- **Test execution**: Running tests across different modules
- **Migrations**: Applying similar changes across related components
- **Refactoring**: Renaming or restructuring across the codebase

### Low Parallelization Candidates (limit parallelization)
- **Complex logic changes**: Changes requiring careful reasoning
- **Interdependent modifications**: Changes where one depends on another
- **Build/compilation tasks**: CPU-intensive operations
- **Database operations**: Operations that might conflict

## Parallelization Levels

### Level 1: Maximum Parallelization (8-10 concurrent tasks)
**Use when:**
- Tasks are purely read-only (research, exploration, analysis)
- Tasks are completely independent with no shared resources
- Tasks are simple and unlikely to fail
- Low CPU/memory requirements

**Examples:**
- "Research how 10 different libraries handle authentication"
- "Find all usages of a deprecated function across the codebase"
- "Check the status of 10 different services"

### Level 2: High Parallelization (5-7 concurrent tasks)
**Use when:**
- Tasks involve simple, templated changes
- Tasks modify different files with no interdependencies
- Changes follow a clear, repeatable pattern
- Moderate complexity with low failure risk

**Examples:**
- "Add the same import statement to 20 files"
- "Update version numbers across all package.json files"
- "Add a standard header comment to all source files"

### Level 3: Moderate Parallelization (3-4 concurrent tasks)
**Use when:**
- Tasks involve some complexity or judgment
- Tasks modify related files but without direct dependencies
- Changes require some context awareness
- Medium risk of conflicts or failures

**Examples:**
- "Refactor 10 similar functions to use a new API"
- "Update error handling patterns across modules"
- "Migrate configuration files to a new format"

### Level 4: Limited Parallelization (2 concurrent tasks)
**Use when:**
- Tasks involve complex logic or decision-making
- Tasks might have subtle interdependencies
- Changes require careful reasoning
- Higher risk of conflicts or cascading failures

**Examples:**
- "Fix type errors in related components"
- "Update database schemas and their migrations"
- "Refactor tightly coupled modules"

### Level 5: Sequential (1 task at a time)
**Use when:**
- Tasks have explicit dependencies (A must complete before B)
- Tasks modify shared state or resources
- Order of operations matters
- High complexity requiring full attention

**Examples:**
- "Build, then test, then deploy"
- "Create base class, then derived classes"
- "Update API, then update all callers"

## Implementation Pattern

When you identify a parallelizable request, structure your response like this:

### Step 1: Identify the Work
Break down the request into discrete, independent units of work.

### Step 2: Assess Complexity
Determine the appropriate parallelization level based on:
- Task independence
- Resource requirements
- Failure impact
- Complexity of each task

### Step 3: Batch and Execute
Group tasks into batches based on the parallelization level and execute.

### Example Implementation

**User Request:** "Add JSDoc comments to all 12 exported functions in the utils/ directory"

**Analysis:**
- Task type: File modifications (templated changes)
- Independence: High (each function is independent)
- Complexity: Low-Medium (requires reading function, writing appropriate docs)
- Recommended level: Level 2-3 (4-6 concurrent tasks)

**Execution Plan:**
```
Batch 1: Tasks 1-5 (parallel)
Batch 2: Tasks 6-10 (parallel)
Batch 3: Tasks 11-12 (parallel)
```

## Critical Rules

### DO:
1. **Always assess independence** before parallelizing
2. **Start conservatively** - you can increase parallelization if tasks succeed
3. **Use haiku model** for simple, repetitive tasks to save cost
4. **Group similar tasks** in the same batch for consistency
5. **Provide clear, detailed prompts** to each task (they don't share context)
6. **Include all necessary context** in each task prompt (file paths, patterns, examples)

### DON'T:
1. **Don't parallelize dependent tasks** - if B needs A's output, run sequentially
2. **Don't over-parallelize complex tasks** - quality suffers
3. **Don't parallelize tasks that modify shared state** (same file, same config)
4. **Don't assume tasks share context** - each Task agent is independent
5. **Don't forget to aggregate results** - summarize outcomes for the user

## Task Prompt Template

When launching parallel tasks, use this template:

```
You are performing task {N} of {TOTAL} in a parallel batch operation.

## Task
{Specific task description}

## Context
{Any necessary background information}

## Files/Targets
{Specific file(s) or item(s) to work on}

## Expected Output
{What the task should produce or change}

## Constraints
- {Any limitations or rules}
- This is a standalone task - do not assume access to other parallel tasks' results
```

## Handling Failures

When parallel tasks fail:

1. **Identify failed tasks** from the results
2. **Analyze failure patterns** - are they related?
3. **Retry failed tasks** with potentially lower parallelization
4. **Report to user** which tasks succeeded and which need attention

## Model Selection for Parallel Tasks

- **haiku**: Simple, repetitive tasks (renaming, adding imports, simple edits)
- **sonnet**: Moderate complexity (refactoring, documentation, standard changes)
- **opus**: Complex reasoning (architecture decisions, complex debugging)

Using haiku for simple parallel tasks can significantly reduce cost and latency while maintaining quality for straightforward operations.
