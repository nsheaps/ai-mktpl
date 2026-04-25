# Work Tracking Rules

Cross-cutting rules for how tasks, PRs, milestones, and communication threads relate to each other.

> **Applicability:** These rules assume a multi-agent setup with coordinating roles (SE, PM, etc.). In single-agent setups, treat "thread" as the handler's primary communication surface (e.g., a Discord channel or Telegram chat).

## 1. Thread Ownership by Role

- **Task threads** — created by the SE (software engineer) agent. Track active work: testing, reviews, PRs, research, coordination.
- **Milestone threads** — created by the PM agent. Track milestone/project status and communicate overall progress to the handler.

## 2. Linking Requirements

### Every task thread MUST link to a milestone

When the SE creates a task thread, it must be linked to a milestone thread. If no milestone exists, coordinate with the PM to create one or assign to an existing one.

### Every PR MUST link to a task thread + GitHub issue + milestone

When a PR is created, ensure all three exist:

1. A task thread tracking the work
2. A GitHub issue for coordination
3. A milestone thread

If any don't exist, coordinate with the PM to create them.

### PRs MUST be developed against merged specs

- Specs live on default branches in the relevant repos
- Issues are coordination ground ("tickets to assign"), NOT the source of truth for specs (see `github-issues-task-management.md` for issue-tracking conventions)
- All specs should be merged (and reviewed if required) before PR work begins

## 3. Thread Discipline

### First message = source of truth

The first message in any thread (task or milestone) is always the canonical state. Discussion within the thread should result in updating the first message:

- Task threads: update CI status, mergeability, PR state, "last checked" timestamp
- Milestone threads: update completion status of constituent tasks

### Respond in the correct thread

If the handler asks about something in a thread that isn't the right thread for the answer:

1. Post the response in the correct thread
2. Tag the handler in that thread
3. Reply to the handler's original message with a link to the response

### Milestone threads = status; Task threads = work

- Milestone threads communicate STATUS to the handler (what's done, what's left)
- Task threads coordinate WORK (testing, reviews, iteration, research)
- Work updates post to task threads; phase completion posts to milestone threads

## 4. Moving Tasks Between Milestones

When a task moves milestones:

1. Update the OLD milestone thread (remove/mark as moved)
2. Update the NEW milestone thread (add the task)
3. Both updates should be in the first message of each thread

## Definitions

- **task thread** — A forum thread in the designated tasks channel that tracks a specific unit of work. Each thread has a title prefix (`feat:`, `fix:`, etc.) and a first-message that serves as the canonical state. The specific channel is project-dependent.
- **handler** — The human operator who manages and directs the AI agent. The handler provides direction, approves merges, and makes final decisions. In this context, this is typically the repository owner.

## Source

- [Thread ownership and linking requirements](https://discord.com/channels/1490863845252665415/1490890535878131792/1497248350947381399)
- [Thread discipline and milestone moves](https://discord.com/channels/1490863845252665415/1490890535878131792/1497248448125337793)
