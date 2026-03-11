---
name: tasks
description: >
  Use this skill when the user asks about managing Google Tasks like
  creating, listing, updating, or completing tasks and task lists via
  the Google Workspace CLI.
---

# Google Tasks via Google Workspace CLI

Use `gws tasks` to manage Google Tasks from the command line.

## Common Operations

### Task Lists

```bash
# List all task lists
gws tasks tasklists list

# Create a new task list
gws tasks tasklists create --title "Sprint 42"

# Update a task list
gws tasks tasklists update <tasklist-id> --title "Sprint 42 - Updated"

# Delete a task list
gws tasks tasklists delete <tasklist-id>
```

### Tasks

```bash
# List tasks in a task list
gws tasks list <tasklist-id>

# List only incomplete tasks
gws tasks list <tasklist-id> --show-completed false

# Create a task
gws tasks create <tasklist-id> --title "Review PR #123"

# Create a task with details
gws tasks create <tasklist-id> \
  --title "Write documentation" \
  --notes "Cover API endpoints and authentication" \
  --due "2026-03-20"

# Update a task
gws tasks update <tasklist-id> <task-id> --title "Updated title"

# Complete a task
gws tasks complete <tasklist-id> <task-id>

# Delete a task
gws tasks delete <tasklist-id> <task-id>

# Move a task (reorder)
gws tasks move <tasklist-id> <task-id> --parent <parent-task-id>
```

## Task Properties

| Property | Description                       |
| -------- | --------------------------------- |
| `title`  | Task title                        |
| `notes`  | Task description/notes            |
| `due`    | Due date (RFC 3339 or YYYY-MM-DD) |
| `status` | `needsAction` or `completed`      |
| `parent` | Parent task ID (for subtasks)     |

## Tips

- The default task list ID is `@default`
- Tasks support subtasks via the `--parent` parameter
- Use `--format json` for structured output
- Due dates are date-only (no time component)
