# Task Parallelization Plugin

An intelligent skill that helps Claude Code parallelize Task tool calls when working on batch operations, repetitive changes, or research tasks.

## Overview

When you ask Claude to perform the same operation across many items (files, components, services), this skill automatically guides Claude to:

1. **Identify parallelizable work** - Recognize when tasks can run concurrently
2. **Assess optimal parallelization** - Determine how many tasks to run in parallel based on complexity
3. **Execute efficiently** - Batch and run tasks for maximum throughput
4. **Handle failures gracefully** - Retry failed tasks and report results clearly

## Features

### Intelligent Parallelization Levels

The skill defines 5 parallelization levels based on task characteristics:

| Level          | Concurrent Tasks | Use Case                                       |
| -------------- | ---------------- | ---------------------------------------------- |
| **Maximum**    | 8-10             | Read-only research, exploration, analysis      |
| **High**       | 5-7              | Simple templated changes, bulk updates         |
| **Moderate**   | 3-4              | Refactoring, migrations, context-aware changes |
| **Limited**    | 2                | Complex logic, subtle dependencies             |
| **Sequential** | 1                | Explicit dependencies, shared state            |

### Automatic Complexity Assessment

The skill evaluates each batch operation for:

- Task independence (can tasks run without affecting each other?)
- Resource requirements (CPU, memory, I/O intensity)
- Failure impact (what happens if one task fails?)
- Task complexity (simple pattern vs. complex reasoning)

### Model Selection Guidance

For cost-effective parallel execution:

- **haiku**: Simple, repetitive tasks (renaming, imports, templated edits)
- **sonnet**: Moderate complexity (refactoring, documentation)
- **opus**: Complex reasoning (architecture, debugging)

## Example Use Cases

### High Parallelization Examples

```
"Research how 10 different libraries handle authentication"
"Add the same import to all 50 component files"
"Check which of these 20 APIs are still active"
```

### Moderate Parallelization Examples

```
"Refactor these 15 functions to use the new error handling pattern"
"Update all configuration files to the new schema"
"Add JSDoc comments to all exported functions"
```

### Sequential Examples

```
"Create the base class, then create all derived classes"
"Update the API schema, then update all callers"
```

## Installation

See [Installation Guide](../../docs/installation.md) for all installation methods.

### Quick Install

```bash
# Via marketplace (recommended)
# Follow marketplace setup: ../../docs/manual-installation.md

# Or via GitHub
claude plugins install github:nsheaps/ai-mktpl/plugins/task-parallelization

# Or locally for testing
cc --plugin-dir /path/to/plugins/task-parallelization
```

## How It Works

When you make a request that involves repetitive or batch operations, Claude will:

1. **Recognize the pattern** - Identify that multiple similar tasks need to be performed
2. **Consult this skill** - Use the parallelization guidelines to plan execution
3. **Create task batches** - Group independent tasks based on the recommended parallelization level
4. **Execute in parallel** - Launch multiple Task agents concurrently
5. **Aggregate results** - Collect and summarize outcomes from all tasks

## Best Practices

### Do

- Be specific about what needs to change across items
- Provide examples of the expected transformation
- Mention if there are any dependencies between items

### Don't

- Ask to parallelize tasks that modify the same file
- Expect shared context between parallel tasks
- Assume order of completion matches order of launch

## License

MIT License - See repository root for details.
